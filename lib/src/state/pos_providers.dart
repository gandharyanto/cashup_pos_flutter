/// The SDK's Riverpod provider graph.
///
/// [CashupPos.initialize] overrides [posConfigProvider] with the host's real
/// `PosConfig` when it builds the SDK's private `ProviderContainer` (see
/// `cashup_pos_sdk.dart`) — every provider below is derived from that one
/// override, so nothing above this file constructs a `PosApiClient` or
/// `PosRepository` directly.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/pos_config.dart';
import '../data/pos_api_client.dart';
import '../data/pos_repository.dart';
import '../data/pos_repository_impl.dart';
import '../models/discount_item.dart';
import '../models/payment_setting.dart';
import '../models/promotion_item.dart';
import 'catalog_controller.dart';

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

/// The catalogue: products, categories, and their in-memory filter/layout
/// state.
final catalogControllerProvider =
    AsyncNotifierProvider<CatalogController, CatalogState>(
      CatalogController.new,
    );

/// The merchant's payment setting (tax/rounding/service charge), or `null`
/// if none has been configured yet.
final paymentSettingProvider = FutureProvider<PaymentSetting?>(
  (ref) => ref.watch(posRepositoryProvider).paymentSetting(),
);

/// Discounts currently available to apply at checkout.
final activeDiscountsProvider = FutureProvider<List<DiscountItem>>(
  (ref) => ref.watch(posRepositoryProvider).discountList(),
);

/// Promotions currently active for this merchant.
final activePromotionsProvider = FutureProvider<List<PromotionItem>>(
  (ref) => ref.watch(posRepositoryProvider).activePromotions(),
);
