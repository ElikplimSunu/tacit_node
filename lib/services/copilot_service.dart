import 'dart:async';
import 'dart:convert';
import 'package:cactus/cactus.dart';
import '../models/routing_decision.dart';
import '../models/session_metrics.dart';
import '../utils/logger.dart';
import 'cloud_service.dart';
import 'metrics_service.dart';
import 'connectivity_service.dart';

/// The core orchestration service.
/// Manages the local Cactus LLM for function calling and routes
/// between local inference and cloud escalation.
class CopilotService {
  // FunctionGemma for tool-call routing
  final CactusLM _lm = CactusLM(enableToolFiltering: true);

  // Local vision model for image identification
  final CactusLM _visionLm = CactusLM();
  bool _isVisionReady = false;

  final CloudService _cloudService = CloudService();

  // NEW: Metrics and connectivity services
  final MetricsService? _metricsService;
  final ConnectivityService? _connectivityService;

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

  // Constructor with optional services
  CopilotService({
    MetricsService? metricsService,
    ConnectivityService? connectivityService,
  }) : _metricsService = metricsService,
       _connectivityService = connectivityService;

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
                'Name of the component. If the user asks "what do you see?" or "what is this?", you MUST set this exactly to "unknown".',
            required: true,
          ),
          'step_description': ToolParameter(
            type: 'string',
            description:
                'Description of the step. If identifying an unknown component, set this exactly to "identifying".',
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
    CactusTool(
      name: 'answer_query',
      description:
          'Use this to directly answer the user\'s question, provide instructions, or give conversational feedback based on your existing knowledge. '
          'Do NOT use this if you need to see an image or diagnose a complex fault.',
      parameters: ToolParametersSchema(
        properties: {
          'response_text': ToolParameter(
            type: 'string',
            description: 'The conversational response to display to the user.',
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
You are TacitNode, a strict routing model assisting a technician.
You MUST reply ONLY with a valid JSON tool call.
DO NOT use Markdown formatting (e.g., no ```json blocks).
DO NOT output any conversational text before or after the JSON.

ROUTING RULES:
1. If the user asks "what do you see?", "what is this?", or to identify something:
   Call `validate_routine_step` and set `component_name` exactly to "unknown".
2. If the user asks "why did this fail?", "what is the error?", or needs deep diagnosis:
   Call `escalate_to_expert`.
3. If the user asks a general question, needs instructions, or greets you:
   Call `answer_query`.

EXAMPLES:
User: "What do you see?"
Model: {"name": "validate_routine_step", "arguments": {"component_name": "unknown", "step_description": "identifying"}}

User: "Why is the motor smoking?"
Model: {"name": "escalate_to_expert", "arguments": {"query": "Why is the motor smoking?", "reason": "user requested diagnosis"}}

User: "How do I connect a resistor?"
Model: {"name": "answer_query", "arguments": {"response_text": "Connect one leg to the positive terminal and..."}}
''';

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Downloads and initializes the local model.
  Future<void> initialize() async {
    _updateStatus('Downloading model…');
    _log('Initializing Cactus LLM engine…', ConsoleSeverity.info);

    try {
      // ---- 1. Download & init FunctionGemma (routing) ----
      _updateStatus('Downloading routing model…');
      await _lm.downloadModel(
        model: 'functiongemma-270m',
        downloadProcessCallback: (progress, status, isError) {
          if (isError) {
            _log('Download error: $status', ConsoleSeverity.error);
          } else {
            _downloadProgress = (progress ?? 0.0) * 0.5; // 0-50%
            _updateStatus(
              'Routing model: ${(_downloadProgress * 200).toStringAsFixed(0)}%',
            );
          }
        },
      );

      _updateStatus('Loading routing model…');
      await _lm.initializeModel();
      _log('✅ FunctionGemma loaded.', ConsoleSeverity.success);

      // ---- 2. Download & init vision model ----
      _updateStatus('Downloading vision model…');
      await _visionLm.downloadModel(
        model: 'lfm2-vl-450m',
        downloadProcessCallback: (progress, status, isError) {
          if (isError) {
            _log('Vision download error: $status', ConsoleSeverity.error);
          } else {
            _downloadProgress = 0.5 + (progress ?? 0.0) * 0.5; // 50-100%
            _updateStatus(
              'Vision model: ${((progress ?? 0.0) * 100).toStringAsFixed(0)}%',
            );
          }
        },
      );

      _updateStatus('Loading vision model…');
      await _visionLm.initializeModel(
        params: CactusInitParams(model: 'lfm2-vl-450m', contextSize: 1024),
      );
      _isVisionReady = true;
      _log('✅ Vision model loaded.', ConsoleSeverity.success);

      _isModelReady = true;
      _updateStatus('Ready');
      _log('✅ All models ready.', ConsoleSeverity.success);
    } catch (e) {
      _updateStatus('Error');
      _log('Model init failed: $e', ConsoleSeverity.error);
    }
  }

  // ---------------------------------------------------------------------------
  // Query processing
  // ---------------------------------------------------------------------------

  /// Processes a technician's query, optionally with captured images.
  /// [imageFilePath] is the raw file path (for local vision model).
  /// [base64Image] is the base64-encoded image (for cloud fallback).
  Future<String> processQuery(
    String query, {
    String? imageFilePath,
    String? base64Image,
  }) async {
    if (!_isModelReady) {
      _log('Model not ready. Cannot process query.', ConsoleSeverity.warning);
      return 'Model is still loading. Please wait.';
    }

    // NEW: Start timing
    final startTime = DateTime.now();

    _updateStatus('Processing…');
    _log('📥 Query: "$query"', ConsoleSeverity.info);

    try {
      // FunctionGemma is text-only — do NOT pass images to it.
      // Images are handled by the vision model in _handleLocalValidation.
      final userMessage = ChatMessage(content: query, role: 'user');

      final messages = [
        ChatMessage(content: _systemPrompt, role: 'system'),
        userMessage,
      ];

      // Clear any previous chat context in the engine so it doesn't hallucinate
      // components from previous queries.
      _lm.reset();

      final result = await _lm.generateCompletion(
        messages: messages,
        params: CactusCompletionParams(tools: _tools),
      );

      // ---- Log raw model output for debugging ----
      _log(
        '🔬 Raw result: success=${result.success}, '
        'toolCalls=${result.toolCalls.length}, '
        'tokens=${result.totalTokens}, '
        'tps=${result.tokensPerSecond.toStringAsFixed(1)}',
        ConsoleSeverity.info,
      );
      _log('🔬 Raw response text: "${result.response}"', ConsoleSeverity.info);
      if (result.toolCalls.isNotEmpty) {
        for (final tc in result.toolCalls) {
          _log(
            '🔬 Tool call: ${tc.name}(${jsonEncode(tc.arguments)})',
            ConsoleSeverity.info,
          );
        }
      }

      if (!result.success) {
        _log(
          '🟡 Local inference failed — auto-escalating to cloud',
          ConsoleSeverity.warning,
        );
        // Still try fallback parsing on the raw text before escalating
        final parsed = _tryParseToolFromResponse(result.response);
        if (parsed != null) {
          _log(
            '🔧 Recovered tool call from failed result: ${parsed['name']}',
            ConsoleSeverity.info,
          );
          final toolName = parsed['name'] as String;
          final toolArgs = Map<String, dynamic>.from(
            parsed['args'] as Map<String, dynamic>? ?? {},
          );
          if (toolName == 'validate_routine_step') {
            return await _handleLocalValidation(
              toolArgs,
              query,
              imageFilePath,
              base64Image,
              startTime,
              result.tokensPerSecond,
            );
          } else if (toolName == 'escalate_to_expert') {
            return await _handleCloudEscalation(
              toolArgs,
              query,
              base64Image,
              startTime,
            );
          } else if (toolName == 'answer_query') {
            return _handleAnswerQuery(
              toolArgs,
              startTime,
              result.tokensPerSecond,
            );
          }
        }
        final lowerQuery = query.toLowerCase();
        if (imageFilePath != null &&
            (lowerQuery.contains('what') ||
                lowerQuery.contains('how') ||
                lowerQuery.contains('identify') ||
                lowerQuery.contains('is this'))) {
          _log(
            '🔄 Engine failed but camera is active. Defaulting to local vision.',
            ConsoleSeverity.info,
          );
          return await _handleLocalValidation(
            {'component_name': 'unknown', 'step_description': 'identifying'},
            query,
            imageFilePath,
            base64Image,
            startTime,
            result.tokensPerSecond,
          );
        }

        return await _handleCloudEscalation(
          {'query': query, 'reason': 'Local model produced unparseable output'},
          query,
          base64Image,
          startTime,
        );
      }

      _log(
        '⚡ Inference: ${result.tokensPerSecond.toStringAsFixed(1)} tok/s',
        ConsoleSeverity.info,
      );

      // Check for tool calls
      if (result.toolCalls.isNotEmpty) {
        return await _handleToolCalls(
          result.toolCalls,
          query,
          imageFilePath,
          base64Image,
          startTime,
          result.tokensPerSecond,
        );
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
          return await _handleLocalValidation(
            toolArgs,
            query,
            imageFilePath,
            base64Image,
            startTime,
            result.tokensPerSecond,
          );
        } else if (toolName == 'escalate_to_expert') {
          return await _handleCloudEscalation(
            toolArgs,
            query,
            base64Image,
            startTime,
          );
        } else if (toolName == 'answer_query') {
          return _handleAnswerQuery(
            toolArgs,
            startTime,
            result.tokensPerSecond,
          );
        }
      }

      // Last resort: auto-escalate to cloud
      _log(
        '🟡 No tool call detected — auto-escalating to cloud',
        ConsoleSeverity.warning,
      );
      final lowerQuery = query.toLowerCase();
      if (imageFilePath != null &&
          (lowerQuery.contains('what') ||
              lowerQuery.contains('how') ||
              lowerQuery.contains('identify') ||
              lowerQuery.contains('is this'))) {
        _log(
          '🔄 No tool called but camera is active. Defaulting to local vision.',
          ConsoleSeverity.info,
        );
        return await _handleLocalValidation(
          {'component_name': 'unknown', 'step_description': 'identifying'},
          query,
          imageFilePath,
          base64Image,
          startTime,
          result.tokensPerSecond,
        );
      }

      return await _handleCloudEscalation(
        {'query': query, 'reason': 'Local model did not call a tool'},
        query,
        base64Image,
        startTime,
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
    String? imageFilePath,
    String? base64Image,
    DateTime startTime,
    double tokensPerSecond,
  ) async {
    for (final call in toolCalls) {
      final toolName = call.name;
      final Map<String, dynamic> toolArgs = Map<String, dynamic>.from(
        call.arguments,
      );

      if (toolName == 'validate_routine_step') {
        return await _handleLocalValidation(
          toolArgs,
          originalQuery,
          imageFilePath,
          base64Image,
          startTime,
          tokensPerSecond,
        );
      } else if (toolName == 'escalate_to_expert') {
        return await _handleCloudEscalation(
          toolArgs,
          originalQuery,
          base64Image,
          startTime,
        );
      } else if (toolName == 'answer_query') {
        return _handleAnswerQuery(toolArgs, startTime, tokensPerSecond);
      }
    }

    _updateStatus('Ready');
    return 'Unknown tool call.';
  }

  Future<String> _handleLocalValidation(
    Map<String, dynamic> args,
    String originalQuery,
    String? imageFilePath,
    String? base64Image,
    DateTime startTime,
    double? tokensPerSecond,
  ) async {
    var component = (args['component_name'] as String?)?.trim() ?? '';
    var step = (args['step_description'] as String?)?.trim() ?? '';

    // FunctionGemma can't see images — use the local vision model when it routes
    // generic identification requests passing 'unknown', 'null', or 'identify'.
    final needsVision =
        component.isEmpty || // Empty string
        component.toLowerCase().contains('unknown') || // "unknown" or 'unknown'
        component.toLowerCase().contains('null') || // "null"
        component.toLowerCase().contains(
          'identify',
        ) || // "identify" or 'identify'
        step.toLowerCase().contains(
          'identify',
        ); // Sometimes the model hallucinates generic step descriptions

    if (needsVision && imageFilePath != null) {
      if (_isVisionReady) {
        _log(
          '�️ Running local vision model for identification…',
          ConsoleSeverity.info,
        );

        try {
          final visionResult = await _visionLm.generateCompletion(
            messages: [
              ChatMessage(
                content:
                    'Identify the main object or electronic component in this image.\n'
                    'Be concise. Just name the component (e.g., "Red LED", "Arduino Uno", "Breadboard").\n'
                    'Do not describe the scene, just provide the name.',
                role: 'user',
                images: [imageFilePath],
              ),
            ],
            params: CactusCompletionParams(maxTokens: 20, temperature: 0.1),
          );

          if (visionResult.success && visionResult.response.isNotEmpty) {
            _log(
              '👁️ Vision: ${visionResult.tokensPerSecond.toStringAsFixed(1)} tok/s',
              ConsoleSeverity.info,
            );
            final visionText = visionResult.response
                .replaceAll('<|im_end|>', '')
                .trim();

            // Aggressively format the vision text
            var stripped = visionText;

            // If the model ignores the prompt and forms a sentence ending in "is a [noun]"
            final isMatch = RegExp(
              r'is a\s+([^,.]+)',
              caseSensitive: false,
            ).firstMatch(stripped);
            if (isMatch != null && isMatch.groupCount >= 1) {
              stripped = isMatch.group(1)!;
            }

            stripped = stripped.replaceAll(
              RegExp(
                r'^(a|an|the|this is|i see|primary|electronic|component|in|this|image)\s+',
                caseSensitive: false,
              ),
              '',
            );

            // Strip numbered list prefixes (e.g. "1. " or "- ") instead of destroying everything after a period.
            stripped = stripped.replaceAll(RegExp(r'^[\d\.\-\*\s]+'), '');

            stripped = stripped.trim();

            if (stripped.contains(' - ')) {
              component = stripped.split(' - ').first.trim();
              step = stripped;
            } else {
              component = stripped.split('\n').first.trim();
              step = stripped;
            }
          }
        } catch (e) {
          _log('⚠️ Local vision failed: $e', ConsoleSeverity.warning);
        }
      }

      // Cloud vision as fallback if local vision unavailable or failed
      if ((component.isEmpty || step.isEmpty) && base64Image != null) {
        _log(
          '🔍 Local vision unavailable → cloud vision fallback',
          ConsoleSeverity.info,
        );
        try {
          final cloudResponse = await _cloudService.escalateToCloud(
            base64Image: base64Image,
            query: 'Briefly identify the main component in the image.',
          );
          component = cloudResponse.split('.').first.trim();
          step = cloudResponse.trim();
        } catch (e) {
          _log('⚠️ Cloud vision failed: $e', ConsoleSeverity.warning);
          component = 'Component detected';
          step = 'Local routing successful. Vision unavailable.';
        }
      }
    }

    // Use query-based fallback if still empty (text-only mode, no camera)
    if (component.isEmpty) component = 'component';
    if (step.isEmpty) step = 'Identified by local model';

    // NEW: Calculate latency
    final latencyMs = DateTime.now().difference(startTime).inMilliseconds;

    final decision = _createDecision(
      action: ActionType.localInference,
      confidence: 0.95,
      rawJson: {
        'tool': 'validate_routine_step',
        'args': {'component_name': component, 'step_description': step},
      },
      toolName: 'validate_routine_step',
      toolArgs: {'component_name': component, 'step_description': step},
      latencyMs: latencyMs,
      tokensPerSecond: tokensPerSecond,
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

  String _handleAnswerQuery(
    Map<String, dynamic> args,
    DateTime startTime,
    double? tokensPerSecond,
  ) {
    final responseText =
        args['response_text'] ?? 'I cannot answer that right now.';

    // NEW: Calculate latency
    final latencyMs = DateTime.now().difference(startTime).inMilliseconds;

    final decision = _createDecision(
      action: ActionType.localInference,
      confidence: 0.95,
      rawJson: {
        'tool': 'answer_query',
        'args': {'response_text': responseText},
      },
      toolName: 'answer_query',
      toolArgs: {'response_text': responseText},
      latencyMs: latencyMs,
      tokensPerSecond: tokensPerSecond,
    );
    _routingStream.add(decision);

    _log(
      '🟢 Action: Conversational Reply\n'
      '   Response: $responseText',
      ConsoleSeverity.success,
    );
    _log(
      '📋 ${jsonEncode(decision.rawJson)}',
      ConsoleSeverity.info,
      metadata: decision.rawJson,
    );

    _updateStatus('Ready');
    return responseText;
  }

  Future<String> _handleCloudEscalation(
    Map<String, dynamic> args,
    String originalQuery,
    String? base64Image,
    DateTime startTime,
  ) async {
    final query = args['query'] ?? originalQuery;
    final reason = args['reason'] ?? 'Unknown reason';

    // NEW: Calculate latency
    final latencyMs = DateTime.now().difference(startTime).inMilliseconds;

    final decision = _createDecision(
      action: ActionType.cloudEscalation,
      confidence: 0.0,
      rawJson: {'tool': 'escalate_to_expert', 'args': args},
      toolName: 'escalate_to_expert',
      toolArgs: args,
      latencyMs: latencyMs,
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

      // Log the actual response content for debugging
      _log('📝 Cloud response: $cloudResponse', ConsoleSeverity.info);

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
      // First try to extract a properly quoted string, robust to internal commas/periods
      final quotePattern = RegExp(
        key + r'''[\s"':]+([\"\'])(.*?)\1''',
        dotAll: true,
      );
      final quoteMatch = quotePattern.firstMatch(response);
      if (quoteMatch != null) {
        return quoteMatch.group(2)?.trim();
      }

      // Fallback for unquoted strings or improperly escaped ends
      final pattern = RegExp(key + r'[\s":]+([^",}{]+)');
      final match = pattern.firstMatch(response);
      return match?.group(1)?.replaceAll(RegExp(r'[\u0027\u0022]'), '').trim();
    }

    if (lower.contains('validate_routine_step')) {
      return {
        'name': 'validate_routine_step',
        'args': {
          'component_name': extractValue('component_name') ?? 'unknown',
          'step_description': extractValue('step_description') ?? 'identifying',
        },
      };
    }

    if (lower.contains('escalate_to_expert')) {
      return {
        'name': 'escalate_to_expert',
        'args': {
          'query': extractValue('query') ?? response,
          'reason': extractValue('reason') ?? 'Model requested escalation',
        },
      };
    }

    if (lower.contains('answer_query')) {
      return {
        'name': 'answer_query',
        'args': {
          'response_text':
              extractValue('response_text') ??
              'I understood your query but encountered a parsing error.',
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

  // ---------------------------------------------------------------------------
  // NEW: Metrics helpers
  // ---------------------------------------------------------------------------

  /// Build routing path string based on action type and tool
  String _buildRoutingPath(ActionType action, String? toolName) {
    if (action == ActionType.localInference) {
      if (toolName == 'validate_routine_step') {
        return 'Local Routing → Local Vision → Response';
      } else if (toolName == 'answer_query') {
        return 'Local Routing → Direct Response';
      }
      return 'Local Inference → Response';
    } else {
      return 'Local Routing → Cloud Escalation → Response';
    }
  }

  /// Calculate cost for a cloud query
  double _calculateCost(
    ActionType action, {
    int? inputTokens,
    int? outputTokens,
  }) {
    if (action == ActionType.cloudEscalation) {
      final input = inputTokens ?? SessionMetrics.avgInputTokens.toInt();
      final output = outputTokens ?? SessionMetrics.avgOutputTokens.toInt();

      return (input * SessionMetrics.costPerInputToken) +
          (output * SessionMetrics.costPerOutputToken);
    }
    return 0.0; // Local inference is free
  }

  /// Create enhanced routing decision with metrics
  RoutingDecision _createDecision({
    required ActionType action,
    required double confidence,
    required Map<String, dynamic> rawJson,
    required String? toolName,
    required Map<String, dynamic>? toolArgs,
    required int latencyMs,
    double? tokensPerSecond,
    int? inputTokens,
    int? outputTokens,
  }) {
    final decision = RoutingDecision(
      action: action,
      confidence: confidence,
      timestamp: DateTime.now(),
      rawJson: rawJson,
      toolName: toolName,
      toolArgs: toolArgs,
      latencyMs: latencyMs,
      tokensPerSecond: tokensPerSecond,
      estimatedCost: _calculateCost(
        action,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
      ),
      isOffline: _connectivityService?.isOnline == false,
      routingPath: _buildRoutingPath(action, toolName),
    );

    // Record to metrics service
    _metricsService?.recordDecision(decision);

    return decision;
  }

  /// Clean up.
  void dispose() {
    _lm.unload();
    _visionLm.unload();
    _consoleStream.close();
    _routingStream.close();
  }
}
