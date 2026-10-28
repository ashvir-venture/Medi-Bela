import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../notifications/push_service.dart';
import '../../../widgets/state_views.dart';
import '../domain/inbox_models.dart';
import 'inbox_controller.dart';

class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final state = ref.watch(inboxControllerProvider);
    final controller = ref.read(inboxControllerProvider.notifier);

    Widget listFor(InboxTab tab) {
      final items = state.items.where((i) => inboxTabFor(i) == tab).toList();
      if (state.isLoading && state.items.isEmpty) return const LoadingView();
      if (state.error != null && state.items.isEmpty) {
        return ListView(children: [
          ErrorView(
            message: state.error!,
            retryLabel: strings.retry,
            onRetry: controller.load,
          ),
        ]);
      }
      // Tabs filter the pages loaded so far, so "Load more" stays available
      // even when this tab is still empty.
      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: (items.isEmpty ? 1 : items.length) + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (items.isEmpty && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(top: 48),
              child: EmptyView(
                message: strings.noNotificationsYet,
                icon: Icons.notifications_none,
              ),
            );
          }
          if (index == (items.isEmpty ? 1 : items.length)) {
            return Center(
              child: state.isLoadingMore
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    )
                  : TextButton(
                      onPressed: controller.loadMore,
                      child: Text(strings.loadMore),
                    ),
            );
          }
          final item = items[index];
          return _InboxTile(
            item: item,
            onTap: () {
              controller.markRead(item.id);
              context.go(routeForNotificationData({...item.data, 'type': item.type}));
            },
          );
        },
      );
    }

    return DefaultTabController(
      length: InboxTab.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings.notifications),
          actions: [
            if (state.unreadCount > 0)
              TextButton(
                onPressed: controller.markAllRead,
                child: Text(strings.markAllRead),
              ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: strings.inboxPersonalTab),
              Tab(text: strings.inboxFamilyTab),
              Tab(text: strings.inboxGeneralTab),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final tab in InboxTab.values)
              RefreshIndicator(onRefresh: controller.load, child: listFor(tab)),
          ],
        ),
      ),
    );
  }
}

class _InboxTile extends StatelessWidget {
  const _InboxTile({required this.item, required this.onTap});

  final InboxItem item;
  final VoidCallback onTap;

  IconData get _icon {
    switch (item.type) {
      case 'MISSED_DOSE_FAMILY_ALERT':
        return Icons.medication_outlined;
      case 'PRESCRIPTION_UPDATE':
        return Icons.description_outlined;
      case 'NOTICE':
        return Icons.campaign_outlined;
      case 'MEDICINE_REMINDER':
        return Icons.alarm_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(_icon, color: theme.colorScheme.primary),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            fontWeight: item.isRead ? FontWeight.normal : FontWeight.w700,
          ),
        ),
        subtitle: Text(item.body, maxLines: 3, overflow: TextOverflow.ellipsis),
        trailing: item.isRead
            ? null
            : Icon(Icons.circle, size: 10, color: theme.colorScheme.primary),
      ),
    );
  }
}
