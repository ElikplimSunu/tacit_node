import 'dart:async';
import 'dart:convert';
import 'package:cactus/cactus.dart';
import '../models/routing_decision.dart';
import '../utils/logger.dart';
import 'cloud_service.dart';

/// The core orchestration service.
/// Manages the local Cactus LLM for function calling and routes
/// between local inference and cloud escalation.
class CopilotService {
  final CactusLM _lm = CactusLM(enableToolFiltering: true);

  final CloudService _cloudService = CloudService();

  final StreamController<ConsoleEntry> _consoleStream =
      StreamController<ConsoleEntry>.broadcast();
  final StreamController<RoutingDecision> _routingStream =
      StreamController<RoutingDecision>.broadcast();

  Stream<ConsoleEntry> get consoleStream => _consoleStream.stream;
  Stream<RoutingDecision> get routingStream => _routingStream.stream;

  bool _isModelReady = false;
  bool get isModelReady => _isModelReady;

  double _downloadProgress = 0.0;
  double get downloadProgress => _downloadProgress;

  String _statusMessage = 'Idle';
  String get statusMessage => _statusMessage;

  // ---------------------------------------------------------------------------
  // Tool definitions
  // ---------------------------------------------------------------------------

  static final List<CactusTool> _tools = [
    CactusTool(
      name: 'validate_routine_step',
      description:
          'Identifies a component or validates a routine step. '
          'Use for ANY visual identification query like "what is this?", '
          '"what do you see?", or when verifying known components '
          '(LED, breadboard, wrench, wire, resistor, capacitor, Arduino, etc). '
          'Also use when confirming a procedure step is correct.',
      parameters: ToolParametersSchema(
        properties: {
          'component_name': ToolParameter(
            type: 'string',
            description:
                'Name of the identified component (e.g. "LED", "breadboard")',
            required: true,
          ),
          'step_description': ToolParameter(
            type: 'string',
            description:
                'Brief description of what was identified or validated.',
            required: true,
          ),
        },
      ),
    ),
    CactusTool(
      name: 'escalate_to_expert',
      description:
          'Escalates to cloud expert for deep diagnosis. '
          'Use when: (1) asked WHY something is failing, '
          '(2) fault or anomaly detected, '
          '(3) complex troubleshooting needed, '
          '(4) you are unsure about the answer.',
      parameters: ToolParametersSchema(
        properties: {
          'query': ToolParameter(
            type: 'string',
            description: 'The question to forward to the expert.',
            required: true,
          ),
          'reason': ToolParameter(
            type: 'string',
            description: 'Why escalation is needed.',
            required: true,
          ),
        },
      ),
    ),
  ];

  // ---------------------------------------------------------------------------
  // System prompt
  // ---------------------------------------------------------------------------

  static const String _systemPrompt = '''
/no_think
You are TacitNode, a field equipment copilot. You MUST call exactly one tool for every query. NEVER respond with plain text.

ROUTING RULES:
- "What is this?", "What do you see?", identifying components → call validate_routine_step
- "Why is this failing?", diagnosing faults, unsure → call escalate_to_expert

ALWAYS call a tool. If unsure which, call escalate_to_expert.
''';

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Downloads and initializes the local model.
  Future<void> initialize() async {
    _updateStatus('Downloading model…');
    _log('Initializing Cactus LLM engine…', ConsoleSeverity.info);

    try {
      await _lm.downloadModel(
        model: 'qwen3-0.6',
        downloadProcessCallback: (progress, status, isError) {
          if (isError) {
            _log('Download error: $status', ConsoleSeverity.error);
          } else {
            _downloadProgress = progress ?? 0.0;
            _updateStatus(
              'Downloading: ${(_downloadProgress * 100).toStringAsFixed(0)}%',
            );
          }
        },
      );

      _updateStatus('Loading model…');
      await _lm.initializeModel();
      _isModelReady = true;
      _updateStatus('Ready');
      _log('✅ Model loaded and ready.', ConsoleSeverity.success);
    } catch (e) {
      _updateStatus('Error');
      _log('Model init failed: $e', ConsoleSeverity.error);
    }
  }

  // ---------------------------------------------------------------------------
  // Query processing
  // ---------------------------------------------------------------------------

  /// Processes a technician's query, optionally with a captured image.
  /// The local model decides whether to handle it locally or escalate.
  Future<String> processQuery(String query, {String? imagePath}) async {
    if (!_isModelReady) {
      _log('Model not ready. Cannot process query.', ConsoleSeverity.warning);
      return 'Model is still loading. Please wait.';
    }

    _updateStatus('Processing…');
    _log('📥 Query: "$query"', ConsoleSeverity.info);

    try {
      final userMessage = imagePath != null
          ? ChatMessage(content: query, role: 'user', images: [imagePath])
          : ChatMessage(content: query, role: 'user');

      final messages = [
        ChatMessage(content: _systemPrompt, role: 'system'),
        userMessage,
      ];

      final result = await _lm.generateCompletion(
        messages: messages,
        params: CactusCompletionParams(tools: _tools),
      );

      if (!result.success) {
        _log(
          '🟡 Local inference failed (likely malformed JSON) — auto-escalating to cloud',
          ConsoleSeverity.warning,
        );
        return await _handleCloudEscalation(
          {'query': query, 'reason': 'Local model produced unparseable output'},
          query,
          imagePath,
        );
      }

      _log(
        '⚡ Inference: ${result.tokensPerSecond.toStringAsFixed(1)} tok/s',
        ConsoleSeverity.info,
      );

      // Check for tool calls
      if (result.toolCalls.isNotEmpty) {
        return await _handleToolCalls(result.toolCalls, query, imagePath);
      }

      // Fallback: try to parse tool calls from raw response text
      final parsed = _tryParseToolFromResponse(result.response);
      if (parsed != null) {
        _log(
          '🔧 Recovered tool call from raw response: ${parsed['name']}',
          ConsoleSeverity.info,
        );
        final toolName = parsed['name'] as String;
        final toolArgs = Map<String, dynamic>.from(
          parsed['args'] as Map<String, dynamic>? ?? {},
        );
        if (toolName == 'validate_routine_step') {
          return _handleLocalValidation(toolArgs);
        } else if (toolName == 'escalate_to_expert') {
          return await _handleCloudEscalation(toolArgs, query, imagePath);
        }
      }

      // Last resort: auto-escalate to cloud
      _log(
        '🟡 No tool call detected — auto-escalating to cloud',
        ConsoleSeverity.warning,
      );
      return await _handleCloudEscalation(
        {'query': query, 'reason': 'Local model did not call a tool'},
        query,
        imagePath,
      );
    } catch (e) {
      _log('Error: $e', ConsoleSeverity.error);
      _updateStatus('Ready');
      return 'Error processing query: $e';
    }
  }

  // ---------------------------------------------------------------------------
  // Tool call handling
  // ---------------------------------------------------------------------------

  Future<String> _handleToolCalls(
    List<ToolCall> toolCalls,
    String originalQuery,
    String? imagePath,
  ) async {
    for (final call in toolCalls) {
      final toolName = call.name;
      final Map<String, dynamic> toolArgs = Map<String, dynamic>.from(
        call.arguments,
      );

      if (toolName == 'validate_routine_step') {
        return _handleLocalValidation(toolArgs);
      } else if (toolName == 'escalate_to_expert') {
        return await _handleCloudEscalation(toolArgs, originalQuery, imagePath);
      }
    }

    _updateStatus('Ready');
    return 'Unknown tool call.';
  }

  String _handleLocalValidation(Map<String, dynamic> args) {
    final component = args['component_name'] ?? 'unknown';
    final step = args['step_description'] ?? 'No description';

    final decision = RoutingDecision(
      action: ActionType.localInference,
      confidence: 0.95,
      timestamp: DateTime.now(),
      rawJson: {'tool': 'validate_routine_step', 'args': args},
      toolName: 'validate_routine_step',
      toolArgs: args,
    );
    _routingStream.add(decision);

    _log(
      '🟢 Action: Local Inference\n'
      '   Component: $component\n'
      '   Result: $step',
      ConsoleSeverity.success,
    );

    _log(
      '📋 ${jsonEncode(decision.rawJson)}',
      ConsoleSeverity.info,
      metadata: decision.rawJson,
    );

    _updateStatus('Ready');
    return '✅ $component — $step';
  }

  Future<String> _handleCloudEscalation(
    Map<String, dynamic> args,
    String originalQuery,
    String? base64Image,
  ) async {
    final query = args['query'] ?? originalQuery;
    final reason = args['reason'] ?? 'Unknown reason';

    final decision = RoutingDecision(
      action: ActionType.cloudEscalation,
      confidence: 0.0,
      timestamp: DateTime.now(),
      rawJson: {'tool': 'escalate_to_expert', 'args': args},
      toolName: 'escalate_to_expert',
      toolArgs: args,
    );
    _routingStream.add(decision);

    _log(
      '🟡 Action: Cloud Escalation Triggered\n'
      '   Reason: $reason',
      ConsoleSeverity.warning,
    );
    _log(
      '📋 ${jsonEncode(decision.rawJson)}',
      ConsoleSeverity.info,
      metadata: decision.rawJson,
    );

    _updateStatus('Escalating to cloud…');

    try {
      String cloudResponse;
      if (base64Image != null) {
        cloudResponse = await _cloudService.escalateToCloud(
          base64Image: base64Image,
          query: query,
        );
      } else {
        cloudResponse = await _cloudService.queryCloud(query: query);
      }

      _log(
        '🟢 Cloud response received (${cloudResponse.length} chars)',
        ConsoleSeverity.success,
      );
      _updateStatus('Ready');
      return '☁️ Expert Analysis:\n\n$cloudResponse';
    } catch (e) {
      _log('❌ Cloud escalation failed: $e', ConsoleSeverity.error);
      _updateStatus('Ready');
      return 'Cloud escalation failed: $e';
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Tries to recover a tool call from raw response text when the SDK
  /// couldn't parse it (the small model often generates slightly broken JSON).
  Map<String, dynamic>? _tryParseToolFromResponse(String response) {
    final lower = response.toLowerCase();

    // Extract a quoted value for a given key from messy model JSON output
    String? extractValue(String key) {
      final pattern = RegExp(key + r'[\s":]+([^",}{]+)');
      final match = pattern.firstMatch(response);
      return match?.group(1)?.trim();
    }

    if (lower.contains('validate_routine_step')) {
      return {
        'name': 'validate_routine_step',
        'args': {
          'component_name': extractValue('component_name') ?? 'component',
          'step_description':
              extractValue('step_description') ?? 'Identified by local model',
        },
      };
    }

    if (lower.contains('escalate_to_expert')) {
      return {
        'name': 'escalate_to_expert',
        'args': {
          'query': extractValue('query') ?? response,
          'reason':
              extractValue('reason') ?? 'Model requested escalation',
        },
      };
    }

    return null;
  }


  void _updateStatus(String status) {
    _statusMessage = status;
  }

  void _log(
    String message,
    ConsoleSeverity severity, {
    Map<String, dynamic>? metadata,
  }) {
    final entry = ConsoleEntry(
      message: message,
      severity: severity,
      metadata: metadata,
    );
    _consoleStream.add(entry);
    TLog.info(message);
  }

  /// Clean up.
  void dispose() {
    _lm.unload();
    _consoleStream.close();
    _routingStream.close();
  }
}
