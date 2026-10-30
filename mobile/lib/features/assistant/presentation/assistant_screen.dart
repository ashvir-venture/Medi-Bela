import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../router/app_router.dart';
import '../domain/assistant_models.dart';
import 'assistant_controller.dart';
import 'assistant_conversations_controller.dart';
import 'assistant_conversations_screen.dart' show confirmDeleteConversation;
import '../../../widgets/state_views.dart';

/// One conversation. [conversationId] is a saved conversation to open (loaded
/// from the server, read-only once closed), or null to start a new one.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key, this.conversationId});

  final String? conversationId;

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  late final _provider = assistantControllerProvider(widget.conversationId);

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _submit(String text) {
    if (text.trim().isEmpty) return;
    ref.read(_provider.notifier).send(text);
    _input.clear();
  }

  void _leave() =>
      context.canPop() ? context.pop() : context.go(AppRoutes.assistant);

  Future<void> _delete() async {
    final strings = ref.read(stringsProvider);
    if (!await confirmDeleteConversation(context, strings)) return;
    if (!mounted) return;
    final outcome = await ref.read(_provider.notifier).deleteConversation();
    if (!mounted) return;
    if (outcome == DeleteOutcome.deleted) {
      _leave(); // back to the list; the conversation is already gone from it
      return;
    }
    // Kept as it was; say why.
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

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _errorText(AppStrings s, AssistantError e) {
    switch (e) {
      case AssistantError.tooManyRequests:
        return s.assistantTooMany;
      case AssistantError.offline:
        return s.assistantNeedsInternet;
      case AssistantError.loadFailed:
        return s.assistantLoadFailed;
      case AssistantError.notFound:
        return s.assistantGone;
      default:
        return s.assistantUnavailable;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final state = ref.watch(_provider);
    final controller = ref.read(_provider.notifier);
    final conversationId = state.conversationId;
    final isDeleting = conversationId != null &&
        ref.watch(assistantConversationsProvider
            .select((s) => s.deletingIds.contains(conversationId)));
    final gone = state.error == AssistantError.notFound;
    // Typing is allowed only when the server would accept a new message.
    final canType = !state.isSending &&
        !state.isLoading &&
        state.pendingText == null &&
        !state.isClosed &&
        !gone &&
        !isDeleting;

    ref.listen<AssistantState>(_provider, (prev, next) {
      if (prev?.messages.length != next.messages.length || prev?.isSending != next.isSending) {
        _scrollToEnd();
      }
    });

    final showEmptyState = state.messages.isEmpty &&
        !state.isLoading &&
        !gone &&
        state.error != AssistantError.loadFailed;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.aiAssistant),
        leading: BackButton(onPressed: _leave),
        actions: [
          if (conversationId != null && !gone)
            isDeleting
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: strings.delete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _delete,
                  ),
        ],
      ),
      body: Column(
        children: [
          // Always visible, not dismissible: what the assistant is and is not.
          Material(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.assistantLimits, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    strings.assistantPrivacy,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.palette.muted),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: state.isLoading && state.messages.isEmpty
                ? const LoadingView(rows: 3)
                : showEmptyState
                    ? _EmptyState(strings: strings, onPick: _submit)
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        itemCount: state.messages.length + (state.isSending ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == state.messages.length) return const _TypingBubble();
                          return _Bubble(message: state.messages[index], strings: strings);
                        },
                      ),
          ),
          if (state.error != AssistantError.none)
            Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(_errorText(strings, state.error))),
                    if (state.error == AssistantError.loadFailed)
                      TextButton(onPressed: controller.load, child: Text(strings.retry))
                    else if (state.error != AssistantError.notFound)
                      TextButton(onPressed: controller.retry, child: Text(strings.retry)),
                  ],
                ),
              ),
            ),
          if (state.isClosed)
            // Read-only: no input, just why, and a way to start over.
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lock_outline, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(strings.assistantConversationClosed)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isDeleting
                              ? null
                              : () => context.pushReplacement(AppRoutes.assistantChat),
                          child: Text(strings.assistantNewConversation),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (gone)
            // Deleted (here or elsewhere): nothing to type into.
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.pushReplacement(AppRoutes.assistantChat),
                    child: Text(strings.assistantNewConversation),
                  ),
                ),
              ),
            )
          else
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (state.userMessageCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${strings.assistantMessagesLabel}: '
                          '${state.userMessageCount}/${state.maxUserMessages}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: context.palette.muted),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            enabled: canType,
                            maxLength: 500,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: _submit,
                            decoration: InputDecoration(
                              hintText: strings.assistantHint,
                              counterText: '',
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: strings.sendLabel,
                          onPressed: canType ? () => _submit(_input.text) : null,
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.strings, required this.onPick});

  final AppStrings strings;
  final void Function(String) onPick;

  @override
  Widget build(BuildContext context) {
    final suggestions = [
      strings.assistantSuggestion1,
      strings.assistantSuggestion2,
      strings.assistantSuggestion3,
    ];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(Icons.smart_toy_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(strings.assistantIntro, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in suggestions) ActionChip(label: Text(s), onPressed: () => onPick(s)),
          ],
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.strings});

  final ChatMessage message;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fromUser = message.fromUser;
    final urgent = message.isEmergency;

    final background = fromUser
        ? theme.colorScheme.primary
        : urgent
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.surfaceContainerHighest;
    final foreground = fromUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (urgent)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: theme.colorScheme.error),
                    const SizedBox(width: 4),
                    Text(
                      strings.assistantUrgent,
                      style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.error),
                    ),
                  ],
                ),
              ),
            SelectableText(message.text, style: TextStyle(color: foreground)),
            if (!fromUser && (message.disclaimer ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message.disclaimer!,
                style: theme.textTheme.bodySmall?.copyWith(color: context.palette.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
