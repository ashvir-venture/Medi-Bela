import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_config.dart';
import '../core/localization/app_strings.dart';
import '../core/localization/locale_controller.dart';
import '../core/theme/app_theme.dart';

/// Round 17 E: first-use tips. Each screen's tips show once on this phone
/// (Next / Skip; Skip or the last "Got it" marks them seen); Settings →
/// Help & about → "Show tips again" clears them. No package: a card over a
/// dimmed screen on the tab roots, an inline card on the reminder page and
/// the + sheet (never over a ringing reminder's buttons).
enum TipsScreen { home, medicines, family, health, reminder, quickAdd }

List<(String, String)> tipsFor(TipsScreen screen, Round17Strings s) => switch (screen) {
      TipsScreen.home => s.tipsHome,
      TipsScreen.medicines => s.tipsMedicines,
      TipsScreen.family => s.tipsFamily,
      TipsScreen.health => s.tipsHealth,
      TipsScreen.reminder => s.tipsReminder,
      TipsScreen.quickAdd => s.tipsQuickAdd,
    };

/// Which screens' tips were already seen. Loads from SharedPreferences; until
/// loaded (or if storage fails) everything counts as seen, so a tip never
/// flashes up by mistake.
class TipsController extends StateNotifier<Set<TipsScreen>?> {
  TipsController() : super(null) {
    _load();
  }

  static String keyFor(TipsScreen s) => '${PrefsKeys.tipsSeenPrefix}${s.name}';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = {for (final s in TipsScreen.values) if (prefs.getBool(keyFor(s)) ?? false) s};
      if (mounted) state = seen;
    } catch (_) {
      if (mounted) state = TipsScreen.values.toSet();
    }
  }

  bool shouldShow(TipsScreen s) => state != null && !state!.contains(s);

  Future<void> markSeen(TipsScreen s) async {
    state = {...?state, s};
    try {
      await (await SharedPreferences.getInstance()).setBool(keyFor(s), true);
    } catch (_) {}
  }

  Future<void> showAgain() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final s in TipsScreen.values) {
        await prefs.remove(keyFor(s));
      }
    } catch (_) {}
    state = <TipsScreen>{};
  }
}

final tipsControllerProvider = StateNotifierProvider<TipsController, Set<TipsScreen>?>((ref) => TipsController());

/// Wraps a tab root: dims it and shows the tip card at the bottom while
/// the screen's tips are unseen.
class FirstUseTips extends ConsumerWidget {
  const FirstUseTips({super.key, required this.screen, required this.child, this.enabled = true});

  final TipsScreen screen;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seen = ref.watch(tipsControllerProvider);
    final show = enabled && seen != null && !seen.contains(screen);
    if (!show) return child;
    final tips = tipsFor(screen, ref.watch(stringsProvider).r17);
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: ModalBarrier(color: Colors.black.withValues(alpha: 0.45), dismissible: false),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: SafeArea(
            top: false,
            child: TipCard(
              tips: tips,
              onFinished: () => ref.read(tipsControllerProvider.notifier).markSeen(screen),
            ),
          ),
        ),
      ],
    );
  }
}

/// The inline version (reminder page, + sheet): the card in the page's own
/// layout, nothing covered.
class InlineFirstUseTips extends ConsumerWidget {
  const InlineFirstUseTips({super.key, required this.screen});

  final TipsScreen screen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seen = ref.watch(tipsControllerProvider);
    if (seen == null || seen.contains(screen)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TipCard(
        tips: tipsFor(screen, ref.watch(stringsProvider).r17),
        onFinished: () => ref.read(tipsControllerProvider.notifier).markSeen(screen),
      ),
    );
  }
}

/// One tip at a time: title, text, "1 of 3", Skip and Next / Got it.
class TipCard extends ConsumerStatefulWidget {
  const TipCard({super.key, required this.tips, required this.onFinished});

  final List<(String, String)> tips;
  final VoidCallback onFinished;

  @override
  ConsumerState<TipCard> createState() => _TipCardState();
}

class _TipCardState extends ConsumerState<TipCard> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider).r17;
    final p = context.palette;
    final last = _index >= widget.tips.length - 1;
    final (title, text) = widget.tips[_index.clamp(0, widget.tips.length - 1)];
    return Material(
      key: const ValueKey('first-use-tip'),
      color: p.surface,
      elevation: 6,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                if (widget.tips.length > 1)
                  Text(s.tipStep(_index + 1, widget.tips.length), style: TextStyle(color: p.muted)),
              ],
            ),
            const SizedBox(height: 8),
            Text(text, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                if (!last) TextButton(onPressed: widget.onFinished, child: Text(s.tipSkip)),
                const Spacer(),
                FilledButton(
                  onPressed: last ? widget.onFinished : () => setState(() => _index++),
                  child: Text(last ? s.tipDone : s.tipNext),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
