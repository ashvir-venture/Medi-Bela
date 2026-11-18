import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/home/domain/day_slots.dart';

/// One fixed colour and icon per part of the day, as in the demo: morning
/// amber, afternoon teal, night navy. Used on every dose, chip and reminder.
({IconData icon, Color bg, Color fg}) slotStyle(BuildContext context, DaySlot slot) {
  final p = context.palette;
  return switch (slot) {
    DaySlot.morning => (icon: Icons.wb_sunny_outlined, bg: p.warnContainer, fg: p.onWarnContainer),
    DaySlot.noon => (icon: Icons.light_mode_outlined, bg: p.primaryContainer, fg: p.onPrimaryContainer),
    DaySlot.night => (icon: Icons.nightlight_outlined, bg: p.navyContainer, fg: p.onNavyContainer),
  };
}

/// The part-of-day icon on its coloured tile.
class SlotTile extends StatelessWidget {
  const SlotTile({super.key, required this.slot, this.size = 36});

  final DaySlot slot;
  final double size;

  @override
  Widget build(BuildContext context) {
    final st = slotStyle(context, slot);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: st.bg, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Icon(st.icon, size: size * 0.55, color: st.fg),
    );
  }
}
