/// A deliberately simple, hand-maintained i18n layer.
///
/// The MVP only needs two languages and a modest string set, so a full
/// `intl`/ARB code-generation pipeline would be more machinery than the
/// project needs right now. Each field below is a translated string;
/// screens read them via `ref.watch(stringsProvider)`.
class AppStrings {
  const AppStrings({
    required this.appName,
    required this.sponsoredAdTag,
    required this.adHeadline,
    required this.adMessage,
    required this.noPrescriptionsYet,
    required this.personalInformation,
    required this.prescriptionsTitle,
    required this.waitingToUpload,
    required this.notificationSettings,
    required this.pushNotificationsLabel,
    required this.pushNotificationsHelp,
    required this.privacySettings,
    required this.privacyHelp,
    required this.syncStatusTitle,
    required this.allChangesSynced,
    required this.changesWaitingToSync,
    required this.needsInternetToSave,
    required this.assistantIntro,
    required this.assistantLimits,
    required this.assistantPrivacy,
    required this.assistantHint,
    required this.assistantSuggestion1,
    required this.assistantSuggestion2,
    required this.assistantSuggestion3,
    required this.assistantUnavailable,
    required this.assistantTooMany,
    required this.assistantNeedsInternet,
    required this.assistantUrgent,
    required this.assistantConversationsTitle,
    required this.assistantNewConversation,
    required this.assistantNoConversations,
    required this.assistantMessagesLabel,
    required this.assistantClosedLabel,
    required this.assistantConversationClosed,
    required this.assistantDeleteTitle,
    required this.assistantDeleteConfirm,
    required this.assistantDeleteFailed,
    required this.assistantDeleting,
    required this.assistantLoadFailed,
    required this.assistantGone,
    required this.delete,
    required this.sendLabel,
    required this.seeAll,
    required this.noticesUnavailable,
    required this.doseSkipped,
    required this.markAllRead,
    required this.noNotificationsYet,
    required this.loadMore,
    required this.familyOwner,
    required this.memberNotSharing,
    required this.noDosesToday,
    required this.familyEmptyHint,
    required this.inviteSent,
    required this.invitedBy,
    required this.familySharingNote,
    required this.inviteToSeeStatus,
    required this.showingSavedData,
    required this.statusNotShared,
    required this.login,
    required this.register,
    required this.phone,
    required this.password,
    required this.confirmPassword,
    required this.name,
    required this.address,
    required this.addressOptional,
    required this.loginButton,
    required this.registerButton,
    required this.noAccountYet,
    required this.alreadyHaveAccount,
    required this.home,
    required this.family,
    required this.prescription,
    required this.health,
    required this.profile,
    required this.todaysMedicine,
    required this.healthReminders,
    required this.dueReminders,
    required this.upcomingReminders,
    required this.markComplete,
    required this.healthRecords,
    required this.addRecord,
    required this.recordType,
    required this.recordValue,
    required this.recordUnit,
    required this.recordNotes,
    required this.save,
    required this.noHealthReminders,
    required this.noHealthRecords,
    required this.notMedicalAdviceDisclaimer,
    required this.governmentNotices,
    required this.viewNotices,
    required this.noNoticesYet,
    required this.aiHealthSuggestions,
    required this.noHealthSuggestionsYet,
    required this.quickActions,
    required this.uploadPrescription,
    required this.aiAssistant,
    required this.comingSoon,
    required this.noItemsYet,
    required this.somethingWentWrong,
    required this.retry,
    required this.offlineBanner,
    required this.syncingBanner,
    required this.pendingSyncBadge,
    required this.myFamily,
    required this.createFamily,
    required this.inviteMember,
    required this.pendingInvitations,
    required this.accept,
    required this.decline,
    required this.familyName,
    required this.invitePhoneHint,
    required this.notInFamilyYet,
    required this.editProfile,
    required this.logout,
    required this.logoutConfirm,
    required this.changePassword,
    required this.currentPassword,
    required this.newPassword,
    required this.language,
    required this.appearance,
    required this.themeSystem,
    required this.themeLight,
    required this.themeDark,
    required this.notifications,
    required this.hideFromFamily,
    required this.newPrescriptionEntry,
    required this.prescriptionNote,
    required this.attachImage,
    required this.saveDraft,
    required this.draftSavedOffline,
    required this.uploadPendingNotice,
    required this.cancel,
    required this.requiredField,
    required this.invalidPhone,
    required this.passwordTooShort,
    required this.forgotPassword,
    required this.resetPasswordTitle,
    required this.forgotPasswordHelp,
    required this.sendCode,
    required this.resetCodeSentNotice,
    required this.verificationCode,
    required this.saveNewPassword,
    required this.passwordResetDone,
    required this.backToLogin,
    required this.passwordChangedDone,
    required this.accountSection,
    required this.deleteAccount,
    required this.deleteAccountWarning,
    required this.deleteAccountPasswordPrompt,
    required this.deleteMyAccount,
    required this.passwordsDoNotMatch,
    required this.statusPending,
    required this.statusCompleted,
    required this.statusRejected,
    required this.statusAwaitingConfirmation,
    required this.statusActive,
    required this.statusEnded,
    required this.rejectionReason,
    required this.reuploadPrescription,
    required this.reuploadHint,
    required this.viewTodaysMedicine,
    required this.noMedicineToday,
    required this.noActiveRoutines,
    required this.myMedicineRoutines,
    required this.doseTaken,
    required this.doseUpcoming,
    required this.pendingReview,
    required this.doseDue,
    required this.doseMissed,
    required this.markAsTaken,
    required this.syncingBadge,
    required this.syncFailedBadge,
    required this.syncedBadge,
    required this.reminderCheckTitle,
    required this.reminderCheckHelp,
    required this.remindersBlockedBanner,
    required this.remindersMayBeLateBanner,
    required this.notificationsPermissionLabel,
    required this.notificationsAllowed,
    required this.notificationsBlocked,
    required this.exactAlarmLabel,
    required this.exactAlarmAllowed,
    required this.exactAlarmDenied,
    required this.batteryLabel,
    required this.batteryUnrestricted,
    required this.batteryRestricted,
    required this.allowAction,
    required this.openSettingsAction,
    required this.reminderVendorTip,
    required this.reminderTitle,
    required this.reminderBodyOne,
    required this.reminderBodyMany,
    required this.reminderDoneAction,
    required this.reminderLaterAction,
    required this.medicineRemindersLabel,
    required this.medicineRemindersHelp,
    required this.medicineRemindersOffTitle,
    required this.medicineRemindersOffWarning,
    required this.turnOffAction,
    required this.noticesLabel,
    required this.noticesHelp,
    required this.inboxPersonalTab,
    required this.inboxFamilyTab,
    required this.inboxGeneralTab,
    required this.byCaregiver,
    required this.selfAdded,
    required this.addedByCaregiver,
    required this.editedByYou,
    required this.editedByCaregiver,
    required this.confirmPrescriptionTitle,
    required this.confirmPrescriptionHelp,
    required this.confirmAndStartReminders,
    required this.prescriptionConfirmedDone,
    required this.alreadyConfirmed,
    required this.keepOneMedicine,
    required this.reviewAndConfirm,
    required this.removeMedicine,
    required this.undoRemove,
    required this.removeMedicineConfirm,
    required this.doseTimes,
    required this.startDate,
    required this.startsWhenConfirmed,
    required this.today,
    required this.mealTiming,
    required this.notSpecified,
    required this.continuousLabel,
    required this.continuousHelp,
    required this.daysCountTemplate,
    required this.myMedicines,
    required this.medicinesOfTemplate,
    required this.manageMedicines,
    required this.addMedicine,
    required this.editMedicine,
    required this.pharmacistMedicineLimited,
    required this.medicineName,
    required this.strength,
    required this.doseAmount,
    required this.timesPerDay,
    required this.numberOfDays,
    required this.numberOfDaysInvalid,
    required this.timesMustDiffer,
    required this.prescriptionsOfTemplate,
    required this.uploadedForMember,
    required this.takePhoto,
    required this.caregiverActingHint,
    required this.medicinesButton,
    required this.prescriptionsButton,
    required this.invitationWarning,
    required this.editYourDetails,
    required this.detailsSaved,
    required this.dateOfBirth,
    required this.gender,
    required this.division,
    required this.district,
    required this.upazila,
    required this.couldNotLoadOptions,
    required this.allNotices,
    required this.noticeSource,
  });

  final String appName;
  final String sponsoredAdTag;
  final String adHeadline;
  final String adMessage;
  final String noPrescriptionsYet;
  final String personalInformation;
  final String prescriptionsTitle;
  final String waitingToUpload;
  final String notificationSettings;
  final String pushNotificationsLabel;
  final String pushNotificationsHelp;
  final String privacySettings;
  final String privacyHelp;
  final String syncStatusTitle;
  final String allChangesSynced;
  final String changesWaitingToSync;
  final String needsInternetToSave;
  final String assistantIntro;
  final String assistantLimits;
  final String assistantPrivacy;
  final String assistantHint;
  final String assistantSuggestion1;
  final String assistantSuggestion2;
  final String assistantSuggestion3;
  final String assistantUnavailable;
  final String assistantTooMany;
  final String assistantNeedsInternet;
  final String assistantUrgent;
  final String assistantConversationsTitle;
  final String assistantNewConversation;
  final String assistantNoConversations;
  final String assistantMessagesLabel;
  final String assistantClosedLabel;
  final String assistantConversationClosed;
  final String assistantDeleteTitle;
  final String assistantDeleteConfirm;
  final String assistantDeleteFailed;
  final String assistantDeleting;
  final String assistantLoadFailed;
  final String assistantGone;
  final String delete;
  final String sendLabel;
  final String seeAll;
  final String noticesUnavailable;
  final String doseSkipped;
  final String markAllRead;
  final String noNotificationsYet;
  final String loadMore;
  final String familyOwner;
  final String memberNotSharing;
  final String noDosesToday;
  final String familyEmptyHint;
  final String inviteSent;
  final String invitedBy;
  final String familySharingNote;
  final String inviteToSeeStatus;
  final String showingSavedData;
  final String statusNotShared;
  final String login;
  final String register;
  final String phone;
  final String password;
  final String confirmPassword;
  final String name;
  final String address;
  final String addressOptional;
  final String loginButton;
  final String registerButton;
  final String noAccountYet;
  final String alreadyHaveAccount;
  final String home;
  final String family;
  final String prescription;
  final String health;
  final String profile;
  final String todaysMedicine;
  final String healthReminders;
  final String dueReminders;
  final String upcomingReminders;
  final String markComplete;
  final String healthRecords;
  final String addRecord;
  final String recordType;
  final String recordValue;
  final String recordUnit;
  final String recordNotes;
  final String save;
  final String noHealthReminders;
  final String noHealthRecords;
  final String notMedicalAdviceDisclaimer;
  final String governmentNotices;
  final String viewNotices;
  final String noNoticesYet;
  final String aiHealthSuggestions;
  final String noHealthSuggestionsYet;
  final String quickActions;
  final String uploadPrescription;
  final String aiAssistant;
  final String comingSoon;
  final String noItemsYet;
  final String somethingWentWrong;
  final String retry;
  final String offlineBanner;
  final String syncingBanner;
  final String pendingSyncBadge;
  final String myFamily;
  final String createFamily;
  final String inviteMember;
  final String pendingInvitations;
  final String accept;
  final String decline;
  final String familyName;
  final String invitePhoneHint;
  final String notInFamilyYet;
  final String editProfile;
  final String logout;
  final String logoutConfirm;
  final String changePassword;
  final String currentPassword;
  final String newPassword;
  final String language;

  /// Theme choice in Profile (this device only).
  final String appearance;
  final String themeSystem;
  final String themeLight;
  final String themeDark;
  final String notifications;
  final String hideFromFamily;
  final String newPrescriptionEntry;
  final String prescriptionNote;
  final String attachImage;
  final String saveDraft;
  final String draftSavedOffline;
  final String uploadPendingNotice;
  final String cancel;
  final String requiredField;
  final String invalidPhone;
  final String passwordTooShort;
  final String forgotPassword;
  final String resetPasswordTitle;
  final String forgotPasswordHelp;
  final String sendCode;
  final String resetCodeSentNotice;
  final String verificationCode;
  final String saveNewPassword;
  final String passwordResetDone;
  final String backToLogin;
  final String passwordChangedDone;
  final String accountSection;
  final String deleteAccount;
  final String deleteAccountWarning;
  final String deleteAccountPasswordPrompt;
  final String deleteMyAccount;
  final String passwordsDoNotMatch;
  final String statusPending;
  final String statusCompleted;
  final String statusRejected;
  final String statusAwaitingConfirmation;
  final String statusActive;
  final String statusEnded;
  final String rejectionReason;
  final String reuploadPrescription;
  final String reuploadHint;
  final String viewTodaysMedicine;
  final String noMedicineToday;
  final String noActiveRoutines;
  final String myMedicineRoutines;
  final String doseTaken;
  final String doseUpcoming;
  final String pendingReview;
  final String doseDue;
  final String doseMissed;
  final String markAsTaken;
  final String syncingBadge;
  final String syncFailedBadge;
  final String syncedBadge;
  final String reminderCheckTitle;
  final String reminderCheckHelp;
  final String remindersBlockedBanner;
  final String remindersMayBeLateBanner;
  final String notificationsPermissionLabel;
  final String notificationsAllowed;
  final String notificationsBlocked;
  final String exactAlarmLabel;
  final String exactAlarmAllowed;
  final String exactAlarmDenied;
  final String batteryLabel;
  final String batteryUnrestricted;
  final String batteryRestricted;
  final String allowAction;
  final String openSettingsAction;
  final String reminderVendorTip;
  final String reminderTitle;
  final String reminderBodyOne;
  final String reminderBodyMany;
  final String reminderDoneAction;
  final String reminderLaterAction;
  final String medicineRemindersLabel;
  final String medicineRemindersHelp;
  final String medicineRemindersOffTitle;
  final String medicineRemindersOffWarning;
  final String turnOffAction;
  final String noticesLabel;
  final String noticesHelp;
  final String inboxPersonalTab;
  final String inboxFamilyTab;
  final String inboxGeneralTab;
  final String byCaregiver;
  final String selfAdded;
  final String addedByCaregiver;
  final String editedByYou;
  final String editedByCaregiver;
  final String confirmPrescriptionTitle;
  final String confirmPrescriptionHelp;
  final String confirmAndStartReminders;
  final String prescriptionConfirmedDone;
  final String alreadyConfirmed;
  final String keepOneMedicine;
  final String reviewAndConfirm;
  final String removeMedicine;
  final String undoRemove;
  final String removeMedicineConfirm;
  final String doseTimes;
  final String startDate;
  final String startsWhenConfirmed;
  final String today;
  final String mealTiming;
  final String notSpecified;
  final String continuousLabel;
  final String continuousHelp;
  final String daysCountTemplate;
  final String myMedicines;
  final String medicinesOfTemplate;
  final String manageMedicines;
  final String addMedicine;
  final String editMedicine;
  final String pharmacistMedicineLimited;
  final String medicineName;
  final String strength;
  final String doseAmount;
  final String timesPerDay;
  final String numberOfDays;
  final String numberOfDaysInvalid;
  final String timesMustDiffer;
  final String prescriptionsOfTemplate;
  final String uploadedForMember;
  final String takePhoto;
  final String caregiverActingHint;
  final String medicinesButton;
  final String prescriptionsButton;
  final String invitationWarning;
  final String editYourDetails;
  final String detailsSaved;
  final String dateOfBirth;
  final String gender;
  final String division;
  final String district;
  final String upazila;
  final String couldNotLoadOptions;

  /// "{n} days"
  String daysCount(int n) => daysCountTemplate.replaceAll('{n}', '$n');

  String medicinesOf(String name) => medicinesOfTemplate.replaceAll('{name}', name);

  String prescriptionsOf(String name) => prescriptionsOfTemplate.replaceAll('{name}', name);
  final String allNotices;
  final String noticeSource;
}

const AppStrings enStrings = AppStrings(
  appName: 'Medi-Bela',
  sponsoredAdTag: 'Sponsored Ad',
  adHeadline: 'Medi-Bela',
  adMessage: 'Taking care of yourself and your family in time.',
  noPrescriptionsYet: 'No prescriptions uploaded yet',
  personalInformation: 'Personal information',
  prescriptionsTitle: 'Prescriptions',
  waitingToUpload: 'Waiting to upload',
  notificationSettings: 'Notification settings',
  pushNotificationsLabel: 'Push notifications',
  pushNotificationsHelp: 'Family alerts, prescription updates and notices sent from Medi-Bela.',
  privacySettings: 'Privacy',
  privacyHelp: 'When on, no one in your family, including the caregiver, can see your address or your medicines or manage them for you, and they get no missed-dose alerts about you.',
  syncStatusTitle: 'Sync',
  allChangesSynced: 'All changes are synced',
  changesWaitingToSync: 'changes waiting to sync',
  needsInternetToSave: 'This needs an internet connection.',
  assistantIntro: 'Hi! I can share general health information, explain your medicine instructions and reminders, and show you how the app works.',
  assistantLimits: 'I can\'t diagnose, prescribe, or change any medicine or dose. Always ask a doctor or pharmacist about your own health.',
  assistantPrivacy: 'Your question and your current medicine list are sent to an AI service to answer. Please don\'t type your name or phone number. Your conversations are saved to your account until you delete them.',
  assistantHint: 'Ask a question…',
  assistantSuggestion1: 'Explain my medicine instructions',
  assistantSuggestion2: 'What does my health reminder mean?',
  assistantSuggestion3: 'How does this app work?',
  assistantUnavailable: 'The assistant is unavailable right now. Please try again later.',
  assistantTooMany: 'You\'ve sent a lot of messages. Please try again in a while.',
  assistantNeedsInternet: 'The assistant needs an internet connection.',
  assistantUrgent: 'Urgent',
  assistantConversationsTitle: 'Conversations',
  assistantNewConversation: 'New conversation',
  assistantNoConversations: 'No conversations yet. Start one to ask a question.',
  assistantMessagesLabel: 'Messages',
  assistantClosedLabel: 'Closed',
  assistantConversationClosed: 'This conversation reached its 10-message limit and is now read-only. Start a new conversation to keep chatting.',
  assistantDeleteTitle: 'Delete conversation?',
  assistantDeleteConfirm: 'This permanently deletes the conversation and all its messages from your account. This cannot be undone.',
  assistantDeleteFailed: 'Could not delete the conversation. It was not removed. Please try again.',
  assistantDeleting: 'Deleting…',
  assistantLoadFailed: 'Could not load your conversations.',
  assistantGone: 'This conversation no longer exists.',
  delete: 'Delete',
  sendLabel: 'Send',
  seeAll: 'See all',
  noticesUnavailable: 'Couldn\'t load notices. Tap to open.',
  doseSkipped: 'Skipped',
  markAllRead: 'Mark all as read',
  noNotificationsYet: 'No notifications yet',
  loadMore: 'Load more',
  familyOwner: 'Caregiver',
  memberNotSharing: 'This member is not sharing their medicine status.',
  noDosesToday: 'No doses scheduled today',
  familyEmptyHint: 'Create a family to share medicine status with people you trust.',
  inviteSent: 'Invitation sent',
  invitedBy: 'Invited by',
  familySharingNote: 'Family members can see which medicines you took or missed today. You can turn this off in Profile.',
  inviteToSeeStatus: 'Invite someone to see their medicine status here.',
  showingSavedData: 'Showing saved data',
  statusNotShared: 'Not shared',
  login: 'Login',
  register: 'Register',
  phone: 'Phone number',
  password: 'Password',
  confirmPassword: 'Confirm password',
  name: 'Full name',
  address: 'Address',
  addressOptional: 'Address (optional)',
  loginButton: 'Log in',
  registerButton: 'Create account',
  noAccountYet: "Don't have an account? Register",
  alreadyHaveAccount: 'Already have an account? Log in',
  home: 'Home',
  family: 'Family',
  prescription: 'Prescription',
  health: 'Health',
  profile: 'Profile',
  todaysMedicine: "Today's Medicine",
  healthReminders: 'Health Reminders',
  dueReminders: 'Due',
  upcomingReminders: 'Upcoming',
  markComplete: 'Mark complete',
  healthRecords: 'Health Records',
  addRecord: 'Add record',
  recordType: 'Type',
  recordValue: 'Value',
  recordUnit: 'Unit (optional)',
  recordNotes: 'Notes (optional)',
  save: 'Save',
  noHealthReminders: 'No health reminders right now',
  noHealthRecords: "You haven't added any health records yet",
  notMedicalAdviceDisclaimer:
      'These are general reminders, not medical advice. Always consult a doctor or pharmacist.',
  governmentNotices: 'Government Notices',
  viewNotices: 'View announcements',
  noNoticesYet: 'No notices right now',
  aiHealthSuggestions: 'AI Health Suggestions',
  noHealthSuggestionsYet: 'No AI health suggestions yet',
  quickActions: 'Quick actions',
  uploadPrescription: 'Upload Prescription',
  aiAssistant: 'AI Assistant',
  comingSoon: 'Coming soon',
  noItemsYet: 'Nothing here yet',
  somethingWentWrong: 'Something went wrong',
  retry: 'Retry',
  offlineBanner: "You're offline — showing saved data",
  syncingBanner: 'Syncing…',
  pendingSyncBadge: 'Pending sync',
  myFamily: 'My Family',
  createFamily: 'Create a family',
  inviteMember: 'Invite a member',
  pendingInvitations: 'Pending invitations',
  accept: 'Accept',
  decline: 'Decline',
  familyName: 'Family name (optional)',
  invitePhoneHint: "Member's phone number",
  notInFamilyYet: "You're not part of a family yet",
  editProfile: 'Edit profile',
  logout: 'Log out',
  logoutConfirm: 'Are you sure you want to log out?',
  changePassword: 'Change password',
  currentPassword: 'Current password',
  newPassword: 'New password',
  language: 'Language',
  appearance: 'Appearance',
  themeSystem: 'Phone setting',
  themeLight: 'Light',
  themeDark: 'Dark',
  notifications: 'Notifications',
  hideFromFamily: 'Hide from family',
  newPrescriptionEntry: 'New prescription entry',
  prescriptionNote: 'Note for the pharmacist',
  attachImage: 'Attach photo',
  saveDraft: 'Save',
  draftSavedOffline: 'Saved on this device. It will upload automatically.',
  uploadPendingNotice:
      'Your prescription will upload automatically once you have a '
      'connection, and a pharmacist will review it shortly after.',
  cancel: 'Cancel',
  requiredField: 'This field is required',
  invalidPhone: 'Enter a valid phone number',
  passwordTooShort: 'Password must be at least 6 characters',
  forgotPassword: 'Forgot password?',
  resetPasswordTitle: 'Reset password',
  forgotPasswordHelp: 'Enter your phone number. If an account exists, we will text a 6-digit code to that phone.',
  sendCode: 'Send code',
  resetCodeSentNotice: 'If an account exists for this number, a code has been sent. Enter it below.',
  verificationCode: '6-digit code',
  saveNewPassword: 'Save new password',
  passwordResetDone: 'Password updated. Please log in with your new password.',
  backToLogin: 'Back to login',
  passwordChangedDone: 'Password changed.',
  accountSection: 'Account',
  deleteAccount: 'Delete account',
  deleteAccountWarning: 'This permanently deletes your account and all your data: prescriptions, routines, reminders, health records, assistant conversations and family membership. This cannot be undone.',
  deleteAccountPasswordPrompt: 'Enter your password to confirm.',
  deleteMyAccount: 'Delete my account',
  passwordsDoNotMatch: 'Passwords do not match',
  statusPending: 'Pending review',
  statusCompleted: 'Reviewed',
  statusRejected: 'Rejected',
  statusAwaitingConfirmation: 'Ready to confirm',
  statusActive: 'Active',
  statusEnded: 'Ended',
  rejectionReason: 'Reason',
  reuploadPrescription: 'Re-upload',
  reuploadHint:
      'Upload a clearer photo of this prescription. The pharmacist will see it together with their note.',
  viewTodaysMedicine: "View today's medicine",
  noMedicineToday: 'No medicine scheduled for today',
  noActiveRoutines: 'No active medicine routines yet',
  myMedicineRoutines: 'My medicine routines',
  doseTaken: 'Taken',
  doseUpcoming: 'Upcoming',
  pendingReview: 'Waiting for pharmacist review',
  doseDue: 'Due now',
  doseMissed: 'Missed',
  markAsTaken: 'Mark as taken',
  syncingBadge: 'Syncing…',
  syncFailedBadge: 'Sync failed',
  syncedBadge: 'Synced',
  reminderCheckTitle: 'Reminder check',
  reminderCheckHelp: 'Make sure medicine reminders reach you on time, even when the app is closed.',
  remindersBlockedBanner: 'Reminders are off: notifications are blocked. Tap to fix.',
  remindersMayBeLateBanner: 'Reminders may be a few minutes late. Tap to fix.',
  notificationsPermissionLabel: 'Notifications',
  notificationsAllowed: 'Allowed',
  notificationsBlocked: 'Blocked: reminders will not show',
  exactAlarmLabel: 'Alarms & reminders',
  exactAlarmAllowed: 'Allowed: reminders arrive on time',
  exactAlarmDenied: 'Not allowed: reminders may be a few minutes late',
  batteryLabel: 'Battery optimization',
  batteryUnrestricted: 'Not restricted',
  batteryRestricted: 'Restricted: the phone may delay reminders. Set Medi-Bela to "Don\'t optimize" or "No restrictions".',
  allowAction: 'Allow',
  openSettingsAction: 'Open settings',
  reminderVendorTip: 'On Xiaomi, realme, OPPO and vivo phones, also turn on Autostart for Medi-Bela and lock it in the recent apps list.',
  reminderTitle: 'Time for your medicine',
  reminderBodyOne: 'A medicine is due at {time}. Open the app to see which.',
  reminderBodyMany: '{count} medicines are due at {time}. Open the app to see which.',
  reminderDoneAction: 'Done',
  reminderLaterAction: 'Later (30 min)',
  medicineRemindersLabel: 'Medicine reminders',
  medicineRemindersHelp: 'Rings at each medicine time, even offline. Your family is alerted if a dose is missed.',
  medicineRemindersOffTitle: 'Turn off medicine reminders?',
  medicineRemindersOffWarning: 'You will get no medicine reminders, and your family will not be alerted when you miss a dose.',
  turnOffAction: 'Turn off',
  noticesLabel: 'Notices',
  noticesHelp: 'Health notices from Medi-Bela. When off, you can still read them in the app.',
  inboxPersonalTab: 'Personal',
  inboxFamilyTab: 'Family',
  inboxGeneralTab: 'General',
  byCaregiver: 'by caregiver',
  selfAdded: 'Self-added',
  addedByCaregiver: 'Added by caregiver',
  editedByYou: 'Edited by you',
  editedByCaregiver: 'Edited by caregiver',
  confirmPrescriptionTitle: 'Confirm your medicines',
  confirmPrescriptionHelp: 'Your pharmacist prepared these medicines. You can change the dose times, start date or meal timing, or remove a medicine. Reminders start when you confirm.',
  confirmAndStartReminders: 'Confirm and start reminders',
  prescriptionConfirmedDone: 'Confirmed. Your reminders have started.',
  alreadyConfirmed: 'This prescription is already confirmed.',
  keepOneMedicine: 'Keep at least one medicine to confirm.',
  reviewAndConfirm: 'Review and confirm',
  removeMedicine: 'Remove',
  undoRemove: 'Keep it',
  removeMedicineConfirm: 'Stop this medicine? Its reminders stop from now on. Past doses stay in your history.',
  doseTimes: 'Dose times',
  startDate: 'Start date',
  startsWhenConfirmed: 'The day you confirm',
  today: 'Today',
  mealTiming: 'Meal timing',
  notSpecified: 'Not specified',
  continuousLabel: 'Continuous (no end date)',
  continuousHelp: 'Keep taking it until a doctor says to stop.',
  daysCountTemplate: '{n} days',
  myMedicines: 'My medicines',
  medicinesOfTemplate: "{name}'s medicines",
  manageMedicines: 'Manage',
  addMedicine: 'Add a medicine',
  editMedicine: 'Change medicine',
  pharmacistMedicineLimited: 'Your pharmacist set this medicine. You can change the dose times and meal timing.',
  medicineName: 'Medicine name',
  strength: 'Strength',
  doseAmount: 'Amount per dose',
  timesPerDay: 'Times a day',
  numberOfDays: 'Number of days',
  numberOfDaysInvalid: 'Enter 1 to 365 days',
  timesMustDiffer: 'Choose a different time for each dose.',
  prescriptionsOfTemplate: "{name}'s prescriptions",
  uploadedForMember: 'Uploaded. The pharmacist will prepare it.',
  takePhoto: 'Take a photo',
  caregiverActingHint: 'As the caregiver you can manage their medicines and prescriptions. They are told about each change.',
  medicinesButton: 'Medicines',
  prescriptionsButton: 'Prescriptions',
  invitationWarning: 'If you join, the person who invited you becomes your caregiver. They can see your medicines, get an alert if you miss a dose, and manage your medicines and prescriptions for you. Only you mark your doses as taken. You can hide yourself from family in Profile.',
  editYourDetails: 'Edit your details',
  detailsSaved: 'Your details are saved.',
  dateOfBirth: 'Date of birth',
  gender: 'Gender',
  division: 'Division',
  district: 'District',
  upazila: 'Upazila',
  couldNotLoadOptions: 'Could not load the options. Check your internet.',
  allNotices: 'All notices',
  noticeSource: 'Source',
);

const AppStrings bnStrings = AppStrings(
  appName: 'মেডি-বেলা',
  sponsoredAdTag: 'স্পনসর্ড বিজ্ঞাপন',
  adHeadline: 'মেডি-বেলা',
  adMessage: 'নিজের এবং পরিবারের যত্ন নিন সময় থাকতেই।',
  noPrescriptionsYet: 'এখনো কোনো প্রেসক্রিপশন আপলোড করা হয়নি',
  personalInformation: 'ব্যক্তিগত তথ্য',
  prescriptionsTitle: 'প্রেসক্রিপশন',
  waitingToUpload: 'আপলোডের অপেক্ষায়',
  notificationSettings: 'বিজ্ঞপ্তি সেটিংস',
  pushNotificationsLabel: 'পুশ নোটিফিকেশন',
  pushNotificationsHelp: 'Medi-Bela থেকে পাঠানো পরিবারের সতর্কতা, প্রেসক্রিপশনের হালনাগাদ ও বিজ্ঞপ্তি।',
  privacySettings: 'গোপনীয়তা',
  privacyHelp: 'চালু থাকলে পরিবারের কেউ, পরিচর্যাকারীসহ, আপনার ঠিকানা বা ওষুধ দেখতে বা আপনার হয়ে পরিচালনা করতে পারবেন না, এবং আপনার ওষুধ মিস হলে সতর্কতাও পাবেন না।',
  syncStatusTitle: 'সিঙ্ক',
  allChangesSynced: 'সব পরিবর্তন সিঙ্ক হয়েছে',
  changesWaitingToSync: 'টি পরিবর্তন সিঙ্কের অপেক্ষায়',
  needsInternetToSave: 'এটির জন্য ইন্টারনেট সংযোগ প্রয়োজন।',
  assistantIntro: 'হ্যালো! আমি সাধারণ স্বাস্থ্য তথ্য দিতে, আপনার ওষুধের নির্দেশনা ও রিমাইন্ডার ব্যাখ্যা করতে এবং অ্যাপ কীভাবে কাজ করে তা বলতে পারি।',
  assistantLimits: 'আমি রোগ নির্ণয়, ওষুধ প্রেসক্রাইব বা কোনো ওষুধ/ডোজ বদলাতে পারি না। নিজের স্বাস্থ্য সম্পর্কে সবসময় ডাক্তার বা ফার্মাসিস্টকে জিজ্ঞেস করুন।',
  assistantPrivacy: 'উত্তর দিতে আপনার প্রশ্ন ও বর্তমান ওষুধের তালিকা একটি এআই সেবায় পাঠানো হয়। আপনার নাম বা ফোন নম্বর লিখবেন না। আপনি মুছে না ফেলা পর্যন্ত আপনার কথোপকথন আপনার অ্যাকাউন্টে সংরক্ষিত থাকে।',
  assistantHint: 'প্রশ্ন লিখুন…',
  assistantSuggestion1: 'আমার ওষুধের নির্দেশনা ব্যাখ্যা করুন',
  assistantSuggestion2: 'আমার স্বাস্থ্য রিমাইন্ডারের মানে কী?',
  assistantSuggestion3: 'এই অ্যাপ কীভাবে কাজ করে?',
  assistantUnavailable: 'সহকারী এখন পাওয়া যাচ্ছে না। পরে আবার চেষ্টা করুন।',
  assistantTooMany: 'আপনি অনেক বার্তা পাঠিয়েছেন। কিছুক্ষণ পরে আবার চেষ্টা করুন।',
  assistantNeedsInternet: 'সহকারীর জন্য ইন্টারনেট সংযোগ প্রয়োজন।',
  assistantUrgent: 'জরুরি',
  assistantConversationsTitle: 'কথোপকথন',
  assistantNewConversation: 'নতুন কথোপকথন',
  assistantNoConversations: 'এখনও কোনো কথোপকথন নেই। প্রশ্ন করতে একটি শুরু করুন।',
  assistantMessagesLabel: 'বার্তা',
  assistantClosedLabel: 'বন্ধ',
  assistantConversationClosed: 'এই কথোপকথনে ১০টি বার্তার সীমা শেষ হয়েছে, তাই এটি এখন শুধু পড়া যাবে। চালিয়ে যেতে নতুন কথোপকথন শুরু করুন।',
  assistantDeleteTitle: 'কথোপকথন মুছবেন?',
  assistantDeleteConfirm: 'এটি আপনার অ্যাকাউন্ট থেকে কথোপকথন ও এর সব বার্তা স্থায়ীভাবে মুছে ফেলবে। এটি ফেরানো যাবে না।',
  assistantDeleteFailed: 'কথোপকথনটি মোছা যায়নি। এটি রয়ে গেছে। আবার চেষ্টা করুন।',
  assistantDeleting: 'মুছে ফেলা হচ্ছে…',
  assistantLoadFailed: 'আপনার কথোপকথন লোড করা যায়নি।',
  assistantGone: 'এই কথোপকথনটি আর নেই।',
  delete: 'মুছুন',
  sendLabel: 'পাঠান',
  seeAll: 'সব দেখুন',
  noticesUnavailable: 'বিজ্ঞপ্তি লোড করা যায়নি। খুলতে ট্যাপ করুন।',
  doseSkipped: 'বাদ দেওয়া হয়েছে',
  markAllRead: 'সবগুলো পড়া হয়েছে চিহ্নিত করুন',
  noNotificationsYet: 'এখনো কোনো বিজ্ঞপ্তি নেই',
  loadMore: 'আরও দেখুন',
  familyOwner: 'পরিচর্যাকারী',
  memberNotSharing: 'এই সদস্য ওষুধের তথ্য শেয়ার করছেন না।',
  noDosesToday: 'আজ কোনো ডোজ নির্ধারিত নেই',
  familyEmptyHint: 'বিশ্বস্ত মানুষদের সাথে ওষুধের তথ্য শেয়ার করতে একটি পরিবার তৈরি করুন।',
  inviteSent: 'আমন্ত্রণ পাঠানো হয়েছে',
  invitedBy: 'আমন্ত্রণ জানিয়েছেন',
  familySharingNote: 'পরিবারের সদস্যরা আপনি আজ কোন ওষুধ খেয়েছেন বা খাননি তা দেখতে পারেন। প্রোফাইল থেকে এটি বন্ধ করতে পারেন।',
  inviteToSeeStatus: 'এখানে ওষুধের অবস্থা দেখতে কাউকে আমন্ত্রণ জানান।',
  showingSavedData: 'সংরক্ষিত তথ্য দেখানো হচ্ছে',
  statusNotShared: 'শেয়ার করা হয়নি',
  login: 'লগ ইন',
  register: 'নিবন্ধন',
  phone: 'ফোন নম্বর',
  password: 'পাসওয়ার্ড',
  confirmPassword: 'পাসওয়ার্ড নিশ্চিত করুন',
  name: 'পুরো নাম',
  address: 'ঠিকানা',
  addressOptional: 'ঠিকানা (ঐচ্ছিক)',
  loginButton: 'লগ ইন করুন',
  registerButton: 'অ্যাকাউন্ট তৈরি করুন',
  noAccountYet: 'অ্যাকাউন্ট নেই? নিবন্ধন করুন',
  alreadyHaveAccount: 'ইতিমধ্যে অ্যাকাউন্ট আছে? লগ ইন করুন',
  home: 'হোম',
  family: 'পরিবার',
  prescription: 'প্রেসক্রিপশন',
  health: 'স্বাস্থ্য',
  profile: 'প্রোফাইল',
  todaysMedicine: 'আজকের ওষুধ',
  healthReminders: 'স্বাস্থ্য রিমাইন্ডার',
  dueReminders: 'বাকি',
  upcomingReminders: 'আসন্ন',
  markComplete: 'সম্পন্ন হিসেবে চিহ্নিত করুন',
  healthRecords: 'স্বাস্থ্য রেকর্ড',
  addRecord: 'রেকর্ড যোগ করুন',
  recordType: 'ধরন',
  recordValue: 'মান',
  recordUnit: 'একক (ঐচ্ছিক)',
  recordNotes: 'নোট (ঐচ্ছিক)',
  save: 'সংরক্ষণ করুন',
  noHealthReminders: 'এই মুহূর্তে কোনো স্বাস্থ্য রিমাইন্ডার নেই',
  noHealthRecords: 'আপনি এখনো কোনো স্বাস্থ্য রেকর্ড যোগ করেননি',
  notMedicalAdviceDisclaimer:
      'এগুলো সাধারণ রিমাইন্ডার, চিকিৎসা পরামর্শ নয়। সবসময় ডাক্তার বা ফার্মাসিস্টের পরামর্শ নিন।',
  governmentNotices: 'সরকারি বিজ্ঞপ্তি',
  viewNotices: 'ঘোষণা দেখুন',
  noNoticesYet: 'এই মুহূর্তে কোনো বিজ্ঞপ্তি নেই',
  aiHealthSuggestions: 'এআই স্বাস্থ্য পরামর্শ',
  noHealthSuggestionsYet: 'এখনো কোনো এআই স্বাস্থ্য পরামর্শ নেই',
  quickActions: 'দ্রুত কার্যক্রম',
  uploadPrescription: 'প্রেসক্রিপশন আপলোড',
  aiAssistant: 'এআই সহকারী',
  comingSoon: 'শীঘ্রই আসছে',
  noItemsYet: 'এখনো কিছু নেই',
  somethingWentWrong: 'কিছু একটা সমস্যা হয়েছে',
  retry: 'আবার চেষ্টা করুন',
  offlineBanner: 'আপনি অফলাইনে আছেন — সংরক্ষিত তথ্য দেখানো হচ্ছে',
  syncingBanner: 'সিঙ্ক হচ্ছে…',
  pendingSyncBadge: 'সিঙ্ক বাকি',
  myFamily: 'আমার পরিবার',
  createFamily: 'পরিবার তৈরি করুন',
  inviteMember: 'সদস্য আমন্ত্রণ করুন',
  pendingInvitations: 'অপেক্ষমাণ আমন্ত্রণ',
  accept: 'গ্রহণ করুন',
  decline: 'প্রত্যাখ্যান করুন',
  familyName: 'পরিবারের নাম (ঐচ্ছিক)',
  invitePhoneHint: 'সদস্যের ফোন নম্বর',
  notInFamilyYet: 'আপনি এখনো কোনো পরিবারের অংশ নন',
  editProfile: 'প্রোফাইল সম্পাদনা',
  logout: 'লগ আউট',
  logoutConfirm: 'আপনি কি লগ আউট করতে চান?',
  changePassword: 'পাসওয়ার্ড পরিবর্তন করুন',
  currentPassword: 'বর্তমান পাসওয়ার্ড',
  newPassword: 'নতুন পাসওয়ার্ড',
  language: 'ভাষা',
  appearance: 'রঙের ধরন',
  themeSystem: 'ফোনের সেটিং',
  themeLight: 'হালকা',
  themeDark: 'গাঢ়',
  notifications: 'বিজ্ঞপ্তি',
  hideFromFamily: 'পরিবার থেকে লুকান',
  newPrescriptionEntry: 'নতুন প্রেসক্রিপশন এন্ট্রি',
  prescriptionNote: 'ফার্মাসিস্টের জন্য নোট',
  attachImage: 'ছবি সংযুক্ত করুন',
  saveDraft: 'সংরক্ষণ করুন',
  draftSavedOffline: 'এই ডিভাইসে সংরক্ষিত হয়েছে। এটি স্বয়ংক্রিয়ভাবে আপলোড হবে।',
  uploadPendingNotice:
      'সংযোগ পাওয়া মাত্র আপনার প্রেসক্রিপশন স্বয়ংক্রিয়ভাবে আপলোড হবে এবং '
      'শীঘ্রই একজন ফার্মাসিস্ট এটি পর্যালোচনা করবেন।',
  cancel: 'বাতিল',
  requiredField: 'এই ঘরটি পূরণ করা আবশ্যক',
  invalidPhone: 'সঠিক ফোন নম্বর দিন',
  passwordTooShort: 'পাসওয়ার্ড কমপক্ষে ৬ অক্ষরের হতে হবে',
  forgotPassword: 'পাসওয়ার্ড ভুলে গেছেন?',
  resetPasswordTitle: 'পাসওয়ার্ড রিসেট',
  forgotPasswordHelp: 'আপনার ফোন নম্বর দিন। অ্যাকাউন্ট থাকলে ওই ফোনে ৬ সংখ্যার একটি কোড পাঠানো হবে।',
  sendCode: 'কোড পাঠান',
  resetCodeSentNotice: 'এই নম্বরে অ্যাকাউন্ট থাকলে একটি কোড পাঠানো হয়েছে। নিচে লিখুন।',
  verificationCode: '৬ সংখ্যার কোড',
  saveNewPassword: 'নতুন পাসওয়ার্ড সংরক্ষণ করুন',
  passwordResetDone: 'পাসওয়ার্ড পরিবর্তন হয়েছে। নতুন পাসওয়ার্ড দিয়ে লগ ইন করুন।',
  backToLogin: 'লগইনে ফিরে যান',
  passwordChangedDone: 'পাসওয়ার্ড পরিবর্তন হয়েছে।',
  accountSection: 'অ্যাকাউন্ট',
  deleteAccount: 'অ্যাকাউন্ট মুছুন',
  deleteAccountWarning: 'এটি আপনার অ্যাকাউন্ট ও সব তথ্য স্থায়ীভাবে মুছে ফেলবে: প্রেসক্রিপশন, রুটিন, রিমাইন্ডার, স্বাস্থ্য রেকর্ড, সহকারীর কথোপকথন ও পরিবারের সদস্যপদ। এটি ফেরানো যাবে না।',
  deleteAccountPasswordPrompt: 'নিশ্চিত করতে আপনার পাসওয়ার্ড দিন।',
  deleteMyAccount: 'আমার অ্যাকাউন্ট মুছুন',
  passwordsDoNotMatch: 'পাসওয়ার্ড দুটি মিলছে না',
  statusPending: 'পর্যালোচনার অপেক্ষায়',
  statusCompleted: 'পর্যালোচিত',
  statusRejected: 'প্রত্যাখ্যাত',
  statusAwaitingConfirmation: 'নিশ্চিত করার অপেক্ষায়',
  statusActive: 'চলমান',
  statusEnded: 'শেষ',
  rejectionReason: 'কারণ',
  reuploadPrescription: 'আবার আপলোড করুন',
  reuploadHint:
      'এই প্রেসক্রিপশনের আরও পরিষ্কার একটি ছবি আপলোড করুন। ফার্মাসিস্ট তাঁর আগের মন্তব্যসহ এটি দেখবেন।',
  viewTodaysMedicine: 'আজকের ওষুধ দেখুন',
  noMedicineToday: 'আজকের জন্য কোনো ওষুধ নির্ধারিত নেই',
  noActiveRoutines: 'এখনো কোনো সক্রিয় ওষুধের রুটিন নেই',
  myMedicineRoutines: 'আমার ওষুধের রুটিন',
  doseTaken: 'নেওয়া হয়েছে',
  doseUpcoming: 'আসন্ন',
  pendingReview: 'ফার্মাসিস্টের পর্যালোচনার অপেক্ষায়',
  doseDue: 'এখনই সময়',
  doseMissed: 'মিস হয়েছে',
  markAsTaken: 'নেওয়া হয়েছে চিহ্নিত করুন',
  syncingBadge: 'সিঙ্ক হচ্ছে…',
  syncFailedBadge: 'সিঙ্ক ব্যর্থ হয়েছে',
  syncedBadge: 'সিঙ্ক হয়েছে',
  reminderCheckTitle: 'রিমাইন্ডার পরীক্ষা',
  reminderCheckHelp: 'অ্যাপ বন্ধ থাকলেও ওষুধের রিমাইন্ডার যেন সময়মতো পৌঁছায়, তা নিশ্চিত করুন।',
  remindersBlockedBanner: 'রিমাইন্ডার বন্ধ: বিজ্ঞপ্তি বন্ধ করা আছে। ঠিক করতে চাপুন।',
  remindersMayBeLateBanner: 'রিমাইন্ডার কয়েক মিনিট দেরিতে আসতে পারে। ঠিক করতে চাপুন।',
  notificationsPermissionLabel: 'বিজ্ঞপ্তি',
  notificationsAllowed: 'অনুমতি আছে',
  notificationsBlocked: 'বন্ধ: রিমাইন্ডার দেখাবে না',
  exactAlarmLabel: 'অ্যালার্ম ও রিমাইন্ডার',
  exactAlarmAllowed: 'অনুমতি আছে: রিমাইন্ডার সময়মতো আসবে',
  exactAlarmDenied: 'অনুমতি নেই: রিমাইন্ডার কয়েক মিনিট দেরিতে আসতে পারে',
  batteryLabel: 'ব্যাটারি অপ্টিমাইজেশন',
  batteryUnrestricted: 'সীমাবদ্ধ নয়',
  batteryRestricted: 'সীমাবদ্ধ: ফোন রিমাইন্ডার দেরি করাতে পারে। Medi-Bela-কে "অপ্টিমাইজ করবেন না" বা "কোনো সীমাবদ্ধতা নেই" করুন।',
  allowAction: 'অনুমতি দিন',
  openSettingsAction: 'সেটিংস খুলুন',
  reminderVendorTip: 'শাওমি, রিয়েলমি, অপো ও ভিভো ফোনে Medi-Bela-র জন্য Autostart চালু করুন এবং সাম্প্রতিক অ্যাপের তালিকায় এটি লক করে রাখুন।',
  reminderTitle: 'ওষুধ খাওয়ার সময়',
  reminderBodyOne: '{time}-এ একটি ওষুধ খাওয়ার সময়। কোনটি দেখতে অ্যাপ খুলুন।',
  reminderBodyMany: '{time}-এ {count}টি ওষুধ খাওয়ার সময়। কোনগুলো দেখতে অ্যাপ খুলুন।',
  reminderDoneAction: 'নিয়েছি',
  reminderLaterAction: 'পরে (৩০ মিনিট)',
  medicineRemindersLabel: 'ওষুধের রিমাইন্ডার',
  medicineRemindersHelp: 'প্রতিটি ওষুধের সময়ে বাজবে, অফলাইনেও। কোনো ডোজ মিস হলে আপনার পরিবারকে জানানো হবে।',
  medicineRemindersOffTitle: 'ওষুধের রিমাইন্ডার বন্ধ করবেন?',
  medicineRemindersOffWarning: 'আপনি কোনো ওষুধের রিমাইন্ডার পাবেন না, এবং ডোজ মিস হলে আপনার পরিবারকে জানানো হবে না।',
  turnOffAction: 'বন্ধ করুন',
  noticesLabel: 'বিজ্ঞপ্তি বোর্ড',
  noticesHelp: 'Medi-Bela-র স্বাস্থ্য বিজ্ঞপ্তি। বন্ধ থাকলেও অ্যাপে পড়তে পারবেন।',
  inboxPersonalTab: 'ব্যক্তিগত',
  inboxFamilyTab: 'পরিবার',
  inboxGeneralTab: 'সাধারণ',
  byCaregiver: 'পরিচর্যাকারী করেছেন',
  selfAdded: 'নিজে যোগ করা',
  addedByCaregiver: 'পরিচর্যাকারী যোগ করেছেন',
  editedByYou: 'আপনি পরিবর্তন করেছেন',
  editedByCaregiver: 'পরিচর্যাকারী পরিবর্তন করেছেন',
  confirmPrescriptionTitle: 'আপনার ওষুধ নিশ্চিত করুন',
  confirmPrescriptionHelp: 'আপনার ফার্মাসিস্ট এই ওষুধগুলো প্রস্তুত করেছেন। আপনি ওষুধ খাওয়ার সময়, শুরুর তারিখ বা খাবারের সময় বদলাতে পারেন, অথবা কোনো ওষুধ বাদ দিতে পারেন। নিশ্চিত করলে রিমাইন্ডার শুরু হবে।',
  confirmAndStartReminders: 'নিশ্চিত করুন ও রিমাইন্ডার শুরু করুন',
  prescriptionConfirmedDone: 'নিশ্চিত হয়েছে। আপনার রিমাইন্ডার শুরু হয়েছে।',
  alreadyConfirmed: 'এই প্রেসক্রিপশন আগেই নিশ্চিত করা হয়েছে।',
  keepOneMedicine: 'নিশ্চিত করতে অন্তত একটি ওষুধ রাখুন।',
  reviewAndConfirm: 'দেখে নিশ্চিত করুন',
  removeMedicine: 'বাদ দিন',
  undoRemove: 'রেখে দিন',
  removeMedicineConfirm: 'এই ওষুধ বন্ধ করবেন? এখন থেকে এর রিমাইন্ডার বন্ধ হবে। আগের ডোজের তথ্য থেকে যাবে।',
  doseTimes: 'ওষুধ খাওয়ার সময়',
  startDate: 'শুরুর তারিখ',
  startsWhenConfirmed: 'যেদিন নিশ্চিত করবেন',
  today: 'আজ',
  mealTiming: 'খাবারের সময়',
  notSpecified: 'উল্লেখ নেই',
  continuousLabel: 'চলমান (শেষ তারিখ নেই)',
  continuousHelp: 'ডাক্তার বন্ধ করতে না বলা পর্যন্ত চলবে।',
  daysCountTemplate: '{n} দিন',
  myMedicines: 'আমার ওষুধ',
  medicinesOfTemplate: '{name}-এর ওষুধ',
  manageMedicines: 'পরিচালনা করুন',
  addMedicine: 'ওষুধ যোগ করুন',
  editMedicine: 'ওষুধ পরিবর্তন',
  pharmacistMedicineLimited: 'এই ওষুধটি ফার্মাসিস্ট ঠিক করেছেন। আপনি ওষুধ খাওয়ার সময় ও খাবারের সময় বদলাতে পারবেন।',
  medicineName: 'ওষুধের নাম',
  strength: 'শক্তি (মাত্রা)',
  doseAmount: 'প্রতিবারের পরিমাণ',
  timesPerDay: 'দিনে কতবার',
  numberOfDays: 'কত দিন',
  numberOfDaysInvalid: '১ থেকে ৩৬৫ দিন লিখুন',
  timesMustDiffer: 'প্রতিটি ডোজের জন্য আলাদা সময় দিন।',
  prescriptionsOfTemplate: '{name}-এর প্রেসক্রিপশন',
  uploadedForMember: 'আপলোড হয়েছে। ফার্মাসিস্ট এটি প্রস্তুত করবেন।',
  takePhoto: 'ছবি তুলুন',
  caregiverActingHint: 'পরিচর্যাকারী হিসেবে আপনি তাঁর ওষুধ ও প্রেসক্রিপশন পরিচালনা করতে পারেন। প্রতিটি পরিবর্তনের কথা তাঁকে জানানো হয়।',
  medicinesButton: 'ওষুধ',
  prescriptionsButton: 'প্রেসক্রিপশন',
  invitationWarning: 'যোগ দিলে যিনি আমন্ত্রণ জানিয়েছেন তিনি আপনার পরিচর্যাকারী হবেন। তিনি আপনার ওষুধ দেখতে, কোনো ডোজ মিস হলে সতর্কতা পেতে এবং আপনার ওষুধ ও প্রেসক্রিপশন পরিচালনা করতে পারবেন। ডোজ নেওয়া হয়েছে বলে শুধু আপনিই চিহ্নিত করবেন। প্রোফাইল থেকে নিজেকে পরিবারের কাছে লুকাতে পারবেন।',
  editYourDetails: 'আপনার তথ্য সম্পাদনা করুন',
  detailsSaved: 'আপনার তথ্য সংরক্ষিত হয়েছে।',
  dateOfBirth: 'জন্ম তারিখ',
  gender: 'লিঙ্গ',
  division: 'বিভাগ',
  district: 'জেলা',
  upazila: 'উপজেলা',
  couldNotLoadOptions: 'তালিকা লোড করা যায়নি। ইন্টারনেট সংযোগ দেখুন।',
  allNotices: 'সব নোটিশ',
  noticeSource: 'সূত্র',
);
