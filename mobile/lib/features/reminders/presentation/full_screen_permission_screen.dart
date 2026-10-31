import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/core_providers.dart';
import '../../../router/app_router.dart';
import '../../../widgets/state_views.dart';
import 'reminder_status_controller.dart';

/// Two steps to let reminders open as a full screen (Round 13): "Display
/// over other apps" (phone in use) and, on Android 14+, full-screen
/// notifications (locked phone). Each opens the system page; the ticks update
/// when the user comes back. Without them the ringing banner stays.
class FullScreenPermissionScreen extends ConsumerWidget {
  const FullScreenPermissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final service = ref.watch(reminderStatusServiceProvider);
    final status = ref.watch(reminderStatusProvider);
    final theme = Theme.of(context);

    return ReminderStatusRefresher(
      child: Scaffold(
        appBar: AppBar(title: Text(strings.fullScreenTitle)),
        body: status.when(
          loading: () => const LoadingView(),
          error: (_, _) => const SizedBox.shrink(),
          data: (s) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Icon(Icons.alarm_on, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(strings.fullScreenHelp, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 20),
              _Step(
                number: 1,
                title: strings.overlayLabel,
                help: strings.overlayStepHelp,
                done: s.overlayAllowed,
                doneText: strings.overlayAllowed,
                actionLabel: strings.allowAction,
                onAction: service.requestOverlay,
              ),
              _Step(
                number: 2,
                title: strings.fullScreenIntentLabel,
                help: strings.fullScreenStepHelp,
                done: s.fullScreenAllowed,
                doneText: strings.fullScreenIntentAllowed,
                actionLabel: strings.allowAction,
                onAction: service.requestFullScreen,
              ),
              const SizedBox(height: 8),
              Text(strings.fullScreenFallback, style: TextStyle(color: context.palette.muted)),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.home),
                child: Text(s.fullScreenReady ? strings.close : strings.notNow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.help,
    required this.done,
    required this.doneText,
    required this.actionLabel,
    required this.onAction,
  });

  final int number;
  final String title;
  final String help;
  final bool done;
  final String doneText;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: done ? context.palette.success : theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  child: done ? const Icon(Icons.check, size: 18) : Text('$number'),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 8),
            Text(done ? doneText : help, style: done ? TextStyle(color: context.palette.success) : null),
            if (!done) ...[
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Asks once (after sign-in, on Home) whether to set up full-screen
/// reminders, like the notifications prompt at first start. "Not now" is
/// remembered; Reminder check keeps both steps for later.
class FullScreenPromptOnce extends ConsumerStatefulWidget {
  const FullScreenPromptOnce({super.key});

  static const prefsKey = 'fullScreenPromptShown';

  @override
  ConsumerState<FullScreenPromptOnce> createState() => _FullScreenPromptOnceState();
}

class _FullScreenPromptOnceState extends ConsumerState<FullScreenPromptOnce> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAsk());
  }

  Future<void> _maybeAsk() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(FullScreenPromptOnce.prefsKey) ?? false) return;
    final status = await ref.read(reminderStatusServiceProvider).check();
    if (status.fullScreenReady) return;
    await prefs.setBool(FullScreenPromptOnce.prefsKey, true);
    if (!mounted) return;
    final strings = ref.read(stringsProvider);
    final setUp = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.alarm_on, size: 40),
        title: Text(strings.fullScreenTitle),
        content: Text(strings.fullScreenPrompt),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(strings.notNow)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(strings.setUpAction)),
        ],
      ),
    );
    if (setUp != true || !mounted) return;
    context.push(AppRoutes.fullScreenSetup);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
