import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../router/app_router.dart';
import '../../../widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/family_models.dart';
import 'family_controller.dart';

/// A family member's medicine status for today, read-only and online-only:
/// name / time / status (the server decides what is shareable). The
/// caregiver also gets shortcuts to manage the member's medicines and
/// prescriptions. Nobody but the member marks their doses taken.
class MemberStatusScreen extends ConsumerWidget {
  const MemberStatusScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final state = ref.watch(memberStatusProvider(userId));
    final myId = ref.watch(authControllerProvider).value?.id;
    final members = ref.watch(familyMembersControllerProvider).value ?? const <FamilyMemberModel>[];
    final iAmCaregiver = members.any((m) => m.userId == myId && m.role == 'CAREGIVER');

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
          ref.invalidate(memberStatusProvider(userId));
          await ref.read(memberStatusProvider(userId).future);
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
              // Deactivated or banned: "Account paused", no medicine data
              // and no caregiver actions until they're back.
              return ListView(children: [
                const SizedBox(height: 60),
                EmptyView(
                  message: detail.paused ? strings.accountPaused : strings.memberNotSharing,
                  icon: detail.paused ? Icons.pause_circle_outline : Icons.lock_outline,
                ),
              ]);
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (iAmCaregiver) ...[
                  _CaregiverShortcuts(userId: userId, name: detail.name),
                  const SizedBox(height: 20),
                ],
                Text(
                  strings.todaysMedicine,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (detail.doses.isEmpty)
                  EmptyView(
                    message: strings.noDosesToday,
                    icon: Icons.medication_outlined,
                  )
                else
                  for (final dose in detail.doses)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _DoseTile(dose: dose),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The caregiver's shortcuts to a member's medicines and prescriptions.
class _CaregiverShortcuts extends ConsumerWidget {
  const _CaregiverShortcuts({required this.userId, required this.name});

  final String userId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(strings.caregiverActingHint, style: TextStyle(color: context.palette.muted)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.medicinesPath(forUserId: userId, name: name)),
                icon: const Icon(Icons.medication_outlined),
                label: Text(strings.medicinesButton),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.memberPrescriptionsPath(userId, name)),
                icon: const Icon(Icons.description_outlined),
                label: Text(strings.prescriptionsButton),
              ),
            ),
          ],
        ),
      ],
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
        color = context.palette.success;
        break;
      case 'MISSED':
        label = strings.doseMissed;
        color = theme.colorScheme.error;
        break;
      case 'SKIPPED':
        label = strings.doseSkipped;
        color = context.palette.subtle;
        break;
      default: // PENDING
        final due = !dose.scheduledAt.isAfter(DateTime.now());
        label = due ? strings.doseDue : strings.doseUpcoming;
        color = due ? context.palette.warning : context.palette.subtle;
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
