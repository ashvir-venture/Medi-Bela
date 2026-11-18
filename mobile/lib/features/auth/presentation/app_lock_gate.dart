import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../router/app_router.dart';
import '../../../widgets/app_logo.dart';
import '../data/app_lock.dart';
import 'auth_controller.dart';
import 'session_notifier.dart';

/// Round 18: puts the fingerprint lock over the whole app while it is
/// locked and signed in, except on the pages a ringing reminder opens.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = ref.read(appLockControllerProvider.notifier);
    if (state == AppLifecycleState.paused) lock.appPaused();
    if (state == AppLifecycleState.resumed) lock.appResumed();
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockControllerProvider);
    final signedIn = ref.watch(sessionNotifierProvider) == true;
    if (!lock.locked || !signedIn) return widget.child;
    final router = ref.watch(appRouterProvider);
    return ListenableBuilder(
      listenable: router.routerDelegate,
      builder: (context, _) {
        final path = router.routerDelegate.currentConfiguration.uri.path;
        if (lockSkipsRoute(path)) return widget.child;
        return Stack(children: [
          // Kept alive underneath, so unlocking returns to the same page.
          Offstage(child: widget.child),
          const AppLockScreen(),
        ]);
      },
    );
  }
}

class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    // Ask at once; the button below asks again after a cancel.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
  }

  Future<void> _ask() async {
    if (_asking || !mounted) return;
    setState(() => _asking = true);
    await ref.read(appLockControllerProvider.notifier).unlock(ref.read(stringsProvider).r18.unlockReason);
    if (mounted) setState(() => _asking = false);
  }

  Future<void> _usePassword() async {
    ref.read(appLockControllerProvider.notifier).reset();
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) GoRouter.maybeOf(context)?.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = ref.watch(stringsProvider);
    final s = strings.r18;
    final p = context.palette;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Center(child: AppLogo(height: 72)),
              const SizedBox(height: 24),
              Icon(Icons.fingerprint_rounded, size: 72, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(s.lockedTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(s.lockedSub, textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: AppType.body)),
              const Spacer(),
              FilledButton.icon(
                key: const ValueKey('app-lock-unlock'),
                onPressed: _asking ? null : _ask,
                icon: const Icon(Icons.fingerprint_rounded),
                label: Text(s.unlock),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('app-lock-password'),
                onPressed: _usePassword,
                child: Text(s.usePasswordInstead),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
