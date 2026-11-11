import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/core_providers.dart';
import '../domain/care_models.dart';
import 'care_actions.dart';
import 'care_providers.dart';
import 'care_widgets.dart';
import 'doctor_picker.dart';

/// A doctor visit (Round 16 A), a pregnancy check-up (kind ANC) or a chemo
/// session (kind CHEMO): date, optional time, doctor, condition, note and
/// "Remind me the day before" (19:00).
class VisitFormScreen extends ConsumerStatefulWidget {
  const VisitFormScreen({super.key, this.id, this.kind = 'VISIT', this.condition, this.who = const CareSubject()});

  final String? id;
  final String kind;
  final String? condition;
  final CareSubject who;

  @override
  ConsumerState<VisitFormScreen> createState() => _VisitFormScreenState();
}

class _VisitFormScreenState extends ConsumerState<VisitFormScreen> {
  DateTime _date = DateTime.now().add(const Duration(days: 7));
  TimeOfDay? _time;
  DoctorChoice _doctor = const DoctorChoice.none();
  String? _condition;
  bool _remind = true;
  final _note = TextEditingController();
  int? _number;
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _load(RecordsOverview records) {
    _loaded = true;
    _condition = widget.condition;
    if (widget.kind == 'ANC') {
      _number = records.appointments.where((a) => a.kind == AppointmentKind.anc).length + 1;
    }
    final a = widget.id == null ? null : records.appointments.where((x) => x.id == widget.id).firstOrNull;
    if (a == null) return;
    _date = a.day;
    if (a.time != null) {
      final p = a.time!.split(':').map(int.parse).toList();
      _time = TimeOfDay(hour: p[0], minute: p[1]);
    }
    _doctor = a.doctor == null ? const DoctorChoice.none() : DoctorChoice.existing(a.doctor!);
    _condition = a.conditionCode;
    _remind = a.remind;
    _note.text = a.note ?? '';
    _number = a.number;
  }

  Future<void> _save() async {
    final s = stringsOf(ref).r15;
    setState(() => _saving = true);
    final body = <String, dynamic>{
      if (widget.id == null) 'kind': widget.kind,
      'date': isoDate(_date),
      'time': _time == null ? null : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}',
      ..._doctor.toBody(),
      'conditionCode': _condition,
      if (widget.kind == 'ANC') 'number': _number,
      'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
      'remind': _remind,
    };
    final ok = await runCareAction(context, ref, () => CareActions(ref, widget.who).saveAppointment(body, id: widget.id), done: s.saved);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;
    if (!widget.who.isMember) await ref.read(careRemindersProvider).reconcile();
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final ok = await runCareAction(context, ref, () => CareActions(ref, widget.who).deleteAppointment(widget.id!));
    if (!ok || !mounted) return;
    if (!widget.who.isMember) await ref.read(careRemindersProvider).reconcile();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = stringsOf(ref).r15;
    final p = context.palette;
    final records = watchRecordsOf(ref, widget.who).valueOrNull;
    final care = watchCareOf(ref, widget.who).valueOrNull ?? CareOverview.empty;
    final lookups = ref.watch(careLookupsProvider).valueOrNull;
    if (records != null && !_loaded) _load(records);
    final title = switch (widget.kind) { 'ANC' => s.checkupN(_number ?? 1), 'CHEMO' => s.chemoSession, _ => s.visitTitle };

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [if (widget.id != null) IconButton(tooltip: s.removeDate, onPressed: _delete, icon: const Icon(Icons.delete_outline))],
      ),
      body: records == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Column(children: [
                    ListTile(
                      title: Text(s.date, style: const TextStyle(fontWeight: FontWeight.w700)),
                      trailing: Text(shortDate(_date, s), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      onTap: () async {
                        final now = DateTime.now();
                        final d = await showDatePicker(context: context, initialDate: _date, firstDate: now.subtract(const Duration(days: 365)), lastDate: now.add(const Duration(days: 730)));
                        if (d != null) setState(() => _date = d);
                      },
                    ),
                    Divider(height: 1, color: p.line3),
                    ListTile(
                      title: Text(s.time + s.optional, style: const TextStyle(fontWeight: FontWeight.w700)),
                      trailing: Text(_time == null ? '—' : s.n(_time!.format(context)), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      onTap: () async {
                        final t = await showTimePicker(context: context, initialTime: _time ?? const TimeOfDay(hour: 17, minute: 0));
                        if (t != null) setState(() => _time = t);
                      },
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                if (widget.kind != 'CHEMO') ...[
                  Text(s.whichDoctor + (widget.kind == 'VISIT' ? '' : s.optional), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  DoctorPicker(value: _doctor, onChanged: (d) => setState(() => _doctor = d), myDoctors: records.myDoctors, who: widget.who),
                  const SizedBox(height: 14),
                ],
                if (care.conditions.isNotEmpty && widget.kind == 'VISIT') ...[
                  Text(s.forWhichCondition + s.optional, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final code in care.conditions)
                      PillButton(
                        label: conditionName(code, lookups, s.bn),
                        selected: _condition == code,
                        onTap: () => setState(() => _condition = _condition == code ? null : code),
                      ),
                  ]),
                  const SizedBox(height: 14),
                ],
                TextField(controller: _note, maxLines: 3, maxLength: 300, decoration: InputDecoration(labelText: s.note + s.optional)),
                Card(
                  child: SwitchListTile(
                    value: _remind,
                    onChanged: (v) => setState(() => _remind = v),
                    title: Text(s.remindTestDayBefore, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(s.remindVisitSub),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(s.save),
                ),
                if (widget.kind == 'VISIT') ...[
                  const SizedBox(height: 8),
                  NoteLine(s.privateDoctorNote, icon: Icons.lock_outline),
                ],
              ],
            ),
    );
  }
}
