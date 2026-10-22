import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../core/utils/result.dart';
import 'family_api.dart';
import '../domain/family_models.dart';

/// Family membership itself only ever changes through a direct,
/// online API call (create / invite / accept / decline) — there's no
/// meaningful offline version of "join a family", so unlike prescription
/// drafts these are NOT queued in the outbox; they simply fail with a
/// friendly message if there's no connection, and the caller can retry.
///
/// Reads, however, follow the same local-first rule as everything else:
/// [watchCachedMembers] / [getCachedMembers] serve instantly from Drift
/// while [refreshFromServer] updates that cache in the background.
class FamilyRepository {
  FamilyRepository({required FamilyApi api, required AppDatabase database})
      : _api = api,
        _db = database;

  final FamilyApi _api;
  final AppDatabase _db;

  Future<List<FamilyMemberModel>> getCachedMembers() async {
    final rows = await _db.select(_db.cachedFamilyMembers).get();
    return rows.map(_rowToModel).toList();
  }

  Stream<List<FamilyMemberModel>> watchCachedMembers() {
    return _db
        .select(_db.cachedFamilyMembers)
        .watch()
        .map((rows) => rows.map(_rowToModel).toList());
  }

  /// Pulls the latest family + members from the server and overwrites the
  /// local cache. Treats "no family yet" (404 from the backend) as a valid
  /// empty state rather than an error.
  Future<Result<List<FamilyMemberModel>>> refreshFromServer() async {
    try {
      final members = await _api.listMembers();
      await _replaceCache(members);
      return Result.success(members);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        await _replaceCache(const []);
        return const Result.success([]);
      }
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  Future<Result<FamilyModel>> createFamily({String? name}) async {
    try {
      final family = await _api.createFamily(name: name);
      await _replaceCache(family.members);
      return Result.success(family);
    } on DioException catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  Future<Result<void>> inviteMember(String phone) async {
    try {
      await _api.inviteMember(phone);
      return const Result.success(null);
    } on DioException catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  Future<Result<List<FamilyInvitationModel>>> listIncomingInvitations() async {
    try {
      final invitations = await _api.listIncomingInvitations();
      return Result.success(invitations);
    } on DioException catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  Future<Result<void>> acceptInvitation(String invitationId) async {
    try {
      await _api.acceptInvitation(invitationId);
      await refreshFromServer();
      return const Result.success(null);
    } on DioException catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  Future<Result<void>> declineInvitation(String invitationId) async {
    try {
      await _api.declineInvitation(invitationId);
      return const Result.success(null);
    } on DioException catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  /// Other members' medicine status is health data about someone else, so it is
  /// fetched live and deliberately NOT written to the local database: no stale
  /// copy of it lingers on the device, and it can't outlive a membership change.
  Future<Result<Map<String, MemberStatusSummary>>> getMembersStatus() async {
    try {
      return Result.success(await _api.getMembersStatus());
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const Result.success({});
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  Future<Result<MemberStatusDetail>> getMemberStatus(String userId) async {
    try {
      return Result.success(await _api.getMemberStatus(userId));
    } on DioException catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  Future<void> _replaceCache(List<FamilyMemberModel> members) async {
    await _db.transaction(() async {
      await _db.delete(_db.cachedFamilyMembers).go();
      final now = DateTime.now();
      for (final m in members) {
        await _db.into(_db.cachedFamilyMembers).insert(
              CachedFamilyMembersCompanion.insert(
                familyMemberId: m.familyMemberId,
                familyId: '', // not needed for display; kept for future use
                userId: m.userId,
                name: m.name,
                phone: m.phone,
                role: m.role,
                address: Value(m.address),
                joinedAt: m.joinedAt,
                cachedAt: now,
              ),
            );
      }
    });
  }

  FamilyMemberModel _rowToModel(CachedFamilyMember row) {
    return FamilyMemberModel(
      familyMemberId: row.familyMemberId,
      userId: row.userId,
      name: row.name,
      phone: row.phone,
      role: row.role,
      address: row.address,
      joinedAt: row.joinedAt,
    );
  }
}
