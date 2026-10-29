import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../providers/core_providers.dart';
import '../../../router/app_router.dart';
import '../../../widgets/caregiver_tag.dart';
import '../../../widgets/load_more_list.dart';
import '../../../widgets/state_views.dart';
import '../domain/prescription_models.dart';
import 'prescription_controller.dart';

/// The caregiver's view of one family member's prescriptions: upload one
/// for them, or confirm one the pharmacist prepared. Online only.
class MemberPrescriptionsScreen extends ConsumerStatefulWidget {
  const MemberPrescriptionsScreen({super.key, required this.userId, required this.memberName});

  final String userId;
  final String memberName;

  @override
  ConsumerState<MemberPrescriptionsScreen> createState() => _MemberPrescriptionsScreenState();
}

class _MemberPrescriptionsScreenState extends ConsumerState<MemberPrescriptionsScreen> {
  bool _uploading = false;

  Future<void> _upload(ImageSource source) async {
    final strings = ref.read(stringsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final file = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (file == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      await ref.read(prescriptionApiProvider).uploadForMember(forUserId: widget.userId, imagePath: file.path);
      ref.invalidate(serverPrescriptionsProvider(widget.userId));
      messenger.showSnackBar(SnackBar(content: Text(strings.uploadedForMember)));
    } on DioException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _chooseSource() {
    final strings = ref.read(stringsProvider);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(strings.takePhoto),
              onTap: () {
                Navigator.pop(ctx);
                _upload(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(strings.attachImage),
              onTap: () {
                Navigator.pop(ctx);
                _upload(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final listAsync = ref.watch(serverPrescriptionsProvider(widget.userId));

    return Scaffold(
      appBar: AppBar(title: Text(strings.prescriptionsOf(widget.memberName))),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(serverPrescriptionsProvider(widget.userId).future),
        child: listAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => ListView(children: [
            ErrorView(
              message: strings.needsInternetToSave,
              retryLabel: strings.retry,
              onRetry: () => ref.invalidate(serverPrescriptionsProvider(widget.userId)),
            ),
          ]),
          data: (items) => items.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 80),
                  EmptyView(message: strings.noPrescriptionsYet, icon: Icons.description_outlined),
                ])
              : LoadMoreListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => ServerPrescriptionTile(
                    prescription: items[i],
                    forUserId: widget.userId,
                  ),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _chooseSource,
        icon: _uploading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.upload_file),
        label: Text(strings.uploadPrescription),
      ),
    );
  }
}

/// A prescription as the server has it, with "Review and confirm" when the
/// pharmacist prepared it. Used for a member (caregiver view) and for
/// prescriptions a caregiver uploaded for me.
class ServerPrescriptionTile extends ConsumerWidget {
  const ServerPrescriptionTile({super.key, required this.prescription, this.forUserId});

  final PrescriptionSummaryModel prescription;
  final String? forUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final p = prescription;
    final d = p.createdAt.toLocal();
    final names = p.medicines.map((m) => m.medicineName).join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${d.day}/${d.month}/${d.year}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(_statusLabel(p.status, strings), style: TextStyle(color: _statusColor(context, p.status))),
              ],
            ),
            if (names.isNotEmpty) Text(names, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (p.status == 'REJECTED' && p.rejectionReason != null)
              Text(
                '${strings.rejectionReason}: ${p.rejectionReason}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (p.uploadedByCaregiver || p.confirmedByCaregiver) ...[
              const SizedBox(height: 8),
              const TagChip(),
            ],
            if (p.awaitsConfirmation) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  final done = await context.push<bool>(
                    AppRoutes.confirmPrescriptionPath(p.id, forUserId: forUserId),
                  );
                  if (done == true) ref.invalidate(serverPrescriptionsProvider(forUserId));
                },
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(strings.reviewAndConfirm),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _statusLabel(String status, AppStrings s) => switch (status) {
        'ACTIVE' => s.statusActive,
        'ENDED' => s.statusEnded,
        'AWAITING_CONFIRMATION' => s.statusAwaitingConfirmation,
        'REJECTED' => s.statusRejected,
        _ => s.statusPending,
      };

  static Color _statusColor(BuildContext context, String status) => switch (status) {
        'ACTIVE' => context.palette.success,
        'AWAITING_CONFIRMATION' => context.palette.info,
        'REJECTED' => Theme.of(context).colorScheme.error,
        _ => context.palette.warning,
      };
}
