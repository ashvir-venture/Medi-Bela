import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../router/app_router.dart';
import '../../../widgets/load_more_list.dart';
import '../../../widgets/state_views.dart';
import '../../care/presentation/reading_screen.dart';
import '../domain/health_models.dart';
import 'health_controller.dart';

/// Every reading, newest first (/health/readings). Round 18: each row is
/// named by its reading type in the app language (insulin showed as
/// "Other: 6.0 units"), and Add opens "Log a reading" (the old free-form
/// add sheet with a type / value / unit form is gone).
class HealthRecordsScreen extends ConsumerStatefulWidget {
  const HealthRecordsScreen({super.key, this.openAdd = false});

  /// Opened from quick add: "Log a reading" comes up at once.
  final bool openAdd;

  @override
  ConsumerState<HealthRecordsScreen> createState() => _HealthRecordsScreenState();
}

class _HealthRecordsScreenState extends ConsumerState<HealthRecordsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(refreshHealthRecordsProvider)());
    if (widget.openAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _logReading(context);
      });
    }
  }

  void _logReading(BuildContext context) => context.push(AppRoutes.healthRecordsAdd);

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final recordsAsync = ref.watch(healthRecordsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.r18.allReadings),
        actions: [
          IconButton(
            key: const ValueKey('readings-add'),
            tooltip: strings.r18.logReading,
            onPressed: () => _logReading(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(refreshHealthRecordsProvider)(),
        child: recordsAsync.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            message: error.toString(),
            retryLabel: strings.retry,
            onRetry: () => ref.read(refreshHealthRecordsProvider)(),
          ),
          data: (records) {
            if (records.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  EmptyView(
                    message: strings.noReadingsYet,
                    icon: Icons.monitor_heart_outlined,
                    actionLabel: strings.r18.logReading,
                    onAction: () => _logReading(context),
                  ),
                ],
              );
            }
            return LoadMoreListView(
              padding: const EdgeInsets.all(16),
              itemCount: records.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) => ReadingTile(record: records[index], strings: strings),
            );
          },
        ),
      ),
    );
  }
}

/// "Insulin: 6 units" / "ইনসুলিন: ৬ ইউনিট", then the date and time.
String readingTitle(HealthRecordModel record, AppStrings strings) {
  final r18 = strings.r18;
  final known = readingTypes.contains(record.type);
  final name = known ? readingTypeName(record.type, strings.r15) : HealthRecordType.displayName(record.type);
  final unit = record.unit == null || record.unit!.isEmpty ? '' : ' ${r18.unit(record.unit!)}';
  return '$name: ${r18.n(trimNumber(record.value))}$unit';
}

/// "6.0" → "6", "9.0" stays "9.0" only for sugar (shown with one decimal).
String trimNumber(String value) {
  final v = double.tryParse(value);
  if (v == null || v != v.roundToDouble()) return value;
  return v.toInt().toString();
}

class ReadingTile extends StatelessWidget {
  const ReadingTile({super.key, required this.record, required this.strings});

  final HealthRecordModel record;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final notes = record.notes;
    final title = record.type == 'BLOOD_SUGAR'
        ? '${readingTypeName(record.type, strings.r15)}: ${strings.r18.n(record.value)}${record.unit == null ? '' : ' ${record.unit}'}'
        : readingTitle(record, strings);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(readingIcon(record.type), color: p.head),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          [strings.r18.dateTime(record.recordedAt), if (notes != null && notes.isNotEmpty) notes].join(' · '),
        ),
        trailing: record.syncState != 'synced'
            ? Tooltip(
                message: strings.r18.notSynced,
                child: Icon(Icons.cloud_upload_outlined, size: 18, color: p.muted),
              )
            : null,
      ),
    );
  }
}
