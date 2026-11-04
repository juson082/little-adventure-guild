import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:little_adventure_guild/main.dart';

void main() {
  testWidgets('퀘스트를 열고 완료한 상태가 다시 열어도 유지된다', (tester) async {
    SharedPreferences.setMockInitialValues({});
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
    expect(find.text('퀘스트 완료 · +10 G'), findsOneWidget);
    await tester.ensureVisible(find.text('퀘스트 완료 · +10 G'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('퀘스트 완료 · +10 G'));
    await tester.pumpAndSettle();
    expect(find.text('완료한 퀘스트'), findsOneWidget);
    expect(find.text('10 G'), findsOneWidget);
    await tester.pumpWidget(const GuildApp(key: ValueKey('restart')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('완료한 퀘스트'), findsOneWidget);
  });
  testWidgets('길드 메뉴에서 안내를 열고 닫는다', (tester) async {
    SharedPreferences.setMockInitialValues({});
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
      'today': '{"date":"$date","quest":0,"opened":true,"completed":false}'
    });
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('퀘스트 완료 · +10 G'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('퀘스트 완료 · +10 G'));
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
      'today':
          '{"date":"$date","quest":0,"opened":true,"completed":false,"gold":20}'
    });
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('이번에는 못 했어요'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이번에는 못 했어요'));
    await tester.pumpAndSettle();
    expect(find.text('오늘은 쉬어가요'), findsOneWidget);
    expect(find.text('20 G'), findsOneWidget);
  });
}
