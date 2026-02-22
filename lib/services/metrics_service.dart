// Metrics service for tracking session-wide statistics.

import 'dart:async';
import 'package:tacit_node/models/routing_decision.dart';
import 'package:tacit_node/models/session_metrics.dart';

class MetricsService {
  final StreamController<SessionMetrics> _metricsStream =
      StreamController<SessionMetrics>.broadcast();

  Stream<SessionMetrics> get metricsStream => _metricsStream.stream;

  final SessionMetrics _currentMetrics = SessionMetrics();
  SessionMetrics get currentMetrics => _currentMetrics;

  // Record a routing decision
  void recordDecision(RoutingDecision decision) {
    _currentMetrics.recordDecision(decision);
    _metricsStream.add(_currentMetrics);
  }

  // Reset all metrics (for demo reset)
  void reset() {
    _currentMetrics.reset();
    _metricsStream.add(_currentMetrics);
  }

  // Calculate cost for a cloud query
  double calculateCloudCost({
    required int inputTokens,
    required int outputTokens,
  }) {
    return (inputTokens * SessionMetrics.costPerInputToken) +
        (outputTokens * SessionMetrics.costPerOutputToken);
  }

  // Get metrics summary for display
  Map<String, dynamic> getSummary() {
    return {
      'localQueries': _currentMetrics.localQueries,
      'cloudQueries': _currentMetrics.cloudQueries,
      'offlineQueries': _currentMetrics.offlineQueries,
      'totalQueries': _currentMetrics.totalQueries,
      'averageLatency': _currentMetrics.averageLatency,
      'estimatedCloudOnlyCost': _currentMetrics.estimatedCloudOnlyCost,
      'actualHybridCost': _currentMetrics.actualHybridCost,
      'costSavings': _currentMetrics.costSavings,
    };
  }

  // Dispose resources
  void dispose() {
    _metricsStream.close();
  }
}
