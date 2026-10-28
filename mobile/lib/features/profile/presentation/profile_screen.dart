import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../features/auth/domain/user_model.dart';
import '../../../router/app_router.dart';
import '../../../widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../medicine_schedule/presentation/medicine_schedule_controller.dart';
import '../../prescription/presentation/prescription_controller.dart';
import 'account_dialogs.dart';
import 'profile_summary_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final userState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(strings.profile)),
      body: RefreshIndicator(
        onRefresh: () => ref.read(authControllerProvider.notifier).refreshProfile(),
        child: userState.when(
          loading: () => const LoadingView(),
          error: (error, _) => ListView(
            children: [
              ErrorView(
                message: error.toString(),
                retryLabel: strings.retry,
                onRetry: () => ref.read(authControllerProvider.notifier).refreshProfile(),
              ),
            ],
          ),
          data: (user) {
            if (user == null) return const LoadingView();
            return _ProfileContent(user: user);
          },
        ),
      ),
    );
  }
}

class _ProfileContent extends ConsumerStatefulWidget {
  const _ProfileContent({required this.user});

  final UserModel user;

  @override
  ConsumerState<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends ConsumerState<_ProfileContent> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _addressController = TextEditingController(text: widget.user.address ?? '');
  }

  @override
  void didUpdateWidget(covariant _ProfileContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.name != widget.user.name) _nameController.text = widget.user.name;
    if (oldWidget.user.address != widget.user.address) {
      _addressController.text = widget.user.address ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final strings = ref.read(stringsProvider);
    final name = _nameController.text.trim();
    if (name.length < 2) {
      _toast(strings.name);
      return;
    }
    setState(() => _isSaving = true);
    final result = await ref.read(authControllerProvider.notifier).updateProfile({
      'name': name,
      'address': _addressController.text.trim(),
    });
    if (!mounted) return;
    setState(() => _isSaving = false);
    result.when(success: (_) => _toast(strings.save), failure: _toast);
  }

  /// Settings are account data (the server uses them to decide who gets
  /// alerts), so they change only when the server confirms. The switch is
  /// driven by the saved profile, so a failed change (e.g. offline) simply
  /// snaps back, with an explanation.
  Future<void> _updateSetting(Map<String, dynamic> patch) async {
    final result = await ref.read(authControllerProvider.notifier).updateProfile(patch);
    result.when(
      success: (_) {},
      failure: (_) => _toast(ref.read(stringsProvider).needsInternetToSave),
    );
  }

  /// Turning reminders off also stops family missed-dose alerts, so confirm.
  Future<void> _setMedicineReminders(bool value) async {
    if (!value) {
      final strings = ref.read(stringsProvider);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(strings.medicineRemindersOffTitle),
          content: Text(strings.medicineRemindersOffWarning),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(strings.cancel)),
            ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(strings.turnOffAction)),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await _updateSetting({'medicineRemindersEnabled': value});
  }

  Future<void> _logout() async {
    final strings = ref.read(stringsProvider);
    final pending = ref.read(pendingSyncCountProvider).valueOrNull ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.logout),
        // Logging out wipes this phone's data, so warn about unsent changes.
        content: Text(pending > 0
            ? '${strings.logoutConfirm}\n\n$pending ${strings.changesWaitingToSync}'
            : strings.logoutConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(strings.cancel)),
          ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(strings.logout)),
        ],
      ),
    );
    if (confirmed == true) await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final locale = ref.watch(localeControllerProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ---- Personal information -------------------------------------
        Center(
          child: CircleAvatar(
            radius: 36,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            child: Text(
              widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : '?',
              style: TextStyle(fontSize: 28, color: theme.colorScheme.primary),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(child: Text(widget.user.phone, style: TextStyle(color: Colors.grey.shade700))),
        const SizedBox(height: 20),
        _Header(strings.personalInformation),
        TextField(
          controller: _nameController,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: strings.name),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addressController,
          decoration: InputDecoration(labelText: strings.address),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(strings.save),
        ),

        // ---- Medicine routine summary ----------------------------------
        const SizedBox(height: 24),
        _Header(strings.myMedicineRoutines, action: strings.seeAll, onAction: () => context.go(AppRoutes.todaysMedicine)),
        const _RoutineSummary(),

        // ---- Prescription summary --------------------------------------
        const SizedBox(height: 24),
        _Header(strings.prescriptionsTitle, action: strings.seeAll, onAction: () => context.go(AppRoutes.prescription)),
        const _PrescriptionSummary(),

        // ---- Language ---------------------------------------------------
        const SizedBox(height: 24),
        _Header(strings.language),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'en', label: Text('English')),
            ButtonSegment(value: 'bn', label: Text('বাংলা')),
          ],
          selected: {locale.languageCode},
          onSelectionChanged: (selection) {
            // Applied instantly on this device; uploaded to the account in the
            // background (SessionServices) because push text follows it.
            ref.read(localeControllerProvider.notifier).setLanguage(selection.first);
          },
        ),

        // ---- Notification settings -------------------------------------
        const SizedBox(height: 24),
        _Header(strings.notificationSettings),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(strings.pushNotificationsLabel),
          subtitle: Text(strings.pushNotificationsHelp),
          value: widget.user.notificationsEnabled,
          onChanged: (value) => _updateSetting({'notificationsEnabled': value}),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(strings.medicineRemindersLabel),
          subtitle: Text(strings.medicineRemindersHelp),
          value: widget.user.medicineRemindersEnabled,
          onChanged: _setMedicineReminders,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(strings.noticesLabel),
          subtitle: Text(strings.noticesHelp),
          value: widget.user.noticesEnabled,
          onChanged: (value) => _updateSetting({'noticesEnabled': value}),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.alarm_outlined),
          title: Text(strings.reminderCheckTitle),
          subtitle: Text(strings.reminderCheckHelp),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.reminderCheck),
        ),

        // ---- Privacy settings --------------------------------------------
        const SizedBox(height: 16),
        _Header(strings.privacySettings),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(strings.visibleToFamily),
          subtitle: Text(strings.privacyHelp),
          value: widget.user.profileVisibleToFamily,
          onChanged: (value) => _updateSetting({'profileVisibleToFamily': value}),
        ),

        // ---- Sync status --------------------------------------------------
        const SizedBox(height: 16),
        _Header(strings.syncStatusTitle),
        const _SyncStatus(),

        // ---- Account ------------------------------------------------------
        const SizedBox(height: 16),
        _Header(strings.accountSection),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.lock_reset),
          title: Text(strings.changePassword),
          onTap: () => showChangePasswordDialog(context),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.delete_forever_outlined, color: theme.colorScheme.error),
          title: Text(
            strings.deleteAccount,
            style: TextStyle(color: theme.colorScheme.error),
          ),
          onTap: () => showDeleteAccountDialog(context),
        ),

        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout),
          label: Text(strings.logout),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            side: BorderSide(color: theme.colorScheme.error),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title, {this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// From the LOCAL routine cache: works offline.
class _RoutineSummary extends ConsumerWidget {
  const _RoutineSummary();

  static const _maxShown = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final routines = ref.watch(activeRoutinesProvider).valueOrNull;
    if (routines == null) return const LinearProgressIndicator();
    if (routines.isEmpty) return Text(strings.noActiveRoutines, style: TextStyle(color: Colors.grey.shade700));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in routines.take(_maxShown))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('• ${r.medicineName} — ${r.dosage}, ${r.frequency}', maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        if (routines.length > _maxShown)
          Text('+${routines.length - _maxShown}', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Counts from the local prescription records. Anything not yet uploaded is
/// shown as "waiting to upload"; once uploaded, the status is the server's.
class _PrescriptionSummary extends ConsumerWidget {
  const _PrescriptionSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final drafts = ref.watch(prescriptionDraftsProvider).valueOrNull;
    if (drafts == null) return const LinearProgressIndicator();
    if (drafts.isEmpty) return Text(strings.noPrescriptionsYet, style: TextStyle(color: Colors.grey.shade700));

    int count(bool Function(String? serverStatus, String status) test) =>
        drafts.where((d) => test(d.serverStatus, d.status)).length;
    final waiting = count((s, status) => s == null && status != 'synced');
    final pending = count((s, status) => s == 'PENDING' || (s == null && status == 'synced'));
    final completed = count((s, _) => s == 'COMPLETED');
    final rejected = count((s, _) => s == 'REJECTED');

    Widget chip(String label, int n, Color color) => Semantics(
          label: '$label: $n',
          excludeSemantics: true,
          child: Chip(
            avatar: CircleAvatar(backgroundColor: color, radius: 6),
            label: Text('$label: $n'),
            visualDensity: VisualDensity.compact,
          ),
        );

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        if (waiting > 0) chip(strings.waitingToUpload, waiting, Colors.blueGrey),
        chip(strings.statusPending, pending, Colors.orange.shade800),
        chip(strings.statusCompleted, completed, Colors.green.shade700),
        chip(strings.statusRejected, rejected, Theme.of(context).colorScheme.error),
      ],
    );
  }
}

class _SyncStatus extends ConsumerWidget {
  const _SyncStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    return Row(
      children: [
        Icon(
          pending == 0 ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined,
          color: pending == 0 ? Colors.green.shade700 : Colors.orange.shade800,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(pending == 0 ? strings.allChangesSynced : '$pending ${strings.changesWaitingToSync}'),
        ),
      ],
    );
  }
}
