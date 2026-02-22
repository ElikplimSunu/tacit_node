import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../models/routing_decision.dart';
import '../services/camera_service.dart';
import '../services/copilot_service.dart';
import '../services/metrics_service.dart';
import '../services/connectivity_service.dart';
import '../widgets/debug_console.dart';
import '../widgets/model_status_bar.dart';
import '../widgets/routing_indicator.dart';
import '../widgets/metrics_overlay.dart';
import '../widgets/demo_controls_fab.dart';
import '../widgets/offline_banner.dart';
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
  final MetricsService _metrics = MetricsService();
  final ConnectivityService _connectivity = ConnectivityService();
  late final CopilotService _copilot;
  final CameraService _camera = CameraService();

  final TextEditingController _queryController = TextEditingController();
  final ScrollController _consoleScrollController = ScrollController();

  final List<ConsoleEntry> _consoleEntries = [];
  bool _isConsoleExpanded = false;
  bool _isProcessing = false;
  String _responseText = '';
  RoutingDecision? _lastRoutingDecision;
  String _statusText = 'Idle';
  double _downloadProgress = 0.0;
  bool _isModelReady = false;

  // New state for routing indicator
  RoutingState _routingState = RoutingState.idle;

  // New state for metrics overlay
  bool _showMetricsOverlay = false;

  // New state for connectivity
  bool _isOnline = true;
  bool _isSimulatingOffline = false;

  StreamSubscription<ConsoleEntry>? _consoleSub;
  StreamSubscription<RoutingDecision>? _routingSub;
  StreamSubscription<bool>? _connectivitySub;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    // Initialize CopilotService with metrics and connectivity services
    _copilot = CopilotService(
      metricsService: _metrics,
      connectivityService: _connectivity,
    );
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Initialize connectivity service
    await _connectivity.initialize();

    // Listen to connectivity stream
    _connectivitySub = _connectivity.connectivityStream.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
          _isSimulatingOffline = _connectivity.isSimulatingOffline;
        });
      }
    });

    // Listen to console stream
    _consoleSub = _copilot.consoleStream.listen((entry) {
      if (mounted) {
        setState(() => _consoleEntries.add(entry));
        _scrollConsoleToBottom();
      }
    });

    // Listen to routing decisions
    _routingSub = _copilot.routingStream.listen((decision) {
      if (mounted) {
        setState(() {
          _lastRoutingDecision = decision;
        });
      }
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

  void _handlePresetSelected(String query, bool simulateOffline) {
    _queryController.text = query;
    if (simulateOffline && !_isSimulatingOffline) {
      _connectivity.toggleOfflineSimulation();
    }
    _handleQuery();
  }

  void _handleResetMetrics() {
    _metrics.reset();
    setState(() {
      _consoleEntries.clear();
      _responseText = '';
      _lastRoutingDecision = null;
    });
  }

  void _toggleMetricsOverlay() {
    setState(() {
      _showMetricsOverlay = !_showMetricsOverlay;
    });
  }

  Future<void> _handleQuery() async {
    final query = _queryController.text.trim();
    if (query.isEmpty || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _responseText = '';
      _lastRoutingDecision = null;
      _routingState = RoutingState.analyzingLocal;
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

    // Update routing state based on decision
    if (_lastRoutingDecision != null) {
      if (_lastRoutingDecision!.action == ActionType.cloudEscalation) {
        setState(() => _routingState = RoutingState.escalatingCloud);
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    // Complete routing animation
    setState(() => _routingState = RoutingState.complete);
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() {
        _responseText = _sanitizeResponse(response);
        _isProcessing = false;
        _routingState = RoutingState.idle;
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
    _connectivitySub?.cancel();
    _statusTimer?.cancel();
    _copilot.dispose();
    _camera.dispose();
    _metrics.dispose();
    _connectivity.dispose();
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
              isOnline: _isOnline,
              isSimulatingOffline: _isSimulatingOffline,
              onToggleMetrics: _toggleMetricsOverlay,
            ),
          ),

          // Layer 3.5: Offline banner (below status bar)
          if (!_isOnline || _isSimulatingOffline)
            Positioned(
              top: MediaQuery.of(context).padding.top + 50,
              left: 0,
              right: 0,
              child: OfflineBanner(
                isOnline: _isOnline,
                isSimulatingOffline: _isSimulatingOffline,
              ),
            ),

          // Layer 4: Routing indicator (center)
          if (_routingState != RoutingState.idle)
            Center(
              child: RoutingIndicator(
                state: _routingState,
                onComplete: () {
                  setState(() => _routingState = RoutingState.idle);
                },
              ),
            ),

          // Layer 5: Response card (when showing results)
          if (_responseText.isNotEmpty && _lastRoutingDecision != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 16,
              right: 16,
              child: _buildResponseCard(_lastRoutingDecision!, _responseText),
            ),

          // Layer 6: Metrics overlay (top-right)
          StreamBuilder(
            stream: _metrics.metricsStream,
            builder: (context, snapshot) {
              return MetricsOverlay(
                metrics: _metrics.currentMetrics,
                isVisible: _showMetricsOverlay,
                onClose: _toggleMetricsOverlay,
              );
            },
          ),

          // Layer 7: Bottom input + debug console
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

          // Layer 8: Demo controls FAB (bottom-right)
          Positioned(
            bottom: _isConsoleExpanded ? 320 : 120,
            right: 16,
            child: DemoControlsFAB(
              onPresetSelected: _handlePresetSelected,
              onResetMetrics: _handleResetMetrics,
              onToggleMetrics: _toggleMetricsOverlay,
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

  Widget _buildResponseCard(RoutingDecision decision, String response) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 280),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0x881A1A2E), // Glassmorphism
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: decision.routingColor.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: decision.routingColor.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader(decision),
              const SizedBox(height: 8),
              _buildMetricsBadges(decision),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    response,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              if (decision.routingPath.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildRoutingPath(decision),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(RoutingDecision decision) {
    return Row(
      children: [
        Icon(decision.routingIcon, size: 16, color: decision.routingColor),
        const SizedBox(width: 8),
        Text(
          decision.actionLabel,
          style: AppTypography.labelSmall.copyWith(
            color: decision.routingColor,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          decision.formattedTime,
          style: AppTypography.labelSmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => setState(() {
            _responseText = '';
            _lastRoutingDecision = null;
          }),
          child: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildMetricsBadges(RoutingDecision decision) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (decision.latencyMs != null)
          _buildMetricBadge(
            icon: Icons.speed,
            label: decision.formattedLatency,
            color: decision.routingColor,
          ),
        if (decision.tokensPerSecond != null)
          _buildMetricBadge(
            icon: Icons.flash_on,
            label: decision.formattedTps,
            color: AppColors.success,
          ),
        if (decision.estimatedCost != null && decision.estimatedCost! > 0)
          _buildMetricBadge(
            icon: Icons.cloud,
            label: decision.formattedCost,
            color: AppColors.warning,
          ),
        if (decision.action == ActionType.localInference)
          _buildMetricBadge(
            icon: Icons.savings,
            label: 'Saved \$0.0001',
            color: AppColors.success,
          ),
        if (decision.isOffline)
          _buildMetricBadge(
            icon: Icons.airplanemode_active,
            label: 'Offline',
            color: AppColors.info,
          ),
      ],
    );
  }

  Widget _buildMetricBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutingPath(RoutingDecision decision) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.route, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              decision.routingPath,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textMuted,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.6),
          ), // Glassmorphism
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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface.withValues(alpha: 0.6),
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
        ),
      ),
    );
  }
}
