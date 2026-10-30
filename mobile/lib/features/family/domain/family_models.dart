class FamilyMemberModel {
  const FamilyMemberModel({
    required this.familyMemberId,
    required this.userId,
    required this.name,
    required this.phone,
    required this.role,
    this.address,
    required this.joinedAt,
    this.paused = false,
  });

  final String familyMemberId;
  final String userId;
  final String name;
  final String phone;
  final String role; // CAREGIVER | MEMBER
  final String? address;
  final DateTime joinedAt;

  /// Deactivated or banned: the family sees "Account paused". From the
  /// server only (the offline cache doesn't keep it).
  final bool paused;

  /// Parses the shape returned by `GET /family/members`
  /// (`{ familyMemberId, role, joinedAt, user: { id, name, phone, address } }`).
  factory FamilyMemberModel.fromMembersListJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return FamilyMemberModel(
      familyMemberId: json['familyMemberId'] as String,
      userId: user['id'] as String,
      name: user['name'] as String,
      phone: user['phone'] as String,
      role: json['role'] as String,
      address: user['address'] as String?,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
      paused: user['paused'] as bool? ?? false,
    );
  }

  /// Parses the nested member shape returned inside `GET /family`
  /// (`{ id, role, joinedAt, user: {...} }`).
  factory FamilyMemberModel.fromFamilyJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return FamilyMemberModel(
      familyMemberId: json['id'] as String,
      userId: user['id'] as String,
      name: user['name'] as String,
      phone: user['phone'] as String,
      role: json['role'] as String,
      address: user['address'] as String?,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
    );
  }
}

class FamilyModel {
  const FamilyModel({
    required this.id,
    this.name,
    required this.members,
  });

  final String id;
  final String? name;
  final List<FamilyMemberModel> members;

  factory FamilyModel.fromJson(Map<String, dynamic> json) {
    final membersJson = json['members'] as List<dynamic>? ?? [];
    return FamilyModel(
      id: json['id'] as String,
      name: json['name'] as String?,
      members: membersJson
          .map(
            (m) => FamilyMemberModel.fromFamilyJson(m as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class FamilyInvitationModel {
  const FamilyInvitationModel({
    required this.id,
    required this.familyId,
    required this.invitedPhone,
    required this.status,
    this.familyName,
    this.invitedByName,
    required this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String familyId;
  final String invitedPhone;
  final String status; // PENDING | ACCEPTED | DECLINED | EXPIRED
  final String? familyName;
  final String? invitedByName;
  final DateTime createdAt;
  final DateTime? expiresAt;

  /// Incoming invitations (`GET /family/invitations?type=incoming`) include
  /// nested `family` and `invitedBy`; sent invitations
  /// (`type=sent`) are flat rows without them.
  factory FamilyInvitationModel.fromJson(Map<String, dynamic> json) {
    final family = json['family'] as Map<String, dynamic>?;
    final invitedBy = json['invitedBy'] as Map<String, dynamic>?;
    return FamilyInvitationModel(
      id: json['id'] as String,
      familyId: json['familyId'] as String,
      invitedPhone: json['invitedPhone'] as String,
      status: json['status'] as String,
      familyName: family?['name'] as String?,
      invitedByName: invitedBy?['name'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
    );
  }
}

/// Today's dose counts for one OTHER family member (`GET /family/members/status`).
/// When the member has stopped sharing, [shared] is false and no counts exist.
class MemberStatusSummary {
  const MemberStatusSummary({
    required this.userId,
    required this.name,
    required this.shared,
    this.paused = false,
    this.total = 0,
    this.taken = 0,
    this.missed = 0,
    this.pending = 0,
  });

  final String userId;
  final String name;
  final bool shared;
  /// Deactivated or banned: no medicine data, "Account paused".
  final bool paused;
  final int total;
  final int taken;
  final int missed;
  final int pending;

  factory MemberStatusSummary.fromJson(Map<String, dynamic> json) {
    final today = json['today'] as Map<String, dynamic>?;
    return MemberStatusSummary(
      userId: json['userId'] as String,
      name: json['name'] as String,
      shared: json['shared'] as bool? ?? false,
      paused: json['paused'] as bool? ?? false,
      total: today?['total'] as int? ?? 0,
      taken: today?['taken'] as int? ?? 0,
      missed: today?['missed'] as int? ?? 0,
      pending: today?['pending'] as int? ?? 0,
    );
  }
}

/// One dose in a member's detail view. Deliberately only name, time and
/// status — the backend never sends dosage or instructions to family members.
class MemberDoseStatus {
  const MemberDoseStatus({
    required this.medicineName,
    required this.scheduledAt,
    required this.status,
    this.takenAt,
  });

  final String medicineName;
  final DateTime scheduledAt;
  final String status; // TAKEN | MISSED | PENDING | SKIPPED
  final DateTime? takenAt;

  factory MemberDoseStatus.fromJson(Map<String, dynamic> json) {
    return MemberDoseStatus(
      medicineName: json['medicineName'] as String,
      scheduledAt: DateTime.parse(json['scheduledAt'] as String).toLocal(),
      status: json['status'] as String,
      takenAt: json['takenAt'] == null
          ? null
          : DateTime.parse(json['takenAt'] as String).toLocal(),
    );
  }
}

class MemberStatusDetail {
  const MemberStatusDetail({
    required this.userId,
    required this.name,
    required this.shared,
    required this.doses,
    this.paused = false,
  });

  final String userId;
  final String name;
  final bool shared;
  final List<MemberDoseStatus> doses;
  final bool paused;

  factory MemberStatusDetail.fromJson(Map<String, dynamic> json) {
    final member = json['member'] as Map<String, dynamic>;
    return MemberStatusDetail(
      userId: member['userId'] as String,
      name: member['name'] as String,
      shared: json['shared'] as bool? ?? false,
      paused: member['paused'] as bool? ?? false,
      doses: (json['doses'] as List<dynamic>? ?? [])
          .map((d) => MemberDoseStatus.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A person in the activity feed: their current name, or a deleted account.
class FamilyEventPerson {
  const FamilyEventPerson({required this.id, required this.name, required this.deleted});

  final String id;
  final String name;
  final bool deleted;

  static FamilyEventPerson? fromJson(Map<String, dynamic>? json) => json == null
      ? null
      : FamilyEventPerson(
          id: json['id'] as String,
          name: json['name'] as String,
          deleted: json['deleted'] as bool? ?? false,
        );
}

/// One line of the family's activity feed (`GET /family/events`).
class FamilyEvent {
  const FamilyEvent({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.subject,
    this.actor,
  });

  final String id;
  final String kind; // CREATED | JOINED | LEFT | REMOVED | CAREGIVER_CHANGED
  final DateTime createdAt;
  final FamilyEventPerson? subject;
  final FamilyEventPerson? actor;

  factory FamilyEvent.fromJson(Map<String, dynamic> json) {
    return FamilyEvent(
      id: json['id'] as String,
      kind: json['kind'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      subject: FamilyEventPerson.fromJson(json['subject'] as Map<String, dynamic>?),
      actor: FamilyEventPerson.fromJson(json['actor'] as Map<String, dynamic>?),
    );
  }
}

/// One page of the feed, newest first; [nextCursor] is null on the last page.
class FamilyEventsPage {
  const FamilyEventsPage({required this.items, this.nextCursor});

  final List<FamilyEvent> items;
  final String? nextCursor;
}
