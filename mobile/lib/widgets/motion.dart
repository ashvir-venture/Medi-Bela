import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/auth_controller.dart';

/// Look pass (2026-11-18): small, quick motion only (150-250 ms), never
/// decorative. Off when Android's "Remove animations" is on and in easy mode.
class Motion {
  static const quick = Duration(milliseconds: 180);
  static const normal = Duration(milliseconds: 240);
}

/// True when animation should be skipped: the phone asks for no animations
/// (MediaQuery.disableAnimations) or easy mode is on.
bool motionOff(BuildContext context, WidgetRef ref) {
  final easy = ref.watch(authControllerProvider.select((u) => u.value?.easyMode ?? false));
  return easy || MediaQuery.maybeDisableAnimationsOf(context) == true;
}

/// [d], or zero when motion is off.
Duration motionDuration(BuildContext context, WidgetRef ref, [Duration d = Motion.normal]) =>
    motionOff(context, ref) ? Duration.zero : d;

/// A gentle pulse around the dose that is due now: the border breathes
/// between [color] at 35% and 100% a few times, then stays. A steady border
/// when motion is off.
class DuePulse extends ConsumerStatefulWidget {
  const DuePulse({super.key, required this.active, required this.color, required this.child, this.radius = 16});

  final bool active;
  final Color color;
  final double radius;
  final Widget child;

  @override
  ConsumerState<DuePulse> createState() => _DuePulseState();
}

class _DuePulseState extends ConsumerState<DuePulse> with SingleTickerProviderStateMixin {
  /// Four breaths (about 6 s), then a steady border: noticeable without
  /// keeping the screen busy on a cheap phone.
  static const _breaths = 4;
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
    ..addStatusListener(_onStatus);
  int _halfCycles = 0;
  bool _started = false;

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
      _halfCycles++;
      if (_halfCycles >= _breaths * 2) {
        _c.value = 1;
        return;
      }
      status == AnimationStatus.completed ? _c.reverse() : _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = motionOff(context, ref);
    if (!widget.active) return widget.child;
    Widget frame(double t, Widget? child) => DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: widget.color.withValues(alpha: 0.35 + 0.65 * t), width: 2),
          ),
          child: child,
        );
    // Never touch the controller during build when motion is off: a steady border.
    if (still) return frame(1, widget.child);
    if (!_started) {
      _started = true;
      _c.forward(from: 0);
    }
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => frame(Curves.easeInOut.transform(_c.value), child),
    );
  }
}

/// A check mark that pops in (scale 0.6 → 1 with a small overshoot) the
/// first time it is built: the rewarding moment after Taken.
class CheckPop extends ConsumerWidget {
  const CheckPop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (motionOff(context, ref)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: Motion.normal,
      curve: Curves.easeOutBack,
      builder: (context, v, c) => Transform.scale(scale: v, child: c),
      child: child,
    );
  }
}
