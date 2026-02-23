// Metrics overlay widget for displaying session statistics.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:tacit_node/models/session_metrics.dart';
import 'package:tacit_node/theme/app_colors.dart';
import 'package:tacit_node/theme/app_typography.dart';

class MetricsOverlay extends StatelessWidget {
  final SessionMetrics metrics;
  final bool isVisible;
  final VoidCallback onClose;

  const MetricsOverlay({
    super.key,
    required this.metrics,
    required this.isVisible,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      top: isVisible ? 80 : -400,
      right: isVisible ? 16 : -300,
      child: _buildOverlayCard(),
    );
  }

  Widget _buildOverlayCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildQueryStats(),
              Divider(color: AppColors.textMuted.withOpacity(0.3)),
              _buildCostStats(),
              Divider(color: AppColors.textMuted.withOpacity(0.3)),
              _buildPerformanceStats(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.analytics, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          'SESSION METRICS',
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.primary,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.close, size: 18),
          color: AppColors.textMuted,
          onPressed: onClose,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildQueryStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatRow(
          icon: Icons.flash_on,
          label: 'Local Queries',
          value: '${metrics.localQueries}',
          color: AppColors.success,
        ),
        const SizedBox(height: 8),
        _buildStatRow(
          icon: Icons.cloud,
          label: 'Cloud Escalations',
          value: '${metrics.cloudQueries}',
          color: AppColors.warning,
        ),
        const SizedBox(height: 8),
        _buildStatRow(
          icon: Icons.airplanemode_active,
          label: 'Offline Queries',
          value: '${metrics.offlineQueries}',
          color: AppColors.info,
        ),
      ],
    );
  }

  Widget _buildCostStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatRow(
          icon: Icons.attach_money,
          label: 'Cloud-Only Cost',
          value: '\$${metrics.estimatedCloudOnlyCost.toStringAsFixed(5)}',
          color: AppColors.error,
        ),
        const SizedBox(height: 8),
        _buildStatRow(
          icon: Icons.savings,
          label: 'Hybrid Cost',
          value: '\$${metrics.actualHybridCost.toStringAsFixed(5)}',
          color: AppColors.success,
        ),
        const SizedBox(height: 8),
        _buildStatRow(
          icon: Icons.trending_down,
          label: 'Savings',
          value: '\$${metrics.costSavings.toStringAsFixed(5)}',
          color: AppColors.primary,
          highlight: true,
        ),
      ],
    );
  }

  Widget _buildPerformanceStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatRow(
          icon: Icons.speed,
          label: 'Avg Latency',
          value: '${metrics.averageLatency.toStringAsFixed(0)}ms',
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 8),
        _buildStatRow(
          icon: Icons.query_stats,
          label: 'Total Queries',
          value: '${metrics.totalQueries}',
          color: AppColors.textSecondary,
        ),
      ],
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool highlight = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: AppTypography.labelMedium.copyWith(
            color: color,
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
