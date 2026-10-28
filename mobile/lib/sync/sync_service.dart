import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../core/constants/app_config.dart';
import '../core/database/app_database.dart';
import '../core/network/connectivity_service.dart';
import 'outbox_constants.dart';
import 'sync_handler.dart';

/// Drains [OutboxEntries] whenever the device comes online, on a light
/// poll interval while online, and on demand (e.g. pull-to-refresh).
///
/// Deliberately simple for the MVP, per the product brief: one FIFO queue,
/// bounded retries per entry, no cross-entity dependency graph. Each
/// [SyncHandler] is responsible for its own entity type; this class only
/// owns the queue's lifecycle (pending → syncing → synced/failed).
class SyncService {
  SyncService({
    required AppDatabase database,
    required ConnectivityService connectivity,
    required List<SyncHandler> handlers,
    DateTime Function()? clock,
  })  : _db = database,
        _connectivity = connectivity,
        _handlersByType = {for (final h in handlers) h.entityType: h},
        _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final ConnectivityService _connectivity;
  final Map<String, SyncHandler> _handlersByType;
  final DateTime Function() _now;

  /// Set when the server answers 429 (rate limited): nothing is sent until
  /// then. Throttling is "try later", never a failure, so it must not use up
  /// an entry's retries — giving up would revert a dose marked taken.
  DateTime? _pausedUntil;

  StreamSubscription<bool>? _connectivitySub;
  Timer? _pollTimer;
  bool _isDraining = false;

  final _statusController = StreamController<bool>.broadcast();

  /// Emits `true` while a drain is in progress — drives a small "Syncing…"
  /// indicator in the UI.
  Stream<bool> get isSyncing => _statusController.stream;

  void start() {
    _connectivitySub = _connectivity.onStatusChange.listen((online) {
      if (online) unawaited(drainQueue());
    });
    _pollTimer = Timer.periodic(AppConfig.syncPollInterval, (_) async {
      if (await _connectivity.isOnline) unawaited(drainQueue());
    });
    unawaited(drainQueue());
  }

  void dispose() {
    _connectivitySub?.cancel();
    _pollTimer?.cancel();
    _statusController.close();
  }

  /// Moves any entries that permanently failed back into the queue for
  /// another attempt (e.g. user tapped "retry" after fixing their
  /// connection, or the backend endpoint has since shipped).
  Future<void> resetFailedEntries() async {
    await (_db.update(_db.outboxEntries)
          ..where((t) => t.status.equals(OutboxStatus.failed)))
        .write(
      const OutboxEntriesCompanion(
        status: Value(OutboxStatus.pending),
        retryCount: Value(0),
      ),
    );
  }

  Future<void> drainQueue() async {
    if (_isDraining) return;
    final pausedUntil = _pausedUntil;
    if (pausedUntil != null && _now().isBefore(pausedUntil)) return;
    if (!await _connectivity.isOnline) return;

    _isDraining = true;
    _statusController.add(true);
    try {
      // Only this method moves rows to `syncing`, and only one drain runs at a
      // time, so any `syncing` row seen here was orphaned (app killed or
      // crashed mid-request). Re-queue it; every handler is idempotent
      // (server-side idempotency keys), so re-sending is safe.
      await (_db.update(_db.outboxEntries)
            ..where((t) => t.status.equals(OutboxStatus.syncing)))
          .write(const OutboxEntriesCompanion(status: Value(OutboxStatus.pending)));

      final pending = await (_db.select(_db.outboxEntries)
            ..where((t) => t.status.equals(OutboxStatus.pending))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

      for (final entry in pending) {
        final throttled = await _processEntry(entry);
        if (throttled) break;
      }
    } finally {
      _isDraining = false;
      _statusController.add(false);
    }
  }

  /// Returns true when the server rate-limited the request, which stops
  /// the current drain.
  Future<bool> _processEntry(OutboxEntry entry) async {
    final handler = _handlersByType[entry.entityType];
    if (handler == null) {
      // No handler registered for this type — leave it for a future app
      // version that knows how to process it, rather than losing data.
      return false;
    }

    await _updateEntry(
      entry.id,
      OutboxEntriesCompanion(
        status: const Value(OutboxStatus.syncing),
        lastAttemptAt: Value(DateTime.now()),
      ),
    );

    try {
      await handler.sync(entry);
      await _updateEntry(
        entry.id,
        const OutboxEntriesCompanion(status: Value(OutboxStatus.synced)),
      );
    } catch (e) {
      final response = e is DioException ? e.response : null;
      if (response?.statusCode == 429) {
        _pausedUntil = _now().add(_retryAfter(response!));
        await _updateEntry(
          entry.id,
          const OutboxEntriesCompanion(status: Value(OutboxStatus.pending)),
        );
        return true;
      }
      final retryCount = entry.retryCount + 1;
      final gaveUp = retryCount >= AppConfig.maxOutboxRetries;
      if (gaveUp) await _releaseLocalPending(entry);
      await _updateEntry(
        entry.id,
        OutboxEntriesCompanion(
          status: Value(gaveUp ? OutboxStatus.failed : OutboxStatus.pending),
          retryCount: Value(retryCount),
          lastError: Value(e.toString()),
        ),
      );
    }
    return false;
  }

  /// The server's Retry-After (seconds), bounded so a bad value can neither
  /// hammer the server nor stall syncing for long.
  Duration _retryAfter(Response<dynamic> response) {
    final seconds = int.tryParse(response.headers.value('retry-after') ?? '') ?? 60;
    return Duration(seconds: seconds.clamp(5, 600));
  }

  /// When an entry permanently fails, the local row it touched must stop
  /// claiming "pending": a pending row is protected from server refreshes, so
  /// it would otherwise stay wrong forever. Marking it `synced` lets the next
  /// refresh restore the server's (authoritative) state.
  Future<void> _releaseLocalPending(OutboxEntry entry) async {
    switch (entry.entityType) {
      case OutboxEntityType.doseTaken:
        await (_db.update(_db.cachedMedicineDoses)
              ..where((t) => t.id.equals(entry.entityLocalId)))
            .write(const CachedMedicineDosesCompanion(syncState: Value('synced')));
        break;
      case OutboxEntityType.healthReminderComplete:
        await (_db.update(_db.cachedHealthReminders)
              ..where((t) => t.id.equals(entry.entityLocalId)))
            .write(const CachedHealthRemindersCompanion(syncState: Value('synced')));
        break;
      default:
        break; // drafts keep their own failed/retry UI
    }
  }

  Future<void> _updateEntry(String id, OutboxEntriesCompanion patch) {
    return (_db.update(_db.outboxEntries)..where((t) => t.id.equals(id)))
        .write(patch);
  }
}
