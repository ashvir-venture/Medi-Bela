import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/localization/app_strings.dart';
import 'package:mobile/core/localization/locale_controller.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/assistant/data/assistant_api.dart';
import 'package:mobile/features/assistant/data/voice_input.dart';
import 'package:mobile/features/assistant/domain/assistant_models.dart';
import 'package:mobile/features/assistant/presentation/assistant_conversations_controller.dart';
import 'package:mobile/features/assistant/presentation/assistant_screen.dart';
import 'package:mobile/features/family/data/family_api.dart';
import 'package:mobile/features/family/domain/family_models.dart';
import 'package:mobile/features/family/presentation/change_history_screen.dart';
import 'package:mobile/features/inbox/domain/inbox_models.dart';
import 'package:mobile/notifications/push_service.dart';
import 'package:mobile/providers/core_providers.dart';
import 'package:mobile/widgets/first_use_tips.dart';

class _FakeVoice implements VoiceInput {
  _FakeVoice(this.result);

  final VoiceStart result;
  void Function(String, bool)? words;
  void Function()? stopped;
  String? locale;

  @override
  Future<VoiceStart> start({
    required String localeId,
    required void Function(String words, bool isFinal) onWords,
    required void Function() onStopped,
  }) async {
    locale = localeId;
    words = onWords;
    stopped = onStopped;
    return result;
  }

  @override
  Future<void> stop() async => stopped?.call();
}

class _FakeAssistantApi extends AssistantApi {
  _FakeAssistantApi() : super(Dio());
  final sent = <String>[];

  @override
  Future<List<AssistantConversationSummary>> listConversations() async => const [];
}

class _FakeFamilyApi extends FamilyApi {
  _FakeFamilyApi() : super(Dio());
  final calls = <(String?, String?)>[];

  @override
  Future<CaregiverChangesPage> listChanges({String? memberUserId, String? cursor}) async {
    calls.add((memberUserId, cursor));
    CaregiverChange c(String id, String action, {bool deleted = false}) => CaregiverChange(
          id: id,
          action: action,
          createdAt: DateTime(2026, 11, 12, 9, 30),
          actor: FamilyEventPerson(id: 'carer', name: 'Rafi', deleted: deleted),
        );
    return cursor == null
        ? CaregiverChangesPage(items: [c('1', 'dose.give'), c('2', 'routine.create', deleted: true)], nextCursor: 'p2')
        : CaregiverChangesPage(items: [c('3', 'user.easy_mode')]);
  }
}

Future<ProviderContainer> pump(WidgetTester tester, Widget child,
    {String lang = 'en', Map<String, Object> prefs = const {}, List<Override> overrides = const []}) async {
  SharedPreferences.setMockInitialValues({'pref_language_code': lang, ...prefs});
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: [
    connectivityStreamProvider.overrideWith((ref) => Stream.value(true)),
    ...overrides,
  ]);
  addTearDown(container.dispose);
  await tester.runAsync(() async {
    container.read(stringsProvider);
    container.read(tipsControllerProvider);
    await Future<void>.delayed(const Duration(milliseconds: 30));
  });
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: AppTheme.light(), home: child),
  ));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  for (final lang in ['en', 'bn']) {
    final s = (lang == 'bn' ? bnStrings : enStrings).r17;

    testWidgets('[$lang] Home tips: Next, Next, Got it, then never again', (tester) async {
      final c = await pump(tester, const FirstUseTips(screen: TipsScreen.home, child: Scaffold(body: Text('home'))),
          lang: lang);
      expect(find.text(s.tipsHome[0].$1), findsOneWidget);
      expect(find.text(s.tipStep(1, 3)), findsOneWidget);
      await tester.tap(find.text(s.tipNext));
      await tester.pump();
      expect(find.text(s.tipsHome[1].$1), findsOneWidget);
      await tester.tap(find.text(s.tipNext));
      await tester.pump();
      expect(find.text(s.tipSkip), findsNothing); // the last tip has only Got it
      await tester.tap(find.text(s.tipDone));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('first-use-tip')), findsNothing);
      expect(c.read(tipsControllerProvider), contains(TipsScreen.home));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('pref_tips_seen_home'), isTrue);
    });

    testWidgets('[$lang] change history: labels, who, deleted caregiver, Load more', (tester) async {
      final api = _FakeFamilyApi();
      await pump(tester, const ChangeHistoryScreen(memberId: 'abba', memberName: 'Rahim'),
          lang: lang, overrides: [familyApiProvider.overrideWithValue(api)]);
      expect(find.text(s.changeLabel('dose.give')), findsOneWidget);
      expect(find.text(s.changeLabel('routine.create')), findsOneWidget);
      expect(find.textContaining(s.byWhom('Rafi')), findsOneWidget);
      final strings = lang == 'bn' ? bnStrings : enStrings;
      expect(find.textContaining(s.byWhom(strings.deletedUser)), findsOneWidget);
      await tester.tap(find.text(strings.loadMore));
      await tester.pumpAndSettle();
      expect(find.text(s.changeLabel('user.easy_mode')), findsOneWidget);
      expect(find.text(strings.loadMore), findsNothing);
      expect(api.calls, [('abba', null), ('abba', 'p2')]);
    });
  }

  testWidgets('Skip marks the tips seen; Show tips again brings them back', (tester) async {
    final c = await pump(tester, const FirstUseTips(screen: TipsScreen.family, child: Scaffold(body: Text('family'))));
    await tester.tap(find.text(enStrings.r17.tipSkip));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('first-use-tip')), findsNothing);
    await tester.runAsync(() => c.read(tipsControllerProvider.notifier).showAgain());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('first-use-tip')), findsOneWidget);
  });

  testWidgets('seen tips and easy mode show nothing; the inline tip shows in the page', (tester) async {
    await pump(
      tester,
      const Scaffold(
        body: Column(children: [
          Expanded(child: FirstUseTips(screen: TipsScreen.health, child: Text('health'))),
          Expanded(child: FirstUseTips(screen: TipsScreen.home, enabled: false, child: Text('easy'))),
          InlineFirstUseTips(screen: TipsScreen.reminder),
        ]),
      ),
      prefs: {'pref_tips_seen_health': true},
    );
    expect(find.text(enStrings.r17.tipsHealth[0].$1), findsNothing);
    expect(find.text(enStrings.r17.tipsHome[0].$1), findsNothing);
    expect(find.text(enStrings.r17.tipsReminder[0].$1), findsOneWidget);
    expect(find.byType(ModalBarrier), findsWidgets); // routes' own barrier only
  });

  testWidgets('[bn] voice: Bengali recognizer, words fill the box, nothing is sent by itself', (tester) async {
    final voice = _FakeVoice(VoiceStart.started);
    final api = _FakeAssistantApi();
    await pump(tester, const AssistantScreen(), lang: 'bn', overrides: [
      voiceInputProvider.overrideWithValue(voice),
      assistantApiProvider.overrideWithValue(api),
    ]);
    final s = bnStrings.r17;
    await tester.enterText(find.byType(TextField), 'নাপা');
    await tester.tap(find.byKey(const ValueKey('assistant-voice')));
    await tester.pump();
    expect(voice.locale, 'bn_BD');
    expect(find.byTooltip(s.stopListening), findsOneWidget);
    voice.words!('কিসের ওষুধ', false);
    await tester.pump();
    expect(find.text('নাপা কিসের ওষুধ'), findsOneWidget);
    voice.stopped!();
    await tester.pump();
    expect(find.text(s.voiceCheck), findsOneWidget);
    expect(find.byTooltip(s.askByVoice), findsOneWidget);
    expect(find.text('নাপা কিসের ওষুধ'), findsOneWidget); // still in the box, not sent
  });

  testWidgets('[en] voice: no microphone permission says how to allow it', (tester) async {
    await pump(tester, const AssistantScreen(), overrides: [
      voiceInputProvider.overrideWithValue(_FakeVoice(VoiceStart.noPermission)),
      assistantApiProvider.overrideWithValue(_FakeAssistantApi()),
    ]);
    await tester.tap(find.byKey(const ValueKey('assistant-voice')));
    await tester.pump();
    expect(find.text(enStrings.r17.voiceNoPermission), findsOneWidget);
    expect(find.byTooltip(enStrings.r17.askByVoice), findsOneWidget);
  });

  test('a shared notice lands in the Family tab and opens that notice', () {
    final item = InboxItem.fromJson({
      'id': 'x',
      'type': 'SYSTEM',
      'title': 'Amma shared a notice',
      'body': 'Dengue alert',
      'data': {'kind': 'notice_shared', 'noticeId': 'n1'},
      'isRead': false,
      'createdAt': '2026-11-12T03:00:00.000Z',
    });
    expect(inboxTabFor(item), InboxTab.family);
    expect(routeForNotificationData({'type': 'SYSTEM', 'kind': 'notice_shared', 'noticeId': 'n1'}), '/notices?id=n1');
  });

  test('every caregiver action has its own line in both languages', () {
    const actions = [
      'prescription.upload', 'prescription.confirm', 'prescription.request_edit', 'routine.create', 'routine.update',
      'routine.remove', 'routine.condition', 'dose.give', 'user.easy_mode', 'personal_reminder.create',
      'personal_reminder.update', 'personal_reminder.remove', 'medicine_box.save', 'health_record.create',
      'care.conditions', 'care.limits', 'care.log', 'care.log_delete', 'care.settings',
      'record.appointment_create', 'record.appointment_update', 'record.appointment_delete', 'record.test_create',
      'record.test_update', 'record.test_delete', 'record.prescription_create', 'record.prescription_update',
      'record.prescription_delete', 'record.photo_add',
    ];
    for (final s in [enStrings.r17, bnStrings.r17]) {
      final fallback = s.changeLabel('something.new');
      for (final a in actions) {
        expect(s.changeLabel(a), isNot(fallback), reason: a);
      }
    }
    expect(enStrings.r17.sharedWith(2), 'Sent to 2 family members.');
    expect(bnStrings.r17.sharedWith(2), 'পরিবারের ২ জনকে পাঠানো হয়েছে।');
  });
}
