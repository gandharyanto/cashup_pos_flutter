import 'package:cashup_pos/src/models/create_transaction_request.dart';
import 'package:cashup_pos/src/models/discount_item.dart';
import 'package:cashup_pos/src/models/promotion_item.dart';
import 'package:cashup_pos/src/models/stock_movement.dart';
import 'package:cashup_pos/src/models/summary_report.dart';
import 'package:cashup_pos/src/models/transaction_details.dart';
import 'package:cashup_pos/src/models/transaction_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CreateTransactionRequest', () {
    test('serializes to the wire keys the backend expects', () {
      const request = CreateTransactionRequest(
        paymentMethod: 'CASH',
        subTotal: '50000.00',
        netAmount: '45000.00',
        discountAmount: '5000.00',
        totalServiceCharge: '0.00',
        totalTax: '4950.00',
        totalRounding: '0.00',
        totalAmount: '49950.00',
        transactionItems: [],
        promotionIds: [7],
      );

      final json = request.toJson();
      expect(json['grossAmount'], '50000.00');
      expect(json['netAmount'], '45000.00');
      expect(json['totalDiscount'], '5000.00');
      expect(json['appliedPromotionIds'], [7]);
    });

    test('omits null optional fields rather than sending them as null', () {
      const request = CreateTransactionRequest(
        paymentMethod: 'CASH',
        subTotal: '50000.00',
        totalServiceCharge: '0.00',
        totalTax: '0.00',
        totalRounding: '0.00',
        totalAmount: '50000.00',
        transactionItems: [],
      );

      final json = request.toJson();
      // Gson drops nulls, and the backend validator treats an explicit null
      // differently from an absent key.
      expect(json.containsKey('totalPromotionAmount'), isFalse);
      expect(json.containsKey('totalDiscount'), isFalse);
      expect(json.containsKey('discountId'), isFalse);
      expect(json.containsKey('appliedPromotionIds'), isFalse);
      expect(json.containsKey('notes'), isFalse);
      expect(json.containsKey('queueNumber'), isFalse);
    });

    test('omits an empty promotion id list', () {
      const request = CreateTransactionRequest(
        paymentMethod: 'CASH',
        subTotal: '1.00',
        totalServiceCharge: '0.00',
        totalTax: '0.00',
        totalRounding: '0.00',
        totalAmount: '1.00',
        transactionItems: [],
        promotionIds: [],
      );
      expect(request.toJson().containsKey('appliedPromotionIds'), isFalse);
    });

    test('always sends the required money fields, even at zero', () {
      const request = CreateTransactionRequest(
        paymentMethod: 'CASH',
        subTotal: '0.00',
        totalServiceCharge: '0.00',
        totalTax: '0.00',
        totalRounding: '0.00',
        totalAmount: '0.00',
        transactionItems: [],
      );
      final json = request.toJson();
      for (final key in const [
        'grossAmount',
        'totalServiceCharge',
        'totalTax',
        'totalRounding',
        'totalAmount',
        'transactionItems',
      ]) {
        expect(json.containsKey(key), isTrue, reason: key);
      }
    });
  });

  group('RequestTransactionItem', () {
    test('carries the per-item breakdown arrays when present', () {
      const item = RequestTransactionItem(
        productId: 1,
        productName: 'Kopi',
        price: '18000.00',
        qty: 2,
        totalPrice: '36000.00',
        discounts: [
          ItemDiscountDetail(
            id: 4,
            type: 'PERCENTAGE',
            value: 10,
            amt: '3600.00',
          ),
        ],
        promotions: [
          ItemPromotionDetail(
            id: 7,
            type: 'BUY_X_GET_Y',
            amt: '18000.00',
            meta: ItemPromotionMeta(role: 'REWARD', buyQty: 1, getQty: 1),
          ),
        ],
        taxes: [
          ItemTaxDetail(id: 1, type: 'PERCENTAGE', value: 11, amt: '0.00'),
        ],
      );

      final json = item.toJson();
      expect(json['discounts'], hasLength(1));
      expect(json['promotions'][0]['meta']['role'], 'REWARD');
      expect(json['taxes'][0]['value'], 11);
    });

    test('omits the breakdown arrays when there is nothing to report', () {
      const item = RequestTransactionItem(
        productId: 1,
        price: '18000.00',
        qty: 1,
        totalPrice: '18000.00',
      );
      final json = item.toJson();
      expect(json.containsKey('discounts'), isFalse);
      expect(json.containsKey('promotions'), isFalse);
      expect(json.containsKey('taxes'), isFalse);
      expect(json.containsKey('details'), isFalse);
      expect(json.containsKey('variantId'), isFalse);
    });

    test('emits variant and modifier details in sort order', () {
      const item = RequestTransactionItem(
        productId: 1,
        price: '18000.00',
        qty: 1,
        totalPrice: '18000.00',
        variantOptionIds: [12],
        details: [
          RequestItemDetail(
            detailType: 'VARIANT',
            name: 'Large',
            groupName: 'Ukuran',
            referenceId: 12,
            groupReferenceId: 1,
            priceAdjustment: 10000,
            qty: 1,
            sortOrder: 0,
          ),
        ],
      );
      final json = item.toJson();
      expect(json['variantOptionIds'], [12]);
      expect(json['details'][0]['detailType'], 'VARIANT');
      expect(json['details'][0]['priceAdjustment'], 10000);
    });
  });

  group('PaymentSettingRequest', () {
    test('always reports taxAppliedAfterDiscount as true', () {
      const request = PaymentSettingRequest(priceIncludeTax: false);
      expect(request.toJson()['taxAppliedAfterDiscount'], isTrue);
    });

    test('omits the service charge object when there is none', () {
      const request = PaymentSettingRequest(priceIncludeTax: false);
      expect(request.toJson().containsKey('serviceCharge'), isFalse);
    });

    test('emits a typed service charge object when present', () {
      const request = PaymentSettingRequest(
        priceIncludeTax: true,
        serviceCharge: ServiceChargeRequest(type: 'PERCENTAGE', value: 5),
      );
      expect(request.toJson()['serviceCharge'], {
        'type': 'PERCENTAGE',
        'value': 5.0,
      });
    });
  });

  group('PromotionItem', () {
    test('reads minimumSubtotal into minPurchase', () {
      final promo = PromotionItem.fromJson(const {
        'id': 7,
        'name': 'Diskon Ceria',
        'promoType': 'DISCOUNT_BY_ORDER',
        'minimumSubtotal': 100000,
        'rewardQty': 2,
      });
      expect(promo.minPurchase, 100000.0);
      expect(promo.rewardQty, 2);
    });

    test('falls back to the object arrays when the id arrays are absent', () {
      final promo = PromotionItem.fromJson(const {
        'id': 7,
        'name': 'Beli 1 Gratis 1',
        'promoType': 'BUY_X_GET_Y',
        'buyProducts': [
          {'id': 3, 'name': 'Kopi'},
        ],
        'rewardCategories': [
          {'id': 9, 'name': 'Snack'},
        ],
      });
      expect(promo.buyProductIds, [3]);
      expect(promo.rewardCategoryIds, [9]);
    });

    test('prefers a populated id array over the object array', () {
      final promo = PromotionItem.fromJson(const {
        'id': 7,
        'name': 'Promo',
        'promoType': 'BUY_X_GET_Y',
        'buyProductIds': [11],
        'buyProducts': [
          {'id': 3, 'name': 'Kopi'},
        ],
      });
      expect(promo.buyProductIds, [11]);
    });

    test('parses the schedule that gates a promotion by day and time', () {
      final promo = PromotionItem.fromJson(const {
        'id': 7,
        'name': 'Happy Hour',
        'promoType': 'DISCOUNT_BY_ORDER',
        'schedule': {
          'activeDays': ['MON', 'TUE'],
          'startTime': '14:00',
          'endTime': '17:00',
        },
      });
      expect(promo.schedule!.activeDays, ['MON', 'TUE']);
      expect(promo.schedule!.startTime, '14:00');
    });

    test('defaults priority and canCombine the way the backend does', () {
      final promo = PromotionItem.fromJson(const {
        'id': 7,
        'name': 'Promo',
        'promoType': 'DISCOUNT_BY_ORDER',
      });
      expect(promo.priority, 100);
      expect(promo.canCombine, isFalse);
      expect(promo.isMultiplied, isFalse);
      expect(promo.minPurchase, 0.0);
    });
  });

  group('DiscountItem', () {
    test('parses target ids from either shape', () {
      final discount = DiscountItem.fromJson(const {
        'id': 4,
        'name': 'Diskon Member',
        'valueType': 'PERCENTAGE',
        'value': 10,
        'scope': 'PRODUCT',
        'targetProductIds': [3, 5],
        'categoryIds': [9],
      });
      expect(discount.targetProductIds, [3, 5]);
      expect(discount.categoryIds, [9]);
    });

    test('falls back to the targetProducts object array', () {
      final discount = DiscountItem.fromJson(const {
        'id': 4,
        'name': 'Diskon',
        'valueType': 'AMOUNT',
        'value': 5000,
        'scope': 'PRODUCT',
        'targetProducts': [
          {'id': 3, 'name': 'Kopi'},
        ],
      });
      expect(discount.targetProductIds, [3]);
    });

    test('reports remaining usage when the backend caps it', () {
      final discount = DiscountItem.fromJson(const {
        'id': 4,
        'name': 'Diskon',
        'valueType': 'AMOUNT',
        'value': 5000,
        'scope': 'ALL',
        'usageLimit': 10,
        'usageCount': 4,
        'usageRemaining': 6,
      });
      expect(discount.usageRemaining, 6);
      expect(discount.isExhausted, isFalse);
    });

    test('reports exhaustion when no uses remain', () {
      final discount = DiscountItem.fromJson(const {
        'id': 4,
        'name': 'Diskon',
        'valueType': 'AMOUNT',
        'value': 5000,
        'scope': 'ALL',
        'usageRemaining': 0,
      });
      expect(discount.isExhausted, isTrue);
    });
  });

  group('TransactionDetails', () {
    test('exposes pricing through convenience getters', () {
      final details = TransactionDetails.fromJson(const {
        'transactionId': 1,
        'code': 'TRX-1',
        'status': 'COMPLETED',
        'paymentMethod': 'CASH',
        'transactionDate': '2026-09-10T10:00:00',
        'pricing': {
          'grossAmount': 50000,
          'taxTotal': 5000,
          'totalAmount': 55000,
          'discountTotal': 2000,
          'promotionTotal': 1000,
          'serviceChargeTotal': 500,
          'roundingTotal': -50,
          'serviceChargePercentage': 5,
        },
      });

      expect(details.grossAmount, 50000.0);
      expect(details.totalTax, 5000.0);
      expect(details.totalAmount, 55000.0);
      expect(details.discountAmount, 2000.0);
      expect(details.promotionAmount, 1000.0);
      expect(details.totalServiceCharge, 500.0);
      expect(details.totalRounding, -50.0);
      expect(details.serviceChargePercentage, 5.0);
    });

    test('falls back to summing line totals when pricing is absent', () {
      final details = TransactionDetails.fromJson(const {
        'transactionId': 1,
        'code': 'TRX-1',
        'status': 'COMPLETED',
        'paymentMethod': 'CASH',
        'transactionDate': '2026-09-10T10:00:00',
        'transactionItems': [
          {
            'productId': 1,
            'productName': 'Kopi',
            'qty': 2,
            'grossLineTotal': 36000,
          },
        ],
      });
      expect(details.grossAmount, 36000.0);
    });

    test('surfaces the discount name from the discount block', () {
      final details = TransactionDetails.fromJson(const {
        'transactionId': 1,
        'code': 'TRX-1',
        'status': 'COMPLETED',
        'paymentMethod': 'CASH',
        'transactionDate': '2026-09-10T10:00:00',
        'discount': {'discountId': 4, 'discountName': 'Diskon Member'},
      });
      expect(details.discountName, 'Diskon Member');
    });
  });

  group('TransactionLine', () {
    test('summarises variants and modifiers in sort order with prices', () {
      final line = TransactionLine.fromJson(const {
        'productId': 1,
        'productName': 'Kopi',
        'qty': 1,
        'details': [
          {
            'detailType': 'MODIFIER',
            'name': 'Boba',
            'groupName': 'Topping',
            'referenceId': 51,
            'groupReferenceId': 5,
            'priceAdjustment': 3000,
            'qty': 1,
            'sortOrder': 1,
          },
          {
            'detailType': 'VARIANT',
            'name': 'Large',
            'groupName': 'Ukuran',
            'referenceId': 12,
            'groupReferenceId': 1,
            'priceAdjustment': 10000,
            'qty': 1,
            'sortOrder': 0,
          },
        ],
      });

      expect(line.variantSummary, 'Large (+10000)');
      expect(line.modifierSummary, 'Boba (+3000)');
      expect(line.detailSummary, 'Large (+10000) • Boba (+3000)');
    });

    test('omits the price when an option costs nothing', () {
      final line = TransactionLine.fromJson(const {
        'productId': 1,
        'productName': 'Kopi',
        'qty': 1,
        'details': [
          {
            'detailType': 'VARIANT',
            'name': 'Small',
            'groupName': 'Ukuran',
            'referenceId': 11,
            'groupReferenceId': 1,
            'priceAdjustment': 0,
            'qty': 1,
            'sortOrder': 0,
          },
        ],
      });
      expect(line.variantSummary, 'Small');
      expect(line.detailSummary, 'Small');
    });

    test('summaries are empty when a line has no options', () {
      final line = TransactionLine.fromJson(const {
        'productId': 1,
        'productName': 'Kopi',
        'qty': 1,
      });
      expect(line.variantSummary, isEmpty);
      expect(line.detailSummary, isEmpty);
    });
  });

  group('TransactionSummaryRow', () {
    test('parses a transaction list row', () {
      final row = TransactionSummaryRow.fromJson(const {
        'id': 91,
        'code': 'TRX-91',
        'trxId': 'ABC',
        'paymentMethod': 'CASH',
        'status': 'PAID',
        'totalAmount': '55000.00',
        'transactionDate': '2026-09-10T10:00:00',
        'queueNumber': '4',
      });
      expect(row.id, 91);
      expect(row.code, 'TRX-91');
      expect(row.totalAmountValue, 55000.0);
    });
  });

  group('UpdateTransactionRequest', () {
    test('serializes the payment confirmation payload', () {
      const request = UpdateTransactionRequest(
        paymentTrxId: 'PT-1',
        paymentMethod: 'QRIS',
        amountPaid: 55000,
        status: 'PAID',
        paymentReference: 'INV-1',
        paymentDate: '2026-09-10T10:00:00',
      );
      expect(request.toJson(), {
        'paymentTrxId': 'PT-1',
        'paymentMethod': 'QRIS',
        'amountPaid': 55000.0,
        'status': 'PAID',
        'paymentReference': 'INV-1',
        'paymentDate': '2026-09-10T10:00:00',
      });
    });
  });

  group('StockMovementRow', () {
    test('parses a movement entry', () {
      final row = StockMovementRow.fromJson(const {
        'productId': 1,
        'qty': -2,
        'movementType': 'OUT',
        'movementReason': 'SALE',
        'localDateTime': '2026-09-10T10:00:00',
      });
      expect(row.qty, -2);
      expect(row.movementType, 'OUT');
      expect(row.isOutbound, isTrue);
    });
  });

  group('SummaryReportData', () {
    test('parses product and payment breakdowns and totals them', () {
      final data = SummaryReportData.fromJson(const {
        'productList': [
          {'productName': 'Kopi', 'totalSaleItems': 3},
        ],
        'paymentListInternal': [
          {
            'paymentName': 'Tunai',
            'totalTransactions': 2,
            'totalAmountTransactions': 100000,
          },
        ],
        'paymentListExternal': [
          {
            'paymentName': 'QRIS',
            'totalTransactions': 1,
            'totalAmountTransactions': 55000,
          },
        ],
      });

      expect(data.productList.single.totalSaleItems, 3);
      expect(data.allPayments.length, 2);
      expect(data.totalTransactions, 3);
      expect(data.totalAmount, 155000.0);
    });

    test('totals to zero when the report is empty', () {
      final data = SummaryReportData.fromJson(const {});
      expect(data.totalTransactions, 0);
      expect(data.totalAmount, 0.0);
      expect(data.isEmpty, isTrue);
    });
  });
}
