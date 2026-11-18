import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/medicine_schedule/data/pill_looks.dart';
import 'package:mobile/features/medicine_schedule/domain/medicine_schedule_models.dart';
import 'package:mobile/notifications/local_notifications_gateway.dart' show reminderColor;
import 'package:mobile/widgets/notification_tone.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owner 2026-11-18: each kind of notification its own colour; the strip
/// colour next to the medicine on reminder pages, also offline.
void main() {
  test('kinds: data.kind wins over type', () {
    expect(noteKindOf('MEDICINE_REMINDER'), NoteKind.medicine);
    expect(noteKindOf('MISSED_DOSE_FAMILY_ALERT'), NoteKind.family);
    expect(noteKindOf('SYSTEM', {'kind': 'reading_alert'}), NoteKind.urgent);
    expect(noteKindOf('SYSTEM', {'kind': 'caregiver_action'}), NoteKind.change);
    expect(noteKindOf('MISSED_DOSE_FAMILY_ALERT', {'kind': 'medicine_box_empty'}), NoteKind.box);
    expect(noteKindOf('TEST_REMINDER'), NoteKind.test);
    expect(noteKindOf('SOMETHING_NEW'), NoteKind.other);
  });

  test('a local reminder takes its colour from the payload type', () {
    expect(reminderColor(jsonEncode({'type': 'MEDICINE_REMINDER'})), noteAndroidColor(NoteKind.medicine));
    expect(reminderColor(jsonEncode({'type': 'TEST_REMINDER'})), noteAndroidColor(NoteKind.test));
    expect(reminderColor('not json'), noteAndroidColor(NoteKind.other));
    expect(noteAndroidColor(NoteKind.urgent), isNot(noteAndroidColor(NoteKind.medicine)));
  });

  test('pill looks survive on the phone and follow the own list', () async {
    SharedPreferences.setMockInitialValues({});
    ManagedRoutine routine(String id, String? color) => ManagedRoutine.fromJson({
          'id': id,
          'medicineName': 'X',
          'dosage': '1',
          'frequency': 'Once a day',
          'scheduleTimes': ['08:00'],
          'startDate': '2026-11-18',
          'pillColor': color,
          'pillShape': color == null ? null : 'round',
          'form': {'name': 'Tablet'},
        });
    await PillLooks.save([routine('r1', 'y'), routine('r2', null)]);
    var looks = await PillLooks.load();
    expect(looks['r1']?.color, 'y');
    expect(looks['r1']?.shape, 'round');
    expect(looks['r2']?.color, isNull);
    expect(looks['r2']?.formName, 'Tablet');
    await PillLooks.save([routine('r2', 'r')]);
    looks = await PillLooks.load();
    expect(looks.containsKey('r1'), isFalse);
    expect(looks['r2']?.color, 'r');
  });
}
