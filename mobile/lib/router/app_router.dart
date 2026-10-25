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
import '../features/health/presentation/health_reminders_screen.dart';
import '../features/health/presentation/health_screen.dart';
import '../features/health/presentation/health_suggestions_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/medicine_schedule/presentation/today_medicine_screen.dart';
import '../features/notices/presentation/notices_screen.dart';
import '../features/prescription/presentation/prescription_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../widgets/main_scaffold.dart';

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
    redirect: (context, state) {
      final loggedIn = ref.read(sessionNotifierProvider);
      final goingToAuth = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.forgotPassword ||
          state.matchedLocation == AppRoutes.resetPassword;

      // Session not yet determined (app just launched): hold on the splash
      // screen so Home is never flashed before the login screen.
      final atSplash = state.matchedLocation == AppRoutes.splash;
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
            builder: (context, state) => const FamilyScreen(),
          ),
          GoRoute(
            path: AppRoutes.familyMember,
            builder: (context, state) =>
                MemberStatusScreen(userId: state.pathParameters['userId']!),
          ),
          GoRoute(
            path: AppRoutes.assistant,
            builder: (context, state) => const AssistantConversationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.assistantChat,
            builder: (context, state) => const AssistantScreen(),
          ),
          GoRoute(
            path: AppRoutes.assistantConversation,
            builder: (context, state) =>
                AssistantScreen(conversationId: state.pathParameters['id']),
          ),
          GoRoute(
            path: AppRoutes.inbox,
            builder: (context, state) => const InboxScreen(),
          ),
          GoRoute(
            path: AppRoutes.prescription,
            builder: (context, state) => const PrescriptionScreen(),
          ),
          GoRoute(
            path: AppRoutes.todaysMedicine,
            builder: (context, state) => const TodaysMedicineScreen(),
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
            builder: (context, state) => const NoticesScreen(),
          ),
          GoRoute(
            path: AppRoutes.diabetes,
            builder: (context, state) => const DiabetesTrackerScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});
