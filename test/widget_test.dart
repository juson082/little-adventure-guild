import 'package:little_adventure_guild/guild_content.dart';
import 'package:little_adventure_guild/guild_decorations.dart';
import 'package:little_adventure_guild/hard_quests.dart';
import 'dart:convert';
import 'package:little_adventure_guild/translations.dart';
import 'package:little_adventure_guild/greeting_translations.dart';
import 'package:little_adventure_guild/quest_feedback.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:little_adventure_guild/main.dart';

Future<void> dismissGreeting(WidgetTester tester) async {
  final dialogue = find.byType(GuildDialogueText);
  if (dialogue.evaluate().isEmpty) return;
  await tester.tap(dialogue);
  await tester.pump();
  if (dialogue.evaluate().isNotEmpty) {
    await tester.tap(dialogue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
  await tester.pumpAndSettle();
}

void main() {
  test('퀘스트 결과 대사는 모든 언어에 다섯 개씩 있다', () {
    for (final language in ['ko', 'en', 'ja', 'zh', 'hi', 'es']) {
      expect(questSuccessMessages[language], hasLength(5));
      expect(questFailureMessages[language], hasLength(5));
      expect(
          questSuccessMessages[language]!.every((s) => s.isNotEmpty), isTrue);
      expect(
          questFailureMessages[language]!.every((s) => s.isNotEmpty), isTrue);
    }
  });
  testWidgets('퀘스트를 열고 완료한 상태가 다시 열어도 유지된다', (tester) async {
    const audio = MethodChannel('hvildir/sound_effects');
    final playedSounds = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audio, (call) async {
      if (call.method == 'play') playedSounds.add(call.arguments as String);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audio, null));
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues({
      'tutorial_complete': true,
      'language_override': 'ko',
      'today': jsonEncode({
        'date': date,
        'quest': 0,
        'catalogVersion': 1,
        'opened': false,
        'completed': false
      }),
    });
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('openQuest')), findsNothing);
    await dismissGreeting(tester);
    expect(find.byKey(const ValueKey('openQuest')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('openQuest')));
    await tester.pumpAndSettle();
    final tappedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
    await tester.tap(find.byKey(const ValueKey('openQuest')));
    await tester.pump();
    expect(playedSounds, ['reveal_normal']);
    expect(find.byType(QuestDocument), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(QuestDocument), findsNothing);
    await tester.pumpAndSettle();
    final opened =
        jsonDecode((await SharedPreferences.getInstance()).getString('today')!)
            as Map;
    expect(opened['opened_at_ms'], greaterThanOrEqualTo(tappedAt));
    expect(opened['opened_at_ms'],
        lessThanOrEqualTo(DateTime.now().toUtc().millisecondsSinceEpoch));
    await tester.tap(find.byKey(const ValueKey('closeQuest')));
    await tester.pump();
    expect(find.byType(QuestDocument), findsNothing);
    await tester.tap(find.byKey(const ValueKey('openQuest')));
    await tester.pump();
    expect(find.byType(QuestDocument), findsOneWidget);
    expect(playedSounds, ['reveal_normal']);
    expect(
        jsonDecode((await SharedPreferences.getInstance()).getString('today')!)[
            'opened_at_ms'],
        opened['opened_at_ms']);
    expect(find.text('퀘스트 완료'), findsOneWidget);
    await tester.ensureVisible(find.text('퀘스트 완료'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('퀘스트 완료'));
    await tester.pumpAndSettle();
    expect(
        find.byWidgetPredicate((w) =>
            w is GuildDialogueText &&
            questSuccessMessages['ko']!.contains(w.text)),
        findsOneWidget);
    expect(
        (jsonDecode((await SharedPreferences.getInstance()).getString('today')!)
            as Map)['gold'],
        10);
    await tester.pumpWidget(const GuildApp(key: ValueKey('restart')));
    await tester.pumpAndSettle();
    await dismissGreeting(tester);
    expect(find.text('퀘스트 완료'), findsNothing);
    expect(find.byKey(const ValueKey('openQuest')), findsNothing);
  });
  testWidgets('어려운 의뢰를 처음 열 때만 어려운 의뢰 효과음이 재생된다', (tester) async {
    const audio = MethodChannel('hvildir/sound_effects');
    final playedSounds = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audio, (call) async {
      if (call.method == 'play') playedSounds.add(call.arguments as String);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audio, null));
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues({
      'tutorial_complete': true,
      'language_override': 'ko',
      'last_greeting_date': date,
      'today': jsonEncode({
        'date': date,
        'quest': quests.length,
        'catalogVersion': 1,
        'opened': false,
        'completed': false,
      }),
    });
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('openQuest')));
    await tester.pump();
    expect(playedSounds, ['reveal_hard']);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('closeQuest')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('openQuest')));
    await tester.pump();
    expect(playedSounds, ['reveal_hard']);
  });
  testWidgets('길드 메뉴에서 안내를 열고 닫는다', (tester) async {
    SharedPreferences.setMockInitialValues(
        {'tutorial_complete': true, 'language_override': 'ko'});
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('길드 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('길드 지원하기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('작은 보급품'), findsOneWidget);
    await tester.tap(find.byType(PixelCloseButton).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('길드 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('의뢰 제안하기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('의뢰 접수는 준비 중'), findsOneWidget);
  });
  testWidgets('완료 골드로 장식을 사고 다시 실행해도 유지된다', (tester) async {
    final d = DateTime.now();
    final date =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues({
      'tutorial_complete': true,
      'language_override': 'ko',
      'today':
          '{"date":"$date","quest":0,"opened":true,"completed":false,"gold":140}'
    });
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    await dismissGreeting(tester);
    await tester.ensureVisible(find.text('퀘스트 완료'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('퀘스트 완료'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('보유 골드'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('별의 수호검 · 150 G'));
    await tester.pumpAndSettle();
    expect(find.text('별의 수호검 · 치우기'), findsOneWidget);
    expect(find.text('보유 골드  0 G'), findsOneWidget);
    await tester.ensureVisible(find.byType(PixelCloseButton).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PixelCloseButton).last);
    await tester.pumpAndSettle();
    await tester
        .pumpWidget(const GuildApp(key: ValueKey('restart decorations')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('보유 골드'));
    await tester.pumpAndSettle();
    expect(find.text('별의 수호검 · 치우기'), findsOneWidget);
    expect(find.text('보유 골드  0 G'), findsOneWidget);
  });
  testWidgets('실패를 선택해도 골드가 차감되지 않는다', (tester) async {
    final d = DateTime.now();
    final date =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues({
      'tutorial_complete': true,
      'language_override': 'ko',
      'today':
          '{"date":"$date","quest":0,"opened":true,"completed":false,"gold":20}'
    });
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    await dismissGreeting(tester);
    await tester.ensureVisible(find.text('퀘스트 실패'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('퀘스트 실패'));
    await tester.pumpAndSettle();
    expect(
        find.byWidgetPredicate((w) =>
            w is GuildDialogueText &&
            questFailureMessages['ko']!.contains(w.text)),
        findsOneWidget);
    expect(
        (jsonDecode((await SharedPreferences.getInstance()).getString('today')!)
            as Map)['gold'],
        20);
  });
  testWidgets('첫 실행에 길드주인의 안내가 나오고 완료 후 다시 나오지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues({'language_override': 'ko'});
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    expect(
        tester.widget<GuildDialogueText>(find.byType(GuildDialogueText)).text,
        contains('리얼 월드에서 메인 퀘스트'));
    expect(find.byKey(const ValueKey('openQuest')), findsNothing);
    for (var i = 0; i < guildTutorial.length; i++) {
      await tester.tap(find.byType(GuildDialogueText));
      await tester.pump();
      await tester.tap(find.byType(GuildDialogueText));
      await tester.pump();
      if (i == tutorialPauseAfterStep) {
        expect(find.text('?'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
      }
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const ValueKey('openQuest')), findsOneWidget);
    await tester.pumpWidget(const GuildApp(key: ValueKey('tutorial restart')));
    await tester.pumpAndSettle();
    expect(find.byType(GuildDialogueText), findsNothing);
    expect(find.byKey(const ValueKey('openQuest')), findsOneWidget);
  });
  testWidgets('지원하지 않는 기기 언어는 영어로 표시한다', (tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('fr');
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
    SharedPreferences.setMockInitialValues({'tutorial_complete': true});
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    expect(
        Localizations.localeOf(tester.element(find.byType(GuildHome)))
            .languageCode,
        'en');
  });
  testWidgets('언어를 바꾸면 저장되고 기기 설정으로 되돌릴 수 있다', (tester) async {
    tester.binding.platformDispatcher.localesTestValue = [const Locale('ko')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    tester.binding.platformDispatcher.localeTestValue = const Locale('ko');
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
    SharedPreferences.setMockInitialValues({'tutorial_complete': true});
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    expect(
        Localizations.localeOf(tester.element(find.byType(GuildHome)))
            .languageCode,
        'ko');
    await tester.tap(find.byTooltip('길드 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('languageSelector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日本語').last);
    await tester.pumpAndSettle();
    expect(
        Localizations.localeOf(tester.element(find.byType(GuildHome)))
            .languageCode,
        'ja');
    await tester.pumpWidget(const GuildApp(key: ValueKey('language restart')));
    await tester.pumpAndSettle();
    expect(
        Localizations.localeOf(tester.element(find.byType(GuildHome)))
            .languageCode,
        'ja');
    await tester.tap(find.byTooltip('ギルドメニュー'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('languageSelector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('端末の設定に従う').last);
    await tester.pumpAndSettle();
    expect(
        Localizations.localeOf(tester.element(find.byType(GuildHome)))
            .languageCode,
        'ko');
  });
  testWidgets('기기 언어 목록이 비어 있으면 영어를 사용한다', (tester) async {
    tester.binding.platformDispatcher.localesTestValue = [];
    tester.binding.platformDispatcher.localeTestValue = const Locale('ko');
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
    SharedPreferences.setMockInitialValues({'tutorial_complete': true});
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    expect(
        find.byWidgetPredicate((w) =>
            w is GuildDialogueText &&
            greetingTranslations['en']!.values.contains(w.text)),
        findsOneWidget);
  });
  test('인사와 튜토리얼에 각 언어 번역이 있다', () {
    final content = [
      ...guildGreetings,
      ...guildTutorial,
    ];
    for (final language in ['en', 'ja', 'zh', 'hi', 'es']) {
      for (final source in content) {
        expect(translate(language, source), isNot(source),
            reason: '$language: $source');
      }
    }
  });
  test('퀘스트 목록이 완성되어 있고 제목에 표시용 번호가 없다', () {
    expect(quests.length, 303);
    expect(quests.map((q) => q.$1).toSet().length, quests.length);
    for (final quest in quests) {
      expect(quest.$1, isNotEmpty);
      expect(quest.$2, isNotEmpty);
      expect(RegExp(r'^\s*\d+[.)]\s').hasMatch(quest.$1), isFalse);
    }
  });
  testWidgets('기존에 받은 오늘의 퀘스트가 목록 교체 후에도 유지된다', (tester) async {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues({
      'tutorial_complete': true,
      'language_override': 'ko',
      'today': '{"date":"$date","quest":0,"opened":true,"completed":false}',
    });
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    await dismissGreeting(tester);
    expect(find.text('잠시 하늘을 올려다보기'), findsOneWidget);
    await tester.pumpWidget(const GuildApp(key: ValueKey('legacy restart')));
    await tester.pumpAndSettle();
    await dismissGreeting(tester);
    expect(find.text('잠시 하늘을 올려다보기'), findsOneWidget);
  });
  for (final (code, _) in [
    ('zh', '欢迎回来！'),
    ('hi', 'अरे, आ गए तुम!'),
    ('es', '¡Qué bueno verte!'),
  ]) {
    testWidgets('$code 기기 언어로 인사와 UI가 표시된다', (tester) async {
      tester.binding.platformDispatcher.localeTestValue = Locale(code);
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
      SharedPreferences.setMockInitialValues({'tutorial_complete': true});
      await tester.pumpWidget(const GuildApp());
      await tester.pumpAndSettle();
      expect(
          find.byWidgetPredicate((w) =>
              w is GuildDialogueText &&
              greetingTranslations[code]!.values.contains(w.text)),
          findsOneWidget);
      await dismissGreeting(tester);
      expect(find.byKey(const ValueKey('openQuest')), findsOneWidget);
    });
  }
  testWidgets('튜토리얼 중 언어를 바꾸면 대사가 바뀌고 설정이 유지된다', (tester) async {
    SharedPreferences.setMockInitialValues({'language_override': 'ko'});
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('길드 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('languageSelector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Español').last);
    await tester.pumpAndSettle();
    expect(
        tester.widget<GuildDialogueText>(find.byType(GuildDialogueText)).text,
        contains('misión principal en el mundo real'));
    await tester.pumpWidget(const GuildApp(key: ValueKey('spanish restart')));
    await tester.pumpAndSettle();
    expect(
        tester.widget<GuildDialogueText>(find.byType(GuildDialogueText)).text,
        contains('misión principal en el mundo real'));
  });
  testWidgets('골드 버튼으로 길드 꾸미기를 연다', (tester) async {
    SharedPreferences.setMockInitialValues(
        {'tutorial_complete': true, 'language_override': 'ko'});
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    expect(find.text('작은 모험 길드'), findsNothing);
    await tester.tap(find.byTooltip('보유 골드'));
    await tester.pumpAndSettle();
    expect(find.text('길드 꾸미기'), findsOneWidget);
  });

  test('어려운 의뢰 20개는 모든 지원 언어에 번역된다', () {
    expect(hardQuests.length, 20);
    for (final language in ['en', 'ja', 'zh', 'hi', 'es']) {
      for (final quest in hardQuests) {
        expect(translate(language, quest.$1), isNot(quest.$1));
        expect(translate(language, quest.$2), isNot(quest.$2));
      }
    }
  });
  for (final complete in [true, false]) {
    testWidgets(complete ? '어려운 의뢰 성공은 30골드를 준다' : '어려운 의뢰 실패는 보상이 없다',
        (tester) async {
      final now = DateTime.now();
      final date =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      SharedPreferences.setMockInitialValues({
        'tutorial_complete': true,
        'language_override': 'ko',
        'last_greeting_date': date,
        'today': jsonEncode({
          'date': date,
          'quest': quests.length,
          'catalogVersion': 1,
          'opened': true,
          'completed': false,
          'gold': 5
        }),
      });
      await tester.pumpWidget(const GuildApp());
      await tester.pumpAndSettle();
      expect(find.text(hardQuests.first.$1), findsOneWidget);
      expect(find.textContaining('30 G'), findsWidgets);
      expect(find.text('특별 의뢰'), findsNothing);
      final action = find.text(complete ? '퀘스트 완료' : '퀘스트 실패');
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      final saved =
          jsonDecode(prefs.getString('today')!) as Map<String, dynamic>;
      expect(saved['gold'], complete ? 35 : 5);
      expect(saved[complete ? 'completed' : 'failed'], isTrue);
    });
  }

  testWidgets('동전 연출이 끝난 뒤에만 골드를 지급한다', (tester) async {
    const channel = MethodChannel('hvildir/sound_effects');
    final sounds = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'play') sounds.add(call.arguments as String);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues({
      'tutorial_complete': true,
      'language_override': 'ko',
      'last_greeting_date': date,
      'today': jsonEncode({
        'date': date,
        'quest': 0,
        'catalogVersion': 1,
        'opened': true,
        'completed': false,
        'gold': 5
      }),
    });
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    final complete = find.text('퀘스트 완료');
    await tester.ensureVisible(complete);
    await tester.pumpAndSettle();
    await tester.tap(complete);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));
    final store = await SharedPreferences.getInstance();
    Map state() => jsonDecode(store.getString('today')!) as Map;
    expect(state()['gold'], 5);
    expect(state()['completed'], isFalse);
    expect(find.byType(RewardFlight), findsOneWidget);
    expect(sounds, ['wood', 'gold']);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(state()['gold'], 15);
    expect(state()['completed'], isTrue);
  });

  test('장식 10개는 각 언어로 번역되고 동일 가격을 사용한다', () {
    expect(guildDecorations.length, 10);
    expect(guildDecorations.map((d) => d.id).toSet().length, 10);
    expect(decorationPrice, 150);
    for (final locale in ['en', 'ja', 'zh', 'hi', 'es']) {
      for (final item in guildDecorations) {
        expect(decorationName(locale, item), isNotEmpty);
        expect(decorationName(locale, item), isNot(item.name));
      }
    }
  });
  testWidgets('같은 위치 장식은 교체되고 다른 위치는 유지된다', (tester) async {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues({
      'tutorial_complete': true,
      'language_override': 'ko',
      'last_greeting_date': date,
      'today': jsonEncode({
        'date': date,
        'quest': 0,
        'catalogVersion': 1,
        'opened': false,
        'completed': false,
        'gold': 0,
        'unlocked': ['sigil', 'banner_dragon', 'crystal'],
        'active_items': ['sigil', 'crystal']
      }),
    });
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('보유 골드'));
    await tester.pumpAndSettle();
    final banner = find.text('용의 날개 깃발 · 놓기');
    await tester.ensureVisible(banner);
    await tester.pumpAndSettle();
    await tester.tap(banner);
    await tester.pumpAndSettle();
    final store = await SharedPreferences.getInstance();
    Map state() => jsonDecode(store.getString('today')!) as Map;
    expect(state()['active_items'], containsAll(['banner_dragon', 'crystal']));
    expect(state()['active_items'], isNot(contains('sigil')));
    expect(state()['gold'], 0);
    final off = find.text('용의 날개 깃발 · 치우기');
    await tester.ensureVisible(off);
    await tester.pumpAndSettle();
    await tester.tap(off);
    await tester.pumpAndSettle();
    expect(state()['active_items'], ['crystal']);
  });
  testWidgets('날짜가 바뀌어도 구매와 장식 상태가 유지된다', (tester) async {
    final old = DateTime.now().subtract(const Duration(days: 1));
    final yesterday =
        '${old.year}-${old.month.toString().padLeft(2, '0')}-${old.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues({
      'tutorial_complete': true,
      'today': jsonEncode({
        'date': yesterday,
        'quest': 0,
        'catalogVersion': 1,
        'opened': true,
        'opened_at_ms': DateTime.now()
            .subtract(const Duration(hours: 25))
            .toUtc()
            .millisecondsSinceEpoch,
        'gold': 73,
        'unlocked': ['sword', 'crystal'],
        'active_items': ['sword', 'crystal']
      }),
    });
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    final store = await SharedPreferences.getInstance();
    final saved = jsonDecode(store.getString('today')!) as Map;
    expect(saved['gold'], 73);
    expect(saved['unlocked'], ['sword', 'crystal']);
    expect(saved['active_items'], ['sword', 'crystal']);
    expect(saved['opened'], isFalse);
  });

  testWidgets('열지 않은 오래된 의뢰는 바뀌고 열린 의뢰는 24시간 유지된다', (tester) async {
    final now = DateTime.now();
    final oldDate =
        '${now.subtract(const Duration(days: 2)).year}-${now.subtract(const Duration(days: 2)).month.toString().padLeft(2, '0')}-${now.subtract(const Duration(days: 2)).day.toString().padLeft(2, '0')}';
    for (final opened in [false, true]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      SharedPreferences.setMockInitialValues({
        'tutorial_complete': true,
        'today': jsonEncode({
          'date': oldDate,
          'quest': 7,
          'catalogVersion': 1,
          'opened': opened,
          if (opened)
            'opened_at_ms': now
                .subtract(const Duration(hours: 23))
                .toUtc()
                .millisecondsSinceEpoch
        })
      });
      await tester.pumpWidget(GuildApp(key: ValueKey('kept-$opened')));
      await tester.pumpAndSettle();
      final store = await SharedPreferences.getInstance();
      final saved = jsonDecode(store.getString('today')!) as Map;
      if (opened) {
        expect(saved['quest'], 7);
      } else {
        expect(saved['quest'], isNot(7));
      }
      expect(saved['opened'], opened);
    }
  });
  testWidgets('예전 열린 의뢰는 이전 시각이 없어도 보존하고 기준 시각을 기록한다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'tutorial_complete': true,
      'today': jsonEncode({
        'date': '2020-01-01',
        'quest': 7,
        'catalogVersion': 1,
        'opened': true
      })
    });
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    final store = await SharedPreferences.getInstance();
    final saved = jsonDecode(store.getString('today')!) as Map;
    expect(saved['quest'], 7);
    expect(saved['opened'], isTrue);
    expect(saved['opened_at_ms'], isA<int>());
  });

  testWidgets('새 날짜의 인사는 남은 24시간 의뢰와 별도로 표시된다', (tester) async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final oldDate =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues({
      'tutorial_complete': true,
      'language_override': 'ko',
      'last_visit_date': oldDate,
      'last_greeting_date': oldDate,
      'today': jsonEncode({
        'date': oldDate,
        'quest': 7,
        'catalogVersion': 1,
        'opened': true,
        'opened_at_ms': now
            .subtract(const Duration(hours: 2))
            .toUtc()
            .millisecondsSinceEpoch,
      }),
    });
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    expect(
        find.byWidgetPredicate(
            (w) => w is GuildDialogueText && guildGreetings.contains(w.text)),
        findsOneWidget);
    final store = await SharedPreferences.getInstance();
    final saved = jsonDecode(store.getString('today')!) as Map;
    expect(saved['quest'], 7);
    expect(saved['opened'], isTrue);
  });
}
