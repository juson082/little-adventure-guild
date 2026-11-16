import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_adventure_guild/guild_keeper_idle.dart';

void main() {
  test('all seven actions start and finish at rest and use valid frames', () {
    expect(keeperIdleSequences.length, 7);
    for (final sequence in keeperIdleSequences.values) {
      expect(sequence.first, 0);
      expect(sequence.last, 17);
      expect(sequence.every((frame) => frame >= 0 && frame < 18), isTrue);
    }
    expect(keeperIdleSequences['beard']!.length, greaterThan(18));
    expect(keeperIdleSequences['sleep']!.length, greaterThan(18));
  });

  testWidgets('idle layer cleans up its timer on disposal', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GuildKeeperIdle()));
    expect(find.byType(GuildKeeperIdle), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('after three minutes an idle animation loads and ends', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: false),
          child: SizedBox(width: 360, height: 600, child: GuildKeeperIdle()),
        ),
      ),
    );
    final layer = find.descendant(
      of: find.byType(GuildKeeperIdle),
      matching: find.byType(CustomPaint),
    );
    await tester.pump(const Duration(minutes: 2, seconds: 59));
    expect(layer, findsNothing);
    await tester.pump(const Duration(seconds: 1));
    for (var i = 0; i < 80 && layer.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
      await tester.pump();
    }
    expect(layer, findsOneWidget);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(layer, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion leaves the idle layer inactive', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: GuildKeeperIdle(),
        ),
      ),
    );
    await tester.pump(const Duration(minutes: 4));
    expect(
      find.descendant(
        of: find.byType(GuildKeeperIdle),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
