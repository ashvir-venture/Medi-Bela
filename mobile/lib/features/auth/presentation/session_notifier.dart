import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `null` = not yet determined (splash/loading), `true`/`false` once known.
///
/// Deliberately a leaf provider with no dependencies, so both
/// [DioClient] (when the server rejects the token) and [AuthController] (on
/// login/logout) can update it without creating a provider cycle, and
/// [GoRouter]'s redirect logic can watch it to decide where to send the
/// user.
class SessionNotifier extends StateNotifier<bool?> {
  SessionNotifier() : super(null);

  void setLoggedIn(bool value) => state = value;
}

final sessionNotifierProvider = StateNotifierProvider<SessionNotifier, bool?>(
  (ref) => SessionNotifier(),
);

/// True after the server rejected the session (401): Login says "Your
/// session ended. Please sign in again." until the next sign-in.
final sessionExpiredNoticeProvider = StateProvider<bool>((ref) => false);

/// True while the API answers 503 (maintenance): the app shows its
/// "being updated" screen over everything until Try again succeeds.
final maintenanceProvider = StateProvider<bool>((ref) => false);
