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
    required this.notifications,
    required this.visibleToFamily,
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
    required this.rejectionReason,
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
  final String notifications;
  final String visibleToFamily;
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
  final String rejectionReason;
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
  pushNotificationsHelp: 'Family alerts, prescription updates and notices. Medicine reminders on this phone always work, even offline.',
  privacySettings: 'Privacy',
  privacyHelp: 'When on, family members can see your name, address and whether you took or missed today\'s medicines. When off, they see none of this and get no missed-dose alerts about you.',
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
  familyOwner: 'Owner',
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
  notifications: 'Notifications',
  visibleToFamily: 'Visible to family',
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
  statusCompleted: 'Completed',
  statusRejected: 'Rejected',
  rejectionReason: 'Reason',
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
  pushNotificationsHelp: 'পরিবারের সতর্কতা, প্রেসক্রিপশনের হালনাগাদ ও বিজ্ঞপ্তি। এই ফোনে ওষুধের রিমাইন্ডার অফলাইনেও সবসময় কাজ করে।',
  privacySettings: 'গোপনীয়তা',
  privacyHelp: 'চালু থাকলে পরিবারের সদস্যরা আপনার নাম, ঠিকানা এবং আজ ওষুধ খেয়েছেন কি না দেখতে পারেন। বন্ধ থাকলে তারা কিছুই দেখতে পারেন না এবং আপনার ওষুধ মিস হলে সতর্কতাও পান না।',
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
  familyOwner: 'মালিক',
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
  notifications: 'বিজ্ঞপ্তি',
  visibleToFamily: 'পরিবারের কাছে দৃশ্যমান',
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
  statusCompleted: 'সম্পন্ন',
  statusRejected: 'প্রত্যাখ্যাত',
  rejectionReason: 'কারণ',
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
);
