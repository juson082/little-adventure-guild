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
    expect(find.text('퀘스트 완료'), findsOneWidget);
    await tester.ensureVisible(find.text('퀘스트 완료'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('퀘스트 완료'));
    await tester.pumpAndSettle();
    expect(find.text('완료한 퀘스트'), findsOneWidget);
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
}
