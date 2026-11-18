import '../core/database/app_database.dart';

/// One [SyncHandler] per outbox `entityType`. [SyncService] looks up the
/// right handler for each pending row and delegates the actual network
/// call to it, keeping the generic drain/retry loop free of per-entity
/// logic.
abstract class SyncHandler {
  String get entityType;

  /// Performs the network call for [entry]. Should throw on failure (the
  /// exception message is stored for display); on success it should also
  /// update the owning local record (e.g. mark a draft `synced`) itself,
  /// since only the handler knows that record's shape.
  Future<void> sync(OutboxEntry entry);
}

/// Round 18 (owner 2026-11-17): a handler with its own retry rule. Photo
/// uploads try 3 times with a growing pause, then stop and tell the user
/// ("Upload failed, tap to retry") instead of the default 5 quick tries.
abstract class RetryPolicy {
  int get maxRetries;

  /// Wait this long after attempt [retryCount] before the next one.
  Duration backoff(int retryCount);

  /// Called once when the last try failed.
  Future<void> onGaveUp(OutboxEntry entry);
}
