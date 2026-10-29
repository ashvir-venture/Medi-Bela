import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/lookups/lookups.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/caregiver_tag.dart';
import '../../../widgets/details_fields.dart' show formatYmd;
import '../../../widgets/state_views.dart';
import '../../medicine_schedule/presentation/medicine_schedule_controller.dart';
import '../domain/prescription_models.dart';
import 'prescription_controller.dart';

/// "HH:mm" -> the phone's time format (e.g. 8:00 AM).
String formatHhmm(BuildContext context, String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return hhmm;
  final time = TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
  return time.format(context);
}

String toHhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// What the patient changed on one line before confirming.
class _LineChoice {
  _LineChoice(PrescriptionMedicineModel m)
      : times = List.of(m.scheduleTimes),
        startDate = m.startDate,
        mealTimingId = m.mealTimingId;

  List<String> times;
  DateTime? startDate;
  int? mealTimingId;
  bool removed = false;
}

/// Confirm or Edit: the pharmacist prepared the routine; the patient (or the
/// caregiver acting for them, [forUserId]) may change dose times, start date
/// and meal timing, or remove a medicine. Reminders start on Confirm.
class ConfirmPrescriptionScreen extends ConsumerStatefulWidget {
  const ConfirmPrescriptionScreen({super.key, required this.prescriptionId, this.forUserId});

  final String prescriptionId;
  final String? forUserId;

  @override
  ConsumerState<ConfirmPrescriptionScreen> createState() => _ConfirmPrescriptionScreenState();
}

class _ConfirmPrescriptionScreenState extends ConsumerState<ConfirmPrescriptionScreen> {
  PrescriptionDetailModel? _prescription;
  final Map<String, _LineChoice> _choices = {};
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await ref.read(prescriptionApiProvider).getDetail(widget.prescriptionId, forUserId: widget.forUserId);
      setState(() {
        _prescription = p;
        _choices
          ..clear()
          ..addEntries(p.medicines.map((m) => MapEntry(m.id, _LineChoice(m))));
      });
    } on DioException catch (e) {
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _changes() {
    final changes = <Map<String, dynamic>>[];
    for (final m in _prescription!.medicines) {
      final c = _choices[m.id]!;
      final change = <String, dynamic>{'id': m.id};
      if (c.removed) {
        change['remove'] = true;
      } else {
        if (c.times.join(',') != m.scheduleTimes.join(',')) change['scheduleTimes'] = c.times;
        if (c.startDate != m.startDate && c.startDate != null) change['startDate'] = formatYmd(c.startDate!);
        if (c.mealTimingId != m.mealTimingId) change['mealTimingId'] = c.mealTimingId;
      }
      if (change.length > 1) changes.add(change);
    }
    return changes;
  }

  Future<void> _confirm() async {
    final strings = ref.read(stringsProvider);
    if (_choices.values.every((c) => c.removed)) {
      setState(() => _error = strings.keepOneMedicine);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(prescriptionApiProvider).confirm(
            widget.prescriptionId,
            lines: _changes(),
            forUserId: widget.forUserId,
          );
      if (widget.forUserId == null) {
        // My own reminders start now.
        await ref.read(refreshMedicineScheduleProvider)();
        await ref.read(prescriptionLocalRepositoryProvider).refreshStatuses();
      }
      ref.invalidate(serverPrescriptionsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.prescriptionConfirmedDone)));
      context.pop(true);
    } on DioException catch (e) {
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final meals = ref.watch(lookupsProvider).valueOrNull?.mealTimings ?? const <LookupOption>[];
    final p = _prescription;

    return Scaffold(
      appBar: AppBar(title: Text(strings.confirmPrescriptionTitle)),
      body: _loading
          ? const LoadingView()
          : p == null
              ? ErrorView(message: _error ?? strings.somethingWentWrong, retryLabel: strings.retry, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(strings.confirmPrescriptionHelp, style: Theme.of(context).textTheme.bodyLarge),
                    if (p.uploadedByCaregiver) ...[
                      const SizedBox(height: 8),
                      const Align(alignment: Alignment.centerLeft, child: TagChip()),
                    ],
                    const SizedBox(height: 16),
                    if (!p.awaitsConfirmation)
                      EmptyView(message: strings.alreadyConfirmed, icon: Icons.check_circle_outline)
                    else
                      ...p.medicines.map((m) => _LineCard(
                            medicine: m,
                            choice: _choices[m.id]!,
                            meals: meals,
                            strings: strings,
                            enabled: !_saving,
                            onChanged: () => setState(() {}),
                          )),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 88),
                  ],
                ),
      bottomNavigationBar: p != null && p.awaitsConfirmation
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _confirm,
                  icon: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check),
                  label: Text(strings.confirmAndStartReminders),
                ),
              ),
            )
          : null,
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.medicine,
    required this.choice,
    required this.meals,
    required this.strings,
    required this.enabled,
    required this.onChanged,
  });

  final PrescriptionMedicineModel medicine;
  final _LineChoice choice;
  final List<LookupOption> meals;
  final AppStrings strings;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [
      medicine.strength,
      medicine.doseAmount,
      medicine.continuous
          ? strings.continuousLabel
          : medicine.durationDays == null
              ? null
              : strings.daysCount(medicine.durationDays!),
    ].whereType<String>().where((s) => s.isNotEmpty).join(' • ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: choice.removed ? 0.5 : 1,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(medicine.medicineName, style: theme.textTheme.titleMedium)),
                  TextButton.icon(
                    onPressed: enabled
                        ? () {
                            choice.removed = !choice.removed;
                            onChanged();
                          }
                        : null,
                    icon: Icon(choice.removed ? Icons.undo : Icons.delete_outline),
                    label: Text(choice.removed ? strings.undoRemove : strings.removeMedicine),
                  ),
                ],
              ),
              if (details.isNotEmpty) Text(details),
              if (!choice.removed) ...[
                const SizedBox(height: 12),
                Text(strings.doseTimes, style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < choice.times.length; i++)
                      ActionChip(
                        avatar: const Icon(Icons.schedule, size: 18),
                        label: Text(formatHhmm(context, choice.times[i]), style: const TextStyle(fontSize: 16)),
                        onPressed: enabled
                            ? () async {
                                final parts = choice.times[i].split(':');
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
                                );
                                if (picked != null) {
                                  choice.times[i] = toHhmm(picked);
                                  onChanged();
                                }
                              }
                            : null,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: Text(strings.startDate),
                  subtitle: Text(choice.startDate == null ? strings.startsWhenConfirmed : formatYmd(choice.startDate!)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: enabled
                      ? () async {
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: choice.startDate != null && !choice.startDate!.isBefore(today)
                                ? choice.startDate!
                                : today,
                            firstDate: today,
                            lastDate: today.add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            choice.startDate = picked;
                            onChanged();
                          }
                        }
                      : null,
                ),
                DropdownButtonFormField<int?>(
                  initialValue: meals.any((m) => m.id == choice.mealTimingId) ? choice.mealTimingId : null,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: strings.mealTiming, prefixIcon: const Icon(Icons.restaurant_outlined)),
                  items: [
                    DropdownMenuItem<int?>(value: null, child: Text(strings.notSpecified)),
                    ...meals.map((m) => DropdownMenuItem<int?>(value: m.id, child: Text(m.name))),
                  ],
                  onChanged: enabled
                      ? (v) {
                          choice.mealTimingId = v;
                          onChanged();
                        }
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
