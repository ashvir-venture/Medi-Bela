import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/core_providers.dart';
import '../domain/reminder_status.dart';

/// Current reminder settings. Every one of them is changed outside the app,
/// so widgets showing it wrap themselves in [ReminderStatusRefresher] to
/// re-check when the user comes back from system settings.
final reminderStatusProvider = FutureProvider.autoDispose<ReminderStatus>((ref) {
  return ref.watch(reminderStatusServiceProvider).check();
});

/// Re-checks [reminderStatusProvider] each time the app returns to the
/// foreground.
class ReminderStatusRefresher extends ConsumerStatefulWidget {
  const ReminderStatusRefresher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ReminderStatusRefresher> createState() => _ReminderStatusRefresherState();
}

class _ReminderStatusRefresherState extends ConsumerState<ReminderStatusRefresher>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(reminderStatusProvider);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
