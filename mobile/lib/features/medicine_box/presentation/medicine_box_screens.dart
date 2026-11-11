import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../providers/core_providers.dart';
import '../../../router/app_router.dart';
import '../../../widgets/state_views.dart';
import '../domain/medicine_box_models.dart';
import '../../../widgets/fit_label.dart';

/// My box: the offline copy (refreshed on open). A member's box (caregiver,
/// [forUserId]): online.
final _myBoxProvider = StreamProvider.autoDispose<MedicineBox?>((ref) {
  return ref.watch(medicineBoxRepositoryProvider).watch();
});

final _memberBoxProvider = FutureProvider.autoDispose.family<MedicineBox, String>(
  (ref, forUserId) => ref.watch(medicineBoxApiProvider).get(forUserId: forUserId),
);

/// Pending "taken" doses per medicine not yet on the server (my box only).
final _pendingTakenProvider = FutureProvider.autoDispose.family<int, (String, DateTime?)>(
  (ref, key) => ref.watch(medicineBoxRepositoryProvider).pendingTaken(key.$1, key.$2),
);

/// The Medicine box (Round 13): "Start your medicine box" until started,
/// then each medicine with what is left and a Refill button. Opened from
/// the Home card and the long button under Today / My medicines.
class MedicineBoxScreen extends ConsumerStatefulWidget {
  const MedicineBoxScreen({super.key, this.forUserId, this.memberName});

  final String? forUserId;
  final String? memberName;

  @override
  ConsumerState<MedicineBoxScreen> createState() => _MedicineBoxScreenState();
}

class _MedicineBoxScreenState extends ConsumerState<MedicineBoxScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.forUserId == null) Future.microtask(_refresh);
  }

  Future<void> _refresh() async {
    try {
      await ref.read(medicineBoxRepositoryProvider).refreshFromServer();
      if (mounted) setState(() => _error = null);
    } on DioException catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    }
  }

  Future<void> _openForm({String? routineId}) async {
    final changed = await context.push<bool>(
      AppRoutes.medicineBoxFormPath(routineId: routineId, forUserId: widget.forUserId),
    );
    if (changed == true && widget.forUserId != null) ref.invalidate(_memberBoxProvider(widget.forUserId!));
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final mine = widget.forUserId == null;
    final async = mine ? ref.watch(_myBoxProvider) : ref.watch(_memberBoxProvider(widget.forUserId!));
    final title = (widget.memberName?.isNotEmpty ?? false)
        ? '${strings.medicineBoxTitle} · ${widget.memberName}'
        : strings.medicineBoxTitle;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        onRefresh: mine ? _refresh : () async => ref.invalidate(_memberBoxProvider(widget.forUserId!)),
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: e is DioException ? friendlyErrorMessage(e) : strings.somethingWentWrong,
            retryLabel: strings.retry,
            onRetry: () => ref.invalidate(_memberBoxProvider(widget.forUserId ?? '')),
          ),
          data: (box) {
            if (box == null) {
              return _error != null
                  ? ErrorView(message: _error!, retryLabel: strings.retry, onRetry: _refresh)
                  : const LoadingView();
            }
            if (box.items.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 80),
                EmptyView(message: strings.boxNoMedicines, icon: Icons.medication_outlined),
              ]);
            }
            if (!box.started) return _StartView(strings: strings, onStart: () => _openForm());
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(strings.medicineBoxHelp, style: TextStyle(color: context.palette.muted)),
                const SizedBox(height: 12),
                for (final item in box.items)
                  _ItemCard(
                    item: item,
                    strings: strings,
                    pendingTaken: mine
                        ? ref.watch(_pendingTakenProvider((item.routineId, item.countedAt))).valueOrNull ?? 0
                        : 0,
                    onRefill: () => _openForm(routineId: item.routineId),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StartView extends StatelessWidget {
  const _StartView({required this.strings, required this.onStart});

  final AppStrings strings;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(Icons.inventory_2_outlined, size: 72, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(strings.startMedicineBox, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(strings.medicineBoxIntro, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: onStart,
          icon: const Icon(Icons.play_arrow),
          label: Text(strings.startMedicineBox),
        ),
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.strings, required this.pendingTaken, required this.onRefill});

  final MedicineBoxItem item;
  final AppStrings strings;
  final int pendingTaken;
  final VoidCallback onRefill;

  @override
  Widget build(BuildContext context) {
    final left = item.remainingWith(pendingTaken);
    final doses = item.dosesLeftWith(pendingTaken);
    final alert = stockAlertFor(doses);
    final color = switch (alert) {
      StockAlert.empty => Theme.of(context).colorScheme.error,
      StockAlert.low => context.palette.warningStrong,
      StockAlert.none => context.palette.success,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.medication_outlined, color: item.counted ? color : context.palette.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.medicineName, style: Theme.of(context).textTheme.titleMedium),
                  Text([item.formName, item.dosage].whereType<String>().where((s) => s.isNotEmpty).join(' • ')),
                  const SizedBox(height: 4),
                  Text(
                    left == null
                        ? strings.notCountedYet
                        : '${strings.unitsLeft(formatUnits(left))} • ${strings.dosesLeft(doses ?? 0)}',
                    style: TextStyle(color: item.counted ? color : context.palette.muted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: onRefill,
              child: Text(item.counted ? strings.boxRefillAction : strings.countAction),
            ),
          ],
        ),
      ),
    );
  }
}

/// Start (every medicine) or Refill (only [routineId]): "how many do you
/// have now?" per medicine. The number is the total now; it replaces the old
/// count.
class MedicineBoxFormScreen extends ConsumerStatefulWidget {
  const MedicineBoxFormScreen({super.key, this.routineId, this.forUserId});

  final String? routineId;
  final String? forUserId;

  @override
  ConsumerState<MedicineBoxFormScreen> createState() => _MedicineBoxFormScreenState();
}

class _MedicineBoxFormScreenState extends ConsumerState<MedicineBoxFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _fields = {};
  List<MedicineBoxItem>? _items;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final box = widget.forUserId == null
          ? (await ref.read(medicineBoxRepositoryProvider).cached()) ??
              await ref.read(medicineBoxRepositoryProvider).refreshFromServer()
          : await ref.read(medicineBoxApiProvider).get(forUserId: widget.forUserId);
      final items = widget.routineId == null
          ? box.items
          : box.items.where((i) => i.routineId == widget.routineId).toList();
      setState(() {
        _items = items;
        for (final i in items) {
          _fields[i.routineId] = TextEditingController();
        }
      });
    } on DioException catch (e) {
      setState(() => _error = friendlyErrorMessage(e));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final quantities = <String, double>{
      for (final e in _fields.entries)
        if (e.value.text.trim().isNotEmpty) e.key: double.parse(e.value.text.trim()),
    };
    if (quantities.isEmpty) {
      setState(() => _error = ref.read(stringsProvider).boxEnterOne);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.forUserId == null) {
        await ref.read(medicineBoxRepositoryProvider).save(quantities);
      } else {
        await ref.read(medicineBoxApiProvider).save(quantities, forUserId: widget.forUserId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(stringsProvider).boxSaved)));
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go(AppRoutes.medicineBox);
      }
    } on DioException catch (e) {
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: Text(widget.routineId == null ? strings.startMedicineBox : strings.boxRefillAction)),
      body: items == null
          ? (_error != null ? ErrorView(message: _error!, retryLabel: strings.retry, onRetry: _load) : const LoadingView())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(strings.howManyYouHave, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(strings.boxFormHelp, style: TextStyle(color: context.palette.muted)),
                  const SizedBox(height: 16),
                  for (final item in items) ...[
                    TextFormField(
                      controller: _fields[item.routineId],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      style: const TextStyle(fontSize: 20),
                      decoration: InputDecoration(
                        labelText: item.medicineName,
                        helperText: [item.formName, item.doseAmount].whereType<String>().join(' • '),
                        suffixText: strings.youHave,
                        prefixIcon: const Icon(Icons.medication_outlined),
                      ),
                      validator: (v) {
                        final text = v?.trim() ?? '';
                        if (text.isEmpty) return null;
                        final n = double.tryParse(text);
                        return n == null || n < 0 || n > 10000 ? strings.quantityInvalid : null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_error != null) ...[
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: 8),
                  ],
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
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

const _alarmChannel = MethodChannel('com.carebridge.app/reminder_status');

/// "A medicine ran out" (full screen when it opened as an alarm): the
/// picture, the medicine, Ignore (red: the caregiver is told) and Refill
/// (green: the count form for this medicine). Only the buttons close it.
class MedicineBoxEmptyScreen extends ConsumerWidget {
  const MedicineBoxEmptyScreen({super.key, required this.routineId, this.alarm = false});

  final String routineId;
  final bool alarm;

  Future<void> _leave(BuildContext context, String route) async {
    var movedBack = false;
    if (alarm && defaultTargetPlatform == TargetPlatform.android) {
      try {
        movedBack = await _alarmChannel.invokeMethod<bool>('finishAlarm') ?? false;
      } catch (_) {}
    }
    if (context.mounted) context.go(movedBack ? AppRoutes.home : route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final box = ref.watch(_myBoxProvider).valueOrNull;
    final item = box?.item(routineId);
    const big = Size(0, 72);

    return PopScope(
      canPop: !alarm,
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  // Buying medicine (owner's picture); the icon until it loads.
                  'assets/images/buying_medicine.png',
                  height: 200,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Icon(Icons.inventory_2_outlined, size: 96, color: theme.colorScheme.error),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                item == null ? strings.boxEmptyTitle : strings.boxRanOut(item.medicineName),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              if (item != null) ...[
                const SizedBox(height: 4),
                Text(
                  [item.formName, item.dosage].whereType<String>().where((s) => s.isNotEmpty).join(' • '),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ],
              const SizedBox(height: 16),
              Text(strings.boxEmptyHelp, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: big,
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                      textStyle: theme.textTheme.titleLarge,
                    ),
                    onPressed: () async {
                      try {
                        await ref.read(medicineBoxRepositoryProvider).ignore(routineId);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.needsInternetToSave)));
                        }
                        return;
                      }
                      if (context.mounted) await _leave(context, AppRoutes.home);
                    },
                    icon: const Icon(Icons.close, size: 28),
                    label: FitLabel(Text(strings.boxIgnoreAction)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: big,
                      backgroundColor: context.palette.success,
                      foregroundColor: theme.colorScheme.onError,
                      textStyle: theme.textTheme.titleLarge,
                    ),
                    onPressed: () => _leave(context, AppRoutes.medicineBoxFormPath(routineId: routineId)),
                    icon: const Icon(Icons.add_shopping_cart, size: 28),
                    label: FitLabel(Text(strings.boxRefillAction)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The Home card and the long button under Today / My medicines.
class MedicineBoxButton extends ConsumerWidget {
  const MedicineBoxButton({super.key, this.card = false});

  /// Home: a small card; elsewhere a long button.
  final bool card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    void open() => context.push(AppRoutes.medicineBox);
    if (!card) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: open,
            icon: const Icon(Icons.inventory_2_outlined),
            label: Text(strings.medicineBoxTitle),
          ),
        ),
      );
    }
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(Icons.inventory_2_outlined, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(strings.medicineBoxTitle, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(strings.medicineBoxCardSubtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: open,
      ),
    );
  }
}
