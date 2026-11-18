import 'package:flutter/material.dart';

/// A field with its label above it (Round 18): long labels wrap onto a second
/// line instead of being cut inside the border ("Days it lasts after
/// opening (l…" in the new-pen dialog, owner's screenshot 2026-11-17).
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child, this.hint});

  final String label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(hint!, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
