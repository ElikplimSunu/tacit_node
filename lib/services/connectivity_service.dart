// Connectivity service for monitoring network status and offline simulation.

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final StreamController<bool> _connectivityStream =
      StreamController<bool>.broadcast();

  Stream<bool> get connectivityStream => _connectivityStream.stream;

  bool _isOnline = true;
  bool _simulateOffline = false;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool get isOnline => _isOnline && !_simulateOffline;
  bool get isSimulatingOffline => _simulateOffline;

  // Initialize connectivity monitoring
  Future<void> initialize() async {
    // Check initial connectivity
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    _isOnline = !result.contains(ConnectivityResult.none);
    _connectivityStream.add(isOnline);

    // Listen to connectivity changes
    _subscription = connectivity.onConnectivityChanged.listen((results) {
      _isOnline = !results.contains(ConnectivityResult.none);
      _connectivityStream.add(isOnline);
    });
  }

  // Toggle offline simulation for demos
  void toggleOfflineSimulation() {
    _simulateOffline = !_simulateOffline;
    _connectivityStream.add(isOnline);
  }

  // Force offline mode
  void setOfflineMode(bool offline) {
    _simulateOffline = offline;
    _connectivityStream.add(isOnline);
  }

  // Check current connectivity status
  Future<bool> checkConnectivity() async {
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    _isOnline = !result.contains(ConnectivityResult.none);
    return isOnline;
  }

  // Dispose resources
  void dispose() {
    _subscription?.cancel();
    _connectivityStream.close();
  }
}
