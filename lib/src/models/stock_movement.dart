import '../util/num_utils.dart';

/// A row of `pos/stock-movement/product/list`.
class StockMovementRow {
  const StockMovementRow({
    required this.productId,
    required this.qty,
    required this.movementType,
    required this.movementReason,
    required this.localDateTime,
  });

  static const String typeIn = 'IN';
  static const String typeOut = 'OUT';

  final int productId;
  final int qty;
  final String movementType;
  final String movementReason;
  final String localDateTime;

  bool get isOutbound => movementType.toUpperCase() == typeOut;
  bool get isInbound => movementType.toUpperCase() == typeIn;

  factory StockMovementRow.fromJson(Map<String, dynamic> json) =>
      StockMovementRow(
        productId: asInt(json['productId']) ?? 0,
        qty: asInt(json['qty']) ?? 0,
        movementType: json['movementType'] as String? ?? '',
        movementReason: json['movementReason'] as String? ?? '',
        localDateTime: json['localDateTime'] as String? ?? '',
      );
}
