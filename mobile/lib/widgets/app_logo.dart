import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/locale_controller.dart';

/// The Medi-Bela logo, picked by the current app language:
/// assets/images/logoBn.png for Bangla, assets/images/logoEn.png otherwise.
/// If the image is missing, [fallback] is shown instead (nothing by default).
class AppLogo extends ConsumerWidget {
  const AppLogo({super.key, this.height = 32, this.fallback});

  final double height;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBangla = ref.watch(localeControllerProvider).languageCode == 'bn';
    return Image.asset(
      isBangla ? 'assets/images/logoBn.png' : 'assets/images/logoEn.png',
      height: height,
      fit: BoxFit.contain,
      semanticLabel: 'Medi-Bela',
      errorBuilder: (_, __, ___) => fallback ?? const SizedBox.shrink(),
    );
  }
}