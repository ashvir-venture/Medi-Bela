import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_config.dart';

/// Light / dark / follow the phone. A per-device choice (not synced to the
/// account), saved in SharedPreferences; defaults to the phone's setting.
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system) {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = parseThemeMode(prefs.getString(PrefsKeys.themeMode));
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.themeMode, mode.name);
  }
}

/// Unknown or missing values mean "follow the phone".
ThemeMode parseThemeMode(String? value) =>
    ThemeMode.values.firstWhere((m) => m.name == value, orElse: () => ThemeMode.system);

final themeModeControllerProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController(),
);
