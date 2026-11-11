import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../features/auth/presentation/auth_controller.dart';
import '../../../providers/core_providers.dart';
import '../../medicine_schedule/domain/medicine_schedule_models.dart';
import '../domain/care_content.dart';
import '../domain/care_models.dart';
import '../domain/doctor_report.dart';
import 'care_providers.dart';

String _d(DateTime d) => '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

/// The report for the doctor in English (doctors' language; the pdf package
/// cannot shape Bengali script). Page 1 the summary, then one page per
/// report photo.
Future<Uint8List> buildDoctorReportPdf(DoctorReport r, {required List<(String, Uint8List)> photos, PdfPageFormat format = PdfPageFormat.a4}) async {
  final doc = pw.Document(title: 'Medi-Bela report', author: 'Medi-Bela');
  final small = const pw.TextStyle(fontSize: 8.5);
  final head = pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#143D6B'));
  pw.Widget section(String title, List<pw.Widget> children) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text(title, style: head), pw.SizedBox(height: 3), ...children]),
      );
  pw.Widget table(List<String> header, List<List<String>> rows) => rows.isEmpty
      ? pw.Text('None recorded', style: small)
      : pw.TableHelper.fromTextArray(
          headers: header,
          data: rows,
          headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          cellStyle: small,
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#E5EDF7')),
        );

  final avg = r.bpAverage;
  final fast = r.sugarAverage('FASTING');
  final after = r.sugarAverage('AFTER_FOOD');

  doc.addPage(pw.MultiPage(
    pageFormat: format,
    margin: const pw.EdgeInsets.all(28),
    header: (_) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('Medi-Bela: report for the doctor', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F7C8A'))),
      pw.Text('${_d(r.from)} to ${_d(r.to)}', style: small),
    ]),
    footer: (ctx) => pw.Text('Recorded by the patient or family in the Medi-Bela app. Not a diagnosis. Page ${ctx.pageNumber}', style: const pw.TextStyle(fontSize: 7)),
    build: (_) => [
      pw.Text('Patient: ${r.patientName}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      if (r.conditions.isNotEmpty) pw.Text('Conditions: ${r.conditions.join(', ')}', style: small),
      section('Medicines: doses on time / late / missed', [
        pw.Text('All medicines: ${r.onTime} on time, ${r.late} late, ${r.missed} missed', style: small),
        pw.SizedBox(height: 3),
        table(['Medicine', 'Dose', 'On time', 'Late', 'Missed'], [
          for (final m in r.medicines) [m.name, m.dosage, '${m.onTime}', '${m.late}', '${m.missed}'],
        ]),
      ]),
      section('Blood pressure', [
        if (avg != null) pw.Text('Average ${avg.systolic}/${avg.diastolic} mmHg over ${r.bp.length} readings', style: small),
        table(['Date', 'BP (mmHg)', 'Pulse', 'Arm'], [
          for (final b in r.bp.take(12)) [_d(b.recordedAt.toLocal()), '${b.systolic ?? '-'}/${b.diastolic ?? '-'}', '${b.pulse ?? ''}', b.bpArm == null ? '' : b.bpArm!.toLowerCase()],
        ]),
      ]),
      section('Blood sugar (mmol/L)', [
        if (fast != null || after != null)
          pw.Text('Average fasting ${fast?.toStringAsFixed(1) ?? '-'}, 2 h after food ${after?.toStringAsFixed(1) ?? '-'}', style: small),
        table(['Date', 'Value', 'When'], [
          for (final x in r.sugar.take(12)) [_d(x.recordedAt.toLocal()), x.numericValue?.toStringAsFixed(1) ?? x.value, sugarContextNames[x.sugarContext]?.$1 ?? ''],
        ]),
      ]),
      if (r.insulin.isNotEmpty)
        section('Insulin', [
          table(['Date', 'Units', 'Site'], [
            for (final x in r.insulin.take(12)) [_d(x.recordedAt.toLocal()), x.numericValue?.toString() ?? x.value, injectionSiteNames[x.injectionSite]?.$1 ?? ''],
          ]),
        ]),
      if (r.weights.isNotEmpty || r.temperatures.isNotEmpty)
        section('Weight and temperature', [
          if (r.weights.isNotEmpty) pw.Text('Weight: ${r.weights.last.numericValue ?? r.weights.last.value} kg (${_d(r.weights.last.recordedAt.toLocal())}) to ${r.weights.first.numericValue ?? r.weights.first.value} kg (${_d(r.weights.first.recordedAt.toLocal())})', style: small),
          if (r.temperatures.isNotEmpty) pw.Text('Highest temperature: ${r.temperatures.map((t) => t.numericValue ?? 0).reduce((a, b) => a > b ? a : b)} °F', style: small),
        ]),
      if (r.limitLines.isNotEmpty) section('Limits the doctor gave', [for (final l in r.limitLines) pw.Text(l, style: small)]),
      section('Test results', [
        table(['Date', 'Test', 'Values', 'Lab'], [
          for (final t in r.results)
            [
              _d(t.day),
              t.testKindCode ?? t.otherName ?? '',
              t.values.map((v) => '${v.name} ${v.textValue ?? v.value} ${v.unit ?? ''}'.trim()).join('; ') + ((t.findings ?? '').isEmpty ? '' : ' (${t.findings})'),
              t.lab ?? '',
            ],
        ]),
      ]),
      if (r.questions.isNotEmpty) section('Questions for the doctor', [for (final q in r.questions) pw.Bullet(text: q, style: small)]),
    ],
  ));

  for (final (caption, bytes) in photos) {
    doc.addPage(pw.Page(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => pw.Column(children: [
        pw.Text(caption, style: head),
        pw.SizedBox(height: 6),
        pw.Expanded(child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain)),
      ]),
    ));
  }
  return doc.save();
}

/// The report preview with Share and Print (the printing package).
class DoctorReportScreen extends ConsumerStatefulWidget {
  const DoctorReportScreen({super.key});

  @override
  ConsumerState<DoctorReportScreen> createState() => _DoctorReportScreenState();
}

class _DoctorReportScreenState extends ConsumerState<DoctorReportScreen> {
  Future<Uint8List>? _pdf;

  Future<Uint8List> _make(PdfPageFormat format) async {
    final repo = ref.read(careRepositoryProvider);
    final now = DateTime.now();
    final from = dateOnly(now).subtract(const Duration(days: 29));
    List<MedicineDoseModel> doses;
    try {
      doses = await ref.read(medicineScheduleApiProvider).getHistory(from, now);
    } catch (_) {
      doses = await ref.read(medicineScheduleRepositoryProvider).watchLastWeek().first;
    }
    final report = buildDoctorReport(
      patientName: ref.read(authControllerProvider).valueOrNull?.name ?? '',
      now: now,
      doses: doses,
      readings: await ref.read(healthRecordRepositoryProvider).all(),
      care: await repo.care(),
      records: await repo.records(),
      lookups: ref.read(careLookupsProvider).valueOrNull,
    );
    // Photos need the internet (signed links); a page that fails is left out.
    final photos = <(String, Uint8List)>[];
    final dio = Dio();
    for (final (caption, url) in report.photos.take(20)) {
      try {
        final res = await dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
        if (res.data != null) photos.add((caption, Uint8List.fromList(res.data!)));
      } catch (_) {}
    }
    return buildDoctorReportPdf(report, photos: photos, format: format);
  }

  @override
  Widget build(BuildContext context) {
    final s = stringsOf(ref).r15;
    return Scaffold(
      appBar: AppBar(title: Text(s.pdfCardTitle)),
      body: PdfPreview(
        build: (format) => _pdf ??= _make(format),
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: 'medi-bela-report.pdf',
        loadingWidget: Center(child: Text(s.makingPdf)),
        onError: (context, error) => Center(child: Text(s.pdfFailed)),
      ),
    );
  }
}
