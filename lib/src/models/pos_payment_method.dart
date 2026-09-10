import '../util/num_utils.dart';

/// A payment method the merchant may accept, from
/// `pos/payment-method/merchant/list`.
class PosPaymentMethod {
  const PosPaymentMethod({
    required this.code,
    required this.name,
    this.category,
    this.paymentType,
    this.provider,
    this.displayOrder = 0,
  });

  static const String cash = 'CASH';
  static const String qris = 'QRIS';

  final String code;
  final String name;
  final String? category;
  final String? paymentType;
  final String? provider;
  final int displayOrder;

  bool get isCash => code.toUpperCase() == cash;
  bool get isQris => code.toUpperCase() == qris;

  factory PosPaymentMethod.fromJson(Map<String, dynamic> json) =>
      PosPaymentMethod(
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        category: json['category'] as String?,
        paymentType: json['paymentType'] as String?,
        provider: json['provider'] as String?,
        displayOrder: asInt(json['displayOrder']) ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'category': category,
    'paymentType': paymentType,
    'provider': provider,
    'displayOrder': displayOrder,
  };

  /// Parses the `data` object, which splits methods into two lists.
  static PosPaymentMethods listFromJson(Map<String, dynamic> json) =>
      PosPaymentMethods(
        internal: _parseList(json['internalPayments']),
        external: _parseList(json['externalPayments']),
      );

  static List<PosPaymentMethod> _parseList(Object? value) {
    if (value is! List) return const [];
    final parsed =
        value
            .whereType<Map>()
            .map((e) => PosPaymentMethod.fromJson(Map<String, dynamic>.from(e)))
            // A method without a code cannot be selected or sent, so it is
            // dropped rather than rendered as an unusable row.
            .where((m) => m.code.isNotEmpty)
            .toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return List.unmodifiable(parsed);
  }
}

/// The two method lists the backend returns, kept apart because the payment
/// page groups them under separate headings.
class PosPaymentMethods {
  const PosPaymentMethods({this.internal = const [], this.external = const []});

  final List<PosPaymentMethod> internal;
  final List<PosPaymentMethod> external;

  List<PosPaymentMethod> get all => [...internal, ...external];

  bool get isEmpty => internal.isEmpty && external.isEmpty;
}
