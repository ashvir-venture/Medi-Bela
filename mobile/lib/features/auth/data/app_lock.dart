import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_config.dart';

/// Round 18 (client note point 10, owner 2026-11-17): unlock with
/// fingerprint. The app stays signed in (its refresh token in secure
/// storage); with the lock on, opening the app, or coming back after 5+
/// minutes away, asks for the fingerprint (or the phone's screen lock)
/// before anything shows. Off until the user turns it on (Settings). Offered
/// on Android 9+ only, where the system draws the prompt.
abstract class BiometricAuth {
  Future<bool> isAvailable();
  Future<bool> authenticate(String reason);
}

class LocalBiometricAuth implements BiometricAuth {
  LocalBiometricAuth({LocalAuthentication? auth}) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;
  static const _channel = MethodChannel('com.carebridge.app/reminder_status');

  @override
  Future<bool> isAvailable() async {
    try {
      final sdk = await _channel.invokeMethod<int>('sdkInt') ?? 0;
      if (sdk < 28) return false;
      if (!await _auth.isDeviceSupported()) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      // Not biometric-only: the phone's PIN / pattern works too (a cut finger).
      return await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
    } catch (_) {
      return false;
    }
  }
}

/// How long the app may be away before it asks again.
const appLockAfter = Duration(minutes: 5);

/// Routes a ringing reminder opens: never behind the lock, so Taken / Later
/// work on a locked app as they do with the app closed.
bool lockSkipsRoute(String path) =>
    path.startsWith('/reminder') || path.startsWith('/test-reminder') || path.startsWith('/medicine-box/empty');

/// Whether the lock is on (this phone only) and whether the app is locked now.
class AppLockState {
  const AppLockState({required this.enabled, required this.locked});

  final bool enabled;
  final bool locked;

  AppLockState copyWith({bool? enabled, bool? locked}) => AppLockState(enabled: enabled ?? this.enabled, locked: locked ?? this.locked);
}

class AppLockController extends StateNotifier<AppLockState> {
  AppLockController(this._auth, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now,
        super(const AppLockState(enabled: false, locked: false)) {
    _restore();
  }

  final BiometricAuth _auth;
  final DateTime Function() _now;
  DateTime? _leftAt;

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final on = prefs.getBool(PrefsKeys.appLock) ?? false;
    // A cold start with the lock on starts locked.
    state = AppLockState(enabled: on, locked: on);
  }

  Future<bool> isAvailable() => _auth.isAvailable();

  /// Turning it on asks once, so a phone without a working fingerprint
  /// can't lock its owner out.
  Future<bool> setEnabled(bool on, String reason) async {
    if (on && !await _auth.authenticate(reason)) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefsKeys.appLock, on);
    state = AppLockState(enabled: on, locked: false);
    return true;
  }

  void appPaused() => _leftAt = _now();

  void appResumed() {
    final left = _leftAt;
    _leftAt = null;
    if (state.enabled && left != null && _now().difference(left) >= appLockAfter) {
      state = state.copyWith(locked: true);
    }
  }

  Future<bool> unlock(String reason) async {
    final ok = await _auth.authenticate(reason);
    if (ok) state = state.copyWith(locked: false);
    return ok;
  }

  /// Signed out (or "Sign in with password" on the lock): nothing to guard.
  void reset() => state = state.copyWith(locked: false);
}

final biometricAuthProvider = Provider<BiometricAuth>((ref) => LocalBiometricAuth());

final appLockControllerProvider = StateNotifierProvider<AppLockController, AppLockState>(
  (ref) => AppLockController(ref.watch(biometricAuthProvider)),
);
