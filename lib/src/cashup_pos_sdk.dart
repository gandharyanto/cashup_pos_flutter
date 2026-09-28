/// The package's public entry point: [CashupPos] holds the host's
/// [PosConfig] and the SDK's own Riverpod container, and
/// [CashupPosLauncher] pushes SDK screens onto the host's navigator.
///
/// The SDK deliberately owns a private `ProviderContainer` rather than
/// relying on a `ProviderScope` the host app may or may not have wrapped
/// itself in — see the "pure online" / seam decisions in `CLAUDE.md`. Every
/// route the SDK pushes is wrapped in an `UncontrolledProviderScope` bound
/// to that container, so SDK state never touches the host's Riverpod graph.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/pos_config.dart';
import 'state/pos_providers.dart';

/// Holds the SDK's configuration and its private Riverpod container for the
/// lifetime of the host's use of the POS.
///
/// A host calls [initialize] once (typically at app startup, after it knows
/// the signed-in user's token), then reads [config] and [container] as
/// needed, and calls [dispose] when the POS is no longer needed — e.g. on
/// sign-out.
class CashupPos {
  CashupPos._();

  static PosConfig? _config;
  static ProviderContainer? _container;

  /// Initializes the SDK with [config].
  ///
  /// Replaces any previous configuration and container — calling this again
  /// (e.g. after a token refresh that changes [PosConfig.tokenProvider])
  /// disposes the previous container first.
  static Future<void> initialize(PosConfig config) async {
    _container?.dispose();
    _config = config;
    _container = ProviderContainer(
      overrides: [posConfigProvider.overrideWithValue(config)],
    );
  }

  /// Whether [initialize] has been called and [dispose] has not since.
  static bool get isInitialized => _config != null;

  /// The active configuration.
  ///
  /// Throws a [StateError] if read before [initialize] has completed.
  static PosConfig get config {
    final config = _config;
    if (config == null) {
      throw StateError(
        'CashupPos.config was read before CashupPos.initialize() completed.',
      );
    }
    return config;
  }

  /// The SDK's own Riverpod container, for internal use by SDK state and by
  /// [CashupPosLauncher] when pushing routes.
  ///
  /// Throws a [StateError] under the same condition as [config].
  static ProviderContainer get container {
    if (_container == null) {
      throw StateError(
        'CashupPos.container was read before CashupPos.initialize() '
        'completed.',
      );
    }
    return _container!;
  }

  /// Tears down the SDK's container and clears the configuration.
  ///
  /// Safe to call whether or not [initialize] was ever called.
  static Future<void> dispose() async {
    _container?.dispose();
    _container = null;
    _config = null;
  }
}

/// Entry points a host app calls to present SDK screens.
///
/// Each method pushes a route wrapped in an `UncontrolledProviderScope`
/// bound to [CashupPos.container], so the pushed screen sees the SDK's own
/// provider graph regardless of what (if anything) the host wrapped its own
/// widget tree in.
class CashupPosLauncher {
  CashupPosLauncher._();

  /// Opens the main POS screen (the sales/checkout flow).
  static Future<void> open(BuildContext context) =>
      _pushPlaceholder(context, 'POS');

  /// Opens the transaction history/list screen.
  static Future<void> openTransactions(BuildContext context) =>
      _pushPlaceholder(context, 'Riwayat Transaksi');

  /// Opens product management (catalogue create/edit).
  static Future<void> openProductManagement(BuildContext context) =>
      _pushPlaceholder(context, 'Manajemen Produk');

  /// Opens POS settings.
  static Future<void> openSettings(BuildContext context) =>
      _pushPlaceholder(context, 'Pengaturan');

  static Future<void> _pushPlaceholder(BuildContext context, String title) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => UncontrolledProviderScope(
          container: CashupPos.container,
          child: _PlaceholderPage(title: title),
        ),
      ),
    );
  }
}

/// Throwaway scaffolding until the real page for each launcher method lands
/// in a later task (Tasks 23+).
class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(child: Text('Belum tersedia')),
    );
  }
}
