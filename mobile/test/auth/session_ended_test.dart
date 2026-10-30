import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/database/app_database.dart';
import 'package:mobile/core/storage/secure_storage_service.dart';
import 'package:mobile/features/auth/data/device_session_wipe.dart';

void main() {
  test('only the session_ended push is recognized', () {
    expect(isSessionEndedMessage({'kind': 'session_ended'}), isTrue);
    expect(isSessionEndedMessage({'kind': 'backstop', 'type': 'MEDICINE_REMINDER'}), isFalse);
    expect(isSessionEndedMessage({'type': 'NOTICE'}), isFalse);
  });

  test('session ended: reminders cancelled, local database and tokens cleared, nothing left to sign in with', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final storage = SecureStorageService();
    await storage.saveTokens(accessToken: 'token');
    await storage.saveRegisteredPushToken('fcm');
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.into(db.cachedUsers).insert(CachedUsersCompanion.insert(
          id: 'u1',
          phone: '+8801712345678',
          name: 'Rahima',
          role: 'USER',
          cachedAt: DateTime(2026, 10, 30),
        ));
    var remindersCancelled = false;
    var noticesCleared = false;

    await wipeDeviceSession(
      cancelReminders: () async => remindersCancelled = true,
      storage: storage,
      database: db,
      clearNotices: () async => noticesCleared = true,
    );

    expect(remindersCancelled, isTrue);
    expect(noticesCleared, isTrue);
    expect(await storage.hasSession(), isFalse);
    expect(await storage.readRegisteredPushToken(), isNull);
    expect(await db.select(db.cachedUsers).get(), isEmpty);
    await db.close();
  });

  test('a failing step does not stop the others', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final storage = SecureStorageService();
    await storage.saveTokens(accessToken: 'token');
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    await wipeDeviceSession(
      cancelReminders: () async => throw StateError('plugin missing in this isolate'),
      storage: storage,
      database: db,
      clearNotices: () async {},
    );

    expect(await storage.hasSession(), isFalse);
    await db.close();
  });
}
