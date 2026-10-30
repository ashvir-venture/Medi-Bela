import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';

/// The three small cards from the web sign-in page (a checked prescription
/// line, a taken reminder, a missed dose the family heard about), as a
/// gently overlapping stack in its own area above the login form, with the
/// tagline under it. Decoration only: hidden from screen readers. The login
/// screen leaves it out while the keyboard is open and on short screens.
class SigninVisual extends ConsumerWidget {
  const SigninVisual({super.key});

  /// Below this height the visual would push the form off screen.
  static const minScreenHeight = 640.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final palette = context.palette;
    return ExcludeSemantics(
      child: Column(
        children: [
          SizedBox(
            height: 176,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  child: _StoryCard(
                    angle: -0.05,
                    title: strings.signinCardPrescription,
                    meta: _Dot(color: palette.success, label: strings.signinCardChecked),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 58,
                  child: _StoryCard(
                    angle: 0.035,
                    title: strings.signinCardReminder,
                    meta: _Chip(label: strings.signinCardTaken, color: palette.success),
                  ),
                ),
                Positioned(
                  left: 24,
                  top: 116,
                  child: _StoryCard(
                    angle: -0.025,
                    title: strings.signinCardMissed,
                    meta: _Dot(color: palette.warning, label: strings.signinCardFamily),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            strings.signinTagline,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.angle, required this.title, required this.meta});

  final double angle;
  final String title;
  final Widget meta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 240,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(color: theme.colorScheme.shadow.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            meta,
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: TextStyle(fontSize: 13, color: context.palette.muted))),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
