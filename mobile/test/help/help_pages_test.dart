import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/localization/app_strings.dart';
import 'package:mobile/features/auth/presentation/register_screen.dart';
import 'package:mobile/features/help/domain/help_content.dart';
import 'package:mobile/features/help/presentation/help_screens.dart';
import 'package:mobile/widgets/not_found_screen.dart';

Widget _app(GoRouter router) => ProviderScope(child: MaterialApp.router(routerConfig: router));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'pref_language_code': 'en'}));

  testWidgets('unknown route: Page not found, and Go to Home leaves it', (tester) async {
    final router = GoRouter(
      initialLocation: '/no/such/page',
      errorBuilder: (context, state) => const NotFoundScreen(),
      routes: [GoRoute(path: '/home', builder: (context, state) => const Text('home page'))],
    );
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    expect(find.text(enStrings.pageNotFound), findsOneWidget);

    await tester.tap(find.text(enStrings.goToHome));
    await tester.pumpAndSettle();
    expect(find.text('home page'), findsOneWidget);
  });

  testWidgets('consent: the box toggles, and the title opens Privacy & terms', (tester) async {
    var ticked = false;
    final router = GoRouter(
      initialLocation: '/register',
      routes: [
        GoRoute(
          path: '/register',
          builder: (context, state) => StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Column(children: [
                TermsConsent(value: ticked, onChanged: (v) => setState(() => ticked = v)),
                ElevatedButton(key: const Key('register'), onPressed: ticked ? () {} : null, child: const Text('Register')),
              ]),
            ),
          ),
        ),
        GoRoute(path: '/help/privacy', builder: (context, state) => const PrivacyTermsScreen()),
      ],
    );
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    ElevatedButton button() => tester.widget<ElevatedButton>(find.byKey(const Key('register')));
    expect(button().onPressed, isNull);
    await tester.tap(find.byKey(const Key('termsCheckbox')));
    await tester.pump();
    expect(ticked, isTrue);
    expect(button().onPressed, isNotNull);

    await tester.tap(find.text(helpContentEn.privacyTitle));
    await tester.pumpAndSettle();
    expect(find.text(helpContentEn.privacySections.first.lines.first), findsOneWidget);
  });

  test('Support numbers: Call and WhatsApp links are right', () {
    expect(supportContacts.map((c) => c.tel), ['tel:+8801810314801', 'tel:+8801763740720']);
    expect(supportContacts.map((c) => c.whatsapp), ['https://wa.me/8801810314801', 'https://wa.me/8801763740720']);
  });

  testWidgets('Support: when nothing can open the call, the number is copied and the user is told', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    final opened = <Uri>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        // Like a phone with no dialer: nothing opens the call.
        externalLauncherProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return false;
        }),
      ],
      child: const MaterialApp(home: SupportScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text(helpContentEn.callLabel).first);
    await tester.pumpAndSettle();
    expect(opened.single.toString(), 'tel:+8801810314801');
    expect(copied, '+8801810314801');
    expect(find.text(enStrings.couldNotOpenLink), findsOneWidget);
  });

  testWidgets('Support on a phone: Call is a full row, WhatsApp and Copy share the next row equally', (tester) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: SupportScreen())));
    await tester.pumpAndSettle();

    Rect box(String label) => tester.getRect(
          find.ancestor(of: find.text(label).first, matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)).first,
        );
    final call = box(helpContentEn.callLabel);
    final whatsapp = box(helpContentEn.whatsappLabel);
    final copy = box(helpContentEn.copyLabel);

    expect(tester.widget(find.ancestor(of: find.text(helpContentEn.callLabel).first, matching: find.byType(FilledButton)).first),
        isA<FilledButton>()); // keeps its highlighted colour
    expect(whatsapp.top, greaterThan(call.bottom - 1)); // below Call
    expect(copy.top, whatsapp.top); // same row
    expect(whatsapp.width, closeTo(copy.width, 0.5));
    expect(call.width, closeTo(copy.right - whatsapp.left, 0.5)); // as wide as both together
  });

  testWidgets('About us shows both team members in Bengali', (tester) async {
    SharedPreferences.setMockInitialValues({'pref_language_code': 'bn'});
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: AboutUsScreen())));
    await tester.pumpAndSettle();
    expect(find.text('আশরাফুল আলম'), findsOneWidget);
    expect(find.text('তানভীর হোসেন'), findsOneWidget);
    expect(find.text(helpContentBn.mission), findsOneWidget);
  });
}
