import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_adventure_guild/guild_decorations.dart';
import 'package:little_adventure_guild/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final language in ['ko', 'en', 'ja', 'zh', 'hi', 'es']) {
    testWidgets('decoration labels fit on a narrow screen: $language',
        (tester) async {
      final now = DateTime.now();
      final date =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      SharedPreferences.setMockInitialValues({
        'tutorial_complete': true,
        'language_override': language,
        'last_visit_date': date,
        'last_greeting_date': date,
        'today': jsonEncode({
          'date': date,
          'quest': 0,
          'catalogVersion': 1,
          'opened': false,
          'completed': false,
          'gold': 150,
        }),
      });
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(const GuildApp());
      await tester.pumpAndSettle();
      final coin = find.byWidgetPredicate((widget) =>
          widget is CustomPaint &&
          widget.painter is HeaderIconPainter &&
          (widget.painter! as HeaderIconPainter).coin);
      await tester.tap(
          find.ancestor(of: coin, matching: find.byType(TextButton)).first);
      await tester.pumpAndSettle();
      for (final item in guildDecorations) {
        final label = find.textContaining(decorationName(language, item));
        await tester.ensureVisible(label);
        await tester.pumpAndSettle();
        final button =
            find.ancestor(of: label, matching: find.byType(GuildButton)).first;
        final textRect = tester.getRect(label);
        final buttonRect = tester.getRect(button);
        expect(textRect.left, greaterThanOrEqualTo(buttonRect.left));
        expect(textRect.right, lessThanOrEqualTo(buttonRect.right));
        expect(textRect.top, greaterThanOrEqualTo(buttonRect.top));
        expect(textRect.bottom, lessThanOrEqualTo(buttonRect.bottom));
        expect(tester.takeException(), isNull);
      }
    });
  }
}
