import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/inbox/domain/inbox_models.dart';

InboxItem _item(String type, [Map<String, dynamic> data = const {}]) =>
    InboxItem.fromJson({
      'id': 'n1',
      'type': type,
      'title': 't',
      'body': 'b',
      'isRead': false,
      'createdAt': '2026-10-29T08:00:00.000Z',
      'data': data,
    });

void main() {
  test('own updates go to Personal', () {
    expect(inboxTabFor(_item('MEDICINE_REMINDER')), InboxTab.personal);
    expect(inboxTabFor(_item('PRESCRIPTION_UPDATE')), InboxTab.personal);
    expect(inboxTabFor(_item('SYSTEM')), InboxTab.personal);
  });

  test('family alerts and invitations go to Family', () {
    expect(inboxTabFor(_item('MISSED_DOSE_FAMILY_ALERT')), InboxTab.family);
    expect(inboxTabFor(_item('SYSTEM', {'kind': 'family_invitation'})), InboxTab.family);
  });

  test('notices go to General', () {
    expect(inboxTabFor(_item('NOTICE')), InboxTab.general);
  });
}
