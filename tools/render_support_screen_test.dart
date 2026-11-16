import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:little_adventure_guild/guild_support.dart';
import 'package:little_adventure_guild/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> render(WidgetTester tester, {required bool mockPrices}) async {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({
      'tutorial_complete': true,
      'language_override': 'ko',
      'last_visit_date': date,
      'last_greeting_date': date,
      'today': jsonEncode({
        'date': date,
        'quest': 0,
        'catalogVersion': 1,
        'opened': false,
        'completed': false,
        'gold': 0,
      }),
    });
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.runAsync(() async {
      for (final name in ['Galmuri', 'sans-serif', 'Roboto']) {
        final font = FontLoader(name)
          ..addFont(rootBundle.load('assets/fonts/Galmuri11.ttf'));
        await font.load();
      }
      final bytes = await File(
        '.tools/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes();
      final icons = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.view(bytes.buffer)));
      await icons.load();
    });
    await tester.pumpWidget(RepaintBoundary(key: key, child: const GuildApp()));
    await tester.pumpAndSettle();
    if (mockPrices) {
      final dynamic homeState = tester.state(find.byType(GuildHome));
      final GuildSupport support = homeState.guildSupport as GuildSupport;
      support.available = true;
      support.loading = false;
      support.message = null;
      support.products = {
        for (var i = 0; i < GuildSupport.ids.length; i++)
          GuildSupport.ids[i]: ProductDetails(
            id: GuildSupport.ids[i],
            title: '',
            description: '',
            price: '\$${[1, 5, 10][i]}.00',
            rawPrice: [1.0, 5.0, 10.0][i],
            currencyCode: 'USD',
            currencySymbol: '\$',
          ),
      };
    }
    await tester.tap(find.byTooltip('길드 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('길드 지원하기'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (final file in [
        'small-pixel.png',
        'generous-pixel.png',
        'special-pixel.png',
      ]) {
        await precacheImage(
          AssetImage('assets/support/$file'),
          key.currentContext!,
        );
      }
    });
    await tester.pumpAndSettle();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        mockPrices
            ? 'preview/support-screen-prices-mock.png'
            : 'preview/support-screen.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'render unavailable support screen',
    (tester) => render(tester, mockPrices: false),
  );
  testWidgets(
    'render support screen with illustrative store prices',
    (tester) => render(tester, mockPrices: true),
  );
}
