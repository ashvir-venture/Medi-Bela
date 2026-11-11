import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The pages visited inside the bottom-bar shell, oldest first, so the
/// phone's back button returns to the page you came from, also after a tab
/// switch or a `go` (inbox entry, notification). Home is the bottom of the
/// stack: going Home clears the rest, and back on Home is "press again to
/// exit" (owner 2026-11-12).
class NavHistory {
  NavHistory({this.home = '/home', this.max = 40});

  final String home;
  final int max;
  final List<String> _stack = [];

  List<String> get entries => List.unmodifiable(_stack);

  /// Records that [location] is now on screen. Calling it again for the same
  /// location (a rebuild) changes nothing; arriving at the page right below
  /// the top is a step back.
  void visit(String location) {
    if (_pathOf(location) == home) {
      _stack
        ..clear()
        ..add(location);
      return;
    }
    if (_stack.isNotEmpty && _stack.last == location) return;
    if (_stack.length >= 2 && _stack[_stack.length - 2] == location) {
      _stack.removeLast();
      return;
    }
    _stack.add(location);
    if (_stack.length > max) _stack.removeAt(0);
  }

  /// Where back leads from the top page: the page before it, else Home.
  String previous() => _stack.length >= 2 ? _stack[_stack.length - 2] : home;

  static String _pathOf(String location) => Uri.parse(location).path;
}

final navHistoryProvider = Provider<NavHistory>((ref) => NavHistory());
