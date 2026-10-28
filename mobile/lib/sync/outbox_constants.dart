/// String constants for the `status` column shared by [OutboxEntries] and
/// [PrescriptionDrafts]. Kept as plain strings (not a Drift enum column)
/// to keep schema migrations simple in this MVP.
class OutboxStatus {
  OutboxStatus._();

  static const String pending = 'pending';
  static const String syncing = 'syncing';
  static const String failed = 'failed';
  static const String synced = 'synced';
}

class OutboxOperation {
  OutboxOperation._();

  static const String create = 'create';
  static const String update = 'update';
  static const String delete = 'delete';
}

/// Identifies which [SyncHandler] should process an outbox row.
class OutboxEntityType {
  OutboxEntityType._();

  static const String prescriptionDraft = 'prescriptionDraft';
  static const String doseTaken = 'doseTaken';
  static const String healthReminderComplete = 'healthReminderComplete';
  static const String healthRecordDraft = 'healthRecordDraft';
}
