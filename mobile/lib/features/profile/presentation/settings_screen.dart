import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../features/auth/domain/user_model.dart';
import '../../../providers/core_providers.dart';
import '../../../router/app_router.dart';
import '../../../widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../family/presentation/family_controller.dart';
import '../../reminders/presentation/reminder_status_controller.dart';
import '../../help/presentation/help_screens.dart';
import 'account_dialogs.dart';

/// Settings, in five sections: Account; Reminders & notifications; Privacy &
/// family; Appearance & language; Account actions (only Delete is red).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final user = ref.watch(authControllerProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(strings.settings)),
      body: user == null ? const LoadingView() : _SettingsContent(user: user),
    );
  }
}

class _SettingsContent extends ConsumerStatefulWidget {
  const _SettingsContent({required this.user});

  final UserModel user;

  @override
  ConsumerState<_SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends ConsumerState<_SettingsContent> {
  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

  Future<void> _leaveFamily() async {
    final strings = ref.read(stringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.leaveFamily),
        content: Text(strings.leaveFamilyConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(strings.cancel)),
          ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(strings.leaveAction)),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await ref.read(familyMembersControllerProvider.notifier).leave();
    result.when(success: (_) {}, failure: _toast);
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final user = widget.user;
    final locale = ref.watch(localeControllerProvider);
    // Account actions need the server; offline they are disabled.
    final online = ref.watch(connectivityStreamProvider).valueOrNull ?? true;
    final inFamily = (ref.watch(familyMembersControllerProvider).valueOrNull ?? const []).isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // (Edit details and Change password are on the Profile page.)
        // ---- Reminders & notifications --------------------------------------
        _SectionHeader(strings.remindersAndNotifications),
        const ReminderStatusRefresher(child: _ReminderCheckTile()),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(strings.pushNotificationsLabel),
          subtitle: Text(strings.pushNotificationsHelp),
          value: user.notificationsEnabled,
          onChanged: (value) => _updateSetting({'notificationsEnabled': value}),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(strings.medicineRemindersLabel),
          subtitle: Text(strings.medicineRemindersHelp),
          value: user.medicineRemindersEnabled,
          onChanged: _setMedicineReminders,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(strings.noticesLabel),
          subtitle: Text(strings.noticesHelp),
          value: user.noticesEnabled,
          onChanged: (value) => _updateSetting({'noticesEnabled': value}),
        ),

        // ---- Privacy & family -------------------------------------------------
        _SectionHeader(strings.privacyAndFamily),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          // The privacy flag: off by default; on hides this user from the
          // whole family, caregiver included (stored inverted on the account).
          title: Text(strings.hideFromFamily),
          subtitle: Text(strings.privacyHelp),
          value: !user.profileVisibleToFamily,
          onChanged: (hide) => _updateSetting({'profileVisibleToFamily': !hide}),
        ),
        if (inFamily)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.group_remove_outlined),
            title: Text(strings.leaveFamily),
            enabled: online,
            onTap: _leaveFamily,
          ),

        // ---- Appearance & language ----------------------------------------------
        _SectionHeader(strings.appearanceAndLanguage),
        Text(strings.language, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
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
        const SizedBox(height: 16),
        Text(strings.appearance, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        SegmentedButton<ThemeMode>(
          segments: [
            ButtonSegment(value: ThemeMode.system, label: Text(strings.themeSystem)),
            ButtonSegment(value: ThemeMode.light, label: Text(strings.themeLight)),
            ButtonSegment(value: ThemeMode.dark, label: Text(strings.themeDark)),
          ],
          selected: {ref.watch(themeModeControllerProvider)},
          onSelectionChanged: (selection) =>
              ref.read(themeModeControllerProvider.notifier).setMode(selection.first),
        ),

        // ---- Help & about (text ships with the app: works offline) -----------------
        _SectionHeader(strings.helpAndAbout),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.support_agent_outlined),
          title: Text(ref.watch(helpContentProvider).supportTitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.support),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.privacy_tip_outlined),
          title: Text(ref.watch(helpContentProvider).privacyTitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.privacyTerms),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.info_outline),
          title: Text(ref.watch(helpContentProvider).aboutTitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.aboutUs),
        ),

        // ---- Account actions (only Delete is red) ---------------------------------
        _SectionHeader(strings.accountActions),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.pause_circle_outline),
          title: Text(strings.deactivateAccount),
          subtitle: online ? null : Text(strings.needsInternetToSave),
          enabled: online,
          onTap: () => showDeactivateDialog(context),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.delete_forever_outlined, color: online ? theme.colorScheme.error : null),
          title: Text(
            strings.deleteAccount,
            style: TextStyle(color: online ? theme.colorScheme.error : null),
          ),
          subtitle: online ? null : Text(strings.needsInternetToSave),
          enabled: online,
          onTap: () => context.push(AppRoutes.deleteAccount),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 4),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }
}

/// Reminder check, first in its section, with a status dot: green "All good"
/// or orange "Needs attention" (reminders blocked or possibly late).
class _ReminderCheckTile extends ConsumerWidget {
  const _ReminderCheckTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final status = ref.watch(reminderStatusProvider).valueOrNull;
    final ok = status == null || !(status.blocked || status.mayBeLate);
    final color = ok ? context.palette.success : context.palette.warning;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.alarm_outlined),
      title: Text(strings.reminderCheckTitle),
      subtitle: status == null
          ? null
          : Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(ok ? strings.allGood : strings.needsAttention, style: TextStyle(color: color)),
              ],
            ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(AppRoutes.reminderCheck),
    );
  }
}
