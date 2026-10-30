import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../router/app_router.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/delete_phrase.dart';
import 'account_dialogs.dart';

/// Delete, screen 1: what is erased and what is kept, with the gentler
/// option (deactivate) offered first.
class DeleteAccountWarningScreen extends ConsumerWidget {
  const DeleteAccountWarningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.deleteAccount)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(strings.deleteWarningTitle, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 20),
          Text(strings.deleteErasedHeading, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(strings.deleteErasedList),
          const SizedBox(height: 20),
          Text(strings.deleteKeptHeading, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(strings.deleteKeptList),
          const SizedBox(height: 20),
          Text(strings.deleteCannotUndo, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 28),
          Text(strings.deactivateHint),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () => showDeactivateDialog(context),
            child: Text(strings.deactivateInstead),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () => context.push(AppRoutes.deleteAccountConfirm),
            child: Text(strings.continueToDelete),
          ),
        ],
      ),
    );
  }
}

/// Delete, screen 2: type the sentence shown (in the app's language); the
/// password field and the red Delete button enable only once it matches.
/// The sentence guards against a slip; the server checks the password.
class DeleteAccountConfirmScreen extends ConsumerStatefulWidget {
  const DeleteAccountConfirmScreen({super.key});

  @override
  ConsumerState<DeleteAccountConfirmScreen> createState() => _DeleteAccountConfirmScreenState();
}

class _DeleteAccountConfirmScreenState extends ConsumerState<DeleteAccountConfirmScreen> {
  final _phrase = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phrase.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_busy || _password.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(authControllerProvider.notifier).deleteAccount(password: _password.text);
    if (!mounted) return;
    // Success: the session has ended and the router shows Login.
    result.when(
      success: (_) {},
      failure: (message) => setState(() {
        _busy = false;
        _error = message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final matches = deletePhraseMatches(_phrase.text, strings.deletePhrase);
    final canDelete = matches && _password.text.isNotEmpty && !_busy;

    return Scaffold(
      appBar: AppBar(title: Text(strings.deleteConfirmTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(strings.deletePhrasePrompt),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(strings.deletePhrase, style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('deletePhraseField'),
            controller: _phrase,
            minLines: 1,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              suffixIcon: matches ? const Icon(Icons.check_circle_outline) : null,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('deletePasswordField'),
            controller: _password,
            enabled: matches && !_busy,
            obscureText: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: strings.password),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 24),
          // The only red element.
          FilledButton(
            key: const Key('deleteButton'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: canDelete ? _delete : null,
            child: _busy
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(strings.deleteMyAccount),
          ),
        ],
      ),
    );
  }
}
