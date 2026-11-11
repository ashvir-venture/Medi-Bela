import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Keeps every screen, sheet and snackbar above the phone's own navigation
/// bar (Android draws apps edge to edge): the strip under it gets the bottom
/// bar's colour, and nothing scrolls or sits behind the system buttons
/// (owner 2026-11-12). Used once, in MaterialApp.builder.
class BottomSafeArea extends StatelessWidget {
  const BottomSafeArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.palette.navBackground,
      child: SafeArea(top: false, left: false, right: false, child: child),
    );
  }
}
