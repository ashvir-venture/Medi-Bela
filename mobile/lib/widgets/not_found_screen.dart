import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/locale_controller.dart';
import 'state_views.dart';

/// go_router's errorBuilder: an unknown route or a bad deep link. Home
/// redirects to Login when signed out.
class NotFoundScreen extends ConsumerWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return Scaffold(
      body: SafeArea(
        child: FullScreenMessage(
          icon: Icons.explore_off_outlined,
          title: strings.pageNotFound,
          actionLabel: strings.goToHome,
          onAction: () => context.go('/home'),
        ),
      ),
    );
  }
}

/// While the API answers 503: "Medi-Bela is being updated", over everything.
/// Try again clears the flag; the next request shows it again if the update
/// is still running.
class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key, required this.onTryAgain});

  final VoidCallback onTryAgain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return Scaffold(
      body: SafeArea(
        child: FullScreenMessage(
          icon: Icons.construction_outlined,
          title: strings.maintenanceMessage,
          actionLabel: strings.tryAgain,
          onAction: onTryAgain,
        ),
      ),
    );
  }
}
