import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// The kinds of notification, each with its own colour and icon (owner
/// 2026-11-18, after the pinned demo: reminder navy, family alert peach,
/// urgent red, caregiver's change teal). One table for the inbox, the
/// reminder pages, the box page, "What notifications look like" and the
/// Android notification colour, so a kind looks the same everywhere.
enum NoteKind { medicine, test, box, family, urgent, change, prescription, notice, other }

/// The kind of an inbox row / push from its type and data.kind.
NoteKind noteKindOf(String type, [Map<String, dynamic> data = const {}]) {
  final kind = data['kind'];
  switch (kind) {
    case 'reading_alert':
    case 'help_alert':
      return NoteKind.urgent;
    case 'caregiver_action':
    case 'caregiver_changed':
    case 'caregiver_permission':
    case 'family_removed':
      return NoteKind.change;
    case 'medicine_box_empty':
      return NoteKind.box;
    case 'test_pending':
    case 'as_needed_over_max':
    case 'personal_reminder_later':
      return NoteKind.family;
    case 'notice_shared':
      return NoteKind.notice;
    case 'member_prescription_ready':
      return NoteKind.prescription;
  }
  return switch (type) {
    'MEDICINE_REMINDER' => NoteKind.medicine,
    'TEST_REMINDER' || 'CARE_REMINDER' => NoteKind.test,
    'MISSED_DOSE_FAMILY_ALERT' => NoteKind.family,
    'PRESCRIPTION_UPDATE' => NoteKind.prescription,
    'NOTICE' => NoteKind.notice,
    _ => NoteKind.other,
  };
}

/// Tile colour, icon colour and icon of a kind (theme tokens, dark mode too).
({Color bg, Color fg, IconData icon}) noteStyle(BuildContext context, NoteKind kind) {
  final p = context.palette;
  return switch (kind) {
    NoteKind.medicine => (bg: p.navyContainer, fg: p.onNavyContainer, icon: Icons.medication_outlined),
    NoteKind.test => (bg: p.violetContainer, fg: p.onVioletContainer, icon: Icons.biotech_outlined),
    NoteKind.box => (bg: p.warnContainer, fg: p.onWarnContainer, icon: Icons.inventory_2_outlined),
    NoteKind.family => (bg: p.warnContainer, fg: p.onWarnContainer, icon: Icons.groups_outlined),
    NoteKind.urgent => (bg: p.errorContainer, fg: p.onErrorContainer, icon: Icons.warning_amber_rounded),
    NoteKind.change => (bg: p.primaryContainer, fg: p.onPrimaryContainer, icon: Icons.sync_rounded),
    NoteKind.prescription => (bg: p.okContainer, fg: p.onOkContainer, icon: Icons.description_outlined),
    NoteKind.notice => (bg: p.violetContainer, fg: p.onVioletContainer, icon: Icons.campaign_outlined),
    NoteKind.other => (bg: p.surface2, fg: p.muted2, icon: Icons.notifications_outlined),
  };
}

/// The accent colour Android shows on a notification of this kind (fixed:
/// the shade is drawn by the system, not by the app's theme).
Color noteAndroidColor(NoteKind kind) => switch (kind) {
      NoteKind.medicine => const Color(0xFF143D6B),
      NoteKind.test => const Color(0xFF4A3D80),
      NoteKind.box || NoteKind.family => const Color(0xFFB85A10),
      NoteKind.urgent => const Color(0xFFB3261E),
      NoteKind.change => const Color(0xFF0E7C86),
      NoteKind.prescription => const Color(0xFF2F7A3A),
      NoteKind.notice => const Color(0xFF4A3D80),
      NoteKind.other => const Color(0xFF0E7C86),
    };

/// The kind's icon on its coloured tile.
class NoteKindTile extends StatelessWidget {
  const NoteKindTile(this.kind, {super.key, this.size = 44, this.icon});

  final NoteKind kind;
  final double size;

  /// Overrides the kind's own icon.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final st = noteStyle(context, kind);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: st.bg, borderRadius: BorderRadius.circular(size >= 44 ? 12 : 10)),
      child: Icon(icon ?? st.icon, size: size * 0.55, color: st.fg),
    );
  }
}
