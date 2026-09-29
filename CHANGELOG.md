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
* **Host integration**: a theme-only `CashupPos.initialize`, the SDK-owned
  `CashupPosApp`, advanced `CashupPos.initializeWithConfig(PosConfig)`, the
  `CashupPosLauncher` entry points, `PosTheme` design tokens,
  `PosFeatureFlags`, per-request token and header providers, and an
  `onTransactionCompleted` callback.
* **Minimal example app** in `example/`; it only supplies theme colours and
  initializes the SDK. The complete UI and demo payment adapters live in the
  SDK.

`CashupPosApp` owns its navigator below the SDK provider scope, so nested POS
screens and dialogs stay inside SDK state.
