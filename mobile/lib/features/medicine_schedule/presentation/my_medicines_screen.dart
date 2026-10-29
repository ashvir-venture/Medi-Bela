import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/core_providers.dart';
import '../../../router/app_router.dart';
import '../../../widgets/caregiver_tag.dart';
import '../../../widgets/load_more_list.dart';
import '../../../widgets/state_views.dart';
import '../../prescription/presentation/confirm_prescription_screen.dart' show formatHhmm;
import '../domain/medicine_schedule_models.dart';
import 'routine_form_screen.dart';

/// Active medicines with their labels, from the server. [forUserId] = the
/// caregiver managing a family member's medicines.
final managedRoutinesProvider = FutureProvider.autoDispose.family<List<ManagedRoutine>, String?>((ref, forUserId) {
  return ref.watch(medicineScheduleApiProvider).getManagedRoutines(forUserId: forUserId);
});

class MyMedicinesScreen extends ConsumerWidget {
  const MyMedicinesScreen({super.key, this.forUserId, this.memberName});

  final String? forUserId;
  final String? memberName;

  Future<void> _openForm(BuildContext context, WidgetRef ref, {ManagedRoutine? routine}) async {
    final changed = await context.push<bool>(
      AppRoutes.medicineForm,
      extra: RoutineFormArgs(forUserId: forUserId, routine: routine),
    );
    if (changed == true) ref.invalidate(managedRoutinesProvider(forUserId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final routinesAsync = ref.watch(managedRoutinesProvider(forUserId));

    return Scaffold(
      appBar: AppBar(
        title: Text(memberName == null ? strings.myMedicines : strings.medicinesOf(memberName!)),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(managedRoutinesProvider(forUserId).future),
        child: routinesAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => ListView(children: [
            ErrorView(
              message: strings.needsInternetToSave,
              retryLabel: strings.retry,
              onRetry: () => ref.invalidate(managedRoutinesProvider(forUserId)),
            ),
          ]),
          data: (routines) {
            if (routines.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 80),
                EmptyView(message: strings.noActiveRoutines, icon: Icons.medication_outlined),
              ]);
            }
            return LoadMoreListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: routines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _RoutineCard(
                routine: routines[i],
                strings: strings,
                onTap: () => _openForm(context, ref, routine: routines[i]),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: Text(strings.addMedicine),
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({required this.routine, required this.strings, required this.onTap});

  final ManagedRoutine routine;
  final AppStrings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final times = routine.scheduleTimes.map((t) => formatHhmm(context, t)).join(', ');
    final tags = <Widget>[
      if (routine.selfAdded)
        TagChip(
          label: routine.addedBy == ActedBy.caregiver ? strings.addedByCaregiver : strings.selfAdded,
          icon: Icons.person_add_alt_outlined,
        ),
      if (routine.editedBy != null)
        TagChip(
          label: routine.editedBy == ActedBy.caregiver ? strings.editedByCaregiver : strings.editedByYou,
          icon: Icons.edit_outlined,
        ),
    ];

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.medication_outlined, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(routine.medicineName, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text([routine.dosage, routine.frequency].where((s) => s != '-').join(' • ')),
                    if (times.isNotEmpty) Text(times, style: TextStyle(color: context.palette.muted)),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: tags),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
