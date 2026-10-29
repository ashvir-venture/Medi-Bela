import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/lookups/lookups.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/details_fields.dart' show formatYmd;
import '../../prescription/presentation/confirm_prescription_screen.dart' show formatHhmm, toHhmm;
import '../domain/medicine_schedule_models.dart';
import 'medicine_schedule_controller.dart';

class RoutineFormArgs {
  const RoutineFormArgs({this.forUserId, this.routine});

  /// The family member the caregiver is managing; null = my own medicines.
  final String? forUserId;

  /// Null = add a new medicine.
  final ManagedRoutine? routine;
}

/// Add a medicine, or change/remove one. A pharmacist's medicine only
/// allows dose times and meal timing; a self-added one allows everything.
class RoutineFormScreen extends ConsumerStatefulWidget {
  const RoutineFormScreen({super.key, required this.args});

  final RoutineFormArgs args;

  @override
  ConsumerState<RoutineFormScreen> createState() => _RoutineFormScreenState();
}

class _RoutineFormScreenState extends ConsumerState<RoutineFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _strength = TextEditingController();
  final _doseAmount = TextEditingController();
  final _days = TextEditingController();
  String? _medicineId;
  List<String> _times = ['08:00'];
  int? _mealTimingId;
  bool _continuous = false;
  DateTime? _startDate;
  bool _saving = false;
  String? _error;
  Timer? _debounce;

  ManagedRoutine? get _routine => widget.args.routine;
  bool get _isNew => _routine == null;

  /// Pharmacist's medicine: only times and meal timing may change.
  bool get _limited => _routine != null && !_routine!.selfAdded;

  @override
  void initState() {
    super.initState();
    final r = _routine;
    if (r != null) {
      _name.text = r.medicineName;
      _strength.text = r.strength ?? '';
      _doseAmount.text = r.doseAmount ?? '';
      _times = r.scheduleTimes.isEmpty ? ['08:00'] : List.of(r.scheduleTimes);
      _mealTimingId = r.mealTimingId;
      _continuous = r.continuous;
      _days.text = r.durationDays?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _strength.dispose();
    _doseAmount.dispose();
    _days.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<Iterable<CatalogMedicineOption>> _suggest(String text) async {
    final q = text.trim();
    if (q.isEmpty || _limited) return const [];
    // Wait for a pause in typing before asking the server.
    final completer = Completer<Iterable<CatalogMedicineOption>>();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        completer.complete(await ref.read(medicineScheduleApiProvider).searchMedicines(q));
      } catch (_) {
        completer.complete(const []);
      }
    });
    return completer.future;
  }

  void _setTimesPerDay(int n) {
    setState(() {
      _times = List.generate(n, (i) => i < _times.length ? _times[i] : _times.last);
    });
  }

  Future<void> _save() async {
    final strings = ref.read(stringsProvider);
    if (!_formKey.currentState!.validate()) return;
    if (_times.toSet().length != _times.length) {
      setState(() => _error = strings.timesMustDiffer);
      return;
    }
    final api = ref.read(medicineScheduleApiProvider);
    final body = <String, dynamic>{
      'scheduleTimes': _times,
      'mealTimingId': _mealTimingId,
    };
    if (!_limited) {
      body.addAll({
        'medicineName': _name.text.trim(),
        'strength': _strength.text.trim(),
        'doseAmount': _doseAmount.text.trim(),
        'timesPerDay': _times.length,
        if (_continuous) 'continuous': true else 'durationDays': int.parse(_days.text.trim()),
      });
      if (!_continuous && !_isNew) body['continuous'] = false;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isNew) {
        if (_mealTimingId == null) body.remove('mealTimingId');
        if (_medicineId != null) body['medicineId'] = _medicineId;
        if (_startDate != null) body['startDate'] = formatYmd(_startDate!);
        await api.createRoutine(body, forUserId: widget.args.forUserId);
      } else {
        await api.updateRoutine(_routine!.id, body, forUserId: widget.args.forUserId);
      }
      await _afterChange();
    } on DioException catch (e) {
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    final strings = ref.read(stringsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.removeMedicine),
        content: Text(strings.removeMedicineConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(strings.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(strings.removeMedicine)),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(medicineScheduleApiProvider).removeRoutine(_routine!.id, forUserId: widget.args.forUserId);
      await _afterChange();
    } on DioException catch (e) {
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// My own medicines changed: refresh the offline copy so reminders follow.
  Future<void> _afterChange() async {
    if (widget.args.forUserId == null) await ref.read(refreshMedicineScheduleProvider)();
    if (mounted) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final meals = ref.watch(lookupsProvider).valueOrNull?.mealTimings ?? const <LookupOption>[];

    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? strings.addMedicine : strings.editMedicine)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_limited) ...[
              Text(_routine!.medicineName, style: Theme.of(context).textTheme.titleLarge),
              Text(_routine!.dosage),
              const SizedBox(height: 8),
              Text(strings.pharmacistMedicineLimited, style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 16),
            ] else ...[
              Autocomplete<CatalogMedicineOption>(
                initialValue: TextEditingValue(text: _name.text),
                optionsBuilder: (v) => _suggest(v.text),
                displayStringForOption: (o) => o.brandName,
                onSelected: (o) {
                  _name.text = o.brandName;
                  _medicineId = o.id;
                },
                fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: strings.medicineName,
                      prefixIcon: const Icon(Icons.medication_outlined),
                    ),
                    onChanged: (text) {
                      _name.text = text;
                      _medicineId = null;
                    },
                    validator: (v) => (v == null || v.trim().isEmpty) ? strings.requiredField : null,
                  );
                },
                optionsViewBuilder: (context, onSelected, options) => Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280, maxWidth: 420),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        children: options
                            .map((o) => ListTile(
                                  title: Text(o.brandName),
                                  subtitle: Text([o.genericName, o.formName].whereType<String>().join(' • ')),
                                  onTap: () => onSelected(o),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _strength,
                      decoration: InputDecoration(labelText: strings.strength, hintText: '500 mg'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _doseAmount,
                      decoration: InputDecoration(labelText: strings.doseAmount, hintText: '1'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _times.length,
                decoration: InputDecoration(labelText: strings.timesPerDay, prefixIcon: const Icon(Icons.repeat)),
                items: [for (var n = 1; n <= 6; n++) DropdownMenuItem(value: n, child: Text('$n'))],
                onChanged: _saving ? null : (n) => _setTimesPerDay(n ?? 1),
              ),
              const SizedBox(height: 16),
            ],
            Text(strings.doseTimes, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _times.length; i++)
                  ActionChip(
                    avatar: const Icon(Icons.schedule, size: 18),
                    label: Text(formatHhmm(context, _times[i]), style: const TextStyle(fontSize: 16)),
                    onPressed: _saving
                        ? null
                        : () async {
                            final parts = _times[i].split(':');
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
                            );
                            if (picked != null) setState(() => _times[i] = toHhmm(picked));
                          },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              initialValue: meals.any((m) => m.id == _mealTimingId) ? _mealTimingId : null,
              isExpanded: true,
              decoration: InputDecoration(labelText: strings.mealTiming, prefixIcon: const Icon(Icons.restaurant_outlined)),
              items: [
                DropdownMenuItem<int?>(value: null, child: Text(strings.notSpecified)),
                ...meals.map((m) => DropdownMenuItem<int?>(value: m.id, child: Text(m.name))),
              ],
              onChanged: _saving ? null : (v) => setState(() => _mealTimingId = v),
            ),
            if (!_limited) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(strings.continuousLabel),
                subtitle: Text(strings.continuousHelp),
                value: _continuous,
                onChanged: _saving ? null : (v) => setState(() => _continuous = v),
              ),
              if (!_continuous)
                TextFormField(
                  controller: _days,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: strings.numberOfDays, prefixIcon: const Icon(Icons.date_range)),
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    return n == null || n < 1 || n > 365 ? strings.numberOfDaysInvalid : null;
                  },
                ),
              if (_isNew) ...[
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: Text(strings.startDate),
                  subtitle: Text(_startDate == null ? strings.today : formatYmd(_startDate!)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () async {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? today,
                      firstDate: today,
                      lastDate: today.add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _startDate = picked);
                  },
                ),
              ],
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(strings.save),
            ),
            if (!_isNew) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : _remove,
                style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                icon: const Icon(Icons.delete_outline),
                label: Text(strings.removeMedicine),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
