import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/localization/app_strings.dart';
import 'package:mobile/features/health/domain/health_models.dart';
import 'package:mobile/features/health/presentation/health_records_screen.dart';
import 'package:mobile/widgets/word_safe_text.dart';

HealthRecordModel _record(String type, String value, String? unit) => HealthRecordModel(
      id: 'r1',
      type: type,
      value: value,
      unit: unit,
      recordedAt: DateTime(2026, 11, 12, 20, 5),
      syncState: 'synced',
    );

void main() {
  group('clock times (client point 12: Bengali had no AM / PM)', () {
    const en = Round18Strings(false);
    const bn = Round18Strings(true);

    test('English uses AM / PM', () {
      expect(en.time(8, 30), '8:30 AM');
      expect(en.time(0, 5), '12:05 AM');
      expect(en.time(12, 0), '12:00 PM');
      expect(en.time(21, 0), '9:00 PM');
    });

    test('Bengali names the part of the day, with Bengali digits', () {
      expect(bn.time(2, 0), 'রাত ২:০০');
      expect(bn.time(5, 15), 'ভোর ৫:১৫');
      expect(bn.time(8, 30), 'সকাল ৮:৩০');
      expect(bn.time(13, 30), 'দুপুর ১:৩০');
      expect(bn.time(16, 0), 'বিকাল ৪:০০');
      expect(bn.time(19, 0), 'সন্ধ্যা ৭:০০');
      expect(bn.time(21, 0), 'রাত ৯:০০');
    });
  });

  test('a reading day reads Today / Yesterday / the date (point 3)', () {
    const en = Round18Strings(false);
    const bn = Round18Strings(true);
    final now = DateTime(2026, 11, 18, 9);
    expect(en.dayLabel(DateTime(2026, 11, 18), now), 'Today');
    expect(en.dayLabel(DateTime(2026, 11, 17), now), 'Yesterday');
    expect(en.dayLabel(DateTime(2026, 11, 12), now), '12 Nov 2026');
    expect(bn.dayLabel(DateTime(2026, 11, 12), now), '১২ নভে ২০২৬');
  });

  group('readings list names each reading (insulin showed as "Other: 6.0 units")', () {
    test('insulin in English and Bengali', () {
      expect(readingTitle(_record('INSULIN', '6.0', 'units'), enStrings), 'Insulin: 6 units');
      expect(readingTitle(_record('INSULIN', '6.0', 'units'), bnStrings), startsWith('ইনসুলিন: ৬ ইউনিট'));
    });

    test('sleep, water and peak flow are named too', () {
      expect(readingTitle(_record('SLEEP', '7.5', 'hours'), enStrings), 'Sleep: 7.5 hours');
      expect(readingTitle(_record('WATER', '6', 'glasses'), enStrings), startsWith('Water'));
      expect(readingTitle(_record('PEAK_FLOW', '380', 'L/min'), enStrings), startsWith('Peak flow'));
    });

    test('whole numbers drop ".0", others keep their decimals', () {
      expect(trimNumber('6.0'), '6');
      expect(trimNumber('7.5'), '7.5');
      expect(trimNumber('120/80'), '120/80');
    });
  });

  group('word-safe text (owner: "Prescriptio / ns")', () {
    const style = TextStyle(fontSize: 13);
    test('text that fits keeps its size', () {
      expect(wordFitScale('Medicine box', style, 200, TextScaler.noScaling), 1);
    });

    testWidgets('a word wider than the room shrinks instead of breaking', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Center(
          child: SizedBox(width: 60, child: WordSafeText('Prescriptions', style: TextStyle(fontSize: 13))),
        ),
      ));
      final text = tester.widget<Text>(find.text('Prescriptions'));
      expect(text.style!.fontSize, lessThan(13));
      // One line: the box is less than two lines tall.
      expect(tester.getSize(find.text('Prescriptions')).height, lessThan(text.style!.fontSize! * 2),
          reason: 'one word must stay on one line');
    });
  });
}
