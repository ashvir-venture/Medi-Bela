import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/app_strings.dart';
import '../core/localization/locale_controller.dart';
import '../core/theme/app_theme.dart';
import '../features/prescription/presentation/prescription_screen.dart';
import '../router/app_router.dart';
import 'connectivity_banner.dart';
import 'double_back_to_exit.dart';

/// Which bottom tab a location lives under. A screen always stays under the
/// same tab: a caregiver's view of a member's medicines (`?for=`) belongs to
/// Family; Inbox, Assistant, Notices and (Round 14) Profile are opened from
/// Home.
int tabIndexForLocation(Uri uri) {
  final path = uri.path;
  bool under(String root) => path == root || path.startsWith('$root/');
  if (under(AppRoutes.medicines) || under(AppRoutes.prescription)) {
    return uri.queryParameters['for'] != null ? 2 : 1;
  }
  if (under(AppRoutes.family)) return 2;
  if (under(AppRoutes.health) || under(AppRoutes.diabetes)) return 3;
  return 0;
}

/// A tab's own root (switched with `go`); everything else is pushed.
/// Round 14: Profile is no tab of its own (the avatar on Home opens it).
bool isTabRoot(Uri uri) {
  if (uri.path == AppRoutes.medicines) return uri.queryParameters['for'] == null;
  return const [AppRoutes.home, AppRoutes.family, AppRoutes.health].contains(uri.path);
}

/// Round 14 (the demo's look): Home · Medicines · (+) · Family · Health,
/// the round + in the middle opens "What would you like to add?", and the
/// AI assistant is a round button above the bar on the tab roots.
class MainScaffold extends ConsumerWidget {
  const MainScaffold({super.key, required this.child});

  final Widget child;

  static const _tabs = [AppRoutes.home, AppRoutes.medicines, AppRoutes.family, AppRoutes.health];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final uri = GoRouterState.of(context).uri;
    final currentIndex = tabIndexForLocation(uri);
    final root = isTabRoot(uri);

    final scaffold = Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ConnectivityBanner(),
            Expanded(child: child),
          ],
        ),
      ),
      floatingActionButton: root
          ? Tooltip(
              message: strings.r14.aiButton,
              child: FloatingActionButton(
                heroTag: 'ai-assistant',
                onPressed: () => context.push(AppRoutes.assistant),
                child: const _AiIcon(),
              ),
            )
          : null,
      bottomNavigationBar: _BottomBar(
        current: currentIndex,
        strings: strings,
        onTab: (i) => context.go(_tabs[i]),
        onAdd: () => showQuickAddSheet(context),
      ),
    );

    // Home: back twice to leave. Other tab roots: back goes to Home.
    // Pushed screens pop normally (Home when there's nothing to pop to).
    if (uri.path == AppRoutes.home) return DoubleBackToExit(child: scaffold);
    if (root || !GoRouter.of(context).canPop()) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) context.go(AppRoutes.home);
        },
        child: scaffold,
      );
    }
    return scaffold;
  }
}

class _AiIcon extends StatelessWidget {
  const _AiIcon();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.smart_toy_outlined, size: 26),
        Positioned(
          top: -10,
          right: -14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: p.surface2, width: 2),
            ),
            child: Text(
              'AI',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.current, required this.strings, required this.onTab, required this.onAdd});

  final int current;
  final AppStrings strings;
  final ValueChanged<int> onTab;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    Widget tab(int i, IconData icon, IconData selected, String label) {
      final on = current == i;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          label: label,
          excludeSemantics: true,
          child: InkWell(
            onTap: () => onTab(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 52,
                    height: 30,
                    decoration: BoxDecoration(
                      color: on ? p.primaryContainer : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Icon(on ? selected : icon, size: 24, color: on ? scheme.primary : p.muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                      color: on ? scheme.primary : p.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: p.navBackground,
      elevation: 8,
      shadowColor: Colors.black26,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              tab(0, Icons.home_outlined, Icons.home, strings.home),
              tab(1, Icons.medication_outlined, Icons.medication, strings.medicinesTab),
              Expanded(
                child: Center(
                  child: Semantics(
                    button: true,
                    label: strings.r14.addAction,
                    excludeSemantics: true,
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: FloatingActionButton(
                        heroTag: 'quick-add',
                        elevation: 2,
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        onPressed: onAdd,
                        child: const Icon(Icons.add, size: 30),
                      ),
                    ),
                  ),
                ),
              ),
              tab(2, Icons.groups_outlined, Icons.groups, strings.family),
              tab(3, Icons.favorite_outline, Icons.favorite, strings.health),
            ],
          ),
        ),
      ),
    );
  }
}

/// "What would you like to add?" from the + in the bottom bar (the demo's
/// quick-add sheet). Round 16 adds tests and doctor visits.
Future<void> showQuickAddSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => const QuickAddSheet(),
  );
}

class QuickAddSheet extends ConsumerWidget {
  const QuickAddSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider).r14;
    final r15 = ref.watch(stringsProvider).r15;
    final p = context.palette;

    void open(void Function(BuildContext) action) {
      final root = GoRouter.of(context).routerDelegate.navigatorKey.currentContext ?? context;
      Navigator.of(context).pop();
      action(root);
    }

    Widget tileButton(IconData icon, Color bg, Color fg, String title, String sub, void Function(BuildContext) go) {
      return Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => open(go),
          child: Container(
            constraints: const BoxConstraints(minHeight: 112),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: fg, size: 26),
                ),
                const SizedBox(height: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(sub, style: TextStyle(color: p.muted2, fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.whatToAdd, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: tileButton(Icons.medication_outlined, p.primaryContainer, p.onPrimaryContainer, s.qAddMedicine,
                      s.qAddMedicineSub, (c) => c.push(AppRoutes.medicineForm)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: tileButton(Icons.photo_camera_outlined, p.navyContainer, p.onNavyContainer, s.qPrescription,
                      s.qPrescriptionSub, (c) => openPrescriptionEntryForm(c)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: tileButton(Icons.monitor_heart_outlined, p.okContainer, p.onOkContainer, s.qReading,
                      s.qReadingSub, (c) => c.push(AppRoutes.healthRecordsAdd)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: tileButton(Icons.alarm_add_outlined, p.violetContainer, p.violet, s.qReminder, s.qReminderSub,
                      (c) => c.push(AppRoutes.personalReminderForm)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: p.warnContainer, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.inventory_2_outlined, color: p.onWarnContainer),
              ),
              title: Text(s.qBox),
              subtitle: Text(s.qBoxSub),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open((c) => c.push(AppRoutes.medicineBox)),
            ),
            // Round 16: a test and a doctor visit.
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: p.violetContainer, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.science_outlined, color: p.onVioletContainer),
              ),
              title: Text(r15.addTestReport),
              subtitle: Text(r15.addUpcomingTest),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open((c) => c.push('/health/records/test')),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: p.navyContainer, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.medical_services_outlined, color: p.onNavyContainer),
              ),
              title: Text(r15.addVisit),
              subtitle: Text(r15.remindDayBefore),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open((c) => c.push('/health/records/visit')),
            ),
          ],
        ),
      ),
    );
  }
}
