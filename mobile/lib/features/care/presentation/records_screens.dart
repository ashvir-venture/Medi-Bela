import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/care_models.dart';
import 'care_actions.dart';
import 'care_providers.dart';
import 'care_widgets.dart';
import 'doctor_picker.dart';
import 'reading_screen.dart';
import 'test_form_screen.dart';
import '../../../widgets/fit_label.dart';

/// Health records (Round 16): the doctor's PDF, doctor visits, upcoming
/// tests (reminder switch, "Done, add result"), test reports, and
/// prescriptions (kept for the record, or sent to a pharmacist).
class RecordsScreen extends ConsumerWidget {
  const RecordsScreen({super.key, this.who = const CareSubject()});

  final CareSubject who;

  void _add(BuildContext context, Round15Strings s) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text(s.whatToAdd, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
          for (final (icon, tone, title, sub, path) in [
            (Icons.science_outlined, ToneKind.violet, s.addTestReport, s.addTestReportSub, testFormPath(done: true, who: who)),
            (Icons.schedule, ToneKind.navy, s.addUpcomingTest, s.remindDayBefore, testFormPath(who: who)),
            (Icons.description_outlined, ToneKind.navy, s.addRecordRx, s.addRecordRxSub, recordRxPath(who: who)),
            (Icons.medical_services_outlined, ToneKind.navy, s.addVisit, s.remindDayBefore, visitFormPath(who: who)),
          ])
            ListTile(
              leading: IconTile(icon, tone: tone),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(sub),
              onTap: () {
                Navigator.pop(ctx);
                context.push(path);
              },
            ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = stringsOf(ref).r15;
    final p = context.palette;
    final lookups = ref.watch(careLookupsProvider).valueOrNull;
    final async = watchRecordsOf(ref, who);
    final today = dateOnly(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text(who.isMember ? '${s.healthRecords} · ${who.memberName ?? ''}' : s.healthRecords),
        actions: [TextButton.icon(onPressed: () => _add(context, s), icon: const Icon(Icons.add), label: Text(s.add))],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(s.needsInternet)),
        data: (r) {
          final visits = r.appointments.where((a) => !a.day.isBefore(today) && !a.done).toList();
          final missing = r.results.where((t) => t.photos.isEmpty || (!t.hasNumbers && (t.findings ?? '').isEmpty)).length;
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              if (!who.isMember)
                Card(
                  child: ListTile(
                    leading: const IconTile(Icons.picture_as_pdf_outlined, tone: ToneKind.navy),
                    title: Text(s.pdfCardTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(s.pdfCardSub),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/health/records/pdf'),
                  ),
                ),
              if (missing > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: p.warnContainer, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(Icons.warning_amber_rounded, color: p.onWarnContainer),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s.missingNumbers(missing), style: TextStyle(color: p.onWarnContainer))),
                  ]),
                ),
              if (visits.isNotEmpty)
                SectionCard(title: s.doctorVisits, children: [
                  for (final a in visits)
                    InkWell(
                      onTap: () => context.push(visitFormPath(id: a.id, kind: a.kind.name.toUpperCase(), condition: a.conditionCode, who: who)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          DateBox(day: s.n(a.day.day), month: monthShort(a.day, s)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(
                                a.kind == AppointmentKind.anc
                                    ? s.checkupN(a.number ?? 1)
                                    : a.kind == AppointmentKind.chemo
                                        ? s.chemoSession
                                        : (a.doctor?.name ?? s.doctorVisit),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text([inDaysLabel(a.day, s), if (a.time != null) hhmmLabel(context, a.time!, s), if (a.doctor != null && a.doctor!.line.isNotEmpty) a.doctor!.line].join(', '),
                                  style: TextStyle(color: p.muted, fontSize: 13)),
                            ]),
                          ),
                          if (a.byCaregiver) StateChip(s.byCaregiver, tone: ToneKind.navy),
                        ]),
                      ),
                    ),
                ]),
              SectionCard(title: s.upcomingTests, children: [
                if (r.upcomingTests.isEmpty) Text(s.noneYet, style: TextStyle(color: p.muted)),
                for (final t in r.upcomingTests)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        DateBox(day: s.n(t.day.day), month: monthShort(t.day, s)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(testName(t.testKindCode, t.otherName, lookups, s.bn), style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text([inDaysLabel(t.day, s), if (t.fasting) s.fasting].join(', '), style: TextStyle(color: p.muted, fontSize: 13)),
                          ]),
                        ),
                        Text(s.remindMe, style: TextStyle(color: p.muted, fontSize: 12)),
                        Switch(
                          value: t.remind,
                          onChanged: (v) async {
                            await runCareAction(context, ref, () => CareActions(ref, who).saveTest({'remind': v}, id: t.id));
                          },
                        ),
                      ]),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(onPressed: () => context.push(testFormPath(id: t.id, done: true, who: who)), child: Text(s.doneAddResult)),
                      ),
                    ]),
                  ),
              ]),
              SectionCard(
                title: s.testReports,
                trailing: TextButton.icon(onPressed: () => context.push(testFormPath(done: true, who: who)), icon: const Icon(Icons.add, size: 18), label: Text(s.addReport)),
                children: [
                  if (r.results.isEmpty) Text(s.noneYet, style: TextStyle(color: p.muted)),
                  for (final t in r.results)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const IconTile(Icons.science_outlined, tone: ToneKind.violet, size: 40),
                      title: Text(testName(t.testKindCode, t.otherName, lookups, s.bn), style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text([
                        shortDate(t.day, s),
                        if (t.values.isNotEmpty) t.values.take(2).map((v) => '${v.name} ${v.textValue ?? numText(v.value ?? 0, s, decimals: 2)}').join(', '),
                        if (t.photos.isNotEmpty) s.pages(t.photos.length),
                      ].join(' · ')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(testReportPath(t.id, who)),
                    ),
                ],
              ),
              SectionCard(
                title: s.prescriptions,
                trailing: TextButton.icon(onPressed: () => context.push(recordRxPath(who: who)), icon: const Icon(Icons.add, size: 18), label: Text(s.keepRecord)),
                children: [
                  if (r.prescriptions.isEmpty) Text(s.noneYet, style: TextStyle(color: p.muted)),
                  for (final rx in r.prescriptions)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const IconTile(Icons.description_outlined, tone: ToneKind.navy, size: 40),
                      title: Text(rx.doctor?.name ?? s.recordOnly, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text([shortDate(parseDate(rx.date), s), if (rx.conditionCode != null) conditionName(rx.conditionCode!, lookups, s.bn), s.pages(rx.photos.length)].join(' · ')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(recordRxPath(id: rx.id, who: who)),
                    ),
                  if (!who.isMember)
                    OutlinedButton.icon(
                      onPressed: () => context.go('/medicines?tab=prescriptions'),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(s.sendToPharmacist),
                    ),
                  const SizedBox(height: 8),
                  NoteLine(s.recordsNote),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One test report: date, lab, the values (with the doctor's target),
/// earlier results of the same test side by side, the photos.
class TestReportScreen extends ConsumerWidget {
  const TestReportScreen({super.key, required this.id, this.who = const CareSubject()});

  final String id;
  final CareSubject who;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = stringsOf(ref).r15;
    final p = context.palette;
    final lookups = ref.watch(careLookupsProvider).valueOrNull;
    final records = watchRecordsOf(ref, who).valueOrNull;
    final care = watchCareOf(ref, who).valueOrNull ?? CareOverview.empty;
    final t = records?.tests.where((x) => x.id == id).firstOrNull;
    if (records == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (t == null) return Scaffold(appBar: AppBar(), body: Center(child: Text(s.noneYet)));
    final kind = lookups?.testKind(t.testKindCode);
    final earlier = t.testKindCode == null ? const <OwnTest>[] : (records.resultsOf(t.testKindCode!).where((x) => x.id != t.id).toList().reversed.take(5).toList());
    final first = kind?.fields.where((f) => f.code != 'bg').firstOrNull;
    final l = care.limits;
    String? target(String? code) => switch (code) {
          'hba1c' when l?.hba1cTarget != null => s.doctorsTarget('< ${numText(l!.hba1cTarget!, s)}%'),
          'tsh' when l?.tshLow != null && l?.tshHigh != null => s.doctorsTarget('${numText(l!.tshLow!, s, decimals: 2)}–${numText(l.tshHigh!, s, decimals: 2)}'),
          _ => null,
        };

    Future<void> delete() async {
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(s.deleteRecordQ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel)),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: p.later), onPressed: () => Navigator.pop(ctx, true), child: Text(s.delete)),
          ],
        ),
      );
      if (yes != true || !context.mounted) return;
      final ok = await runCareAction(context, ref, () => CareActions(ref, who).deleteTest(t.id));
      if (ok && context.mounted) context.pop();
    }

    return Scaffold(
      appBar: AppBar(title: Text(testName(t.testKindCode, t.otherName, lookups, s.bn))),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          SectionCard(children: [
            Text(shortDate(t.day, s, now: DateTime(0)), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text(t.lab ?? s.noLab, style: TextStyle(color: p.muted)),
            if (t.byCaregiver) Padding(padding: const EdgeInsets.only(top: 6), child: StateChip(s.byCaregiver, tone: ToneKind.navy)),
          ]),
          SectionCard(title: s.results, children: [
            if (t.values.isEmpty && (t.findings ?? '').isEmpty) Text(s.noNumbers, style: TextStyle(color: p.muted)),
            for (final v in t.values)
              Container(
                decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line3))),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(kind?.fields.where((f) => f.id == v.fieldId).firstOrNull?.name(s.bn) ?? v.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (target(kind?.fields.where((f) => f.id == v.fieldId).firstOrNull?.code) != null)
                        Text(target(kind!.fields.firstWhere((f) => f.id == v.fieldId).code)!, style: TextStyle(color: p.muted, fontSize: 12)),
                    ]),
                  ),
                  Text(v.textValue ?? numText(v.value ?? 0, s, decimals: 2), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(v.unit ?? '', style: TextStyle(color: p.muted)),
                ]),
              ),
            if ((t.findings ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(s.findings, style: TextStyle(color: p.muted, fontSize: 13)),
              Text(t.findings!),
            ],
          ]),
          if (earlier.isNotEmpty && first != null)
            SectionCard(title: s.earlierResults, children: [
              for (final e in earlier)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(child: Text(shortDate(e.day, s, now: DateTime(0)))),
                    Text(e.valueOf(first.id) == null ? '—' : '${numText(e.valueOf(first.id)!, s, decimals: 2)} ${first.unit ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                ),
            ]),
          SectionCard(title: s.reportPhotos, children: [
            if (t.photos.isEmpty) Text(s.noPhoto, style: TextStyle(color: p.muted)),
            if (t.photos.isNotEmpty)
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (final ph in t.photos)
                  GestureDetector(
                    onTap: () => showDialog<void>(context: context, builder: (_) => Dialog(child: InteractiveViewer(child: Image.network(ph.imageUrl)))),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(ph.imageUrl, width: 80, height: 104, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(width: 80, height: 104, color: p.surface2, child: const Icon(Icons.image_outlined))),
                    ),
                  ),
              ]),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final path = await pickRecordPhoto(ImageSource.camera);
                if (path == null || !context.mounted) return;
                await runCareAction(context, ref, () => CareActions(ref, who).addPhoto(path: path, testId: t.id));
              },
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(t.photos.isEmpty ? s.takePhoto : s.addPage),
            ),
          ]),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => context.push(testFormPath(id: t.id, done: true, who: who)), icon: const Icon(Icons.edit_outlined), label: FitLabel(Text(s.editNumbers)))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: p.later), onPressed: delete, icon: const Icon(Icons.delete_outline), label: FitLabel(Text(s.delete)))),
          ]),
          const SizedBox(height: 8),
          NoteLine(s.pdfGetsNumbers, icon: Icons.description_outlined),
        ],
      ),
    );
  }
}

/// A prescription kept for the record only (Round 16 D): photos, date,
/// doctor, condition, note. Never in the pharmacist queue, no medicines.
class RecordPrescriptionScreen extends ConsumerStatefulWidget {
  const RecordPrescriptionScreen({super.key, this.id, this.who = const CareSubject()});

  final String? id;
  final CareSubject who;

  @override
  ConsumerState<RecordPrescriptionScreen> createState() => _RecordPrescriptionScreenState();
}

class _RecordPrescriptionScreenState extends ConsumerState<RecordPrescriptionScreen> {
  DateTime _date = DateTime.now();
  DoctorChoice _doctor = const DoctorChoice.none();
  String? _condition;
  final _note = TextEditingController();
  final _local = <String>[];
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  RecordPrescription? _existing(RecordsOverview r) => widget.id == null ? null : r.prescriptions.where((x) => x.id == widget.id).firstOrNull;

  void _load(RecordsOverview r) {
    _loaded = true;
    final rx = _existing(r);
    if (rx == null) return;
    _date = parseDate(rx.date);
    _doctor = rx.doctor == null ? const DoctorChoice.none() : DoctorChoice.existing(rx.doctor!);
    _condition = rx.conditionCode;
    _note.text = rx.note ?? '';
  }

  Future<void> _save(RecordsOverview r) async {
    final s = stringsOf(ref).r15;
    final existing = _existing(r);
    if (existing == null && _local.isEmpty) {
      setState(() => _error = s.addPhotoFirst);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final actions = CareActions(ref, widget.who);
    String? id = existing?.id;
    final ok = await runCareAction(context, ref, () async {
      final saved = await actions.savePrescription({
        'date': isoDate(_date),
        ..._doctor.toBody(),
        'conditionCode': _condition,
        'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
      }, id: id);
      id = saved['id'] as String?;
    }, done: s.saved);
    if (ok && id != null) {
      for (final path in _local) {
        if (!mounted) break;
        if (!await runCareAction(context, ref, () => actions.addPhoto(path: path, prescriptionId: id))) break;
      }
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = stringsOf(ref).r15;
    final p = context.palette;
    final records = watchRecordsOf(ref, widget.who).valueOrNull;
    final care = watchCareOf(ref, widget.who).valueOrNull ?? CareOverview.empty;
    final lookups = ref.watch(careLookupsProvider).valueOrNull;
    if (records != null && !_loaded) _load(records);
    final existing = records == null ? null : _existing(records);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.keepRxTitle),
        actions: [
          if (existing != null)
            IconButton(
              tooltip: s.delete,
              onPressed: () async {
                final ok = await runCareAction(context, ref, () => CareActions(ref, widget.who).deletePrescription(existing.id));
                if (ok && context.mounted) context.pop();
              },
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: records == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: p.navyContainer, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(Icons.lock_outline, color: p.onNavyContainer),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s.keepRxNote, style: TextStyle(color: p.onNavyContainer))),
                  ]),
                ),
                SectionCard(title: s.rxPhoto, children: [
                  PhotoPagesField(
                    uploaded: existing?.photos ?? const [],
                    local: _local,
                    onAdd: (src) async {
                      final path = await pickRecordPhoto(src);
                      if (path == null || !context.mounted) return;
                      if (existing != null) {
                        await runCareAction(context, ref, () => CareActions(ref, widget.who).addPhoto(path: path, prescriptionId: existing.id));
                      } else {
                        setState(() => _local.add(path));
                      }
                    },
                    onRemoveLocal: (i) => setState(() => _local.removeAt(i)),
                    onRemoveUploaded: (ph) => runCareAction(context, ref, () => CareActions(ref, widget.who).deletePhoto(ph.id)),
                    s: s,
                  ),
                ]),
                Card(
                  child: ListTile(
                    title: Text(s.rxDate, style: const TextStyle(fontWeight: FontWeight.w700)),
                    trailing: Text(shortDate(_date, s), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    onTap: () async {
                      final now = DateTime.now();
                      final d = await showDatePicker(context: context, initialDate: _date, firstDate: now.subtract(const Duration(days: 3650 * 3)), lastDate: now);
                      if (d != null) setState(() => _date = d);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Text(s.whichDoctor + s.optional, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                DoctorPicker(value: _doctor, onChanged: (d) => setState(() => _doctor = d), myDoctors: records.myDoctors, who: widget.who),
                if (care.conditions.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(s.forWhichCondition + s.optional, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final code in care.conditions)
                      PillButton(label: conditionName(code, lookups, s.bn), selected: _condition == code, onTap: () => setState(() => _condition = _condition == code ? null : code)),
                  ]),
                ],
                const SizedBox(height: 14),
                TextField(controller: _note, maxLines: 3, maxLength: 500, decoration: InputDecoration(labelText: s.note + s.optional)),
                if (_error != null) Text(_error!, style: TextStyle(color: p.later, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _saving ? null : () => _save(records), child: Text(s.saveToRecords)),
                if (!widget.who.isMember)
                  TextButton(onPressed: () => context.go('/medicines?tab=prescriptions'), child: Text(s.sendToPharmacist)),
              ],
            ),
    );
  }
}
