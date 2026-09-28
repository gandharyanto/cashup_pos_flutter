/// The SDK's public entry point: [CashupPos] holds the host's
/// [PosConfig] and the Riverpod [ProviderContainer] every SDK-internal
/// widget reads from, and [CashupPosLauncher] is how a host pushes the POS
/// UI onto its own [Navigator].
///
/// Nothing under `state/` or `ui/` exists yet (Tasks 17+), so the launcher
/// methods below push a placeholder page rather than a real one — see each
/// method's doc comment. Task 23 replaces `open`'s body with the real
/// entry page; `openTransactions` / `openProductManagement` /
/// `openSettings` are replaced by their own later tasks.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/pos_config.dart';
import 'state/pos_providers.dart';
import 'ui/pages/manage_product_page.dart';
import 'ui/pages/payment_setting_page.dart';
import 'ui/pages/pos_home_page.dart';
import 'ui/pages/transaction_list_page.dart';

/// Owns the SDK's lifecycle: the host's [PosConfig] and the
/// [ProviderContainer] every SDK screen reads from via
/// `UncontrolledProviderScope`.
///
/// A host calls [initialize] once (typically in `main()`, before the app
/// that hosts the POS button is shown) and [dispose] when the SDK is no
/// longer needed (e.g. on sign-out).
class CashupPos {
  CashupPos._();

  static PosConfig? _config;
  static ProviderContainer? _container;

  /// Whether [initialize] has completed and not yet been [dispose]d.
  static bool get isInitialized => _config != null;

  /// The active configuration, as passed to [initialize] — with [baseUrl]
  /// normalised to always carry a trailing slash.
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

  /// Stores [config] (normalising [PosConfig.baseUrl]) and creates a fresh
  /// [ProviderContainer]. Calling this again while already initialized
  /// disposes the previous container first, so a host that re-initializes
  /// (e.g. after switching merchant accounts) never leaks the old one.
  ///
  /// The container overrides `posConfigProvider` with the normalized
  /// config — every other provider in `pos_providers.dart` derives from it,
  /// so nothing else needs to be wired here.
  static Future<void> initialize(PosConfig config) async {
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
            extraHeaders: config.extraHeaders,
            onTransactionCompleted: config.onTransactionCompleted,
          );

    _config = normalized;
    _container = ProviderContainer(
      overrides: [posConfigProvider.overrideWithValue(normalized)],
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
