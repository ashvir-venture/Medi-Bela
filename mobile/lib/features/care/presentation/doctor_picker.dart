import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/core_providers.dart';
import '../domain/care_models.dart';
import 'care_providers.dart';

/// Which doctor a visit or record prescription is for (owner, 2026-11-11):
/// a catalog doctor, one of my own, a new one of mine (private, never added
/// to the pharmacists' catalog), or none.
class DoctorChoice {
  const DoctorChoice.none()
      : doctor = null,
        newName = null,
        newChamber = null,
        newArea = null;
  const DoctorChoice.existing(DoctorRef this.doctor)
      : newName = null,
        newChamber = null,
        newArea = null;
  const DoctorChoice.typed(String this.newName, {this.newChamber, this.newArea}) : doctor = null;

  final DoctorRef? doctor;
  final String? newName;
  final String? newChamber;
  final String? newArea;

  /// The API's doctor fields.
  Map<String, dynamic> toBody() {
    if (doctor != null) return doctor!.mine ? {'myDoctorId': doctor!.id, 'doctorId': null} : {'doctorId': doctor!.id, 'myDoctorId': null};
    if (newName != null && newName!.trim().isNotEmpty) {
      return {
        'newDoctor': {
          'name': newName!.trim(),
          if ((newChamber ?? '').trim().isNotEmpty) 'chamber': newChamber!.trim(),
          if ((newArea ?? '').trim().isNotEmpty) 'area': newArea!.trim(),
        },
      };
    }
    return {'doctorId': null, 'myDoctorId': null};
  }
}

class DoctorPicker extends ConsumerStatefulWidget {
  const DoctorPicker({super.key, required this.value, required this.onChanged, required this.myDoctors, this.who = const CareSubject()});

  final DoctorChoice value;
  final ValueChanged<DoctorChoice> onChanged;
  final List<DoctorRef> myDoctors;
  final CareSubject who;

  @override
  ConsumerState<DoctorPicker> createState() => _DoctorPickerState();
}

class _DoctorPickerState extends ConsumerState<DoctorPicker> {
  final _q = TextEditingController();
  final _name = TextEditingController();
  final _chamber = TextEditingController();
  final _area = TextEditingController();
  Timer? _debounce;
  List<DoctorRef> _found = const [];
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    _typing = widget.value.newName != null;
    _name.text = widget.value.newName ?? '';
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_q, _name, _chamber, _area]) {
      c.dispose();
    }
    super.dispose();
  }

  void _search(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _found = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final res = await ref.read(careApiProvider).searchDoctors(q.trim(), forUserId: widget.who.memberId);
        if (!mounted) return;
        setState(() => _found = [
              for (final d in (res['mine'] as List? ?? [])) DoctorRef.fromJson(Map<String, dynamic>.from(d as Map), mine: true),
              for (final d in (res['catalog'] as List? ?? [])) DoctorRef.fromJson(Map<String, dynamic>.from(d as Map), mine: false),
            ]);
      } catch (_) {
        // Offline: my own doctors are still listed below.
      }
    });
  }

  void _emitTyped() => widget.onChanged(DoctorChoice.typed(_name.text, newChamber: _chamber.text, newArea: _area.text));

  @override
  Widget build(BuildContext context) {
    final s = stringsOf(ref).r15;
    final p = context.palette;
    final picked = widget.value.doctor;
    Widget option(DoctorRef d) {
      final on = picked != null && picked.id == d.id;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() => _typing = false);
            widget.onChanged(on ? const DoctorChoice.none() : DoctorChoice.existing(d));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: on ? p.primaryContainer : p.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: on ? Theme.of(context).colorScheme.primary : p.line2, width: on ? 2 : 1.5),
            ),
            child: Row(children: [
              Icon(Icons.medical_services_outlined, size: 20, color: p.head),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (d.line.isNotEmpty) Text(d.line, style: TextStyle(color: p.muted, fontSize: 13)),
                ]),
              ),
              if (on) Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
            ]),
          ),
        ),
      );
    }

    final shownIds = <String>{};
    final list = [
      ?picked,
      ...widget.myDoctors,
      ..._found,
    ].where((d) => shownIds.add('${d.mine}:${d.id}')).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(controller: _q, onChanged: _search, decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: s.searchDoctor)),
      const SizedBox(height: 8),
      for (final d in list) option(d),
      if (!_typing)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              setState(() => _typing = true);
              _emitTyped();
            },
            icon: const Icon(Icons.add),
            label: Text(s.newDoctor),
          ),
        )
      else ...[
        TextField(controller: _name, decoration: InputDecoration(labelText: s.doctorName), onChanged: (_) => _emitTyped()),
        const SizedBox(height: 8),
        TextField(controller: _chamber, decoration: InputDecoration(labelText: s.chamber + s.optional), onChanged: (_) => _emitTyped()),
        const SizedBox(height: 8),
        TextField(controller: _area, decoration: InputDecoration(labelText: s.area + s.optional), onChanged: (_) => _emitTyped()),
      ],
    ]);
  }
}
