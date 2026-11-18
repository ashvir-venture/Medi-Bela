import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/constants/app_config.dart';
import 'package:mobile/features/auth/data/app_lock.dart';

class _FakeBio implements BiometricAuth {
  bool available = true;
  bool answer = true;
  int asked = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) async {
    asked++;
    return answer;
  }
}

void main() {
  late _FakeBio bio;
  late DateTime now;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    bio = _FakeBio();
    now = DateTime(2026, 11, 18, 9);
  });

  Future<AppLockController> make() async {
    final c = AppLockController(bio, clock: () => now);
    await Future<void>.delayed(Duration.zero);
    return c;
  }

  test('off by default; turning it on asks for the fingerprint once', () async {
    final c = await make();
    expect(c.state.enabled, isFalse);
    expect(await c.setEnabled(true, 'r'), isTrue);
    expect(bio.asked, 1);
    expect(c.state.enabled, isTrue);
    expect(c.state.locked, isFalse);
    expect((await SharedPreferences.getInstance()).getBool(PrefsKeys.appLock), isTrue);
  });

  test('a failed fingerprint leaves it off (nobody locked out)', () async {
    bio.answer = false;
    final c = await make();
    expect(await c.setEnabled(true, 'r'), isFalse);
    expect(c.state.enabled, isFalse);
  });

  test('locks after 5 minutes away, not after a short switch', () async {
    final c = await make();
    await c.setEnabled(true, 'r');
    c.appPaused();
    now = now.add(const Duration(minutes: 4, seconds: 59));
    c.appResumed();
    expect(c.state.locked, isFalse);
    c.appPaused();
    now = now.add(appLockAfter);
    c.appResumed();
    expect(c.state.locked, isTrue);
    expect(await c.unlock('r'), isTrue);
    expect(c.state.locked, isFalse);
  });

  test('a cold start with the lock on starts locked', () async {
    SharedPreferences.setMockInitialValues({PrefsKeys.appLock: true});
    final c = await make();
    expect(c.state.locked, isTrue);
  });

  test('a ringing reminder page is never behind the lock', () {
    expect(lockSkipsRoute('/reminder'), isTrue);
    expect(lockSkipsRoute('/test-reminder/abc'), isTrue);
    expect(lockSkipsRoute('/medicine-box/empty'), isTrue);
    expect(lockSkipsRoute('/home'), isFalse);
    expect(lockSkipsRoute('/medicines'), isFalse);
  });
}
