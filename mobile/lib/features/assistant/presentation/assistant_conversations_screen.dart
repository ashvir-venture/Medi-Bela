import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../router/app_router.dart';
import '../../../widgets/load_more_list.dart';
import '../domain/assistant_models.dart';
import 'assistant_conversations_controller.dart';
import '../../../widgets/state_views.dart';

/// Asks before anything is deleted. Shared by this list and the chat screen.
Future<bool> confirmDeleteConversation(
  BuildContext context,
  AppStrings strings,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(strings.assistantDeleteTitle),
      content: Text(strings.assistantDeleteConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(strings.cancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(strings.delete),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// The user's saved assistant conversations (newest first), with delete.
class AssistantConversationsScreen extends ConsumerStatefulWidget {
  const AssistantConversationsScreen({super.key});

  @override
  ConsumerState<AssistantConversationsScreen> createState() =>
      _AssistantConversationsScreenState();
}

class _AssistantConversationsScreenState
    extends ConsumerState<AssistantConversationsScreen> {
  Future<void> _open([String? id]) async {
    await context.push(
      id == null
          ? AppRoutes.assistantChat
          : AppRoutes.assistantConversationPath(id),
    );
    // The chat may have added messages, closed the conversation or deleted it.
    if (mounted) ref.read(assistantConversationsProvider.notifier).refresh();
  }

  Future<void> _delete(AssistantConversationSummary conversation) async {
    final strings = ref.read(stringsProvider);
    if (!await confirmDeleteConversation(context, strings)) return;
    if (!mounted) return;
    final outcome = await ref
        .read(assistantConversationsProvider.notifier)
        .delete(conversation.id);
    if (!mounted || outcome == DeleteOutcome.deleted) return;
    // The conversation is still in the list; say why.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          outcome == DeleteOutcome.offline
              ? strings.needsInternetToSave
              : strings.assistantDeleteFailed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final state = ref.watch(assistantConversationsProvider);
    final controller = ref.read(assistantConversationsProvider.notifier);

    Widget body;
    if (state.isLoading && state.items.isEmpty) {
      body = const LoadingView();
    } else if (state.loadFailed && state.items.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(strings.assistantLoadFailed, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(onPressed: controller.load, child: Text(strings.retry)),
            ],
          ),
        ),
      );
    } else if (state.items.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.smart_toy_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(strings.assistantNoConversations, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    } else {
      body = LoadMoreListView(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: state.items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final c = state.items[index];
          final deleting = state.deletingIds.contains(c.id);
          return ListTile(
            enabled: !deleting,
            leading: Icon(
              c.isClosed ? Icons.lock_outline : Icons.chat_bubble_outline,
            ),
            title: Text(
              c.preview.isEmpty ? strings.aiAssistant : c.preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${strings.assistantMessagesLabel}: '
              '${c.userMessageCount}/${c.maxUserMessages}'
              '${c.isClosed ? ' · ${strings.assistantClosedLabel}' : ''}'
              '${deleting ? ' · ${strings.assistantDeleting}' : ''}',
            ),
            trailing: deleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    tooltip: strings.delete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(c),
                  ),
            onTap: deleting ? null : () => _open(c.id),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.assistantConversationsTitle),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
        ),
      ),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _open,
        icon: const Icon(Icons.add),
        label: Text(strings.assistantNewConversation),
      ),
    );
  }
}
