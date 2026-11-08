import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_adventure_guild/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('wooden controls sound only when enabled for interaction',
      (tester) async {
    const channel = MethodChannel('hvildir/sound_effects');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'play') calls.add(call.arguments as String);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Column(children: [
      GuildButton(label: 'menu', onPressed: () => taps++),
      GuildButton(
          label: 'decoration', soundEnabled: false, onPressed: () => taps++),
      const GuildButton(label: 'disabled', onPressed: null),
    ]))));
    await tester.tap(find.text('menu'));
    await tester.pump();
    expect(calls, ['wood']);
    await tester.tap(find.text('decoration'));
    await tester.pump();
    await tester.tap(find.text('disabled'));
    await tester.pump();
    expect(taps, 2);
    expect(calls, ['wood']);
  });
  testWidgets('music and effects volumes save independently and restore',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'tutorial_complete': true, 'language_override': 'ko'});
    const channel = MethodChannel('hvildir/sound_effects');
    final volumeCalls = <double>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'volume') volumeCalls.add(call.arguments as double);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(const GuildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('길드 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    final music =
        tester.widget<Slider>(find.byKey(const ValueKey('musicVolume')));
    music.onChanged!(0.3);
    music.onChangeEnd!(0.3);
    await tester.pump();
    final effects =
        tester.widget<Slider>(find.byKey(const ValueKey('effectsVolume')));
    effects.onChanged!(0.6);
    effects.onChangeEnd!(0.6);
    await tester.pump();
    final store = await SharedPreferences.getInstance();
    expect(store.getDouble('music_volume'), 0.3);
    expect(store.getDouble('effects_volume'), 0.6);
    expect(volumeCalls.last, 0.6);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const GuildApp(key: ValueKey('restarted')));
    await tester.pumpAndSettle();
    expect(volumeCalls.last, 0.6);
    await tester.tap(find.byTooltip('길드 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<Slider>(find.byKey(const ValueKey('musicVolume'))).value,
        0.3);
    expect(
        tester
            .widget<Slider>(find.byKey(const ValueKey('effectsVolume')))
            .value,
        0.6);
  });
}
