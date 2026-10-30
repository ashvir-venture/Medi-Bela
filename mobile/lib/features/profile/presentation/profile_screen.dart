import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/domain/user_model.dart';
import '../../../router/app_router.dart';
import '../../../widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../family/presentation/family_controller.dart';
import 'account_dialogs.dart';
import 'profile_summary_providers.dart';

/// Who is signed in, Edit details and Change password right under it, the
/// way into Settings, and Log out (last, set apart).
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

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.user});

  final UserModel user;

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    // Watched so the logout dialog can read the count straight away.
    ref.watch(pendingSyncCountProvider);
    final members = ref.watch(familyMembersControllerProvider).valueOrNull;
    final me = members?.where((m) => m.userId == user.id).firstOrNull;
    final familyRole = me == null
        ? strings.notInFamilyYet
        : me.role == 'CAREGIVER'
            ? strings.familyOwner
            : strings.familyMemberRole;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // ---- Identity -----------------------------------------------------
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: 26, color: theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 2),
                      Text(user.phone, style: TextStyle(color: context.palette.muted)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.groups_outlined, size: 18, color: context.palette.muted),
                          const SizedBox(width: 6),
                          Flexible(child: Text(familyRole, style: TextStyle(color: context.palette.muted))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ---- My details, right under who I am --------------------------------
        Card(
          child: Column(
            children: [
              ListTile(
                minVerticalPadding: 16,
                leading: const Icon(Icons.edit_outlined),
                title: Text(strings.editDetails, style: theme.textTheme.titleMedium),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.editDetails),
              ),
              const Divider(height: 1),
              ListTile(
                minVerticalPadding: 16,
                leading: const Icon(Icons.lock_reset),
                title: Text(strings.changePassword, style: theme.textTheme.titleMedium),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showChangePasswordDialog(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---- Settings -----------------------------------------------------
        Card(
          child: ListTile(
            minVerticalPadding: 16,
            leading: const Icon(Icons.settings_outlined),
            title: Text(strings.settings, style: theme.textTheme.titleMedium),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.settings),
          ),
        ),

        // ---- Log out: last, set apart ---------------------------------------
        const SizedBox(height: 48),
        OutlinedButton.icon(
          onPressed: () => _logout(context, ref),
          icon: const Icon(Icons.logout),
          label: Text(strings.logout),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
