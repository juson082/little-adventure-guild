import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:little_adventure_guild/guild_support.dart';
import 'package:little_adventure_guild/support_messages.dart';

PurchaseDetails update(
  PurchaseStatus status, {
  String id = 'guild_supply_small',
}) => PurchaseDetails(
  productID: id,
  purchaseID: 'order-1',
  transactionDate: null,
  status: status,
  verificationData: PurchaseVerificationData(
    localVerificationData: '',
    serverVerificationData: 'token-1',
    source: 'test',
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'pending stays pending and successful Android payment is consumed once',
    () async {
      var count = 0;
      final gate = Completer<bool>();
      final service = GuildSupport(
        androidForTest: true,
        consumeForTest: (_) {
          count++;
          return gate.future;
        },
      );
      await service.processUpdatesForTest([update(PurchaseStatus.pending)]);
      expect(service.busy, isTrue);
      expect(service.message, 'pending');
      final first = service.processUpdatesForTest([
        update(PurchaseStatus.purchased),
      ]);
      final duplicate = service.processUpdatesForTest([
        update(PurchaseStatus.purchased),
      ]);
      expect(count, 1);
      gate.complete(true);
      await Future.wait([first, duplicate]);
      await service.processUpdatesForTest([update(PurchaseStatus.purchased)]);
      expect(count, 1);
      expect(service.message, 'thanks');
      expect(service.busy, isFalse);
      service.dispose();
    },
  );

  test('failed consumption is not reported as successful', () async {
    final service = GuildSupport(
      androidForTest: true,
      consumeForTest: (_) async => false,
    );
    await service.processUpdatesForTest([update(PurchaseStatus.purchased)]);
    expect(service.message, 'error');
    expect(service.busy, isFalse);
    service.dispose();
  });

  test('cancelled purchase clears pending state without consuming', () async {
    final service = GuildSupport(
      androidForTest: true,
      consumeForTest: (_) async => throw StateError('must not consume'),
    );
    await service.processUpdatesForTest([update(PurchaseStatus.pending)]);
    await service.processUpdatesForTest([update(PurchaseStatus.canceled)]);
    expect(service.message, isNull);
    expect(service.busy, isFalse);
    service.dispose();
  });

  test(
    'unrelated purchases are ignored and support messages are localized',
    () async {
      final service = GuildSupport(
        androidForTest: true,
        consumeForTest: (_) async => throw StateError('unexpected'),
      );
      await service.processUpdatesForTest([
        update(PurchaseStatus.purchased, id: 'unrelated'),
      ]);
      expect(service.message, isNull);
      for (final code in ['ko', 'en', 'ja', 'zh', 'hi', 'es']) {
        expect(
          supportMessages[code]!.keys,
          containsAll([
            'unavailable',
            'loading',
            'pending',
            'thanks',
            'error',
            'retry',
            'price',
          ]),
        );
      }
      service.dispose();
    },
  );
}
