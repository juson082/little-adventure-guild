import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_adventure_guild/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> render(WidgetTester tester, String name, bool opened) async {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({
      'tutorial_complete': true,
      'language_override': 'en',
      'last_visit_date': date,
      'last_greeting_date': date,
      'today': jsonEncode({
        'date': date,
        'quest': 0,
        'catalogVersion': 1,
        'opened': opened,
        if (opened) 'opened_at_ms': now.toUtc().millisecondsSinceEpoch,
        'completed': false,
        'failed': false,
        'gold': 0,
      }),
    });
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    final pixelFont = FontLoader('Galmuri')
      ..addFont(rootBundle.load('assets/fonts/Galmuri11.ttf'));
    final textFont = FontLoader('sans-serif')
      ..addFont(rootBundle.load('assets/fonts/Galmuri11.ttf'));
    final defaultFont = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/Galmuri11.ttf'));
    await tester.runAsync(() async {
      final iconBytes = await File(
              '.tools/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
          .readAsBytes();
      final icons = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.view(iconBytes.buffer)));
      await pixelFont.load();
      await textFont.load();
      await defaultFont.load();
      await icons.load();
    });
    await tester.pumpWidget(RepaintBoundary(key: key, child: const GuildApp()));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (final asset in [
        'assets/guild_interior_v4.png',
        'assets/dialogue_frame.png',
        'assets/wood_button.png',
        'assets/sealed_scroll_v2.png',
        'assets/quest_paper_normal.png',
        'assets/quest_paper_hard.png'
      ]) {
        await precacheImage(AssetImage(asset), key.currentContext!);
      }
    });
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('store-assets/$name')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('render home for store',
      (tester) async => render(tester, 'screenshot-01.png', false));
  testWidgets('render quest for store',
      (tester) async => render(tester, 'screenshot-02.png', true));
}
