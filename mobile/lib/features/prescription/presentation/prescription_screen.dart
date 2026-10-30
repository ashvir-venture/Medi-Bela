import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/core_providers.dart';
import '../../../router/app_router.dart';
import '../../../widgets/load_more_list.dart';
import '../../../widgets/state_views.dart';
import '../domain/prescription_draft_model.dart';
import '../domain/prescription_photo.dart';
import 'member_prescriptions_screen.dart' show ServerPrescriptionTile;
import 'prescription_controller.dart';

class PrescriptionScreen extends ConsumerStatefulWidget {
  const PrescriptionScreen({super.key});

  @override
  ConsumerState<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends ConsumerState<PrescriptionScreen> {
  @override
  void initState() {
    super.initState();
    // Pull pharmacist decisions for already-synced drafts on open; purely
    // additive to the locally-cached list already rendered below.
    Future.microtask(
      () => ref.read(prescriptionLocalRepositoryProvider).refreshStatuses(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final draftsAsync = ref.watch(prescriptionDraftsProvider);

    // Shown under the Medicines tab, whose app bar carries the title.
    return Scaffold(
      body: draftsAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error.toString(),
          retryLabel: strings.retry,
          onRetry: () => ref.invalidate(prescriptionDraftsProvider),
        ),
        data: (drafts) {
          // Prescriptions my caregiver uploaded for me aren't local drafts:
          // they come from the server (online only) and are listed after mine.
          final mineOnPhone = drafts.map((d) => d.serverId).whereType<String>().toSet();
          final fromCaregiver = (ref.watch(serverPrescriptionsProvider(null)).valueOrNull ?? const [])
              .where((p) => p.uploadedByCaregiver && !mineOnPhone.contains(p.id))
              .toList();
          if (drafts.isEmpty && fromCaregiver.isEmpty) {
            return EmptyView(
              message: strings.noPrescriptionsYet,
              icon: Icons.description_outlined,
              actionLabel: strings.uploadPrescription,
              onAction: () => openPrescriptionEntryForm(context),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(serverPrescriptionsProvider(null));
              await ref.read(prescriptionLocalRepositoryProvider).refreshStatuses();
            },
            child: LoadMoreListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: drafts.length + fromCaregiver.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) => index < drafts.length
                  ? _DraftTile(draft: drafts[index])
                  : ServerPrescriptionTile(prescription: fromCaregiver[index - drafts.length]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEntryForm(context),
        icon: const Icon(Icons.add),
        label: Text(strings.newPrescriptionEntry),
      ),
    );
  }

  void _openEntryForm(BuildContext context) => openPrescriptionEntryForm(context);
}

/// [rejectedServerId] set = re-upload of that rejected prescription.
void openPrescriptionEntryForm(BuildContext context, {String? rejectedServerId}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PrescriptionEntryForm(rejectedServerId: rejectedServerId),
  );
}

class _DraftTile extends ConsumerWidget {
  const _DraftTile({required this.draft});

  final PrescriptionDraftModel draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final (icon, color, label) = _statusDisplay(context, strings);

    return Card(
      child: ListTile(
        leading: Icon(
          draft.imageLocalPath != null
              ? Icons.image_outlined
              : Icons.note_alt_outlined,
        ),
        title: Text(
          draft.note?.isNotEmpty == true ? draft.note! : strings.newPrescriptionEntry,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(color: color, fontSize: 12)),
              ],
            ),
            if (draft.serverStatus == 'REJECTED' && draft.rejectionReason != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${strings.rejectionReason}: ${draft.rejectionReason}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                ),
              ),
            if (draft.serverStatus == 'AWAITING_CONFIRMATION' && draft.serverId != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FilledButton.icon(
                  onPressed: () async {
                    final done = await context.push<bool>(AppRoutes.confirmPrescriptionPath(draft.serverId!));
                    if (done == true) {
                      await ref.read(prescriptionLocalRepositoryProvider).refreshStatuses();
                    }
                  },
                  icon: const Icon(Icons.fact_check_outlined),
                  label: Text(strings.reviewAndConfirm),
                ),
              ),
            if (draft.serverStatus == 'REJECTED' && draft.serverId != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      openPrescriptionEntryForm(context, rejectedServerId: draft.serverId),
                  icon: const Icon(Icons.upload_outlined, size: 18),
                  label: Text(strings.reuploadPrescription),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Combines upload-sync state ([draft.status]) with pharmacist-review
  /// state ([draft.serverStatus]) into a single badge. Sync state takes
  /// priority while the upload itself hasn't completed yet; once synced,
  /// the server's review status (still PENDING vs ACTIVE/REJECTED/...) is
  /// what the user actually cares about.
  (IconData, Color, String) _statusDisplay(BuildContext context, AppStrings strings) {
    if (draft.status == 'failed') {
      return (Icons.error_outline, Theme.of(context).colorScheme.error, 'Failed to upload');
    }
    if (draft.status != 'synced') {
      return (Icons.schedule, Colors.orange, strings.pendingSyncBadge);
    }
    return switch (draft.serverStatus) {
      'ACTIVE' => (Icons.check_circle, Colors.green, strings.statusActive),
      'ENDED' => (Icons.check_circle_outline, Colors.grey, strings.statusEnded),
      'AWAITING_CONFIRMATION' => (Icons.fact_check_outlined, Colors.blue, strings.statusAwaitingConfirmation),
      'REJECTED' => (Icons.cancel_outlined, Theme.of(context).colorScheme.error, strings.statusRejected),
      _ => (Icons.hourglass_top, Colors.orange, strings.statusPending),
    };
  }
}

class _PrescriptionEntryForm extends ConsumerStatefulWidget {
  const _PrescriptionEntryForm({this.rejectedServerId});

  /// Server id of the rejected prescription this re-uploads, if any.
  final String? rejectedServerId;

  @override
  ConsumerState<_PrescriptionEntryForm> createState() =>
      _PrescriptionEntryFormState();
}

class _PrescriptionEntryFormState extends ConsumerState<_PrescriptionEntryForm> {
  final _noteController = TextEditingController();
  String? _imagePath;
  bool _isSaving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: prescriptionPhotoMaxSide,
      maxHeight: prescriptionPhotoMaxSide,
      imageQuality: prescriptionPhotoQuality,
    );
    if (file != null) {
      setState(() => _imagePath = file.path);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final create = ref.read(createPrescriptionDraftProvider);
    await create(
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      imageLocalPath: _imagePath,
      previousPrescriptionId: widget.rejectedServerId,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    final strings = ref.read(stringsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.draftSavedOffline)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final isReupload = widget.rejectedServerId != null;
    // The server needs a photo; a re-upload is only useful with a new one.
    final canSave = !_isSaving && (!isReupload || _imagePath != null);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isReupload ? strings.reuploadPrescription : strings.newPrescriptionEntry,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (isReupload) ...[
            const SizedBox(height: 8),
            Text(strings.reuploadHint, style: const TextStyle(fontSize: 13)),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              strings.uploadPendingNotice,
              style: TextStyle(fontSize: 13, color: context.palette.caution),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(_imagePath == null ? strings.attachImage : '1 photo attached'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 4,
            decoration: InputDecoration(labelText: strings.prescriptionNote),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: canSave ? _save : null,
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(strings.saveDraft),
          ),
        ],
      ),
    );
  }
}
