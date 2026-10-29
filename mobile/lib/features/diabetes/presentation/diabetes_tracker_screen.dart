import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import 'diabetes_log_sheet.dart';
import 'diabetes_strings.dart';

/// Hub for the Diabetes Tracker: one button per kind of reading.
/// Placeholder feature - the forms do not store anything yet.
class DiabetesTrackerScreen extends ConsumerWidget {
  const DiabetesTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(diabetesStringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s.whatToLog, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _LogCard(
            icon: Icons.bloodtype_outlined,
            title: s.bloodSugar,
            subtitle: s.bloodSugarSub,
            onTap: () => showDiabetesLogSheet(context, DiabetesLogType.bloodSugar),
          ),
          const SizedBox(height: 12),
          _LogCard(
            icon: Icons.monitor_heart_outlined,
            title: s.bloodPressure,
            subtitle: s.bloodPressureSub,
            onTap: () => showDiabetesLogSheet(context, DiabetesLogType.bloodPressure),
          ),
          const SizedBox(height: 12),
          _LogCard(
            icon: Icons.vaccines_outlined,
            title: s.insulin,
            subtitle: s.insulinSub,
            onTap: () => showDiabetesLogSheet(context, DiabetesLogType.insulin),
          ),
          const SizedBox(height: 12),
          _LogCard(
            icon: Icons.monitor_weight_outlined,
            title: s.weight,
            subtitle: s.weightSub,
            onTap: () => showDiabetesLogSheet(context, DiabetesLogType.weight),
          ),
          const SizedBox(height: 12),
          _LogCard(
            icon: Icons.science_outlined,
            title: s.hba1c,
            subtitle: s.hba1cSub,
            onTap: () => showDiabetesLogSheet(context, DiabetesLogType.hba1c),
          ),
          const SizedBox(height: 20),
          Text(
            s.disclaimer,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: context.palette.muted),
          ),
        ],
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      excludeSemantics: true,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.12),
                  child: Icon(icon, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: context.palette.subtle),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
