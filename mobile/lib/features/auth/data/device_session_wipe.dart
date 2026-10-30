import '../../../core/database/app_database.dart';
import '../../../core/storage/secure_storage_service.dart';

/// The server's data-only push sent when the account was deactivated,
/// deleted or banned (every device of the user gets it before its token is
/// dropped).
bool isSessionEndedMessage(Map<String, dynamic> data) => data['kind'] == 'session_ended';

/// Ends this phone's session after the account was paused or removed on the
/// server: no reminder may ring for it, and nothing of it stays on the phone.
/// Makes no server calls (the session is already gone there), so it works in
/// a background isolate with the app closed. Every step is best-effort; the
/// next app start finds no session and shows Login.
Future<void> wipeDeviceSession({
  required Future<void> Function() cancelReminders,
  required SecureStorageService storage,
  required AppDatabase database,
  required Future<void> Function() clearNotices,
}) async {
  Future<void> step(Future<void> Function() run) async {
    try {
      await run();
    } catch (_) {}
  }

  await step(cancelReminders);
  await step(storage.clearTokens);
  await step(storage.clearRegisteredPushToken);
  await step(database.clearAllUserData);
  await step(clearNotices);
}
