import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../widgets/state_views.dart';
import '../domain/health_models.dart';
import 'health_controller.dart';

class HealthRecordsScreen extends ConsumerStatefulWidget {
  const HealthRecordsScreen({super.key});

  @override
  ConsumerState<HealthRecordsScreen> createState() => _HealthRecordsScreenState();
}

class _HealthRecordsScreenState extends ConsumerState<HealthRecordsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(refreshHealthRecordsProvider)());
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final recordsAsync = ref.watch(healthRecordsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(strings.healthRecords)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddRecordSheet(context),
        icon: const Icon(Icons.add),
        label: Text(strings.addRecord),
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
                  EmptyView(message: strings.noHealthRecords, icon: Icons.monitor_heart_outlined),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: records.length,
              itemBuilder: (context, index) => _RecordTile(record: records[index]),
            );
          },
        ),
      ),
    );
  }

  void _openAddRecordSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddRecordSheet(),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});

  final HealthRecordModel record;

  @override
  Widget build(BuildContext context) {
    final unitSuffix = record.unit != null ? ' ${record.unit}' : '';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.monitor_heart_outlined),
        title: Text('${HealthRecordType.displayName(record.type)}: ${record.value}$unitSuffix'),
        subtitle: Text(
          [
            _formatDateTime(record.recordedAt),
            if (record.notes != null && record.notes!.isNotEmpty) record.notes!,
          ].join(' • '),
        ),
        trailing: record.syncState != 'synced'
            ? const Icon(Icons.cloud_upload_outlined, size: 18, color: Colors.orange)
            : null,
      ),
    );
  }

  String _formatDateTime(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

class _AddRecordSheet extends ConsumerStatefulWidget {
  const _AddRecordSheet();

  @override
  ConsumerState<_AddRecordSheet> createState() => _AddRecordSheetState();
}

class _AddRecordSheetState extends ConsumerState<_AddRecordSheet> {
  String _type = HealthRecordType.bloodPressure;
  final _valueController = TextEditingController();
  final _unitController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _valueController.dispose();
    _unitController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_valueController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    await ref.read(createHealthRecordProvider)(
      type: _type,
      value: _valueController.text.trim(),
      unit: _unitController.text.trim().isEmpty ? null : _unitController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(strings.addRecord, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: InputDecoration(labelText: strings.recordType),
            items: HealthRecordType.all
                .map((t) => DropdownMenuItem(value: t, child: Text(HealthRecordType.displayName(t))))
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _valueController,
            decoration: InputDecoration(labelText: strings.recordValue),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _unitController,
            decoration: InputDecoration(labelText: strings.recordUnit),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            decoration: InputDecoration(labelText: strings.recordNotes),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: Text(strings.save),
          ),
        ],
      ),
    );
  }
}
