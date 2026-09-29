# cashup_pos

`cashup_pos` is a Flutter package that embeds a complete Point of Sale into a
host application. You get the full cashier UI (responsive phone and tablet
layouts): product browsing, cart, discounts and promotions, checkout with
cash, QRIS and card payments, receipts, transaction history, product and
category management, payment settings, a sales summary report and a
simple-amount mode. You also get the transaction calculation engine behind
it. The UI copy is Indonesian. The package is a port of the shipping Kotlin
Cashup POS and talks to the same `/pos/*` backend, which re-computes every
amount and rejects any that don't match.

The SDK owns the complete application UI, including its `MaterialApp`, theme,
navigator and every POS route. The example host only initializes the SDK,
supplies colour tokens and runs `CashupPosApp`.

## Installation

The package isn't published to pub.dev. Depend on it by path or git:

```yaml
dependencies:
  cashup_pos:
    path: ../cashup_pos_flutter
  # or
  # cashup_pos:
  #   git:
  #     url: <repository url>
```

Import only the public library:

```dart
import 'package:cashup_pos/cashup_pos.dart';
```

`lib/cashup_pos.dart` is the whole public API. Never import
`package:cashup_pos/src/...`. Those files are internal and can change
without notice.

The SDK brings its own Riverpod container. The host doesn't need to wrap
anything in a `ProviderScope`, and the SDK never touches the host's own
provider graph. Nothing uses code generation, so the host build doesn't need
`build_runner`.

## Quick start

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await CashupPos.initialize(
    bannerImageUrls: const [
      'https://cdn.example.com/pos/banner-1.jpg',
      'https://cdn.example.com/pos/banner-2.jpg',
    ],
    theme: const PosTheme(
      shellBackground: Color(0xFF212B52),
      surface: Color(0xFFFFFFFF),
      surfaceSoft: Color(0xFFF8FAFC),
      textOnShell: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF0F172A),
      textSecondary: Color(0xFF475569),
      strokeSoft: Color(0xFFE2E8F0),
      accentSuccess: Color(0xFF10B981),
    ),
  );

  runApp(const CashupPosApp());
}
```

`CashupPos.initialize` reads optional `CASHUP_POS_BASE_URL` and
`CASHUP_POS_TOKEN` dart-defines. Its demo merchant and payment adapters live
inside the SDK, not in the example. See [Example app](#example-app).

For a production host that owns authentication or payment hardware, use
`CashupPos.initializeWithConfig(PosConfig(...))`; the UI still remains fully
inside `CashupPosApp`.

## `CashupPos` and `CashupPosLauncher`

| API | What it does |
| --- | --- |
| `CashupPos.initialize(theme: ..., bannerImageUrls: ...)` | Creates the SDK using its self-contained defaults. The host can supply its colour theme and ordered catalogue banner URLs. |
| `CashupPos.initializeWithConfig(PosConfig)` | Advanced production setup for a custom backend, auth, merchant and payment adapters. Re-initializing resets SDK state, including the cart. |
| `CashupPosApp` | SDK-owned application root containing the theme, provider scope, navigator and initial POS screen. |
| `CashupPos.dispose()` | Tears the container down and clears the config (for example, on sign-out). Safe to call at any time. |
| `CashupPos.isInitialized` | Whether `initialize` has run and `dispose` hasn't. |
| `CashupPos.config` | The active config, with `baseUrl` normalised to end in `/`. Throws before `initialize`. |
| `CashupPosLauncher.open(context)` | Pushes the main POS shell: catalogue, cart and checkout. |
| `CashupPosLauncher.openTransactions(context)` | Pushes transaction history. |
| `CashupPosLauncher.openProductManagement(context)` | Pushes product management. |
| `CashupPosLauncher.openSettings(context)` | Pushes payment settings. |

The launcher methods remain available for embedding individual routes in a
larger host application. Every launcher method pushes onto the host's
`Navigator` and throws a
`StateError` if the SDK isn't initialized. Each pushed route is themed from
`PosConfig.theme`. It follows the host's current brightness, taken from
`Theme.of(context)` at push time.

## `PosConfig`

`PosConfig` is the advanced integration object passed to
`CashupPos.initializeWithConfig`. Building one never fails and never touches
the network.

| Field | Required | Meaning |
| --- | --- | --- |
| `baseUrl` | yes | Base URL of the `/pos/*` backend. A missing trailing slash is added by `initialize`. |
| `tokenProvider` | yes | `Future<String?> Function()`, called **before every request** to get the bearer token (JWT). The SDK never caches the token, so a refreshed token is picked up without re-initializing. Return `null` or an empty string to send no `Authorization` header. A rejected token shows up as `PosErrorKind.unauthorized`. |
| `merchant` | yes | `PosMerchant`: the merchant identity shown in the POS chrome and on receipts. See below. |
| `paymentHandler` | no | Your `PosPaymentHandler` for card, EDC or CDCP payments. If it's `null`, only cash and (if `qrisGateway` is set) QRIS are offered. |
| `qrisGateway` | no | Your `QrisGateway`. If it's `null`, QRIS isn't offered. |
| `theme` | no | `PosTheme` design tokens. Defaults to `PosTheme.cashup()`. |
| `features` | no | `PosFeatureFlags`. Everything is enabled by default. |
| `locale` | no | Defaults to `Locale('id', 'ID')`. It's stored but nothing reads it yet. The UI copy is currently Indonesian only, and money is always formatted as rupiah. |
| `extraHeaders` | no | `Map<String, String> Function()`, called for every request and merged onto it next to the bearer token. Use it for device-id, app-version or user-agent headers. |
| `onTransactionCompleted` | no | `void Function(TransactionDetails)`. It's called once a sale has been created and paid on the backend, with the full transaction detail. If the detail fetch fails, the callback is skipped and the sale itself still stands. |

`PosMerchant` has these fields:

| Field | Meaning |
| --- | --- |
| `name` (required) | The merchant name. |
| `address`, `address2` | Optional address lines. |
| `logoAssetPath` | An asset path resolved against the **host's** asset bundle. The SDK ships no merchant logos. |

## Payments

The SDK decides which methods to offer from the backend's payment-method
list, filtered by what the host can actually execute:

- **Cash** is always available and handled entirely by the SDK: the tendered
  amount dialog and change calculation.
- **QRIS** is offered when `qrisGateway` is set. The SDK owns the dialog, the
  QR rendering and the polling loop. The host only generates and checks the
  status.
- **Every other method** (card, EDC, CDCP) is offered only if its backend
  code is in `paymentHandler.supportedMethods`, and is delegated to the host.

After a successful payment, the SDK creates the transaction on the backend.

### Implementing `PosPaymentHandler`

```dart
class MyCardPaymentHandler implements PosPaymentHandler {
  @override
  Set<String> get supportedMethods => const {'CARD'}; // backend method codes

  @override
  Future<PosPaymentResult> pay({
    required String method,
    required double amount,
    required String merchantTrxId,
    int? transactionId,
  }) async {
    final response = await myTerminal.charge(amount, reference: merchantTrxId);
    if (response.cancelledByUser) return const PosPaymentResult.cancelled();
    if (!response.approved) {
      return PosPaymentResult.failed(message: response.error, code: response.code);
    }
    return PosPaymentResult.success(
      reference: response.rrn,
      approvalCode: response.approvalCode,
      cardMasked: response.maskedPan,
      raw: response.toJson(),
    );
  }
}
```

The SDK calls `pay` and waits for it, so don't return until the terminal has
a definitive answer. A `failed` or `cancelled` result means the transaction
is **not** created, and the cashier sees your `message` (or
"Pembayaran dibatalkan.").

### Implementing `QrisGateway`

On a real device, the QRIS payload usually arrives DUKPT-encrypted and is
decrypted natively, so this part lives in the host:

```dart
class MyQrisGateway implements QrisGateway {
  @override
  Future<QrisPayload> generate({required double amount, String? merchantTrxId}) async {
    final res = await myGateway.createQris(amount);
    return QrisPayload(qrString: res.decryptedQr, invoiceNumber: res.invoice);
  }

  @override
  Future<QrisStatus> checkStatus({required String invoiceNumber, String? merchantTrxId}) async {
    final res = await myGateway.status(invoiceNumber);
    return switch (res.code) {
      '0010' => QrisStatus.paid,
      '0020' => QrisStatus.failed,
      _ => QrisStatus.pending,
    };
  }
}
```

The dialog checks status right away and then every 3 seconds. Only `paid`
and `failed` stop the polling. `pending` and `expired` keep polling, which
matches the Kotlin app, until the cashier closes the dialog. Closing it
abandons the sale without creating a transaction. If `generate` throws, the
dialog shows "Gagal membuat QR. Coba lagi."

## Theming

`PosTheme` holds the colour tokens (ported from the Kotlin
`pos_design_tokens.xml`) plus a spacing scale and a corner radius:

```dart
const PosTheme(
  shellBackground: Color(0xFF0B3D2E), // app bar / shell chrome
  surface: Color(0xFFFFFFFF),         // cards and pages
  surfaceSoft: Color(0xFFF5F7F6),     // grouped / secondary areas, scaffold
  textOnShell: Color(0xFFFFFFFF),
  textPrimary: Color(0xFF0F172A),
  textSecondary: Color(0xFF475569),
  strokeSoft: Color(0xFFE2E8F0),      // borders, dividers
  accentSuccess: Color(0xFF10B981),   // paid / confirm accents
  spacingMd: 16,                      // spacingXs..spacingXl are optional
  cornerRadius: 12,
)
```

`PosTheme.cashup()` is the stock Cashup palette.
`theme.toThemeData(brightness)` builds the Material 3 `ThemeData` used by the
SDK-owned `MaterialApp` and its routes.

## Feature flags

`PosFeatureFlags` turns optional parts of the POS off. Every flag defaults to
`true`.

| Flag | Effect today |
| --- | --- |
| `enableProductManagement` | Shows the "Produk" entry in the POS menu. |
| `enableCategoryManagement` | Shows the "Kategori" entry in the POS menu. |
| `enableSummaryReport` | Shows the "Ringkasan penjualan" entry in the POS menu. |
| `enableSimpleMode` | Shows the "Nominal sederhana" (simple amount) entry in the POS menu. |
| `enableStockTracking` | Reserved. Not read by any screen yet. |
| `enableQueueNumber` | Reserved. Not read by any screen yet. |

The flags only control what the POS menu shows. They don't block the
`CashupPosLauncher` entry points, so a host that disables product management
shouldn't call `openProductManagement` either.

## Pure online: what happens when connectivity drops

The SDK has **no local database, no disk cache and no offline outbox**. This
is a deliberate product decision, not a gap.

- **Every screen reads live from the backend.** If a request fails, the
  screen shows an error with a "Coba Lagi" (retry) button. The message comes
  from `PosException.friendlyMessage`, for example "Tidak ada koneksi
  internet. POS memerlukan koneksi aktif."
- **A dropped connection stops sales.** The catalogue can't load, and a
  checkout can't be submitted.
- **A lost `transaction/create` response is never retried automatically.** If
  the request to create a transaction fails with a network or timeout error,
  the SDK can't know whether the backend recorded the sale. It shows
  "Periksa transaksi" ("Status transaksi belum diketahui. Periksa daftar
  transaksi sebelum mencoba lagi.") and leaves the cart intact. The cashier
  must check the transaction history before trying again, because a blind
  retry could charge the customer twice. Card and QRIS payments have already
  settled at that point, which makes this check especially important.
- Other failures, such as HTTP 4xx/5xx or a business error in a 200
  response, are reported as a plain "Pembayaran gagal" with the backend's
  message. Here the backend did answer, and its answer was a rejection.

Every SDK error is a `PosException`. Its `kind` is a `PosErrorKind` value:
`network`, `timeout`, `unauthorized`, `server`, `badResponse`, `cancelled`
or `unknown`. A host that reacts to `unauthorized` (for example, by forcing
a sign-in) can do so in its `tokenProvider` or its session layer.

The data layer sits behind the `PosRepository` interface. That interface is
the seam where a cached or offline implementation could be added later
without touching the UI, state or calculation code. None is planned in this
release.

## Example app

```sh
cd example
flutter run -d <device-id> \
  --dart-define=CASHUP_POS_BASE_URL=https://your-host/api/ \
  --dart-define=CASHUP_POS_TOKEN=<jwt>
```

The example contains no host-owned screen. It supplies only `PosTheme`, calls
`CashupPos.initialize`, and runs `CashupPosApp`. The SDK's built-in demo card
and QRIS adapters keep the payment UI exercisable; catalogue and transaction
operations still need a reachable `/pos/*` backend.

Android builds need `JAVA_HOME` pointing at JDK 17.

## Development

```sh
flutter pub get
flutter analyze        # must be clean
dart format lib test
flutter test           # whole suite, including the ported Kotlin engine tests
```

## Source of truth

The calculation engine and every screen are ported from the Kotlin Cashup
POS:

- Branch: `feature/pos-asg-phase3`
- Pinned commit: `6990fbbb5`. It was bumped from
  `33ddffdcc50aa8f9c6c53344bb4b269de5733064`. The only changes between the
  two touch receipt layout and the summary report, not the engine or the
  data layer.
- Modules: `pos-core` (engine and data), `feature/pos` (phone UI),
  `feature/pos-tablet` (tablet UI), `feature/pos-shared`

To sync with a newer backend or app release, diff the Kotlin modules from
the pinned commit to the new head. Dart file names mirror the Kotlin ones,
so the two trees can be compared side by side. The ported Kotlin unit tests
under `test/calc/` encode agreement with the backend: a change that breaks
one is a regression.
