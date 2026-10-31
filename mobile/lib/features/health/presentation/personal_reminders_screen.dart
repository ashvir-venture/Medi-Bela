import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../providers/core_providers.dart';
import '../../../router/app_router.dart';
import '../../../widgets/caregiver_tag.dart';
import '../../../widgets/details_fields.dart' show formatYmd;
import '../../../widgets/interval_field.dart';
import '../../../widgets/state_views.dart';
import '../../prescription/presentation/confirm_prescription_screen.dart' show formatHhmm, toHhmm;
import '../domain/personal_reminder_models.dart';

/// My own reminders (offline copy), or a member's when their caregiver opens
/// it ([forUserId], online).
final _myPersonalRemindersProvider = StreamProvider.autoDispose<List<PersonalReminderModel>>(
  (ref) => ref.watch(personalReminderRepositoryProvider).watchAll(),
);

final _memberPersonalRemindersProvider = FutureProvider.autoDispose.family<List<PersonalReminderModel>, String>(
  (ref, forUserId) => ref.watch(personalReminderApiProvider).list(forUserId: forUserId),
);

class PersonalRemindersArgs {
  const PersonalRemindersArgs({this.forUserId, this.reminder});
  final String? forUserId;
  /// Null = a new one.
  final PersonalReminderModel? reminder;
}

/// "My reminders" (Round 13): reminders the user sets up for themself ("Time
/// for your {name}"), or a caregiver for a member.
class PersonalRemindersScreen extends ConsumerStatefulWidget {
  const PersonalRemindersScreen({super.key, this.forUserId, this.memberName});

  final String? forUserId;
  final String? memberName;

  @override
  ConsumerState<PersonalRemindersScreen> createState() => _PersonalRemindersScreenState();
}

class _PersonalRemindersScreenState extends ConsumerState<PersonalRemindersScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.forUserId == null) {
      Future.microtask(() => ref.read(personalReminderRepositoryProvider).refreshFromServer());
    }
  }

  Future<void> _open([PersonalReminderModel? r]) async {
    final changed = await context.push<bool>(
      AppRoutes.personalReminderForm,
      extra: PersonalRemindersArgs(forUserId: widget.forUserId, reminder: r),
    );
    if (changed == true && widget.forUserId != null) ref.invalidate(_memberPersonalRemindersProvider(widget.forUserId!));
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final async = widget.forUserId == null
        ? ref.watch(_myPersonalRemindersProvider)
        : ref.watch(_memberPersonalRemindersProvider(widget.forUserId!));
    final title = widget.memberName == null || widget.memberName!.isEmpty
        ? strings.personalRemindersTitle
        : '${strings.personalRemindersTitle} · ${widget.memberName}';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
        icon: const Icon(Icons.add_alarm),
        label: Text(strings.addReminder),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is DioException ? friendlyErrorMessage(e) : strings.somethingWentWrong,
          retryLabel: strings.retry,
          onRetry: () => ref.invalidate(_memberPersonalRemindersProvider(widget.forUserId ?? '')),
        ),
        data: (list) => list.isEmpty
            ? EmptyView(
                message: strings.noPersonalReminders,
                icon: Icons.alarm_add_outlined,
                actionLabel: strings.addReminder,
                onAction: () => _open(),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  for (final r in list)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.alarm),
                        title: Text(r.name, style: Theme.of(context).textTheme.titleMedium),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (r.description?.isNotEmpty ?? false) Text(r.description!),
                            Text(
                              '${r.scheduleTimes.map((t) => formatHhmm(context, t)).join(', ')} • '
                              '${r.intervalDays > 1 ? strings.everyNDays(r.intervalDays) : strings.everyDay}',
                              style: TextStyle(color: context.palette.muted),
                            ),
                            if (r.byCaregiver && widget.forUserId == null) ...[
                              const SizedBox(height: 4),
                              TagChip(label: strings.setUpByCaregiver),
                            ],
                          ],
                        ),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () => _open(r),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Add or change a personal reminder: name, what to remind, times (like a
/// medicine: several a day), every day or every N days, an optional last day.
class PersonalReminderFormScreen extends ConsumerStatefulWidget {
  const PersonalReminderFormScreen({super.key, required this.args});

  final PersonalRemindersArgs args;

  @override
  ConsumerState<PersonalReminderFormScreen> createState() => _PersonalReminderFormScreenState();
}

class _PersonalReminderFormScreenState extends ConsumerState<PersonalReminderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _what = TextEditingController();
  List<String> _times = ['08:00'];
  int _intervalDays = 1;
  DateTime? _endDate;
  bool _saving = false;
  String? _error;

  PersonalReminderModel? get _reminder => widget.args.reminder;

  @override
  void initState() {
    super.initState();
    final r = _reminder;
    if (r != null) {
      _name.text = r.name;
      _what.text = r.description ?? '';
      _times = r.scheduleTimes.isEmpty ? ['08:00'] : List.of(r.scheduleTimes);
      _intervalDays = r.intervalDays;
      _endDate = r.endDate;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _what.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final strings = ref.read(stringsProvider);
    if (!_formKey.currentState!.validate()) return;
    if (_times.toSet().length != _times.length) {
      setState(() => _error = strings.timesMustDiffer);
      return;
    }
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'description': _what.text.trim(),
      'scheduleTimes': _times,
      'intervalDays': _intervalDays,
      'endDate': _endDate == null ? null : formatYmd(_endDate!),
    };
    await _run(() async {
      final api = ref.read(personalReminderApiProvider);
      if (_reminder == null) {
        if (body['endDate'] == null) body.remove('endDate');
        await api.create(body, forUserId: widget.args.forUserId);
      } else {
        await api.update(_reminder!.id, body, forUserId: widget.args.forUserId);
      }
    });
  }

  Future<void> _remove() async {
    final strings = ref.read(stringsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.removeReminder),
        content: Text(strings.removeReminderConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(strings.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(strings.removeReminder)),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => ref.read(personalReminderApiProvider).remove(_reminder!.id, forUserId: widget.args.forUserId));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action();
      // My own: pull again so the phone rings on the new schedule.
      if (widget.args.forUserId == null) await ref.read(personalReminderRepositoryProvider).refreshFromServer();
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
    return Scaffold(
      appBar: AppBar(title: Text(_reminder == null ? strings.addReminder : strings.editReminder)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: strings.reminderNameLabel,
                hintText: strings.reminderNameHint,
                prefixIcon: const Icon(Icons.label_outline),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? strings.requiredField : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _what,
              maxLength: 300,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: strings.reminderWhatLabel,
                hintText: strings.reminderWhatHint,
                prefixIcon: const Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _times.length,
              decoration: InputDecoration(labelText: strings.timesPerDay, prefixIcon: const Icon(Icons.repeat_one)),
              items: [for (var n = 1; n <= 6; n++) DropdownMenuItem(value: n, child: Text('$n'))],
              onChanged: _saving
                  ? null
                  : (n) => setState(() {
                        final count = n ?? 1;
                        _times = List.generate(count, (i) => i < _times.length ? _times[i] : _times.last);
                      }),
            ),
            const SizedBox(height: 16),
            _TimeChips(
              times: _times,
              strings: strings,
              enabled: !_saving,
              onChanged: (i, t) => setState(() => _times[i] = t),
            ),
            const SizedBox(height: 16),
            IntervalField(
              value: _intervalDays,
              strings: strings,
              enabled: !_saving,
              onChanged: (n) => setState(() => _intervalDays = n),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_busy_outlined),
              title: Text(strings.endDateLabel),
              subtitle: Text(_endDate == null ? strings.noEndDate : formatYmd(_endDate!)),
              trailing: _endDate == null
                  ? const Icon(Icons.edit_calendar_outlined)
                  : IconButton(
                      tooltip: strings.noEndDate,
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _endDate = null),
                    ),
              onTap: _saving
                  ? null
                  : () async {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? today,
                        firstDate: today,
                        lastDate: today.add(const Duration(days: 730)),
                      );
                      if (picked != null) setState(() => _endDate = picked);
                    },
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(strings.save),
            ),
            if (_reminder != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : _remove,
                style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                icon: const Icon(Icons.delete_outline),
                label: Text(strings.removeReminder),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimeChips extends StatelessWidget {
  const _TimeChips({required this.times, required this.strings, required this.enabled, required this.onChanged});

  final List<String> times;
  final AppStrings strings;
  final bool enabled;
  final void Function(int index, String time) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.reminderTimesLabel, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < times.length; i++)
              ActionChip(
                avatar: const Icon(Icons.schedule, size: 18),
                label: Text(formatHhmm(context, times[i]), style: const TextStyle(fontSize: 16)),
                onPressed: !enabled
                    ? null
                    : () async {
                        final parts = times[i].split(':');
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
                        );
                        if (picked != null) onChanged(i, toHhmm(picked));
                      },
              ),
          ],
        ),
      ],
    );
  }
}
