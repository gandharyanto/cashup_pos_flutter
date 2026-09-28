## 0.1.0

First release of the Cashup POS Flutter SDK. This is a port of the Kotlin
Cashup POS (`feature/pos-asg-phase3` at `6990fbbb5`).

* **Full POS UI**, responsive across phone and tablet layouts: product
  browsing with category and search filters, cart with variants and price
  overrides, discounts and promotions, checkout, receipts, transaction
  history and detail, product and category management with stock movements,
  payment and receipt settings, a sales summary report, and a simple-amount
  mode. All UI copy is Indonesian.
* **Calculation engine** (`calc/`): totals, tax, service charge, rounding,
  per-item discounts, and promotion evaluation (including buy-X-get-Y), with
  the backend's exact rounding semantics. It ships with every Kotlin
  `pos-core` unit test ported.
* **Pure-online data layer**: a dio-backed client for the `/pos/*` backend
  behind the `PosRepository` seam, with a typed `PosException` /
  `PosErrorKind` error model. There's no local cache or outbox. A lost
  transaction-create response is surfaced for the cashier to check, never
  retried blindly.
* **Payments**: cash is handled in the SDK. QRIS uses an SDK-owned dialog, QR
  rendering and 3-second polling, backed by a host-implemented
  `QrisGateway`. Card, EDC and CDCP are delegated to a host-implemented
  `PosPaymentHandler`.
* **Host integration**: `CashupPos.initialize(PosConfig)`, the
  `CashupPosLauncher` entry points, `PosTheme` design tokens,
  `PosFeatureFlags`, per-request token and header providers, and an
  `onTransactionCompleted` callback.
* **Example host app** in `example/`, with a demo card handler and a demo
  QRIS gateway.

### Known issues

* Screens and dialogs that SDK pages open themselves (the POS menu, the
  phone cart sheet, checkout, payment dialogs) are pushed onto the host's
  `Navigator`, outside the SDK's provider scope, and fail with "No
  ProviderScope found". Only the pages that `CashupPosLauncher` opens
  directly work from a host app. The widget tests don't catch this because
  they wrap the whole `MaterialApp` in a `ProviderScope`.
