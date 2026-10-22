/// Mirrors the Phase 1 NestJS route list exactly (all relative to
/// [AppConfig.apiBaseUrl], which already includes `/api/v1`).
class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String changePassword = '/auth/change-password';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // Users
  static const String me = '/users/me';

  // Family
  static const String family = '/family';
  static const String familyMembers = '/family/members';
  static const String familyInvitations = '/family/invitations';
  static String acceptInvitation(String id) =>
      '/family/invitations/$id/accept';
  static String declineInvitation(String id) =>
      '/family/invitations/$id/decline';
  static const String familyMembersStatus = '/family/members/status';
  static String familyMemberStatus(String userId) =>
      '/family/members/$userId/status';

  // Notifications (Phase 4A)
  static const String notifications = '/notifications';
  static const String notificationsReadAll = '/notifications/read-all';
  static String notificationRead(String id) => '/notifications/$id/read';
  static const String registerDevice = '/notifications/devices';
  static const String unregisterDevice = '/notifications/devices/unregister';

  // Prescription (Phase 3A)
  static const String prescriptions = '/prescriptions';
  static const String prescriptionHistory = '/prescriptions/mine';
  static String prescriptionDetail(String id) => '/prescriptions/$id';

  // Medicine schedule (Phase 3A/3B) — synchronized routines/doses
  // generated once a prescription is COMPLETED.
  static const String medicineRoutines = '/medicine-schedule/routines';
  static const String medicineToday = '/medicine-schedule/today';
  static const String medicineUpcoming = '/medicine-schedule/upcoming';
  static String doseDetail(String id) => '/medicine-schedule/doses/$id';
  static String markDoseTaken(String id) => '/medicine-schedule/doses/$id/taken';

  // Health reminders (Phase 3B)
  static const String healthReminders = '/health-reminders';
  static const String healthRemindersUpcoming = '/health-reminders/upcoming';
  static const String healthRemindersDue = '/health-reminders/due';
  static String healthReminderDetail(String id) => '/health-reminders/$id';
  static String completeHealthReminder(String id) => '/health-reminders/$id/complete';

  // Health records (Phase 3B)
  static const String healthRecords = '/health-records';
  static String healthRecordDetail(String id) => '/health-records/$id';

  // AI health suggestions (Phase 4) — admin-published only; drafts are
  // never exposed on this endpoint. See backend `HealthSuggestionsController`.
  static const String healthSuggestionsMine = '/health-suggestions/mine';

  // Government/admin notices (Phase 4) — published, non-expired,
  // audience-matched only. See backend `NoticesController`.
  static const String noticesMine = '/notices/mine';

  // AI assistant (Phase 4B): Flutter -> NestJS -> AI provider.
  static const String assistantConversations = '/assistant/conversations';
  static String assistantConversation(String id) =>
      '/assistant/conversations/$id';
  static String assistantConversationMessages(String id) =>
      '/assistant/conversations/$id/messages';
}
