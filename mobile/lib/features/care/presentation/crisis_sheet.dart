import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/core_providers.dart';
import '../../help/presentation/help_screens.dart';
import '../domain/care_content.dart';
import 'care_providers.dart';
import '../../../widgets/fit_label.dart';

enum CrisisKind { bp, sugar }

/// The emergency sheet on a dangerous reading (Round 15 D): what to do now,
/// Call 999, 16263 and Alert family. Fixed texts (no diagnosis, no medicine).
/// It never alerts by itself; "Alert family" tells the caregiver.
/// Returns true when the user chose "Measure again".
Future<bool> showCrisisSheet(
  BuildContext context, {
  required CrisisKind kind,
  required String reading,
  String? level,
  bool forMember = false,
}) async {
  final again = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => CrisisSheet(kind: kind, reading: reading, level: level, forMember: forMember),
  );
  return again ?? false;
}

class CrisisSheet extends ConsumerWidget {
  const CrisisSheet({super.key, required this.kind, required this.reading, this.level, this.forMember = false});

  final CrisisKind kind;
  final String reading;

  /// The BP level now in force, e.g. "180/120".
  final String? level;

  /// The caregiver logged it for a member: "Alert family" is theirs to do.
  final bool forMember;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = stringsOf(ref).r15;
    final bn = s.bn;
    final p = context.palette;
    final bp = kind == CrisisKind.bp;
    final title = tr(bp ? bpCrisisTitle : sugarCrisisTitle, bn);
    final step1 = tr(bp ? bpCrisisStep1 : sugarCrisisStep1, bn);
    final step1Sub = bp ? tr(bpCrisisStep1Sub, bn).replaceAll('{level}', s.n(level ?? '180/120')) : tr(sugarCrisisStep1Sub, bn);
    final step2 = tr(bp ? bpCrisisStep2 : sugarCrisisStep2, bn);
    final step2Sub = tr(bp ? bpCrisisStep2Sub : sugarCrisisStep2Sub, bn);

    Future<void> alert() async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final told = await ref.read(careRepositoryProvider).alertFamily();
        messenger.showSnackBar(SnackBar(content: Text(told ? s.alertSent : s.alertNobody)));
      } catch (_) {
        messenger.showSnackBar(SnackBar(content: Text(s.needsInternet)));
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: p.errorContainer, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.warning_amber_rounded, color: p.onErrorContainer),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.later)),
              Text(reading, style: const TextStyle(fontSize: 16)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(step1, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(step1Sub, style: TextStyle(color: p.muted)),
            const SizedBox(height: 8),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(bp ? s.measureAgainNow : s.checkAgain)),
          ]),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: p.errorContainer, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(step2, style: TextStyle(fontWeight: FontWeight.w700, color: p.onErrorContainer)),
            const SizedBox(height: 4),
            Text(step2Sub, style: TextStyle(color: p.onErrorContainer)),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: p.later, foregroundColor: p.onLater),
              onPressed: () => openExternal(context, ref, 'tel:999', fallbackCopy: '999'),
              icon: const Icon(Icons.phone),
              label: Text(s.call999),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          if (!forMember) ...[
            Expanded(
              child: OutlinedButton.icon(onPressed: alert, icon: const Icon(Icons.groups_outlined), label: FitLabel(Text(s.alertFamily))),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => openExternal(context, ref, 'tel:16263', fallbackCopy: '16263'),
              icon: const Icon(Icons.phone_outlined),
              label: FitLabel(Text(s.call16263)),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Text(tr(helpline16263, bn), style: TextStyle(color: p.muted, fontSize: 13)),
        const SizedBox(height: 4),
        Text(tr(crisisNoExtraMedicine, bn), style: TextStyle(color: p.muted, fontSize: 13)),
      ]),
    );
  }
}
