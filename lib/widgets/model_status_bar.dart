import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Top status bar showing model loading state and connection mode.
class ModelStatusBar extends StatelessWidget {
  final String status;
  final double downloadProgress;
  final bool isModelReady;

  const ModelStatusBar({
    super.key,
    required this.status,
    required this.downloadProgress,
    required this.isModelReady,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.6), // Glassmorphism
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                // Logo / Title
                Text(
                  'TACIT',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                ),
                Text(
                  'NODE',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(width: 12),
                // Status chip
                Expanded(child: _buildStatusChip()),
                // Connection indicator
                _buildConnectionDot(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    Color chipColor;
    IconData chipIcon;

    if (isModelReady) {
      chipColor = AppColors.success;
      chipIcon = Icons.check_circle_outline;
    } else if (status.contains('Error')) {
      chipColor = AppColors.error;
      chipIcon = Icons.error_outline;
    } else {
      chipColor = AppColors.primary;
      chipIcon = Icons.hourglass_top;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isModelReady && !status.contains('Error'))
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                value: downloadProgress > 0 ? downloadProgress : null,
                strokeWidth: 1.5,
                color: chipColor,
              ),
            )
          else
            Icon(chipIcon, size: 14, color: chipColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              status,
              style: AppTypography.labelSmall.copyWith(
                color: chipColor,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionDot() {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isModelReady ? AppColors.success : AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: (isModelReady ? AppColors.success : AppColors.primary)
                      .withValues(alpha: 0.6),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isModelReady ? 'EDGE' : 'INIT',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
