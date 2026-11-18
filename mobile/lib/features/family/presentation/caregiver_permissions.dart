import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../providers/core_providers.dart';
import '../domain/family_models.dart';

/// Round 18 (owner 2026-11-17): a member decides what the family caregiver
/// may do. Asked right after joining a family (and after a caregiver
/// handover); changeable in Settings → Privacy & family.
final caregiverPermissionsProvider = FutureProvider.autoDispose<CaregiverPermissions>(
  (ref) => ref.watch(familyApiProvider).getPermissions(),
);

/// The sheet with the two switches. Returns true when saved.
Future<bool> showCaregiverPermissionSheet(BuildContext context, WidgetRef ref, CaregiverPermissions current) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: current.answered,
    enableDrag: current.answered,
    builder: (_) => _PermissionSheet(current: current),
  );
  ref.invalidate(caregiverPermissionsProvider);
  return saved == true;
}

class _PermissionSheet extends ConsumerStatefulWidget {
  const _PermissionSheet({required this.current});

  final CaregiverPermissions current;

  @override
  ConsumerState<_PermissionSheet> createState() => _PermissionSheetState();
}

class _PermissionSheetState extends ConsumerState<_PermissionSheet> {
  late bool _view = widget.current.view;
  late bool _manage = widget.current.manage;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(familyApiProvider).setPermissions(view: _view || _manage, manage: _manage);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider).r18;
    final p = context.palette;
    final name = widget.current.caregiverName ?? s.yourCaregiver;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.permTitle(name), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(s.permIntro(name), style: TextStyle(color: p.muted, fontSize: AppType.small, height: AppType.bodyHeight)),
            const SizedBox(height: 12),
            SwitchListTile(
              key: const ValueKey('perm-view'),
              contentPadding: EdgeInsets.zero,
              title: Text(s.permView),
              subtitle: Text(s.permViewSub),
              value: _view || _manage,
              onChanged: _saving
                  ? null
                  : (v) => setState(() {
                        _view = v;
                        if (!v) _manage = false;
                      }),
            ),
            SwitchListTile(
              key: const ValueKey('perm-manage'),
              contentPadding: EdgeInsets.zero,
              title: Text(s.permManage),
              subtitle: Text(s.permManageSub),
              value: _manage,
              onChanged: _saving
                  ? null
                  : (v) => setState(() {
                        _manage = v;
                        if (v) _view = true;
                      }),
            ),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.notifications_active_outlined, size: 18, color: p.muted),
              const SizedBox(width: 8),
              Expanded(child: Text(s.permAlwaysAlerts(name), style: TextStyle(color: p.muted, fontSize: AppType.small))),
            ]),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('perm-save'),
              onPressed: _saving ? null : _save,
              child: Text(s.permSave),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks once per app start when the member hasn't answered yet (after
/// joining, or after the caregiver changed). Invisible otherwise.
class CaregiverPermissionPrompt extends ConsumerStatefulWidget {
  const CaregiverPermissionPrompt({super.key});

  @override
  ConsumerState<CaregiverPermissionPrompt> createState() => _CaregiverPermissionPromptState();
}

class _CaregiverPermissionPromptState extends ConsumerState<CaregiverPermissionPrompt> {
  static bool _shownThisRun = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<CaregiverPermissions>>(caregiverPermissionsProvider, (_, next) {
      final perms = next.valueOrNull;
      if (perms == null || !perms.needsAnswer || _shownThisRun) return;
      _shownThisRun = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showCaregiverPermissionSheet(context, ref, perms);
      });
    });
    return const SizedBox.shrink();
  }
}

/// For tests: lets the prompt ask again.
@visibleForTesting
void resetCaregiverPermissionPrompt() => _CaregiverPermissionPromptState._shownThisRun = false;
