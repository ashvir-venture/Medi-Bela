import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/app_logo.dart';
import 'auth_controller.dart';

/// Shown for the instant at launch while the app works out whether someone is
/// logged in, so Home is never flashed before the login screen.
/// The router leaves this screen on its own once the session is known.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The session check lives in the auth controller and only starts when
    // something reads it. Reading it here is what lets the splash end.
    ref.watch(authControllerProvider);

    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogo(
              height: 96,
              fallback: Icon(Icons.local_hospital_outlined, size: 72),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
