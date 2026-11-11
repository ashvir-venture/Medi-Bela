import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/session_notifier.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/assistant/presentation/assistant_conversations_screen.dart';
import '../features/assistant/presentation/assistant_screen.dart';
import '../features/family/presentation/family_screen.dart';
import '../features/family/presentation/member_status_screen.dart';
import '../features/family/presentation/change_history_screen.dart';
import '../widgets/first_use_tips.dart';
import '../features/inbox/presentation/inbox_screen.dart';
import '../features/care/presentation/care_providers.dart' show CareSubject;
import '../features/care/presentation/condition_screen.dart';
import '../features/care/presentation/doctor_report_screen.dart';
import '../features/care/presentation/insulin_screen.dart';
import '../features/care/presentation/limits_screen.dart';
import '../features/care/presentation/my_care_screen.dart';
import '../features/care/presentation/reading_screen.dart';
import '../features/care/presentation/records_screens.dart';
import '../features/care/presentation/test_form_screen.dart';
import '../features/care/presentation/visit_form_screen.dart';
import '../features/health/presentation/health_records_screen.dart';
import '../features/help/presentation/help_screens.dart';
import '../features/health/presentation/health_reminders_screen.dart';
import '../features/health/presentation/health_screen.dart';
import '../features/health/presentation/health_suggestions_screen.dart';
import '../features/health/presentation/personal_reminders_screen.dart';
import '../features/medicine_box/presentation/medicine_box_screens.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/medicine_schedule/presentation/medicines_tab_screen.dart';
import '../features/medicine_schedule/presentation/my_medicines_screen.dart';
import '../features/medicine_schedule/presentation/routine_form_screen.dart';
import '../features/notices/presentation/notices_screen.dart';
import '../features/prescription/presentation/confirm_prescription_screen.dart';
import '../features/prescription/presentation/member_prescriptions_screen.dart';
import '../features/profile/presentation/edit_details_screen.dart';
import '../features/profile/presentation/delete_account_screens.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/profile/presentation/settings_screen.dart';
import '../features/reminders/presentation/full_screen_permission_screen.dart';
import '../features/reminders/presentation/reminder_check_screen.dart';
import '../features/reminders/presentation/notification_look_screen.dart';
import '../features/reminders/presentation/reminder_pages.dart';
import '../features/reminders/presentation/reminder_rules_screen.dart';
import '../widgets/main_scaffold.dart';
import '../widgets/not_found_screen.dart';
import '../widgets/state_views.dart';

class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const home = '/home';
  static const family = '/family';
  static const familyMember = '/family/member/:userId';
  static const inbox = '/inbox';
  static const assistant = '/assistant';
  static const assistantChat = '/assistant/chat';
  static const assistantConversation = '/assistant/chat/:id';
  static String assistantConversationPath(String id) => '/assistant/chat/$id';
  static const prescription = '/prescription';
  static const todaysMedicine = '/prescription/today';
  static const health = '/health';
  static const healthReminders = '/health/reminders';
  static const healthRecords = '/health/records';
  /// Round 14: the quick-add "Log a reading" (opens the add sheet at once).
  /// Round 15: "Log a reading" (quick add and Health tiles).
  static const healthRecordsAdd = '/health/reading';
  /// The plain list of every reading (before Round 16 this was /health/records).
  static const healthReadings = '/health/readings';
  static const healthSuggestions = '/health/suggestions';
  static const notices = '/notices';
  static const diabetes = '/diabetes';
  static const profile = '/profile';
  static const reminderCheck = '/profile/reminders';
  static const fullScreenSetup = '/profile/reminders/full-screen';
  // Round 14: the user's own reminder timings, and what notifications look like.
  static const reminderRules = '/profile/reminders/rules';
  static const notificationLook = '/profile/reminders/look';
  // Round 13: personal reminders and the medicine box (?for=&name= = a
  // caregiver looking after a member).
  static const personalReminders = '/health/personal-reminders';
  static const personalReminderForm = '/health/personal-reminders/form';
  static String personalRemindersPath({String? forUserId, String? name}) => Uri(
        path: personalReminders,
        queryParameters: {if (forUserId != null) 'for': forUserId, if (name != null) 'name': name},
      ).toString();
  static const medicineBox = '/medicine-box';
  static String medicineBoxPath({String? forUserId, String? name}) => Uri(
        path: medicineBox,
        queryParameters: {if (forUserId != null) 'for': forUserId, if (name != null) 'name': name},
      ).toString();
  static const medicineBoxForm = '/medicine-box/refill';
  static String medicineBoxFormPath({String? routineId, String? forUserId}) => Uri(
        path: medicineBoxForm,
        queryParameters: {if (routineId != null) 'routine': routineId, if (forUserId != null) 'for': forUserId},
      ).toString();
  static const medicineBoxEmpty = '/medicine-box/empty';
  static const editDetails = '/profile/details';
  static const settings = '/profile/settings';
  static const deleteAccount = '/profile/settings/delete';
  static const deleteAccountConfirm = '/profile/settings/delete/confirm';
  // Help & about (Round 11): full-screen pages; Privacy & terms is open while
  // signed out too (the sign-up consent links to it).
  static const privacyTerms = '/help/privacy';
  static const support = '/help/support';
  static const aboutUs = '/help/about';
  // Round 12: the page a reminder notification opens (?at=<ms>&stage=<n>).
  static const doseReminder = '/reminder';
  static const testReminder = '/test-reminder/:id';

  // Round 6. `for` = the family member a caregiver acts for.
  // Round 10: without `for`, /medicines is the Medicines tab (?tab=today |
  // mine | prescriptions); /prescription and /prescription/today redirect there.
  static const medicines = '/medicines';
  static String medicinesTabPath(String tab) => Uri(path: medicines, queryParameters: {'tab': tab}).toString();
  static String medicinesPath({String? forUserId, String? name}) => Uri(
        path: medicines,
        queryParameters: {if (forUserId != null) 'for': forUserId, if (name != null) 'name': name},
      ).toString();
  static const medicineForm = '/medicines/form';
  static const confirmPrescription = '/prescription/confirm/:id';
  static String confirmPrescriptionPath(String id, {String? forUserId}) => Uri(
        path: '/prescription/confirm/$id',
        queryParameters: {if (forUserId != null) 'for': forUserId},
      ).toString();
  static const memberPrescriptions = '/family/member/:userId/prescriptions';
  // Round 17: change history (mine; the caregiver's view of a member).
  static const familyChanges = '/family/changes';
  static const memberChanges = '/family/member/:userId/changes';
  static String memberChangesPath(String userId, String name) =>
      Uri(path: '/family/member/$userId/changes', queryParameters: {'name': name}).toString();
  static String memberPrescriptionsPath(String userId, String name) =>
      Uri(path: '/family/member/$userId/prescriptions', queryParameters: {'name': name}).toString();
}

/// Bridges Riverpod's [sessionNotifierProvider] to GoRouter's
/// `refreshListenable`, so a login/logout anywhere in the app immediately
/// re-runs the redirect logic below without any manual navigation calls.
class _RouterRefreshNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();
  ref.listen<bool?>(sessionNotifierProvider, (_, __) => refreshNotifier.ping());
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshNotifier,
    // An unknown route or a bad deep link: "Page not found" + Go to Home.
    errorBuilder: (context, state) => const NotFoundScreen(),
    redirect: (context, state) {
      final loggedIn = ref.read(sessionNotifierProvider);
      final goingToAuth = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.forgotPassword ||
          state.matchedLocation == AppRoutes.resetPassword;

      // Session not yet determined (app just launched): hold on the splash
      // screen so Home is never flashed before the login screen.
      final atSplash = state.matchedLocation == AppRoutes.splash;
      // Help & about pages open in either state, with nothing to redirect.
      if (state.matchedLocation.startsWith('/help/')) return null;
      if (loggedIn == null) return atSplash ? null : AppRoutes.splash;
      if (atSplash) return loggedIn ? AppRoutes.home : AppRoutes.login;

      if (!loggedIn && !goingToAuth) return AppRoutes.login;
      if (loggedIn && goingToAuth) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.privacyTerms,
        builder: (context, state) => const PrivacyTermsScreen(),
      ),
      GoRoute(
        path: AppRoutes.support,
        builder: (context, state) => const SupportScreen(),
      ),
      GoRoute(
        path: AppRoutes.aboutUs,
        builder: (context, state) => const AboutUsScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        // The phone typed on the previous screen (editable there as well).
        builder: (context, state) =>
            ResetPasswordScreen(initialPhone: state.extra as String?),
      ),
      // Tapping a reminder (not its buttons): full-screen, no bottom tabs.
      GoRoute(
        path: AppRoutes.doseReminder,
        builder: (context, state) {
          final ms = int.tryParse(state.uri.queryParameters['at'] ?? '');
          if (ms == null) return const NotFoundScreen();
          return DoseReminderScreen(
            at: DateTime.fromMillisecondsSinceEpoch(ms),
            stage: int.tryParse(state.uri.queryParameters['stage'] ?? '') ?? 0,
            alarm: state.uri.queryParameters['alarm'] == '1',
          );
        },
      ),
      // "A medicine ran out": full screen, like a reminder.
      GoRoute(
        path: AppRoutes.medicineBoxEmpty,
        builder: (context, state) {
          final routine = state.uri.queryParameters['routine'];
          if (routine == null) return const NotFoundScreen();
          return MedicineBoxEmptyScreen(routineId: routine, alarm: state.uri.queryParameters['alarm'] == '1');
        },
      ),
      GoRoute(
        path: AppRoutes.testReminder,
        builder: (context, state) => TestReminderScreen(
          reminderId: state.pathParameters['id']!,
          day: int.tryParse(state.uri.queryParameters['day'] ?? '') ?? 0,
          alarm: state.uri.queryParameters['alarm'] == '1',
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            // Round 17: first-use tips (easy mode has its own Home, no tips).
            builder: (context, state) => const _HomeWithTips(),
          ),
          GoRoute(
            path: AppRoutes.family,
            builder: (context, state) =>
                const FirstUseTips(screen: TipsScreen.family, child: OnlineOnly(child: FamilyScreen())),
          ),
          GoRoute(
            path: AppRoutes.familyMember,
            builder: (context, state) =>
                OnlineOnly(child: MemberStatusScreen(userId: state.pathParameters['userId']!)),
          ),
          GoRoute(
            path: AppRoutes.assistant,
            builder: (context, state) => const OnlineOnly(child: AssistantConversationsScreen()),
          ),
          GoRoute(
            path: AppRoutes.assistantChat,
            builder: (context, state) => const OnlineOnly(child: AssistantScreen()),
          ),
          GoRoute(
            path: AppRoutes.assistantConversation,
            builder: (context, state) =>
                OnlineOnly(child: AssistantScreen(conversationId: state.pathParameters['id'])),
          ),
          GoRoute(
            path: AppRoutes.inbox,
            builder: (context, state) => const InboxScreen(),
          ),
          // Old addresses (pushes, links) open the Medicines tab's segment.
          GoRoute(
            path: AppRoutes.prescription,
            redirect: (context, state) => AppRoutes.medicinesTabPath('prescriptions'),
          ),
          GoRoute(
            path: AppRoutes.todaysMedicine,
            redirect: (context, state) => AppRoutes.medicinesTabPath('today'),
          ),
          GoRoute(
            path: AppRoutes.health,
            builder: (context, state) => const FirstUseTips(screen: TipsScreen.health, child: HealthScreen()),
          ),
          GoRoute(
            path: AppRoutes.healthReminders,
            builder: (context, state) => const HealthRemindersScreen(),
          ),
          // Rounds 15-16: my care, readings, limits, condition pages, insulin,
          // health records 2.0. `?for=&name=` = the caregiver for a member (online).
          GoRoute(
            path: AppRoutes.healthReadings,
            builder: (context, state) => HealthRecordsScreen(openAdd: state.uri.queryParameters['add'] == '1'),
          ),
          GoRoute(
            path: AppRoutes.healthRecords,
            builder: (context, state) => _careRoute(state, (who) => RecordsScreen(who: who)),
          ),
          GoRoute(
            path: '/health/my-care',
            builder: (context, state) => _careRoute(
              state,
              (who) => MyCareScreen(signupStep: state.uri.queryParameters['step'] == '1', who: who),
            ),
          ),
          GoRoute(
            path: '/health/reading',
            builder: (context, state) => _careRoute(state, (who) => ReadingScreen(initialType: state.uri.queryParameters['type'], who: who)),
          ),
          GoRoute(
            path: '/health/limits',
            builder: (context, state) => _careRoute(state, (who) => LimitsScreen(who: who)),
          ),
          GoRoute(
            path: '/health/care/:code',
            builder: (context, state) => _careRoute(state, (who) => ConditionScreen(code: state.pathParameters['code']!, who: who)),
          ),
          GoRoute(
            path: '/health/insulin',
            builder: (context, state) => _careRoute(state, (who) => InsulinScreen(who: who)),
          ),
          GoRoute(
            path: '/health/records/test',
            builder: (context, state) {
              final q = state.uri.queryParameters;
              return _careRoute(
                state,
                (who) => TestFormScreen(id: q['id'], kind: q['kind'], done: q['done'] == '1', reminderId: q['reminder'], condition: q['condition'], who: who),
              );
            },
          ),
          GoRoute(
            path: '/health/records/report/:id',
            builder: (context, state) => _careRoute(state, (who) => TestReportScreen(id: state.pathParameters['id']!, who: who)),
          ),
          GoRoute(
            path: '/health/records/visit',
            builder: (context, state) {
              final q = state.uri.queryParameters;
              return _careRoute(state, (who) => VisitFormScreen(id: q['id'], kind: q['kind'] ?? 'VISIT', condition: q['condition'], who: who));
            },
          ),
          GoRoute(
            path: '/health/records/rx',
            builder: (context, state) => _careRoute(state, (who) => RecordPrescriptionScreen(id: state.uri.queryParameters['id'], who: who)),
          ),
          GoRoute(
            path: '/health/records/pdf',
            builder: (context, state) => const DoctorReportScreen(),
          ),
          GoRoute(
            path: AppRoutes.healthSuggestions,
            builder: (context, state) => const HealthSuggestionsScreen(),
          ),
          GoRoute(
            path: AppRoutes.notices,
            // ?id= (from a push or the inbox) shows that notice first, highlighted.
            builder: (context, state) => NoticesScreen(highlightId: state.uri.queryParameters['id']),
          ),
          // Round 15: the diabetes page replaces the earlier placeholder tracker.
          GoRoute(
            path: AppRoutes.diabetes,
            redirect: (context, state) => '/health/care/diabetes',
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.medicineBox,
            builder: (context, state) {
              final forUserId = state.uri.queryParameters['for'];
              final screen = MedicineBoxScreen(forUserId: forUserId, memberName: state.uri.queryParameters['name']);
              return forUserId == null ? screen : OnlineOnly(child: screen);
            },
          ),
          GoRoute(
            path: AppRoutes.medicineBoxForm,
            builder: (context, state) => OnlineOnly(
              child: MedicineBoxFormScreen(
                routineId: state.uri.queryParameters['routine'],
                forUserId: state.uri.queryParameters['for'],
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.personalReminders,
            builder: (context, state) {
              final forUserId = state.uri.queryParameters['for'];
              final screen = PersonalRemindersScreen(forUserId: forUserId, memberName: state.uri.queryParameters['name']);
              return forUserId == null ? screen : OnlineOnly(child: screen);
            },
          ),
          GoRoute(
            path: AppRoutes.personalReminderForm,
            builder: (context, state) => OnlineOnly(
              child: PersonalReminderFormScreen(
                args: state.extra as PersonalRemindersArgs? ?? const PersonalRemindersArgs(),
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.fullScreenSetup,
            builder: (context, state) => const FullScreenPermissionScreen(),
          ),
          GoRoute(
            path: AppRoutes.reminderRules,
            builder: (context, state) => const ReminderRulesScreen(),
          ),
          GoRoute(
            path: AppRoutes.notificationLook,
            builder: (context, state) => const NotificationLookScreen(),
          ),
          GoRoute(
            path: AppRoutes.reminderCheck,
            builder: (context, state) => const ReminderCheckScreen(),
          ),
          GoRoute(
            path: AppRoutes.editDetails,
            builder: (context, state) => const EditDetailsScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.deleteAccount,
            builder: (context, state) => const DeleteAccountWarningScreen(),
          ),
          GoRoute(
            path: AppRoutes.deleteAccountConfirm,
            builder: (context, state) => const DeleteAccountConfirmScreen(),
          ),
          GoRoute(
            path: AppRoutes.medicines,
            builder: (context, state) {
              final forUserId = state.uri.queryParameters['for'];
              // A caregiver's view of a member: its own page (under Family).
              if (forUserId != null) {
                return OnlineOnly(
                  child: MyMedicinesScreen(forUserId: forUserId, memberName: state.uri.queryParameters['name']),
                );
              }
              return FirstUseTips(
                screen: TipsScreen.medicines,
                child: MedicinesTabScreen(segment: MedicinesSegment.parse(state.uri.queryParameters['tab'])),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.medicineForm,
            builder: (context, state) =>
                RoutineFormScreen(args: state.extra as RoutineFormArgs? ?? const RoutineFormArgs()),
          ),
          GoRoute(
            path: AppRoutes.confirmPrescription,
            builder: (context, state) => OnlineOnly(
              child: ConfirmPrescriptionScreen(
                prescriptionId: state.pathParameters['id']!,
                forUserId: state.uri.queryParameters['for'],
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.memberPrescriptions,
            builder: (context, state) => OnlineOnly(
              child: MemberPrescriptionsScreen(
                userId: state.pathParameters['userId']!,
                memberName: state.uri.queryParameters['name'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.familyChanges,
            builder: (context, state) => const OnlineOnly(child: ChangeHistoryScreen()),
          ),
          GoRoute(
            path: AppRoutes.memberChanges,
            builder: (context, state) => OnlineOnly(
              child: ChangeHistoryScreen(
                memberId: state.pathParameters['userId'],
                memberName: state.uri.queryParameters['name'],
              ),
            ),
          ),
        ],
      ),
    ],
  );
});

/// A care screen for me, or for a member (`?for=&name=`, online only).
Widget _careRoute(GoRouterState state, Widget Function(CareSubject who) build) {
  final who = subjectFromQuery(state.uri.queryParameters);
  return who.isMember ? OnlineOnly(child: build(who)) : build(who);
}

/// Home with its first-use tips, none in easy mode (its own simple Home).
class _HomeWithTips extends ConsumerWidget {
  const _HomeWithTips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final easyMode = ref.watch(authControllerProvider.select((u) => u.value?.easyMode ?? false));
    return FirstUseTips(screen: TipsScreen.home, enabled: !easyMode, child: const HomeScreen());
  }
}
