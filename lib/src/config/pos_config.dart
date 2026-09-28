/// The host-supplied configuration the SDK is initialized with.
///
/// This is the single point of contact between a host app and the SDK: the
/// backend base URL and auth, merchant branding, the two payment seams
/// ([PosPaymentHandler] for card/EDC/CDCP, [QrisGateway] for QRIS), the
/// visual theme, feature toggles and a callback for completed transactions.
/// `CashupPos.initialize` stores one of these and every layer below reads it
/// through the SDK's own `ProviderContainer`, never directly.
library;

import 'dart:ui' show Locale;

import '../data/pos_repository.dart';
import '../models/transaction_details.dart';
import '../payment/pos_payment_handler.dart';
import '../payment/qris_gateway.dart';
import 'pos_theme.dart';

/// Branding shown on receipts and the POS shell — the Dart counterpart of
/// the Kotlin merchant profile fields the tablet UI renders in its header
/// and on printed/shared receipts.
class PosMerchant {
  /// Creates a merchant profile.
  const PosMerchant({
    required this.name,
    this.address,
    this.address2,
    this.logoAssetPath,
  });

  /// The merchant's display name.
  final String name;

  /// First address line, if any.
  final String? address;

  /// Second address line, if any.
  final String? address2;

  /// Asset path (host bundle) for the merchant's logo, if any.
  final String? logoAssetPath;
}

/// Toggles for optional SDK surfaces, so a host can embed only the parts of
/// the POS it needs. All default to enabled.
class PosFeatureFlags {
  /// Creates a set of feature flags. Every flag defaults to enabled.
  const PosFeatureFlags({
    this.enableProductManagement = true,
    this.enableCategoryManagement = true,
    this.enableStockTracking = true,
    this.enableSummaryReport = true,
    this.enableQueueNumber = true,
    this.enableSimpleMode = true,
  });

  /// Whether the product catalogue can be created/edited from within the SDK.
  final bool enableProductManagement;

  /// Whether categories can be created/edited from within the SDK.
  final bool enableCategoryManagement;

  /// Whether stock quantities and stock movement history are shown.
  final bool enableStockTracking;

  /// Whether the sales summary report screen is available.
  final bool enableSummaryReport;

  /// Whether queue numbers are assigned to transactions.
  final bool enableQueueNumber;

  /// Whether the simplified (reduced-step) checkout mode is offered.
  final bool enableSimpleMode;
}

/// Called once a transaction has been created on the backend, so the host
/// can react — e.g. print a receipt, update its own order records, or
/// navigate away from the POS.
typedef PosTransactionCompletedCallback = void Function(
  TransactionDetails transaction,
);

/// Configuration the host supplies to [CashupPos.initialize].
///
/// Everything the SDK needs to talk to the `/pos/*` backend and to present
/// itself inside a host app lives here: no other entry point for
/// configuration exists.
class PosConfig {
  /// Creates a POS configuration.
  ///
  /// [baseUrl] is normalised so it always ends with a trailing slash, to
  /// match the relative paths [PosRepository] and `PosApiClient` build
  /// requests with.
  PosConfig({
    required String baseUrl,
    required this.tokenProvider,
    required this.merchant,
    this.paymentHandler,
    this.qrisGateway,
    this.theme = const PosTheme.cashup(),
    this.features = const PosFeatureFlags(),
    this.locale = const Locale('id', 'ID'),
    this.extraHeaders,
    this.onTransactionCompleted,
  }) : baseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';

  /// The `/pos/*` backend's base URL, always normalised to end with `/`.
  final String baseUrl;

  /// Returns the current bearer token, read fresh on every request. `null`
  /// when no user is signed in — the request is then sent unauthenticated
  /// and the backend rejects it.
  final Future<String?> Function() tokenProvider;

  /// Branding shown throughout the POS UI and on receipts.
  final PosMerchant merchant;

  /// Handles card/EDC/CDCP payments. `null` if the host offers no such
  /// methods; the SDK then only offers QRIS and cash.
  final PosPaymentHandler? paymentHandler;

  /// Generates and polls QRIS payloads. `null` if the host does not support
  /// QRIS.
  final QrisGateway? qrisGateway;

  /// Visual theme tokens. Defaults to [PosTheme.cashup].
  final PosTheme theme;

  /// Which optional SDK surfaces are enabled.
  final PosFeatureFlags features;

  /// Locale for currency, date and number formatting. Defaults to
  /// Indonesian.
  final Locale locale;

  /// Extra headers merged into every request, e.g. device id or app
  /// version. Sent as-is on top of the `Authorization` header the SDK
  /// manages itself.
  final Map<String, String>? extraHeaders;

  /// Invoked once a transaction is successfully created on the backend.
  final PosTransactionCompletedCallback? onTransactionCompleted;
}
