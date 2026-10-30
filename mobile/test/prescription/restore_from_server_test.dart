import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/database/app_database.dart';
import 'package:mobile/features/prescription/data/prescription_api.dart';
import 'package:mobile/features/prescription/data/prescription_local_repository.dart';
import 'package:mobile/features/prescription/domain/prescription_models.dart';

/// Serves a fixed server history, without a network.
class _HistoryApi extends PrescriptionApi {
  _HistoryApi(this.history) : super(Dio());

  List<PrescriptionSummaryModel> history;

  @override
  Future<List<PrescriptionSummaryModel>> getHistory({String? forUserId}) async => history;
}

PrescriptionSummaryModel _server(String id, String status, {bool byCaregiver = false, String? reason}) =>
    PrescriptionSummaryModel(
      id: id,
      status: status,
      imageUrl: 'https://img.test/$id.jpg',
      rejectionReason: reason,
      createdAt: DateTime.utc(2026, 10, 30, 9),
      medicines: const [],
      uploadedByCaregiver: byCaregiver,
    );

void main() {
  late AppDatabase db;
  late _HistoryApi api;
  late PrescriptionLocalRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = _HistoryApi([
      _server('p-pending', 'PENDING'),
      _server('p-rejected', 'REJECTED', reason: 'Photo is blurry'),
      _server('p-caregiver', 'PENDING', byCaregiver: true),
    ]);
    repo = PrescriptionLocalRepository(database: db, api: api);
  });

  tearDown(() => db.close());

  test('after a reinstall, my own uploads come back from the server', () async {
    await repo.refreshStatuses();

    final drafts = await repo.getDrafts();
    expect(drafts.map((d) => d.serverId), unorderedEquals(['p-pending', 'p-rejected']));
    final rejected = drafts.firstWhere((d) => d.serverId == 'p-rejected');
    expect(rejected.status, 'synced');
    expect(rejected.serverStatus, 'REJECTED');
    expect(rejected.rejectionReason, 'Photo is blurry');
  });

  test('restoring twice adds nothing new; a later status change is applied', () async {
    await repo.refreshStatuses();
    api.history = [
      _server('p-pending', 'AWAITING_CONFIRMATION'),
      _server('p-rejected', 'REJECTED', reason: 'Photo is blurry'),
    ];
    await repo.refreshStatuses();

    final drafts = await repo.getDrafts();
    expect(drafts, hasLength(2));
    expect(drafts.firstWhere((d) => d.serverId == 'p-pending').serverStatus, 'AWAITING_CONFIRMATION');
  });

  test('nothing is added while an upload of mine is still on its way', () async {
    await repo.createAndQueue(imageLocalPath: '/tmp/p.jpg');

    await repo.refreshStatuses();

    // Only the queued draft: the server copy of it may already exist, and
    // adding it now would show the same prescription twice.
    expect(await repo.getDrafts(), hasLength(1));
  });
}
