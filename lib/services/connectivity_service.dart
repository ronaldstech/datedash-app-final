import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  final Connectivity _connectivity = Connectivity();

  ConnectivityService._internal();

  factory ConnectivityService() {
    return _instance;
  }

  /// Stream of connectivity status
  Stream<bool> get isOnline {
    return _connectivity.onConnectivityChanged.map((results) {
      return !results.contains(ConnectivityResult.none);
    });
  }

  /// Check current connectivity status
  Future<bool> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  /// Listen to connectivity changes
  void startListening(Function(bool) onStatusChanged) {
    _connectivity.onConnectivityChanged.listen((results) {
      onStatusChanged(!results.contains(ConnectivityResult.none));
    });
  }
}
