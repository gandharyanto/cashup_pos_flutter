/// The SDK's core Riverpod DI wiring.
///
/// [CashupPos.initialize] overrides [posConfigProvider] with the host's real
/// `PosConfig` when it builds the SDK's private `ProviderContainer` (see
/// `cashup_pos_sdk.dart`) — [posApiClientProvider] and [posRepositoryProvider]
/// are derived from that one override, so nothing above this file constructs
/// a `PosApiClient` or `PosRepository` directly.
///
/// This file stays deliberately small: each controller (catalogue, cart,
/// checkout, ...) owns its own providers in its own file, built on top of
/// [posRepositoryProvider] here.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/pos_config.dart';
import '../data/pos_api_client.dart';
import '../data/pos_repository.dart';
import '../data/pos_repository_impl.dart';

/// The active `PosConfig`. Reading it before [CashupPos.initialize]'s
/// override is applied is a programming error, hence the default `throw`.
final posConfigProvider = Provider<PosConfig>(
  (ref) => throw UnimplementedError(),
);

/// The dio-backed client, built from [posConfigProvider]. `PosConfig.
/// extraHeaders` is a plain map while `PosApiClient` wants a closure, so it
/// is adapted here.
final posApiClientProvider = Provider<PosApiClient>((ref) {
  final config = ref.watch(posConfigProvider);
  return PosApiClient(
    baseUrl: config.baseUrl,
    tokenProvider: config.tokenProvider,
    extraHeaders: config.extraHeaders == null
        ? null
        : () => config.extraHeaders!,
  );
});

/// The seam every controller talks to instead of [PosApiClient] directly —
/// see the "pure online" decision in `CLAUDE.md`.
final posRepositoryProvider = Provider<PosRepository>(
  (ref) => PosRepositoryImpl(ref.watch(posApiClientProvider)),
);
