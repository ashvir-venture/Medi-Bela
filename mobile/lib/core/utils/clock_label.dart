import 'package:flutter/material.dart';

import '../localization/app_strings.dart';

/// Round 18 (client note point 12): a clock time in the app language, the
/// way people say it: "8:30 PM" / "রাত ৮:৩০". Flutter's own Bengali format
/// had no AM / PM. Every time shown on screen goes through this.
extension ClockLabel on TimeOfDay {
  String label(BuildContext context) {
    final bn = Localizations.maybeLocaleOf(context)?.languageCode == 'bn';
    return Round18Strings(bn).time(hour, minute);
  }
}
