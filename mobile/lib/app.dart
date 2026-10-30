import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/localization/locale_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/session_notifier.dart';
import 'notifications/session_services.dart';
import 'router/app_router.dart';
import 'widgets/not_found_screen.dart';

class CareBridgeApp extends ConsumerWidget {
  const CareBridgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeControllerProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    final maintenance = ref.watch(maintenanceProvider);

    // Start/stop push registration and local-reminder upkeep with the session.
    ref.listen<bool?>(sessionNotifierProvider, (_, loggedIn) {
      final services = ref.read(sessionServicesProvider);
      if (loggedIn == true) {
        services.start();
      } else if (loggedIn == false) {
        services.stop();
      }
    });

    return MaterialApp.router(
      title: 'Medi-Bela',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('bn')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      // The API answered 503 (maintenance): one screen over everything.
      builder: (context, child) => maintenance
          ? MaintenanceScreen(
              onTryAgain: () {
                ref.read(maintenanceProvider.notifier).state = false;
                // Any request will do: still 503 brings this screen back.
                ref.read(authControllerProvider.notifier).refreshProfile();
              },
            )
          : child ?? const SizedBox.shrink(),
    );
  }
}
