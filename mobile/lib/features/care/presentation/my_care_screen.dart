import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/core_providers.dart';
import '../domain/care_content.dart';
import 'care_providers.dart';
import 'care_widgets.dart';

/// "What care do you need?" (Round 15 A): the last step after sign-up
/// ([signupStep], with "Later") and Health → Edit conditions. Each picked
/// condition gets its own card on Home and a page under Health. For a member
/// ([who]) the caregiver picks for them (online).
class MyCareScreen extends ConsumerStatefulWidget {
  const MyCareScreen({super.key, this.signupStep = false, this.who = const CareSubject()});

  final bool signupStep;
  final CareSubject who;

  @override
  ConsumerState<MyCareScreen> createState() => _MyCareScreenState();
}

class _MyCareScreenState extends ConsumerState<MyCareScreen> {
  Set<String>? _picked;
  bool _saving = false;

  Future<void> _save() async {
    final picked = _picked ?? {};
    final codes = [for (final c in conditionCodes) if (picked.contains(c)) c];
    setState(() => _saving = true);
    final ok = await runCareAction(context, ref, () async {
      if (widget.who.isMember) {
        await ref.read(careApiProvider).setConditions(codes, forUserId: widget.who.memberId);
        invalidateMember(ref, widget.who);
      } else {
        await ref.read(careRepositoryProvider).setConditions(codes);
      }
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) _leave();
  }

  Future<void> _later() async {
    // Best effort: offline the step simply shows again next time.
    try {
      await ref.read(careRepositoryProvider).skipStep();
    } catch (_) {}
    if (mounted) _leave();
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = stringsOf(ref).r15;
    final p = context.palette;
    final lookups = ref.watch(careLookupsProvider).valueOrNull;
    final care = watchCareOf(ref, widget.who).valueOrNull;
    _picked ??= care == null ? null : {...care.conditions};
    final picked = _picked ?? <String>{};
    final codes = [
      ...conditionCodes,
      // Rows the owner adds later (no page of their own yet).
      ...?lookups?.conditions.map((c) => c.code).where((c) => !conditionCodes.contains(c)),
    ];

    return Scaffold(
      appBar: widget.signupStep
          ? AppBar(
              automaticallyImplyLeading: false,
              title: Text(s.lastStep, style: TextStyle(color: p.muted, fontSize: 15, fontWeight: FontWeight.w700)),
              actions: [TextButton(onPressed: _saving ? null : _later, child: Text(s.later))],
            )
          : AppBar(title: Text(widget.who.isMember ? '${s.myCare} · ${widget.who.memberName ?? ''}' : s.myCare)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s.whatCare, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: p.head)),
          const SizedBox(height: 6),
          Text(s.whatCareSub, style: TextStyle(color: p.muted, fontSize: 15)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: [
              for (final code in codes)
                _ConditionTile(
                  code: code,
                  name: conditionName(code, lookups, s.bn),
                  subtitle: conditionSubtitle(code, lookups, s.bn),
                  selected: picked.contains(code),
                  onTap: () => setState(() {
                    final next = {...picked};
                    next.contains(code) ? next.remove(code) : next.add(code);
                    _picked = next;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 10),
          PillButton(
            label: s.noneForNow,
            selected: picked.isEmpty,
            onTap: () => setState(() => _picked = {}),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.homeWillShow, style: TextStyle(color: p.muted, fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              if (picked.isEmpty)
                Text(s.homeWillShowNone)
              else
                Wrap(spacing: 8, runSpacing: 6, children: [
                  for (final code in codes.where(picked.contains))
                    StateChip(conditionName(code, lookups, s.bn), tone: ToneKind.navy),
                ]),
            ]),
          ),
          const SizedBox(height: 12),
          NoteLine(s.carePrivate, icon: Icons.lock_outline),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(widget.signupStep ? s.getStarted : s.save),
          ),
        ],
      ),
    );
  }
}

class _ConditionTile extends StatelessWidget {
  const _ConditionTile({required this.code, required this.name, this.subtitle, required this.selected, required this.onTap});

  final String code;
  final String name;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? p.primaryContainer : p.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? primary : p.line2, width: selected ? 2 : 1.5),
          ),
          child: Stack(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(conditionIcon(code), color: selected ? p.onPrimaryContainer : p.head),
              const SizedBox(height: 4),
              Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (subtitle != null)
                Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 12)),
            ]),
            if (selected)
              Positioned(
                top: 0,
                right: 0,
                child: CircleAvatar(radius: 12, backgroundColor: primary, child: Icon(Icons.check, size: 14, color: Theme.of(context).colorScheme.onPrimary)),
              ),
          ]),
        ),
      ),
    );
  }
}
