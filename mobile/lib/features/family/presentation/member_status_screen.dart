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
import '../../../widgets/fit_label.dart';
import '../../../core/utils/clock_label.dart';
import '../../../widgets/slot_style.dart';
import '../../home/domain/day_slots.dart' as home;
import 'family_screen.dart' show FamilyAvatar;
import '../../../core/lookups/lookups.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../widgets/labeled_field.dart';

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
            final today = MemberStatusSummary(
              userId: detail.userId,
              name: detail.name,
              shared: true,
              total: detail.doses.length,
              taken: detail.doses.where((d) => d.status == 'TAKEN').length,
              missed: detail.doses.where((d) => d.status == 'MISSED').length,
            );
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _RelationshipRow(userId: userId, current: detail.relationship),
                const SizedBox(height: 8),
                // The demo's top card: who, and how today is going.
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      FamilyAvatar(name: detail.name, summary: today, size: 60),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          // Owner 2026-11-18: "বাবা" (what I call them), the name under it.
                          Text(detail.label(strings.r18.bn), style: Theme.of(context).textTheme.titleLarge),
                          if (detail.relationship != null)
                            Text(detail.name, style: TextStyle(color: context.palette.muted, fontSize: AppType.small)),
                          const SizedBox(height: 4),
                          if (today.total == 0)
                            Text(strings.noDosesToday, style: TextStyle(color: context.palette.muted, fontSize: AppType.small))
                          else ...[
                            Text('${strings.doseTaken}: ${today.taken}/${today.total}',
                                style: TextStyle(fontWeight: FontWeight.w700, color: context.palette.onOkContainer)),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: today.taken / today.total,
                                minHeight: 8,
                                color: today.missed > 0 ? context.palette.warning : context.palette.success,
                                backgroundColor: context.palette.track,
                              ),
                            ),
                          ],
                        ]),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                // Round 18: only what the member allows (View / Manage).
                if (iAmCaregiver && detail.permissions != null && !detail.permissions!.view) ...[
                  _PermissionNote(text: strings.r18.memberNoView(detail.name), icon: Icons.lock_outline),
                  const SizedBox(height: 20),
                ] else if (iAmCaregiver) ...[
                  if (detail.permissions != null && !detail.permissions!.manage) ...[
                    _PermissionNote(text: strings.r18.memberViewOnly(detail.name), icon: Icons.visibility_outlined),
                    const SizedBox(height: 12),
                  ],
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

/// Round 18: why the caregiver sees less (the member's permission).
class _PermissionNote extends StatelessWidget {
  const _PermissionNote({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      key: const ValueKey('member-permission-note'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: p.navyContainer, borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: p.onNavyContainer),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: p.onNavyContainer, fontSize: AppType.small, height: AppType.bodyHeight))),
      ]),
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
                label: FitLabel(Text(strings.medicinesButton)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.memberPrescriptionsPath(userId, name)),
                icon: const Icon(Icons.description_outlined),
                label: FitLabel(Text(strings.prescriptionsButton)),
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
                label: FitLabel(Text(strings.personalRemindersShort)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.medicineBoxPath(forUserId: userId, name: name)),
                icon: const Icon(Icons.inventory_2_outlined),
                label: FitLabel(Text(strings.medicineBoxTitle)),
              ),
            ),
          ],
        ),
        // Round 18 (client point 14): the member's ring gap, rings and when
        // the caregiver is told (saving needs the member's Manage permission).
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const ValueKey('member-reminder-timings'),
          onPressed: () => context.push(AppRoutes.reminderRulesPath(forUserId: userId, name: name)),
          icon: const Icon(Icons.timer_outlined),
          label: Text(strings.r18.memberTimingsButton),
        ),
        // Rounds 15-16: the member's conditions, readings and records.
        MemberCareSection(memberId: userId, memberName: name),
        const SizedBox(height: 12),
        // Round 17: what a caregiver changed for this member.
        OutlinedButton.icon(
          key: const ValueKey('member-change-history'),
          onPressed: () => context.push(AppRoutes.memberChangesPath(userId, name)),
          icon: const Icon(Icons.history_outlined),
          label: Text(strings.r17.changeHistory),
        ),
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
                SlotTile(slot: home.slotOf(dose.scheduledAt), size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dose.medicineName, style: theme.textTheme.titleMedium),
                      Text(TimeOfDay.fromDateTime(dose.scheduledAt).label(context),
                          style: TextStyle(color: context.palette.muted)),
                    ],
                  ),
                ),
                if (outcome == null)
                  Chip(
                    label: Text(label, style: TextStyle(color: color, fontSize: AppType.tiny)),
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

/// "What you call them" (owner 2026-11-18): Baba, Ma, ... seen by you only,
/// in place of the name. Set at the invitation, changed here.
class _RelationshipRow extends ConsumerWidget {
  const _RelationshipRow({required this.userId, required this.current});

  final String userId;
  final BiOption? current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final s = strings.r18;
    final options = ref.watch(lookupsProvider).valueOrNull?.relationships ?? const <BiOption>[];
    if (options.isEmpty) return const SizedBox.shrink();
    return LabeledField(
      label: s.relationshipSet,
      hint: s.relationshipHint,
      child: DropdownButtonFormField<int?>(
        key: const ValueKey('member-relationship'),
        initialValue: current?.id,
        isExpanded: true,
        items: [
          DropdownMenuItem<int?>(value: null, child: Text(s.relationshipNone)),
          for (final r in options) DropdownMenuItem<int?>(value: r.id, child: Text(r.name(s.bn))),
        ],
        onChanged: (id) async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            await ref.read(familyApiProvider).setRelationship(userId, id);
            messenger.showSnackBar(SnackBar(content: Text(s.relationshipSaved)));
          } catch (e) {
            messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
          }
          ref.invalidate(memberStatusProvider(userId));
          ref.invalidate(familyStatusSummaryProvider);
          await ref.read(familyMembersControllerProvider.notifier).refresh();
        },
      ),
    );
  }
}

