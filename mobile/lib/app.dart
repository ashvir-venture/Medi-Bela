import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/localization/locale_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/session_notifier.dart';
import 'notifications/session_services.dart';
import 'router/app_router.dart';

class CareBridgeApp extends ConsumerWidget {
  const CareBridgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeControllerProvider);

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
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('bn')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
