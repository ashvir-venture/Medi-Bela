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
