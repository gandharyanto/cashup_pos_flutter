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
  /// Provider registration is added in a later task (`pos_providers.dart`,
  /// Task 20) — today the container is created empty.
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
    _container = ProviderContainer();
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
/// so SDK state never touches the host's own Riverpod graph, and requires
/// [CashupPos.initialize] to have run first.
class CashupPosLauncher {
  CashupPosLauncher._();

  /// Opens the main POS entry page. Wired to the real page in Task 23 —
  /// today it pushes [_PosPlaceholderPage].
  static Future<void> open(BuildContext context) =>
      _openPlaceholder(context, 'POS');

  /// Opens the transaction history / list page.
  static Future<void> openTransactions(BuildContext context) =>
      _openPlaceholder(context, 'Transaksi');

  /// Opens product and category management.
  static Future<void> openProductManagement(BuildContext context) =>
      _openPlaceholder(context, 'Manajemen Produk');

  /// Opens POS settings (payment setting, receipt footer, etc).
  static Future<void> openSettings(BuildContext context) =>
      _openPlaceholder(context, 'Pengaturan');

  static Future<void> _openPlaceholder(BuildContext context, String title) {
    if (!CashupPos.isInitialized) {
      throw StateError(
        'CashupPos.initialize() must be called before opening the POS UI.',
      );
    }
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => UncontrolledProviderScope(
          container: CashupPos.container,
          child: _PosPlaceholderPage(title: title),
        ),
      ),
    );
  }
}

/// Stand-in page pushed by every [CashupPosLauncher] method until the real
/// pages exist (Tasks 23+). Deliberately minimal: it proves the navigation
/// and provider-scope wiring work without pretending any real screen is
/// built yet.
class _PosPlaceholderPage extends StatelessWidget {
  const _PosPlaceholderPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(child: Text('Belum tersedia di build ini.')),
    );
  }
}
