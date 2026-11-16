# Google Play voluntary support setup

The app queries three one-time, repeatable (consumable) in-app products from Google Play. Supporting the guild does not unlock any feature, quest, or digital content. The billing flow must not be considered live until the store products are created and tested.

| Product ID | Korean name | Intended US base price |
| --- | --- | --- |
| `guild_supply_small` | 작은 보급품 | USD 1.00 |
| `guild_supply_generous` | 든든한 보급품 | USD 5.00 |
| `guild_supply_special` | 특별 보급품 | USD 10.00 |

In Play Console, create and activate all three one-time products for the app's package, assign the listed US prices, review the regional prices and tax settings, and upload a build containing the billing integration. The app shows prices returned by Google Play; it never assumes that the US price applies in another country. Product IDs must exactly match the table. Set up a test track and license testers, install from Google Play, then verify each purchase, cancellation, pending payment, repeat purchase, interrupted purchase recovery, and store-unavailable state.

Purchases are processed on-device through Google Play Billing. Android purchases are consumed to allow repeat support; an app start queries previously unconsumed purchases. There is no backend verification, fraud detection, transaction ledger, or reconciliation implemented. Because support unlocks nothing, there is no entitlement to grant, but Play Console is the source for transaction and refund records. Assess backend verification before relying on client-side data for anything of value. No real purchase should be made without a tester's explicit intent.

For iOS, create matching App Store Connect consumables and test StoreKit separately before enabling release.
