import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/core_providers.dart';
import '../../prescription/domain/prescription_photo.dart';
import '../domain/care_content.dart';
import '../domain/care_models.dart';
import 'care_actions.dart';
import 'care_providers.dart';
import 'care_widgets.dart';
import '../../../widgets/fit_label.dart';

/// Picks one page photo, shrunk like prescription photos (2000 px, q80).
Future<String?> pickRecordPhoto(ImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: prescriptionPhotoMaxSide,
    maxHeight: prescriptionPhotoMaxSide,
    imageQuality: prescriptionPhotoQuality,
  );
  return file?.path;
}

/// Photo pages: the uploaded ones (signed links) and new ones on the phone.
class PhotoPagesField extends StatelessWidget {
  const PhotoPagesField({super.key, required this.uploaded, required this.local, required this.onAdd, required this.onRemoveLocal, this.onRemoveUploaded, required this.s});

  final List<RecordPhoto> uploaded;
  final List<String> local;
  final void Function(ImageSource) onAdd;
  final void Function(int) onRemoveLocal;
  final void Function(RecordPhoto)? onRemoveUploaded;
  final Round15Strings s;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget thumb(Widget image, VoidCallback? remove) => Stack(clipBehavior: Clip.none, children: [
          ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(width: 62, height: 82, child: image)),
          if (remove != null)
            Positioned(
              top: -8,
              right: -8,
              child: IconButton.filled(
                iconSize: 14,
                constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                padding: EdgeInsets.zero,
                tooltip: s.remove,
                onPressed: remove,
                icon: const Icon(Icons.close),
              ),
            ),
        ]);
    final any = uploaded.isNotEmpty || local.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (any)
        Wrap(spacing: 14, runSpacing: 14, children: [
          for (final ph in uploaded)
            thumb(
              Image.network(ph.imageUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: p.surface2, child: const Icon(Icons.image_outlined))),
              onRemoveUploaded == null ? null : () => onRemoveUploaded!(ph),
            ),
          for (var i = 0; i < local.length; i++) thumb(Image.file(File(local[i]), fit: BoxFit.cover), () => onRemoveLocal(i)),
        ]),
      if (any) const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: any
              ? OutlinedButton.icon(onPressed: () => onAdd(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined), label: Text(s.addPage))
              : FilledButton.icon(onPressed: () => onAdd(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined), label: Text(s.takePhoto)),
        ),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: () => onAdd(ImageSource.gallery), icon: const Icon(Icons.image_outlined), label: FitLabel(Text(s.fromGallery)))),
      ]),
    ]);
  }
}

/// "Test or report" (Round 16 B, C): an upcoming test (date, reminder the
/// day before at 09:00, fasting) or a done one with results: the values of
/// the owner's test list (exactly as printed), more values by name, the
/// blood group, findings, lab and report photos (private, signed links).
class TestFormScreen extends ConsumerStatefulWidget {
  const TestFormScreen({super.key, this.id, this.kind, this.done = false, this.reminderId, this.condition, this.who = const CareSubject()});

  final String? id;
  final String? kind;
  final bool done;
  final String? reminderId;
  final String? condition;
  final CareSubject who;

  @override
  ConsumerState<TestFormScreen> createState() => _TestFormScreenState();
}

class _ExtraValue {
  final name = TextEditingController();
  final value = TextEditingController();
  final unit = TextEditingController();
  void dispose() {
    name.dispose();
    value.dispose();
    unit.dispose();
  }
}

class _TestFormScreenState extends ConsumerState<TestFormScreen> {
  String? _kind;
  final _other = TextEditingController();
  late bool _done = widget.done;
  DateTime _date = DateTime.now();
  bool _remind = true;
  bool _fasting = false;
  final _findings = TextEditingController();
  final _lab = TextEditingController();
  final _fieldValues = <String, TextEditingController>{};
  final _extra = <_ExtraValue>[];
  String? _bloodGroup;
  final _localPhotos = <String>[];
  OwnTest? _existing;
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _kind = widget.kind;
    if (!widget.done) _date = DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    for (final c in [_other, _findings, _lab, ..._fieldValues.values]) {
      c.dispose();
    }
    for (final e in _extra) {
      e.dispose();
    }
    super.dispose();
  }

  TextEditingController _field(String code) => _fieldValues.putIfAbsent(code, TextEditingController.new);

  void _load(RecordsOverview records, CareLookups? lookups) {
    _loaded = true;
    final t = widget.id == null ? null : records.tests.where((x) => x.id == widget.id).firstOrNull;
    if (t == null) return;
    _existing = t;
    _kind = t.testKindCode;
    _other.text = t.otherName ?? '';
    _done = widget.done || t.done;
    _date = t.done || !widget.done ? t.day : DateTime.now();
    _remind = t.remind;
    _fasting = t.fasting;
    _findings.text = t.findings ?? '';
    _lab.text = t.lab ?? '';
    final kind = lookups?.testKind(t.testKindCode);
    for (final v in t.values) {
      final f = kind?.fields.where((x) => x.id == v.fieldId).firstOrNull;
      if (f != null && f.code == 'bg') {
        _bloodGroup = v.textValue;
      } else if (f != null) {
        _field(f.code).text = v.value == null ? '' : _plain(v.value!);
      } else {
        final e = _ExtraValue();
        e.name.text = v.name;
        e.value.text = v.value == null ? '' : _plain(v.value!);
        e.unit.text = v.unit ?? '';
        _extra.add(e);
      }
    }
  }

  static String _plain(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Future<void> _addPhoto(ImageSource source) async {
    final path = await pickRecordPhoto(source);
    if (path == null || !mounted) return;
    if (_existing != null) {
      await runCareAction(context, ref, () => CareActions(ref, widget.who).addPhoto(path: path, testId: _existing!.id));
      return;
    }
    setState(() => _localPhotos.add(path));
  }

  Future<void> _save(CareLookups? lookups) async {
    final s = stringsOf(ref).r15;
    final kindCode = (_kind == null || _kind!.isEmpty) ? null : _kind;
    if (_existing == null && kindCode == null && _other.text.trim().isEmpty) {
      setState(() => _error = s.pickTest);
      return;
    }
    final kind = lookups?.testKind(kindCode ?? _existing?.testKindCode);
    final values = <Map<String, dynamic>>[];
    if (_done) {
      for (final f in kind?.fields ?? const <TestKindField>[]) {
        if (f.code == 'bg') {
          if (_bloodGroup != null) values.add({'fieldCode': 'bg', 'textValue': _bloodGroup});
          continue;
        }
        final v = parseNumber(_field(f.code).text);
        if (v != null) values.add({'fieldCode': f.code, 'value': v});
      }
      for (final e in _extra) {
        final v = parseNumber(e.value.text);
        if (e.name.text.trim().isEmpty || v == null) continue;
        values.add({'name': e.name.text.trim(), 'value': v, if (e.unit.text.trim().isNotEmpty) 'unit': e.unit.text.trim()});
      }
    }
    final body = <String, dynamic>{
      if (_existing == null) ...{
        if (kindCode != null) 'testKindCode': kindCode else 'otherName': _other.text.trim(),
        if (widget.reminderId != null) 'healthReminderId': widget.reminderId,
        'conditionCode': ?widget.condition,
      },
      'status': _done ? 'DONE' : 'UPCOMING',
      'date': isoDate(_date),
      'remind': _done ? false : _remind,
      'fasting': _done ? false : _fasting,
      if (_done) ...{
        'findings': _findings.text.trim().isEmpty ? null : _findings.text.trim(),
        'lab': _lab.text.trim().isEmpty ? null : _lab.text.trim(),
        'values': values,
      },
    };
    setState(() {
      _saving = true;
      _error = null;
    });
    final actions = CareActions(ref, widget.who);
    String? savedId;
    final ok = await runCareAction(context, ref, () async {
      final saved = await actions.saveTest(body, id: _existing?.id);
      savedId = saved['id'] as String?;
    }, done: s.saved);
    if (ok && savedId != null && _localPhotos.isNotEmpty) {
      for (final path in _localPhotos) {
        if (!mounted) break;
        final uploaded = await runCareAction(context, ref, () => actions.addPhoto(path: path, testId: savedId));
        if (!uploaded) break;
      }
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;
    if (!widget.who.isMember) await ref.read(careRemindersProvider).reconcile();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = stringsOf(ref).r15;
    final p = context.palette;
    final lookups = ref.watch(careLookupsProvider).valueOrNull;
    final records = watchRecordsOf(ref, widget.who).valueOrNull;
    if (records != null && !_loaded) _load(records, lookups);
    final kinds = lookups?.testKinds ?? const <TestKind>[];
    final kind = lookups?.testKind(_kind);
    final existing = _existing == null ? null : records?.tests.where((t) => t.id == _existing!.id).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(_existing != null ? s.testResult : s.testOrReport)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s.whichTest, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (_existing == null)
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final k in kinds) PillButton(label: k.name(s.bn), selected: _kind == k.code, onTap: () => setState(() => _kind = k.code)),
              PillButton(label: s.otherTest, selected: _kind == '', onTap: () => setState(() => _kind = '')),
            ])
          else
            Text(testName(_existing!.testKindCode, _existing!.otherName, lookups, s.bn), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (_kind == '' && _existing == null) ...[
            const SizedBox(height: 8),
            TextField(controller: _other, decoration: InputDecoration(labelText: s.testName), onChanged: (_) => setState(() {})),
          ],
          const SizedBox(height: 14),
          if (_existing == null || !_existing!.done)
            SegmentedButton<bool>(
              segments: [ButtonSegment(value: false, label: FitLabel(Text(s.comingUpMode))), ButtonSegment(value: true, label: FitLabel(Text(s.doneMode)))],
              selected: {_done},
              onSelectionChanged: (v) => setState(() => _done = v.first),
            ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              title: Text(_done ? s.whenWasIt : s.when, style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: Text(shortDate(_date, s), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              onTap: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: now.subtract(const Duration(days: 3650)),
                  lastDate: _done ? now : now.add(const Duration(days: 730)),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
          ),
          if (_done) ...[
            SectionCard(title: s.enterResults, subtitle: s.exactlyAsPrinted, children: [
              for (final f in kind?.fields ?? const <TestKindField>[])
                if (f.code == 'bg')
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final g in bloodGroups) PillButton(label: g, selected: _bloodGroup == g, onTap: () => setState(() => _bloodGroup = _bloodGroup == g ? null : g)),
                  ])
                else
                  Container(
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line3))),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Expanded(child: Text(f.name(s.bn), style: const TextStyle(fontWeight: FontWeight.w600))),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _field(f.code),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      SizedBox(width: 70, child: Padding(padding: const EdgeInsets.only(left: 6), child: Text(f.unit ?? '', style: TextStyle(color: p.muted, fontSize: 13)))),
                    ]),
                  ),
              for (var i = 0; i < _extra.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    Expanded(child: TextField(controller: _extra[i].name, decoration: InputDecoration(hintText: s.valueName, isDense: true))),
                    const SizedBox(width: 6),
                    SizedBox(width: 72, child: TextField(controller: _extra[i].value, keyboardType: const TextInputType.numberWithOptions(decimal: true), textAlign: TextAlign.end, decoration: InputDecoration(hintText: s.value, isDense: true))),
                    const SizedBox(width: 6),
                    SizedBox(width: 62, child: TextField(controller: _extra[i].unit, decoration: InputDecoration(hintText: s.unit, isDense: true))),
                    IconButton(tooltip: s.remove, onPressed: () => setState(() => _extra.removeAt(i).dispose()), icon: const Icon(Icons.close)),
                  ]),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(onPressed: () => setState(() => _extra.add(_ExtraValue())), icon: const Icon(Icons.add), label: Text(s.addValue)),
              ),
              TextField(controller: _findings, maxLines: 3, decoration: InputDecoration(labelText: s.findings + s.optional, hintText: s.findingsHint)),
              const SizedBox(height: 8),
              TextField(controller: _lab, decoration: InputDecoration(labelText: s.whichLab + s.optional, hintText: s.labName)),
            ]),
            SectionCard(title: s.reportPhoto, subtitle: s.reportPhotoSub, children: [
              PhotoPagesField(
                uploaded: existing?.photos ?? const [],
                local: _localPhotos,
                onAdd: _addPhoto,
                onRemoveLocal: (i) => setState(() => _localPhotos.removeAt(i)),
                onRemoveUploaded: (ph) => runCareAction(context, ref, () => CareActions(ref, widget.who).deletePhoto(ph.id)),
                s: s,
              ),
            ]),
            NoteLine(s.numbersNote),
          ] else
            Card(
              child: Column(children: [
                SwitchListTile(
                  value: _remind,
                  onChanged: (v) => setState(() => _remind = v),
                  title: Text(s.remindTestDayBefore, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(s.remindTestSub),
                ),
                SwitchListTile(value: _fasting, onChanged: (v) => setState(() => _fasting = v), title: Text(s.fastingNeeded)),
              ]),
            ),
          if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: TextStyle(color: p.later, fontWeight: FontWeight.w600))],
          const SizedBox(height: 16),
          FilledButton(onPressed: _saving ? null : () => _save(lookups), child: Text(s.save)),
        ],
      ),
    );
  }
}
