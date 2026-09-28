/// Cashup POS — an embeddable Point of Sale for Flutter host applications.
///
/// This file is the entire public surface of the package. Nothing under
/// `lib/src/` may be imported directly by a host app.
library;

export 'src/cashup_pos_sdk.dart' show CashupPos, CashupPosLauncher;
export 'src/config/pos_config.dart';
export 'src/config/pos_theme.dart';
export 'src/payment/payment_result.dart';
export 'src/payment/pos_payment_handler.dart';
export 'src/payment/qris_gateway.dart';
export 'src/data/pos_exception.dart' show PosException, PosErrorKind;
export 'src/data/pos_repository.dart' show PosRepository;
export 'src/models/transaction_details.dart' show TransactionDetails;
