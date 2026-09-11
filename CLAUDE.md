# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`cashup_pos` is a Flutter **package**, not an app. Host applications depend on it to gain a complete Point of Sale: the full UI (phone and tablet) plus the transaction calculation engine.

It is a port of an existing, shipping Kotlin implementation. That fact drives most of the rules below.

## Status

Implementation in progress. The plan's checkboxes are the progress record — a task whose steps are all `[x]` is done and committed; resume at the first unchecked task. `git log` confirms it (one `feat(...)` commit per task).

- `docs/superpowers/specs/2026-09-10-cashup-pos-flutter-sdk-design.md` — the design spec
- `docs/superpowers/plans/2026-09-10-cashup-pos-flutter-sdk.md` — 36-task implementation plan, TDD, checkbox steps

As of 2026-09-11, Tasks 1–10 are done: util helpers, all models, and the calculation engine up to transaction totals (`lib/src/calc/`). Nothing exists yet under `data/`, `payment/`, `config/`, `state/` or `ui/`.

**Read the plan before writing code.** Execute it with `superpowers:subagent-driven-development` or `superpowers:executing-plans`. Task numbers in the plan's headings are authoritative; the `[T##]` tags in its File Structure block are off by one for `data/` and `payment/`.

## Commands

```bash
flutter pub get
flutter analyze                                   # must be clean; warnings are failures
dart format lib test
flutter test                                      # whole suite
flutter test test/calc                            # engine only — the fast inner loop
flutter test test/calc/promotion/buyxgety/free_reward_strategy_test.dart   # single file
flutter test --plain-name 'rounds halves toward positive infinity'         # single test
flutter test --coverage
cd example && flutter run                         # manual verification against the demo host
```

Android builds of the example app need `JAVA_HOME` on **JDK 17**. The JBR bundled with Android Studio (25) breaks Gradle here.

## Source of truth

The calculation engine and every screen are ported from:

- Repo: `D:\gandha_cashup\projects\mobile-apps-cashlez`
- Branch: `origin/feature/pos-asg-phase3`
- Pinned commit: `33ddffdcc50aa8f9c6c53344bb4b269de5733064`
- Modules: `pos-core` (engine + data), `feature/pos` (phone UI), `feature/pos-tablet` (tablet UI), `feature/pos-shared`

Read the original without checking the branch out:

```bash
cd /d/gandha_cashup/projects/mobile-apps-cashlez
git show origin/feature/pos-asg-phase3:pos-core/src/main/java/com/cz/pos_core/util/TransactionCalculator.kt
git ls-tree -r --name-only origin/feature/pos-asg-phase3 -- pos-core/src/test
```

Dart file names deliberately mirror the Kotlin ones so the two trees can be diffed by eye when the backend changes. Do not restructure for elegance.

## Architecture

Four layers, dependencies pointing downward only:

```
ui/pages  →  state (Riverpod)  →  data (PosRepository)  →  PosApiClient (dio)  →  /pos/* backend
     ↓            ↓
ui/widgets     calc/ (pure)
     ↓
util/ (pure helpers)
```

- `calc/` imports nothing from `data/`, `state/` or `ui/`. Pure functions over plain data.
- `ui/widgets/` never takes a `WidgetRef`. Widgets receive data and callbacks, which is what makes them reusable across pages.
- `util/` imports nothing beyond `dart:` and `intl`. No `BuildContext`.
- `lib/cashup_pos.dart` is the **entire** public surface. Host apps must never import `package:cashup_pos/src/...`.

No codegen anywhere — serialization is hand-written, so host builds stay free of `build_runner`.

## Two decisions that shape everything

**1. Pure online.** No local database, no disk cache, no outbox. A dropped connection halts sales, and a `POST /pos/transaction/create` whose response is lost is indeterminate — the UI must prompt for retry rather than retrying silently, because a blind retry can double-charge. This was an explicit product decision; the `PosRepository` interface is the seam that lets a cached implementation be added later without touching UI, state or calculation code. Nothing above `data/` may reach past that interface to `PosApiClient`.

**2. The backend re-computes every amount and rejects mismatches.** The calculation engine is therefore not free to be cleaner than its source. Several redundant-looking steps are deliberate mirrors of backend quirks — for example per-item percentage discounts are rounded individually before summing, because an aggregate round diverges by a rupiah.

The trap that bites hardest: **never use Dart's `num.round()` inside `lib/src/calc/`.** It breaks ties away from zero; Java's `Math.round` breaks them toward positive infinity. Use `jvmRound` from `lib/src/util/num_utils.dart`. `BigDecimal.setScale(n, HALF_UP)` maps to `setScale`.

All 11 Kotlin test classes under `pos-core/src/test/` are ported into `test/calc/`. They encode agreement with the backend; a change that breaks one is a regression, not a stale test.

## Project skills

Two skills in `.claude/skills/` carry the detail and are the right thing to load before working:

- **`flutter-pos-dev`** — toolchain, layering rules, the shared widget library inventory, Riverpod conventions, the 10-rule performance budget, definition of done. Load it before writing or reviewing any Dart.
- **`pos-calc-parity`** — Kotlin source map, exact rounding semantics, engine invariants, how to prove a change did not drift. Load it before touching `lib/src/calc/`.

## Non-obvious conventions

- UI copy is Indonesian; identifiers and comments are English.
- Money strings in API payloads use `'0.00'` with a US decimal separator, and the wire keys differ from the Dart field names (`subTotal` → `grossAmount`, `discountAmount` → `totalDiscount`, `promotionAmount` → `totalPromotionAmount`, `promotionIds` → `appliedPromotionIds`). Null optional fields are omitted from payloads, not sent as `null`.
- A cart line is keyed by `cartKey`, not product id — the same product with different variants or an overridden price occupies separate lines, and the calculator keys per-line savings off it. The format must match Kotlin exactly.
- QRIS lives inside the SDK (dialog, QR rendering, 3 s polling); card/EDC/CDCP is delegated to the host through `PosPaymentHandler`. DUKPT decryption is native, so `QrisGateway` is host-implemented too.
- Dependencies are allowlisted: `flutter_riverpod`, `dio`, `intl`, `collection`, `qr_flutter`. Adding one needs a reason in the commit message.
