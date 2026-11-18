import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/medicine_schedule_models.dart';

/// How a medicine looks (tablet colour, shape, form), kept on the phone per
/// routine so a reminder page opened offline or over the lock screen still
/// shows the strip colour next to the name (owner 2026-11-18). Written each
/// time the user's own medicines load (My medicine, Home); a few bytes each.
class PillLook {
  const PillLook({this.color, this.shape, this.formName});

  final String? color;
  final String? shape;
  final String? formName;

  Map<String, dynamic> toJson() => {'c': color, 's': shape, 'f': formName};

  factory PillLook.fromJson(Map<String, dynamic> j) =>
      PillLook(color: j['c'] as String?, shape: j['s'] as String?, formName: j['f'] as String?);
}

class PillLooks {
  static const _key = 'pref_pill_looks';

  /// Replaces the saved looks with these routines' (the full own list, so a
  /// removed medicine drops out).
  static Future<void> save(Iterable<ManagedRoutine> routines) async {
    final map = {
      for (final r in routines) r.id: PillLook(color: r.pillColor, shape: r.pillShape, formName: r.formName).toJson(),
    };
    try {
      await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(map));
    } catch (_) {
      // Only a picture; never block the list on it.
    }
  }

  static Future<Map<String, PillLook>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return const {};
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {for (final e in map.entries) e.key: PillLook.fromJson(e.value as Map<String, dynamic>)};
    } catch (_) {
      return const {};
    }
  }
}

/// The saved looks by routine id (empty until the medicines loaded once).
final pillLooksProvider = FutureProvider<Map<String, PillLook>>((ref) => PillLooks.load());
