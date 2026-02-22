// Data models for TacitNode routing decisions and console entries.

enum ActionType { localInference, cloudEscalation }

class RoutingDecision {
  final ActionType action;
  final double confidence;
  final DateTime timestamp;
  final Map<String, dynamic> rawJson;
  final String? toolName;
  final Map<String, dynamic>? toolArgs;

  RoutingDecision({
    required this.action,
    required this.confidence,
    required this.timestamp,
    required this.rawJson,
    this.toolName,
    this.toolArgs,
  });

  String get actionLabel => switch (action) {
    ActionType.localInference => '⚡ LOCAL INFERENCE',
    ActionType.cloudEscalation => '☁️ CLOUD ESCALATION',
  };
}

enum ConsoleSeverity { info, success, warning, error }

class ConsoleEntry {
  final DateTime timestamp;
  final String message;
  final ConsoleSeverity severity;
  final Map<String, dynamic>? metadata;

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
}
