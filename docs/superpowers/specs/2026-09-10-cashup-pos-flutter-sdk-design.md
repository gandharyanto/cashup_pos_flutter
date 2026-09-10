# Cashup POS Flutter SDK — Design Spec

**Goal:** Port the Cashup POS feature (currently `pos-core` + `feature/pos` + `feature/pos-tablet` + `feature/pos-shared` on `mobile-apps-cashlez@feature/pos-asg-phase3`, ±35k lines of Kotlin) into a standalone Flutter package, `cashup_pos`, that any Flutter host application can depend on to gain a complete POS: full end-to-end UI plus the transaction calculation engine.

**Scope:** Full port — models, calculation engine, `/pos/*` API layer, state layer, and every screen (phone + tablet). Behaviour of the calculation engine must be identical to the Kotlin original, because the backend validates the amounts the client sends.

**Non-goals:**
- No local database. See *Connectivity Model*.
- No card/EDC/ECR integration inside the SDK. The host app owns the payment terminal.
- No Cashlez-specific auth flow. The host supplies a base URL and a token provider.

**Source of truth:** `mobile-apps-cashlez`, branch `origin/feature/pos-asg-phase3`. Every "ported from" reference in this document is a path on that branch.

---

## Decisions Taken

| Area | Decision | Why |
|---|---|---|
| State management | Riverpod (`flutter_riverpod`, no codegen) | Closest to `ViewModel` + `StateFlow`. DI built in; does not force a provider tree on the host; `select()` gives the per-widget rebuild control the performance budget depends on. No `build_runner` burden for host apps. |
| Payments | QRIS handled **inside** the SDK (QR render + 3 s polling); card/EDC/CDCP **delegated** to the host | The QRIS payload is generated and status-polled over HTTP, which the SDK can own. DUKPT decryption and EDC/ECR are native and device-specific, so they stay with the host behind `PosPaymentHandler`. |
| Connectivity | **Pure online.** No local DB, no cache, no outbox. | Explicit product decision. Risk recorded under *Connectivity Model*. |
| UI scope | One responsive UI covering phone and tablet | The Kotlin tree duplicated every screen across `feature/pos` and `feature/pos-tablet`; a single adaptive tree removes that duplication. |
| Serialization | Hand-written `fromJson` / `toJson` | Keeps the package codegen-free. Also confines the loose backend typing (numbers arriving as strings) to one place. |

---

## Connectivity Model — Pure Online

The SDK calls `/pos/*` on every read and write. Nothing is persisted. When the network drops, the POS stops selling.

This is a deliberate product decision. Two consequences are recorded here so they are not rediscovered later:

1. **A dropped connection halts sales.** There is no snapshot of the catalogue to fall back on.
2. **An in-flight `POST /pos/transaction/create` whose response is lost is indeterminate.** The server may have committed it; the client cannot tell. The SDK surfaces this to the cashier as an explicit retry prompt rather than retrying silently, because a blind retry can double-charge.

**Mitigation carried in the design:** every data access goes through the `PosRepository` interface, and `PosRepositoryImpl` is its only online implementation. A caching or outbox-backed implementation can be added later as a second implementation of the same interface — no UI, state, or calculation code changes. This is the single structural concession to the risk above.

---

## Package Layout

```
lib/
├── cashup_pos.dart                     ← the entire public surface; nothing else is exported
└── src/
    ├── cashup_pos_sdk.dart             ← CashupPos.initialize(...), CashupPosLauncher
    ├── config/
    │   ├── pos_config.dart             ← base url, token provider, feature flags, locale
    │   └── pos_theme.dart              ← PosTheme + PosColors + PosSpacing tokens
    ├── models/                         ← 1:1 with pos-core data/request + data/response
    ├── calc/                           ← 1:1 with pos-core util/ (the engine)
    │   ├── rounding_utils.dart
    │   ├── calculator_models.dart
    │   ├── transaction_calculator.dart
    │   └── promotion/
    │       ├── evaluation_context.dart
    │       ├── promotion_evaluator.dart
    │       ├── promotion_orchestrator.dart
    │       ├── discount_by_order_evaluator.dart
    │       ├── discount_by_item_subtotal_evaluator.dart
    │       └── buyxgety/
    │           ├── buy_x_get_y_evaluator.dart
    │           ├── reward_strategy.dart
    │           ├── free_reward_strategy.dart
    │           ├── percentage_reward_strategy.dart
    │           ├── amount_reward_strategy.dart
    │           └── fixed_price_reward_strategy.dart
    ├── data/
    │   ├── pos_api_client.dart         ← dio, interceptors, error mapping
    │   ├── pos_repository.dart         ← abstract; the seam described above
    │   ├── pos_repository_impl.dart
    │   └── pos_exception.dart
    ├── payment/
    │   ├── pos_payment_handler.dart    ← host implements: card / EDC / CDCP
    │   ├── qris_gateway.dart           ← host implements: generate + check (DUKPT is native)
    │   └── payment_result.dart
    ├── state/                          ← Riverpod controllers, one per bounded concern
    ├── ui/
    │   ├── pages/                      ← 20 screens, each thin
    │   └── widgets/                    ← the shared widget library
    └── util/                           ← the helper layer
```

---

## Public API

The host app never imports `src/`. The whole surface is:

```dart
await CashupPos.initialize(
  PosConfig(
    baseUrl: 'https://api.example.com/',
    tokenProvider: () async => await myAuth.posToken(),
    merchant: PosMerchant(name: 'Toko Maju', address: 'Jl. Sudirman 1'),
    paymentHandler: MyEdcPaymentHandler(),   // card / EDC / CDCP
    qrisGateway: MyQrisGateway(),            // optional; omit to hide QRIS
    theme: PosTheme.cashup(),
    locale: const Locale('id', 'ID'),
  ),
);

// Anywhere in the host's navigation:
CashupPosLauncher.open(context);                 // full POS shell
CashupPosLauncher.openTransactions(context);     // deep-link to history
CashupPosLauncher.openProductManagement(context);
```

`CashupPos.initialize` builds a `ProviderContainer` internally; the host is not required to wrap its app in `ProviderScope`. `CashupPosLauncher` pushes an `UncontrolledProviderScope`, so SDK state is isolated from the host's own Riverpod graph.

---

## Calculation Engine — Fidelity Requirements

Ported function-for-function from `pos-core/src/main/java/com/cz/pos_core/util/TransactionCalculator.kt` (1 991 lines) and the `util/promotion/` package. Structure and naming are preserved so the Dart and Kotlin trees can be diffed by eye when the backend changes.

**Rounding semantics must be reproduced exactly.** The Kotlin code mixes three styles and the backend validates against all three:

| Kotlin | Dart counterpart | Note |
|---|---|---|
| `Math.round(x)`, `roundToInt()` | `jvmRound(x)` = `(x + 0.5).floorToDouble()` | Dart's `num.round()` breaks ties *away from zero*; Java breaks them toward positive infinity. Using `num.round()` would silently diverge for negative values. |
| `BigDecimal.setScale(n, HALF_UP)` | `setScale(x, n)` | Half-up on the absolute value. |
| `floor` / `ceil` | identical | — |

`BigDecimal` appears only inside `calculateItemTaxAmount` and the tax total. This port keeps `double` arithmetic and applies `setScale` at the same points; for money-magnitude inputs the results are identical.

**Engine invariants** (each is asserted by a ported test):
- `totalAmount = subTotal − discount − promotion + tax + serviceCharge ± rounding`
- `netAmount = grossAmount − totalDiscount − totalPromotion` (tax is *not* deducted)
- `taxAppliedAfterDiscount` is always `true`; each item's taxable base is reduced by its full deduction share.
- Promotion total can never exceed `subTotal − discount`.
- Service charge applies to `subTotal + tax`, before discount.
- Payment-settings rounding applies to **cash only**; cash additionally rounds serviceCharge, tax and total to whole rupiah.
- FREE `BUY_X_GET_Y` reward value uses the item's **post-discount** price; other reward types use net price per unit.
- `DISCOUNT_BY_ORDER`'s contribution is `Math.round`ed before it reaches `totalPromotionAmount`; other promo types are not.

**Every unit test in `pos-core/src/test/` is ported** — `TransactionCalculatorTest`, `TransactionCalculatorCombinationTest`, `TransactionCalculatorComputePerItemSavingsTest`, `DiscountByOrderEvaluatorTest`, `DiscountByItemSubtotalEvaluatorTest`, `PromotionOrchestratorTest`, `BuyXGetYEvaluatorTest`, `FreeRewardStrategyTest`, `PercentageRewardStrategyTest`, `AmountRewardStrategyTest`, `FixedPriceRewardStrategyTest`. They are the contract; a Dart-side change that breaks one is a regression against the backend.

---

## API Surface Consumed

Ported from `pos-core/src/main/java/com/cz/pos_core/data/network/PosService.kt`. All calls carry the merchant headers plus the bearer token from `PosConfig.tokenProvider`. Timeout 10 s, matching the Kotlin client.

| Method | Path |
|---|---|
| POST | `pos/auth/login` |
| GET | `pos/product/list` |
| GET | `pos/product/detail/{productId}` |
| POST | `pos/product/add` |
| PUT | `pos/product/update` |
| DELETE | `pos/product/delete/{productId}` |
| GET | `pos/product/{productId}/option-groups` |
| GET | `pos/product/{productId}/variants` |
| GET | `pos/product/{productId}/modifiers` |
| GET | `pos/category/list` |
| GET | `pos/category/detail/{categoryId}` |
| POST | `pos/category/single/add` |
| PUT | `pos/category/update` |
| DELETE | `pos/category/delete/{categoryId}` |
| PUT | `pos/stock/update` |
| GET | `pos/stock-movement/product/list` |
| GET | `pos/payment-setting` |
| POST | `pos/payment-setting/create` |
| PUT | `pos/payment-setting/update` |
| GET | `pos/payment-method/merchant/list` |
| POST | `pos/transaction/create` |
| GET | `pos/transaction/detail/{transactionId}` |
| GET | `pos/transaction/list` |
| PUT | `pos/transaction/update/{merchantTrxId}` |
| GET | `pos/summary-report/list` |
| GET | `pos/discount/available` |
| GET | `pos/promotion/active` |

---

## UI Architecture

Three rules govern every screen:

1. **Pages are thin.** A page composes widgets and reads state. It contains no formatting, no arithmetic, no networking. If a page exceeds ~200 lines, the excess belongs in a widget or a helper.
2. **Widgets are page-agnostic.** A widget in `ui/widgets/` takes plain data and callbacks — never a Riverpod `ref`, never a `PosProduct` where a `String` and a `double` suffice. That is what makes it reusable across pages.
3. **Helpers are pure.** Everything in `util/` is a pure function or an immutable value type — no `BuildContext`, no I/O — so it is testable without a widget tree.

### Shared Widget Library (`ui/widgets/`)

Built once, consumed by many pages. The "used by" column is the reuse justification; a widget that would serve only one page does not belong here.

| Widget | Used by |
|---|---|
| `PosScaffold` | every page — app bar, connectivity dot, consistent chrome |
| `PosPanel` | tablet split panes, cart, settings sections |
| `AsyncView<T>` | every page that loads — one implementation of loading / error / empty / data |
| `EmptyState`, `ErrorState`, `LoadingState` | inside `AsyncView`, plus inline use |
| `PagedListView<T>` | transactions, stock movement, product management |
| `PosProductTile` | product browse (grid + list), search, product management |
| `CategoryChipBar` | product browse, search, product edit |
| `CartLineTile` | cart page, tablet cart pane, reward selector |
| `QtyStepper` | cart line, variant sheet, stock update |
| `AmountRow` | cart totals, receipt, transaction detail, summary report |
| `TotalsPanel` | cart totals, transaction detail, receipt preview |
| `MoneyText` | everywhere an amount is displayed |
| `SearchField` | product browse, transactions, category picker |
| `NumericKeypad`, `NumericKeypadSheet` | cash payment, simple-amount mode, stock update, price override |
| `PosDialog`, `PosBottomSheet` | every dialog and sheet — one chrome, one dismiss behaviour |
| `StatusBadge` | transaction list, transaction detail |
| `SectionHeader` | settings, receipt config, summary report |
| `ImageThumb` | product tile, cart line, product detail |
| `OptionGroupSelector` | variant/modifier sheet, product edit |
| `PaymentMethodTile` | payment method page, quick-pay row |
| `DateRangeField` | transaction filter, stock movement, summary report |
| `ReceiptView` | receipt preview, transaction detail, reprint |

### Helper Layer (`util/`)

| Helper | Responsibility |
|---|---|
| `num_utils.dart` | `jvmRound`, `setScale`, `roundToIntegerForCash`, loose-JSON coercion |
| `currency.dart` | `Money.format(...)` over a **cached** `NumberFormat` — constructing one per build is a measurable cost on a product grid |
| `pos_date_utils.dart` | parses the five date shapes the backend emits; **cached** `DateFormat` instances |
| `responsive.dart` | `PosBreakpoints`, `PosLayout.of(context)` — the single source of "is this a tablet" |
| `debouncer.dart` | search input debounce |
| `cart_key.dart` | `buildCartKey(productId, variants, modifiers, customPrice, isPriceAdjustable)` — must match Kotlin exactly; it keys per-line savings |
| `calc_mappers.dart` | API model → calculator input (`toDiscountInput`, `toPromotionInputs`, `toCartItemData`) |
| `image_url.dart` | resolves a relative `imageUrl` against `meta.baseUrl` |

---

## Performance Budget

Stated as rules, because "prioritise performance" is only enforceable if it is specific. Each rule names the failure it prevents.

1. **Lists are always virtualised.** `ListView.builder` / `GridView.builder`, with `itemExtent` or `prototypeItem` wherever rows are uniform. Never a `Column` of N children inside a `SingleChildScrollView`. *Prevents:* laying out 500 products to show 8.
2. **Every `ref.watch` is narrowed with `select`.** A cart line watches only its own line; `TotalsPanel` watches only the totals record. *Prevents:* typing a quantity rebuilding all 40 cart rows.
3. **The calculation is memoised.** `calculateTransaction` is pure; the checkout provider caches its result against an input fingerprint (cart lines + discount + promotions + payment setting + payment method). A rebuild that does not change those inputs reuses the cached result. *Prevents:* re-running the promotion orchestrator on every scroll frame — it is the most expensive function in the SDK.
4. **Images decode at display size.** `Image.network` with explicit `cacheWidth` / `cacheHeight`. *Prevents:* decoding 1080p product photos into 96 px tiles.
5. **`RepaintBoundary` around grid tiles and the QRIS image.** *Prevents:* a polling status label repainting the whole QR bitmap every 3 s.
6. **`const` constructors wherever the widget has no dynamic input**, and named widget classes rather than builder closures for anything appearing in a list. *Prevents:* element-tree churn defeating `ListView.builder` recycling.
7. **Search is debounced 300 ms; server lists page at 20.** *Prevents:* a request per keystroke.
8. **The catalogue is fetched once per POS session.** Category filtering and search-within-loaded-page happen in memory via derived providers. *Prevents:* a network round-trip on every category chip tap.
9. **Dialog-local state uses `ValueNotifier`, not `setState`.** In the cash dialog only the change amount rebuilds as digits are typed, not the keypad's 12 buttons. *Prevents:* keypad latency on low-end EDC hardware.
10. **No `NumberFormat` or `DateFormat` construction inside `build`.** Both live as cached singletons in the helper layer.

---

## Screen Inventory

Twenty screens, merged from the phone and tablet Kotlin trees into one adaptive tree. Phone renders a single pane with a cart FAB; tablet renders the 60/40 split from `activity_pos_tablet_main.xml`.

| # | Page | Ported from |
|---|---|---|
| 1 | `PosHomePage` (shell, Simple ⇄ POS mode selector) | `PosTabletMainActivity`, `MainActivity` |
| 2 | `SimpleAmountPage` | `CalculatorActivity`, `PosAmountFragment` |
| 3 | `ProductBrowsePage` (grid/list, category filter, search) | `PosProductFragment`, `TabletProductsFragment` |
| 4 | `ProductVariantSheet` | `PosProductVariantBottomSheet`, `ProductVariantBottomSheet` |
| 5 | `CartPage` / tablet cart pane | `ProductCartActivity`, `TabletCartFragment` |
| 6 | `DiscountPickerSheet`, `PromotionPickerSheet`, `RewardSelectorSheet` | cart bottom sheets |
| 7 | `PaymentMethodPage` | `ListPaymentActivity` |
| 8 | `CashPaymentDialog` | `CashPaymentDialog` |
| 9 | `QrisPaymentDialog` | `QrisPaymentDialog` |
| 10 | `PaymentResultPage` | `ResultActivity` |
| 11 | `ReceiptPage` | `PosTransactionReceiptActivity`, `ReceiptTemplate` |
| 12 | `TransactionListPage` | `TransactionActivity` |
| 13 | `TransactionDetailPage` | `TransactionDetailActivity` |
| 14 | `StockMovementPage` | `StockMovementActivity` |
| 15 | `ManageProductPage` (list / add / edit / detail) | `ManageProductActivity` + fragments |
| 16 | `ManageCategoryPage` (list / add / edit / detail) | `ManageCategoryActivity` + fragments |
| 17 | `PaymentSettingPage` | `PaymentSettingActivity` |
| 18 | `ReceiptConfigPage` | `PosReceiptConfigActivity` |
| 19 | `SummaryReportPage` | `PosSummaryReportActivity` |
| 20 | `PosMenuPage` | `TabletMenuActivity` |

`SyncActivity` has no counterpart: with no local database there is nothing to sync. Its entry point becomes a catalogue refresh action on `PosMenuPage`.

---

## Testing Strategy

| Layer | Coverage |
|---|---|
| `calc/` | All 11 Kotlin test classes ported. Non-negotiable — they encode backend agreement. |
| `util/` | `jvmRound` vs `num.round()` divergence, `setScale` half-up, cart-key construction, date parsing across all five backend shapes. |
| `data/` | Repository against a mocked `Dio`: success, HTTP error, malformed payload. |
| `state/` | Cart controller (add / merge by cart key / decrement / stock guard), checkout memoisation (same inputs ⇒ no recompute). |
| `ui/` | Widget tests for the reusable library — `AsyncView` state matrix, `QtyStepper` bounds, `NumericKeypad` input rules, `AmountRow` formatting. |

---

## Risks

| Risk | Mitigation |
|---|---|
| Calculation drift from the backend | Ported tests are the gate; engine structure mirrors Kotlin file-for-file so backend changes can be diffed across both. |
| Pure-online failure mode | `PosRepository` seam allows a cached implementation later without touching UI or calculation. Documented above as an accepted product risk. |
| Double-charge on a lost `create` response | Surface an explicit retry prompt carrying the request's idempotency key; never auto-retry a write. |
| Kotlin tree keeps moving | This port targets `feature/pos-asg-phase3` at a fixed commit; the SHA is recorded in `README.md` so future syncs have a diff base. |
