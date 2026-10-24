import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'diabetes_strings.dart';

enum DiabetesLogType { bloodSugar, bloodPressure, insulin, weight, hba1c }

/// Opens the log form for [type]. Placeholder only: nothing is saved.
Future<void> showDiabetesLogSheet(BuildContext context, DiabetesLogType type) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DiabetesLogSheet(type: type),
  );
}

class DiabetesLogSheet extends ConsumerStatefulWidget {
  const DiabetesLogSheet({super.key, required this.type});

  final DiabetesLogType type;

  @override
  ConsumerState<DiabetesLogSheet> createState() => _DiabetesLogSheetState();
}

class _DiabetesLogSheetState extends ConsumerState<DiabetesLogSheet> {
  final _formKey = GlobalKey<FormState>();
  final _value = TextEditingController();
  final _systolic = TextEditingController();
  final _diastolic = TextEditingController();
  final _pulse = TextEditingController();
  final _notes = TextEditingController();

  String _sugarUnit = 'mmol/L';
  String? _when;
  String? _insulinType;
  String? _takenAt;
  DateTime _at = DateTime.now();

  @override
  void dispose() {
    _value.dispose();
    _systolic.dispose();
    _diastolic.dispose();
    _pulse.dispose();
    _notes.dispose();
    super.dispose();
  }

  // ---- helpers -----------------------------------------------------------

  /// Accepts Bangla digits and a decimal comma as well as plain 0-9 and '.'.
  static double? _parse(String raw) {
    const bn = '০১২৩৪৫৬৭৮৯';
    final out = StringBuffer();
    for (final ch in raw.trim().split('')) {
      final i = bn.indexOf(ch);
      out.write(i >= 0 ? '$i' : ch);
    }
    return double.tryParse(out.toString().replaceAll(',', '.'));
  }

  String? _numberError(
    String? raw,
    double min,
    double max, {
    bool isRequired = true,
  }) {
    final s = ref.read(diabetesStringsProvider);
    if (raw == null || raw.trim().isEmpty) {
      return isRequired ? s.errEnterValue : null;
    }
    final n = _parse(raw);
    if (n == null) return s.errValidNumber;
    if (n < min || n > max) return s.errUnusual;
    return null;
  }

  String? _choiceError(String? v) =>
      v == null ? ref.read(diabetesStringsProvider).errChooseOption : null;

  String _formatDateTime(DateTime d, DiabetesStrings s) {
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final mm = d.minute.toString().padLeft(2, '0');
    final suffix = d.hour >= 12 ? s.pm : s.am;
    final dd = d.day.toString().padLeft(2, '0');
    final mo = d.month.toString().padLeft(2, '0');
    return '$dd/$mo/${d.year}, $h12:$mm $suffix';
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year, now.month, now.day, 23, 59),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    if (time == null || !mounted) return;
    setState(() {
      _at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final s = ref.read(diabetesStringsProvider);
    // Placeholder: the entered data is intentionally NOT stored anywhere.
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.construction_outlined),
        title: Text(s.comingSoonTitle),
        content: Text(s.comingSoonBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.ok),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  // ---- UI ----------------------------------------------------------------

  static final _numberFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'[0-9০-৯.,]'),
  );

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required double min,
    required double max,
    bool isRequired = true,
    String? suffix,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [_numberFormatter],
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      validator: (v) => _numberError(v, min, max, isRequired: isRequired),
    );
  }

  Widget _dropdown({
    required String label,
    required List<String> options,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final o in options)
          DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: onChanged,
      validator: _choiceError,
    );
  }

  List<Widget> _fields(DiabetesStrings s) {
    switch (widget.type) {
      case DiabetesLogType.bloodSugar:
        final mmol = _sugarUnit == 'mmol/L';
        return [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'mmol/L', label: Text('mmol/L')),
              ButtonSegment(value: 'mg/dL', label: Text('mg/dL')),
            ],
            selected: {_sugarUnit},
            onSelectionChanged: (sel) => setState(() => _sugarUnit = sel.first),
          ),
          const SizedBox(height: 12),
          _numberField(
            controller: _value,
            label: s.reading,
            suffix: _sugarUnit,
            min: mmol ? 0.5 : 10,
            max: mmol ? 50 : 900,
          ),
          const SizedBox(height: 12),
          _dropdown(
            label: s.whenMeasured,
            options: [s.fasting, s.beforeMeal, s.afterMeal, s.bedtime, s.random],
            value: _when,
            onChanged: (v) => setState(() => _when = v),
          ),
        ];
      case DiabetesLogType.bloodPressure:
        return [
          _numberField(
            controller: _systolic,
            label: s.systolic,
            min: 40,
            max: 300,
          ),
          const SizedBox(height: 12),
          _numberField(
            controller: _diastolic,
            label: s.diastolic,
            min: 20,
            max: 200,
          ),
          const SizedBox(height: 12),
          _numberField(
            controller: _pulse,
            label: s.pulseOptional,
            min: 20,
            max: 250,
            isRequired: false,
          ),
        ];
      case DiabetesLogType.insulin:
        return [
          _numberField(controller: _value, label: s.dose, min: 0.5, max: 300),
          const SizedBox(height: 12),
          _dropdown(
            label: s.insulinType,
            options: [
              s.rapidActing,
              s.shortActing,
              s.intermediate,
              s.longActing,
              s.mixed,
            ],
            value: _insulinType,
            onChanged: (v) => setState(() => _insulinType = v),
          ),
          const SizedBox(height: 12),
          _dropdown(
            label: s.takenAt,
            options: [
              s.beforeBreakfast,
              s.beforeLunch,
              s.beforeDinner,
              s.bedtime,
              s.other,
            ],
            value: _takenAt,
            onChanged: (v) => setState(() => _takenAt = v),
          ),
        ];
      case DiabetesLogType.weight:
        return [
          _numberField(
            controller: _value,
            label: s.weightKg,
            suffix: 'kg',
            min: 1,
            max: 500,
          ),
        ];
      case DiabetesLogType.hba1c:
        return [
          _numberField(
            controller: _value,
            label: s.hba1cPercent,
            suffix: '%',
            min: 2,
            max: 20,
          ),
        ];
    }
  }

  String _title(DiabetesStrings s) => switch (widget.type) {
        DiabetesLogType.bloodSugar => s.bloodSugar,
        DiabetesLogType.bloodPressure => s.bloodPressure,
        DiabetesLogType.insulin => s.insulin,
        DiabetesLogType.weight => s.weight,
        DiabetesLogType.hba1c => s.hba1c,
      };

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(diabetesStringsProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_title(s), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ..._fields(s),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: s.dateTime,
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(_formatDateTime(_at, s)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                maxLines: 2,
                decoration: InputDecoration(labelText: s.notesOptional),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _submit, child: Text(s.submit)),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(s.cancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
