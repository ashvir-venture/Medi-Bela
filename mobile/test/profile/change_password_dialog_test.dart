import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/localization/app_strings.dart';
import 'package:mobile/features/profile/presentation/account_dialogs.dart';

void main() {
  // The server, sign-up, password reset and this message all use 6 characters;
  // the change-password dialog used to demand 8.
  testWidgets('change password accepts a 6+ character new password', (tester) async {
    SharedPreferences.setMockInitialValues({'pref_language_code': 'en'});
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showChangePasswordDialog(context),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'oldpass');
    await tester.enterText(fields.at(1), 'abc1234'); // 7 characters
    // A different confirmation keeps the form invalid, so nothing is sent.
    await tester.enterText(fields.at(2), 'different');
    await tester.tap(find.text(enStrings.save));
    await tester.pumpAndSettle();

    expect(find.text(enStrings.passwordTooShort), findsNothing);
    expect(find.text(enStrings.passwordsDoNotMatch), findsOneWidget);

    // 5 characters is still too short.
    await tester.enterText(fields.at(1), 'abc12');
    await tester.tap(find.text(enStrings.save));
    await tester.pumpAndSettle();
    expect(find.text(enStrings.passwordTooShort), findsOneWidget);
  });
}
