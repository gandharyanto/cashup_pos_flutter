/// Host-supplied configuration for the SDK.
///
/// [PosConfig] is the single object a host builds and passes to
/// `CashupPos.initialize`. It never reaches past the seams the package
/// already defines: [PosPaymentHandler] / [QrisGateway] (Task 15) are the
/// host's own implementations, and nothing here talks to [PosRepository] or
/// `PosApiClient` directly — those are constructed from [baseUrl] /
/// [tokenProvider] / [extraHeaders] later, once `pos_providers.dart`
/// (Task 20) exists.
library;

import 'package:flutter/widgets.dart' show Locale;

import '../models/transaction_details.dart';
import '../payment/pos_payment_handler.dart';
import '../payment/qris_gateway.dart';
import 'pos_theme.dart';

/// Merchant identity shown on receipts and the POS chrome.
class PosMerchant {
  const PosMerchant({
    required this.name,
    this.address,
    this.address2,
    this.logoAssetPath,
  });

  final String name;
  final String? address;
  final String? address2;

  /// An asset path resolved against the *host* app's asset bundle, not the
  /// SDK's — the SDK never ships merchant logos.
  final String? logoAssetPath;
}

/// Toggles for optional POS capabilities. Every flag defaults to enabled;
/// a host narrows the surface by turning individual flags off rather than
/// the SDK opting features in piecemeal.
class PosFeatureFlags {
  const PosFeatureFlags({
    this.enableProductManagement = true,
    this.enableCategoryManagement = true,
    this.enableStockTracking = true,
    this.enableSummaryReport = true,
    this.enableQueueNumber = true,
    this.enableSimpleMode = true,
  });

  final bool enableProductManagement;
  final bool enableCategoryManagement;
  final bool enableStockTracking;
  final bool enableSummaryReport;
  final bool enableQueueNumber;
  final bool enableSimpleMode;
}

/// Everything the SDK needs from the host, gathered into one object.
///
/// Construction never fails and never talks to the network — validation
/// (e.g. base URL normalisation) happens once, in `CashupPos.initialize`,
/// so this class stays a plain, immutable data holder.
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

  /// The `/pos/*` backend's base URL. `CashupPos.initialize` normalises a
  /// missing trailing slash onto this before it is exposed via
  /// `CashupPos.config` or used to build the API client.
  final String baseUrl;

  /// Read fresh before every request — see `PosApiClient`'s doc comment for
  /// why nothing caches the token on the SDK side.
  final Future<String?> Function() tokenProvider;

  final PosMerchant merchant;

  /// Executes card / EDC / CDCP payments. `null` when the host does not
  /// support any of those methods — the checkout flow then offers only cash
  /// and (if [qrisGateway] is set) QRIS.
  final PosPaymentHandler? paymentHandler;

  /// Generates and polls QRIS payments. `null` when the host does not
  /// support QRIS.
  final QrisGateway? qrisGateway;

  final PosTheme theme;
  final PosFeatureFlags features;
  final Locale locale;

  /// Extra headers merged onto every request, alongside the bearer token —
  /// the Dart counterpart of the device-id / version-id / user-agent
  /// headers the Kotlin `PosAuthInterceptor` adds.
  final Map<String, String> Function()? extraHeaders;

  /// Notified once a transaction has been created and paid.
  final void Function(TransactionDetails transaction)? onTransactionCompleted;
}
