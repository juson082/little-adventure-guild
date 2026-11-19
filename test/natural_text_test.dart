import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_adventure_guild/natural_text.dart';

void main() {
  test('Korean syllables stay together only when the word fits', () {
    expect(koreanWordBreaks('오늘의 의뢰', (_) => true), '오\u2060늘\u2060의 의\u2060뢰');
    expect(koreanWordBreaks('오늘의 의뢰', (word) => word != '오늘의'), '오늘의 의\u2060뢰');
    expect(koreanWordBreaks('English 日本語 中文', (_) => true), 'English 日本語 中文');
  });

  testWidgets('typewriter reserves the full dialogue layout', (tester) async {
    Widget app(int visible) => MaterialApp(
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(
        body: SizedBox(
          width: 130,
          child: NaturalText('오늘의 작은 의뢰를 받아 보게', visibleCharacters: visible),
        ),
      ),
    );
    await tester.pumpWidget(app(1));
    final initial = tester.getSize(find.byType(NaturalText));
    await tester.pumpWidget(app(15));
    expect(tester.getSize(find.byType(NaturalText)), initial);
    expect(tester.takeException(), isNull);
  });
}
