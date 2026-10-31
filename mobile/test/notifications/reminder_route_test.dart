import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/health/domain/health_models.dart';
import 'package:mobile/notifications/push_service.dart';

// Owner, 2026-10-31: tapping a reminder (not its buttons) opens its own page.
void main() {
  test('a local medicine reminder opens its reminder page with its stage', () {
    expect(
      routeForNotificationData({'type': 'MEDICINE_REMINDER', 'at': 1761876000000, 'stage': 2}),
      '/reminder?at=1761876000000&stage=2',
    );
  });

  test("the server's backstop opens the same page as stage 1", () {
    final route = routeForNotificationData({
      'type': 'MEDICINE_REMINDER',
      'kind': 'backstop',
      'scheduledAt': '2026-10-31T02:00:00.000Z',
    });
    expect(route, '/reminder?at=${DateTime.utc(2026, 10, 31, 2).millisecondsSinceEpoch}&stage=1');
  });

  test('a test reminder opens the test page on its day', () {
    expect(
      routeForNotificationData({'type': 'TEST_REMINDER', 'reminderId': 'h1', 'day': 1}),
      '/test-reminder/h1?day=1',
    );
  });

  test('a test reminder: Done only from its time; day 1-3', () {
    final at = DateTime(2026, 11, 3, 8);
    final r = HealthReminderModel(id: 'h1', title: 'CBC', scheduledAt: at, status: 'PENDING', kind: 'TEST');
    expect(r.canCompleteAt(DateTime(2026, 11, 3, 7)), isFalse);
    expect(r.canCompleteAt(DateTime(2026, 11, 3, 8)), isTrue);
    expect(r.testDayAt(DateTime(2026, 11, 3, 7)), isNull);
    expect(r.testDayAt(DateTime(2026, 11, 4, 9)), 2);
    expect(r.testDayAt(DateTime(2026, 11, 9)), 3);
    expect(HealthReminderModel.fromJson({
      'id': 'h1',
      'title': 'CBC',
      'scheduledAt': '2026-11-03T02:00:00.000Z',
      'status': 'PENDING',
      'kind': 'TEST',
      'mealTiming': {'id': 1, 'name': 'Before meal'},
    }).mealTiming, 'Before meal');
  });

  // Round 13: a ringing reminder opens as a full screen that only its buttons close.
  test('ringing reminders open in alarm mode; other notifications have no full screen', () {
    expect(
      alarmRouteForPayload('{"type":"MEDICINE_REMINDER","at":1761876000000,"stage":0}'),
      '/reminder?at=1761876000000&stage=0&alarm=1',
    );
    expect(alarmRouteForPayload('{"type":"TEST_REMINDER","reminderId":"h1","day":2}'), '/test-reminder/h1?day=2&alarm=1');
    expect(alarmRouteForPayload('{"type":"NOTICE","noticeId":"n1"}'), isNull);
    expect(alarmRouteForPayload(null), isNull);
  });
}
