import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../router/app_router.dart';
import '../../diabetes/presentation/diabetes_strings.dart';

/// Hub for the Health tab: health reminders (from suggestion rules) and
/// basic health records. Kept intentionally simple — two cards, no
/// nested tabs — per the "avoid unnecessary medical features" scope
/// restriction for this phase.
class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(strings.health)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Diabetes is common in this age group: a clear row near the top.
          _HealthSectionCard(
            icon: Icons.bloodtype_outlined,
            title: ref.watch(diabetesStringsProvider).title,
            onTap: () => context.push(AppRoutes.diabetes),
          ),
          const SizedBox(height: 12),
          _HealthSectionCard(
            icon: Icons.favorite_border,
            title: strings.healthReminders,
            onTap: () => context.push(AppRoutes.healthReminders),
          ),
          const SizedBox(height: 12),
          _HealthSectionCard(
            icon: Icons.tips_and_updates_outlined,
            title: strings.aiHealthSuggestions,
            onTap: () => context.push(AppRoutes.healthSuggestions),
          ),
          const SizedBox(height: 12),
          _HealthSectionCard(
            icon: Icons.monitor_heart_outlined,
            title: strings.healthRecords,
            onTap: () => context.push(AppRoutes.healthRecords),
          ),
        ],
      ),
    );
  }
}

class _HealthSectionCard extends StatelessWidget {
  const _HealthSectionCard({required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
