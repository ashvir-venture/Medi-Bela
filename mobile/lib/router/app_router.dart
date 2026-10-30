import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/session_notifier.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/assistant/presentation/assistant_conversations_screen.dart';
import '../features/assistant/presentation/assistant_screen.dart';
import '../features/diabetes/presentation/diabetes_tracker_screen.dart';
import '../features/family/presentation/family_screen.dart';
import '../features/family/presentation/member_status_screen.dart';
import '../features/inbox/presentation/inbox_screen.dart';
import '../features/health/presentation/health_records_screen.dart';
import '../features/help/presentation/help_screens.dart';
import '../features/health/presentation/health_reminders_screen.dart';
import '../features/health/presentation/health_screen.dart';
import '../features/health/presentation/health_suggestions_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/medicine_schedule/presentation/medicines_tab_screen.dart';
import '../features/medicine_schedule/presentation/my_medicines_screen.dart';
import '../features/medicine_schedule/presentation/routine_form_screen.dart';
import '../features/medicine_schedule/presentation/today_medicine_screen.dart';
import '../features/notices/presentation/notices_screen.dart';
import '../features/prescription/presentation/confirm_prescription_screen.dart';
import '../features/prescription/presentation/member_prescriptions_screen.dart';
import '../features/prescription/presentation/prescription_screen.dart';
import '../features/profile/presentation/edit_details_screen.dart';
import '../features/profile/presentation/delete_account_screens.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/profile/presentation/settings_screen.dart';
import '../features/reminders/presentation/reminder_check_screen.dart';
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
  static const healthSuggestions = '/health/suggestions';
  static const notices = '/notices';
  static const diabetes = '/diabetes';
  static const profile = '/profile';
  static const reminderCheck = '/profile/reminders';
  static const editDetails = '/profile/details';
  static const settings = '/profile/settings';
  static const deleteAccount = '/profile/settings/delete';
  static const deleteAccountConfirm = '/profile/settings/delete/confirm';
  // Help & about (Round 11): full-screen pages; Privacy & terms is open while
  // signed out too (the sign-up consent links to it).
  static const privacyTerms = '/help/privacy';
  static const support = '/help/support';
  static const aboutUs = '/help/about';

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
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.family,
            builder: (context, state) => const OnlineOnly(child: FamilyScreen()),
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
            builder: (context, state) => const HealthScreen(),
          ),
          GoRoute(
            path: AppRoutes.healthReminders,
            builder: (context, state) => const HealthRemindersScreen(),
          ),
          GoRoute(
            path: AppRoutes.healthRecords,
            builder: (context, state) => const HealthRecordsScreen(),
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
          GoRoute(
            path: AppRoutes.diabetes,
            builder: (context, state) => const DiabetesTrackerScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfileScreen(),
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
              return MedicinesTabScreen(segment: MedicinesSegment.parse(state.uri.queryParameters['tab']));
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
        ],
      ),
    ],
  );
});
