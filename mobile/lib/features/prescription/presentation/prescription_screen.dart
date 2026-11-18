import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/core_providers.dart';
import '../../../router/app_router.dart';
import '../../../widgets/fit_label.dart';
import '../../../widgets/load_more_list.dart';
import '../../../widgets/state_views.dart';
import '../domain/prescription_draft_model.dart';
import '../domain/prescription_photo.dart';
import 'member_prescriptions_screen.dart' show ServerPrescriptionTile;
import 'prescription_camera_screen.dart';
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
              // Round 18: the add button heads the list (it was a floating
              // button next to the AI button on this tab root).
              itemCount: drafts.length + fromCaregiver.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) => index == 0
                  ? FilledButton.icon(
                      key: const ValueKey('prescription-add'),
                      onPressed: () => _openEntryForm(context),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(strings.newPrescriptionEntry),
                    )
                  : index - 1 < drafts.length
                      ? _DraftTile(draft: drafts[index - 1])
                      : ServerPrescriptionTile(prescription: fromCaregiver[index - 1 - drafts.length]),
            ),
          );
        },
      ),
    );
  }

  void _openEntryForm(BuildContext context) => openPrescriptionEntryForm(context);
}

/// [rejectedServerId] set = re-upload of that rejected prescription.
/// Owner 2026-11-18: the in-app camera opens first (with "Choose from
/// gallery" on it, at most 2 photos); then the sheet with the note and Send.
/// [autoCamera] off (widget tests) opens the sheet straight away.
Future<void> openPrescriptionEntryForm(BuildContext context, {String? rejectedServerId, bool autoCamera = true}) async {
  var pages = const <String>[];
  if (autoCamera) {
    final shot = await openPrescriptionCamera(context, max: _PrescriptionEntryFormState.maxPages);
    if (shot == null || !context.mounted) return; // closed the camera
    pages = shot;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PrescriptionEntryForm(rejectedServerId: rejectedServerId, initialPages: pages),
  );
}

class _DraftTile extends ConsumerWidget {
  const _DraftTile({required this.draft});

  final PrescriptionDraftModel draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final online = ref.watch(connectivityStreamProvider).valueOrNull ?? true;
    final (icon, color, label) = _statusDisplay(context, strings, online);

    return Card(
      child: ListTile(
        // Round 18: "Upload failed. Tap to retry".
        onTap: draft.status == 'failed' ? () => _retry(ref) : null,
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
                Text(label, style: TextStyle(color: color, fontSize: AppType.tiny)),
              ],
            ),
            if (draft.serverStatus == 'REJECTED' && draft.rejectionReason != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${strings.rejectionReason}: ${draft.rejectionReason}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: AppType.tiny),
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
  Future<void> _retry(WidgetRef ref) async {
    await ref.read(prescriptionLocalRepositoryProvider).markQueued(draft.id);
    final sync = ref.read(syncServiceProvider);
    await sync.resetFailedEntries();
    await sync.drainQueue();
  }

  (IconData, Color, String) _statusDisplay(BuildContext context, AppStrings strings, bool online) {
    final p = context.palette;
    // Round 18: Uploading… / Waiting for internet / Upload failed, tap to retry.
    if (draft.status == 'failed') {
      return (Icons.error_outline, p.later, strings.r18.uploadFailedTap);
    }
    if (draft.status != 'synced') {
      return online
          ? (Icons.cloud_upload_outlined, p.head, strings.r18.uploading)
          : (Icons.wifi_off_rounded, p.muted, strings.r18.waitingForInternet);
    }
    return switch (draft.serverStatus) {
      'ACTIVE' => (Icons.check_circle_rounded, p.taken, strings.statusActive),
      'ENDED' => (Icons.check_circle_outline, p.muted, strings.statusEnded),
      'AWAITING_CONFIRMATION' => (Icons.fact_check_outlined, p.head, strings.statusAwaitingConfirmation),
      'REJECTED' => (Icons.cancel_outlined, p.later, strings.statusRejected),
      _ => (Icons.hourglass_top_rounded, p.onWarnContainer, strings.statusPending),
    };
  }
}

class _PrescriptionEntryForm extends ConsumerStatefulWidget {
  const _PrescriptionEntryForm({this.rejectedServerId, this.initialPages = const []});

  /// The photos taken on the camera screen.
  final List<String> initialPages;

  /// Server id of the rejected prescription this re-uploads, if any.
  final String? rejectedServerId;

  @override
  ConsumerState<_PrescriptionEntryForm> createState() =>
      _PrescriptionEntryFormState();
}

class _PrescriptionEntryFormState extends ConsumerState<_PrescriptionEntryForm> {
  final _noteController = TextEditingController();
  /// Round 18 (client point 2): the pages, in order (owner 2026-11-18: at most 2 per prescription).
  late final List<String> _pages = [...widget.initialPages];
  bool _isSaving = false;

  static const maxPages = 2;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  /// The in-app camera for the rest (Retake replaces the last photo).
  Future<void> _camera({bool replaceLast = false}) async {
    final room = maxPages - _pages.length + (replaceLast && _pages.isNotEmpty ? 1 : 0);
    if (room <= 0) return;
    final shot = await openPrescriptionCamera(context, max: room);
    if (shot == null || shot.isEmpty || !mounted) return;
    setState(() {
      if (replaceLast && _pages.isNotEmpty) _pages.removeLast();
      _pages.addAll(shot.take(maxPages - _pages.length));
    });
  }

  /// Up to 2 photos at a time from the gallery (owner 2026-11-17).
  Future<void> _gallery() async {
    final room = maxPages - _pages.length;
    if (room <= 0) return;
    // pickMultiImage needs a limit of 2 or more; extra picks are dropped below.
    final files = await ImagePicker().pickMultiImage(
      limit: 2,
      maxWidth: prescriptionPhotoMaxSide,
      maxHeight: prescriptionPhotoMaxSide,
      imageQuality: prescriptionPhotoQuality,
    );
    if (!mounted) return;
    setState(() => _pages.addAll(files.take(room < 2 ? room : 2).map((f) => f.path)));
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final create = ref.read(createPrescriptionDraftProvider);
    await create(
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      pages: List.of(_pages),
      previousPrescriptionId: widget.rejectedServerId,
    );
    // The outbox uploads it in the background; the user can leave now.
    unawaited(ref.read(syncServiceProvider).drainQueue());
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ref.read(stringsProvider).r18.sentInBackground)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final s = strings.r18;
    final p = context.palette;
    final isReupload = widget.rejectedServerId != null;
    final canSave = !_isSaving && _pages.isNotEmpty;
    final full = _pages.length >= maxPages;

    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(isReupload ? strings.reuploadPrescription : strings.newPrescriptionEntry, style: Theme.of(context).textTheme.titleLarge),
            if (isReupload) ...[
              const SizedBox(height: 6),
              Text(strings.reuploadHint, style: TextStyle(fontSize: AppType.small, color: p.muted)),
            ],
            const SizedBox(height: 12),
            if (_pages.isNotEmpty) ...[
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(File(_pages[i]), width: 90, height: 120, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(width: 90, height: 120, color: p.surface2)),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: IconButton.filledTonal(
                        key: ValueKey('rx-page-remove-$i'),
                        visualDensity: VisualDensity.compact,
                        iconSize: 16,
                        onPressed: () => setState(() => _pages.removeAt(i)),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 6),
              Text(s.pagesN(_pages.length, maxPages), style: TextStyle(color: p.muted, fontSize: AppType.small)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('rx-retake'),
                    onPressed: () => _camera(replaceLast: true),
                    icon: const Icon(Icons.refresh_rounded),
                    label: FitLabel(Text(s.retake)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('rx-add-page'),
                    onPressed: full ? null : _camera,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: FitLabel(Text(s.addPage)),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
            ] else ...[
              FilledButton.icon(
                key: const ValueKey('rx-camera'),
                onPressed: _camera,
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(s.takePhoto),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              key: const ValueKey('rx-gallery'),
              onPressed: full ? null : _gallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(s.fromGallery),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(s.twoAtATime, style: TextStyle(color: p.muted, fontSize: AppType.small)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(labelText: strings.prescriptionNote),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const ValueKey('rx-send'),
              onPressed: canSave ? _save : null,
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(s.sendToPharmacist),
            ),
          ],
        ),
      ),
    );
  }
}
