import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/presentation/auth_controller.dart';
import '../../../features/health/domain/health_models.dart';
import '../../../features/health/presentation/health_controller.dart';
import '../../../features/notices/domain/notice_models.dart';
import '../../../features/notices/presentation/notices_controller.dart';
import '../../../router/app_router.dart';
import '../../../widgets/sponsored_ad_banner.dart';
import '../../family/presentation/family_controller.dart';
import '../../reminders/presentation/full_screen_permission_screen.dart';
import 'easy_home_screen.dart';
import 'home_top.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final easyMode = ref.watch(authControllerProvider.select((u) => u.value?.easyMode ?? false));
    // Round 14: easy mode for elders replaces Home.
    if (easyMode) return const EasyHomeScreen();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myNoticesProvider);
          ref.invalidate(familyStatusSummaryProvider);
          await ref.read(authControllerProvider.notifier).refreshProfile();
        },
        // Round 14: the demo's Home. A navy band, the "Today's medicine"
        // card over it, services, family, health reminders, notices.
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const HomeBand(),
            const TodayHeroCard(),
            Transform.translate(
              offset: const Offset(0, -42),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FullScreenPromptOnce(),
                    const HomeServices(),
                    const SizedBox(height: 12),
                    const HomeFamilyCard(),
                    const SizedBox(height: 16),
                    const _HealthRemindersSection(),
                    const SizedBox(height: 20),
                    // Active notices only: published, not expired, audience-matched
                    // (the server filters; expiry is re-checked on the client).
                    const _HomeNotices(),
                    const SizedBox(height: 16),
                    // Ad slot: static for now, to be sold to a sponsor later.
                    SponsoredAdBanner(
                      tag: ref.watch(stringsProvider).sponsoredAdTag,
                      title: ref.watch(stringsProvider).adHeadline,
                      message: ref.watch(stringsProvider).adMessage,
                    ),
                    // Room for the AI button above the bottom bar.
                    const SizedBox(height: 48),
                  ],
                ),
              ),
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
    required this.onSeeAll,
    required this.seeAllLabel,
  });

  final String title;
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
        TextButton(onPressed: onSeeAll, child: Text(seeAllLabel)),
      ],
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
