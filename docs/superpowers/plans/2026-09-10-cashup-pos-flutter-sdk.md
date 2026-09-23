# Cashup POS Flutter SDK Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `cashup_pos`, a Flutter package that gives any host application a complete Point of Sale — full end-to-end UI plus a transaction calculation engine ported byte-for-byte from the existing Kotlin implementation.

**Architecture:** Four layers with downward-only dependencies: `ui/pages` → `state` (Riverpod) → `data` (`PosRepository` over dio) → backend; with `calc/` (pure calculation) and `util/` (pure helpers) as leaves that depend on nothing. The UI is one adaptive tree covering phone and tablet, built from a shared, page-agnostic widget library. The calculation engine mirrors the Kotlin file structure function-for-function so the two can be diffed when the backend changes.

**Tech Stack:** Flutter 3.47 / Dart 3.13, `flutter_riverpod` 2.6, `dio` 5.7, `intl` 0.20, `collection` 1.19, `qr_flutter` 4.1. No codegen, no `build_runner`.

**Spec:** `docs/superpowers/specs/2026-09-10-cashup-pos-flutter-sdk-design.md`

## Global Constraints

- **Source of truth:** `D:\gandha_cashup\projects\mobile-apps-cashlez`, branch `origin/feature/pos-asg-phase3`, pinned at commit `33ddffdcc50aa8f9c6c53344bb4b269de5733064`. Read files with `git show origin/feature/pos-asg-phase3:<path>` — never check the branch out.
- **Package name:** `cashup_pos`. Directory: `D:\gandha_cashup\projects\cashup_pos_flutter`.
- **Public surface:** `lib/cashup_pos.dart` only. Nothing under `lib/src/` is exported directly, and no host app may import `package:cashup_pos/src/...`.
- **No codegen.** Serialization is hand-written `fromJson` / `toJson`. No `build_runner`, no `freezed`, no `json_serializable`.
- **Dependency allowlist:** `flutter_riverpod`, `dio`, `intl`, `collection`, `qr_flutter`. Adding any other dependency requires an explicit decision recorded in the commit message.
- **Connectivity: pure online.** No local database, no disk cache, no outbox. All data access goes through the `PosRepository` interface so a cached implementation can be added later without touching UI, state, or calculation code.
- **Rounding:** use `jvmRound` from `lib/src/util/num_utils.dart` for every Kotlin `Math.round` / `roundToInt` / `roundToLong`. **Never** use Dart's `num.round()` in `lib/src/calc/` — it breaks ties away from zero, Java breaks them toward positive infinity.
- **Currency:** Indonesian Rupiah, `Locale('id', 'ID')`. All UI copy is Indonesian; identifiers and comments are English.
- **Every `ref.watch` is narrowed with `select`.** Watching a whole controller from inside a list row is a defect.
- **Every list is virtualised.** `ListView.builder` / `GridView.builder`, never a `Column` of N children in a `SingleChildScrollView`.
- **Quality gate for every task:** `flutter analyze` clean, `dart format lib test` applied, `flutter test` green.

---

## File Structure

**Already created by scaffolding (Task 1 verifies and tests them):**
```
pubspec.yaml                     ← deps pinned per allowlist above
lib/src/util/num_utils.dart      ← jvmRound, setScale, roundToIntegerForCash, JSON coercion
```

**To create:**
```
lib/
├── cashup_pos.dart                              ← public exports (Task 36 audits)
└── src/
    ├── cashup_pos_sdk.dart                      ← CashupPos.initialize, CashupPosLauncher   [T16]
    ├── config/
    │   ├── pos_config.dart                                                                   [T16]
    │   └── pos_theme.dart                                                                    [T16]
    ├── util/
    │   ├── num_utils.dart                       ← exists                                     [T1]
    │   ├── currency.dart                        ← cached NumberFormat                        [T1]
    │   ├── pos_date_utils.dart                  ← cached DateFormat, 5 backend shapes        [T1]
    │   ├── responsive.dart                      ← PosBreakpoints, PosLayout                  [T17]
    │   ├── debouncer.dart                                                                    [T18]
    │   ├── cart_key.dart                                                                     [T21]
    │   ├── image_url.dart                                                                    [T19]
    │   └── calc_mappers.dart                    ← API model → calculator input               [T22]
    ├── models/
    │   ├── paged_result.dart                                                                 [T2]
    │   ├── pos_category.dart                                                                 [T2]
    │   ├── pos_product.dart                                                                  [T2]
    │   ├── option_group.dart                                                                 [T2]
    │   ├── payment_setting.dart                                                              [T2]
    │   ├── pos_payment_method.dart                                                           [T2]
    │   ├── discount_item.dart                                                                [T3]
    │   ├── promotion_item.dart                                                               [T3]
    │   ├── transaction_details.dart                                                          [T3]
    │   ├── transaction_summary.dart                                                          [T3]
    │   ├── create_transaction_request.dart                                                   [T3]
    │   ├── stock_movement.dart                                                               [T3]
    │   └── summary_report.dart                                                               [T3]
    ├── calc/
    │   ├── rounding_utils.dart                                                               [T4]
    │   ├── calculator_models.dart                                                            [T4]
    │   ├── transaction_calculator.dart                                                       [T10,T11,T12]
    │   └── promotion/
    │       ├── evaluation_context.dart                                                       [T5]
    │       ├── promotion_evaluator.dart          ← interface + ItemPromoRole + shared fns     [T5]
    │       ├── discount_by_order_evaluator.dart                                              [T6]
    │       ├── discount_by_item_subtotal_evaluator.dart                                      [T6]
    │       ├── promotion_orchestrator.dart                                                   [T9]
    │       └── buyxgety/
    │           ├── reward_strategy.dart                                                      [T7]
    │           ├── free_reward_strategy.dart                                                 [T7]
    │           ├── percentage_reward_strategy.dart                                           [T7]
    │           ├── amount_reward_strategy.dart                                               [T7]
    │           ├── fixed_price_reward_strategy.dart                                          [T7]
    │           └── buy_x_get_y_evaluator.dart                                                [T8]
    ├── data/
    │   ├── pos_exception.dart                                                                [T14]
    │   ├── pos_api_client.dart                                                               [T14]
    │   ├── pos_repository.dart                                                               [T15]
    │   └── pos_repository_impl.dart                                                          [T15]
    ├── payment/
    │   ├── payment_result.dart                                                               [T16]
    │   ├── pos_payment_handler.dart                                                          [T16]
    │   └── qris_gateway.dart                                                                 [T16]
    ├── state/
    │   ├── pos_providers.dart                                                                [T20]
    │   ├── catalog_controller.dart                                                           [T20]
    │   ├── cart_controller.dart                                                              [T21]
    │   ├── checkout_controller.dart                                                          [T22]
    │   ├── transaction_controller.dart                                                       [T30]
    │   ├── product_admin_controller.dart                                                     [T31]
    │   ├── category_admin_controller.dart                                                    [T32]
    │   ├── payment_setting_controller.dart                                                   [T33]
    │   └── summary_controller.dart                                                           [T34]
    └── ui/
        ├── widgets/                              ← 22 shared widgets                  [T17,T18,T19]
        └── pages/                                ← 20 screens                          [T23..T35]
```

Widget-per-file, page-per-file. A page's private sub-widgets live in the page file until a second page needs them, at which point they move to `ui/widgets/`.

---

## Task 1: Foundation — helpers and formatting

**Files:**
- Verify: `pubspec.yaml`
- Verify: `lib/src/util/num_utils.dart`
- Create: `lib/src/util/currency.dart`
- Create: `lib/src/util/pos_date_utils.dart`
- Create: `analysis_options.yaml`
- Test: `test/util/num_utils_test.dart`
- Test: `test/util/currency_test.dart`
- Test: `test/util/pos_date_utils_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `double jvmRound(double)`, `double setScale(double, int)`, `double roundToIntegerForCash(double)`, `double atLeastZero(double)`, `double? asDouble(Object?)`, `int? asInt(Object?)`, `bool? asBool(Object?)`, `List<int> asIntList(Object?)`
  - `class Money { static String format(double amount, {bool withSymbol = true, int decimals = 0}); static String formatCompact(double amount); }`
  - `class PosDates { static DateTime? parse(String raw); static String display(DateTime d); static String time(DateTime d); static String apiDate(DateTime d); }`

- [x] **Step 1: Write the failing helper tests**

```dart
// test/util/num_utils_test.dart
import 'package:cashup_pos/src/util/num_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('jvmRound', () {
    test('rounds halves toward positive infinity like java.lang.Math.round', () {
      expect(jvmRound(2.5), 3.0);
      expect(jvmRound(2.4), 2.0);
      // The divergence that motivates this helper: Dart's num.round() gives -3.
      expect(jvmRound(-2.5), -2.0);
      expect((-2.5).round(), -3);
    });
  });

  group('setScale', () {
    test('rounds half up on the absolute value', () {
      expect(setScale(1.005, 2), 1.01);
      expect(setScale(2.344, 2), 2.34);
      expect(setScale(-1.005, 2), -1.01);
    });
  });

  group('roundToIntegerForCash', () {
    test('rounds up from a half rupiah, down below it', () {
      expect(roundToIntegerForCash(1805.5), 1806.0);
      expect(roundToIntegerForCash(1805.49), 1805.0);
    });
  });

  group('json coercion', () {
    test('accepts the numeric strings the backend sends', () {
      expect(asDouble('12500.00'), 12500.0);
      expect(asInt('3'), 3);
      expect(asBool('true'), isTrue);
      expect(asIntList(['1', 2]), [1, 2]);
    });
  });
}
```

```dart
// test/util/currency_test.dart
import 'package:cashup_pos/src/util/currency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats rupiah with Indonesian grouping and no decimals', () {
    expect(Money.format(1250000), 'Rp 1.250.000');
    expect(Money.format(0), 'Rp 0');
    expect(Money.format(-2500), '-Rp 2.500');
  });

  test('omits the symbol when asked', () {
    expect(Money.format(1250000, withSymbol: false), '1.250.000');
  });

  test('reuses one NumberFormat instance across calls', () {
    expect(identical(Money.debugFormatter, Money.debugFormatter), isTrue);
  });
}
```

```dart
// test/util/pos_date_utils_test.dart
import 'package:cashup_pos/src/util/pos_date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses every shape the backend emits', () {
    for (final raw in const [
      '2026-09-10T14:05:03',
      '2026-09-10T14:05:03Z',
      '2026-09-10 14:05:03',
      '2026-09-10T14:05:03.123',
      '2026-09-10T14:05:03.123Z',
    ]) {
      final parsed = PosDates.parse(raw);
      expect(parsed, isNotNull, reason: raw);
      expect(parsed!.year, 2026);
      expect(parsed.month, 9);
      expect(parsed.day, 10);
    }
  });

  test('returns null rather than throwing on junk', () {
    expect(PosDates.parse('not a date'), isNull);
  });
}
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/util`
Expected: FAIL — `currency.dart` and `pos_date_utils.dart` do not exist.

- [x] **Step 3: Create `analysis_options.yaml`**

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  errors:
    invalid_use_of_internal_member: error
    unused_import: error

linter:
  rules:
    - prefer_const_constructors
    - prefer_const_constructors_in_immutables
    - prefer_const_declarations
    - prefer_final_locals
    - avoid_unnecessary_containers
    - sized_box_for_whitespace
    - use_super_parameters
```

- [x] **Step 4: Implement `lib/src/util/currency.dart`**

```dart
import 'package:intl/intl.dart';

/// Rupiah formatting for the whole SDK.
///
/// The formatter is constructed once. Building a [NumberFormat] inside `build`
/// is a measurable cost on a product grid, so every caller comes through here.
class Money {
  Money._();

  static final NumberFormat _grouped = NumberFormat.decimalPattern('id_ID');

  /// Exposed only so a test can assert the instance is reused.
  static NumberFormat get debugFormatter => _grouped;

  /// Formats [amount] as `Rp 1.250.000`.
  ///
  /// Negative amounts render as `-Rp 2.500` — the sign leads, matching the
  /// receipt layout in the Kotlin original.
  static String format(double amount, {bool withSymbol = true, int decimals = 0}) {
    final negative = amount < 0;
    final magnitude = amount.abs();
    final digits = decimals == 0
        ? _grouped.format(magnitude.round())
        : NumberFormat.decimalPatternDigits(locale: 'id_ID', decimalDigits: decimals)
            .format(magnitude);
    final body = withSymbol ? 'Rp $digits' : digits;
    return negative ? '-$body' : body;
  }

  /// Short form for dense tablet panels: `Rp 1,2jt`.
  static String formatCompact(double amount) {
    final magnitude = amount.abs();
    final sign = amount < 0 ? '-' : '';
    if (magnitude >= 1000000) {
      return '${sign}Rp ${(magnitude / 1000000).toStringAsFixed(1).replaceAll('.', ',')}jt';
    }
    if (magnitude >= 1000) {
      return '${sign}Rp ${(magnitude / 1000).toStringAsFixed(0)}rb';
    }
    return format(amount);
  }
}
```

- [x] **Step 5: Implement `lib/src/util/pos_date_utils.dart`**

```dart
import 'package:intl/intl.dart';

/// Date parsing and display for the SDK.
///
/// The backend emits five different shapes for the same field (the Kotlin
/// `ReceiptTemplate` walks the same list), so parsing tries each in order.
/// All [DateFormat] instances are cached — constructing one per row is a
/// visible cost on a transaction list.
class PosDates {
  PosDates._();

  static const List<String> _patterns = [
    "yyyy-MM-dd'T'HH:mm:ss",
    "yyyy-MM-dd'T'HH:mm:ss'Z'",
    'yyyy-MM-dd HH:mm:ss',
    "yyyy-MM-dd'T'HH:mm:ss.SSS",
    "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
  ];

  static final Map<String, DateFormat> _parsers = {
    for (final p in _patterns) p: DateFormat(p, 'id_ID'),
  };
  static final DateFormat _display = DateFormat('dd MMM yyyy', 'id_ID');
  static final DateFormat _time = DateFormat('HH:mm:ss', 'id_ID');
  static final DateFormat _api = DateFormat('yyyy-MM-dd');
  static final DateFormat _apiDateTime = DateFormat("yyyy-MM-dd'T'HH:mm:ss");

  static DateTime? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final pattern in _patterns) {
      try {
        return _parsers[pattern]!.parseLoose(raw);
      } on FormatException {
        continue;
      }
    }
    return DateTime.tryParse(raw);
  }

  static String display(DateTime value) => _display.format(value);
  static String time(DateTime value) => _time.format(value);
  static String apiDate(DateTime value) => _api.format(value);
  static String apiDateTime(DateTime value) => _apiDateTime.format(value);

  /// Convenience for list rows: `10 Sep 2026 14:05:03`, or `-` when unparsable.
  static String displayRaw(String? raw) {
    final parsed = parse(raw);
    if (parsed == null) return '-';
    return '${_display.format(parsed)} ${_time.format(parsed)}';
  }
}
```

- [x] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/util` — Expected: PASS
Run: `flutter analyze` — Expected: no issues

- [x] **Step 7: Commit**

```bash
git add pubspec.yaml analysis_options.yaml lib/src/util test/util
git commit -m "feat(util): rounding, currency and date helpers with JVM-parity rounding"
```

---

## Task 2: Catalogue and settings models

**Files:**
- Create: `lib/src/models/paged_result.dart`
- Create: `lib/src/models/pos_category.dart`
- Create: `lib/src/models/pos_product.dart`
- Create: `lib/src/models/option_group.dart`
- Create: `lib/src/models/payment_setting.dart`
- Create: `lib/src/models/pos_payment_method.dart`
- Test: `test/models/catalog_models_test.dart`

**Kotlin source:** `pos-core/src/main/java/com/cz/pos_core/data/response/{PosProductListResponse,PosDetailProductResponse,PosCategoryResponse,ProductVariantModifierModels,PosPaymentSettingResponse,PosPaymentMethodListResponse}.kt`

**Interfaces:**
- Consumes: `asDouble`, `asInt`, `asBool`, `asIntList` from Task 1.
- Produces:
  - `class PagedResult<T> { final List<T> items; final String? baseUrl; final int page, size, totalElements, totalPages; }`
  - `class PosCategory { final int id; final String name; final String? imageUrl, description; }`
  - `class PosProduct { final int id; final String name; final String? sku, upc, imageUrl, imageThumbUrl, description; final double basePrice, finalPrice; final bool isPriceIncludeTax, isTaxable, isPriceAdjustable, isUnlimitedStock, hasModifiers; final PosTax? tax; final int qty; final List<PosCategory> categories; final List<PosProductImage> images; final String productType; bool get isVariant; bool get isSimple; List<int> get categoryIds; }`
  - `class PosTax { final int? taxId; final String? taxName; final double? taxPercentage, taxAmount; }`
  - `class VariantOption { final int id, variantGroupId; final String name, groupName; final double additionalPrice; }`
  - `class ModifierOption { final int id, productId, groupId; final String name, groupName; final double additionalPrice; }`
  - `class OptionItem { final int optionId; final int? variantId; final String name; final double priceAdjustment; final int qty; final bool isUnlimitedStock, isOptional; final int displayOrder; }`
  - `class OptionGroup { final int groupId; final String name, groupType; final String? selectionType; final bool isRequired, isCombinationMember; final int minSelection, maxSelection; final List<OptionItem> options; }`
  - `class ProductOptionGroups { final int productId; final String productType; final bool isPriceAdjustable; final List<OptionGroup> variantGroups, modifierGroups; }`
  - `class PaymentSetting { final int paymentSettingId; final bool isPriceIncludeTax, isRounding, isServiceCharge, isTax; final int roundingTarget; final String roundingType, taxName; final double serviceChargePercentage, serviceChargeAmount, taxPercentage; final String? receiptFooterText; }`
  - `class PosPaymentMethod { final String code, name; final String? category, paymentType, provider; final int displayOrder; }`

- [x] **Step 1: Write the failing model test**

```dart
// test/models/catalog_models_test.dart
import 'package:cashup_pos/src/models/pos_product.dart';
import 'package:cashup_pos/src/models/payment_setting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PosProduct tolerates the loose typing the backend sends', () {
    final product = PosProduct.fromJson(const {
      'id': 12,
      'name': 'Kopi Susu',
      'basePrice': '18000.00',      // string, not number
      'isTaxable': 'true',          // string, not bool
      'qty': 5,
      'productType': 'SIMPLE',
      'categories': [
        {'id': 3, 'name': 'Minuman'}
      ],
      'tax': {'taxId': 1, 'taxName': 'PPN', 'taxPercentage': 11},
    });

    expect(product.id, 12);
    expect(product.basePrice, 18000.0);
    expect(product.isTaxable, isTrue);
    expect(product.categoryIds, [3]);
    expect(product.tax!.taxPercentage, 11.0);
    expect(product.isSimple, isTrue);
  });

  test('PosProduct falls back to productImages when imageUrl is absent', () {
    final product = PosProduct.fromJson(const {
      'id': 1,
      'name': 'Teh',
      'productImages': [
        {'id': 9, 'fullImage': '/img/full.png', 'thumbImage': '/img/thumb.png'}
      ],
    });
    expect(product.effectiveImageUrl, '/img/full.png');
    expect(product.effectiveThumbUrl, '/img/thumb.png');
  });

  test('PaymentSetting round-trips through json', () {
    const json = {
      'paymentSettingId': 4,
      'isPriceIncludeTax': false,
      'isRounding': true,
      'roundingTarget': 100,
      'roundingType': 'CEILING',
      'isServiceCharge': true,
      'serviceChargePercentage': 5.0,
      'serviceChargeAmount': 0.0,
      'isTax': true,
      'taxPercentage': 11.0,
      'taxName': 'PPN',
    };
    final setting = PaymentSetting.fromJson(json);
    expect(setting.roundingType, 'CEILING');
    expect(PaymentSetting.fromJson(setting.toJson()).roundingTarget, 100);
  });
}
```

- [x] **Step 2: Run the test to verify it fails**

Run: `flutter test test/models/catalog_models_test.dart`
Expected: FAIL — models do not exist.

- [x] **Step 3: Implement the models**

Read each Kotlin data class and mirror its fields, keeping the backend's JSON keys. Example, showing the required shape — every other model follows it:

```dart
// lib/src/models/pos_product.dart
import '../util/num_utils.dart';
import 'pos_category.dart';

class PosTax {
  const PosTax({this.taxId, this.taxName, this.taxPercentage, this.taxAmount});

  final int? taxId;
  final String? taxName;
  final double? taxPercentage;
  final double? taxAmount;

  factory PosTax.fromJson(Map<String, dynamic> json) => PosTax(
        taxId: asInt(json['taxId']),
        taxName: json['taxName'] as String?,
        taxPercentage: asDouble(json['taxPercentage']),
        taxAmount: asDouble(json['taxAmount']),
      );

  Map<String, dynamic> toJson() => {
        'taxId': taxId,
        'taxName': taxName,
        'taxPercentage': taxPercentage,
        'taxAmount': taxAmount,
      };
}

class PosProductImage {
  const PosProductImage({this.id, this.thumbImage, this.fullImage});

  final int? id;
  final String? thumbImage;
  final String? fullImage;

  factory PosProductImage.fromJson(Map<String, dynamic> json) => PosProductImage(
        id: asInt(json['id']),
        thumbImage: json['thumbImage'] as String?,
        fullImage: json['fullImage'] as String?,
      );
}

class PosProduct {
  const PosProduct({
    required this.id,
    required this.name,
    this.sku,
    this.upc,
    this.imageUrl,
    this.imageThumbUrl,
    this.description,
    this.basePrice = 0,
    this.finalPrice = 0,
    this.isPriceIncludeTax = false,
    this.isTaxable = false,
    this.isPriceAdjustable = false,
    this.isUnlimitedStock = false,
    this.hasModifiers = false,
    this.tax,
    this.qty = 0,
    this.categories = const [],
    this.images = const [],
    this.productType = typeSimple,
  });

  static const String typeSimple = 'SIMPLE';
  static const String typeVariant = 'VARIANT';
  static const String typeModifier = 'MODIFIER';

  final int id;
  final String name;
  final String? sku;
  final String? upc;
  final String? imageUrl;
  final String? imageThumbUrl;
  final String? description;
  final double basePrice;
  final double finalPrice;
  final bool isPriceIncludeTax;
  final bool isTaxable;
  final bool isPriceAdjustable;
  final bool isUnlimitedStock;
  final bool hasModifiers;
  final PosTax? tax;
  final int qty;
  final List<PosCategory> categories;
  final List<PosProductImage> images;
  final String productType;

  bool get isVariant => productType == typeVariant;
  bool get isModifier => productType == typeModifier;
  bool get isSimple => productType == typeSimple;

  List<int> get categoryIds =>
      categories.map((c) => c.id).toList(growable: false);

  /// Mirrors `ProductItem.getEffectiveImageUrl()`: the flat field wins, then
  /// the first entry of `productImages`.
  String? get effectiveImageUrl {
    final flat = imageUrl;
    if (flat != null && flat.isNotEmpty) return flat;
    return images.isEmpty ? null : images.first.fullImage;
  }

  String? get effectiveThumbUrl {
    final flat = imageThumbUrl;
    if (flat != null && flat.isNotEmpty) return flat;
    return images.isEmpty ? null : images.first.thumbImage;
  }

  factory PosProduct.fromJson(Map<String, dynamic> json) => PosProduct(
        id: asInt(json['id']) ?? 0,
        name: json['name'] as String? ?? '',
        sku: json['sku'] as String?,
        upc: json['upc'] as String?,
        imageUrl: json['imageUrl'] as String?,
        imageThumbUrl: json['imageThumbUrl'] as String?,
        description: json['description'] as String?,
        basePrice: asDouble(json['basePrice']) ?? 0,
        finalPrice: asDouble(json['finalPrice']) ?? asDouble(json['basePrice']) ?? 0,
        isPriceIncludeTax: asBool(json['isPriceIncludeTax']) ?? false,
        isTaxable: asBool(json['isTaxable']) ?? false,
        isPriceAdjustable: asBool(json['isPriceAdjustable']) ?? false,
        isUnlimitedStock: asBool(json['isUnlimitedStock']) ?? false,
        hasModifiers: asBool(json['hasModifiers']) ?? false,
        tax: json['tax'] == null
            ? null
            : PosTax.fromJson(Map<String, dynamic>.from(json['tax'] as Map)),
        qty: asInt(json['qty']) ?? 0,
        categories: (json['categories'] as List?)
                ?.map((e) => PosCategory.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList(growable: false) ??
            const [],
        images: (json['productImages'] as List?)
                ?.map((e) => PosProductImage.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList(growable: false) ??
            const [],
        productType: json['productType'] as String? ?? typeSimple,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sku': sku,
        'upc': upc,
        'imageUrl': imageUrl,
        'imageThumbUrl': imageThumbUrl,
        'description': description,
        'basePrice': basePrice,
        'finalPrice': finalPrice,
        'isPriceIncludeTax': isPriceIncludeTax,
        'isTaxable': isTaxable,
        'isPriceAdjustable': isPriceAdjustable,
        'isUnlimitedStock': isUnlimitedStock,
        'hasModifiers': hasModifiers,
        'tax': tax?.toJson(),
        'qty': qty,
        'categories': categories.map((c) => c.toJson()).toList(),
        'productType': productType,
      };
}
```

Apply the same pattern to `PosCategory`, `OptionGroup` / `OptionItem` / `VariantOption` / `ModifierOption` / `ProductOptionGroups`, `PaymentSetting`, `PosPaymentMethod`, and `PagedResult<T>`.

`PagedResult<T>` takes a `T Function(Map<String, dynamic>)` item parser and reads `data`, `meta.baseUrl`, `page`, `size`, `totalElements`, `totalPages`.

Do **not** port `DummyVariantDataProvider` — it is test scaffolding from the Kotlin tree and has no place in a shipped SDK.

- [x] **Step 4: Run the test to verify it passes**

Run: `flutter test test/models/catalog_models_test.dart` — Expected: PASS

- [x] **Step 5: Commit**

```bash
git add lib/src/models test/models
git commit -m "feat(models): catalogue, option group and payment setting models"
```

---

## Task 3: Transaction, discount, promotion and report models

**Files:**
- Create: `lib/src/models/discount_item.dart`
- Create: `lib/src/models/promotion_item.dart`
- Create: `lib/src/models/transaction_details.dart`
- Create: `lib/src/models/transaction_summary.dart`
- Create: `lib/src/models/create_transaction_request.dart`
- Create: `lib/src/models/stock_movement.dart`
- Create: `lib/src/models/summary_report.dart`
- Test: `test/models/transaction_models_test.dart`

**Kotlin source:** `pos-core/.../data/response/{PosDiscountPromotionResponse,PosDetailTransactionResponse,PosTransactionListResponse,PosStockMovementResponse,PosSummaryReportResponse}.kt` and `pos-core/.../data/request/{PosCreateTransactionRequest,PosUpdateTransactionRequest}.kt`

**Interfaces:**
- Consumes: Task 1 coercion helpers.
- Produces:
  - `class DiscountItem { final int id; final String name, valueType, scope; final double value, minPurchase; final double? maxDiscountAmount; final List<int> categoryIds, targetProductIds; final int? usageRemaining; }`
  - `class PromotionItem { final int id; final String name, promoType; final int priority; final bool canCombine, isMultiplied; final String? valueType, rewardType, rewardValueType; final double? value, maxDiscountAmount, rewardValue, rewardDiscountValue; final double minPurchase; final int? buyQty, rewardQty; final List<int> buyProductIds, buyCategoryIds, rewardProductIds, rewardCategoryIds; final PromotionSchedule? schedule; }`
  - `class PromotionSchedule { final List<String> activeDays; final String? startTime, endTime, startDate, endDate; }`
  - `class TransactionDetails { final int transactionId; final String code, status, paymentMethod, transactionDate; final bool priceIncludeTax; final String? queueNumber, notes; final TransactionPricing? pricing; final TransactionDiscountInfo? discount; final double cashTendered, cashChange; final List<TransactionLine> transactionItems; final List<PaymentEntry> payments; }` plus the convenience getters from the Kotlin original (`grossAmount`, `totalTax`, `totalServiceCharge`, `totalRounding`, `totalAmount`, `discountAmount`, `promotionAmount`, `discountName`, `serviceChargePercentage`)
  - `class TransactionPricing`, `class TransactionDiscountInfo`, `class PaymentEntry`, `class TransactionLine` (with `variantSummary`, `modifierSummary`, `detailSummary`), `class TransactionLineDetail`
  - `class TransactionSummaryRow { final int? id; final String? code, trxId, paymentMethod, status, totalAmount, transactionDate, queueNumber; }`
  - `class CreateTransactionRequest`, `class RequestTransactionItem`, `class RequestItemDetail`, `class ItemDiscountDetail`, `class ItemPromotionDetail`, `class ItemPromotionMeta`, `class ItemTaxDetail`, `class PaymentSettingRequest`, `class ServiceChargeRequest`, `class UpdateTransactionRequest`
  - `class StockMovementRow`, `class SummaryReportData`, `class ProductSummaryRow`, `class PaymentSummaryRow`

**Critical JSON key mappings** — the Dart field name and the wire key differ, and the backend rejects the wrong key:

| Dart field | JSON key |
|---|---|
| `CreateTransactionRequest.subTotal` | `grossAmount` |
| `CreateTransactionRequest.discountAmount` | `totalDiscount` |
| `CreateTransactionRequest.promotionAmount` | `totalPromotionAmount` |
| `CreateTransactionRequest.promotionIds` | `appliedPromotionIds` |
| `PromotionItem.minPurchase` | `minimumSubtotal` |
| `PromotionItem.rewardQty` | `rewardQty` (maps to the calculator's `getQty`) |

- [x] **Step 1: Write the failing test**

```dart
// test/models/transaction_models_test.dart
import 'package:cashup_pos/src/models/create_transaction_request.dart';
import 'package:cashup_pos/src/models/promotion_item.dart';
import 'package:cashup_pos/src/models/transaction_details.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CreateTransactionRequest serializes to the wire keys the backend expects', () {
    const request = CreateTransactionRequest(
      paymentMethod: 'CASH',
      subTotal: '50000.00',
      netAmount: '45000.00',
      discountAmount: '5000.00',
      promotionAmount: null,
      totalServiceCharge: '0.00',
      totalTax: '4950.00',
      totalRounding: '0.00',
      totalAmount: '49950.00',
      transactionItems: [],
      promotionIds: [7],
    );

    final json = request.toJson();
    expect(json['grossAmount'], '50000.00');
    expect(json['totalDiscount'], '5000.00');
    expect(json['appliedPromotionIds'], [7]);
    expect(json.containsKey('totalPromotionAmount'), isFalse,
        reason: 'null promotion amount must be omitted, not sent as null');
  });

  test('PromotionItem reads minimumSubtotal into minPurchase', () {
    final promo = PromotionItem.fromJson(const {
      'id': 7,
      'name': 'Diskon Ceria',
      'promoType': 'DISCOUNT_BY_ORDER',
      'minimumSubtotal': 100000,
      'rewardQty': 2,
      'buyProducts': [
        {'id': 3, 'name': 'Kopi'}
      ],
    });
    expect(promo.minPurchase, 100000.0);
    expect(promo.rewardQty, 2);
    expect(promo.buyProductIds, [3], reason: 'ids fall back to the object array');
  });

  test('TransactionDetails exposes pricing through convenience getters', () {
    final details = TransactionDetails.fromJson(const {
      'transactionId': 1,
      'code': 'TRX-1',
      'status': 'COMPLETED',
      'paymentMethod': 'CASH',
      'transactionDate': '2026-09-10T10:00:00',
      'pricing': {'grossAmount': 50000, 'taxTotal': 5000, 'totalAmount': 55000},
    });
    expect(details.grossAmount, 50000.0);
    expect(details.totalTax, 5000.0);
    expect(details.totalAmount, 55000.0);
  });
}
```

- [x] **Step 2: Run the test to verify it fails**

Run: `flutter test test/models/transaction_models_test.dart` — Expected: FAIL, models missing.

- [x] **Step 3: Implement the models**

Follow the Task 2 pattern. Two rules specific to this task:

1. `toJson()` **omits null optional fields** rather than emitting `null` — the Kotlin client uses Gson defaults which drop nulls, and the backend validator treats an explicit `null` differently from an absent key. Build the map then `..removeWhere((_, v) => v == null)` for the optional block only.
2. `PromotionItem.fromJson` reproduces the id fallback from `PosCartViewModel.toPromotionInputs`: `buyProductIds` if non-empty, else ids extracted from `buyProducts`; same for categories and rewards.

- [x] **Step 4: Run the test to verify it passes**

Run: `flutter test test/models` — Expected: PASS

- [x] **Step 5: Commit**

```bash
git add lib/src/models test/models
git commit -m "feat(models): transaction, discount, promotion and report models"
```

---

## Task 4: Calculator value types and rounding

**Files:**
- Create: `lib/src/calc/rounding_utils.dart`
- Create: `lib/src/calc/calculator_models.dart`
- Test: `test/calc/rounding_utils_test.dart`

**Kotlin source:** `pos-core/.../util/RoundingUtils.kt`; the nested data classes at the top of `TransactionCalculator.kt`.

**Interfaces:**
- Consumes: `jvmRound` from Task 1.
- Produces:
  - `class RoundingUtils { static double applyRounding({required double amount, required int target, required String type}); static double calculateRoundingAdjustment(double original, double rounded); }`
  - `class CartItemData` — fields: `productId` (int), `productName` (String), `price` (double, the effective price), `basePrice` (double), `quantity` (int), `taxAmountPerUnit` (double), `isTaxable` (bool), `taxId` (int?), `taxName` (String?), `taxPercentage` (double?), `variantId` (int?), `selectedVariants` (`List<VariantOption>`), `selectedModifiers` (`List<ModifierOption>`), `categoryIds` (`List<int>`), `cartKey` (String), `isPriceAdjustable` (bool), `isPriceOverride` (bool); plus `CartItemData copyWith({int? quantity})` and `double get lineSubtotal => price * quantity`
  - `class DiscountInput` — `discountId` (int?), `name` (String), `valueType` (String), `value` (double), `maxDiscountAmount` (double?), `minPurchase` (double), `scope` (String), `eligibleProductIds` (`List<int>`), `eligibleCategoryIds` (`List<int>`)
  - `class PromotionInput` — every field from the Kotlin `PromotionInput`, with `getQty` named exactly that (it is fed from `PromotionItem.rewardQty`), plus `selectedRewardQtyMap` (`Map<String, int>`), `activeDays` (`List<String>`), `activeStartTime`, `activeEndTime`
  - `class TaxBreakdown { final int? taxId; final String taxName; final double taxPercentage, amount; }`
  - `class TransactionCalculationInput { final List<CartItemData> cartItems; final PaymentSetting? paymentSettings; final String paymentMethod; final bool priceIncludeTax; final DiscountInput? discountInput; final List<PromotionInput> promotions; }`
  - `class TransactionCalculationResult { final double subTotal, discountAmount, promotionAmount, serviceCharge, tax, rounding, totalAmount; final List<RequestTransactionItem> transactionItems; final List<TaxBreakdown> taxBreakdowns; final List<int> appliedPromotionIds; final Map<int, double> perPromoAmounts; }`
  - `class PerItemSavingsResult { final Map<String, double> savings; final Map<String, String> labels; }`

All of these are immutable with `const` constructors where possible. `CartItemData` implements `==`/`hashCode` over all fields — the checkout memoisation fingerprint in Task 22 depends on it.

- [x] **Step 1: Write the failing rounding test**

```dart
// test/calc/rounding_utils_test.dart
import 'package:cashup_pos/src/calc/rounding_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('applyRounding', () {
    test('FLOOR rounds down to the target multiple', () {
      expect(RoundingUtils.applyRounding(amount: 10450, target: 100, type: 'FLOOR'), 10400);
    });
    test('CEILING rounds up to the target multiple', () {
      expect(RoundingUtils.applyRounding(amount: 10450, target: 100, type: 'CEILING'), 10500);
    });
    test('ROUND picks the nearest multiple, halves going up', () {
      expect(RoundingUtils.applyRounding(amount: 10450, target: 100, type: 'ROUND'), 10500);
      expect(RoundingUtils.applyRounding(amount: 10440, target: 100, type: 'ROUND'), 10400);
    });
    test('NONE and a non-positive target leave the amount untouched', () {
      expect(RoundingUtils.applyRounding(amount: 10450, target: 100, type: 'NONE'), 10450);
      expect(RoundingUtils.applyRounding(amount: 10450, target: 0, type: 'CEILING'), 10450);
    });
    test('the type is matched case-insensitively', () {
      expect(RoundingUtils.applyRounding(amount: 10450, target: 100, type: 'ceiling'), 10500);
    });
  });

  test('calculateRoundingAdjustment reports the signed delta', () {
    expect(RoundingUtils.calculateRoundingAdjustment(10450, 10500), 50);
    expect(RoundingUtils.calculateRoundingAdjustment(10450, 10400), -50);
  });
}
```

- [x] **Step 2: Run the test to verify it fails**

Run: `flutter test test/calc/rounding_utils_test.dart` — Expected: FAIL.

- [x] **Step 3: Implement `rounding_utils.dart`**

```dart
import '../util/num_utils.dart';

/// Total-amount rounding, ported from `RoundingUtils.kt`.
///
/// `ROUND` uses [jvmRound] rather than Dart's `num.round()` so ties break the
/// same way the backend breaks them.
class RoundingUtils {
  RoundingUtils._();

  static double applyRounding({
    required double amount,
    required int target,
    required String type,
  }) {
    if (target <= 0) return amount;
    switch (type.toUpperCase()) {
      case 'FLOOR':
        return (amount / target).floorToDouble() * target;
      case 'CEILING':
        return (amount / target).ceilToDouble() * target;
      case 'ROUND':
        return jvmRound(amount / target) * target;
      case 'NONE':
      default:
        return amount;
    }
  }

  static double calculateRoundingAdjustment(double originalAmount, double roundedAmount) =>
      roundedAmount - originalAmount;
}
```

- [x] **Step 4: Implement `calculator_models.dart`**

Port each nested data class from the top of `TransactionCalculator.kt`, preserving field names and defaults exactly. Keep the doc comments — they record backend behaviour and are the reason several fields exist.

- [x] **Step 5: Run the test to verify it passes**

Run: `flutter test test/calc` — Expected: PASS

- [x] **Step 6: Commit**

```bash
git add lib/src/calc test/calc
git commit -m "feat(calc): rounding utils and calculator value types"
```

---

## Task 5: Promotion evaluation context and shared evaluator helpers

**Files:**
- Create: `lib/src/calc/promotion/evaluation_context.dart`
- Create: `lib/src/calc/promotion/promotion_evaluator.dart`
- Test: `test/calc/promotion/promotion_evaluator_helpers_test.dart`

**Kotlin source:** `pos-core/.../util/promotion/EvaluationContext.kt`, `PromotionEvaluator.kt`

**Interfaces:**
- Consumes: `CartItemData`, `DiscountInput`, `PromotionInput` (Task 4).
- Produces:
  - `class EvaluationContext { final List<CartItemData> cartItems, originalCartItems; final DiscountInput? discountInput; final double totalDiscountAmt, subTotal; final Set<String> freeItemCartKeys; final Map<String, int> freeQtyByCartKey; final Map<String, double> discountPerCartKey; EvaluationContext copyWith({List<CartItemData>? cartItems, double? subTotal}); }`
  - `abstract class PromotionEvaluator { double evaluate(PromotionInput promo, EvaluationContext ctx); Map<String, double> perItemDeduction(PromotionInput promo, EvaluationContext ctx); List<ItemPromoRole> itemRole(PromotionInput promo, CartItemData item, EvaluationContext ctx); }`
  - `class ItemPromoRole { final int promotionId; final String promoType, role; final double amt; final int? buyQty, getQty; ItemPromoRole copyWith({double? amt}); }` — `role` is `'QUALIFIER'` or `'REWARD'`
  - `List<CartItemData> filterItemsByScope(List<CartItemData> cartItems, String scope, List<int> productIds, List<int> categoryIds)`
  - `double netPricePerUnit(CartItemData item, EvaluationContext ctx, {Set<String>? freeItemCartKeys, bool roundAmountDiscount = false})`
  - `double computeItemDiscountAmt(CartItemData item, DiscountInput discountInput, double totalDiscountAmt, List<CartItemData> cartItems, {Set<String> freeItemCartKeys = const {}, bool roundAmountDiscount = true})`

- [x] **Step 1: Write the failing helper test**

```dart
// test/calc/promotion/promotion_evaluator_helpers_test.dart
import 'package:cashup_pos/src/calc/calculator_models.dart';
import 'package:cashup_pos/src/calc/promotion/evaluation_context.dart';
import 'package:cashup_pos/src/calc/promotion/promotion_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

CartItemData item(int id, double price, int qty, {List<int> categories = const []}) =>
    CartItemData(
      productId: id,
      productName: 'P$id',
      price: price,
      quantity: qty,
      categoryIds: categories,
      cartKey: '$id',
    );

void main() {
  group('filterItemsByScope', () {
    final cart = [item(1, 10000, 1, categories: [5]), item(2, 20000, 1)];

    test('ALL returns every line', () {
      expect(filterItemsByScope(cart, 'ALL', const [], const []).length, 2);
    });
    test('PRODUCT keeps only listed product ids', () {
      expect(filterItemsByScope(cart, 'PRODUCT', const [2], const []).single.productId, 2);
    });
    test('CATEGORY keeps lines with a matching category', () {
      expect(filterItemsByScope(cart, 'CATEGORY', const [], const [5]).single.productId, 1);
    });
  });

  group('computeItemDiscountAmt', () {
    test('AMOUNT scope=ALL distributes proportionally and rounds each share', () {
      final cart = [item(1, 10000, 1), item(2, 20000, 1)];
      const discount = DiscountInput(valueType: 'AMOUNT', value: 5000, scope: 'ALL');
      // 10000/30000 * 5000 = 1666.67 -> 1667 (Math.round on the share)
      expect(computeItemDiscountAmt(cart[0], discount, 5000, cart), 1667.0);
    });

    test('the raw share is used when rounding is suppressed for tax bases', () {
      final cart = [item(1, 10000, 1), item(2, 20000, 1)];
      const discount = DiscountInput(valueType: 'AMOUNT', value: 5000, scope: 'ALL');
      expect(
        computeItemDiscountAmt(cart[0], discount, 5000, cart, roundAmountDiscount: false),
        closeTo(1666.666, 0.001),
      );
    });

    test('a fully free line takes no discount share', () {
      final cart = [item(1, 10000, 1), item(2, 20000, 1)];
      const discount = DiscountInput(valueType: 'AMOUNT', value: 5000, scope: 'ALL');
      expect(
        computeItemDiscountAmt(cart[0], discount, 5000, cart, freeItemCartKeys: {'1'}),
        0.0,
      );
    });
  });
}
```

- [x] **Step 2: Run the test to verify it fails**

Run: `flutter test test/calc/promotion` — Expected: FAIL.

- [x] **Step 3: Implement `evaluation_context.dart` and `promotion_evaluator.dart`**

Port from the Kotlin verbatim. The two helper functions are the ones every evaluator shares; keep the doc comments explaining *why* `originalCartItems` is the denominator (claimed-unit reductions must not inflate other items' shares).

- [x] **Step 4: Run the test to verify it passes**

Run: `flutter test test/calc/promotion` — Expected: PASS

- [x] **Step 5: Commit**

```bash
git add lib/src/calc/promotion test/calc/promotion
git commit -m "feat(calc): promotion evaluation context and shared evaluator helpers"
```

---

## Task 6: DISCOUNT_BY_ORDER and DISCOUNT_BY_ITEM_SUBTOTAL evaluators

**Files:**
- Create: `lib/src/calc/promotion/discount_by_order_evaluator.dart`
- Create: `lib/src/calc/promotion/discount_by_item_subtotal_evaluator.dart`
- Test: `test/calc/promotion/discount_by_order_evaluator_test.dart`
- Test: `test/calc/promotion/discount_by_item_subtotal_evaluator_test.dart`

**Kotlin source:** `DiscountByOrderEvaluator.kt`, `DiscountByItemSubtotalEvaluator.kt`, and their tests at `pos-core/src/test/java/com/cz/pos_core/util/promotion/`.

**Interfaces:**
- Consumes: `PromotionEvaluator`, `EvaluationContext`, `filterItemsByScope`, `computeItemDiscountAmt` (Task 5).
- Produces: `class DiscountByOrderEvaluator implements PromotionEvaluator`, `class DiscountByItemSubtotalEvaluator implements PromotionEvaluator`.

- [x] **Step 1: Port the two Kotlin test classes**

Read them first — they are the specification:

```bash
cd /d/gandha_cashup/projects/mobile-apps-cashlez
git show origin/feature/pos-asg-phase3:pos-core/src/test/java/com/cz/pos_core/util/promotion/DiscountByOrderEvaluatorTest.kt
git show origin/feature/pos-asg-phase3:pos-core/src/test/java/com/cz/pos_core/util/promotion/DiscountByItemSubtotalEvaluatorTest.kt
```

Translate each `@Test` into a Dart `test(...)` with the same name and the same numbers. Do not "improve" the assertions — the numbers came from production mismatches.

- [x] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/calc/promotion` — Expected: FAIL, evaluators missing.

- [x] **Step 3: Implement both evaluators**

Port verbatim. Two behaviours that are easy to lose and that the tests catch:

- `DiscountByOrderEvaluator.computeEffectiveAmt` applies `jvmRound` to `min(evaluate(...), subTotal − totalDiscountAmt)`. The backend rounds this promo's contribution to whole rupiah before validating `netAmount`; no other promo type is rounded here.
- `DiscountByItemSubtotalEvaluator.perItemDeduction` rounds each item's PERCENTAGE amount individually (`jvmRound`) and only then applies the cap proportionally. Summing first and rounding once diverges by a rupiah.

- [x] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/calc/promotion` — Expected: PASS

- [x] **Step 5: Commit**

```bash
git add lib/src/calc/promotion test/calc/promotion
git commit -m "feat(calc): order and item-subtotal discount evaluators"
```

---

## Task 7: BUY_X_GET_Y reward strategies

**Files:**
- Create: `lib/src/calc/promotion/buyxgety/reward_strategy.dart`
- Create: `lib/src/calc/promotion/buyxgety/free_reward_strategy.dart`
- Create: `lib/src/calc/promotion/buyxgety/percentage_reward_strategy.dart`
- Create: `lib/src/calc/promotion/buyxgety/amount_reward_strategy.dart`
- Create: `lib/src/calc/promotion/buyxgety/fixed_price_reward_strategy.dart`
- Test: `test/calc/promotion/buyxgety/free_reward_strategy_test.dart`
- Test: `test/calc/promotion/buyxgety/percentage_reward_strategy_test.dart`
- Test: `test/calc/promotion/buyxgety/amount_reward_strategy_test.dart`
- Test: `test/calc/promotion/buyxgety/fixed_price_reward_strategy_test.dart`

**Kotlin source:** `pos-core/.../util/promotion/buyxgety/*.kt` and the four matching test classes.

**Interfaces:**
- Consumes: `EvaluationContext`, `netPricePerUnit`, `PromotionInput`.
- Produces:
  - `abstract class RewardStrategy { double calculateAmount(List<CartItemData> availableItems, int effectiveRewardQty, PromotionInput promo, EvaluationContext ctx); }`
  - `class FreeRewardStrategy`, `PercentageRewardStrategy`, `AmountRewardStrategy`, `FixedPriceRewardStrategy` — each a `const`-constructible singleton-style implementation.

**Why these are isolated:** in the Kotlin tree a fix to FREE repeatedly shifted PERCENTAGE and AMOUNT because they shared helpers. Keeping one file per reward type is the whole point; do not merge them.

- [x] **Step 1: Port the four Kotlin test classes**

```bash
cd /d/gandha_cashup/projects/mobile-apps-cashlez
for f in FreeRewardStrategyTest PercentageRewardStrategyTest AmountRewardStrategyTest FixedPriceRewardStrategyTest; do
  git show origin/feature/pos-asg-phase3:pos-core/src/test/java/com/cz/pos_core/util/promotion/buyxgety/$f.kt
done
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/calc/promotion/buyxgety` — Expected: FAIL.

- [x] **Step 3: Implement the four strategies**

The behaviour each test pins:

- **FREE** — reward value is the item's **post-discount** price, not gross. `FreeRewardStrategy.postDiscountPriceForFreeUnit` branches on the manual discount's `valueType`: PERCENTAGE derives the share from the eligible *effective* subtotal; AMOUNT divides `discountPerCartKey` by the original quantity. This was verified against a production rejection (client 77 623.00 vs server 77 105.24 — the 517.76 gap was exactly the discount's share of the reward item's gross price).
- **PERCENTAGE** — sorts candidates by `netPricePerUnit(..., roundAmountDiscount: true)`, sums the cheapest `effectiveRewardQty` units, then `jvmRound(subtotal * rewardValue / 100)`.
- **AMOUNT** — `min(rewardValue, netPricePerUnit(item))` per unit, cheapest first.
- **FIXED_PRICE** — `max(0, netPricePerUnit(item) − fixedPrice)` per unit, cheapest first.

- [x] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/calc/promotion/buyxgety` — Expected: PASS

- [x] **Step 5: Commit**

```bash
git add lib/src/calc/promotion/buyxgety test/calc/promotion/buyxgety
git commit -m "feat(calc): isolated buy-x-get-y reward strategies"
```

---

## Task 8: BuyXGetYEvaluator

**Files:**
- Create: `lib/src/calc/promotion/buyxgety/buy_x_get_y_evaluator.dart`
- Test: `test/calc/promotion/buyxgety/buy_x_get_y_evaluator_test.dart`

**Kotlin source:** `BuyXGetYEvaluator.kt` (332 lines) and `BuyXGetYEvaluatorTest.kt`.

**Interfaces:**
- Consumes: the four strategies (Task 7), `PromotionEvaluator` (Task 5).
- Produces: `class BuyXGetYEvaluator implements PromotionEvaluator` with the additional public method `Map<int, int> claimedRewardUnits(PromotionInput promo, EvaluationContext ctx)` — the orchestrator (Task 9) calls it to stop two promotions rewarding the same physical unit.

**The four private helpers must be ported exactly** — they encode the "who gets the reward" rules:

- `computeEffectiveRewardQty` — returns 0 unless the buy condition is met and enough reward units survive qualifier reservation; honours `isMultiplied` with a different multiplier for overlapping vs non-overlapping scopes.
- `computeAvailableRewardQty` — reserves `buyQty` units for the purchase condition, but only the shortfall that non-reward buy items cannot cover.
- `buildAvailableRewardItems` — subtracts reserved units for price selection; multi-line overlap reserves the **most expensive** first (they become qualifiers), leaving the cheapest available as rewards.
- `resolveRewardItems` — honours `selectedRewardQtyMap` only when `rewardScope != 'ALL'` and enough buy-scope quantity remains after the selection; otherwise falls back to the auto-selected pool.

- [x] **Step 1: Port `BuyXGetYEvaluatorTest.kt`**

```bash
cd /d/gandha_cashup/projects/mobile-apps-cashlez
git show origin/feature/pos-asg-phase3:pos-core/src/test/java/com/cz/pos_core/util/promotion/buyxgety/BuyXGetYEvaluatorTest.kt
```

- [x] **Step 2: Run to verify it fails**

Run: `flutter test test/calc/promotion/buyxgety/buy_x_get_y_evaluator_test.dart` — Expected: FAIL.

- [x] **Step 3: Implement the evaluator**

- [x] **Step 4: Run to verify it passes**

Run: `flutter test test/calc` — Expected: PASS (whole engine suite, not just this file — the shared helpers are exactly where regressions land).

- [x] **Step 5: Commit**

```bash
git add lib/src/calc/promotion/buyxgety test/calc/promotion/buyxgety
git commit -m "feat(calc): buy-x-get-y evaluator with qualifier reservation"
```

---

## Task 9: PromotionOrchestrator

**Files:**
- Create: `lib/src/calc/promotion/promotion_orchestrator.dart`
- Test: `test/calc/promotion/promotion_orchestrator_test.dart`

**Kotlin source:** `PromotionOrchestrator.kt` (207 lines) and `PromotionOrchestratorTest.kt`.

**Interfaces:**
- Consumes: all three evaluators.
- Produces:
  - `class PromotionEvaluationOutcome { final double totalAmount; final List<int> appliedIds; final Map<int, double> perPromoAmounts; }`
  - `class PromotionOrchestrator { PromotionEvaluationOutcome evaluateAll(List<PromotionInput> promotions, EvaluationContext baseCtx); Map<String, double> computeAllPerItemDeductions(List<PromotionInput> promotions, List<int> appliedIds, EvaluationContext ctx, [Map<int, double> perPromoAmounts = const {}]); List<ItemPromoRole> computeAllItemRoles(CartItemData item, List<PromotionInput> promotions, List<int> appliedIds, EvaluationContext ctx, [Map<int, double> perPromoAmounts = const {}]); }`

Kotlin returns a `Triple` from `evaluateAll`; Dart gets the named class above instead. Everything else keeps its Kotlin name.

**Ordering and bookkeeping rules to port exactly:**
1. Sort: FREE `BUY_X_GET_Y` first, then `priority` ascending, then `promotionId`.
2. Skip when `subTotal < minPurchase`, or the buy-scope quantity (minus consumed qualifiers) is below `buyQty`, or every reward unit is already claimed.
3. Only a **fully FREE** reward removes an item from the order: its gross price is subtracted from `subTotal` for subsequent promotions via `freeGrossExclusion`. Non-FREE reward types must **not** reduce a later promotion's base.
4. `jvmRound` is applied to `DISCOUNT_BY_ORDER`'s amount and nothing else.
5. Qualifier units are consumed for **all** reward types — one physical unit qualifies at most one promotion. Consumption is recorded once per promo application, not once per reward product in scope.
6. `canCombine == false` stops evaluation after that promo applies.
7. `computeAllPerItemDeductions` and `computeAllItemRoles` rescale `DISCOUNT_BY_ORDER`'s per-item shares to the authoritative sequential total from `perPromoAmounts`; other types keep scale 1.0.

- [x] **Step 1: Port `PromotionOrchestratorTest.kt`**

- [x] **Step 2: Run to verify it fails**

Run: `flutter test test/calc/promotion/promotion_orchestrator_test.dart` — Expected: FAIL.

- [x] **Step 3: Implement the orchestrator**

- [x] **Step 4: Run to verify it passes**

Run: `flutter test test/calc` — Expected: PASS

- [x] **Step 5: Commit**

```bash
git add lib/src/calc/promotion test/calc/promotion
git commit -m "feat(calc): promotion orchestrator with claimed-unit and qualifier tracking"
```

---

## Task 10: TransactionCalculator — totals

**Files:**
- Create: `lib/src/calc/transaction_calculator.dart`
- Test: `test/calc/transaction_calculator_test.dart`

**Kotlin source:** `TransactionCalculator.kt` — `calculateTransaction`, `calculateDiscountAmount`, `calculateItemTaxAmount`, `computeFreeQtyByCartKey`, `computeFreeItemCartKeys`, `computePerItemTotalDeductionByCartKey`, `buildDiscountPerCartKey`, `calculateCashPaymentWithRounding`, `getRoundedTotalAmountForDisplay`. Test: `TransactionCalculatorTest.kt`.

**Interfaces:**
- Consumes: `PromotionOrchestrator`, `RoundingUtils`, calculator value types.
- Produces:
  - `TransactionCalculationResult calculateTransaction(TransactionCalculationInput input)`
  - `({double total, double rounding}) calculateCashPaymentWithRounding(double originalTotal, PaymentSetting? paymentSettings)`
  - `double getRoundedTotalAmountForDisplay(TransactionCalculationResult result, {String paymentMethod = ''})`

Kotlin's `object TransactionCalculator` becomes a Dart class with a private constructor and static members, so call sites read the same.

**Order of operations — this sequence is the contract:**
1. `subTotal = Σ price × quantity`
2. Preliminary discount with no free quantities → used as promotion context and to seed `discountPerCartKey`
3. `orchestrator.evaluateAll` → promotion amount, applied ids, per-promo amounts
4. `freeQtyByCartKey` from applied FREE promos; `freeItemCartKeys` = lines where every unit is free
5. Final discount, now aware of free units
6. `effectivePromotionAmount = min(promotionAmount, max(0, subTotal − discountAmount))`
7. Per-item deductions for tax; tax = `setScale(Σ per-item tax, 2)`
8. Tax breakdowns grouped by `taxId`, excluding fully-free lines
9. Service charge on `(subTotal + tax)`
10. `totalAmount` — omits tax when `priceIncludeTax`
11. Payment-settings rounding, **cash only**
12. Cash whole-rupiah rounding of serviceCharge, tax and total; `rounding` recomputed against the unrounded base
13. Build `transactionItems`

- [x] **Step 1: Port `TransactionCalculatorTest.kt`**

```bash
cd /d/gandha_cashup/projects/mobile-apps-cashlez
git show origin/feature/pos-asg-phase3:pos-core/src/test/java/com/cz/pos_core/util/TransactionCalculatorTest.kt
```

- [x] **Step 2: Run to verify it fails**

Run: `flutter test test/calc/transaction_calculator_test.dart` — Expected: FAIL.

- [x] **Step 3: Implement the totals path**

- [x] **Step 4: Run to verify it passes**

Run: `flutter test test/calc` — Expected: PASS

- [x] **Step 5: Commit**

```bash
git add lib/src/calc test/calc
git commit -m "feat(calc): transaction totals with tax, service charge and cash rounding"
```

---

## Task 11: TransactionCalculator — payload builder

**Files:**
- Modify: `lib/src/calc/transaction_calculator.dart`
- Test: `test/calc/transaction_calculator_payload_test.dart`

**Kotlin source:** `buildTransactionPayload`, `buildItemsWithBreakdown`, `buildPaymentSettingRequest`, `buildVariantOptionIds`, `buildItemDetails`, `computeItemDiscountAmt`, `buildTransactionDetails`.

**Interfaces:**
- Consumes: Task 10 output plus the request models from Task 3.
- Produces:
  - `CreateTransactionRequest buildTransactionPayload({required TransactionCalculationResult result, required String paymentMethod, String cashTendered = '0', String cashChange = '0', int? queueNumber, bool priceIncludeTax = false, String? notes, int? discountId, List<int>? promotionIds, PaymentSetting? paymentSettings, DiscountInput? discountInput, List<PromotionInput> appliedPromotions = const [], List<CartItemData> cartItemsForBreakdown = const []})`
  - `TransactionDetails buildTransactionDetails({required TransactionCalculationResult result, required int transactionId, required String transactionCode, required String paymentMethod, int cashTendered = 0, int cashChange = 0, String? qrisInvoice, PaymentSetting? paymentSettings, String? notes})`

**Formatting rules the backend validates:**
- Money strings use `'0.00'` with a US decimal separator — build them with a cached `NumberFormat('0.00', 'en_US')`, never `toStringAsFixed` on a locale-sensitive formatter.
- `totalTax` in the payload comes from `result.tax` (the aggregate), never from summing the per-item rounded amounts.
- Non-cash `totalAmount` is recomputed from rounded components: `round(subTotal) − totalDeduction + round(serviceCharge) + round(rounding) + round(tax)`.
- Items are emitted sorted by their first discount amount ascending.
- `paymentSetting.taxAppliedAfterDiscount` is always `true`.

- [x] **Step 1: Write the failing payload test**

```dart
// test/calc/transaction_calculator_payload_test.dart
import 'package:cashup_pos/src/calc/calculator_models.dart';
import 'package:cashup_pos/src/calc/transaction_calculator.dart';
import 'package:cashup_pos/src/models/payment_setting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('payload money fields use US-decimal two-place strings', () {
    final result = TransactionCalculator.calculateTransaction(
      TransactionCalculationInput(
        cartItems: [
          CartItemData(
            productId: 1,
            productName: 'Kopi',
            price: 18000,
            quantity: 2,
            cartKey: '1',
          ),
        ],
        paymentSettings: null,
        paymentMethod: 'CASH',
      ),
    );

    final payload = TransactionCalculator.buildTransactionPayload(
      result: result,
      paymentMethod: 'CASH',
      cashTendered: '40000',
      cashChange: '4000',
    );

    final json = payload.toJson();
    expect(json['grossAmount'], '36000.00');
    expect(json['totalAmount'], '36000.00');
    expect(json['paymentSetting']['taxAppliedAfterDiscount'], isTrue);
  });

  test('service charge is emitted as a typed object only when enabled', () {
    const settings = PaymentSetting(
      paymentSettingId: 1,
      isPriceIncludeTax: false,
      isRounding: false,
      roundingTarget: 0,
      roundingType: 'NONE',
      isServiceCharge: true,
      serviceChargePercentage: 5,
      serviceChargeAmount: 0,
      isTax: false,
      taxPercentage: 0,
      taxName: 'none',
    );
    final result = TransactionCalculator.calculateTransaction(
      TransactionCalculationInput(
        cartItems: [
          CartItemData(productId: 1, productName: 'Kopi', price: 10000, quantity: 1, cartKey: '1'),
        ],
        paymentSettings: settings,
        paymentMethod: 'CARD',
      ),
    );
    final json = TransactionCalculator.buildTransactionPayload(
      result: result,
      paymentMethod: 'CARD',
      paymentSettings: settings,
    ).toJson();

    expect(json['paymentSetting']['serviceCharge'], {'type': 'PERCENTAGE', 'value': 5.0});
  });
}
```

- [x] **Step 2: Run to verify it fails**

Run: `flutter test test/calc/transaction_calculator_payload_test.dart` — Expected: FAIL.

- [x] **Step 3: Implement the payload builder**

- [x] **Step 4: Run to verify it passes**

Run: `flutter test test/calc` — Expected: PASS

- [x] **Step 5: Commit**

```bash
git add lib/src/calc test/calc
git commit -m "feat(calc): transaction payload builder with per-item breakdown"
```

---

## Task 12: TransactionCalculator — per-item savings and eligibility

**Files:**
- Modify: `lib/src/calc/transaction_calculator.dart`
- Test: `test/calc/transaction_calculator_savings_test.dart`
- Test: `test/calc/transaction_calculator_combination_test.dart`

**Kotlin source:** `computePerItemSavings`, `isDiscountEligible`, `isPromotionEligible`, `isScheduleActive`, `parseTimeToMinutes`. Tests: `TransactionCalculatorComputePerItemSavingsTest.kt`, `TransactionCalculatorCombinationTest.kt`.

**Interfaces:**
- Produces:
  - `PerItemSavingsResult computePerItemSavings(List<CartItemData> cartItems, DiscountInput? discountInput, List<PromotionInput> promotions)`
  - `bool isDiscountEligible(DiscountInput discount, List<CartItemData> cartItems, double subTotal)`
  - `bool isPromotionEligible(PromotionInput promo, List<CartItemData> cartItems, double subTotal, {DateTime? now})`

`isPromotionEligible` takes an injectable `now` — the Kotlin version reads the system clock, which makes the schedule branch untestable. Default to `DateTime.now()`.

**Note:** `computePerItemSavings` is **display-only** — it drives the per-line savings badge in the cart. It deliberately keeps its own FREE-reward attribution because the orchestrator's `computeAllPerItemDeductions` zeroes FREE items instead of attributing them. Do not "unify" the two; the Kotlin comment says the same.

- [x] **Step 1: Port both Kotlin test classes**

- [x] **Step 2: Run to verify they fail**

Run: `flutter test test/calc` — Expected: FAIL.

- [x] **Step 3: Implement savings and eligibility**

- [x] **Step 4: Run to verify they pass**

Run: `flutter test test/calc` — Expected: PASS. This is the point where the whole engine is done; the suite should now mirror all 11 Kotlin test classes.

- [x] **Step 5: Commit**

```bash
git add lib/src/calc test/calc
git commit -m "feat(calc): per-item savings badges and discount/promotion eligibility"
```

---

## Task 13: API client and error model

**Files:**
- Create: `lib/src/data/pos_exception.dart`
- Create: `lib/src/data/pos_api_client.dart`
- Test: `test/data/pos_api_client_test.dart`

**Kotlin source:** `pos-core/.../data/network/PosService.kt`, `pos-core/.../util/PosAuthInterceptor.kt`

**Interfaces:**
- Consumes: `PosConfig` is not yet defined (Task 16); this task takes its inputs as plain constructor parameters so it can be built and tested first.
- Produces:
  - `class PosException implements Exception { final PosErrorKind kind; final String message; final String? code; final int? statusCode; final Object? cause; }`
  - `enum PosErrorKind { network, timeout, unauthorized, server, badResponse, cancelled, unknown }`
  - `class PosApiClient { PosApiClient({required String baseUrl, required Future<String?> Function() tokenProvider, Map<String, String> Function()? extraHeaders, Dio? dio}); Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}); Future<Map<String, dynamic>> post(String path, {Object? body}); Future<Map<String, dynamic>> put(String path, {Object? body}); Future<Map<String, dynamic>> delete(String path); }`

**Rules:**
- Connect / receive / send timeouts are 10 s, matching `PosService.TIMEOUT_SECONDS`.
- The bearer token comes from `tokenProvider` on every request — never cached in the client, because the host owns refresh.
- A `DioException` is translated into a `PosException` at the client boundary. Nothing above `data/` ever sees a `DioException`.
- A non-2xx response, or a body whose `status` field is not a success code, raises `PosException` carrying the backend `message` so the UI can show it verbatim.

- [x] **Step 1: Write the failing client test**

```dart
// test/data/pos_api_client_test.dart
import 'package:cashup_pos/src/data/pos_api_client.dart';
import 'package:cashup_pos/src/data/pos_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream,
          Future<void>? cancelFuture) =>
      handler(options);
}

void main() {
  late Dio dio;

  PosApiClient clientWith(Future<ResponseBody> Function(RequestOptions) handler) {
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/'));
    dio.httpClientAdapter = _StubAdapter(handler);
    return PosApiClient(
      baseUrl: 'https://example.test/',
      tokenProvider: () async => 'token-123',
      dio: dio,
    );
  }

  test('attaches the bearer token from the provider on every call', () async {
    late RequestOptions seen;
    final client = clientWith((options) async {
      seen = options;
      return ResponseBody.fromString('{"status":"200","data":{}}', 200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
    });

    await client.get('pos/category/list');
    expect(seen.headers['Authorization'], 'Bearer token-123');
  });

  test('translates a 401 into an unauthorized PosException', () async {
    final client = clientWith((options) async =>
        ResponseBody.fromString('{"message":"token expired"}', 401,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]}));

    expect(
      () => client.get('pos/category/list'),
      throwsA(isA<PosException>()
          .having((e) => e.kind, 'kind', PosErrorKind.unauthorized)
          .having((e) => e.message, 'message', 'token expired')),
    );
  });

  test('translates a connection timeout into a timeout PosException', () async {
    final client = clientWith((options) async =>
        throw DioException.connectionTimeout(
            timeout: const Duration(seconds: 10), requestOptions: options));

    expect(
      () => client.get('pos/category/list'),
      throwsA(isA<PosException>().having((e) => e.kind, 'kind', PosErrorKind.timeout)),
    );
  });
}
```

- [x] **Step 2: Run to verify it fails**

Run: `flutter test test/data/pos_api_client_test.dart` — Expected: FAIL.

- [x] **Step 3: Implement `pos_exception.dart` then `pos_api_client.dart`**

`PosException.friendlyMessage` returns Indonesian copy per `kind`, because every page shows it:

```dart
String get friendlyMessage {
  switch (kind) {
    case PosErrorKind.network:
      return 'Tidak ada koneksi internet. POS memerlukan koneksi aktif.';
    case PosErrorKind.timeout:
      return 'Koneksi terlalu lama merespons. Coba lagi.';
    case PosErrorKind.unauthorized:
      return 'Sesi berakhir. Silakan masuk kembali.';
    case PosErrorKind.server:
      return message.isEmpty ? 'Server sedang bermasalah. Coba lagi.' : message;
    case PosErrorKind.badResponse:
      return 'Respons server tidak dikenali.';
    case PosErrorKind.cancelled:
      return 'Permintaan dibatalkan.';
    case PosErrorKind.unknown:
      return message.isEmpty ? 'Terjadi kesalahan. Coba lagi.' : message;
  }
}
```

- [x] **Step 4: Run to verify it passes**

Run: `flutter test test/data` — Expected: PASS

- [x] **Step 5: Commit**

```bash
git add lib/src/data test/data
git commit -m "feat(data): dio-backed api client with typed error translation"
```

---

## Task 14: PosRepository interface and online implementation

**Files:**
- Create: `lib/src/data/pos_repository.dart`
- Create: `lib/src/data/pos_repository_impl.dart`
- Test: `test/data/pos_repository_impl_test.dart`

**Kotlin source:** `pos-core/.../data/repositories/PosRepositoryImpl.kt` (752 lines) — but only the request/response shapes carry over; the `LiveData` plumbing does not.

**Interfaces:**
- Consumes: `PosApiClient` (Task 13), every model (Tasks 2–3).
- Produces: `abstract class PosRepository` with these members, and `class PosRepositoryImpl implements PosRepository`:

```dart
abstract class PosRepository {
  Future<PagedResult<PosProduct>> productList({
    int size = 100, int? categoryId, String? keyword,
    String? upc, String? sku, String? sortBy, String? sortDir,
  });
  Future<PosProduct> productDetail(int productId);
  Future<int> productCreate(PosProductDraft draft);
  Future<void> productUpdate(int productId, PosProductDraft draft);
  Future<void> productDelete(int productId);
  Future<ProductOptionGroups?> productOptionGroups(int productId);

  Future<PagedResult<PosCategory>> categoryList({int size = 100});
  Future<PosCategory> categoryDetail(int categoryId);
  Future<int> categoryCreate(PosCategoryDraft draft);
  Future<void> categoryUpdate(int categoryId, PosCategoryDraft draft);
  Future<void> categoryDelete(int categoryId);

  Future<void> stockUpdate({required int productId, required int qty, required String updateType});
  Future<PagedResult<StockMovementRow>> stockMovements({
    required int productId, required DateTime startDate, required DateTime endDate,
  });

  Future<PaymentSetting?> paymentSetting();
  Future<void> paymentSettingCreate(PaymentSetting setting);
  Future<void> paymentSettingUpdate(PaymentSetting setting);
  Future<List<PosPaymentMethod>> paymentMethods();

  Future<CreatedTransaction> transactionCreate(CreateTransactionRequest request);
  Future<TransactionDetails> transactionDetail(int transactionId);
  Future<void> transactionUpdate(String merchantTrxId, UpdateTransactionRequest request);
  Future<PagedResult<TransactionSummaryRow>> transactionList({
    required int page, required int size,
    required DateTime startDate, required DateTime endDate,
    String sortBy = 'transactionDate', String sortType = 'DESC',
  });

  Future<SummaryReportData> summaryReport({required DateTime startDate, required DateTime endDate});
  Future<List<DiscountItem>> discountList();
  Future<List<PromotionItem>> activePromotions();
}
```

Plus the small carriers: `class PosProductDraft`, `class PosCategoryDraft`, `class CreatedTransaction { final int id; final String trxId; final String? queueNumber; }`.

**This interface is the seam that keeps the pure-online decision reversible.** A future caching or outbox implementation implements the same abstract class and nothing above `data/` changes. Do not let UI or state code reach past it to `PosApiClient`.

- [x] **Step 1: Write the failing repository test**

```dart
// test/data/pos_repository_impl_test.dart
import 'package:cashup_pos/src/data/pos_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_api_client.dart'; // records paths, returns canned bodies

void main() {
  test('productList sends the documented query parameters', () async {
    final api = FakeApiClient({'pos/product/list': {'status': '200', 'data': []}});
    final repo = PosRepositoryImpl(api);

    await repo.productList(size: 50, categoryId: 3, keyword: 'kopi');

    expect(api.lastPath, 'pos/product/list');
    expect(api.lastQuery, containsPair('size', 50));
    expect(api.lastQuery, containsPair('categoryId', 3));
    expect(api.lastQuery, containsPair('keyword', 'kopi'));
  });

  test('productList maps the envelope into a PagedResult with the meta base url', () async {
    final api = FakeApiClient({
      'pos/product/list': {
        'status': '200',
        'meta': {'baseUrl': 'https://cdn.test/'},
        'data': [
          {'id': 1, 'name': 'Kopi', 'basePrice': 18000}
        ],
        'page': 0, 'size': 20, 'totalElements': 1, 'totalPages': 1,
      }
    });

    final page = await PosRepositoryImpl(api).productList();
    expect(page.items.single.name, 'Kopi');
    expect(page.baseUrl, 'https://cdn.test/');
    expect(page.totalPages, 1);
  });

  test('transactionCreate returns the created id and trx id', () async {
    final api = FakeApiClient({
      'pos/transaction/create': {
        'status': '200',
        'message': 'ok',
        'data': {'id': 91, 'trxId': 'TRX-91', 'queueNumber': '4'},
      }
    });

    final created = await PosRepositoryImpl(api).transactionCreate(sampleRequest());
    expect(created.id, 91);
    expect(created.trxId, 'TRX-91');
    expect(created.queueNumber, '4');
  });
}
```

Write `test/data/fake_api_client.dart` in the same step: it implements `PosApiClient`'s surface, records `lastPath` / `lastQuery` / `lastBody`, and returns the canned map for the requested path.

- [x] **Step 2: Run to verify it fails**

Run: `flutter test test/data/pos_repository_impl_test.dart` — Expected: FAIL.

- [x] **Step 3: Implement the interface and the online implementation**

Map every endpoint from the table in the spec. Each method unwraps the `{status, message, data}` envelope and throws `PosException(kind: badResponse)` when `data` is missing where required.

- [x] **Step 4: Run to verify it passes**

Run: `flutter test test/data` — Expected: PASS

- [x] **Step 5: Commit**

```bash
git add lib/src/data test/data
git commit -m "feat(data): PosRepository interface and online implementation"
```

---

## Task 15: Payment contracts

**Files:**
- Create: `lib/src/payment/payment_result.dart`
- Create: `lib/src/payment/pos_payment_handler.dart`
- Create: `lib/src/payment/qris_gateway.dart`
- Test: `test/payment/payment_result_test.dart`

**Interfaces:**
- Produces:

```dart
/// What the host reports back after running a card / EDC / CDCP payment.
class PosPaymentResult {
  const PosPaymentResult.success({required this.reference, this.approvalCode, this.cardMasked, this.raw});
  const PosPaymentResult.failed({required this.message, this.code, this.raw});
  const PosPaymentResult.cancelled();

  final String? reference;
  final String? approvalCode;
  final String? cardMasked;
  final String? message;
  final String? code;
  final Map<String, dynamic>? raw;

  bool get isSuccess;
  bool get isCancelled;
}

/// Implemented by the host application. The SDK calls this and waits.
abstract class PosPaymentHandler {
  /// Payment methods this host can actually execute, e.g. {'CARD', 'CDCP'}.
  Set<String> get supportedMethods;

  Future<PosPaymentResult> pay({
    required String method,
    required double amount,
    required String merchantTrxId,
    int? transactionId,
  });
}

/// Implemented by the host because the QR payload arrives DUKPT-encrypted and
/// decryption is native. The SDK owns the dialog, the QR rendering and the
/// polling loop; the host owns only these two calls.
abstract class QrisGateway {
  Future<QrisPayload> generate({required double amount, String? merchantTrxId});
  Future<QrisStatus> checkStatus({required String invoiceNumber, String? merchantTrxId});
}

class QrisPayload {
  const QrisPayload({required this.qrString, required this.invoiceNumber});
  final String qrString;
  final String invoiceNumber;
}

enum QrisStatus { pending, paid, failed, expired }
```

- [x] **Step 1: Write the failing test**

```dart
// test/payment/payment_result_test.dart
import 'package:cashup_pos/src/payment/payment_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('success carries a reference and reports isSuccess', () {
    const result = PosPaymentResult.success(reference: 'REF-1', approvalCode: '00');
    expect(result.isSuccess, isTrue);
    expect(result.isCancelled, isFalse);
    expect(result.reference, 'REF-1');
  });

  test('cancelled is neither success nor an error to report', () {
    const result = PosPaymentResult.cancelled();
    expect(result.isSuccess, isFalse);
    expect(result.isCancelled, isTrue);
  });

  test('failed carries the message the UI shows', () {
    const result = PosPaymentResult.failed(message: 'Kartu ditolak', code: '05');
    expect(result.isSuccess, isFalse);
    expect(result.message, 'Kartu ditolak');
  });
}
```

- [x] **Step 2: Run to verify it fails** — `flutter test test/payment`

- [x] **Step 3: Implement the three files**

- [x] **Step 4: Run to verify it passes** — `flutter test test/payment`

- [x] **Step 5: Commit**

```bash
git add lib/src/payment test/payment
git commit -m "feat(payment): host-implemented payment handler and QRIS gateway contracts"
```

---

## Task 16: Configuration, theme and SDK entry point

**Files:**
- Create: `lib/src/config/pos_config.dart`
- Create: `lib/src/config/pos_theme.dart`
- Create: `lib/src/cashup_pos_sdk.dart`
- Modify: `lib/cashup_pos.dart`
- Test: `test/config/pos_config_test.dart`

**Interfaces:**
- Consumes: `PosPaymentHandler`, `QrisGateway` (Task 15), `PosRepository` (Task 14).
- Produces:

```dart
class PosMerchant {
  const PosMerchant({required this.name, this.address, this.address2, this.logoAssetPath});
  final String name;
  final String? address;
  final String? address2;
  final String? logoAssetPath;
}

class PosFeatureFlags {
  const PosFeatureFlags({
    this.enableProductManagement = true,
    this.enableCategoryManagement = true,
    this.enableStockTracking = true,
    this.enableSummaryReport = true,
    this.enableQueueNumber = true,
    this.enableSimpleMode = true,
  });
  // ... fields
}

class PosConfig {
  const PosConfig({
    required this.baseUrl,
    required this.tokenProvider,
    required this.merchant,
    this.paymentHandler,
    this.qrisGateway,
    this.theme = const PosTheme.cashup(),
    this.features = const PosFeatureFlags(),
    this.locale = const Locale('id', 'ID'),
    this.extraHeaders,
    this.onTransactionCompleted,
  });
  // ... fields
}

class CashupPos {
  static Future<void> initialize(PosConfig config);
  static bool get isInitialized;
  static PosConfig get config;               // throws StateError when not initialized
  static ProviderContainer get container;    // internal use
  static Future<void> dispose();
}

class CashupPosLauncher {
  static Future<void> open(BuildContext context);
  static Future<void> openTransactions(BuildContext context);
  static Future<void> openProductManagement(BuildContext context);
  static Future<void> openSettings(BuildContext context);
}
```

`PosTheme` holds colour and spacing tokens ported from `feature/pos-tablet/src/main/res/values/pos_design_tokens.xml` and exposes `ThemeData toThemeData(Brightness)`. `PosTheme.cashup()` is the default; a host can supply its own.

Each launcher wraps its route in `UncontrolledProviderScope(container: CashupPos.container, child: ...)` so SDK state never touches the host's Riverpod graph.

- [x] **Step 1: Write the failing config test**

```dart
// test/config/pos_config_test.dart
import 'package:cashup_pos/cashup_pos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() async => CashupPos.dispose());

  test('accessing config before initialize is a clear StateError', () {
    expect(() => CashupPos.config, throwsA(isA<StateError>()));
    expect(CashupPos.isInitialized, isFalse);
  });

  test('initialize exposes the config and marks the sdk ready', () async {
    await CashupPos.initialize(PosConfig(
      baseUrl: 'https://example.test/',
      tokenProvider: () async => 'token',
      merchant: const PosMerchant(name: 'Toko Uji'),
    ));

    expect(CashupPos.isInitialized, isTrue);
    expect(CashupPos.config.merchant.name, 'Toko Uji');
  });

  test('a trailing slash is normalised onto the base url', () async {
    await CashupPos.initialize(PosConfig(
      baseUrl: 'https://example.test',
      tokenProvider: () async => null,
      merchant: const PosMerchant(name: 'Toko Uji'),
    ));
    expect(CashupPos.config.baseUrl, 'https://example.test/');
  });
}
```

- [x] **Step 2: Run to verify it fails** — `flutter test test/config`

- [x] **Step 3: Implement config, theme and the SDK entry point**

- [x] **Step 4: Export the public surface from `lib/cashup_pos.dart`**

```dart
library cashup_pos;

export 'src/cashup_pos_sdk.dart' show CashupPos, CashupPosLauncher;
export 'src/config/pos_config.dart';
export 'src/config/pos_theme.dart';
export 'src/payment/payment_result.dart';
export 'src/payment/pos_payment_handler.dart';
export 'src/payment/qris_gateway.dart';
export 'src/data/pos_exception.dart' show PosException, PosErrorKind;
export 'src/data/pos_repository.dart' show PosRepository;
export 'src/models/transaction_details.dart' show TransactionDetails;
```

- [x] **Step 5: Run to verify it passes** — `flutter test` (whole suite)

- [x] **Step 6: Commit**

```bash
git add lib test
git commit -m "feat(sdk): public entry point, configuration and theme tokens"
```

---

## Task 17: Widget library — layout and async foundations

**Files:**
- Create: `lib/src/util/responsive.dart`
- Create: `lib/src/ui/widgets/pos_scaffold.dart`
- Create: `lib/src/ui/widgets/pos_panel.dart`
- Create: `lib/src/ui/widgets/section_header.dart`
- Create: `lib/src/ui/widgets/loading_state.dart`
- Create: `lib/src/ui/widgets/empty_state.dart`
- Create: `lib/src/ui/widgets/error_state.dart`
- Create: `lib/src/ui/widgets/async_view.dart`
- Create: `lib/src/ui/widgets/money_text.dart`
- Create: `lib/src/ui/widgets/amount_row.dart`
- Create: `lib/src/ui/widgets/totals_panel.dart`
- Test: `test/ui/widgets/async_view_test.dart`
- Test: `test/ui/widgets/totals_panel_test.dart`

**Interfaces:**
- Consumes: `Money` (Task 1), `PosException` (Task 13), `PosTheme` (Task 16).
- Produces:

```dart
class PosBreakpoints { static const double tablet = 720; static const double wide = 1080; }

enum PosFormFactor { phone, tablet, wide }

class PosLayout {
  const PosLayout(this.formFactor, this.size);
  final PosFormFactor formFactor;
  final Size size;
  bool get isPhone; bool get isTablet; bool get isWide;
  int get productGridColumns;     // 2 / 3 / 4
  static PosLayout of(BuildContext context);
}

class PosScaffold extends StatelessWidget {
  const PosScaffold({super.key, required this.title, required this.body,
    this.actions, this.bottomBar, this.floatingActionButton,
    this.showConnectivityDot = false, this.onBack, this.padding});
}

class PosPanel extends StatelessWidget {
  const PosPanel({super.key, required this.child, this.title, this.trailing, this.padding});
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.trailing});
}

class LoadingState extends StatelessWidget { const LoadingState({super.key, this.message}); }
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.message, this.icon, this.action});
}
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry, this.code});
  factory ErrorState.fromException(Object error, {VoidCallback? onRetry});
}

/// The single loading/error/empty/data switch used by every page.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.data,
    this.onRetry, this.isEmpty, this.empty, this.loading});
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final bool Function(T data)? isEmpty;
}

class MoneyText extends StatelessWidget {
  const MoneyText(this.amount, {super.key, this.style, this.compact = false,
    this.withSymbol = true, this.negative = false});
}

/// One label/value row. Used by cart totals, receipt, transaction detail
/// and the summary report — the reason it lives in the shared library.
class AmountRow extends StatelessWidget {
  const AmountRow({super.key, required this.label, required this.amount,
    this.sublabel, this.emphasis = AmountEmphasis.normal, this.negative = false});
}

enum AmountEmphasis { normal, muted, strong, total }

class TotalsPanel extends StatelessWidget {
  const TotalsPanel({super.key, required this.rows, this.footer});
  final List<AmountRow> rows;
}
```

**Performance requirements for this task:** every widget here has a `const` constructor. `AsyncView` must not rebuild its data subtree when only the loading flag toggles — build the data branch from the `AsyncValue` directly rather than through a `StatefulWidget`.

- [x] **Step 1: Write the failing widget tests**

```dart
// test/ui/widgets/async_view_test.dart
import 'package:cashup_pos/src/ui/widgets/async_view.dart';
import 'package:cashup_pos/src/ui/widgets/empty_state.dart';
import 'package:cashup_pos/src/ui/widgets/error_state.dart';
import 'package:cashup_pos/src/ui/widgets/loading_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('shows the loading state while pending', (tester) async {
    await tester.pumpWidget(wrap(AsyncView<List<int>>(
      value: const AsyncValue.loading(),
      data: (_) => const Text('data'),
    )));
    expect(find.byType(LoadingState), findsOneWidget);
  });

  testWidgets('shows the error state with a retry action', (tester) async {
    var retried = false;
    await tester.pumpWidget(wrap(AsyncView<List<int>>(
      value: AsyncValue.error(Exception('boom'), StackTrace.empty),
      onRetry: () => retried = true,
      data: (_) => const Text('data'),
    )));
    expect(find.byType(ErrorState), findsOneWidget);
    await tester.tap(find.text('Coba Lagi'));
    expect(retried, isTrue);
  });

  testWidgets('shows the empty state when isEmpty reports true', (tester) async {
    await tester.pumpWidget(wrap(AsyncView<List<int>>(
      value: const AsyncValue.data(<int>[]),
      isEmpty: (items) => items.isEmpty,
      empty: const EmptyState(title: 'Kosong'),
      data: (_) => const Text('data'),
    )));
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('data'), findsNothing);
  });

  testWidgets('shows data when present and not empty', (tester) async {
    await tester.pumpWidget(wrap(AsyncView<List<int>>(
      value: const AsyncValue.data(<int>[1]),
      isEmpty: (items) => items.isEmpty,
      data: (_) => const Text('data'),
    )));
    expect(find.text('data'), findsOneWidget);
  });
}
```

```dart
// test/ui/widgets/totals_panel_test.dart
import 'package:cashup_pos/src/ui/widgets/amount_row.dart';
import 'package:cashup_pos/src/ui/widgets/totals_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders each row with rupiah formatting', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: TotalsPanel(rows: [
          AmountRow(label: 'Subtotal', amount: 36000),
          AmountRow(label: 'Diskon', amount: 5000, negative: true),
          AmountRow(label: 'TOTAL', amount: 31000, emphasis: AmountEmphasis.total),
        ]),
      ),
    ));

    expect(find.text('Rp 36.000'), findsOneWidget);
    expect(find.text('-Rp 5.000'), findsOneWidget);
    expect(find.text('Rp 31.000'), findsOneWidget);
  });
}
```

- [x] **Step 2: Run to verify they fail** — `flutter test test/ui`

- [x] **Step 3: Implement `responsive.dart` and the eleven widgets**

- [x] **Step 4: Run to verify they pass** — `flutter test test/ui`

- [x] **Step 5: Commit**

```bash
git add lib/src/ui/widgets lib/src/util/responsive.dart test/ui
git commit -m "feat(ui): shared layout, async-state and amount widgets"
```

---

## Task 18: Widget library — inputs and overlays

**Files:**
- Create: `lib/src/util/debouncer.dart`
- Create: `lib/src/ui/widgets/search_field.dart`
- Create: `lib/src/ui/widgets/qty_stepper.dart`
- Create: `lib/src/ui/widgets/numeric_keypad.dart`
- Create: `lib/src/ui/widgets/numeric_keypad_sheet.dart`
- Create: `lib/src/ui/widgets/pos_dialog.dart`
- Create: `lib/src/ui/widgets/pos_bottom_sheet.dart`
- Create: `lib/src/ui/widgets/date_range_field.dart`
- Create: `lib/src/ui/widgets/status_badge.dart`
- Test: `test/ui/widgets/qty_stepper_test.dart`
- Test: `test/ui/widgets/numeric_keypad_test.dart`
- Test: `test/util/debouncer_test.dart`

**Kotlin source:** `custom-component` `NumericKeypadBottomSheet` / `NumericKeypadConfig` / `SpecialKeyAction`, as used by `CashPaymentDialog`.

**Interfaces:**
- Produces:

```dart
class Debouncer {
  Debouncer({this.duration = const Duration(milliseconds: 300)});
  void run(VoidCallback action);
  void cancel();
  void dispose();
}

class SearchField extends StatefulWidget {
  const SearchField({super.key, required this.onChanged, this.hintText,
    this.initialValue, this.debounce = const Duration(milliseconds: 300),
    this.autofocus = false, this.onSubmitted});
}

class QtyStepper extends StatelessWidget {
  const QtyStepper({super.key, required this.value, required this.onChanged,
    this.min = 0, this.max, this.compact = false, this.onEditRequested});
}

class NumericKeypadConfig {
  const NumericKeypadConfig({this.maxLength = 12, this.allowDecimal = false,
    this.normalizeLeadingZero = true, this.specialKeyText = '00',
    this.specialKeyAction = SpecialKeyAction.append});
}

enum SpecialKeyAction { append, decimalPoint, none }

/// Digits-only keypad. Drives a [ValueNotifier<String>] so a keypress rebuilds
/// the amount label, not the twelve buttons.
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({super.key, required this.value,
    this.config = const NumericKeypadConfig(), this.onSubmit, this.submitLabel});
  final ValueNotifier<String> value;
}

Future<String?> showNumericKeypadSheet(BuildContext context, {
  required String title, String initialValue = '',
  NumericKeypadConfig config = const NumericKeypadConfig(),
  String? subtitle, String submitLabel = 'Simpan',
});

class PosDialog extends StatelessWidget {
  const PosDialog({super.key, required this.title, required this.child,
    this.actions, this.onClose, this.maxWidth = 420});
}

Future<T?> showPosBottomSheet<T>(BuildContext context, {
  required String title, required Widget Function(BuildContext) builder,
  bool isScrollControlled = true, double? maxHeightFactor,
});

class DateRangeField extends StatelessWidget {
  const DateRangeField({super.key, required this.start, required this.end,
    required this.onChanged, this.label});
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});   // PAID / PENDING / UNPAID / FAILED
}
```

- [x] **Step 1: Write the failing tests**

```dart
// test/ui/widgets/qty_stepper_test.dart
import 'package:cashup_pos/src/ui/widgets/qty_stepper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('increments and decrements within bounds', (tester) async {
    var value = 1;
    await tester.pumpWidget(StatefulBuilder(builder: (context, setState) {
      return MaterialApp(
        home: Scaffold(
          body: QtyStepper(
            value: value,
            min: 1,
            max: 3,
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      );
    }));

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(value, 2);

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(value, 1);

    // At the minimum the decrement is disabled, not merely ignored.
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(value, 1);
  });

  testWidgets('does not exceed max', (tester) async {
    var value = 3;
    await tester.pumpWidget(StatefulBuilder(builder: (context, setState) {
      return MaterialApp(
        home: Scaffold(
          body: QtyStepper(value: value, max: 3, onChanged: (n) => setState(() => value = n)),
        ),
      );
    }));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(value, 3);
  });
}
```

```dart
// test/ui/widgets/numeric_keypad_test.dart
import 'package:cashup_pos/src/ui/widgets/numeric_keypad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('appends digits, honours the 00 key and backspace', (tester) async {
    final value = ValueNotifier<String>('');
    addTearDown(value.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: NumericKeypad(value: value)),
    ));

    await tester.tap(find.text('5'));
    await tester.pump();
    expect(value.value, '5');

    await tester.tap(find.text('00'));
    await tester.pump();
    expect(value.value, '500');

    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    expect(value.value, '50');
  });

  testWidgets('normalises a leading zero', (tester) async {
    final value = ValueNotifier<String>('0');
    addTearDown(value.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: NumericKeypad(value: value))));

    await tester.tap(find.text('7'));
    await tester.pump();
    expect(value.value, '7');
  });

  testWidgets('stops at maxLength', (tester) async {
    final value = ValueNotifier<String>('12');
    addTearDown(value.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NumericKeypad(value: value, config: const NumericKeypadConfig(maxLength: 2)),
      ),
    ));
    await tester.tap(find.text('3'));
    await tester.pump();
    expect(value.value, '12');
  });
}
```

```dart
// test/util/debouncer_test.dart
import 'package:cashup_pos/src/util/debouncer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('only the last action within the window runs', (tester) async {
    final debouncer = Debouncer(duration: const Duration(milliseconds: 50));
    addTearDown(debouncer.dispose);

    final calls = <int>[];
    debouncer.run(() => calls.add(1));
    debouncer.run(() => calls.add(2));
    debouncer.run(() => calls.add(3));

    await tester.pump(const Duration(milliseconds: 80));
    expect(calls, [3]);
  });
}
```

- [x] **Step 2: Run to verify they fail** — `flutter test test/ui test/util`

- [x] **Step 3: Implement the helpers and widgets**

`NumericKeypad` builds its twelve buttons once as `const` children and wraps only the caller's amount display in a `ValueListenableBuilder`. That is the point of taking a `ValueNotifier` rather than a `String` plus callback.

- [x] **Step 4: Run to verify they pass** — `flutter test test/ui test/util`

- [x] **Step 5: Commit**

```bash
git add lib/src/ui/widgets lib/src/util/debouncer.dart test
git commit -m "feat(ui): search, quantity stepper, numeric keypad and overlay chrome"
```

---

## Task 19: Widget library — domain widgets

**Files:**
- Create: `lib/src/util/image_url.dart`
- Create: `lib/src/ui/widgets/image_thumb.dart`
- Create: `lib/src/ui/widgets/pos_product_tile.dart`
- Create: `lib/src/ui/widgets/category_chip_bar.dart`
- Create: `lib/src/ui/widgets/cart_line_tile.dart`
- Create: `lib/src/ui/widgets/payment_method_tile.dart`
- Create: `lib/src/ui/widgets/option_group_selector.dart`
- Create: `lib/src/ui/widgets/paged_list_view.dart`
- Test: `test/ui/widgets/pos_product_tile_test.dart`
- Test: `test/ui/widgets/paged_list_view_test.dart`
- Test: `test/util/image_url_test.dart`

**Interfaces:**
- Produces:

```dart
String? resolveImageUrl(String? relative, String? baseUrl);

/// Always decodes at display size — [width] and [height] feed cacheWidth /
/// cacheHeight. This is rule 4 of the performance budget.
class ImageThumb extends StatelessWidget {
  const ImageThumb({super.key, required this.url, required this.width,
    required this.height, this.borderRadius, this.placeholderIcon});
}

enum ProductTileLayout { grid, list }

/// Takes primitives, not a PosProduct, so product management and the browse
/// grid can both use it without either owning the other's model.
class PosProductTile extends StatelessWidget {
  const PosProductTile({super.key, required this.name, required this.price,
    required this.layout, this.imageUrl, this.sku, this.stockLabel,
    this.outOfStock = false, this.badgeLabel, this.quantityInCart = 0,
    this.onTap, this.onLongPress, this.trailing});
}

class CategoryChipBar extends StatelessWidget {
  const CategoryChipBar({super.key, required this.categories,
    required this.selectedId, required this.onSelected, this.allLabel = 'Semua'});
  final List<({int id, String name})> categories;
}

class CartLineTile extends StatelessWidget {
  const CartLineTile({super.key, required this.name, required this.unitPrice,
    required this.quantity, required this.lineTotal, this.optionsSummary,
    this.savingsAmount, this.savingsLabel, this.imageUrl, this.freeQty = 0,
    this.onQuantityChanged, this.onRemove, this.onTap});
}

class PaymentMethodTile extends StatelessWidget {
  const PaymentMethodTile({super.key, required this.name, required this.code,
    this.subtitle, this.iconAsset, this.enabled = true, this.onTap});
}

class OptionGroupSelection {
  const OptionGroupSelection({required this.groupId, required this.optionIds});
  final int groupId;
  final List<int> optionIds;
}

/// Renders variant and modifier groups with single/multi selection, min/max
/// enforcement and running price adjustment. Used by the add-to-cart sheet and
/// the product editor.
class OptionGroupSelector extends StatelessWidget {
  const OptionGroupSelector({super.key, required this.groups,
    required this.selections, required this.onChanged});
}

/// Infinite-scroll list with a loading / error footer. Backs transactions,
/// stock movement and product management.
class PagedListView<T> extends StatefulWidget {
  const PagedListView({super.key, required this.items, required this.itemBuilder,
    required this.hasMore, required this.onLoadMore, this.isLoadingMore = false,
    this.error, this.onRetry, this.itemExtent, this.separator,
    this.padding, this.onRefresh, this.emptyPlaceholder});
}
```

**Performance requirements for this task:** `PosProductTile` is wrapped in a `RepaintBoundary` at its root. `PagedListView` uses `ListView.builder` with `itemExtent` when the caller supplies one, and triggers `onLoadMore` from a scroll extent threshold rather than by building a sentinel item on every frame.

- [x] **Step 1: Write the failing tests**

```dart
// test/util/image_url_test.dart
import 'package:cashup_pos/src/util/image_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('joins a relative path onto the meta base url exactly once', () {
    expect(resolveImageUrl('/img/a.png', 'https://cdn.test/'), 'https://cdn.test/img/a.png');
    expect(resolveImageUrl('img/a.png', 'https://cdn.test'), 'https://cdn.test/img/a.png');
  });

  test('passes an absolute url through untouched', () {
    expect(resolveImageUrl('https://x.test/a.png', 'https://cdn.test/'), 'https://x.test/a.png');
  });

  test('returns null when either side is missing', () {
    expect(resolveImageUrl(null, 'https://cdn.test/'), isNull);
    expect(resolveImageUrl('/img/a.png', null), isNull);
  });
}
```

```dart
// test/ui/widgets/pos_product_tile_test.dart
import 'package:cashup_pos/src/ui/widgets/pos_product_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows name, price and the cart quantity badge', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: PosProductTile(
          name: 'Kopi Susu',
          price: 18000,
          layout: ProductTileLayout.grid,
          quantityInCart: 2,
        ),
      ),
    ));

    expect(find.text('Kopi Susu'), findsOneWidget);
    expect(find.text('Rp 18.000'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('disables the tap target when out of stock', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PosProductTile(
          name: 'Teh',
          price: 8000,
          layout: ProductTileLayout.grid,
          outOfStock: true,
          onTap: () => tapped = true,
        ),
      ),
    ));

    await tester.tap(find.text('Teh'));
    expect(tapped, isFalse);
    expect(find.text('Stok habis'), findsOneWidget);
  });

  testWidgets('is wrapped in a RepaintBoundary', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: PosProductTile(name: 'Teh', price: 8000, layout: ProductTileLayout.grid),
      ),
    ));
    expect(
      find.descendant(of: find.byType(PosProductTile), matching: find.byType(RepaintBoundary)),
      findsWidgets,
    );
  });
}
```

```dart
// test/ui/widgets/paged_list_view_test.dart
import 'package:cashup_pos/src/ui/widgets/paged_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('requests the next page when scrolled near the end', (tester) async {
    var loadMoreCalls = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PagedListView<int>(
          items: List.generate(30, (i) => i),
          itemExtent: 60,
          hasMore: true,
          onLoadMore: () => loadMoreCalls++,
          itemBuilder: (context, item, index) => SizedBox(height: 60, child: Text('row $item')),
        ),
      ),
    ));

    await tester.drag(find.byType(ListView), const Offset(0, -1600));
    await tester.pump();
    expect(loadMoreCalls, greaterThan(0));
  });

  testWidgets('shows the error footer with retry instead of loading', (tester) async {
    var retried = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PagedListView<int>(
          items: const [1, 2],
          hasMore: true,
          error: 'Gagal memuat',
          onRetry: () => retried = true,
          onLoadMore: () {},
          itemBuilder: (context, item, index) => Text('row $item'),
        ),
      ),
    ));

    expect(find.text('Gagal memuat'), findsOneWidget);
    await tester.tap(find.text('Coba Lagi'));
    expect(retried, isTrue);
  });
}
```

- [x] **Step 2: Run to verify they fail** — `flutter test test/ui test/util`

- [x] **Step 3: Implement the helper and the eight widgets**

- [x] **Step 4: Run to verify they pass** — `flutter test`

- [x] **Step 5: Commit**

```bash
git add lib/src/ui/widgets lib/src/util/image_url.dart test
git commit -m "feat(ui): product tile, cart line, option selector and paged list"
```

---

## Task 20: Catalogue state

**Files:**
- Create: `lib/src/state/pos_providers.dart`
- Create: `lib/src/state/catalog_controller.dart`
- Test: `test/state/catalog_controller_test.dart`

**Interfaces:**
- Consumes: `PosRepository` (Task 14), `PosConfig` (Task 16).
- Produces:

```dart
// pos_providers.dart
final posConfigProvider = Provider<PosConfig>((ref) => throw UnimplementedError());
final posApiClientProvider = Provider<PosApiClient>((ref) => ...);
final posRepositoryProvider = Provider<PosRepository>((ref) => PosRepositoryImpl(ref.watch(posApiClientProvider)));

// catalog_controller.dart
class CatalogState {
  const CatalogState({this.products = const [], this.categories = const [],
    this.baseUrl, this.selectedCategoryId, this.query = '', this.isGrid = true});
  List<PosProduct> get visibleProducts;   // category filter + query, in memory
}

class CatalogController extends AsyncNotifier<CatalogState> {
  Future<void> refresh();
  void selectCategory(int? categoryId);
  void setQuery(String query);
  void toggleLayout();
  Future<ProductOptionGroups?> optionGroups(int productId);
}

final catalogControllerProvider = AsyncNotifierProvider<CatalogController, CatalogState>(CatalogController.new);
final paymentSettingProvider = FutureProvider<PaymentSetting?>((ref) => ...);
final activeDiscountsProvider = FutureProvider<List<DiscountItem>>((ref) => ...);
final activePromotionsProvider = FutureProvider<List<PromotionItem>>((ref) => ...);
```

**Performance requirement:** `build()` fetches products and categories **once**. `selectCategory` and `setQuery` filter the already-loaded list in memory and never hit the network — that is rule 8 of the budget. `visibleProducts` is computed in the state class, not in a widget `build`.

- [x] **Step 1: Write the failing controller test**

```dart
// test/state/catalog_controller_test.dart
import 'package:cashup_pos/src/state/catalog_controller.dart';
import 'package:cashup_pos/src/state/pos_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/fake_repository.dart';

void main() {
  late FakeRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeRepository()
      ..products = [product(1, 'Kopi', categories: [10]), product(2, 'Teh', categories: [20])];
    container = ProviderContainer(overrides: [posRepositoryProvider.overrideValue(repo)]);
    addTearDown(container.dispose);
  });

  test('loads products and categories once', () async {
    await container.read(catalogControllerProvider.future);
    expect(repo.productListCalls, 1);
    expect(repo.categoryListCalls, 1);
  });

  test('selecting a category filters in memory without another request', () async {
    await container.read(catalogControllerProvider.future);
    container.read(catalogControllerProvider.notifier).selectCategory(20);
    await container.pump();

    final state = container.read(catalogControllerProvider).requireValue;
    expect(state.visibleProducts.single.name, 'Teh');
    expect(repo.productListCalls, 1, reason: 'filtering must not refetch');
  });

  test('the query filters by name and sku, case-insensitively', () async {
    await container.read(catalogControllerProvider.future);
    container.read(catalogControllerProvider.notifier).setQuery('kop');
    await container.pump();

    expect(
      container.read(catalogControllerProvider).requireValue.visibleProducts.single.name,
      'Kopi',
    );
    expect(repo.productListCalls, 1);
  });
}
```

Write `test/data/fake_repository.dart` in this step — an in-memory `PosRepository` that counts calls. Later state tasks reuse it.

- [x] **Step 2: Run to verify it fails** — `flutter test test/state`

- [x] **Step 3: Implement the providers and the controller**

- [x] **Step 4: Run to verify it passes** — `flutter test test/state`

- [x] **Step 5: Commit**

```bash
git add lib/src/state test/state test/data
git commit -m "feat(state): catalogue controller with in-memory filtering"
```

---

## Task 21: Cart state

**Files:**
- Create: `lib/src/util/cart_key.dart`
- Create: `lib/src/state/cart_controller.dart`
- Test: `test/util/cart_key_test.dart`
- Test: `test/state/cart_controller_test.dart`

**Kotlin source:** `feature/pos/.../ui/main/SharedPosViewModel.kt` — `CartItem`, `buildCartKey`, `addToCartWithOptions`, `updateCartQuantity`, `decrementCartQuantity`, `resetCart`.

**Interfaces:**
- Produces:

```dart
String buildCartKey({
  required int productId,
  List<VariantOption> variants = const [],
  List<ModifierOption> modifiers = const [],
  double? customBasePrice,
  bool isPriceAdjustable = false,
});

class PosCartLine {
  const PosCartLine({required this.product, required this.quantity,
    this.selectedVariants = const [], this.selectedModifiers = const [],
    this.customBasePrice, required this.cartKey});

  double get effectivePrice;   // (customBasePrice ?? basePrice) + variant adds + modifier adds
  String get displayName;      // "Kopi (Large)" — variants in parentheses
  String get optionsSummary;   // modifiers, comma separated
  double get lineTotal;
  PosCartLine copyWith({int? quantity});
}

class CartState {
  const CartState({this.lines = const {}, this.notes, this.customerName, this.queueNumber});
  final Map<String, PosCartLine> lines;
  int get totalQuantity;
  double get subTotal;
  bool get isEmpty;
}

class CartController extends Notifier<CartState> {
  String? add(PosProduct product, {List<VariantOption> variants = const [],
      List<ModifierOption> modifiers = const [], double? customBasePrice, int quantity = 1});
  void setQuantity(String cartKey, int quantity);
  void remove(String cartKey);
  void clear();
  void setNotes(String? notes);
}

final cartControllerProvider = NotifierProvider<CartController, CartState>(CartController.new);

/// Narrow selector so a row rebuilds only for its own line.
final cartLineProvider = Provider.family<PosCartLine?, String>((ref, cartKey) =>
    ref.watch(cartControllerProvider.select((s) => s.lines[cartKey])));
```

`add` returns `null` on success or an Indonesian error message when the stock guard rejects it — mirroring `_stockValidationError` in the Kotlin ViewModel. The guard is skipped when `product.isUnlimitedStock`.

**Cart key format** — must match Kotlin exactly, because it keys per-line savings from the calculator:
`"$productId" + ("_v" + variantIds.join('-') if any) + ("_m" + sortedModifierIds.join('-') if any) + ("_p" + customBasePrice.toInt() if price-adjustable and overridden)`

- [x] **Step 1: Write the failing tests**

```dart
// test/util/cart_key_test.dart
import 'package:cashup_pos/src/util/cart_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a plain product keys on its id alone', () {
    expect(buildCartKey(productId: 12), '12');
  });

  test('variants append in selection order, modifiers append sorted', () {
    expect(
      buildCartKey(productId: 12, variants: [variant(3), variant(1)], modifiers: [modifier(9), modifier(4)]),
      '12_v3-1_m4-9',
    );
  });

  test('an overridden price only participates when the product is price-adjustable', () {
    expect(buildCartKey(productId: 12, customBasePrice: 25000, isPriceAdjustable: true), '12_p25000');
    expect(buildCartKey(productId: 12, customBasePrice: 25000), '12');
  });
}
```

```dart
// test/state/cart_controller_test.dart
import 'package:cashup_pos/src/state/cart_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  CartController get cart => container.read(cartControllerProvider.notifier);

  test('adding the same product twice merges onto one line', () {
    cart.add(product(1, 'Kopi', price: 18000, unlimited: true));
    cart.add(product(1, 'Kopi', price: 18000, unlimited: true));

    final state = container.read(cartControllerProvider);
    expect(state.lines.length, 1);
    expect(state.lines.values.single.quantity, 2);
    expect(state.subTotal, 36000);
  });

  test('different variants of one product occupy separate lines', () {
    final p = product(1, 'Kopi', price: 18000, unlimited: true);
    cart.add(p, variants: [variant(3, price: 5000)]);
    cart.add(p, variants: [variant(4, price: 0)]);

    expect(container.read(cartControllerProvider).lines.length, 2);
    expect(container.read(cartControllerProvider).subTotal, 18000 + 5000 + 18000);
  });

  test('the stock guard rejects going past available quantity', () {
    final p = product(1, 'Kopi', price: 18000, qty: 1);
    expect(cart.add(p), isNull);
    final error = cart.add(p);
    expect(error, contains('Stok'));
    expect(container.read(cartControllerProvider).lines.values.single.quantity, 1);
  });

  test('unlimited stock bypasses the guard', () {
    final p = product(1, 'Kopi', price: 18000, qty: 0, unlimited: true);
    expect(cart.add(p), isNull);
    expect(cart.add(p), isNull);
    expect(container.read(cartControllerProvider).lines.values.single.quantity, 2);
  });

  test('setting a quantity to zero removes the line', () {
    cart.add(product(1, 'Kopi', price: 18000, unlimited: true));
    final key = container.read(cartControllerProvider).lines.keys.single;
    cart.setQuantity(key, 0);
    expect(container.read(cartControllerProvider).isEmpty, isTrue);
  });
}
```

- [x] **Step 2: Run to verify they fail** — `flutter test test/state test/util`

- [x] **Step 3: Implement `cart_key.dart` and `cart_controller.dart`**

- [x] **Step 4: Run to verify they pass** — `flutter test test/state test/util`

- [x] **Step 5: Commit**

```bash
git add lib/src/state lib/src/util/cart_key.dart test
git commit -m "feat(state): cart controller with per-line keys and stock guard"
```

---

## Task 22: Checkout state with memoised calculation

**Files:**
- Create: `lib/src/util/calc_mappers.dart`
- Create: `lib/src/state/checkout_controller.dart`
- Test: `test/util/calc_mappers_test.dart`
- Test: `test/state/checkout_controller_test.dart`

**Kotlin source:** `PosCartViewModel.toDiscountInput` / `toPromotionInputs`.

**Interfaces:**
- Produces:

```dart
DiscountInput toDiscountInput(DiscountItem item);
List<PromotionInput> toPromotionInputs(List<PromotionItem> items,
    {Map<int, Map<String, int>> selectedRewards = const {}});
CartItemData toCartItemData(PosCartLine line);

class CheckoutState {
  const CheckoutState({required this.result, this.discount, this.promotions = const [],
    this.savings = const PerItemSavingsResult(savings: {}, labels: {}),
    this.paymentMethod = ''});
  final TransactionCalculationResult result;
}

class CheckoutController extends Notifier<CheckoutState> {
  void applyDiscount(DiscountItem? discount);
  void setPaymentMethod(String method);
  void selectReward(int promotionId, Map<String, int> qtyByCartKey);
  CreateTransactionRequest buildPayload({required String cashTendered, required String cashChange, int? queueNumber, String? notes});
}

final checkoutControllerProvider = NotifierProvider<CheckoutController, CheckoutState>(CheckoutController.new);

/// Narrow selectors — a totals row must not rebuild when a product image loads.
final checkoutTotalsProvider = Provider<TransactionCalculationResult>(
    (ref) => ref.watch(checkoutControllerProvider.select((s) => s.result)));
final lineSavingsProvider = Provider.family<double, String>((ref, cartKey) =>
    ref.watch(checkoutControllerProvider.select((s) => s.savings.savings[cartKey] ?? 0)));
```

**Memoisation — the core requirement of this task.** `CheckoutController` holds a private `_CalcFingerprint` built from the cart lines, the discount id, the applied promotion ids and their reward selections, the payment setting id, and the payment method. `build()` recomputes only when the fingerprint differs from the previous one. `_CalcFingerprint` implements `==` and `hashCode` over those fields.

- [x] **Step 1: Write the failing memoisation test**

```dart
// test/state/checkout_controller_test.dart
import 'package:cashup_pos/src/calc/transaction_calculator.dart';
import 'package:cashup_pos/src/state/cart_controller.dart';
import 'package:cashup_pos/src/state/checkout_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  setUp(() {
    TransactionCalculator.debugCalculationCount = 0;
    container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);
  });

  test('totals reflect the cart', () async {
    container.read(cartControllerProvider.notifier)
        .add(product(1, 'Kopi', price: 18000, unlimited: true));
    await container.pump();

    expect(container.read(checkoutTotalsProvider).subTotal, 18000);
  });

  test('reading the totals repeatedly does not recompute', () async {
    container.read(cartControllerProvider.notifier)
        .add(product(1, 'Kopi', price: 18000, unlimited: true));
    await container.pump();

    final countAfterFirst = TransactionCalculator.debugCalculationCount;
    container.read(checkoutTotalsProvider);
    container.read(checkoutTotalsProvider);
    container.read(checkoutTotalsProvider);

    expect(TransactionCalculator.debugCalculationCount, countAfterFirst,
        reason: 'the fingerprint is unchanged, so the cached result must be reused');
  });

  test('changing a quantity recomputes exactly once', () async {
    container.read(cartControllerProvider.notifier)
        .add(product(1, 'Kopi', price: 18000, unlimited: true));
    await container.pump();
    final before = TransactionCalculator.debugCalculationCount;

    final key = container.read(cartControllerProvider).lines.keys.single;
    container.read(cartControllerProvider.notifier).setQuantity(key, 3);
    await container.pump();

    expect(TransactionCalculator.debugCalculationCount, before + 1);
    expect(container.read(checkoutTotalsProvider).subTotal, 54000);
  });
}
```

`TransactionCalculator.debugCalculationCount` is a `static int` incremented at the top of `calculateTransaction`. It exists solely so this test can assert the budget; keep it.

- [x] **Step 2: Run to verify it fails** — `flutter test test/state`

- [x] **Step 3: Implement the mappers and the controller**

- [x] **Step 4: Run to verify it passes** — `flutter test test/state test/util`

- [x] **Step 5: Commit**

```bash
git add lib/src/state lib/src/util/calc_mappers.dart test
git commit -m "feat(state): checkout controller with memoised transaction calculation"
```

---

## Task 23: Responsive shell and home page

**Files:**
- Create: `lib/src/ui/pages/pos_home_page.dart`
- Create: `lib/src/ui/widgets/pos_mode_selector.dart`
- Modify: `lib/src/cashup_pos_sdk.dart` (wire `CashupPosLauncher.open`)
- Test: `test/ui/pages/pos_home_page_test.dart`

**Kotlin source:** `PosTabletMainActivity` + `activity_pos_tablet_main.xml` (60/40 split, Simple ⇄ POS selector, online dot), `MainActivity` + `fragment_pos.xml`.

**Interfaces:**
- Produces:
  - `class PosHomePage extends ConsumerWidget`
  - `class PosModeSelector extends StatelessWidget { const PosModeSelector({required this.isSimple, required this.onChanged}); }`
  - `final posModeProvider = StateProvider<PosMode>((ref) => PosMode.pos);` with `enum PosMode { simple, pos }`

**Layout:**
- `PosFormFactor.phone` — a single pane showing `ProductBrowsePage`, with a cart summary bar pinned to the bottom that opens `CartPage`.
- `PosFormFactor.tablet` / `.wide` — `Row` with the browse pane at flex 6 and the cart pane at flex 4, both inside `PosPanel`, mirroring the Kotlin weights.
- The mode selector sits in the app bar in both cases; `PosMode.simple` swaps the browse pane for `SimpleAmountPage`.

- [x] **Step 1: Write the failing layout test**

```dart
// test/ui/pages/pos_home_page_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('phone width shows one pane and a cart bar', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await pumpPosHome(tester);

    expect(find.byType(ProductBrowsePane), findsOneWidget);
    expect(find.byType(CartPane), findsNothing);
    expect(find.byType(CartSummaryBar), findsOneWidget);
  });

  testWidgets('tablet width shows the browse and cart panes side by side', (tester) async {
    tester.view.physicalSize = const Size(2560, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await pumpPosHome(tester);

    expect(find.byType(ProductBrowsePane), findsOneWidget);
    expect(find.byType(CartPane), findsOneWidget);
    expect(find.byType(CartSummaryBar), findsNothing);
  });

  testWidgets('switching to Simple replaces the browse pane', (tester) async {
    tester.view.physicalSize = const Size(2560, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await pumpPosHome(tester);
    await tester.tap(find.text('Simple'));
    await tester.pumpAndSettle();

    expect(find.byType(SimpleAmountPane), findsOneWidget);
    expect(find.byType(ProductBrowsePane), findsNothing);
  });
}
```

- [x] **Step 2: Run to verify it fails** — `flutter test test/ui/pages`

- [x] **Step 3: Implement the shell**

- [x] **Step 4: Run to verify it passes** — `flutter test test/ui`

- [x] **Step 5: Commit**

```bash
git add lib/src/ui test
git commit -m "feat(ui): responsive POS shell with simple/pos mode selector"
```

---

## Tasks 24–35: Screens

Each screen task follows the same five-step shape as Task 23 — write the widget test, watch it fail, implement the page from its Kotlin counterpart, watch it pass, commit — and each obeys the Global Constraints (virtualised lists, `select`-narrowed watches, no widget duplicating one in `ui/widgets/`).

| Task | Page(s) | Kotlin source | Key behaviours the test must pin |
|---|---|---|---|
| 24 ✅ | `ProductBrowsePage`, `ProductVariantSheet` | `PosProductFragment`, `TabletProductsFragment`, `PosProductVariantBottomSheet` | grid/list toggle; category chips filter without refetch; debounced search; a product with option groups opens the sheet instead of adding directly; price-adjustable products prompt for a price via the keypad sheet |
| 25 ✅ | `CartPage`, `CartPane`, `DiscountPickerSheet`, `PromotionPickerSheet`, `RewardSelectorSheet` | `ProductCartActivity` (1 313 lines), `TabletCartFragment` (1 532 lines) | per-line savings badge; ineligible discounts greyed out via `isDiscountEligible`; reward selection feeds `selectedRewardQtyMap`; totals panel shows subtotal, discount, promo, service charge, tax, rounding, total |
| 26 ✅ | `PaymentMethodPage`, `CashPaymentDialog` | `ListPaymentActivity` (1 370 lines), `CashPaymentDialog` | internal/external method groups; methods the host cannot handle are hidden; cash quick-amount predictions (exact, next 1k, 5k, 10k, 50k, then denominations, always four); confirm disabled until tendered ≥ total; change computed to 2 dp |
| 27 ✅ | `QrisPaymentDialog` | `QrisPaymentDialog` (448 lines) | QR renders from `QrisGateway.generate`; polls `checkStatus` every 3 s; stops polling on paid/failed; cancel stops polling and reports cancellation; the QR image sits in a `RepaintBoundary` so the status label repaint does not touch it |
| 28 ✅ | payment orchestration, `PaymentResultPage` | `ListPaymentActivity` + `ResultActivity` | cash completes locally then posts; card/CDCP delegates to `PosPaymentHandler` and posts on success; a lost `create` response shows a retry prompt rather than auto-retrying; success clears the cart and routes to the receipt |
| 29 ✅ | `ReceiptView`, `ReceiptPage` | `ReceiptTemplate.kt` (923 lines), `PosTransactionReceiptActivity` | section order: header, code, date, items (qty badge, name, line total, unit price when qty > 1, variant then modifier bullets), notes box, discount, promo, subtotal, service charge with percentage, tax, rounding, TOTAL, payment info, cash tendered, change, queue number, footer; 58 mm and 80 mm widths |
| 30 | `TransactionListPage`, `TransactionDetailPage` | `TransactionActivity`, `TransactionDetailActivity` | date-range filter; paged 20 at a time via `PagedListView`; status badges; detail shows items with variant/modifier summaries and the same `TotalsPanel` as the cart |
| 31 | `ManageProductPage` (list/add/edit/detail), `StockMovementPage` | `ManageProductActivity` + fragments, `StockMovementActivity` | create/update validation; category multi-select; stock update with movement type; movement history paged by date range |
| 32 | `ManageCategoryPage` (list/add/edit/detail) | `ManageCategoryActivity` + fragments | create/update/delete with confirmation; deleting a category in use surfaces the backend message |
| 33 | `PaymentSettingPage`, `ReceiptConfigPage` | `PaymentSettingActivity`, `PosReceiptConfigActivity` | rounding target/type, service charge percentage vs amount (mutually exclusive), tax name and percentage, price-include-tax; missing settings offer to create defaults; receipt header/footer text |
| 34 | `SummaryReportPage`, `PosMenuPage` | `PosSummaryReportActivity`, `TabletMenuActivity` | product sales and payment breakdown over a date range; menu gates entries on `PosFeatureFlags`; menu carries the catalogue refresh action that replaces `SyncActivity` |
| 35 | `SimpleAmountPage` | `CalculatorActivity`, `PosAmountFragment` | keypad-driven amount; charge routes into the same payment flow with a single synthetic line; no catalogue required |

---

## Task 36: Example app, README and public API audit

**Files:**
- Create: `example/lib/main.dart`
- Create: `example/pubspec.yaml`
- Create: `README.md`
- Create: `CHANGELOG.md`
- Modify: `lib/cashup_pos.dart`
- Test: `test/public_api_test.dart`

**Interfaces:**
- Consumes: everything.
- Produces: a runnable host application demonstrating `CashupPos.initialize` plus a stub `PosPaymentHandler` and `QrisGateway`.

- [ ] **Step 1: Write the failing public API test**

```dart
// test/public_api_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no source file outside lib/src imports lib/src by package path', () {
    final offenders = <String>[];
    for (final entity in Directory('example/lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      if (content.contains('package:cashup_pos/src/')) offenders.add(entity.path);
    }
    expect(offenders, isEmpty,
        reason: 'the example must consume only the public surface');
  });

  test('every public symbol the README documents is exported', () {
    final exports = File('lib/cashup_pos.dart').readAsStringSync();
    for (final symbol in const [
      'CashupPos', 'CashupPosLauncher', 'PosConfig', 'PosMerchant',
      'PosFeatureFlags', 'PosTheme', 'PosPaymentHandler', 'PosPaymentResult',
      'QrisGateway', 'QrisPayload', 'QrisStatus', 'PosException', 'PosErrorKind',
    ]) {
      expect(exports.contains(symbol), isTrue, reason: '$symbol is not exported');
    }
  });
}
```

- [ ] **Step 2: Run to verify it fails** — `flutter test test/public_api_test.dart`

- [ ] **Step 3: Build the example app**

`example/lib/main.dart` initialises the SDK against a configurable base URL, provides a `DemoPaymentHandler` that returns a successful `PosPaymentResult` after a short delay, and a `DemoQrisGateway` that returns a static payload and reports `paid` on the third poll — enough to exercise the whole flow without a backend.

- [ ] **Step 4: Write `README.md`**

Sections: what the SDK is; installation; `CashupPos.initialize` with every `PosConfig` field explained; implementing `PosPaymentHandler` and `QrisGateway`; theming; feature flags; **the pure-online constraint and what happens when connectivity drops**; the pinned Kotlin source commit `33ddffdcc50aa8f9c6c53344bb4b269de5733064` so future syncs have a diff base.

- [ ] **Step 5: Run the full suite and analyzer**

Run: `flutter test` — Expected: PASS
Run: `flutter analyze` — Expected: no issues
Run: `cd example && flutter run` — Expected: the POS shell opens and a cash sale completes end to end

- [ ] **Step 6: Commit**

```bash
git add example README.md CHANGELOG.md lib/cashup_pos.dart test/public_api_test.dart
git commit -m "feat: example host app, README and public API audit"
```

---

## Self-Review Notes

**Spec coverage:** every spec section maps to at least one task — connectivity model → Task 14 (the `PosRepository` seam); calculation fidelity → Tasks 4–12; API surface → Tasks 13–14; public API → Tasks 16, 36; widget library → Tasks 17–19; helper layer → Tasks 1, 18, 19, 21, 22; performance budget → enforced per task and asserted in Tasks 19, 20, 22; screen inventory → Tasks 23–35; testing strategy → the test file in every task.

**Known follow-ups, deliberately out of this plan:**
- Thermal printing. `ReceiptView` (Task 29) renders and can rasterise, but driving a printer is host territory — it needs a `PosPrinter` contract, which belongs in its own spec.
- Offline support. The `PosRepository` seam exists for it; the implementation is a separate plan if the pure-online decision is revisited.
- Localisation beyond Indonesian. Copy is currently inline; extracting to ARB is a separate, mechanical pass.
