// Session metrics model for tracking cumulative statistics.

import 'package:tacit_node/models/routing_decision.dart';

class SessionMetrics {
  int localQueries = 0;
  int cloudQueries = 0;
  int offlineQueries = 0;
  double totalLatencyMs = 0;
  double totalCloudCost = 0;
  List<RoutingDecision> queryHistory = [];

  // Pricing constants (Gemini 2.5 Flash)
  static const double costPerInputToken = 0.000000125; // $0.125 per 1M tokens
  static const double costPerOutputToken = 0.0000005; // $0.50 per 1M tokens
  static const double avgInputTokens = 100; // Estimated avg
  static const double avgOutputTokens = 150; // Estimated avg

  // Calculated properties
  double get averageLatency => (localQueries + cloudQueries) > 0
      ? totalLatencyMs / (localQueries + cloudQueries)
      : 0;

  double get estimatedCloudOnlyCost =>
      (localQueries + cloudQueries) *
      ((avgInputTokens * costPerInputToken) +
          (avgOutputTokens * costPerOutputToken));

  double get actualHybridCost => totalCloudCost;

  double get costSavings => estimatedCloudOnlyCost - actualHybridCost;

  int get totalQueries => localQueries + cloudQueries;

  // Reset all metrics
  void reset() {
    localQueries = 0;
    cloudQueries = 0;
    offlineQueries = 0;
    totalLatencyMs = 0;
    totalCloudCost = 0;
    queryHistory.clear();
  }

  // Record a decision
  void recordDecision(RoutingDecision decision) {
    queryHistory.add(decision);

    if (decision.action == ActionType.localInference) {
      localQueries++;
      if (decision.isOffline) {
        offlineQueries++;
      }
    } else {
      cloudQueries++;
      if (decision.estimatedCost != null) {
        totalCloudCost += decision.estimatedCost!;
      }
    }

    if (decision.latencyMs != null) {
      totalLatencyMs += decision.latencyMs!;
    }
  }
}
