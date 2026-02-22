// Offline banner widget displayed when offline or simulating offline mode.

import 'package:flutter/material.dart';
import 'package:tacit_node/theme/app_colors.dart';
import 'package:tacit_node/theme/app_typography.dart';

class OfflineBanner extends StatelessWidget {
  final bool isOnline;
  final bool isSimulatingOffline;
  final VoidCallback? onToggleOffline;

  const OfflineBanner({
    super.key,
    required this.isOnline,
    required this.isSimulatingOffline,
    this.onToggleOffline,
  });

  @override
  Widget build(BuildContext context) {
    if (isOnline && !isSimulatingOffline) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: isSimulatingOffline ? onToggleOffline : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.15),
          border: Border(
            bottom: BorderSide(
              color: AppColors.info.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.airplanemode_active,
              size: 16,
              color: AppColors.info,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isSimulatingOffline
                    ? '✈️ Offline Mode (Simulated) - Local inference only'
                    : '✈️ Offline Mode - Local inference only',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.info,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isSimulatingOffline) ...[
              const SizedBox(width: 8),
              Text(
                'Tap to disable',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.info.withValues(alpha: 0.7),
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.close,
                size: 14,
                color: AppColors.info.withValues(alpha: 0.7),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
