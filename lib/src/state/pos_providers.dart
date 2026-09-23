/// The SDK's Riverpod provider registry.
///
/// [CashupPos.container] (`cashup_pos_sdk.dart`) is the only
/// [ProviderContainer] these providers ever run in — a host never wraps its
/// own app in a `ProviderScope` for this package (see the package's
/// `CLAUDE.md`). [posConfigProvider] is therefore left as a placeholder body
/// that must be overridden: `CashupPos.initialize` supplies the real
/// [PosConfig] via `ProviderContainer(overrides: [...])` when it creates the
/// container, the same way a host app overrides a required provider on its
/// own `ProviderScope`. Reading it unoverridden (e.g. a container built
/// without going through `CashupPos.initialize`) throws deliberately, the
/// same way [CashupPos.config] does when read before initialization.
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

/// The active host configuration. Overridden by `CashupPos.initialize` when
/// it builds the SDK's [ProviderContainer] — never read successfully before
/// that.
final posConfigProvider = Provider<PosConfig>(
  (ref) => throw UnimplementedError(
    'posConfigProvider has no default — CashupPos.initialize() must '
    'override it with the real PosConfig before any provider reads it.',
  ),
);

/// The Dio-backed client, built once per container from [posConfigProvider].
final posApiClientProvider = Provider<PosApiClient>((ref) {
  final config = ref.watch(posConfigProvider);
  return PosApiClient(
    baseUrl: config.baseUrl,
    tokenProvider: config.tokenProvider,
    extraHeaders: config.extraHeaders,
  );
});

/// The seam every screen depends on — see `PosRepository`'s doc comment.
final posRepositoryProvider = Provider<PosRepository>(
  (ref) => PosRepositoryImpl(ref.watch(posApiClientProvider)),
);

/// The product catalogue: products, categories, and the in-memory filters
/// applied to them. See `catalog_controller.dart`.
final catalogControllerProvider =
    AsyncNotifierProvider<CatalogController, CatalogState>(
      CatalogController.new,
    );

/// The merchant's payment configuration, `null` when none has been set up
/// yet.
final paymentSettingProvider = FutureProvider<PaymentSetting?>(
  (ref) => ref.watch(posRepositoryProvider).paymentSetting(),
);

/// Discounts the cashier may apply by hand.
final activeDiscountsProvider = FutureProvider<List<DiscountItem>>(
  (ref) => ref.watch(posRepositoryProvider).discountList(),
);

/// Promotions the calculation engine evaluates automatically.
final activePromotionsProvider = FutureProvider<List<PromotionItem>>(
  (ref) => ref.watch(posRepositoryProvider).activePromotions(),
);
