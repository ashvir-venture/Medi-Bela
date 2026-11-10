import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_config.dart';

/// Round 14: Appearance → Text size (Normal / Large / Larger), this phone
/// only, on top of the phone's own font size. Easy mode uses at least Large.
enum AppTextSize {
  normal(1.0),
  large(1.15),
  larger(1.3);

  const AppTextSize(this.factor);
  final double factor;

  static AppTextSize parse(String? value) =>
      AppTextSize.values.firstWhere((s) => s.name == value, orElse: () => AppTextSize.normal);
}

class TextSizeController extends StateNotifier<AppTextSize> {
  TextSizeController() : super(AppTextSize.normal) {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppTextSize.parse(prefs.getString(PrefsKeys.textSize));
  }

  Future<void> setSize(AppTextSize size) async {
    state = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.textSize, size.name);
  }
}

final textSizeControllerProvider =
    StateNotifierProvider<TextSizeController, AppTextSize>((ref) => TextSizeController());

/// The factor the whole app scales text by: the chosen size, at least Large
/// in easy mode.
double appTextFactor(AppTextSize size, {required bool easyMode}) =>
    easyMode && size.factor < AppTextSize.large.factor ? AppTextSize.large.factor : size.factor;

/// Multiplies the phone's own text scaling by [factor].
Widget withAppTextScale(BuildContext context, double factor, Widget child) {
  if (factor == 1.0) return child;
  final media = MediaQuery.of(context);
  final phone = media.textScaler;
  return MediaQuery(
    data: media.copyWith(textScaler: _ScaledBy(phone, factor)),
    child: child,
  );
}

class _ScaledBy extends TextScaler {
  const _ScaledBy(this.base, this.factor);
  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor * factor;

  @override
  bool operator ==(Object other) => other is _ScaledBy && other.base == base && other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}
