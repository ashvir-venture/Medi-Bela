import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/locale_controller.dart';
import '../router/app_router.dart';
import 'connectivity_banner.dart';
import 'double_back_to_exit.dart';

/// Which bottom tab a location lives under. A screen always stays under the
/// same tab: a caregiver's view of a member's medicines (`?for=`) belongs to
/// Family; Inbox, Assistant and Notices are opened from Home.
int tabIndexForLocation(Uri uri) {
  final path = uri.path;
  bool under(String root) => path == root || path.startsWith('$root/');
  if (under(AppRoutes.medicines) || under(AppRoutes.prescription)) {
    return uri.queryParameters['for'] != null ? 2 : 1;
  }
  if (under(AppRoutes.family)) return 2;
  if (under(AppRoutes.health) || under(AppRoutes.diabetes)) return 3;
  if (under(AppRoutes.profile)) return 4;
  return 0;
}

/// A tab's own root (switched with `go`); everything else is pushed.
bool isTabRoot(Uri uri) {
  if (uri.path == AppRoutes.medicines) return uri.queryParameters['for'] == null;
  return const [AppRoutes.home, AppRoutes.family, AppRoutes.health, AppRoutes.profile].contains(uri.path);
}

class MainScaffold extends ConsumerWidget {
  const MainScaffold({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    AppRoutes.home,
    AppRoutes.medicines,
    AppRoutes.family,
    AppRoutes.health,
    AppRoutes.profile,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final uri = GoRouterState.of(context).uri;
    final currentIndex = tabIndexForLocation(uri);

    final scaffold = Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ConnectivityBanner(),
            Expanded(child: child),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) => context.go(_tabs[index]),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined, size: 28),
            selectedIcon: const Icon(Icons.home, size: 28),
            label: strings.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.medication_outlined, size: 28),
            selectedIcon: const Icon(Icons.medication, size: 28),
            label: strings.medicinesTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.groups_outlined, size: 28),
            selectedIcon: const Icon(Icons.groups, size: 28),
            label: strings.family,
          ),
          NavigationDestination(
            icon: const Icon(Icons.favorite_outline, size: 28),
            selectedIcon: const Icon(Icons.favorite, size: 28),
            label: strings.health,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline, size: 28),
            selectedIcon: const Icon(Icons.person, size: 28),
            label: strings.profile,
          ),
        ],
      ),
    );

    // Home: back twice to leave. Other tab roots: back goes to Home.
    // Pushed screens pop normally.
    if (uri.path == AppRoutes.home) return DoubleBackToExit(child: scaffold);
    if (isTabRoot(uri)) {
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
