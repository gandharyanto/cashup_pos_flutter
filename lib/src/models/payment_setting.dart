import '../util/num_utils.dart';

/// The merchant's POS payment configuration, from `pos/payment-setting`.
///
/// Every field feeds the calculation engine, so the names match the Kotlin
/// `PaymentSettingData` exactly.
class PaymentSetting {
  const PaymentSetting({
    required this.paymentSettingId,
    required this.isPriceIncludeTax,
    required this.isRounding,
    required this.roundingTarget,
    required this.roundingType,
    required this.isServiceCharge,
    required this.serviceChargePercentage,
    required this.serviceChargeAmount,
    required this.isTax,
    required this.taxPercentage,
    required this.taxName,
    this.receiptFooterText,
  });

  /// The settings offered to a merchant that has none yet — everything off,
  /// which is the only safe starting point for money.
  const PaymentSetting.defaults()
    : paymentSettingId = 0,
      isPriceIncludeTax = false,
      isRounding = false,
      roundingTarget = 0,
      roundingType = 'NONE',
      isServiceCharge = false,
      serviceChargePercentage = 0,
      serviceChargeAmount = 0,
      isTax = false,
      taxPercentage = 0,
      taxName = '',
      receiptFooterText = null;

  final int paymentSettingId;
  final bool isPriceIncludeTax;
  final bool isRounding;
  final int roundingTarget;
  final String roundingType;
  final bool isServiceCharge;
  final double serviceChargePercentage;
  final double serviceChargeAmount;
  final bool isTax;
  final double taxPercentage;
  final String taxName;
  final String? receiptFooterText;

  factory PaymentSetting.fromJson(Map<String, dynamic> json) => PaymentSetting(
    paymentSettingId: asInt(json['paymentSettingId']) ?? 0,
    isPriceIncludeTax: asBool(json['isPriceIncludeTax']) ?? false,
    isRounding: asBool(json['isRounding']) ?? false,
    roundingTarget: asInt(json['roundingTarget']) ?? 0,
    roundingType: json['roundingType'] as String? ?? 'NONE',
    isServiceCharge: asBool(json['isServiceCharge']) ?? false,
    serviceChargePercentage: asDouble(json['serviceChargePercentage']) ?? 0,
    serviceChargeAmount: asDouble(json['serviceChargeAmount']) ?? 0,
    isTax: asBool(json['isTax']) ?? false,
    taxPercentage: asDouble(json['taxPercentage']) ?? 0,
    taxName: json['taxName'] as String? ?? '',
    receiptFooterText: json['receiptFooterText'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'paymentSettingId': paymentSettingId,
    'isPriceIncludeTax': isPriceIncludeTax,
    'isRounding': isRounding,
    'roundingTarget': roundingTarget,
    'roundingType': roundingType,
    'isServiceCharge': isServiceCharge,
    'serviceChargePercentage': serviceChargePercentage,
    'serviceChargeAmount': serviceChargeAmount,
    'isTax': isTax,
    'taxPercentage': taxPercentage,
    'taxName': taxName,
    'receiptFooterText': receiptFooterText,
  };

  PaymentSetting copyWith({
    int? paymentSettingId,
    bool? isPriceIncludeTax,
    bool? isRounding,
    int? roundingTarget,
    String? roundingType,
    bool? isServiceCharge,
    double? serviceChargePercentage,
    double? serviceChargeAmount,
    bool? isTax,
    double? taxPercentage,
    String? taxName,
    String? receiptFooterText,
  }) => PaymentSetting(
    paymentSettingId: paymentSettingId ?? this.paymentSettingId,
    isPriceIncludeTax: isPriceIncludeTax ?? this.isPriceIncludeTax,
    isRounding: isRounding ?? this.isRounding,
    roundingTarget: roundingTarget ?? this.roundingTarget,
    roundingType: roundingType ?? this.roundingType,
    isServiceCharge: isServiceCharge ?? this.isServiceCharge,
    serviceChargePercentage:
        serviceChargePercentage ?? this.serviceChargePercentage,
    serviceChargeAmount: serviceChargeAmount ?? this.serviceChargeAmount,
    isTax: isTax ?? this.isTax,
    taxPercentage: taxPercentage ?? this.taxPercentage,
    taxName: taxName ?? this.taxName,
    receiptFooterText: receiptFooterText ?? this.receiptFooterText,
  );
}
