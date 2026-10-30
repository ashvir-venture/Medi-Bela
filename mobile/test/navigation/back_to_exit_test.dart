import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/localization/app_strings.dart';
import 'package:mobile/widgets/double_back_to_exit.dart';
import 'package:mobile/widgets/main_scaffold.dart';

void main() {
  group('press back again to exit', () {
    late DateTime now;
    late int exits;

    Future<void> pump(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'pref_language_code': 'en'});
      now = DateTime(2026, 10, 30, 9);
      exits = 0;
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: DoubleBackToExit(
            clock: () => now,
            onExit: () => exits++,
            child: const Scaffold(body: Text('home')),
          ),
        ),
      ));
    }

    Future<void> back(WidgetTester tester) async {
      await tester.binding.handlePopRoute();
      await tester.pump();
    }

    testWidgets('first back shows the hint and stays; a second within 2 s exits', (tester) async {
      await pump(tester);
      await back(tester);
      expect(find.text(enStrings.pressBackAgainToExit), findsOneWidget);
      expect(exits, 0);
      expect(find.text('home'), findsOneWidget);

      now = now.add(const Duration(milliseconds: 1500));
      await back(tester);
      expect(exits, 1);
    });

    testWidgets('after 2 s it starts over: the next back only shows the hint again', (tester) async {
      await pump(tester);
      await back(tester);
      now = now.add(const Duration(seconds: 3));
      await back(tester);
      expect(exits, 0);
      now = now.add(const Duration(seconds: 1));
      await back(tester);
      expect(exits, 1);
    });
  });

  group('bottom tabs', () {
    test('every screen lives under one tab', () {
      int tab(String location) => tabIndexForLocation(Uri.parse(location));
      expect(tab('/home'), 0);
      expect(tab('/inbox'), 0);
      expect(tab('/assistant/chat'), 0);
      expect(tab('/notices?id=1'), 0);
      expect(tab('/medicines'), 1);
      expect(tab('/medicines?tab=prescriptions'), 1);
      expect(tab('/prescription/confirm/abc'), 1);
      expect(tab('/medicines/form'), 1);
      // A caregiver's view of a member's medicines belongs to Family.
      expect(tab('/medicines?for=u1&name=Rahima'), 2);
      expect(tab('/family/member/u1/prescriptions'), 2);
      expect(tab('/health/records'), 3);
      expect(tab('/diabetes'), 3);
      expect(tab('/profile/settings'), 4);
    });

    test('tab roots go back to Home; pushed screens pop', () {
      bool root(String location) => isTabRoot(Uri.parse(location));
      expect(root('/home'), isTrue);
      expect(root('/medicines?tab=today'), isTrue);
      expect(root('/family'), isTrue);
      expect(root('/health'), isTrue);
      expect(root('/profile'), isTrue);
      expect(root('/medicines?for=u1'), isFalse);
      expect(root('/profile/settings'), isFalse);
      expect(root('/family/member/u1'), isFalse);
    });
  });
}
