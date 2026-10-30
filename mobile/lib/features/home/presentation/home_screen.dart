import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/presentation/auth_controller.dart';
import '../../../features/health/domain/health_models.dart';
import '../../../features/health/presentation/health_controller.dart';
import '../../../features/inbox/presentation/inbox_controller.dart';
import '../../../features/medicine_schedule/domain/dose_display_status.dart';
import '../../../features/medicine_schedule/domain/medicine_schedule_models.dart';
import '../../../features/medicine_schedule/presentation/medicine_schedule_controller.dart';
import '../../../core/localization/app_strings.dart';
import '../../../features/notices/domain/notice_models.dart';
import '../../../features/notices/presentation/notices_controller.dart';
import '../../../router/app_router.dart';
import '../../../widgets/app_logo.dart';
import '../../../widgets/sponsored_ad_banner.dart';
import '../../prescription/presentation/prescription_screen.dart';
import '../../reminders/presentation/reminder_status_banner.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final userState = ref.watch(authControllerProvider);
    final userName = userState.value?.name;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(height: 32),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                userName == null ? strings.appName : 'Hi, $userName',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (context) {
              final unread =
                  ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
              return IconButton(
                tooltip: strings.notifications,
                onPressed: () async {
                  await context.push(AppRoutes.inbox);
                  ref.invalidate(unreadNotificationCountProvider);
                },
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text(unread > 99 ? '99+' : '$unread'),
                  child: const Icon(Icons.notifications_outlined),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myNoticesProvider);
          await ref.read(authControllerProvider.notifier).refreshProfile();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const ReminderStatusBanner(),
            const _TodaysMedicineSection(),
            const SizedBox(height: 20),
            const _HealthRemindersSection(),
            const SizedBox(height: 20),
            // The first thing every new user does, and the main thing a
            // returning patient does: one large button, not hidden in a tab.
            FilledButton.icon(
              onPressed: () => openPrescriptionEntryForm(context),
              icon: const Icon(Icons.upload_file_outlined, size: 26),
              label: Text(strings.uploadPrescription),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(60),
                textStyle: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 16),
            _AssistantCard(
              title: strings.aiAssistant,
              subtitle: strings.assistantCardSubtitle,
              onTap: () => context.push(AppRoutes.assistant),
            ),
            const SizedBox(height: 20),
            // Active notices only: published, not expired, audience-matched
            // (the server filters; expiry is re-checked on the client).
            const _HomeNotices(),
            const SizedBox(height: 16),
            // Ad slot: static for now, to be sold to a sponsor later.
            SponsoredAdBanner(
              tag: strings.sponsoredAdTag,
              title: strings.adHeadline,
              message: strings.adMessage,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime dt) {
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  return '$hour12:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.trailing,
    required this.onSeeAll,
    required this.seeAllLabel,
  });

  final String title;
  final String? trailing;
  final VoidCallback onSeeAll;
  final String seeAllLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        if (trailing != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              trailing!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        TextButton(onPressed: onSeeAll, child: Text(seeAllLabel)),
      ],
    );
  }
}

/// Today's doses from the LOCAL database, so this works offline. Anything
/// that still needs attention (due / missed / upcoming) is listed before what
/// is already taken, and the list is capped so Home stays short.
class _TodaysMedicineSection extends ConsumerWidget {
  const _TodaysMedicineSection();

  static const _maxShown = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final doses = ref.watch(todaysMedicineProvider).valueOrNull;

    if (doses == null) {
      return Column(
        children: [
          _SectionHeader(
            title: strings.todaysMedicine,
            onSeeAll: () => context.go(AppRoutes.todaysMedicine),
            seeAllLabel: strings.seeAll,
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    final taken = doses.where((d) => d.isTaken).length;
    final attention = doses.where((d) => !d.isTaken).toList();
    final ordered = [...attention, ...doses.where((d) => d.isTaken)];
    final shown = ordered.take(_maxShown).toList();
    final more = ordered.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: strings.todaysMedicine,
          trailing: doses.isEmpty
              ? null
              : '$taken/${doses.length} ${strings.doseTaken}',
          onSeeAll: () => context.go(AppRoutes.todaysMedicine),
          seeAllLabel: strings.seeAll,
        ),
        if (doses.isEmpty)
          _EmptyLine(
            icon: Icons.medication_outlined,
            text: strings.noMedicineToday,
          )
        else ...[
          for (final dose in shown) _DoseRow(dose: dose, strings: strings),
          if (more > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                '+$more',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ],
    );
  }
}

class _DoseRow extends StatelessWidget {
  const _DoseRow({required this.dose, required this.strings});

  final MedicineDoseModel dose;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (computeDoseDisplayStatus(dose)) {
      DoseDisplayStatus.taken => (
        Icons.check_circle,
        context.palette.success,
        strings.doseTaken,
      ),
      DoseDisplayStatus.missed => (
        Icons.cancel_outlined,
        Theme.of(context).colorScheme.error,
        strings.doseMissed,
      ),
      DoseDisplayStatus.due => (
        Icons.notifications_active_outlined,
        context.palette.warning,
        strings.doseDue,
      ),
      DoseDisplayStatus.skipped => (
        Icons.block,
        context.palette.muted,
        strings.doseMissed,
      ),
      DoseDisplayStatus.upcoming => (
        Icons.schedule,
        Colors.blueGrey,
        strings.doseUpcoming,
      ),
    };
    final time = _formatTime(dose.scheduledAt);
    // Status is conveyed by icon + colour + WORD, and the whole row is one
    // screen-reader announcement, so colour is never the only signal.
    return Semantics(
      label: '${dose.medicineName}, ${dose.dosage}, $time, $label',
      excludeSemantics: true,
      child: Card(
        margin: const EdgeInsets.only(top: 8),
        child: ListTile(
          minVerticalPadding: 8,
          leading: Icon(icon, color: color),
          title: Text(
            dose.medicineName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${dose.dosage} • $time',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          onTap: () => context.go(AppRoutes.todaysMedicine),
        ),
      ),
    );
  }
}

/// Overdue + upcoming health reminders from the LOCAL database (offline-safe).
class _HealthRemindersSection extends ConsumerWidget {
  const _HealthRemindersSection();

  static const _maxShown = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final due =
        ref.watch(dueHealthRemindersProvider).valueOrNull ??
        const <HealthReminderModel>[];
    final upcoming =
        ref.watch(upcomingHealthRemindersProvider).valueOrNull ??
        const <HealthReminderModel>[];
    final seen = <String>{};
    final items = [
      ...due,
      ...upcoming,
    ].where((r) => seen.add(r.id)).take(_maxShown).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: strings.healthReminders,
          onSeeAll: () => context.go(AppRoutes.healthReminders),
          seeAllLabel: strings.seeAll,
        ),
        if (items.isEmpty)
          _EmptyLine(
            icon: Icons.favorite_border,
            text: strings.noHealthReminders,
          )
        else
          for (final r in items)
            Semantics(
              label: '${r.title}, ${r.scheduledAt.day}/${r.scheduledAt.month}',
              excludeSemantics: true,
              child: Card(
                margin: const EdgeInsets.only(top: 8),
                child: ListTile(
                  leading: Icon(
                    Icons.favorite_border,
                    color: due.any((d) => d.id == r.id)
                        ? context.palette.warning
                        : Colors.blueGrey,
                  ),
                  title: Text(
                    r.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${r.scheduledAt.day}/${r.scheduledAt.month} • ${_formatTime(r.scheduledAt)}',
                  ),
                  onTap: () => context.go(AppRoutes.healthReminders),
                ),
              ),
            ),
      ],
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: context.palette.subtle),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(color: context.palette.muted)),
          ),
        ],
      ),
    );
  }
}

class _HomeNotices extends ConsumerWidget {
  const _HomeNotices();

  static const _maxShown = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final async = ref.watch(myNoticesProvider);

    // Loading / error / empty all collapse to the same tappable card, so a
    // slow or failed notices request never leaves a hole or an error box on Home.
    Widget linkCard(String subtitle) => _PlaceholderSectionCard(
      icon: Icons.campaign_outlined,
      title: strings.governmentNotices,
      subtitle: subtitle,
      onTap: () => context.push(AppRoutes.notices),
    );

    return async.when(
      loading: () => linkCard(strings.viewNotices),
      error: (_, __) => linkCard(strings.noticesUnavailable),
      data: (notices) {
        if (notices.isEmpty) return linkCard(strings.noNoticesYet);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings.governmentNotices,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.notices),
                  child: Text(strings.seeAll),
                ),
              ],
            ),
            for (final notice in notices.take(_maxShown))
              _NoticeTile(notice: notice),
          ],
        );
      },
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({required this.notice});

  final NoticeModel notice;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.push(AppRoutes.notices),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.campaign_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notice.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notice.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: context.palette.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderSectionCard extends StatelessWidget {
  const _PlaceholderSectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Theme.of(context).colorScheme.primary
                    .withValues(alpha: 0.12),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: context.palette.subtle),
                    ),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// The AI assistant, as one large card on Home (no tab of its own).
class _AssistantCard extends StatelessWidget {
  const _AssistantCard({required this.title, required this.subtitle, required this.onTap});

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                  child: Icon(Icons.smart_toy_outlined, size: 30, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(subtitle, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
