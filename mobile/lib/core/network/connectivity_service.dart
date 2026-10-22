import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper so the rest of the app depends on a simple `bool`
/// (online/offline) instead of connectivity_plus's result-list API.
///
/// Note: this reports *network* reachability (Wi-Fi/mobile data present),
/// not actual internet/API reachability. Dio calls can still fail on a
/// technically-connected-but-captive network; the sync engine treats any
/// network-layer failure the same way it treats "offline" (retry later).
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Future<bool> get isOnline async {
    final results = await _connectivity.checkConnectivity();
    return _hasConnection(results);
  }

  Stream<bool> get onStatusChange =>
      _connectivity.onConnectivityChanged.map(_hasConnection);

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }
}
