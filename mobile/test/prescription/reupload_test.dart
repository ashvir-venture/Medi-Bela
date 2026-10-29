import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/database/app_database.dart';
import 'package:mobile/features/prescription/data/prescription_api.dart';
import 'package:mobile/features/prescription/data/prescription_local_repository.dart';
import 'package:mobile/features/prescription/data/prescription_sync_handler.dart';

/// Records what the sync handler would upload, without a network.
class _RecordingApi extends PrescriptionApi {
  _RecordingApi() : super(Dio());

  final uploads = <Map<String, String?>>[];

  @override
  Future<String> uploadDraft({
    required String clientId,
    String? note,
    String? imageLocalPath,
    String? previousPrescriptionId,
  }) async {
    uploads.add({'clientId': clientId, 'previousPrescriptionId': previousPrescriptionId});
    return 'server-$clientId';
  }
}

void main() {
  late AppDatabase db;
  late _RecordingApi api;
  late PrescriptionLocalRepository repo;
  late PrescriptionSyncHandler handler;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = _RecordingApi();
    repo = PrescriptionLocalRepository(database: db, api: api);
    handler = PrescriptionSyncHandler(api: api, database: db);
  });

  tearDown(() => db.close());

  test('a re-upload carries the rejected prescription id to the server', () async {
    await repo.createAndQueue(imageLocalPath: '/tmp/p.jpg', previousPrescriptionId: 'rejected-1');

    final entry = (await db.select(db.outboxEntries).get()).single;
    expect(jsonDecode(entry.payloadJson)['previousPrescriptionId'], 'rejected-1');

    await handler.sync(entry);
    expect(api.uploads.single['previousPrescriptionId'], 'rejected-1');
    final draft = (await db.select(db.prescriptionDrafts).get()).single;
    expect(draft.status, 'synced');
  });

  test('a normal upload sends no re-upload link', () async {
    await repo.createAndQueue(imageLocalPath: '/tmp/p.jpg');

    final entry = (await db.select(db.outboxEntries).get()).single;
    expect((jsonDecode(entry.payloadJson) as Map).containsKey('previousPrescriptionId'), isFalse);

    await handler.sync(entry);
    expect(api.uploads.single['previousPrescriptionId'], isNull);
  });
}
