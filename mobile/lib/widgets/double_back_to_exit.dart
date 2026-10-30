import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/locale_controller.dart';

/// On Home and Login: the first back shows "Press back again to exit"; a
/// second back within [window] closes the app. After that it starts over.
/// Closing the app never affects reminders (they are OS alarms).
class DoubleBackToExit extends ConsumerStatefulWidget {
  const DoubleBackToExit({
    super.key,
    required this.child,
    this.window = const Duration(seconds: 2),
    this.onExit,
    this.clock,
  });

  final Widget child;
  final Duration window;

  /// Closes the app (default SystemNavigator.pop); replaceable in tests.
  final VoidCallback? onExit;
  final DateTime Function()? clock;

  @override
  ConsumerState<DoubleBackToExit> createState() => _DoubleBackToExitState();
}

class _DoubleBackToExitState extends ConsumerState<DoubleBackToExit> {
  DateTime? _lastBack;

  void _onBack() {
    final now = (widget.clock ?? DateTime.now)();
    final last = _lastBack;
    if (last != null && now.difference(last) <= widget.window) {
      _lastBack = null;
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
      (widget.onExit ?? SystemNavigator.pop)();
      return;
    }
    _lastBack = now;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(ref.read(stringsProvider).pressBackAgainToExit),
        duration: widget.window,
      ));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: widget.child,
    );
  }
}
