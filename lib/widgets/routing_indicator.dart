// Routing indicator widget with animated visual feedback.

import 'package:flutter/material.dart';
import 'package:tacit_node/theme/app_colors.dart';
import 'package:tacit_node/theme/app_typography.dart';

enum RoutingState {
  idle, // Not visible
  analyzingLocal, // Green pulse animation
  escalatingCloud, // Amber pulse animation
  complete, // Fade out transition
}

class RoutingIndicator extends StatefulWidget {
  final RoutingState state;
  final VoidCallback? onComplete;

  const RoutingIndicator({super.key, required this.state, this.onComplete});

  @override
  State<RoutingIndicator> createState() => _RoutingIndicatorState();
}

class _RoutingIndicatorState extends State<RoutingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  // Animation configuration
  static const Duration pulseDuration = Duration(milliseconds: 800);
  static const Duration fadeDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(duration: pulseDuration, vsync: this);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _updateAnimation();
  }

  @override
  void didUpdateWidget(RoutingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    if (widget.state == RoutingState.idle) {
      _controller.stop();
      _controller.value = 0.0;
    } else if (widget.state == RoutingState.complete) {
      _controller.stop();
      // Fade out
      _controller.animateTo(0.0, duration: fadeDuration).then((_) {
        widget.onComplete?.call();
      });
    } else {
      // Pulse animation for analyzing/escalating states
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state == RoutingState.idle) {
      return const SizedBox.shrink();
    }

    final isLocal = widget.state == RoutingState.analyzingLocal;
    final color = isLocal ? AppColors.success : AppColors.warning;
    final icon = isLocal ? Icons.flash_on : Icons.cloud;
    final text = isLocal ? 'Analyzing locally...' : 'Escalating to expert...';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = widget.state == RoutingState.complete
            ? _fadeAnimation.value
            : 1.0;
        final scale = widget.state == RoutingState.complete
            ? 1.0
            : _pulseAnimation.value;

        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 32, color: color),
                  const SizedBox(width: 12),
                  Text(
                    text,
                    style: AppTypography.labelMedium.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
