import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_adventure_guild/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('render greeting dismissal and sealed scroll appearance', (
    tester,
  ) async {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({
      'tutorial_complete': true,
      'language_override': 'ko',
      'last_visit_date': date,
      'today': jsonEncode({
        'date': date,
        'quest': 0,
        'catalogVersion': 1,
        'opened': false,
        'completed': false,
        'failed': false,
        'gold': 0,
      }),
    });
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundaryKey = GlobalKey();
    await tester.runAsync(() async {
      for (final name in ['Galmuri', 'sans-serif', 'Roboto']) {
        final font = FontLoader(name)
          ..addFont(rootBundle.load('assets/fonts/Galmuri11.ttf'));
        await font.load();
      }
      final iconData = await File(
        '.tools/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes();
      final icons = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.view(iconData.buffer)));
      await icons.load();
    });
    await tester.pumpWidget(
      RepaintBoundary(key: boundaryKey, child: const GuildApp()),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (final file in [
        'assets/guild_interior_v4.png',
        'assets/sealed_scroll_v2.png',
        'assets/dialogue_frame.png',
      ]) {
        await precacheImage(AssetImage(file), boundaryKey.currentContext!);
      }
    });
    await tester.pump();
    final dialogue = find.byType(GuildDialogueText);
    await tester.tap(dialogue);
    await tester.pump();
    await tester.runAsync(
      () =>
          Directory('preview/scroll-appearance-frames').create(recursive: true),
    );
    Future<void> frame(int i) async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'preview/scroll-appearance-frames/${i.toString().padLeft(3, '0')}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await frame(0);
    await tester.tap(dialogue);
    for (var i = 1; i <= 20; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      await frame(i);
    }
    expect(find.byKey(const ValueKey('openQuest')), findsOneWidget);
  });
}
