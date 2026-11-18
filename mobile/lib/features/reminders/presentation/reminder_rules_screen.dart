import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../notifications/reminder_timing.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/state_views.dart';

/// Round 14 (owner, 2026-11-10): the user's own ring gap, Later delay, number
/// of rings and family-alert time. Empty = the server's default (.env). The
/// family must be told after the last ring has finished.
class ReminderRules {
  const ReminderRules({this.repeatMinutes, this.laterMinutes, this.rings, this.familyAlertMinutes});

  final int? repeatMinutes, laterMinutes, rings, familyAlertMinutes;

  factory ReminderRules.fromJson(Map<String, dynamic>? json) => ReminderRules(
        repeatMinutes: json?['repeatMinutes'] as int?,
        laterMinutes: json?['laterMinutes'] as int?,
        rings: json?['rings'] as int?,
        familyAlertMinutes: json?['familyAlertMinutes'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'repeatMinutes': repeatMinutes,
        'laterMinutes': laterMinutes,
        'rings': rings,
        'familyAlertMinutes': familyAlertMinutes,
      };

  ReminderRules copyWith({
    int? Function()? repeatMinutes,
    int? Function()? laterMinutes,
    int? Function()? rings,
    int? Function()? familyAlertMinutes,
  }) =>
      ReminderRules(
        repeatMinutes: repeatMinutes == null ? this.repeatMinutes : repeatMinutes(),
        laterMinutes: laterMinutes == null ? this.laterMinutes : laterMinutes(),
        rings: rings == null ? this.rings : rings(),
        familyAlertMinutes: familyAlertMinutes == null ? this.familyAlertMinutes : familyAlertMinutes(),
      );
}

/// The server's defaults and the user's own values, from GET /users/me/reminder-timing.
class ReminderRulesState {
  const ReminderRulesState({required this.defaults, required this.own});

  final ReminderTiming defaults;
  final ReminderRules own;
}

/// Options the pickers step through (the server allows 5-60, 1-6 and 5-360).
const ringGapOptions = [5, 10, 15, 20, 30, 45, 60];
const laterOptions = [5, 10, 15, 20, 30, 45, 60];
const ringsOptions = [1, 2, 3, 4, 5, 6];
const familyAlertOptions = [10, 15, 20, 30, 40, 50, 60, 75, 90, 120, 180, 240, 360];

/// When the last ring has finished, in minutes after the dose time.
int lastRingEnds({required int rings, required int repeatMinutes, required int ringMinutes}) =>
    (rings - 1) * repeatMinutes + ringMinutes;

final reminderRulesProvider = FutureProvider.autoDispose<ReminderRulesState>((ref) async {
  final res = await ref.watch(dioClientProvider).dio.get<Map<String, dynamic>>(ApiEndpoints.reminderTiming);
  return _rulesState(res.data);
});

/// Round 18 (client point 14): a member's timings, read by their caregiver
/// (the member's View permission; saving needs Manage).
final memberReminderRulesProvider = FutureProvider.autoDispose.family<ReminderRulesState, String>((ref, forUserId) async {
  final res = await ref
      .watch(dioClientProvider)
      .dio
      .get<Map<String, dynamic>>(ApiEndpoints.reminderTiming, queryParameters: {'forUserId': forUserId});
  return _rulesState(res.data);
});

ReminderRulesState _rulesState(Map<String, dynamic>? data) => ReminderRulesState(
      defaults: ReminderTiming.fromJson((data?['defaults'] as Map<String, dynamic>?) ?? const {}),
      own: ReminderRules.fromJson(data?['own'] as Map<String, dynamic>?),
    );

class ReminderRulesScreen extends ConsumerStatefulWidget {
  const ReminderRulesScreen({super.key, this.forUserId, this.memberName});

  /// Round 18: the caregiver setting a member's timings (incl. when the
  /// caregiver is told); null = my own.
  final String? forUserId;
  final String? memberName;

  @override
  ConsumerState<ReminderRulesScreen> createState() => _ReminderRulesScreenState();
}

class _ReminderRulesScreenState extends ConsumerState<ReminderRulesScreen> {
  ReminderRules? _draft;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final s = strings.r14;
    final forUserId = widget.forUserId;
    final async = forUserId == null ? ref.watch(reminderRulesProvider) : ref.watch(memberReminderRulesProvider(forUserId));
    return Scaffold(
      appBar: AppBar(title: Text(forUserId == null ? s.routineTitle : strings.r18.memberTimings(widget.memberName ?? ''))),
      body: OnlineOnly(
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: friendlyErrorMessage(e),
            retryLabel: strings.retry,
            onRetry: () => _invalidate(),
          ),
          data: (state) => _form(context, strings, state),
        ),
      ),
    );
  }

  Widget _form(BuildContext context, AppStrings strings, ReminderRulesState state) {
    final s = strings.r14;
    final p = context.palette;
    final draft = _draft ?? state.own;
    final d = state.defaults;
    final gap = draft.repeatMinutes ?? d.repeatMinutes;
    final rings = draft.rings ?? d.rings;
    final alert = draft.familyAlertMinutes ?? d.missedGraceMinutes;
    final lastEnds = lastRingEnds(rings: rings, repeatMinutes: gap, ringMinutes: d.ringMinutes);
    final valid = alert > lastEnds;

    void set(ReminderRules next) => setState(() => _draft = next);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(s.routineIntro, style: TextStyle(color: p.muted, fontSize: AppType.body)),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                _StepperRow(
                  title: s.ringGap,
                  help: s.ringGapHelp,
                  label: s.minutes(gap),
                  isDefault: draft.repeatMinutes == null,
                  defaultTag: s.defaultTag,
                  options: ringGapOptions,
                  value: gap,
                  onChanged: (v) => set(draft.copyWith(repeatMinutes: () => v)),
                ),
                _StepperRow(
                  title: s.laterDelay,
                  help: s.laterDelayHelp,
                  label: s.minutes(draft.laterMinutes ?? (draft.repeatMinutes ?? d.laterMinutes)),
                  isDefault: draft.laterMinutes == null,
                  defaultTag: s.defaultTag,
                  options: laterOptions,
                  value: draft.laterMinutes ?? (draft.repeatMinutes ?? d.laterMinutes),
                  onChanged: (v) => set(draft.copyWith(laterMinutes: () => v)),
                ),
                _StepperRow(
                  title: s.ringsCount,
                  help: s.ringsHelp,
                  label: s.times(rings),
                  isDefault: draft.rings == null,
                  defaultTag: s.defaultTag,
                  options: ringsOptions,
                  value: rings,
                  onChanged: (v) => set(draft.copyWith(rings: () => v)),
                ),
                _StepperRow(
                  title: s.familyAlertAfter,
                  help: s.familyAlertHelp,
                  label: s.minutes(alert),
                  isDefault: draft.familyAlertMinutes == null,
                  defaultTag: s.defaultTag,
                  options: familyAlertOptions,
                  value: alert,
                  onChanged: (v) => set(draft.copyWith(familyAlertMinutes: () => v)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(s.lastRing(lastEnds), style: TextStyle(color: p.muted, fontSize: AppType.small)),
        if (!valid) ...[
          const SizedBox(height: 8),
          Container(
            key: const ValueKey('rules-too-early'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.errorContainer, borderRadius: BorderRadius.circular(12)),
            child: Text(s.familyAlertTooEarly, style: TextStyle(color: p.onErrorContainer, fontWeight: FontWeight.w600)),
          ),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: !valid || _saving ? null : () => _save(draft),
          child: _saving
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
              : Text(strings.save),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _saving ? null : () => _save(const ReminderRules()),
          child: Text(s.useDefaults),
        ),
      ],
    );
  }

  void _invalidate() {
    final forUserId = widget.forUserId;
    if (forUserId == null) {
      ref.invalidate(reminderRulesProvider);
    } else {
      ref.invalidate(memberReminderRulesProvider(forUserId));
    }
  }

  Future<void> _save(ReminderRules rules) async {
    final s = ref.read(stringsProvider).r14;
    setState(() => _saving = true);
    try {
      final res = await ref
          .read(dioClientProvider)
          .dio
          .put<Map<String, dynamic>>(
            ApiEndpoints.reminderTiming,
            data: rules.toJson(),
            queryParameters: {'forUserId': ?widget.forUserId},
          );
      final effective = res.data?['effective'];
      // A member's timings apply on the member's phone, never on this one.
      if (widget.forUserId == null && effective is Map<String, dynamic> && await ReminderTiming.apply(effective)) {
        ref.read(notificationSchedulerProvider).timingChanged();
      }
      _draft = null;
      _invalidate();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.saved)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.title,
    required this.help,
    required this.label,
    required this.isDefault,
    required this.defaultTag,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String title, help, label, defaultTag;
  final bool isDefault;
  final List<int> options;
  final int value;
  final ValueChanged<int> onChanged;

  int? _step(int dir) {
    if (dir > 0) {
      for (final o in options) {
        if (o > value) return o;
      }
    } else {
      for (final o in options.reversed) {
        if (o < value) return o;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final down = _step(-1), up = _step(1);
    Widget btn(IconData icon, int? to) => SizedBox(
          width: 44,
          height: 44,
          child: IconButton.outlined(
            padding: EdgeInsets.zero,
            onPressed: to == null ? null : () => onChanged(to),
            icon: Icon(icon),
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line3))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w700)),
                Text(help, style: TextStyle(color: p.muted, fontSize: AppType.small)),
                if (isDefault)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(defaultTag, style: TextStyle(color: p.link, fontSize: AppType.tiny, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
          btn(Icons.remove, down),
          SizedBox(
            width: 76,
            child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w800)),
          ),
          btn(Icons.add, up),
        ],
      ),
    );
  }
}
