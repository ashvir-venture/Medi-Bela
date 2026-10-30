import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../domain/family_models.dart';

class FamilyApi {
  FamilyApi(this._dio);

  final Dio _dio;

  Future<FamilyModel> createFamily({String? name}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.family,
      data: {if (name != null && name.isNotEmpty) 'name': name},
    );
    return FamilyModel.fromJson(response.data!);
  }

  Future<FamilyModel> getMyFamily() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.family,
    );
    return FamilyModel.fromJson(response.data!);
  }

  Future<List<FamilyMemberModel>> listMembers() async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.familyMembers,
    );
    return response.data!
        .map(
          (m) => FamilyMemberModel.fromMembersListJson(
            m as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> inviteMember(String phone) async {
    await _dio.post(
      ApiEndpoints.familyInvitations,
      data: {'phone': phone},
    );
  }

  Future<List<FamilyInvitationModel>> listIncomingInvitations() async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.familyInvitations,
      queryParameters: {'type': 'incoming'},
    );
    return response.data!
        .map(
          (i) => FamilyInvitationModel.fromJson(i as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> acceptInvitation(String invitationId) async {
    await _dio.post(ApiEndpoints.acceptInvitation(invitationId));
  }

  Future<void> declineInvitation(String invitationId) async {
    await _dio.post(ApiEndpoints.declineInvitation(invitationId));
  }

  Future<void> leave() async {
    await _dio.post(ApiEndpoints.familyLeave);
  }

  /// Caregiver only.
  Future<void> removeMember(String userId) async {
    await _dio.delete(ApiEndpoints.familyMember(userId));
  }

  Future<FamilyEventsPage> listEvents({String? cursor}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.familyEvents,
      queryParameters: {if (cursor != null) 'cursor': cursor},
    );
    final data = response.data!;
    return FamilyEventsPage(
      items: (data['items'] as List<dynamic>? ?? [])
          .map((e) => FamilyEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: data['nextCursor'] as String?,
    );
  }

  Future<Map<String, MemberStatusSummary>> getMembersStatus() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.familyMembersStatus,
    );
    final members = response.data!['members'] as List<dynamic>? ?? [];
    return {
      for (final m in members)
        (m as Map<String, dynamic>)['userId'] as String:
            MemberStatusSummary.fromJson(m),
    };
  }

  Future<MemberStatusDetail> getMemberStatus(String userId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.familyMemberStatus(userId),
    );
    return MemberStatusDetail.fromJson(response.data!);
  }
}
