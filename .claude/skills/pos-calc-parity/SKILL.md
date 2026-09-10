---
name: pos-calc-parity
description: Use when touching anything under lib/src/calc/ — the transaction calculator, discount logic, tax, rounding, or the promotion evaluators. Explains where the Kotlin source of truth lives, the exact rounding semantics the backend validates against, and how to prove a change did not drift.
---

# POS Calculation Parity

The calculation engine is a port. The backend re-computes every amount the client sends and **rejects the transaction on mismatch**, so this code is not free to be "cleaner" than its source — it has to be equal.

## Source of Truth

Repository: `D:\gandha_cashup\projects\mobile-apps-cashlez`
Branch: `origin/feature/pos-asg-phase3`
Pinned commit: `33ddffdcc50aa8f9c6c53344bb4b269de5733064` (2026-09-07)

Read the original without checking the branch out:

```bash
cd /d/gandha_cashup/projects/mobile-apps-cashlez
git show origin/feature/pos-asg-phase3:pos-core/src/main/java/com/cz/pos_core/util/TransactionCalculator.kt
git show origin/feature/pos-asg-phase3:pos-core/src/main/java/com/cz/pos_core/util/promotion/PromotionOrchestrator.kt
git ls-tree -r --name-only origin/feature/pos-asg-phase3 -- pos-core/src/test
```

| Dart | Kotlin |
|---|---|
| `lib/src/calc/transaction_calculator.dart` | `pos-core/.../util/TransactionCalculator.kt` |
| `lib/src/calc/rounding_utils.dart` | `pos-core/.../util/RoundingUtils.kt` |
| `lib/src/calc/promotion/*` | `pos-core/.../util/promotion/*` |
| `lib/src/calc/promotion/buyxgety/*` | `pos-core/.../util/promotion/buyxgety/*` |
| `test/calc/*` | `pos-core/src/test/java/com/cz/pos_core/util/**` |

File and function names are deliberately kept parallel so the two trees can be diffed by eye when the backend changes.

## Rounding — The Part That Silently Breaks

| Kotlin | Dart | Trap |
|---|---|---|
| `Math.round(x)`, `roundToInt()`, `roundToLong()` | `jvmRound(x)` from `util/num_utils.dart` | **Never use Dart's `num.round()`.** It breaks ties *away from zero*; Java breaks them *toward positive infinity*. They differ on negatives. |
| `BigDecimal.setScale(n, HALF_UP)` | `setScale(x, n)` | Half-up on the absolute value. |
| `floor`, `ceil` | `floorToDouble()`, `ceilToDouble()` | Identical. |
| cash whole-rupiah rounding | `roundToIntegerForCash(x)` | `>= .5` up, else down. |

`BigDecimal` appears in the original only inside `calculateItemTaxAmount` and the tax total. The port uses `double` and applies `setScale` at the same points.

## Invariants

Each is asserted by a ported test. If a change breaks one, the change is wrong — not the test.

- `totalAmount = subTotal − discount − promotion + tax + serviceCharge ± rounding`
- `netAmount = grossAmount − totalDiscount − totalPromotion` — tax is **not** deducted
- `taxAppliedAfterDiscount` is always `true`; each item's taxable base drops by its full deduction share
- Promotion total can never exceed `subTotal − discount`
- Service charge applies to `subTotal + tax`, before discount
- Payment-settings rounding is **cash only**; cash additionally rounds serviceCharge, tax and total to whole rupiah
- FREE `BUY_X_GET_Y` reward value uses the item's **post-discount** price; other reward types use net price per unit
- `DISCOUNT_BY_ORDER`'s contribution is `jvmRound`ed before it reaches `totalPromotionAmount`; other promo types are not
- A physical unit qualifies at most one promotion, and is rewarded by at most one

## Changing This Code

1. Read the Kotlin function first. Do not infer it from the Dart.
2. Write the failing Dart test before the fix, mirroring the Kotlin test if one exists.
3. `flutter test test/calc` — the full engine suite, not just your file. The evaluators share helpers; a fix to one reward type has historically shifted another. That entanglement is exactly why the strategies are isolated.
4. If the change corrects a client/server mismatch, record the observed numbers in the test name or a comment — the Kotlin source does this and it is how past mismatches stayed fixed.
5. If the Kotlin side changed too, update the pinned commit at the top of this file.

## Do Not

- Do not "simplify" a redundant-looking calculation. Several are deliberate mirrors of backend quirks — for example per-item percentage discounts are rounded individually before summing, because the server does the same and an aggregate round diverges by a rupiah.
- Do not switch to a decimal library without re-running the whole parity suite.
- Do not let `calc/` import from `data/`, `state/` or `ui/`. It stays pure.
