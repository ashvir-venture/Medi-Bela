import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/core_providers.dart';
import '../../../sync/outbox_constants.dart';

/// Number of local changes (doses taken, reminders completed, prescriptions,
/// health records) not yet confirmed by the server. Live, from the local
/// outbox, so it works offline and drops to 0 as the sync engine drains.
final pendingSyncCountProvider = StreamProvider.autoDispose<int>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.outboxEntries)
    ..where((t) => t.status.equals(OutboxStatus.synced).not());
  return query.watch().map((rows) => rows.length);
});
