import 'package:little_adventure_guild/guild_content.dart';
import 'package:little_adventure_guild/translations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:little_adventure_guild/main.dart';

void main() {
  testWidgets('퀘스트를 열고 완료한 상태가 다시 열어도 유지된다', (tester) async {
    SharedPreferences.setMockInitialValues(
        {'tutorial_complete': true, 'language_override': 'ko'});
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    expect(find.text('양피지 열기'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('양피지 열기'), findsOneWidget);
    await tester.ensureVisible(find.text('양피지 열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('양피지 열기'));
    await tester.pumpAndSettle();
    expect(find.text('퀘스트 완료'), findsOneWidget);
    await tester.ensureVisible(find.text('퀘스트 완료'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('퀘스트 완료'));
    await tester.pumpAndSettle();
    expect(find.text('퀘스트 완료'), findsOneWidget);
    expect(find.text('10 G'), findsOneWidget);
    await tester.pumpWidget(const GuildApp(key: ValueKey('restart')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('퀘스트 완료'), findsOneWidget);
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
    expect(find.text('작은 보급품'), findsOneWidget);
    await tester.tap(find.text('돌아가기'));
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
      'today': '{"date":"$date","quest":0,"opened":true,"completed":false}'
    });
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('퀘스트 완료'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('퀘스트 완료'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 900));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('길드 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('길드 꾸미기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('작은 화분 · 10 G'));
    await tester.pumpAndSettle();
    expect(find.text('작은 화분 · 치우기'), findsOneWidget);
    expect(find.text('보유 골드  0 G'), findsOneWidget);
    await tester.tap(find.text('돌아가기'));
    await tester.pumpAndSettle();
    await tester
        .pumpWidget(const GuildApp(key: ValueKey('restart decorations')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('길드 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('길드 꾸미기'));
    await tester.pumpAndSettle();
    expect(find.text('작은 화분 · 치우기'), findsOneWidget);
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
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('퀘스트 실패'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('퀘스트 실패'));
    await tester.pumpAndSettle();
    expect(find.text('퀘스트 실패'), findsOneWidget);
    expect(find.text('20 G'), findsOneWidget);
  });
  testWidgets('첫 실행에 길드주인의 안내가 나오고 완료 후 다시 나오지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues({'language_override': 'ko'});
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('새로운 모험가로구나'), findsOneWidget);
    expect(find.text('양피지 열기'), findsNothing);
    for (var i = 0; i < 5; i++) {
      await tester.ensureVisible(find.text('다음 이야기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음 이야기'));
      await tester.pumpAndSettle();
    }
    expect(find.text('모험 시작하기'), findsOneWidget);
    await tester.ensureVisible(find.text('모험 시작하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('모험 시작하기'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('양피지 열기'), findsOneWidget);
    await tester.pumpWidget(const GuildApp(key: ValueKey('tutorial restart')));
    await tester.pumpAndSettle();
    expect(find.text('다음 이야기'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('양피지 열기'), findsOneWidget);
  });
  testWidgets('지원하지 않는 기기 언어는 영어로 표시한다', (tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('fr');
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
    SharedPreferences.setMockInitialValues({'tutorial_complete': true});
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    expect(find.text('Little Adventure Guild'), findsOneWidget);
    expect(find.text('Welcome, adventurer.'), findsOneWidget);
  });
  testWidgets('언어를 바꾸면 저장되고 기기 설정으로 되돌릴 수 있다', (tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('ko');
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
    SharedPreferences.setMockInitialValues({'tutorial_complete': true});
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    expect(find.text('작은 모험 길드'), findsOneWidget);
    await tester.tap(find.byTooltip('길드 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日本語'));
    await tester.pumpAndSettle();
    expect(find.text('小さな冒険ギルド'), findsOneWidget);
    expect(
        Localizations.localeOf(tester.element(find.text('小さな冒険ギルド')))
            .languageCode,
        'ja');
    await tester.pumpWidget(const GuildApp(key: ValueKey('language restart')));
    await tester.pumpAndSettle();
    expect(find.text('小さな冒険ギルド'), findsOneWidget);
    await tester.tap(find.byTooltip('ギルドメニュー'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('端末の設定に従う'));
    await tester.pumpAndSettle();
    expect(find.text('작은 모험 길드'), findsOneWidget);
  });
  testWidgets('기기 언어 목록이 비어 있으면 영어를 사용한다', (tester) async {
    tester.binding.platformDispatcher.localesTestValue = [];
    tester.binding.platformDispatcher.localeTestValue = const Locale('ko');
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
    SharedPreferences.setMockInitialValues({'tutorial_complete': true});
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    expect(find.text('Little Adventure Guild'), findsOneWidget);
  });
  test('인사와 튜토리얼 및 예시 퀘스트에 영어·일본어 번역이 있다', () {
    final content = [
      ...guildGreetings,
      ...guildTutorial,
      for (final q in quests) ...[q.$1, q.$2]
    ];
    for (final language in ['en', 'ja']) {
      for (final source in content) {
        expect(translations[language]!.containsKey(source), isTrue,
            reason: '$language: $source');
      }
    }
  });
}
