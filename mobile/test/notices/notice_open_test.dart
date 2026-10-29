import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/notices/domain/notice_models.dart';
import 'package:mobile/notifications/push_service.dart';

void main() {
  test('a notice push or inbox entry opens that notice', () {
    expect(routeForNotificationData({'type': 'NOTICE', 'noticeId': 'n1'}), '/notices?id=n1');
    expect(routeForNotificationData({'type': 'NOTICE'}), '/notices');
  });

  test('the source travels with a notice (and through the offline copy)', () {
    final n = NoticeModel.fromJson({
      'id': 'n1',
      'title': 'Dengue alert',
      'content': 'Use nets.',
      'source': 'DGHS',
      'publishedAt': '2026-10-29T06:00:00.000Z',
      'expiresAt': null,
    });
    expect(n.source, 'DGHS');
    expect(NoticeModel.fromJson(n.toJson()).source, 'DGHS');
  });
}
