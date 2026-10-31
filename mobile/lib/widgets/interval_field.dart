import 'package:flutter/material.dart';

import '../core/localization/app_strings.dart';

/// "Repeat": every day, or every N days (2-30 here; the server takes up to
/// 90, and a pharmacist's larger value stays selectable).
class IntervalField extends StatelessWidget {
  const IntervalField({
    super.key,
    required this.value,
    required this.strings,
    required this.onChanged,
    this.enabled = true,
  });

  final int value;
  final AppStrings strings;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final options = {1, for (var n = 2; n <= 30; n++) n, value}.toList()..sort();
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: strings.repeatLabel, prefixIcon: const Icon(Icons.repeat)),
      items: [
        for (final n in options)
          DropdownMenuItem<int>(value: n, child: Text(n == 1 ? strings.everyDay : strings.everyNDays(n))),
      ],
      onChanged: enabled ? (v) => onChanged(v ?? 1) : null,
    );
  }
}
