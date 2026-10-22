class PrescriptionDraftModel {
  const PrescriptionDraftModel({
    required this.id,
    this.imageLocalPath,
    this.note,
    required this.status,
    this.serverId,
    this.serverStatus,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? imageLocalPath;
  final String? note;
  final String status; // draft | queued | syncing | synced | failed
  final String? serverId;
  /// PENDING | COMPLETED | REJECTED once known — see
  /// [PrescriptionLocalRepository.refreshStatuses].
  final String? serverStatus;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPendingSync => status == 'queued' || status == 'syncing';
  bool get isAwaitingReview => status == 'synced' && serverStatus == 'PENDING';
}
