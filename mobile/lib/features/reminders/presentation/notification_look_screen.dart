import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';

/// Round 14: "What notifications look like" (the demo's notification page).
/// Which alerts take over the screen and which are normal notifications, with
/// a sample of the neutral lock-screen text (never medicine names).
class NotificationLookScreen extends ConsumerWidget {
  const NotificationLookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final s = strings.r14;
    final p = context.palette;
    final theme = Theme.of(context);

    Widget item(IconData icon, Color bg, Color fg, String title, String body, {required bool fullPage}) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: fg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: fullPage ? p.primaryContainer : p.surface2,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          fullPage ? s.npFullPage : s.npNormal,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: fullPage ? p.onPrimaryContainer : p.muted2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(body, style: TextStyle(color: p.muted2, fontSize: 15)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(s.notifLookTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s.notifLookIntro, style: TextStyle(color: p.muted, fontSize: 15)),
          const SizedBox(height: 14),
          // A lock screen with the neutral reminder text.
          ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
              decoration: BoxDecoration(color: const Color(0xFF16263B), borderRadius: BorderRadius.circular(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('8:00',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(16),
                      border: const Border(left: BorderSide(color: Color(0xFF2F7A3A), width: 4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Medi-Bela · ${s.npMedicineTitle}',
                            style: const TextStyle(color: Color(0xFF0F2137), fontWeight: FontWeight.w700)),
                        Text(s.npMedicineSample, style: const TextStyle(color: Color(0xFF0F2137))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          item(Icons.medication, p.primaryContainer, p.onPrimaryContainer, s.npMedicineTitle, s.npMedicineBody,
              fullPage: true),
          item(Icons.biotech_outlined, p.violetContainer, p.violet, s.npTestTitle, s.npTestBody, fullPage: true),
          item(Icons.inventory_2_outlined, p.warnContainer, p.onWarnContainer, s.npBoxTitle, s.npBoxBody,
              fullPage: true),
          item(Icons.groups_outlined, p.errorContainer, p.onErrorContainer, s.npMissedTitle, s.npMissedBody,
              fullPage: false),
          item(Icons.notifications_outlined, p.navyContainer, p.onNavyContainer, s.npOtherTitle, s.npOtherBody,
              fullPage: false),
        ],
      ),
    );
  }
}
