import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../providers/core_providers.dart';
import '../../../router/app_router.dart';
import '../../../widgets/language_switcher.dart';

/// Step 2: the 6-digit code from the SMS + the new password. Success sends the
/// user back to the login screen; every failure shows the same generic server
/// message ("Invalid or expired code"), so nothing about the account leaks.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.initialPhone});

  final String? initialPhone;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _phone = TextEditingController(text: widget.initialPhone ?? '');
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _isSubmitting = false;
  bool _isResending = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final result = await ref.read(authRepositoryProvider).resetPassword(
          phone: _phone.text.trim(),
          code: _code.text.trim(),
          newPassword: _password.text,
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.read(stringsProvider).passwordResetDone)),
        );
        context.go(AppRoutes.login);
      },
      failure: (message) => setState(() => _error = message),
    );
  }

  Future<void> _resend() async {
    if (_phone.text.trim().isEmpty || _isResending) return;
    setState(() {
      _isResending = true;
      _error = null;
    });
    final result = await ref
        .read(authRepositoryProvider)
        .forgotPassword(phone: _phone.text.trim());
    if (!mounted) return;
    setState(() => _isResending = false);
    result.when(
      success: (_) => setState(() => _info = ref.read(stringsProvider).resetCodeSentNotice),
      failure: (message) => setState(() => _error = message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.resetPasswordTitle), actions: const [LanguageSwitcher()]),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_info ?? strings.resetCodeSentNotice),
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: strings.phone,
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? strings.requiredField : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: strings.verificationCode,
                        prefixIcon: const Icon(Icons.sms_outlined),
                        counterText: '',
                      ),
                      validator: (v) => v == null || v.trim().length != 6 ? strings.requiredField : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: strings.newPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return strings.requiredField;
                        if (v.length < 6) return strings.passwordTooShort;
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirm,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: strings.confirmPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) => v != _password.text ? strings.passwordsDoNotMatch : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(strings.saveNewPassword),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isResending ? null : _resend,
                      child: Text(strings.sendCode),
                    ),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.login),
                      child: Text(strings.backToLogin),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
