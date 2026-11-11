import 'package:flutter/widgets.dart';

/// A button label that stays on one line: shrinks a little when the button
/// is too narrow (buttons side by side, segment buttons, long Bengali text)
/// instead of breaking the word inside the pill. Text that fits is unchanged.
class FitLabel extends StatelessWidget {
  const FitLabel(this.child, {super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => FittedBox(fit: BoxFit.scaleDown, child: child);
}
