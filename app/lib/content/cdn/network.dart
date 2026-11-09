import 'package:connectivity_plus/connectivity_plus.dart';

/// True on Wi-Fi or Ethernet: where new stories may download without a tap, if the learner allowed
/// it. A failed check counts as metered.
Future<bool> onUnmeteredNetwork() async {
  try {
    final r = await Connectivity().checkConnectivity();
    return r.contains(ConnectivityResult.wifi) || r.contains(ConnectivityResult.ethernet);
  } catch (_) {
    return false;
  }
}
