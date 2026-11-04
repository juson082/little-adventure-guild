import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:little_adventure_guild/main.dart';

void main() {
  testWidgets('퀘스트를 열고 완료한 상태가 다시 열어도 유지된다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const GuildApp());
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
    expect(find.text('완료한 퀘스트'), findsOneWidget);
  });
}




