import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/state_views.dart';
import '../domain/family_models.dart';

/// Round 17 D: the change history, 10 per page with "Load more" (online).
class ChangeHistoryState {
  const ChangeHistoryState({this.items = const [], this.nextCursor, this.isLoading = false, this.error});

  final List<CaregiverChange> items;
  final String? nextCursor;
  final bool isLoading;
  final String? error;
}

class ChangeHistoryController extends StateNotifier<ChangeHistoryState> {
  ChangeHistoryController(this._load, {bool autoload = true}) : super(const ChangeHistoryState()) {
    if (autoload) reload();
  }

  final Future<CaregiverChangesPage> Function(String? cursor) _load;

  Future<void> reload() => _fetch(reset: true);

  Future<void> loadMore() async {
    if (state.nextCursor == null || state.isLoading) return;
    await _fetch(reset: false);
  }

  Future<void> _fetch({required bool reset}) async {
    final kept = reset ? const <CaregiverChange>[] : state.items;
    final cursor = reset ? null : state.nextCursor;
    state = ChangeHistoryState(items: kept, nextCursor: cursor, isLoading: true);
    try {
      final page = await _load(cursor);
      if (!mounted) return;
      state = ChangeHistoryState(items: [...kept, ...page.items], nextCursor: page.nextCursor);
    } on DioException catch (e) {
      if (!mounted) return;
      state = ChangeHistoryState(items: kept, nextCursor: cursor, error: friendlyErrorMessage(e));
    }
  }
}

/// Key: the member's id for the caregiver's view, null for my own.
final changeHistoryProvider =
    StateNotifierProvider.autoDispose.family<ChangeHistoryController, ChangeHistoryState, String?>((ref, memberId) {
  final api = ref.watch(familyApiProvider);
  return ChangeHistoryController((cursor) => api.listChanges(memberUserId: memberId, cursor: cursor));
});

/// [memberId] null: "Changes made for you" (the member's side); else the
/// caregiver's view of that member ([memberName] in the title).
class ChangeHistoryScreen extends ConsumerWidget {
  const ChangeHistoryScreen({super.key, this.memberId, this.memberName});

  final String? memberId;
  final String? memberName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final s = strings.r17;
    final state = ref.watch(changeHistoryProvider(memberId));
    final controller = ref.read(changeHistoryProvider(memberId).notifier);
    final mine = memberId == null;
    final title = mine
        ? s.changesForMe
        : (memberName == null || memberName!.isEmpty ? s.changeHistory : '${s.changeHistory} · $memberName');

    Widget body;
    if (state.items.isEmpty && state.isLoading) {
      body = const LoadingView();
    } else if (state.items.isEmpty && state.error != null) {
      body = ListView(children: [
        const SizedBox(height: 80),
        ErrorView(message: state.error!, retryLabel: strings.retry, onRetry: controller.reload),
      ]);
    } else {
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(mine ? s.changesForMeSub : s.changeHistorySub, style: TextStyle(color: context.palette.muted)),
          const SizedBox(height: 12),
          if (state.items.isEmpty)
            EmptyView(message: s.noChanges, icon: Icons.history)
          else
            for (final c in state.items) _ChangeTile(change: c, strings: strings),
          if (state.nextCursor != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton(
                onPressed: state.isLoading ? null : controller.loadMore,
                child: Text(strings.loadMore),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(onRefresh: controller.reload, child: body),
    );
  }
}

class _ChangeTile extends StatelessWidget {
  const _ChangeTile({required this.change, required this.strings});

  final CaregiverChange change;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final s = strings.r17;
    final who = change.actor == null || change.actor!.deleted ? strings.deletedUser : change.actor!.name;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(changeIcon(change.action), color: Theme.of(context).colorScheme.primary),
        title: Text(s.changeLabel(change.action)),
        subtitle: Text('${s.byWhom(who)} · ${s.n(formatChangeWhen(change.createdAt))}',
            style: TextStyle(color: context.palette.muted)),
      ),
    );
  }
}

IconData changeIcon(String action) {
  if (action.startsWith('prescription.') || action.startsWith('record.prescription')) return Icons.description_outlined;
  if (action.startsWith('routine.')) return Icons.medication_outlined;
  if (action == 'dose.give') return Icons.check_circle_outline;
  if (action == 'user.easy_mode') return Icons.accessibility_new;
  if (action.startsWith('personal_reminder.')) return Icons.alarm_outlined;
  if (action == 'medicine_box.save') return Icons.inventory_2_outlined;
  if (action.startsWith('record.appointment')) return Icons.event_outlined;
  if (action.startsWith('record.test') || action == 'record.photo_add') return Icons.biotech_outlined;
  return Icons.favorite_border;
}

String formatChangeWhen(DateTime at) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(at.day)}/${two(at.month)}/${at.year} ${two(at.hour)}:${two(at.minute)}';
}
