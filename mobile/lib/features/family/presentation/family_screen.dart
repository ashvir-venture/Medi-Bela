import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/family_models.dart';
import 'family_controller.dart';

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final membersState = ref.watch(familyMembersControllerProvider);
    final myId = ref.watch(authControllerProvider).value?.id;
    final members = membersState.value ?? const <FamilyMemberModel>[];
    // Only the caregiver may invite (the server enforces this too; the button
    // is hidden so members aren't offered an action that would be refused).
    final isCaregiver = members.any((m) => m.userId == myId && m.role == 'CAREGIVER');

    return Scaffold(
      appBar: AppBar(title: Text(strings.myFamily)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(familyStatusSummaryProvider);
          await ref.read(familyEventsControllerProvider.notifier).reload();
          await ref.read(familyInvitationsControllerProvider.notifier).load();
          await ref.read(familyMembersControllerProvider.notifier).refresh();
        },
        child: membersState.when(
          loading: () => const LoadingView(),
          error: (error, _) => ListView(
            children: [
              ErrorView(
                message: error.toString(),
                retryLabel: strings.retry,
                onRetry: () =>
                    ref.read(familyMembersControllerProvider.notifier).refresh(),
              ),
            ],
          ),
          data: (members) => _FamilyContent(members: members, myId: myId),
        ),
      ),
      floatingActionButton: isCaregiver
          ? FloatingActionButton.extended(
              onPressed: () => _showInviteDialog(context, ref),
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(strings.inviteMember),
            )
          : null,
    );
  }

  void _showInviteDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => const _InviteMemberDialog(),
    );
  }
}

class _FamilyContent extends ConsumerWidget {
  const _FamilyContent({required this.members, required this.myId});

  final List<FamilyMemberModel> members;
  final String? myId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);

    if (members.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 40),
          EmptyView(
            message: strings.notInFamilyYet,
            icon: Icons.groups_outlined,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
            child: Text(
              strings.familyEmptyHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.palette.subtle),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ElevatedButton(
              onPressed: () => _createFamily(context, ref),
              child: Text(strings.createFamily),
            ),
          ),
          const SizedBox(height: 24),
          _PendingInvitationsSection(),
        ],
      );
    }

    final viewerIsCaregiver = members.any((m) => m.userId == myId && m.role == 'CAREGIVER');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      // header + members + (solo hint) + sharing note + invitations + activity
      itemCount: members.length + 5,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              strings.myFamily,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        }
        if (index == members.length + 1) {
          // Only me in the family: explain how to see anyone's status.
          return members.length <= 1
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    strings.inviteToSeeStatus,
                    style: TextStyle(color: context.palette.subtle),
                  ),
                )
              : const SizedBox.shrink();
        }
        if (index == members.length + 2) {
          // Transparency: members should know what the family can see.
          return Card(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(strings.familySharingNote)),
                ],
              ),
            ),
          );
        }
        if (index == members.length + 3) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _PendingInvitationsSection(),
          );
        }
        if (index == members.length + 4) {
          return const Padding(
            padding: EdgeInsets.only(top: 16),
            child: _FamilyActivitySection(),
          );
        }
        final member = members[index - 1];
        return _MemberTile(
          member: member,
          isMe: member.userId == myId,
          canRemove: viewerIsCaregiver && member.userId != myId,
        );
      },
    );
  }

  Future<void> _createFamily(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(familyMembersControllerProvider.notifier)
        .createFamily();
    if (!context.mounted) return;
    result.when(
      success: (_) {},
      failure: (message) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.member, required this.isMe, required this.canRemove});

  final FamilyMemberModel member;
  final bool isMe;

  /// The caregiver may remove anyone but themself (they use Leave family).
  final bool canRemove;

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final strings = ref.read(stringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.removeFromFamily),
        content: Text(strings.removeMemberConfirm(member.name)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(strings.cancel)),
          ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(strings.removeAction)),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await ref.read(familyMembersControllerProvider.notifier).removeMember(member.userId);
    if (!context.mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(familyStatusSummaryProvider);
        ref.read(familyEventsControllerProvider.notifier).reload();
      },
      failure: (message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message))),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final isCaregiver = member.role == 'CAREGIVER';
    // Summary failures (offline, etc.) must never break the member list: the
    // tile simply shows no status chips.
    final summary = isMe
        ? null
        : ref.watch(familyStatusSummaryProvider).valueOrNull?[member.userId];
    final paused = member.paused || (summary?.paused ?? false);

    return Card(
      child: ListTile(
        onTap: isMe
            ? null
            : () => context.push('/family/member/${member.userId}'),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          child: Text(
            member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
            style: TextStyle(color: theme.colorScheme.primary),
          ),
        ),
        title: Text(member.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(member.phone),
            if (paused)
              Text(strings.accountPaused, style: TextStyle(color: context.palette.warningStrong))
            else if (summary != null) ...[
              const SizedBox(height: 4),
              _SummaryChips(summary: summary),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCaregiver)
              Chip(
                label: Text(strings.familyOwner),
                visualDensity: VisualDensity.compact,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
            if (canRemove)
              PopupMenuButton<String>(
                tooltip: strings.removeFromFamily,
                onSelected: (_) => _remove(context, ref),
                itemBuilder: (_) => [PopupMenuItem(value: 'remove', child: Text(strings.removeFromFamily))],
              )
            else if (!isMe)
              const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _SummaryChips extends ConsumerWidget {
  const _SummaryChips({required this.summary});

  final MemberStatusSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    if (!summary.shared) {
      return Text(
        strings.statusNotShared,
        style: TextStyle(color: context.palette.subtle, fontSize: 12),
      );
    }
    if (summary.total == 0) {
      return Text(
        strings.noDosesToday,
        style: TextStyle(color: context.palette.subtle, fontSize: 12),
      );
    }
    return Wrap(
      spacing: 6,
      children: [
        Text('${strings.doseTaken}: ${summary.taken}/${summary.total}',
            style: const TextStyle(fontSize: 12)),
        if (summary.missed > 0)
          Text(
            '${strings.doseMissed}: ${summary.missed}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
      ],
    );
  }
}

/// The family's activity feed: who joined, left or was removed, and caregiver
/// changes. Newest first, 10 at a time with "Load more" (online only).
class _FamilyActivitySection extends ConsumerWidget {
  const _FamilyActivitySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final feed = ref.watch(familyEventsControllerProvider);
    final muted = TextStyle(color: context.palette.subtle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.familyActivity, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (feed.items.isEmpty && feed.isLoading)
          const SkeletonLines()
        else if (feed.items.isEmpty && feed.error != null)
          Text(feed.error!, style: TextStyle(color: Theme.of(context).colorScheme.error))
        else if (feed.items.isEmpty)
          Text(strings.noFamilyActivity, style: muted)
        else
          for (final event in feed.items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_eventIcon(event.kind)),
              title: Text(familyEventLine(event, strings)),
              subtitle: Text(_formatWhen(event.createdAt), style: muted),
            ),
        if (feed.nextCursor != null)
          OutlinedButton(
            onPressed: feed.isLoading ? null : () => ref.read(familyEventsControllerProvider.notifier).loadMore(),
            child: Text(strings.loadMore),
          ),
      ],
    );
  }

  static IconData _eventIcon(String kind) => switch (kind) {
        'JOINED' => Icons.person_add_alt_1_outlined,
        'LEFT' => Icons.logout,
        'REMOVED' => Icons.person_remove_outlined,
        'CAREGIVER_CHANGED' => Icons.verified_user_outlined,
        _ => Icons.groups_outlined,
      };

  static String _formatWhen(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)} ${two(at.hour)}:${two(at.minute)}';
  }
}

/// One feed line in the app's language. A deleted account shows as
/// "Deleted user"; a missing person (should not happen) the same.
String familyEventLine(FamilyEvent event, AppStrings strings) {
  String nameOf(FamilyEventPerson? p) => p == null || p.deleted ? strings.deletedUser : p.name;
  final name = nameOf(event.subject);
  return switch (event.kind) {
    'JOINED' => strings.eventJoined(name),
    'LEFT' => strings.eventLeft(name),
    'REMOVED' => strings.eventRemoved(name, nameOf(event.actor)),
    'CAREGIVER_CHANGED' => strings.eventCaregiver(name),
    _ => strings.eventCreated(name),
  };
}

class _PendingInvitationsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final invitationsState = ref.watch(familyInvitationsControllerProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.pendingInvitations,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          invitationsState.when(
            loading: () => const SkeletonLines(lines: 2),
            error: (error, _) => Text(
              error.toString(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            data: (invitations) {
              if (invitations.isEmpty) {
                return Text(
                  strings.noItemsYet,
                  style: TextStyle(color: context.palette.subtle),
                );
              }
              return Column(
                children: invitations
                    .map((i) => _InvitationTile(invitation: i))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InvitationTile extends ConsumerWidget {
  const _InvitationTile({required this.invitation});

  final FamilyInvitationModel invitation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invitation.familyName ?? invitation.invitedByName ?? '—',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (invitation.invitedByName != null)
                    Text(
                      '${strings.invitedBy} ${invitation.invitedByName!}',
                      style: TextStyle(color: context.palette.subtle),
                    ),
                  const SizedBox(height: 6),
                  // What joining means: the inviter becomes this person's caregiver.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 18, color: context.palette.warning),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          strings.invitationWarning,
                          style: TextStyle(fontSize: 13, color: context.palette.warningStrong),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _respond(context, ref, accept: false),
              child: Text(strings.decline),
            ),
            ElevatedButton(
              onPressed: () => _respond(context, ref, accept: true),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 40),
              ),
              child: Text(strings.accept),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref, {
    required bool accept,
  }) async {
    final membersController = ref.read(familyMembersControllerProvider.notifier);
    final result = accept
        ? await membersController.acceptInvitation(invitation.id)
        : await membersController.declineInvitation(invitation.id);

    if (!context.mounted) return;
    result.when(
      success: (_) {
        ref.read(familyInvitationsControllerProvider.notifier).load();
      },
      failure: (message) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
    );
  }
}

class _InviteMemberDialog extends ConsumerStatefulWidget {
  const _InviteMemberDialog();

  @override
  ConsumerState<_InviteMemberDialog> createState() =>
      _InviteMemberDialogState();
}

class _InviteMemberDialogState extends ConsumerState<_InviteMemberDialog> {
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final strings = ref.read(stringsProvider);
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMessage = strings.requiredField);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final result = await ref
        .read(familyMembersControllerProvider.notifier)
        .inviteMember(phone);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    result.when(
      success: (_) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(SnackBar(content: Text(strings.inviteSent)));
      },
      failure: (message) => setState(() => _errorMessage = message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);

    return AlertDialog(
      title: Text(strings.inviteMember),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(hintText: strings.invitePhoneHint),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(strings.inviteMember),
        ),
      ],
    );
  }
}
