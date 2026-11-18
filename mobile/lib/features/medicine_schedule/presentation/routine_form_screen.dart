import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/lookups/lookups.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/clock_label.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/details_fields.dart' show formatYmd;
import '../../../widgets/fit_label.dart';
import '../../../widgets/pill_icon.dart';
import '../../care/presentation/care_widgets.dart' show PillButton;
import '../../care/presentation/medicine_tag.dart';
import '../../medicine_box/domain/medicine_box_models.dart' show boxUnitsPerDoseOf;
import '../../prescription/presentation/confirm_prescription_screen.dart' show toHhmm;
import '../domain/medicine_schedule_models.dart';
import 'medicine_schedule_controller.dart';
import 'pack_photo_field.dart';

class RoutineFormArgs {
  const RoutineFormArgs({this.forUserId, this.routine});

  /// The family member the caregiver is managing; null = my own medicines.
  final String? forUserId;

  /// Null = add a new medicine.
  final ManagedRoutine? routine;
}

/// "When to take it" (Round 18, client note point 1b).
enum TakeWhen { everyDay, certainDays, everyFewDays, asNeeded }

/// The common forms shown as tiles, in this order (client: "capsule,
/// tablet, syrup common, the rest under More"); matched to the
/// medicine_forms lookup by name.
const commonForms = ['Tablet', 'Capsule', 'Syrup', 'Insulin', 'Injection', 'Drops', 'Inhaler'];

/// Default dose times for N doses a day.
List<String> defaultTimes(int n) => switch (n) {
      1 => ['08:00'],
      2 => ['08:00', '20:00'],
      3 => ['08:00', '14:00', '20:00'],
      4 => ['08:00', '12:00', '16:00', '20:00'],
      5 => ['07:00', '10:00', '13:00', '17:00', '21:00'],
      _ => ['06:00', '10:00', '14:00', '18:00', '22:00', '02:00'],
    };

/// Prescription patterns ("1+0+1" = morning and night).
const prescriptionPatterns = ['1+0+1', '1+1+1', '1+0+0', '0+0+1', '1+1+0', '0+1+1'];
const _slotTimes = ['08:00', '14:00', '20:00'];
List<String> patternTimes(String pattern) {
  final parts = pattern.split('+');
  return [for (var i = 0; i < 3; i++) if (parts[i] == '1') _slotTimes[i]];
}

/// Length chips: days (30 = 1 month), 0 = ongoing, -1 = other.
const lengthChoices = [3, 5, 7, 14, 30, 0, -1];

/// Default unit of the box count by form.
String unitForForm(String? formName) {
  final f = (formName ?? '').toLowerCase();
  if (f.contains('syrup') || f.contains('suspension') || f.contains('solution')) return 'ml';
  if (f.contains('capsule')) return 'capsule';
  if (f.contains('drop')) return 'drop';
  if (f.contains('inhaler')) return 'puff';
  if (f.contains('insulin')) return 'unit';
  if (f.contains('tablet')) return 'tablet';
  return 'dose';
}

/// Round 18 (client note point 1, the demo's "Add a medicine"): form tiles,
/// When to take it (every day / certain days / every few days / only when
/// needed), times a day with the prescription patterns, length chips, the
/// box count, and More details (the tablet's real look, what it is for,
/// pack photo, note). A pharmacist's medicine only allows times, meal
/// timing and the days (plus the personal look and note).
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
  final _otherDays = TextEditingController();
  final _stock = TextEditingController();
  final _note = TextEditingController();
  String? _medicineId;
  List<String> _times = defaultTimes(2);
  int? _mealTimingId;
  int? _formId;
  bool _moreForms = false;
  TakeWhen _when = TakeWhen.everyDay;
  Set<int> _weekdays = {DateTime.now().weekday % 7};
  int _everyN = 2;
  int? _maxPerDay;
  int? _minGap;
  int _length = 5; // see lengthChoices
  String? _condition;
  DateTime? _startDate;
  int _refillDays = 3;
  String? _stockUnit;
  bool _more = false;
  String? _pillColor;
  String? _pillShape;
  String? _packPhotoPath;
  bool _saving = false;
  String? _error;
  Timer? _debounce;

  ManagedRoutine? get _routine => widget.args.routine;
  bool get _isNew => _routine == null;

  /// Pharmacist's medicine: only times, meal timing and the days may change.
  bool get _limited => _routine != null && !_routine!.selfAdded;

  @override
  void initState() {
    super.initState();
    final r = _routine;
    if (r != null) {
      _condition = r.conditionCode;
      _name.text = r.medicineName;
      _strength.text = r.strength ?? '';
      _doseAmount.text = r.doseAmount ?? '';
      _times = r.scheduleTimes.isEmpty ? defaultTimes(1) : List.of(r.scheduleTimes);
      _mealTimingId = r.mealTimingId;
      _formId = r.formId;
      _everyN = r.intervalDays > 1 ? r.intervalDays : 2;
      _when = r.asNeeded
          ? TakeWhen.asNeeded
          : r.weekdays.isNotEmpty
              ? TakeWhen.certainDays
              : r.intervalDays > 1
                  ? TakeWhen.everyFewDays
                  : TakeWhen.everyDay;
      if (r.weekdays.isNotEmpty) _weekdays = r.weekdays.toSet();
      _maxPerDay = r.maxPerDay;
      _minGap = r.minGapHours;
      final d = r.durationDays;
      _length = d == null ? 0 : (lengthChoices.contains(d) ? d : -1);
      if (_length == -1) _otherDays.text = '$d';
      _pillColor = r.pillColor;
      _pillShape = r.pillShape;
      _note.text = r.note ?? '';
      _more = r.pillColor != null || (r.note ?? '').isNotEmpty;
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _strength, _doseAmount, _otherDays, _stock, _note]) {
      c.dispose();
    }
    _debounce?.cancel();
    super.dispose();
  }

  Future<Iterable<CatalogMedicineOption>> _suggest(String text) async {
    final q = text.trim();
    if (q.isEmpty || _limited) return const [];
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

  String? _formName(List<LookupOption> forms) => forms.where((f) => f.id == _formId).firstOrNull?.name;

  bool get _isPill {
    final f = (_formName(ref.read(lookupsProvider).valueOrNull?.medicineForms ?? const []) ?? '').toLowerCase();
    return f.contains('tablet') || f.contains('capsule') || f.isEmpty;
  }

  int? get _durationDays {
    if (_length == 0) return null;
    if (_length == -1) return int.tryParse(_otherDays.text.trim());
    return _length;
  }

  Future<void> _save() async {
    final r18 = ref.read(stringsProvider).r18;
    if (!_formKey.currentState!.validate()) return;
    final asNeeded = _when == TakeWhen.asNeeded;
    if (!asNeeded && _times.toSet().length != _times.length) {
      setState(() => _error = r18.pickTimesDifferent);
      return;
    }
    if (_when == TakeWhen.certainDays && _weekdays.isEmpty) {
      setState(() => _error = r18.pickDays);
      return;
    }
    final days = _durationDays;
    if (_length == -1 && (days == null || days < 1 || days > 365)) {
      setState(() => _error = ref.read(stringsProvider).numberOfDaysInvalid);
      return;
    }

    final body = <String, dynamic>{
      'mealTimingId': _mealTimingId,
      'pillColor': _pillColor,
      'pillShape': _pillColor == null ? null : _pillShape ?? PillIcon.defaultShape(_pillColor!),
      'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
    };
    if (!asNeeded) {
      body['scheduleTimes'] = _times;
      body['intervalDays'] = _when == TakeWhen.everyFewDays ? _everyN : 1;
      body['weekdays'] = _when == TakeWhen.certainDays ? (_weekdays.toList()..sort()) : <int>[];
    }
    if (!_limited) {
      body.addAll({
        if (_formId != null || !_isNew) 'formId': _formId,
        'medicineName': _name.text.trim(),
        'strength': _strength.text.trim(),
        'doseAmount': _doseAmount.text.trim(),
        'asNeeded': asNeeded,
        if (!asNeeded) 'timesPerDay': _times.length,
        if (asNeeded) ...{'maxPerDay': _maxPerDay, 'minGapHours': _minGap},
        if (days == null) 'continuous': true else 'durationDays': days,
      });
      if (days != null && !_isNew) body['continuous'] = false;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final api = ref.read(medicineScheduleApiProvider);
    final forUserId = widget.args.forUserId;
    try {
      ManagedRoutine saved;
      if (_isNew) {
        if (_mealTimingId == null) body.remove('mealTimingId');
        body.removeWhere((k, v) => v == null);
        if (body['weekdays'] is List && (body['weekdays'] as List).isEmpty) body.remove('weekdays');
        if (_medicineId != null) body['medicineId'] = _medicineId;
        if (_startDate != null) body['startDate'] = formatYmd(_startDate!);
        if (_condition != null) body['conditionCode'] = _condition;
        saved = await api.createRoutine(body, forUserId: forUserId);
      } else {
        saved = await api.updateRoutine(_routine!.id, body, forUserId: forUserId);
        if (_condition != _routine!.conditionCode) {
          await api.setRoutineCondition(_routine!.id, _condition, forUserId: forUserId);
        }
      }
      // Round 18 (point 1c): the box count from the same form.
      final count = double.tryParse(_stock.text.trim());
      if (count != null) {
        await ref.read(medicineBoxApiProvider).saveItem(
              saved.id,
              count,
              unit: _stockUnit ?? unitForForm(_formName(ref.read(lookupsProvider).valueOrNull?.medicineForms ?? const [])),
              refillDays: _refillDays,
              forUserId: forUserId,
            );
      }
      // Round 18 (point 1d): the pack photo goes up in the background.
      if (_packPhotoPath != null) {
        unawaited(ref.read(packPhotoUploaderProvider).upload(saved.id, _packPhotoPath!, forUserId: forUserId));
      }
      if (forUserId == null) await ref.read(refreshMedicineScheduleProvider)();
      if (mounted) context.pop(true);
    } on DioException catch (e) {
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final s = strings.r18;
    final p = context.palette;
    final lookups = ref.watch(lookupsProvider).valueOrNull;
    final meals = lookups?.mealTimings ?? const <LookupOption>[];
    final forms = lookups?.medicineForms ?? const <LookupOption>[];
    final asNeeded = _when == TakeWhen.asNeeded;
    final formName = _formName(forms);

    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? strings.addMedicine : strings.editMedicine)),
      bottomNavigationBar: _Footer(
        summary: asNeeded
            ? s.summaryAsNeeded(_doseAmount.text.trim(), _maxPerDay)
            : s.summaryTimes(_times.length, _doseAmount.text.trim(), _durationDays),
        label: _isNew ? strings.save : s.saveChanges,
        saving: _saving,
        onSave: _save,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (_limited) ...[
              Text(_routine!.medicineName, style: Theme.of(context).textTheme.titleLarge),
              Text(_routine!.dosage, style: TextStyle(color: p.muted)),
              const SizedBox(height: 6),
              Text(strings.pharmacistMedicineLimited, style: TextStyle(color: p.muted, fontSize: AppType.small)),
              const SizedBox(height: 16),
            ] else ...[
              Text(s.nameRequiredOnly, style: TextStyle(color: p.muted, fontSize: AppType.small)),
              const SizedBox(height: 10),
              _nameField(strings, forms),
              const SizedBox(height: 20),
              _Section(title: s.form, child: _formTiles(s, forms)),
              const SizedBox(height: 16),
              Row(children: [
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
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(labelText: asNeeded ? s.amountEachTime : strings.doseAmount, hintText: _amountHint(s, formName)),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
            ],
            _Section(title: s.whenToTake, child: _whenTiles(s)),
            const SizedBox(height: 20),
            if (asNeeded)
              _asNeededCard(s)
            else ...[
              _Section(title: s.howManyTimes, child: _timesPicker(s)),
              const SizedBox(height: 12),
              _doseTimes(context, s),
            ],
            const SizedBox(height: 20),
            if (meals.isNotEmpty)
              _Section(
                title: s.withFood + s.optional,
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final m in meals)
                    PillButton(
                      label: m.name,
                      square: true,
                      selected: _mealTimingId == m.id,
                      onTap: () => setState(() => _mealTimingId = _mealTimingId == m.id ? null : m.id),
                    ),
                ]),
              ),
            if (!_limited) ...[
              const SizedBox(height: 20),
              _Section(title: s.forHowLong, child: _lengthChips(s)),
            ],
            const SizedBox(height: 20),
            _stockCard(s, formName),
            const SizedBox(height: 16),
            _moreDetails(s, formName),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: p.later, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }

  String _amountHint(Round18Strings s, String? formName) {
    final unit = unitForForm(formName);
    if (unit == 'ml') return s.doseAmountHintSyrup;
    if (unit == 'unit') return s.doseAmountHintUnits;
    return s.doseAmountHintTablet;
  }

  Widget _nameField(AppStrings strings, List<LookupOption> forms) {
    return Autocomplete<CatalogMedicineOption>(
      initialValue: TextEditingValue(text: _name.text),
      optionsBuilder: (v) => _suggest(v.text),
      displayStringForOption: (o) => o.brandName,
      onSelected: (o) {
        _name.text = o.brandName;
        _medicineId = o.id;
        // The catalog's form picks the tile (still changeable).
        final form = forms.where((f) => f.name == o.formName).firstOrNull;
        if (form != null) setState(() => _formId = form.id);
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmit) => TextFormField(
        key: const ValueKey('medicine-name'),
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(labelText: '${strings.medicineName} *', prefixIcon: const Icon(Icons.search_rounded)),
        onChanged: (text) {
          _name.text = text;
          _medicineId = null;
        },
        validator: (v) => (v == null || v.trim().isEmpty) ? strings.requiredField : null,
      ),
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
                        subtitle: Text([o.genericName, o.formName].whereType<String>().join(' · ')),
                        onTap: () => onSelected(o),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formTiles(Round18Strings s, List<LookupOption> forms) {
    final common = [
      for (final name in commonForms) ...forms.where((f) => f.name.toLowerCase() == name.toLowerCase()),
    ];
    final rest = forms.where((f) => !common.contains(f)).toList();
    final restPicked = rest.any((f) => f.id == _formId);
    Widget tile(String label, IconData icon, bool on, VoidCallback onTap, {Key? key}) => _ChoiceTile(
          key: key,
          label: label,
          icon: icon,
          selected: on,
          onTap: onTap,
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.05,
        children: [
          for (final f in common)
            tile(f.name, formIcon(f.name), _formId == f.id, () => setState(() => _formId = _formId == f.id ? null : f.id), key: ValueKey('form-${f.name}')),
          if (rest.isNotEmpty)
            tile(restPicked ? forms.firstWhere((f) => f.id == _formId).name : s.more, Icons.more_horiz_rounded, restPicked || _moreForms,
                () => setState(() => _moreForms = !_moreForms)),
        ],
      ),
      if (_moreForms && rest.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in rest) PillButton(label: f.name, selected: _formId == f.id, onTap: () => setState(() => _formId = f.id)),
        ]),
      ],
    ]);
  }

  Widget _whenTiles(Round18Strings s) {
    final choices = [
      (TakeWhen.everyDay, s.everyDay),
      (TakeWhen.certainDays, s.certainDays),
      (TakeWhen.everyFewDays, s.everyFewDays),
      // A pharmacist's medicine keeps its own kind.
      if (!_limited) (TakeWhen.asNeeded, s.onlyWhenNeeded),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3.4,
        children: [
          for (final (w, label) in choices)
            PillButton(
              key: ValueKey('when-${w.name}'),
              label: label,
              square: true,
              selected: _when == w,
              onTap: () => setState(() {
                _when = w;
                // Every few days: one dose on those days.
                if (w == TakeWhen.everyFewDays && !_limited) _times = [_times.first];
              }),
            ),
        ],
      ),
      if (_when == TakeWhen.certainDays) ...[
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final d in [6, 0, 1, 2, 3, 4, 5])
            PillButton(
              key: ValueKey('day-$d'),
              label: s.weekdayShort[d],
              selected: _weekdays.contains(d),
              onTap: () => setState(() => _weekdays.contains(d) ? _weekdays.remove(d) : _weekdays.add(d)),
            ),
        ]),
      ],
      if (_when == TakeWhen.everyFewDays) ...[
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          initialValue: _everyN,
          items: [for (final n in [2, 3, 4, 5, 6, 7, 10, 14, 15, 21, 28, 30]) DropdownMenuItem(value: n, child: Text(s.onceEvery(n)))],
          onChanged: (v) => setState(() => _everyN = v ?? 2),
        ),
      ],
    ]);
  }

  Widget _timesPicker(Round18Strings s) {
    final pattern = prescriptionPatterns.where((k) => patternTimes(k).join() == _times.join()).firstOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        for (var n = 1; n <= 6; n++) ...[
          if (n > 1) const SizedBox(width: 6),
          Expanded(
            child: PillButton(
              key: ValueKey('times-$n'),
              label: s.n(n),
              square: true,
              selected: _times.length == n,
              onTap: _limited ? () {} : () => setState(() => _times = defaultTimes(n)),
            ),
          ),
        ],
      ]),
      if (!_limited) ...[
        const SizedBox(height: 10),
        Text(s.orAsWritten, style: TextStyle(color: context.palette.muted, fontSize: AppType.small)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final k in prescriptionPatterns)
            PillButton(label: s.n(k), selected: pattern == k, onTap: () => setState(() => _times = patternTimes(k))),
        ]),
      ],
    ]);
  }

  Widget _doseTimes(BuildContext context, Round18Strings s) {
    final p = context.palette;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(children: [
          for (var i = 0; i < _times.length; i++)
            InkWell(
              key: ValueKey('dose-time-$i'),
              onTap: () async {
                final parts = _times[i].split(':');
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
                );
                if (picked != null) setState(() => _times[i] = toHhmm(picked));
              },
              child: Container(
                decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: p.line3))),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  SlotBadge(hhmm: _times[i]),
                  const SizedBox(width: 12),
                  Expanded(child: Text(slotName(s, _times[i]), style: TextStyle(color: p.muted, fontSize: AppType.small))),
                  Text(_label(_times[i]), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: AppType.body)),
                  const SizedBox(width: 4),
                  Icon(Icons.edit_outlined, size: 18, color: p.muted),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  String _label(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])).label(context);
  }

  Widget _asNeededCard(Round18Strings s) {
    Widget stepper(String title, int? value, int min, int max, String Function(int) shown, ValueChanged<int?> set, {required Key key}) {
      return Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
        IconButton(
          tooltip: '-',
          onPressed: value == null ? null : () => set(value <= min ? null : value - 1),
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        SizedBox(width: 64, child: Text(value == null ? s.notSet : shown(value), key: key, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
        IconButton(
          tooltip: '+',
          onPressed: () => set(value == null ? min : (value >= max ? max : value + 1)),
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ]);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          stepper(s.mostPerDay, _maxPerDay, 1, 24, (v) => s.n(v), (v) => setState(() => _maxPerDay = v), key: const ValueKey('prn-max')),
          stepper(s.minGap, _minGap, 1, 48, s.hoursN, (v) => setState(() => _minGap = v), key: const ValueKey('prn-gap')),
          Text(s.asDoctorSaid, style: TextStyle(color: context.palette.muted, fontSize: AppType.small)),
        ]),
      ),
    );
  }

  Widget _lengthChips(Round18Strings s) {
    final start = _startDate ?? DateUtils.dateOnly(DateTime.now());
    final days = _durationDays;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final c in lengthChoices)
          PillButton(
            key: ValueKey('length-$c'),
            label: c == 0 ? s.ongoing : c == -1 ? s.other : c == 30 ? s.oneMonth : s.daysN(c),
            selected: _length == c,
            onTap: () => setState(() => _length = c),
          ),
      ]),
      if (_length == -1) ...[
        const SizedBox(height: 8),
        TextFormField(
          controller: _otherDays,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(hintText: s.typeDays),
        ),
      ],
      if (_isNew) ...[
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            title: Text(s.starts, style: const TextStyle(fontWeight: FontWeight.w700)),
            trailing: Text(s.dayLabel(start, DateTime.now()), style: const TextStyle(fontWeight: FontWeight.w700)),
            onTap: () async {
              final today = DateUtils.dateOnly(DateTime.now());
              final picked = await showDatePicker(context: context, initialDate: start, firstDate: today, lastDate: today.add(const Duration(days: 365)));
              if (picked != null) setState(() => _startDate = picked);
            },
          ),
        ),
      ],
      const SizedBox(height: 4),
      Text(
        days == null ? s.untilDoctorStops : s.endsOn(s.dateOf(start.add(Duration(days: days - 1)))),
        style: TextStyle(color: context.palette.muted, fontSize: AppType.small),
      ),
    ]);
  }

  Widget _stockCard(Round18Strings s, String? formName) {
    final p = context.palette;
    final unit = _stockUnit ?? unitForForm(formName);
    final count = double.tryParse(_stock.text.trim());
    final perDose = boxUnitsPerDoseOf(_doseAmount.text, unit);
    final perDay = _when == TakeWhen.asNeeded
        ? null
        : _times.length * perDose * (_when == TakeWhen.everyFewDays ? 1 / _everyN : _when == TakeWhen.certainDays ? _weekdays.length / 7 : 1);
    final lasts = count != null && perDay != null && perDay > 0 ? (count / perDay).floor() : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.inventory_2_outlined, color: p.onWarnContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.howMuchHave + s.optional, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(s.howMuchHaveSub, style: TextStyle(color: p.muted, fontSize: AppType.small)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextFormField(
                key: const ValueKey('stock-count'),
                controller: _stock,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(hintText: unit == 'ml' ? '200' : '10', isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: unit,
              underline: const SizedBox.shrink(),
              items: [for (final u in boxUnits) DropdownMenuItem(value: u, child: Text(s.unitName(u)))],
              onChanged: (v) => setState(() => _stockUnit = v),
            ),
          ]),
          if (lasts != null) ...[
            const SizedBox(height: 6),
            Text(s.lastsDays(lasts), style: TextStyle(color: p.onOkContainer, fontWeight: FontWeight.w700, fontSize: AppType.small)),
          ],
          const SizedBox(height: 8),
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 6, children: [
            Text(s.remindWhenLeft, style: TextStyle(color: p.muted, fontSize: AppType.small)),
            for (final d in const [3, 5, 7]) PillButton(label: s.daysN(d), selected: _refillDays == d, onTap: () => setState(() => _refillDays = d)),
          ]),
        ]),
      ),
    );
  }

  Widget _moreDetails(Round18Strings s, String? formName) {
    final p = context.palette;
    final pill = _isPill;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      OutlinedButton(
        key: const ValueKey('more-details'),
        onPressed: () => setState(() => _more = !_more),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.moreDetails + s.optional),
              Text(pill ? s.moreDetailsSubPill : s.moreDetailsSub,
                  style: TextStyle(color: p.muted, fontSize: AppType.small, fontWeight: FontWeight.w400)),
            ]),
          ),
          if (pill && _pillColor != null) PillIcon(color: _pillColor, shape: _pillShape, size: 36),
          Icon(_more ? Icons.expand_less_rounded : Icons.expand_more_rounded),
        ]),
      ),
      if (_more) ...[
        const SizedBox(height: 12),
        if (pill) _lookPicker(s),
        const SizedBox(height: 12),
        ConditionTagField(
          value: _condition,
          forUserId: widget.args.forUserId,
          enabled: !_saving,
          onChanged: (c) => setState(() => _condition = c),
        ),
        const SizedBox(height: 12),
        PackPhotoField(
          picked: _packPhotoPath,
          existing: _routine?.hasPackPhoto ?? false,
          onPicked: (path) => setState(() => _packPhotoPath = path),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _note,
          maxLines: 3,
          maxLength: 300,
          decoration: InputDecoration(labelText: s.note, hintText: s.noteHint),
        ),
      ],
    ]);
  }

  Widget _lookPicker(Round18Strings s) {
    final p = context.palette;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            PillIcon(color: _pillColor, shape: _pillShape, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.realLook + s.optional, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(s.realLookSub, style: TextStyle(color: p.muted, fontSize: AppType.small)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Text(s.colour, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: AppType.small)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            PillButton(label: s.none, selected: _pillColor == null, onTap: () => setState(() => _pillColor = null)),
            for (final (code, name) in s.pillColours)
              Semantics(
                label: name,
                selected: _pillColor == code,
                button: true,
                child: InkWell(
                  key: ValueKey('colour-$code'),
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() {
                    _pillColor = code;
                    _pillShape ??= PillIcon.defaultShape(code);
                  }),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: pillColorValues[code]!.$1,
                      border: Border.all(color: _pillColor == code ? Theme.of(context).colorScheme.primary : pillColorValues[code]!.$2, width: _pillColor == code ? 3 : 1.5),
                    ),
                    child: _pillColor == code ? Icon(Icons.check_rounded, size: 18, color: pillColorValues[code]!.$2) : null,
                  ),
                ),
              ),
          ]),
          if (_pillColor != null) ...[
            const SizedBox(height: 12),
            Text(s.shape, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: AppType.small)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final (code, name) in s.pillShapes)
                PillButton(label: name, selected: _pillShape == code, onTap: () => setState(() => _pillShape = code)),
            ]),
          ],
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, size: 16, color: p.muted),
            const SizedBox(width: 6),
            Expanded(child: Text(s.neverByColour, style: TextStyle(color: p.muted, fontSize: AppType.small))),
          ]),
        ]),
      ),
    );
  }
}

/// The units a box count may be in (BOX_UNITS on the server).
const boxUnits = ['tablet', 'capsule', 'ml', 'spoon', 'drop', 'puff', 'unit', 'dose', 'piece', 'strip', 'pen', 'vial', 'sachet'];

/// Morning / afternoon / night of a dose time (client note point 18).
enum DaySlot { morning, afternoon, night }

DaySlot slotOf(String hhmm) {
  final h = int.tryParse(hhmm.split(':').first) ?? 8;
  if (h >= 4 && h < 12) return DaySlot.morning;
  if (h >= 12 && h < 17) return DaySlot.afternoon;
  return DaySlot.night;
}

String slotName(Round18Strings s, String hhmm) => switch (slotOf(hhmm)) {
      DaySlot.morning => s.morning,
      DaySlot.afternoon => s.afternoon,
      DaySlot.night => s.night,
    };

/// A small sun / noon / moon badge next to a dose time (the demo's slot marks).
class SlotBadge extends StatelessWidget {
  const SlotBadge({super.key, required this.hhmm, this.size = 36});

  final String hhmm;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (icon, bg, fg) = switch (slotOf(hhmm)) {
      DaySlot.morning => (Icons.wb_sunny_outlined, p.warnContainer, p.onWarnContainer),
      DaySlot.afternoon => (Icons.light_mode_outlined, p.primaryContainer, p.onPrimaryContainer),
      DaySlot.night => (Icons.nightlight_outlined, p.navyContainer, p.onNavyContainer),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Icon(icon, size: size * 0.5, color: fg),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        child,
      ]);
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({super.key, required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : p.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? scheme.primary : p.line2, width: 1.5),
          ),
          padding: const EdgeInsets.all(4),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 22, color: selected ? scheme.onPrimary : p.head),
            const SizedBox(height: 4),
            FitLabel(Text(label,
                style: TextStyle(fontSize: AppType.small, fontWeight: FontWeight.w700, color: selected ? scheme.onPrimary : p.head))),
          ]),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.summary, required this.label, required this.saving, required this.onSave});

  final String summary;
  final String label;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(summary, key: const ValueKey('add-summary'), textAlign: TextAlign.center, style: TextStyle(color: p.muted2, fontSize: AppType.small)),
            const SizedBox(height: 8),
            ElevatedButton(
              key: const ValueKey('add-save'),
              onPressed: saving ? null : onSave,
              child: saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : Text(label),
            ),
          ]),
        ),
      ),
    );
  }
}
