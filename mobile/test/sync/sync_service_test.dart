import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/constants/app_config.dart';
import 'package:mobile/core/database/app_database.dart';
import 'package:mobile/core/network/connectivity_service.dart';
import 'package:mobile/sync/outbox_constants.dart';
import 'package:mobile/sync/sync_handler.dart';
import 'package:mobile/sync/sync_service.dart';

class _OnlineConnectivity implements ConnectivityService {
  @override
  Future<bool> get isOnline async => true;

  @override
  Stream<bool> get onStatusChange => const Stream.empty();
}

/// Fails with whatever [nextError] holds, or succeeds when it's null.
class _FakeHandler implements SyncHandler {
  Object? nextError;
  int calls = 0;

  @override
  String get entityType => OutboxEntityType.doseTaken;

  @override
  Future<void> sync(OutboxEntry entry) async {
    calls++;
    if (nextError != null) throw nextError!;
  }
}

DioException _status(int code, {String? retryAfter}) {
  final options = RequestOptions(path: '/medicine-schedule/doses/d1/taken');
  return DioException(
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: code,
      headers: Headers.fromMap({
        if (retryAfter != null) 'retry-after': [retryAfter],
      }),
    ),
    type: DioExceptionType.badResponse,
  );
}

void main() {
  late AppDatabase db;
  late _FakeHandler handler;
  late SyncService sync;
  late DateTime now;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    handler = _FakeHandler();
    now = DateTime(2026, 10, 28, 8);
    sync = SyncService(
      database: db,
      connectivity: _OnlineConnectivity(),
      handlers: [handler],
      clock: () => now,
    );
    // A dose the user marked taken offline, waiting in the outbox.
    await db.into(db.cachedMedicineDoses).insert(
          CachedMedicineDosesCompanion.insert(
            id: 'd1',
            routineId: 'r1',
            medicineName: 'Napa',
            dosage: '1 tablet',
            scheduledAt: now,
            doseStatus: 'TAKEN',
            syncState: const Value('pending'),
            cachedAt: now,
          ),
        );
    await db.into(db.outboxEntries).insert(
          OutboxEntriesCompanion.insert(
            id: 'o1',
            entityType: OutboxEntityType.doseTaken,
            entityLocalId: 'd1',
            operation: OutboxOperation.create,
            payloadJson: '{}',
            createdAt: now,
          ),
        );
  });

  tearDown(() => db.close());

  Future<OutboxEntry> outbox() => db.select(db.outboxEntries).getSingle();
  Future<CachedMedicineDose> dose() => db.select(db.cachedMedicineDoses).getSingle();

  test('429 keeps the entry pending without using a retry', () async {
    handler.nextError = _status(429, retryAfter: '30');

    await sync.drainQueue();

    final entry = await outbox();
    expect(entry.status, OutboxStatus.pending);
    expect(entry.retryCount, 0);
  });

  test('pauses for Retry-After, then resumes', () async {
    handler.nextError = _status(429, retryAfter: '30');
    await sync.drainQueue();
    expect(handler.calls, 1);

    now = now.add(const Duration(seconds: 29));
    await sync.drainQueue();
    expect(handler.calls, 1, reason: 'still paused');

    handler.nextError = null;
    now = now.add(const Duration(seconds: 2));
    await sync.drainQueue();
    expect(handler.calls, 2);
    expect((await outbox()).status, OutboxStatus.synced);
  });

  test('repeated throttling never reverts a dose marked taken', () async {
    handler.nextError = _status(429);
    for (var i = 0; i < AppConfig.maxOutboxRetries + 3; i++) {
      await sync.drainQueue();
      now = now.add(const Duration(minutes: 10));
    }

    expect((await outbox()).status, OutboxStatus.pending);
    expect((await dose()).syncState, 'pending');
  });

  test('other errors still count toward giving up', () async {
    handler.nextError = _status(500);
    for (var i = 0; i < AppConfig.maxOutboxRetries; i++) {
      await sync.drainQueue();
    }

    expect((await outbox()).status, OutboxStatus.failed);
    expect((await dose()).syncState, 'synced');
  });
}
