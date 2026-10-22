import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/core_providers.dart';
import '../domain/prescription_draft_model.dart';

/// A `StreamProvider` is enough here — Drift's `.watch()` already gives us
/// live updates as the sync engine flips a draft from `queued` to
/// `synced`/`failed`, so there's no extra controller state to manage.
final prescriptionDraftsProvider =
    StreamProvider<List<PrescriptionDraftModel>>((ref) {
  return ref.watch(prescriptionLocalRepositoryProvider).watchDrafts();
});

final createPrescriptionDraftProvider =
    Provider<Future<String> Function({String? note, String? imageLocalPath})>(
  (ref) {
    final repo = ref.watch(prescriptionLocalRepositoryProvider);
    return ({String? note, String? imageLocalPath}) =>
        repo.createAndQueue(note: note, imageLocalPath: imageLocalPath);
  },
);
