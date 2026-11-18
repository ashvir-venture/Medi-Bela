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
import '../../../widgets/pill_icon.dart';
import '../../../widgets/tile_grid.dart';
import '../../../widgets/state_views.dart';
import '../domain/medicine_box_models.dart';
import '../../../widgets/fit_label.dart';
import '../../../widgets/notification_tone.dart';

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

  /// Round 18: after adding, counting or removing a box-only item.
  Future<void> _afterExtra(MedicineBox box) async {
    if (widget.forUserId != null) {
      ref.invalidate(_memberBoxProvider(widget.forUserId!));
    } else {
      await _refresh();
    }
  }

  Future<void> _addExtra(BuildContext context) async {
    final box = await showModalBottomSheet<MedicineBox>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddExtraSheet(forUserId: widget.forUserId),
    );
    if (box != null) await _afterExtra(box);
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
            if (box.items.isNotEmpty && !box.started && box.extras.isEmpty) {
              return _StartView(strings: strings, onStart: () => _openForm());
            }
            final s = strings.r18;
            // Round 18 (client points 5, 6): medicines, then care supplies
            // and medicines with no reminder, each with how long it lasts.
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(strings.medicineBoxHelp, style: TextStyle(color: context.palette.muted, fontSize: AppType.small)),
                const SizedBox(height: 12),
                Text(s.boxMedicines, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (box.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(strings.boxNoMedicines, style: TextStyle(color: context.palette.muted)),
                  ),
                // The demo's 3-column tile grid.
                TileGrid(children: [
                  for (final item in box.items)
                    _ItemCard(
                      item: item,
                      strings: strings,
                      pendingTaken: mine
                          ? ref.watch(_pendingTakenProvider((item.routineId, item.countedAt))).valueOrNull ?? 0
                          : 0,
                      onRefill: () => _openForm(routineId: item.routineId),
                    ),
                ]),
                const SizedBox(height: 16),
                Text(s.careSupplies, style: Theme.of(context).textTheme.titleMedium),
                Text(s.careSuppliesSub, style: TextStyle(color: context.palette.muted, fontSize: AppType.small)),
                const SizedBox(height: 8),
                TileGrid(children: [
                  for (final x in box.extras)
                    _ExtraCard(item: x, strings: strings, onChanged: _afterExtra, forUserId: widget.forUserId),
                  BoxTile(
                    key: const ValueKey('box-add-item'),
                    dashed: true,
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: context.palette.primaryContainer, borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.add_rounded, color: context.palette.onPrimaryContainer),
                    ),
                    title: s.addItem,
                    onTap: () => _addExtra(context),
                  ),
                ]),
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
        const Center(child: MedicineBoxIcon(size: 96)),
        const SizedBox(height: 16),
        Text(strings.startMedicineBox, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(strings.medicineBoxIntro, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: onStart,
          icon: const Icon(Icons.play_arrow_outlined),
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
    final p = context.palette;
    final left = item.remainingWith(pendingTaken);
    final doses = item.dosesLeftWith(pendingTaken);
    final days = item.daysLeftWith(pendingTaken);
    final alert = stockAlertFor(doses);
    final color = switch (alert) {
      StockAlert.empty => Theme.of(context).colorScheme.error,
      StockAlert.low => p.warningStrong,
      StockAlert.none => p.onOkContainer,
    };
    final low = item.counted && alert != StockAlert.none;
    return BoxTile(
      key: ValueKey('box-item-${item.routineId}'),
      low: low,
      leading: PillIcon(color: item.pillColor, shape: item.pillShape, formName: item.formName, size: 44),
      title: item.medicineName,
      line: left == null
          ? strings.notCountedYet
          // Round 18: days left, else what is left in the box's own unit (ml for a syrup).
          : days != null
              ? strings.r18.daysLeftTag(days)
              : strings.r18.leftAmount('${formatUnits(left)} ${strings.r18.unitName(item.unit ?? 'dose')}'),
      lineColor: item.counted ? color : p.muted,
      fill: days == null ? null : (days / 30).clamp(0.0, 1.0).toDouble(),
      action: item.counted ? strings.boxRefillAction : strings.countAction,
      onTap: onRefill,
    );
  }
}

/// One tile of the box: picture, name (2 lines), how long it lasts, a small
/// bar, and an orange edge when it runs low.
class BoxTile extends StatelessWidget {
  const BoxTile({
    super.key,
    required this.leading,
    required this.title,
    required this.onTap,
    this.line,
    this.lineColor,
    this.fill,
    this.action,
    this.low = false,
    this.dashed = false,
  });

  final Widget leading;
  final String title;
  final String? line;
  final Color? lineColor;
  final double? fill;
  final String? action;
  final bool low;
  final bool dashed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: low
          ? BorderSide(color: p.warning, width: 2)
          : dashed
              ? BorderSide(color: p.line2, width: 1.5)
              : BorderSide.none,
    );
    return Material(
      color: dashed ? Colors.transparent : p.surface,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
          child: Column(children: [
            leading,
            const SizedBox(height: 6),
            Text(title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: AppType.small, color: p.ink, height: 1.3)),
            if (line != null) ...[
              const SizedBox(height: 4),
              Text(line!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: AppType.tiny, color: lineColor ?? p.muted)),
            ],
            const Spacer(),
            if (fill != null) ...[
              const SizedBox(height: 6),
              FractionallySizedBox(
                widthFactor: 0.8,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(value: fill, minHeight: 5, color: low ? p.warning : p.success, backgroundColor: p.track),
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 6),
              Text(action!, textAlign: TextAlign.center, style: TextStyle(color: p.link, fontWeight: FontWeight.w700, fontSize: AppType.tiny)),
            ],
          ]),
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
                      style: const TextStyle(fontSize: AppType.appBar),
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
    // The box's own light yellow, as everywhere (owner 2026-11-18).
    final tone = noteStyle(context, NoteKind.box);

    return PopScope(
      canPop: !alarm,
      child: Scaffold(
        backgroundColor: tone.bg,
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
                  errorBuilder: (_, _, _) => const Center(child: MedicineBoxIcon(size: 96)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                item == null ? strings.boxEmptyTitle : strings.boxRanOut(item.medicineName),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(color: tone.fg, fontWeight: FontWeight.w700),
              ),
              if (item != null) ...[
                const SizedBox(height: 12),
                Center(child: PillIcon(color: item.pillColor, shape: item.pillShape, formName: item.formName, size: 56)),
              ],
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

/// The medicine box's own look, the same everywhere (owner 2026-11-18): the
/// box icon on a light yellow tile (palette warnContainer / onWarnContainer).
class MedicineBoxIcon extends StatelessWidget {
  const MedicineBoxIcon({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: p.warnContainer, borderRadius: BorderRadius.circular(size >= 44 ? 12 : 10)),
      child: Icon(Icons.inventory_2_outlined, size: size * 0.55, color: p.onWarnContainer),
    );
  }
}

/// The medicine box button under Today / My medicines (where it always
/// was): amber like the box everywhere, and short, left-aligned, so the AI
/// button on the right never covers it (owner 2026-11-18).
class MedicineBoxButton extends ConsumerWidget {
  const MedicineBoxButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final p = context.palette;
    return SafeArea(
      top: false,
      child: Padding(
        // Right: room for the AI button (56 + its margin).
        padding: const EdgeInsets.fromLTRB(16, 4, 88, 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const ValueKey('medicine-box-button'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              backgroundColor: p.warnContainer,
              foregroundColor: p.onWarnContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onPressed: () => context.push(AppRoutes.medicineBox),
            icon: const Icon(Icons.inventory_2_outlined, size: 20),
            label: FitLabel(Text(strings.medicineBoxTitle)),
          ),
        ),
      ),
    );
  }
}


/// Round 18 (client point 5): a box item with no reminder.
class _ExtraCard extends ConsumerWidget {
  const _ExtraCard({required this.item, required this.strings, required this.onChanged, this.forUserId});

  final BoxExtra item;
  final AppStrings strings;
  final Future<void> Function(MedicineBox) onChanged;
  final String? forUserId;

  Future<void> _bought(BuildContext context, WidgetRef ref) async {
    final s = strings.r18;
    final c = TextEditingController(text: formatUnits(item.remaining));
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.newCount),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: s.unitName(item.unit ?? 'piece')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(strings.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, double.tryParse(c.text.trim())), child: Text(strings.save)),
        ],
      ),
    );
    c.dispose();
    if (value == null) return;
    try {
      await onChanged(await ref.read(medicineBoxApiProvider).updateExtra(item.id, {'quantity': value}, forUserId: forUserId));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    try {
      await onChanged(await ref.read(medicineBoxApiProvider).removeExtra(item.id, forUserId: forUserId));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  /// Tapping the tile: Bought or Remove.
  Future<void> _actions(BuildContext context, WidgetRef ref) async {
    final s = strings.r18;
    final pick = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.add_shopping_cart_outlined),
            title: Text(s.bought),
            onTap: () => Navigator.pop(ctx, 'bought'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded),
            title: Text(s.removeItem),
            onTap: () => Navigator.pop(ctx, 'remove'),
          ),
        ]),
      ),
    );
    if (!context.mounted) return;
    if (pick == 'bought') {
      await _bought(context, ref);
    } else if (pick == 'remove') {
      await _remove(context, ref);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = strings.r18;
    final p = context.palette;
    final low = item.low;
    return BoxTile(
      key: ValueKey('box-extra-${item.id}'),
      low: low,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: low ? p.warnContainer : p.navyContainer, borderRadius: BorderRadius.circular(12)),
        child: Icon(item.isSupply ? Icons.medical_services_outlined : Icons.medication_outlined,
            color: low ? p.onWarnContainer : p.onNavyContainer),
      ),
      title: item.name,
      line: [
        item.daysLeft != null
            ? s.daysLeftTag(item.daysLeft!)
            : s.leftAmount('${formatUnits(item.remaining)} ${s.unitName(item.unit ?? 'piece')}'),
        if (!item.isSupply) s.noReminder,
      ].join(' · '),
      lineColor: low ? p.warningStrong : p.muted,
      action: s.bought,
      onTap: () => _actions(context, ref),
    );
  }
}

/// Round 18: add a care supply or a medicine kept with no reminder.
class _AddExtraSheet extends ConsumerStatefulWidget {
  const _AddExtraSheet({this.forUserId});

  final String? forUserId;

  @override
  ConsumerState<_AddExtraSheet> createState() => _AddExtraSheetState();
}

class _AddExtraSheetState extends ConsumerState<_AddExtraSheet> {
  final _name = TextEditingController();
  final _count = TextEditingController();
  final _perDay = TextEditingController();
  String _kind = 'SUPPLY';
  String _unit = 'piece';
  int _refill = 5;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _count.dispose();
    _perDay.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final strings = ref.read(stringsProvider);
    final count = double.tryParse(_count.text.trim());
    if (_name.text.trim().isEmpty || count == null) {
      setState(() => _error = strings.requiredField);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final box = await ref.read(medicineBoxApiProvider).addExtra({
        'kind': _kind,
        'name': _name.text.trim(),
        'unit': _unit,
        'quantity': count,
        'perDay': ?double.tryParse(_perDay.text.trim()),
        'refillDays': _refill,
      }, forUserId: widget.forUserId);
      if (mounted) Navigator.pop(context, box);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final s = strings.r18;
    final p = context.palette;
    Widget choice(String label, bool on, VoidCallback onTap) => ChoiceChip(label: Text(label), selected: on, onSelected: (_) => onTap());
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s.addItem, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            choice(s.kindSupply, _kind == 'SUPPLY', () => setState(() => _kind = 'SUPPLY')),
            choice(s.kindMedicine, _kind == 'MEDICINE', () => setState(() {
                  _kind = 'MEDICINE';
                  if (_unit == 'piece') _unit = 'tablet';
                })),
          ]),
          if (_kind == 'SUPPLY') ...[
            const SizedBox(height: 10),
            Text(s.suggested, style: TextStyle(color: p.muted, fontSize: AppType.small)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final (name, unit) in s.supplySuggestions)
                ActionChip(
                  label: Text(name),
                  onPressed: () => setState(() {
                    _name.text = name;
                    _unit = unit;
                  }),
                ),
            ]),
          ],
          const SizedBox(height: 12),
          TextField(key: const ValueKey('extra-name'), controller: _name, decoration: InputDecoration(labelText: s.itemName, hintText: s.itemNameHint)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                key: const ValueKey('extra-count'),
                controller: _count,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: s.howManyNow),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _unit,
              underline: const SizedBox.shrink(),
              items: [for (final u in const ['piece', 'tablet', 'capsule', 'ml', 'pen', 'vial', 'strip', 'unit', 'puff', 'sachet']) DropdownMenuItem(value: u, child: Text(s.unitName(u)))],
              onChanged: (v) => setState(() => _unit = v ?? _unit),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _perDay,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: s.usedPerDay, helperText: s.usedPerDayHelp),
          ),
          const SizedBox(height: 12),
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
            Text(s.remindWhenLeft, style: TextStyle(color: p.muted, fontSize: AppType.small)),
            for (final d in const [3, 5, 7]) choice(s.daysN(d), _refill == d, () => setState(() => _refill = d)),
          ]),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: p.later, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 16),
          FilledButton(key: const ValueKey('extra-save'), onPressed: _saving ? null : _save, child: Text(strings.save)),
        ]),
      ),
    );
  }
}
