import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/details_fields.dart';
import '../../../widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';

/// "Edit your details": name, address, date of birth, gender and location.
/// Its own page so Profile stays short. Loads the details from the server
/// (the offline profile copy keeps only the basics).
class EditDetailsScreen extends ConsumerStatefulWidget {
  const EditDetailsScreen({super.key});

  @override
  ConsumerState<EditDetailsScreen> createState() => _EditDetailsScreenState();
}

class _EditDetailsScreenState extends ConsumerState<EditDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  PersonalDetails _details = const PersonalDetails();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref.read(authRepositoryProvider).refreshProfileFromServer();
    if (!mounted) return;
    result.when(
      success: (user) {
        _name.text = user.name;
        _address.text = user.address ?? '';
        _details = PersonalDetails(
          dateOfBirth: user.dateOfBirth,
          genderId: user.genderId,
          divisionId: user.divisionId,
          districtId: user.districtId,
          upazilaId: user.upazilaId,
        );
      },
      failure: (message) => _error = message,
    );
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final strings = ref.read(stringsProvider);
    final result = await ref.read(authControllerProvider.notifier).updateProfile({
      'name': _name.text.trim(),
      'address': _address.text.trim(),
      ..._details.toJson(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.detailsSaved)));
        context.pop();
      },
      failure: (message) => setState(() => _error = message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(strings.editYourDetails)),
      body: _loading
          ? const LoadingView()
          : _error != null && _name.text.isEmpty
              ? ErrorView(message: _error!, retryLabel: strings.retry, onRetry: _load)
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextFormField(
                        controller: _name,
                        decoration: InputDecoration(labelText: strings.name, prefixIcon: const Icon(Icons.person_outline)),
                        validator: (v) => (v == null || v.trim().length < 2) ? strings.requiredField : null,
                      ),
                      const SizedBox(height: 16),
                      PersonalDetailsFields(value: _details, onChanged: (d) => setState(() => _details = d)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _address,
                        decoration: InputDecoration(
                          labelText: strings.addressOptional,
                          prefixIcon: const Icon(Icons.home_outlined),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(strings.save),
                      ),
                    ],
                  ),
                ),
    );
  }
}
