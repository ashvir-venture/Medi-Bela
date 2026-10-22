import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_config.dart';
import 'app_strings.dart';

const _supportedLanguageCodes = ['en', 'bn'];

/// Persisted app language ('en' | 'bn'). Defaults to the device locale when
/// it's one we support, otherwise English.
class LocaleController extends StateNotifier<Locale> {
  LocaleController() : super(const Locale('en')) {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(PrefsKeys.languageCode);
    if (saved != null && _supportedLanguageCodes.contains(saved)) {
      state = Locale(saved);
      return;
    }

    final deviceCode = PlatformDispatcher.instance.locale.languageCode;
    if (_supportedLanguageCodes.contains(deviceCode)) {
      state = Locale(deviceCode);
    }
  }

  static const _dirtyKey = 'pref_language_unsynced';

  /// [fromServer] = adopting the account's saved preference (not a user
  /// choice on this device), so nothing needs to be uploaded.
  Future<void> setLanguage(String languageCode, {bool fromServer = false}) async {
    if (!_supportedLanguageCodes.contains(languageCode)) return;
    state = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.languageCode, languageCode);
    // A choice made here must reach the server (it decides the language of
    // push notifications); remember it until that upload succeeds.
    await prefs.setBool(_dirtyKey, !fromServer);
  }

  Future<bool> hasUnsyncedChoice() async =>
      (await SharedPreferences.getInstance()).getBool(_dirtyKey) ?? false;

  Future<void> markSynced() async =>
      (await SharedPreferences.getInstance()).setBool(_dirtyKey, false);
}

final localeControllerProvider =
    StateNotifierProvider<LocaleController, Locale>(
  (ref) => LocaleController(),
);

/// The string table for the currently selected language. Widgets read
/// `ref.watch(stringsProvider)` and rebuild automatically on language change.
final stringsProvider = Provider<AppStrings>((ref) {
  final locale = ref.watch(localeControllerProvider);
  return locale.languageCode == 'bn' ? bnStrings : enStrings;
});
