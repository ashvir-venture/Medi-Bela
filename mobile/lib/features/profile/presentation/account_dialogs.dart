import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../auth/presentation/auth_controller.dart';

/// Change the password while signed in (current + new + confirm).
Future<void> showChangePasswordDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ChangePasswordDialog(),
  );
}

/// Pause the account after re-entering the password (signing in again
/// brings it back). Delete is two screens of its own (delete_account_screens.dart).
Future<void> showDeactivateDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _DeactivateDialog(),
  );
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(authControllerProvider.notifier).changePassword(
          currentPassword: _current.text,
          newPassword: _new.text,
        );
    if (!mounted) return;
    result.when(
      success: (_) {
        final message = ref.read(stringsProvider).passwordChangedDone;
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(SnackBar(content: Text(message)));
      },
      failure: (message) => setState(() {
        _busy = false;
        _error = message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    return AlertDialog(
      title: Text(strings.changePassword),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              TextFormField(
                controller: _current,
                obscureText: true,
                decoration: InputDecoration(labelText: strings.currentPassword),
                validator: (v) => v == null || v.isEmpty ? strings.requiredField : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _new,
                obscureText: true,
                decoration: InputDecoration(labelText: strings.newPassword),
                validator: (v) {
                  if (v == null || v.isEmpty) return strings.requiredField;
                  // Same minimum as the server, sign-up and password reset.
                  if (v.length < 6) return strings.passwordTooShort;
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirm,
                obscureText: true,
                decoration: InputDecoration(labelText: strings.confirmPassword),
                validator: (v) => v != _new.text ? strings.passwordsDoNotMatch : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(strings.save),
        ),
      ],
    );
  }
}

class _DeactivateDialog extends ConsumerStatefulWidget {
  const _DeactivateDialog();

  @override
  ConsumerState<_DeactivateDialog> createState() => _DeactivateDialogState();
}

class _DeactivateDialogState extends ConsumerState<_DeactivateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(authControllerProvider.notifier).deactivate(password: _password.text);
    if (!mounted) return;
    result.when(
      // The session has ended: the router returns to the login screen.
      success: (_) => Navigator.of(context).pop(),
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
    return AlertDialog(
      title: Text(strings.deactivateAccount),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.deactivateExplain),
              const SizedBox(height: 12),
              Text(strings.deleteAccountPasswordPrompt),
              const SizedBox(height: 8),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                ),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(labelText: strings.password),
                validator: (v) => v == null || v.isEmpty ? strings.requiredField : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(strings.deactivateAction),
        ),
      ],
    );
  }
}
