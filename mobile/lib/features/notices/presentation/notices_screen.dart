import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../providers/core_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../widgets/load_more_list.dart';
import '../../../widgets/state_views.dart';
import '../domain/notice_models.dart';
import 'notices_controller.dart';

class NoticesScreen extends ConsumerWidget {
  const NoticesScreen({super.key, this.highlightId});

  /// Opened from a push or the inbox: this notice is shown first, highlighted.
  final String? highlightId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final noticesAsync = ref.watch(myNoticesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(strings.governmentNotices)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myNoticesProvider),
        child: noticesAsync.when(
          loading: () => const LoadingView(),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 80),
              ErrorView(
                message: friendlyErrorMessage(error),
                retryLabel: strings.retry,
                onRetry: () => ref.invalidate(myNoticesProvider),
              ),
            ],
          ),
          data: (own) {
            // Round 17: a notice shared by my family that my list doesn't have.
            final missing = highlightId != null && !own.any((n) => n.id == highlightId);
            final shared = missing ? ref.watch(sharedNoticeProvider(highlightId!)).valueOrNull : null;
            final notices = [?shared, ...own];
            if (notices.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  EmptyView(message: strings.noNoticesYet, icon: Icons.campaign_outlined),
                ],
              );
            }
            final ordered = [
              ...notices.where((n) => n.id == highlightId),
              ...notices.where((n) => n.id != highlightId),
            ];
            return LoadMoreListView(
              padding: const EdgeInsets.all(16),
              itemCount: ordered.length,
              itemBuilder: (context, index) => _NoticeCard(
                notice: ordered[index],
                highlighted: ordered[index].id == highlightId,
                sourceLabel: strings.noticeSource,
                // Only notices of my own list can be passed on.
                shareLabel: own.any((n) => n.id == ordered[index].id) ? strings.r17.shareWithFamily : null,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Round 17 C: sends the notice to the family's Family inbox and says how it went.
Future<void> shareNoticeWithFamily(BuildContext context, WidgetRef ref, String noticeId) async {
  final s = ref.read(stringsProvider).r17;
  final messenger = ScaffoldMessenger.of(context);
  String message;
  try {
    final r = await ref.read(noticesApiProvider).shareWithFamily(noticeId);
    message = r.alreadyShared ? s.alreadyShared : s.sharedWith(r.sharedWith);
  } on DioException catch (e) {
    message = e.response?.statusCode == 404 ? s.shareNeedsFamily : friendlyErrorMessage(e);
  }
  messenger.showSnackBar(SnackBar(content: Text(message)));
}

class _NoticeCard extends ConsumerStatefulWidget {
  const _NoticeCard({required this.notice, required this.sourceLabel, this.highlighted = false, this.shareLabel});

  final NoticeModel notice;
  final String sourceLabel;
  final bool highlighted;

  /// Null: no Share button (a notice shared with me from another division).
  final String? shareLabel;

  @override
  ConsumerState<_NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends ConsumerState<_NoticeCard> {
  bool _sharing = false;

  NoticeModel get notice => widget.notice;
  String get sourceLabel => widget.sourceLabel;
  bool get highlighted => widget.highlighted;

  Future<void> _share() async {
    setState(() => _sharing = true);
    await shareNoticeWithFamily(context, ref, notice.id);
    if (mounted) setState(() => _sharing = false);
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDate(DateTime d) {
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final period = d.hour < 12 ? 'AM' : 'PM';
    return '${_months[d.month - 1]} ${d.day}, ${d.year} · $hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: highlighted
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: primary, width: 2),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.campaign_outlined, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(notice.title, style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(notice.content, style: Theme.of(context).textTheme.bodyMedium),
            if (notice.source != null && notice.source!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '$sourceLabel: ${notice.source}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
            if (notice.publishedAt != null) ...[
              const SizedBox(height: 10),
              Text(
                _formatDate(notice.publishedAt!.toLocal()),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: context.palette.subtle),
              ),
            ],
            if (widget.shareLabel != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  key: ValueKey('share-notice-${notice.id}'),
                  onPressed: _sharing ? null : _share,
                  icon: const Icon(Icons.family_restroom_outlined),
                  label: Text(widget.shareLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
