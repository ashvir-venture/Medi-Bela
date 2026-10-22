import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/result.dart';
import '../../../providers/core_providers.dart';
import '../data/family_repository.dart';
import '../domain/family_models.dart';

/// Local-first: starts from whatever is cached in Drift, then reconciles
/// with the server. Screens should render `state.value` immediately
/// (never wait for `state.isLoading`) so cached data shows instantly.
class FamilyMembersController
    extends StateNotifier<AsyncValue<List<FamilyMemberModel>>> {
  FamilyMembersController(this._repository)
      : super(const AsyncValue.loading()) {
    _bootstrap();
  }

  final FamilyRepository _repository;

  Future<void> _bootstrap() async {
    final cached = await _repository.getCachedMembers();
    state = AsyncValue.data(cached);
    await refresh();
  }

  Future<void> refresh() async {
    final result = await _repository.refreshFromServer();
    result.when(
      success: (members) => state = AsyncValue.data(members),
      failure: (message) {
        // Keep showing cached data; only surface an error if we have
        // nothing cached at all to show instead.
        if (state.value == null || state.value!.isEmpty) {
          state = AsyncValue.error(message, StackTrace.current);
        }
      },
    );
  }

  Future<Result<FamilyModel>> createFamily({String? name}) async {
    final result = await _repository.createFamily(name: name);
    if (result.isSuccess) await refresh();
    return result;
  }

  Future<Result<void>> inviteMember(String phone) {
    return _repository.inviteMember(phone);
  }

  Future<Result<void>> acceptInvitation(String invitationId) async {
    final result = await _repository.acceptInvitation(invitationId);
    if (result.isSuccess) await refresh();
    return result;
  }

  Future<Result<void>> declineInvitation(String invitationId) {
    return _repository.declineInvitation(invitationId);
  }
}

// autoDispose: leaving the family screen (or logging out, which redirects away
// from it) discards the in-memory state, so one account's family is never
// shown to the next account on the same device.
final familyMembersControllerProvider = StateNotifierProvider.autoDispose<
    FamilyMembersController, AsyncValue<List<FamilyMemberModel>>>((ref) {
  return FamilyMembersController(ref.watch(familyRepositoryProvider));
});

/// Incoming pending invitations — always fetched live (there's no
/// meaningful offline view of "invitations addressed to me").
class FamilyInvitationsController
    extends StateNotifier<AsyncValue<List<FamilyInvitationModel>>> {
  FamilyInvitationsController(this._repository)
      : super(const AsyncValue.loading()) {
    load();
  }

  final FamilyRepository _repository;

  Future<void> load() async {
    state = const AsyncValue.loading();
    final result = await _repository.listIncomingInvitations();
    state = result.when(
      success: (invitations) => AsyncValue.data(invitations),
      failure: (message) => AsyncValue.error(message, StackTrace.current),
    );
  }
}

final familyInvitationsControllerProvider = StateNotifierProvider.autoDispose<
    FamilyInvitationsController, AsyncValue<List<FamilyInvitationModel>>>((ref) {
  return FamilyInvitationsController(ref.watch(familyRepositoryProvider));
});

/// Today's counts per other family member, keyed by user id.
final familyStatusSummaryProvider =
    FutureProvider.autoDispose<Map<String, MemberStatusSummary>>((ref) async {
  final result = await ref.watch(familyRepositoryProvider).getMembersStatus();
  return result.when(
    success: (summary) => summary,
    failure: (message) => throw message,
  );
});

/// One member's dose detail for today.
final memberStatusProvider = FutureProvider.autoDispose
    .family<MemberStatusDetail, String>((ref, userId) async {
  final result =
      await ref.watch(familyRepositoryProvider).getMemberStatus(userId);
  return result.when(
    success: (detail) => detail,
    failure: (message) => throw message,
  );
});
