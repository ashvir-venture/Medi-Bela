import 'package:flutter/material.dart';
import '../../care/presentation/member_care_section.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../router/app_router.dart';
import '../../../widgets/state_views.dart';
import '../../../core/localization/app_strings.dart';
import '../../../providers/core_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../home/presentation/easy_home_screen.dart';
import '../../home/presentation/home_top.dart';
import '../../medicine_schedule/domain/dose_display_status.dart';
import '../../medicine_schedule/domain/medicine_schedule_models.dart';
import '../domain/family_models.dart';
import 'family_controller.dart';

/// A family member's medicine status for today, online-only: name / time /
/// status, On time / Late / Missed (the server decides what is shareable).
/// The caregiver also gets shortcuts to manage the member's medicines and
/// prescriptions, "I gave it" on a due dose and the easy-mode switch
/// (Round 14, owner 2026-11-10).
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
                  if (detail.asCaregiver) ...[
                    const SizedBox(height: 12),
                    _EasyModeCard(detail: detail),
                  ],
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
                      child: _DoseTile(dose: dose, memberUserId: userId, canGive: detail.asCaregiver),
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
        const SizedBox(height: 12),
        // Round 13: the member's own reminders and medicine box.
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.personalRemindersPath(forUserId: userId, name: name)),
                icon: const Icon(Icons.alarm_add_outlined),
                label: Text(strings.personalRemindersShort),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.medicineBoxPath(forUserId: userId, name: name)),
                icon: const Icon(Icons.inventory_2_outlined),
                label: Text(strings.medicineBoxTitle),
              ),
            ),
          ],
        ),
        // Rounds 15-16: the member's conditions, readings and records.
        MemberCareSection(memberId: userId, memberName: name),
      ],
    );
  }
}

/// Round 14: the caregiver switches the member's easy mode, and can see
/// what that looks like on the member's phone.
class _EasyModeCard extends ConsumerStatefulWidget {
  const _EasyModeCard({required this.detail});

  final MemberStatusDetail detail;

  @override
  ConsumerState<_EasyModeCard> createState() => _EasyModeCardState();
}

class _EasyModeCardState extends ConsumerState<_EasyModeCard> {
  bool _busy = false;

  Future<void> _set(bool on) async {
    setState(() => _busy = true);
    final result = await ref.read(familyRepositoryProvider).setEasyMode(widget.detail.userId, on);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) => ref.invalidate(memberStatusProvider(widget.detail.userId)),
      failure: (m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider).r14;
    final d = widget.detail;
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            key: const ValueKey('member-easy-mode'),
            title: Text(s.easyMode),
            subtitle: Text(s.easyModeMemberHelp),
            value: d.easyMode ?? false,
            onChanged: _busy ? null : _set,
          ),
          ListTile(
            leading: const Icon(Icons.visibility_outlined),
            title: Text(s.easyPreview),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => EasyHomePreviewScreen(name: d.name, doses: previewDoses(d)),
            )),
          ),
        ],
      ),
    );
  }
}

/// The member's shared doses as dose models for the easy-home preview.
List<MedicineDoseModel> previewDoses(MemberStatusDetail d) => [
      for (var i = 0; i < d.doses.length; i++)
        MedicineDoseModel(
          id: d.doses[i].id ?? 'preview-$i',
          routineId: 'preview-${d.doses[i].medicineName}',
          medicineName: d.doses[i].medicineName,
          dosage: '',
          scheduledAt: d.doses[i].scheduledAt,
          status: d.doses[i].status,
          takenAt: d.doses[i].takenAt,
        ),
    ];

class _DoseTile extends ConsumerStatefulWidget {
  const _DoseTile({required this.dose, required this.memberUserId, this.canGive = false});

  final MemberDoseStatus dose;
  final String memberUserId;
  final bool canGive;

  @override
  ConsumerState<_DoseTile> createState() => _DoseTileState();
}

class _DoseTileState extends ConsumerState<_DoseTile> {
  bool _busy = false;

  Future<void> _give() async {
    final s = ref.read(stringsProvider).r14;
    setState(() => _busy = true);
    final result = await ref.read(familyRepositoryProvider).giveDose(widget.memberUserId, widget.dose.id!);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.doseGiven)));
        ref.invalidate(memberStatusProvider(widget.memberUserId));
      },
      failure: (m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dose = widget.dose;
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

    final outcome = switch (dose.status) {
      'TAKEN' => dose.takenLate == true ? DoseOutcome.late : DoseOutcome.onTime,
      'MISSED' || 'SKIPPED' => DoseOutcome.missed,
      _ => null,
    };
    final mayGive = widget.canGive &&
        dose.id != null &&
        (dose.status == 'PENDING' || dose.status == 'MISSED') &&
        !dose.scheduledAt.isAfter(DateTime.now().add(const Duration(minutes: 2)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dose.medicineName, style: theme.textTheme.titleMedium),
                      Text(TimeOfDay.fromDateTime(dose.scheduledAt).format(context),
                          style: TextStyle(color: context.palette.muted)),
                    ],
                  ),
                ),
                if (outcome == null)
                  Chip(
                    label: Text(label, style: TextStyle(color: color, fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: color.withValues(alpha: 0.1),
                    side: BorderSide.none,
                  ),
              ],
            ),
            if (outcome != null) ...[
              const SizedBox(height: 6),
              DoseOutcomeChip(outcome: outcome, given: dose.givenByCaregiver),
            ],
            if (mayGive) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                key: ValueKey('give-${dose.id}'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: context.palette.taken,
                  foregroundColor: context.palette.onTaken,
                ),
                onPressed: _busy ? null : _give,
                icon: const Icon(Icons.check),
                label: Text(strings.r14.iGaveIt),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
