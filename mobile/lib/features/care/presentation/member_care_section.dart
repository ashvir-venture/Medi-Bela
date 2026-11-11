import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../health/domain/health_models.dart';
import '../domain/care_models.dart';
import 'care_providers.dart';
import 'condition_screen.dart';
import 'reading_screen.dart';
import '../../../widgets/fit_label.dart';

/// The member's health on the caregiver's member page (Rounds 15-16): their
/// conditions (each opens its page for the member), log a reading, health
/// records, targets and limits, and edit conditions. Online, like the page.
class MemberCareSection extends ConsumerWidget {
  const MemberCareSection({super.key, required this.memberId, required this.memberName});

  final String memberId;
  final String memberName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = stringsOf(ref).r15;
    final p = context.palette;
    final who = CareSubject(memberId: memberId, memberName: memberName);
    final care = ref.watch(memberCareProvider(memberId)).valueOrNull;
    if (care == null) return const SizedBox.shrink();
    final records = ref.watch(memberRecordsProvider(memberId)).valueOrNull ?? RecordsOverview.empty;
    final readings = ref.watch(memberReadingsProvider(memberId)).valueOrNull ?? const <HealthRecordModel>[];
    final lookups = ref.watch(careLookupsProvider).valueOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 16),
      Text(s.myCare, style: TextStyle(color: p.muted, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      for (final code in care.conditions)
        CareConditionTile(code: code, name: conditionName(code, lookups, s.bn), summary: careSummary(code, care, records, readings, s, lookups), who: who),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: () => context.push(readingPath(null, who)), icon: const Icon(Icons.monitor_heart_outlined), label: FitLabel(Text(s.logReading)))),
        const SizedBox(width: 12),
        Expanded(child: OutlinedButton.icon(onPressed: () => context.push(recordsPath(who)), icon: const Icon(Icons.folder_outlined), label: FitLabel(Text(s.healthRecords)))),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: () => context.push(limitsPath(who)), icon: const Icon(Icons.track_changes), label: FitLabel(Text(s.targetsLimits)))),
        const SizedBox(width: 12),
        Expanded(child: OutlinedButton.icon(onPressed: () => context.push(myCarePath(who)), icon: const Icon(Icons.tune), label: FitLabel(Text(s.editConditions)))),
      ]),
    ]);
  }
}
