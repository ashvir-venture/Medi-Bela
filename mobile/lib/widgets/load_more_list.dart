import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/locale_controller.dart';

/// User lists show 10 rows at a time with a "Load more" button below.
const int userPageSize = 10;

/// A list that shows [pageSize] items, then [pageSize] more per tap on
/// "Load more". For lists already held in memory (local cache or one
/// server call); the inbox pages on the server instead.
class LoadMoreListView extends ConsumerStatefulWidget {
  const LoadMoreListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.separatorBuilder,
    this.padding,
    this.pageSize = userPageSize,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final IndexedWidgetBuilder? separatorBuilder;
  final EdgeInsetsGeometry? padding;
  final int pageSize;

  @override
  ConsumerState<LoadMoreListView> createState() => _LoadMoreListViewState();
}

class _LoadMoreListViewState extends ConsumerState<LoadMoreListView> {
  late int _visible = widget.pageSize;

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final shown = widget.itemCount < _visible ? widget.itemCount : _visible;
    final hasMore = widget.itemCount > shown;

    return ListView.separated(
      // Always scrollable, so pull-to-refresh works on short lists too.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: widget.padding,
      itemCount: shown + (hasMore ? 1 : 0),
      separatorBuilder: (context, index) =>
          widget.separatorBuilder?.call(context, index) ?? const SizedBox.shrink(),
      itemBuilder: (context, index) {
        if (index == shown) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: OutlinedButton(
              onPressed: () => setState(() => _visible += widget.pageSize),
              child: Text(strings.loadMore),
            ),
          );
        }
        return widget.itemBuilder(context, index);
      },
    );
  }
}
