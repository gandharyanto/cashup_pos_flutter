/// Cashup POS — an embeddable Point of Sale for Flutter host applications.
///
/// This file is the entire public surface of the package. Nothing under
/// `lib/src/` may be imported directly by a host app. Every export names
/// its symbols explicitly, so a new public class added under `lib/src/`
/// never leaks into the host-facing API by accident.
library;

export 'src/cashup_pos_sdk.dart' show CashupPos, CashupPosLauncher;
export 'src/config/pos_config.dart'
    show PosConfig, PosMerchant, PosFeatureFlags;
export 'src/config/pos_theme.dart' show PosTheme;
export 'src/payment/payment_result.dart' show PosPaymentResult;
export 'src/payment/pos_payment_handler.dart' show PosPaymentHandler;
export 'src/payment/qris_gateway.dart'
    show QrisGateway, QrisPayload, QrisStatus;
export 'src/data/pos_exception.dart' show PosException, PosErrorKind;
export 'src/data/pos_repository.dart' show PosRepository;
export 'src/models/transaction_details.dart' show TransactionDetails;
