import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:little_adventure_guild/main.dart';
import 'package:little_adventure_guild/quest_feedback.dart';
import 'package:little_adventure_guild/natural_text.dart';

void main() {
  testWidgets('대화 탭은 출력 완료 후 닫고 의뢰를 보여 준다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'tutorial_complete': true,
      'language_override': 'ko',
    });
    await tester.pumpWidget(const GuildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final dialogue = find.byType(GuildDialogueText);
    expect(dialogue, findsOneWidget);
    final text = tester.widget<GuildDialogueText>(dialogue).text;
    await tester.tap(dialogue);
    await tester.pump();
    expect(
      tester
          .widget<NaturalText>(find.byType(NaturalText).first)
          .visibleCharacters,
      text.characters.length,
    );
    expect(find.byKey(const ValueKey('openQuest')), findsNothing);
    await tester.tap(dialogue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const ValueKey('openQuest')), findsOneWidget);
  });

  testWidgets('실패 뒤 의뢰가 사라지고 1분 뒤 다른 대사가 나온다', (tester) async {
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
        'opened_at_ms': now.toUtc().millisecondsSinceEpoch,
        'completed': false,
        'failed': false,
        'gold': 0,
      }),
    });
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('퀘스트 실패'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(QuestDocument), findsNothing);
    expect(find.byKey(const ValueKey('openQuest')), findsNothing);
    await tester.tap(find.byType(GuildDialogueText));
    await tester.pump();
    await tester.tap(find.byType(GuildDialogueText));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(minutes: 1));
    await tester.pump();
    expect(
      questIdleMessages['ko'],
      contains(
        tester.widget<GuildDialogueText>(find.byType(GuildDialogueText)).text,
      ),
    );
    expect(find.byKey(const ValueKey('openQuest')), findsNothing);
  });

  test('대기 대사는 지원 언어마다 다섯 개다', () {
    for (final code in ['ko', 'en', 'ja', 'zh', 'hi', 'es']) {
      expect(questIdleMessages[code], hasLength(5));
    }
  });

  testWidgets('메뉴 하단의 라이선스를 열고 X로 닫는다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'tutorial_complete': true,
      'language_override': 'ko',
    });
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('길드 메뉴'));
    await tester.pumpAndSettle();
    expect(find.text('길드 꾸미기'), findsNothing);
    expect(find.text('오픈소스 라이선스'), findsOneWidget);
    await tester.tap(find.text('오픈소스 라이선스'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(PixelCloseButton).last);
    await tester.pumpAndSettle();
    expect(find.text('오픈소스 라이선스'), findsNothing);
  });
}
