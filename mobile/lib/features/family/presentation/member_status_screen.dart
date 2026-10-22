import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../router/app_router.dart';
import '../../../widgets/state_views.dart';
import '../domain/family_models.dart';
import 'family_controller.dart';

/// A family member's medicine status for today. Read-only, online-only, and
/// limited to name / time / status — the server decides what is shareable.
class MemberStatusScreen extends ConsumerWidget {
  const MemberStatusScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final state = ref.watch(memberStatusProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: Text(state.valueOrNull?.name ?? strings.family),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.family),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.refresh(memberStatusProvider(userId).future);
        },
        child: state.when(
          loading: () => const LoadingView(),
          error: (error, _) => ListView(
            children: [
              ErrorView(
                message: error.toString(),
                retryLabel: strings.retry,
                onRetry: () => ref.invalidate(memberStatusProvider(userId)),
              ),
            ],
          ),
          data: (detail) {
            if (!detail.shared) {
              return ListView(children: [
                const SizedBox(height: 60),
                EmptyView(
                  message: strings.memberNotSharing,
                  icon: Icons.lock_outline,
                ),
              ]);
            }
            if (detail.doses.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 60),
                EmptyView(
                  message: strings.noDosesToday,
                  icon: Icons.medication_outlined,
                ),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: detail.doses.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Text(
                    strings.todaysMedicine,
                    style: Theme.of(context).textTheme.titleMedium,
                  );
                }
                return _DoseTile(dose: detail.doses[index - 1]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _DoseTile extends ConsumerWidget {
  const _DoseTile({required this.dose});

  final MemberDoseStatus dose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final theme = Theme.of(context);

    late final String label;
    late final Color color;
    switch (dose.status) {
      case 'TAKEN':
        label = strings.doseTaken;
        color = Colors.green.shade700;
        break;
      case 'MISSED':
        label = strings.doseMissed;
        color = theme.colorScheme.error;
        break;
      case 'SKIPPED':
        label = strings.doseSkipped;
        color = Colors.grey.shade600;
        break;
      default: // PENDING
        final due = !dose.scheduledAt.isAfter(DateTime.now());
        label = due ? strings.doseDue : strings.doseUpcoming;
        color = due ? Colors.orange.shade800 : Colors.grey.shade600;
    }

    return Card(
      child: ListTile(
        title: Text(dose.medicineName),
        subtitle: Text(TimeOfDay.fromDateTime(dose.scheduledAt).format(context)),
        trailing: Chip(
          label: Text(label, style: TextStyle(color: color, fontSize: 12)),
          visualDensity: VisualDensity.compact,
          backgroundColor: color.withValues(alpha: 0.1),
          side: BorderSide.none,
        ),
      ),
    );
  }
}
