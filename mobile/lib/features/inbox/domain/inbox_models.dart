class InboxItem {
  const InboxItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  InboxItem copyWith({bool? isRead}) => InboxItem(
        id: id,
        type: type,
        title: title,
        body: body,
        data: data,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );

  factory InboxItem.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return InboxItem(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      data: rawData is Map ? Map<String, dynamic>.from(rawData) : const {},
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }
}

class InboxPage {
  const InboxPage({
    required this.items,
    required this.unreadCount,
    this.nextCursor,
  });

  final List<InboxItem> items;
  final int unreadCount;
  final String? nextCursor;

  factory InboxPage.fromJson(Map<String, dynamic> json) {
    return InboxPage(
      items: (json['items'] as List<dynamic>? ?? [])
          .map((i) => InboxItem.fromJson(i as Map<String, dynamic>))
          .toList(),
      unreadCount: json['unreadCount'] as int? ?? 0,
      nextCursor: json['nextCursor'] as String?,
    );
  }
}

/// Inbox tabs: the user's own updates, their family's, and general notices.
enum InboxTab { personal, family, general }

InboxTab inboxTabFor(InboxItem item) {
  switch (item.type) {
    case 'NOTICE':
      return InboxTab.general;
    case 'MISSED_DOSE_FAMILY_ALERT':
      return InboxTab.family;
    case 'SYSTEM':
      return item.data['kind'] == 'family_invitation' ? InboxTab.family : InboxTab.personal;
    default:
      // MEDICINE_REMINDER, PRESCRIPTION_UPDATE, anything new.
      return InboxTab.personal;
  }
}
