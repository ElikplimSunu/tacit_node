import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../models/routing_decision.dart';
import '../services/camera_service.dart';
import '../services/copilot_service.dart';
import '../widgets/debug_console.dart';
import '../widgets/model_status_bar.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// The main operator interface:
/// Full-screen camera preview, debug console overlay, query input,
/// and floating capture button.
class CopilotScreen extends StatefulWidget {
  const CopilotScreen({super.key});

  @override
  State<CopilotScreen> createState() => _CopilotScreenState();
}

class _CopilotScreenState extends State<CopilotScreen> {
  final CopilotService _copilot = CopilotService();
  final CameraService _camera = CameraService();

  final TextEditingController _queryController = TextEditingController();
  final ScrollController _consoleScrollController = ScrollController();

  final List<ConsoleEntry> _consoleEntries = [];
  bool _isConsoleExpanded = false;
  bool _isProcessing = false;
  String _responseText = '';
  String _statusText = 'Idle';
  double _downloadProgress = 0.0;
  bool _isModelReady = false;

  StreamSubscription<ConsoleEntry>? _consoleSub;
  StreamSubscription<RoutingDecision>? _routingSub;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Listen to console stream
    _consoleSub = _copilot.consoleStream.listen((entry) {
      if (mounted) {
        setState(() => _consoleEntries.add(entry));
        _scrollConsoleToBottom();
      }
    });

    // Listen to routing decisions
    _routingSub = _copilot.routingStream.listen((decision) {
      // Routing events are already logged to the console
    });

    // Poll status updates
    _statusTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (mounted) {
        setState(() {
          _statusText = _copilot.statusMessage;
          _downloadProgress = _copilot.downloadProgress;
          _isModelReady = _copilot.isModelReady;
        });
      }
    });

    // Initialize camera
    await _camera.initialize();
    if (mounted) setState(() {});

    // Initialize copilot (downloads + loads model)
    await _copilot.initialize();
  }

  void _scrollConsoleToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_consoleScrollController.hasClients) {
        _consoleScrollController.animateTo(
          _consoleScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleQuery() async {
    final query = _queryController.text.trim();
    if (query.isEmpty || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _responseText = '';
    });

    // Capture a frame if camera is available
    String? imageFilePath;
    String? base64Image;
    if (_camera.isInitialized) {
      imageFilePath = await _camera.captureFrame();
      base64Image = await _camera.captureFrameAsBase64();
    }

    final response = await _copilot.processQuery(
      query,
      imageFilePath: imageFilePath,
      base64Image: base64Image,
    );

    if (mounted) {
      setState(() {
        _responseText = _sanitizeResponse(response);
        _isProcessing = false;
      });
    }

    _queryController.clear();
  }

  /// Strips Qwen3 thinking tokens and other model artifacts from display text.
  String _sanitizeResponse(String raw) {
    var cleaned = raw;
    // Remove <think>...</think> blocks (greedy across newlines)
    cleaned = cleaned.replaceAll(
      RegExp(r'<think>.*?</think>', dotAll: true),
      '',
    );
    // Remove stray opening/closing think tags
    cleaned = cleaned.replaceAll(RegExp(r'</?think>'), '');
    // Remove end-of-turn markers
    cleaned = cleaned.replaceAll(RegExp(r'<\|im_end\|>'), '');
    cleaned = cleaned.replaceAll(RegExp(r'<\|endoftext\|>'), '');
    // Collapse excessive whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return cleaned.trim();
  }

  @override
  void dispose() {
    _consoleSub?.cancel();
    _routingSub?.cancel();
    _statusTimer?.cancel();
    _copilot.dispose();
    _camera.dispose();
    _queryController.dispose();
    _consoleScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Layer 1: Camera preview (or placeholder)
          Positioned.fill(child: _buildCameraLayer()),

          // Layer 2: Dark gradient overlay for readability
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  stops: const [0.0, 0.15, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // Layer 3: Top status bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ModelStatusBar(
              status: _statusText,
              downloadProgress: _downloadProgress,
              isModelReady: _isModelReady,
            ),
          ),

          // Layer 4: Response card (when showing results)
          if (_responseText.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 16,
              right: 16,
              child: _buildResponseCard(),
            ),

          // Layer 5: Bottom input + debug console
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Query input bar
                _buildInputBar(),
                // Debug console
                DebugConsole(
                  entries: _consoleEntries,
                  scrollController: _consoleScrollController,
                  isExpanded: _isConsoleExpanded,
                  onToggle: () =>
                      setState(() => _isConsoleExpanded = !_isConsoleExpanded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sub-builders
  // ---------------------------------------------------------------------------

  Widget _buildCameraLayer() {
    if (!_camera.isInitialized || _camera.controller == null) {
      return Container(
        color: AppColors.background,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_off_rounded,
                size: 64,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 12),
              Text(
                'No camera available',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Running in text-only mode',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _camera.controller!.value.previewSize?.height ?? 1,
            height: _camera.controller!.value.previewSize?.width ?? 1,
            child: CameraPreview(_camera.controller!),
          ),
        ),
      ),
    );
  }

  Widget _buildResponseCard() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xEE1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _responseText.startsWith('☁️')
              ? AppColors.warning.withValues(alpha: 0.4)
              : AppColors.success.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 16),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _responseText.startsWith('☁️')
                    ? Icons.cloud
                    : Icons.check_circle,
                size: 16,
                color: _responseText.startsWith('☁️')
                    ? AppColors.warning
                    : AppColors.success,
              ),
              const SizedBox(width: 8),
              Text(
                _responseText.startsWith('☁️')
                    ? 'EXPERT ANALYSIS'
                    : 'LOCAL VALIDATION',
                style: AppTypography.labelSmall.copyWith(
                  color: _responseText.startsWith('☁️')
                      ? AppColors.warning
                      : AppColors.success,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _responseText = ''),
                child: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Text(
                _responseText,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(color: AppColors.surface),
      child: Row(
        children: [
          // Capture button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isProcessing
                  ? null
                  : () {
                      if (_queryController.text.trim().isEmpty) {
                        _queryController.text = 'What do you see?';
                      }
                      _handleQuery();
                    },
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isProcessing
                      ? Colors.grey.shade800
                      : AppColors.primary,
                  boxShadow: _isProcessing
                      ? []
                      : [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                          ),
                        ],
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Text input
          Expanded(
            child: TextField(
              controller: _queryController,
              onSubmitted: (_) => _handleQuery(),
              style: AppTypography.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Ask about what you see…',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Send button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isProcessing ? null : _handleQuery,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: _isProcessing
                      ? AppColors.textMuted
                      : AppColors.primary,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
