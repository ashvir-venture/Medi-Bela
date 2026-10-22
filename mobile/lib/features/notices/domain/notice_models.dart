/// A published, non-expired notice visible to this user (admin/govt
/// announcements). Matches the backend's `Notice` model exactly; only
/// ever fetched already filtered by status/audience/expiry — see
/// `NoticesService.listVisibleTo` — so there's nothing further to filter
/// on the client.
class NoticeModel {
  const NoticeModel({
    required this.id,
    required this.title,
    required this.content,
    required this.publishedAt,
    this.expiresAt,
  });

  final String id;
  final String title;
  final String content;
  final DateTime? publishedAt;
  final DateTime? expiresAt;

  bool get isExpired => expiresAt != null && !expiresAt!.isAfter(DateTime.now());

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'publishedAt': publishedAt?.toUtc().toIso8601String(),
        'expiresAt': expiresAt?.toUtc().toIso8601String(),
      };

  factory NoticeModel.fromJson(Map<String, dynamic> json) {
    return NoticeModel(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      publishedAt:
          json['publishedAt'] == null ? null : DateTime.parse(json['publishedAt'] as String),
      expiresAt:
          json['expiresAt'] == null ? null : DateTime.parse(json['expiresAt'] as String),
    );
  }
}
