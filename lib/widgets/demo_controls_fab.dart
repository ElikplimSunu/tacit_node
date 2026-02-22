// Demo controls FAB with expandable preset buttons.

import 'package:flutter/material.dart';
import 'package:tacit_node/models/demo_preset.dart';
import 'package:tacit_node/theme/app_colors.dart';

class DemoControlsFAB extends StatefulWidget {
  final Function(String query, bool simulateOffline) onPresetSelected;
  final VoidCallback onResetMetrics;
  final VoidCallback onToggleMetrics;
  final ValueChanged<bool>? onExpandedChanged;
  final bool? isExpanded;

  const DemoControlsFAB({
    super.key,
    required this.onPresetSelected,
    required this.onResetMetrics,
    required this.onToggleMetrics,
    this.onExpandedChanged,
    this.isExpanded,
  });

  @override
  State<DemoControlsFAB> createState() => _DemoControlsFABState();
}

class _DemoControlsFABState extends State<DemoControlsFAB>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.125,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Initialize from parent state if provided
    if (widget.isExpanded == true) {
      _isExpanded = true;
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(DemoControlsFAB oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync with parent state
    if (widget.isExpanded != null && widget.isExpanded != _isExpanded) {
      setState(() {
        _isExpanded = widget.isExpanded!;
        if (_isExpanded) {
          _controller.forward();
        } else {
          _controller.reverse();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
      // Notify parent of state change
      widget.onExpandedChanged?.call(_isExpanded);
    });
  }

  void _handlePresetTap(DemoPreset preset) {
    widget.onPresetSelected(preset.query, preset.simulateOffline);
    _toggleExpanded();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Backdrop scrim
        if (_isExpanded)
          GestureDetector(
            onTap: _toggleExpanded,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _isExpanded ? 0.3 : 0.0,
              child: Container(color: Colors.black),
            ),
          ),

        // Expanded menu
        if (_isExpanded)
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Preset buttons
              ...List.generate(
                DemoPreset.defaults.length,
                (index) =>
                    _buildPresetButton(DemoPreset.defaults[index], index),
              ),

              // Control buttons
              _buildControlButton(
                icon: Icons.analytics,
                color: AppColors.primary,
                onPressed: widget.onToggleMetrics,
                index: DemoPreset.defaults.length,
                tooltip: 'Toggle Metrics',
              ),

              const SizedBox(height: 12),

              _buildControlButton(
                icon: Icons.refresh,
                color: AppColors.info,
                onPressed: widget.onResetMetrics,
                index: DemoPreset.defaults.length + 1,
                tooltip: 'Reset Metrics',
              ),

              const SizedBox(height: 72), // Extra space for main FAB
            ],
          ),

        // Main FAB
        FloatingActionButton(
          onPressed: _toggleExpanded,
          backgroundColor: AppColors.primary,
          child: AnimatedBuilder(
            animation: _rotationAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationAnimation.value * 2 * 3.14159,
                child: Icon(
                  _isExpanded ? Icons.close : Icons.science,
                  size: 28,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPresetButton(DemoPreset preset, int index) {
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        final delay = index * 0.1;
        final progress =
            (_expandAnimation.value - delay).clamp(0.0, 1.0) / (1.0 - delay);
        final curvedProgress = Curves.easeOut.transform(progress);

        return Transform.translate(
          offset: Offset(0, (1 - curvedProgress) * 20),
          child: Opacity(
            opacity: curvedProgress,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Label
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: preset.color.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      preset.label,
                      style: TextStyle(
                        color: preset.color,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Button
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: preset.color,
                    onPressed: () => _handlePresetTap(preset),
                    heroTag: 'preset_$index',
                    child: Icon(preset.icon, size: 20),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required int index,
    required String tooltip,
  }) {
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        final delay = index * 0.1;
        final progress =
            (_expandAnimation.value - delay).clamp(0.0, 1.0) / (1.0 - delay);
        final curvedProgress = Curves.easeOut.transform(progress);

        return Transform.translate(
          offset: Offset(0, (1 - curvedProgress) * 20),
          child: Opacity(
            opacity: curvedProgress,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Label
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: color.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    tooltip,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Button
                FloatingActionButton(
                  mini: true,
                  backgroundColor: color,
                  onPressed: () {
                    onPressed();
                    _toggleExpanded();
                  },
                  heroTag: 'control_$index',
                  tooltip: tooltip,
                  child: Icon(icon, size: 20),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
