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
  static const String deactivate = '/users/me/deactivate';

  // Dropdown data (public)
  static const String lookups = '/lookups';
  static const String upazilas = '/lookups/upazilas';

  // Medicine catalog autosuggest (read-only for patients)
  static const String catalogMedicineSearch = '/catalog/medicines/search';

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
  static String familyMember(String userId) => '/family/members/$userId';
  static const String familyLeave = '/family/leave';
  static const String familyEvents = '/family/events';
  // Round 17: what a caregiver changed (mine / a member's).
  static const String familyChanges = '/family/changes';
  static String familyMemberChanges(String userId) => '/family/members/$userId/changes';

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
  static String prescriptionConfirm(String id) => '/prescriptions/$id/confirm';
  static String prescriptionRequestEdit(String id) => '/prescriptions/$id/request-edit';

  // Medicine schedule (Phase 3A/3B) — synchronized routines/doses
  // generated once a prescription is COMPLETED.
  static const String medicineRoutines = '/medicine-schedule/routines';
  static String medicineRoutine(String id) => '/medicine-schedule/routines/$id';
  static const String medicineToday = '/medicine-schedule/today';
  static const String medicineUpcoming = '/medicine-schedule/upcoming';
  static String doseDetail(String id) => '/medicine-schedule/doses/$id';

  // Round 14
  static const String reminderTiming = '/users/me/reminder-timing';
  static String memberEasyMode(String userId) => '/family/members/$userId/easy-mode';
  static String markDoseTaken(String id) => '/medicine-schedule/doses/$id/taken';

  // Health reminders (Phase 3B)
  static const String healthReminders = '/health-reminders';
  // Round 13: reminder timings from the server's .env, personal reminders, the medicine box.
  static const String appConfig = '/app-config';
  static const String personalReminders = '/personal-reminders';
  static String personalReminder(String id) => '/personal-reminders/$id';
  static String personalReminderLater(String id) => '/personal-reminders/$id/later';
  static const String medicineBox = '/medicine-box';
  static String medicineBoxIgnore(String routineId) => '/medicine-box/$routineId/ignore';
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
  // Round 17: share a notice with my family; open one shared with me.
  static String noticeShareFamily(String id) => '/notices/$id/share-family';
  static String noticeShared(String id) => '/notices/shared/$id';

  // AI assistant (Phase 4B): Flutter -> NestJS -> AI provider.
  static const String assistantConversations = '/assistant/conversations';
  static String assistantConversation(String id) =>
      '/assistant/conversations/$id';
  static String assistantConversationMessages(String id) =>
      '/assistant/conversations/$id/messages';

  // Round 15: my care (conditions, limits, settings, ticks, logs, questions).
  static const String care = '/care';
  static const String careConditions = '/care/conditions';
  static const String careStepSkip = '/care/step-skip';
  static const String careLimits = '/care/limits';
  static String careSettings(String code) => '/care/settings/$code';
  static const String careTicks = '/care/ticks';
  static const String careLogs = '/care/logs';
  static String careLog(String id) => '/care/logs/$id';
  static const String careQuestions = '/care/questions';
  static String careQuestion(String id) => '/care/questions/$id';
  static const String careAlertFamily = '/care/alert-family';

  // Round 16: health records 2.0.
  static const String records = '/records';
  static const String recordsDoctorSearch = '/records/doctors/search';
  static const String recordsAppointments = '/records/appointments';
  static String recordsAppointment(String id) => '/records/appointments/$id';
  static const String recordsTests = '/records/tests';
  static String recordsTest(String id) => '/records/tests/$id';
  static String recordsTestPhotos(String id) => '/records/tests/$id/photos';
  static const String recordsPrescriptions = '/records/prescriptions';
  static String recordsPrescription(String id) => '/records/prescriptions/$id';
  static String recordsPrescriptionPhotos(String id) => '/records/prescriptions/$id/photos';
  static String recordsPhoto(String id) => '/records/photos/$id';
}
