import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';

/// Repeatable voluntary support; purchases do not unlock app features.
class GuildSupport extends ChangeNotifier {
  GuildSupport({
    @visibleForTesting bool? androidForTest,
    @visibleForTesting Future<bool> Function(PurchaseDetails)? consumeForTest,
  })  : _isAndroid = androidForTest ?? Platform.isAndroid,
        _consumeForTest = consumeForTest;

  final bool _isAndroid;
  final Future<bool> Function(PurchaseDetails)? _consumeForTest;
  static const ids = [
    'guild_supply_small',
    'guild_supply_generous',
    'guild_supply_special'
  ];
  InAppPurchase get _store => InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final Set<String> _processing = {};
  final Set<String> _processed = {};
  Map<String, ProductDetails> products = {};
  bool loading = true;
  bool busy = false;
  bool available = false;
  String? message;
  bool _disposed = false;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (kIsWeb || (!_isAndroid && !Platform.isIOS)) {
      loading = false;
      _changed();
      return;
    }
    try {
      _subscription =
          _store.purchaseStream.listen(_handleUpdates, onError: (Object _) {
        busy = false;
        message = 'error';
        _changed();
      });
      await refresh();
      await recoverPurchases();
    } catch (_) {
      loading = false;
      available = false;
      message = 'unavailable';
      _changed();
    }
  }

  Future<void> recoverPurchases() async {
    if (!available || !_isAndroid || _disposed) return;
    try {
      final addition =
          _store.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final previous = await addition.queryPastPurchases();
      if (previous.error == null) {
        await _handleUpdates(previous.pastPurchases);
      }
    } catch (_) {
      // The store may be temporarily offline. Retry on a later resume.
    }
  }

  Future<void> refresh() async {
    loading = true;
    _changed();
    try {
      available = await _store.isAvailable();
      if (available) {
        final response = await _store.queryProductDetails(ids.toSet());
        products = {
          for (final product in response.productDetails) product.id: product
        };
        if (response.error != null) message = 'unavailable';
      } else {
        products = {};
      }
    } catch (_) {
      available = false;
      products = {};
      message = 'unavailable';
    } finally {
      loading = false;
      _changed();
    }
  }

  Future<void> purchase(String id) async {
    final product = products[id];
    if (busy || product == null) return;
    busy = true;
    message = null;
    _changed();
    try {
      final launched = await _store.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
        // Explicitly consume Android purchases in the update handler, including
        // ones re-delivered after the app is restarted.
        autoConsume: !_isAndroid,
      );
      if (!launched) {
        busy = false;
        message = 'error';
        _changed();
      }
    } catch (_) {
      busy = false;
      message = 'error';
      _changed();
    }
  }

  Future<void> _handleUpdates(List<PurchaseDetails> updates) async {
    for (final purchase in updates) {
      if (!ids.contains(purchase.productID)) continue;
      if (purchase.status == PurchaseStatus.pending) {
        busy = true;
        message = 'pending';
        _changed();
        continue;
      }
      if (purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled) {
        busy = false;
        message = purchase.status == PurchaseStatus.error ? 'error' : null;
        if (purchase.pendingCompletePurchase) {
          try {
            await _store.completePurchase(purchase);
          } catch (_) {
            message = 'error';
          }
        }
        _changed();
        continue;
      }
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final token = purchase.verificationData.serverVerificationData;
        final key = token.isEmpty
            ? '${purchase.productID}:${purchase.purchaseID}'
            : token;
        if (_processed.contains(key) || !_processing.add(key)) continue;
        try {
          if (_isAndroid) {
            final override = _consumeForTest;
            final success = override != null
                ? await override(purchase)
                : (await _store
                            .getPlatformAddition<
                                InAppPurchaseAndroidPlatformAddition>()
                            .consumePurchase(purchase))
                        .responseCode ==
                    BillingResponse.ok;
            if (!success) {
              throw StateError('consume failed');
            }
          } else if (purchase.pendingCompletePurchase) {
            await _store.completePurchase(purchase);
          }
          _processed.add(key);
          message = 'thanks';
        } catch (_) {
          message = 'error';
        } finally {
          _processing.remove(key);
          busy = false;
          _changed();
        }
      }
    }
  }

  @visibleForTesting
  Future<void> processUpdatesForTest(List<PurchaseDetails> updates) =>
      _handleUpdates(updates);

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
