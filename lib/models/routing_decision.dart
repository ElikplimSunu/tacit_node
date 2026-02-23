// Data models for TacitNode routing decisions and console entries.

import 'package:flutter/material.dart';
import 'package:tacit_node/theme/app_colors.dart';

enum ActionType { localInference, cloudEscalation }

class RoutingDecision {
  // Core fields (existing)
  final ActionType action;
  final double confidence;
  final DateTime timestamp;
  final Map<String, dynamic> rawJson;
  final String? toolName;
  final Map<String, dynamic>? toolArgs;

  // Performance metrics (new)
  final int? latencyMs;
  final double? tokensPerSecond;
  final double? estimatedCost;
  final int? ramUsageMb;
  final bool isOffline;
  final String routingPath;

  RoutingDecision({
    required this.action,
    required this.confidence,
    required this.timestamp,
    required this.rawJson,
    this.toolName,
    this.toolArgs,
    this.latencyMs,
    this.tokensPerSecond,
    this.estimatedCost,
    this.ramUsageMb,
    this.isOffline = false,
    this.routingPath = '',
  });

  String get actionLabel => switch (action) {
    ActionType.localInference => '⚡ LOCAL INFERENCE',
    ActionType.cloudEscalation => '☁️ CLOUD ESCALATION',
  };

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get formattedLatency => latencyMs != null ? '${latencyMs}ms' : 'N/A';

  String get formattedTps => tokensPerSecond != null
      ? '${tokensPerSecond!.toStringAsFixed(0)} tok/s'
      : 'N/A';

  String get formattedCost => estimatedCost != null
      ? '\$${estimatedCost!.toStringAsFixed(4)}'
      : '\$0.00';

  IconData get routingIcon =>
      action == ActionType.localInference ? Icons.flash_on : Icons.cloud;

  Color get routingColor => action == ActionType.localInference
      ? AppColors.success
      : AppColors.warning;
}

enum ConsoleSeverity { info, success, warning, error }

class ConsoleEntry {
  final DateTime timestamp;
  final String message;
  final ConsoleSeverity severity;
  final Map<String, dynamic>? metadata;

  // NEW: Expansion state for JSON viewer
  bool isExpanded = false;

  ConsoleEntry({
    required this.message,
    this.severity = ConsoleSeverity.info,
    this.metadata,
  }) : timestamp = DateTime.now();

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // NEW: Check if entry has JSON metadata
  bool get hasMetadata => metadata != null && metadata!.isNotEmpty;
}
