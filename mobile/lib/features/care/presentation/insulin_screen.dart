import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/core_providers.dart';
import '../../health/domain/health_models.dart';
import '../../medicine_box/domain/medicine_box_models.dart';
import '../../medicine_schedule/domain/medicine_schedule_models.dart';
import '../../medicine_schedule/presentation/medicine_schedule_controller.dart';
import '../domain/care_content.dart';
import '../domain/care_models.dart';
import '../domain/reading_rules.dart';
import 'care_actions.dart';
import 'care_providers.dart';
import 'care_widgets.dart';

/// The medicine box answer, cached (it carries each routine's form).
final _boxProvider = StreamProvider.autoDispose<MedicineBox?>((ref) => ref.watch(medicineBoxRepositoryProvider).watch());

/// Insulin medicines: form "Insulin" (when the owner adds it to
/// medicine_forms) or "insulin" in the name (owner to confirm).
bool isInsulinMedicine(String name, String? formName) {
  bool says(String? x) => x != null && (x.toLowerCase().contains('insulin') || x.contains('ইনসুলিন'));
  return says(formName) || says(name);
}

/// The first number in a dose text ("10 units" -> 10).
double? unitsFromDosage(String dosage) {
  final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(westernDigits(dosage));
  return m == null ? null : double.tryParse(m[1]!);
}

/// Insulin log (Round 15 F): today's insulin doses, where to inject next on
/// a body map (the site used longest ago, never one used today), who gave
/// it, the units, and the pen's opening and use-by date. Logging a dose
/// also marks it taken. For a member (caregiver) the doses are not linked.
class InsulinScreen extends ConsumerStatefulWidget {
  const InsulinScreen({super.key, this.who = const CareSubject()});

  final CareSubject who;

  @override
  ConsumerState<InsulinScreen> createState() => _InsulinScreenState();
}

class _InsulinScreenState extends ConsumerState<InsulinScreen> {
  String? _site;
  String _who = 'SELF';
  final _units = TextEditingController();
  String? _unitsFor;
  bool _why = false;
  bool _saving = false;

  @override
  void dispose() {
    _units.dispose();
    super.dispose();
  }

  Future<void> _log(MedicineDoseModel? dose, String site, Round15Strings s) async {
    final units = parseNumber(_units.text);
    if (units == null || units < 0.5 || units > 200) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.numberOutOfRange)));
      return;
    }
    setState(() => _saving = true);
    final details = <String, dynamic>{'numericValue': units, 'injectionSite': site, 'injectionGiver': _who};
    final ok = await runCareAction(context, ref, () async {
      if (widget.who.isMember) {
        await ref.read(healthApiProvider).createRecord(
              type: 'INSULIN',
              value: units.toString(),
              unit: 'units',
              recordedAt: DateTime.now(),
              details: details,
              forUserId: widget.who.memberId,
            );
        CareActions(ref, widget.who).readingsChanged();
        return;
      }
      var linked = false;
      if (dose != null) linked = await ref.read(markDoseTakenProvider)(dose.id);
      await ref.read(healthRecordRepositoryProvider).create(
            type: 'INSULIN',
            value: units.toString(),
            unit: 'units',
            recordedAt: DateTime.now(),
            details: {...details, if (linked) 'doseId': dose!.id},
          );
    }, done: s.insulinLogged);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) {
        _site = null;
        _unitsFor = null;
      }
    });
  }

  Future<void> _newPen(Round15Strings s) async {
    var opened = DateTime.now();
    final life = TextEditingController(text: '28');
    final remind = TextEditingController(text: '3');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: Text(s.penNew),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.penOpenedOn),
              trailing: Text(shortDate(opened, s), style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () async {
                final d = await showDatePicker(context: ctx, initialDate: opened, firstDate: DateTime.now().subtract(const Duration(days: 90)), lastDate: DateTime.now());
                if (d != null) setInner(() => opened = d);
              },
            ),
            TextField(controller: life, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: s.penLifeDays, suffixText: s.daysUnit)),
            TextField(controller: remind, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: s.penRemindBefore, suffixText: s.daysUnit)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.save)),
          ],
        ),
      ),
    );
    final lifeDays = parseNumber(life.text)?.round();
    final remindDays = parseNumber(remind.text)?.round();
    life.dispose();
    remind.dispose();
    if (saved != true || lifeDays == null || lifeDays < 1 || lifeDays > 90 || remindDays == null || remindDays < 0 || remindDays > 14 || !mounted) return;
    await runCareAction(
      context,
      ref,
      () => CareActions(ref, widget.who).updateSetting('diabetes', {
        'pen': {'openedOn': isoDate(opened), 'lifeDays': lifeDays, 'remindDaysBefore': remindDays},
      }),
      done: s.saved,
    );
    await ref.read(careRemindersProvider).reconcile();
  }

  @override
  Widget build(BuildContext context) {
    final s = stringsOf(ref).r15;
    final p = context.palette;
    final now = DateTime.now();
    final care = watchCareOf(ref, widget.who).valueOrNull ?? CareOverview.empty;
    final readings = watchReadingsOf(ref, widget.who).valueOrNull ?? const <HealthRecordModel>[];
    final injections = readings.where((r) => r.type == 'INSULIN').toList();
    final lastUsed = <String, DateTime>{};
    for (final r in injections) {
      final site = r.injectionSite;
      if (site == null) continue;
      final at = r.recordedAt.toLocal();
      if (lastUsed[site] == null || at.isAfter(lastUsed[site]!)) lastUsed[site] = at;
    }
    final suggested = suggestedSite(lastUsed, now);
    final site = _site ?? suggested;

    // Today's insulin doses (own only: the member's doses stay on their phone).
    final box = widget.who.isMember ? null : ref.watch(_boxProvider).valueOrNull;
    final insulinRoutines = {
      for (final i in box?.items ?? const <MedicineBoxItem>[])
        if (isInsulinMedicine(i.medicineName, i.formName)) i.routineId,
    };
    final today = widget.who.isMember ? const <MedicineDoseModel>[] : (ref.watch(todaysMedicineProvider).valueOrNull ?? const <MedicineDoseModel>[]);
    final doses = today.where((d) => insulinRoutines.contains(d.routineId) || isInsulinMedicine(d.medicineName, null)).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final due = doses.where((d) => !d.isTaken && d.canMarkTakenAt(now)).firstOrNull;
    if (due != null && _unitsFor != due.id) {
      _unitsFor = due.id;
      final u = unitsFromDosage(due.dosage);
      _units.text = u == null ? '' : (u == u.roundToDouble() ? u.toStringAsFixed(0) : '$u');
    }
    final injectionFor = {for (final r in injections) if (r.doseId != null) r.doseId!: r};

    final pen = care.setting('diabetes')['pen'];
    final penInfo = pen is Map && pen['openedOn'] is String
        ? penStatus(parseDate(pen['openedOn'] as String), (pen['lifeDays'] as num).toInt(), (pen['remindDaysBefore'] as num?)?.toInt() ?? 0, now)
        : null;

    final noInsulin = !widget.who.isMember && doses.isEmpty && injections.isEmpty && insulinRoutines.isEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(widget.who.isMember ? '${s.insulinLog} · ${widget.who.memberName ?? ''}' : s.insulinLog)),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          if (noInsulin)
            SectionCard(children: [
              const Align(alignment: Alignment.centerLeft, child: IconTile(Icons.vaccines_outlined)),
              const SizedBox(height: 8),
              Text(s.noInsulin, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              const SizedBox(height: 4),
              Text(s.noInsulinSub, style: TextStyle(color: p.muted)),
              const SizedBox(height: 8),
              FilledButton.icon(onPressed: () => context.push('/medicines/form'), icon: const Icon(Icons.add), label: Text(s.addInsulin)),
            ]),
          if (doses.isNotEmpty)
            SectionCard(title: s.today, children: [
              for (final d in doses)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: d.isTaken ? p.taken : p.surface2,
                      child: d.isTaken ? Icon(Icons.check, color: p.onTaken) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${d.medicineName}, ${s.n(d.dosage)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                          d.isTaken
                              ? s.insulinGiven(
                                  timeLabel(context, (d.takenAt ?? d.scheduledAt).toLocal(), s),
                                  injectionFor[d.id]?.injectionSite == null ? '' : tr(injectionSiteNames[injectionFor[d.id]!.injectionSite]!, s.bn),
                                )
                              : s.insulinDue(timeLabel(context, d.scheduledAt.toLocal(), s)),
                          style: TextStyle(color: p.muted, fontSize: 13),
                        ),
                      ]),
                    ),
                  ]),
                ),
            ]),
          SectionCard(title: s.whereNext, subtitle: s.whereNextSub, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              BodyMap(selected: site, suggested: suggested, lastUsed: lastUsed, now: now, onTap: (x) => setState(() => _site = x), names: {for (final e in injectionSiteNames.entries) e.key: tr(e.value, s.bn)}),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _Legend(color: p.taken, text: s.suggestedNext),
                  _Legend(color: p.warningStrong, text: s.usedToday),
                  _Legend(color: p.line2, text: s.usedEarlier),
                  const SizedBox(height: 6),
                  Text(s.bodyFacesYou, style: TextStyle(color: p.muted, fontSize: 12)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.6,
              children: [
                for (final x in injectionSites)
                  _SiteTile(
                    name: tr(injectionSiteNames[x]!, s.bn),
                    sub: () {
                      final at = lastUsed[x];
                      if (at == null) return s.notUsedYet;
                      if (dateOnly(at) == dateOnly(now)) return '${s.today} ${timeLabel(context, at, s)}';
                      return s.usedOn(dayLabel(at, s));
                    }(),
                    selected: x == site,
                    today: lastUsed[x] != null && dateOnly(lastUsed[x]!) == dateOnly(now),
                    onTap: () => setState(() => _site = x),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(s.whoGave + s.optional, style: TextStyle(color: p.muted, fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (final e in injectionGiverNames.entries) PillButton(label: tr(e.value, s.bn), selected: _who == e.key, onTap: () => setState(() => _who = e.key)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.unitsGiven, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (due != null) Text(s.prescribedUnits(s.n(due.dosage)), style: TextStyle(color: p.muted, fontSize: 13)),
                ]),
              ),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _units,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            if (doses.isNotEmpty && due == null && doses.every((d) => d.isTaken))
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: p.okContainer, borderRadius: BorderRadius.circular(12)),
                child: Text(s.allInsulinDone, style: TextStyle(color: p.onOkContainer, fontWeight: FontWeight.w700)),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: p.taken, foregroundColor: p.onTaken),
              onPressed: _saving ? null : () => _log(due, site, s),
              icon: const Icon(Icons.check),
              label: Text(s.logInsulinAt(tr(injectionSiteNames[site]!, s.bn))),
            ),
          ]),
          if (penInfo != null)
            SectionCard(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const IconTile(Icons.inventory_2_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.penInUse(shortDate(parseDate(pen['openedOn'] as String), s)), style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(s.penUseBy(shortDate(penInfo.useBy, s), ((pen['remindDaysBefore'] as num?) ?? 0).toInt()), style: TextStyle(color: p.muted2, fontSize: 13)),
                    if (penInfo.warn)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: StateChip(penInfo.daysLeft <= 0 ? s.penExpired : s.penExpires(inDaysLabel(penInfo.useBy, s)), tone: ToneKind.warn, icon: Icons.warning_amber_rounded),
                      ),
                  ]),
                ),
              ]),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => _newPen(s), child: Text(s.penNew)),
            ])
          else
            Card(
              child: ListTile(
                leading: const IconTile(Icons.inventory_2_outlined),
                title: Text(s.penAdd + s.optional),
                subtitle: Text(s.penAddSub),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _newPen(s),
              ),
            ),
          Card(
            color: p.surface2,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                InkWell(
                  onTap: () => setState(() => _why = !_why),
                  child: Row(children: [
                    Expanded(child: Text(s.whyRotate, style: const TextStyle(fontWeight: FontWeight.w700))),
                    Icon(_why ? Icons.expand_less : Icons.expand_more),
                  ]),
                ),
                if (_why) ...[const SizedBox(height: 6), Text(tr(whyRotateSites, s.bn), style: TextStyle(color: p.muted2))],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ]),
      );
}

class _SiteTile extends StatelessWidget {
  const _SiteTile({required this.name, required this.sub, required this.selected, required this.today, required this.onTap});

  final String name;
  final String sub;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bg = selected ? p.okContainer : today ? p.warnContainer : p.surface;
    final fg = selected ? p.onOkContainer : today ? p.onWarnContainer : p.ink;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? p.taken : (today ? Colors.transparent : p.line2), width: selected ? 2 : 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(name, style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: today || selected ? fg : p.muted)),
        ]),
      ),
    );
  }
}

/// A simple front-facing body with the 6 sites (its left = the viewer's right).
class BodyMap extends StatelessWidget {
  const BodyMap({super.key, required this.selected, required this.suggested, required this.lastUsed, required this.now, required this.onTap, required this.names});

  final String selected;
  final String suggested;
  final Map<String, DateTime> lastUsed;
  final DateTime now;
  final ValueChanged<String> onTap;
  final Map<String, String> names;

  /// Site positions in a 150 x 272 box (the demo's SITE_XY).
  static const positions = <String, Offset>{
    'LEFT_ARM': Offset(122, 92),
    'RIGHT_ARM': Offset(28, 92),
    'LEFT_ABDOMEN': Offset(90, 112),
    'RIGHT_ABDOMEN': Offset(60, 112),
    'LEFT_THIGH': Offset(90, 190),
    'RIGHT_THIGH': Offset(60, 190),
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: 150,
      height: 272,
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _BodyPainter(fill: p.surface2, line: p.line2))),
        for (final e in positions.entries)
          Positioned(
            left: e.value.dx - 20,
            top: e.value.dy - 20,
            child: Semantics(
              button: true,
              label: names[e.key],
              selected: e.key == selected,
              child: GestureDetector(
                onTap: () => onTap(e.key),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: Container(
                      width: e.key == selected ? 22 : 14,
                      height: e.key == selected ? 22 : 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: lastUsed[e.key] != null && dateOnly(lastUsed[e.key]!) == dateOnly(now)
                            ? p.warningStrong
                            : e.key == suggested
                                ? p.taken
                                : p.line2,
                        border: e.key == selected ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3) : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _BodyPainter extends CustomPainter {
  _BodyPainter({required this.fill, required this.line});

  final Color fill;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final f = Paint()..color = fill;
    final l = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    void shape(RRect r) {
      canvas.drawRRect(r, f);
      canvas.drawRRect(r, l);
    }

    canvas.drawCircle(const Offset(75, 24), 18, f);
    canvas.drawCircle(const Offset(75, 24), 18, l);
    shape(RRect.fromRectAndRadius(const Rect.fromLTWH(44, 46, 62, 96), const Radius.circular(20)));
    shape(RRect.fromRectAndRadius(const Rect.fromLTWH(17, 50, 22, 88), const Radius.circular(11)));
    shape(RRect.fromRectAndRadius(const Rect.fromLTWH(111, 50, 22, 88), const Radius.circular(11)));
    shape(RRect.fromRectAndRadius(const Rect.fromLTWH(46, 146, 27, 118), const Radius.circular(13)));
    shape(RRect.fromRectAndRadius(const Rect.fromLTWH(77, 146, 27, 118), const Radius.circular(13)));
  }

  @override
  bool shouldRepaint(covariant _BodyPainter old) => old.fill != fill || old.line != line;
}
