/// Public SDK lifecycle and UI entry points.
///
/// [CashupPosApp] is the preferred self-contained root: the SDK owns its
/// `MaterialApp`, theme, navigator, provider scope and every POS screen.
/// [CashupPosLauncher] remains available for hosts that embed POS routes in
/// a larger application.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/pos_config.dart';
import 'config/pos_theme.dart';
import 'payment/payment_result.dart';
import 'payment/pos_payment_handler.dart';
import 'payment/qris_gateway.dart';
import 'state/pos_providers.dart';
import 'ui/pages/manage_product_page.dart';
import 'ui/pages/payment_setting_page.dart';
import 'ui/pages/pos_home_page.dart';
import 'ui/pages/transaction_list_page.dart';

/// Owns the SDK's lifecycle: the host's [PosConfig] and the
/// [ProviderContainer] every SDK screen reads from via
/// `UncontrolledProviderScope`.
///
/// A host calls [initialize] once for the self-contained setup, or
/// [initializeWithConfig] for production backend/auth/payment integration.
/// Call [dispose] when the SDK is no longer needed.
class CashupPos {
  CashupPos._();

  static PosConfig? _config;
  static ProviderContainer? _container;

  /// Whether [initialize] has completed and not yet been [dispose]d.
  static bool get isInitialized => _config != null;

  /// The active configuration, with [baseUrl] normalised to always carry a
  /// trailing slash.
  ///
  /// Throws a [StateError] when read before [initialize].
  static PosConfig get config {
    final config = _config;
    if (config == null) {
      throw StateError(
        'CashupPos.initialize() must be called before CashupPos.config is '
        'read.',
      );
    }
    return config;
  }

  /// The Riverpod container backing every SDK screen. Internal use only —
  /// a host never reads providers from this directly; it exists so
  /// `CashupPosLauncher` can wrap pushed routes in
  /// `UncontrolledProviderScope(container: CashupPos.container, ...)`.
  ///
  /// Throws a [StateError] when read before [initialize].
  static ProviderContainer get container {
    final container = _container;
    if (container == null) {
      throw StateError(
        'CashupPos.initialize() must be called before CashupPos.container '
        'is read.',
      );
    }
    return container;
  }

  /// Initializes the self-contained POS with SDK-owned demo defaults.
  ///
  /// The host only supplies colour tokens. Build-time
  /// `CASHUP_POS_BASE_URL` and `CASHUP_POS_TOKEN` values are used when
  /// present.
  static Future<void> initialize({
    PosTheme theme = const PosTheme.cashup(),
    List<String> bannerImageUrls = const [],
  }) => initializeWithConfig(
    PosConfig(
      baseUrl: const String.fromEnvironment(
        'CASHUP_POS_BASE_URL',
        defaultValue: 'https://tucanos-orca-pos.cashup.id/',
      ),
      tokenProvider: _defaultTokenProvider,
      merchant: const PosMerchant(
        name: 'Toko Demo Cashup',
        address: 'Jl. Contoh No. 1',
        address2: 'Jakarta',
      ),
      paymentHandler: const _SdkDemoPaymentHandler(),
      qrisGateway: _SdkDemoQrisGateway(),
      theme: theme,
      bannerImageUrls: bannerImageUrls,
    ),
  );

  /// Stores [config] (normalising [PosConfig.baseUrl]) and creates a fresh
  /// [ProviderContainer]. Calling this again while already initialized
  /// disposes the previous container first, so a host that re-initializes
  /// (e.g. after switching merchant accounts) never leaks the old one.
  ///
  /// The container overrides `posConfigProvider` with the normalized
  /// config — every other provider in `pos_providers.dart` derives from it,
  /// so nothing else needs to be wired here.
  static Future<void> initializeWithConfig(PosConfig config) async {
    _container?.dispose();

    final baseUrl = config.baseUrl.endsWith('/')
        ? config.baseUrl
        : '${config.baseUrl}/';
    final normalized = identical(baseUrl, config.baseUrl)
        ? config
        : PosConfig(
            baseUrl: baseUrl,
            tokenProvider: config.tokenProvider,
            merchant: config.merchant,
            paymentHandler: config.paymentHandler,
            qrisGateway: config.qrisGateway,
            theme: config.theme,
            features: config.features,
            locale: config.locale,
            bannerImageUrls: config.bannerImageUrls,
            extraHeaders: config.extraHeaders,
            onTransactionCompleted: config.onTransactionCompleted,
          );

    _config = normalized;
    _container = ProviderContainer(
      overrides: [
        posConfigProvider.overrideWithValue(normalized),
        posBannerImageUrlsProvider.overrideWithValue(
          List.unmodifiable(normalized.bannerImageUrls),
        ),
      ],
    );
  }

  /// Disposes the provider container and clears the stored configuration.
  /// Safe to call whether or not [initialize] ran.
  static Future<void> dispose() async {
    _container?.dispose();
    _container = null;
    _config = null;
  }
}

Future<String?> _defaultTokenProvider() async =>
    const String.fromEnvironment('CASHUP_POS_TOKEN');

/// The complete SDK-owned application shell.
///
/// Pass this directly to `runApp` after [CashupPos.initialize]. Its provider
/// scope, theme and navigator own every screen and nested SDK route.
class CashupPosApp extends StatelessWidget {
  const CashupPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (!CashupPos.isInitialized) {
      throw StateError(
        'CashupPos.initialize() must be called before CashupPosApp is built.',
      );
    }

    final config = CashupPos.config;
    return UncontrolledProviderScope(
      container: CashupPos.container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: config.merchant.name,
        theme: config.theme.toThemeData(Brightness.light),
        darkTheme: config.theme.toThemeData(Brightness.dark),
        home: const PosHomePage(),
      ),
    );
  }
}

class _SdkDemoPaymentHandler implements PosPaymentHandler {
  const _SdkDemoPaymentHandler();

  @override
  Set<String> get supportedMethods => const {'CARD'};

  @override
  Future<PosPaymentResult> pay({
    required String method,
    required double amount,
    required String merchantTrxId,
    int? transactionId,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    return PosPaymentResult.success(
      reference: 'DEMO-$merchantTrxId',
      approvalCode: '123456',
      cardMasked: '4111 **** **** 1111',
      raw: {'method': method, 'amount': amount},
    );
  }
}

class _SdkDemoQrisGateway implements QrisGateway {
  final Map<String, int> _checks = {};

  static const _demoQrString =
      '00020101021226610016ID.CO.CASHUP.WWW0118936000000000000000'
      '0215DEMO000000000005204599953033605802ID5909TOKO DEMO6007JAKARTA'
      '6304ABCD';

  @override
  Future<QrisPayload> generate({
    required double amount,
    String? merchantTrxId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return QrisPayload(
      qrString: _demoQrString,
      invoiceNumber: 'DEMO-INV-${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  @override
  Future<QrisStatus> checkStatus({
    required String invoiceNumber,
    String? merchantTrxId,
  }) async {
    final count = (_checks[invoiceNumber] ?? 0) + 1;
    _checks[invoiceNumber] = count;
    return count < 3 ? QrisStatus.pending : QrisStatus.paid;
  }
}

/// Navigation entry points a host calls to push the POS UI.
///
/// Every method wraps its route in
/// `UncontrolledProviderScope(container: CashupPos.container, child: ...)`
/// **and** a `Theme` built from `CashupPos.config.theme.toThemeData(...)`
/// (via [_wrapPage]) so SDK state never touches the host's own Riverpod
/// graph and every SDK page actually reflects the host's configured
/// [PosTheme] — not just whatever `Theme.of(context)` the host's app
/// happens to be using at the push site. Requires [CashupPos.initialize]
/// to have run first.
///
/// **Every future route this SDK pushes (Task 23+ included) must go
/// through [_wrapPage]** — it is the one place theming is applied, and a
/// page pushed any other way silently ignores the host's `PosTheme`.
class CashupPosLauncher {
  CashupPosLauncher._();

  /// Opens the responsive main POS entry page.
  static Future<void> open(BuildContext context) =>
      _openPage(context, const PosHomePage());

  /// Opens the transaction history / list page.
  static Future<void> openTransactions(BuildContext context) =>
      _openPage(context, const TransactionListPage());

  /// Opens product and category management.
  static Future<void> openProductManagement(BuildContext context) =>
      _openPage(context, const ManageProductPage());

  /// Opens POS settings (payment setting, receipt footer, etc).
  static Future<void> openSettings(BuildContext context) =>
      _openPage(context, const PaymentSettingPage());

  static Future<void> _openPage(BuildContext context, Widget page) {
    if (!CashupPos.isInitialized) {
      throw StateError(
        'CashupPos.initialize() must be called before opening the POS UI.',
      );
    }
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => _wrapPage(context, page)),
    );
  }

  /// Wraps [child] in the provider scope and theme every SDK-pushed route
  /// needs. [context] is the pushing context — read synchronously (before
  /// any `await`), so it is still valid here even though this runs inside
  /// a `MaterialPageRoute.builder` callback.
  ///
  /// Brightness is taken from `Theme.of(context).brightness` — the host
  /// app's *current* light/dark mode at push time — rather than
  /// `MediaQuery.platformBrightnessOf(context)` (the OS-level setting).
  /// This makes the SDK follow whatever light/dark mode the host app is
  /// actually rendering in, including a host that overrides the platform
  /// brightness (e.g. a manual in-app theme toggle) rather than diverging
  /// from it.
  static Widget _wrapPage(BuildContext context, Widget child) {
    return UncontrolledProviderScope(
      container: CashupPos.container,
      child: Theme(
        data: CashupPos.config.theme.toThemeData(Theme.of(context).brightness),
        child: child,
      ),
    );
  }
}
