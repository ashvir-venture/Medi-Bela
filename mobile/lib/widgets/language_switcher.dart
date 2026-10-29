import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/locale_controller.dart';

/// English / বাংলা toggle for the sign-in screens, where Profile isn't
/// reachable yet. Shows the language it switches TO, in that language, so a
/// reader of either can find it. The choice is applied at once and uploaded to
/// the account after sign-in (LocaleController's unsynced flag), like Profile.
class LanguageSwitcher extends ConsumerWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBangla = ref.watch(localeControllerProvider).languageCode == 'bn';
    return TextButton.icon(
      key: const ValueKey('language-switcher'),
      onPressed: () =>
          ref.read(localeControllerProvider.notifier).setLanguage(isBangla ? 'en' : 'bn'),
      icon: const Icon(Icons.translate),
      label: Text(isBangla ? 'English' : 'বাংলা'),
    );
  }
}
