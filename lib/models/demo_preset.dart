// Demo preset model for quick-access demo scenarios.

import 'package:flutter/material.dart';
import 'package:tacit_node/theme/app_colors.dart';

class DemoPreset {
  final String label;
  final String query;
  final IconData icon;
  final Color color;
  final bool simulateOffline;
  final String description;

  const DemoPreset({
    required this.label,
    required this.query,
    required this.icon,
    required this.color,
    this.simulateOffline = false,
    this.description = '',
  });

  // Predefined presets
  static const List<DemoPreset> defaults = [
    DemoPreset(
      label: 'Quick ID',
      query: 'What is this?',
      icon: Icons.flash_on,
      color: AppColors.success,
      description: 'Instant local identification',
    ),
    DemoPreset(
      label: 'Diagnose',
      query: 'Why is this circuit failing?',
      icon: Icons.cloud,
      color: AppColors.warning,
      description: 'Complex cloud diagnosis',
    ),
    DemoPreset(
      label: 'Offline Test',
      query: 'What do you see?',
      icon: Icons.airplanemode_active,
      color: AppColors.info,
      simulateOffline: true,
      description: 'Test offline capability',
    ),
  ];
}
