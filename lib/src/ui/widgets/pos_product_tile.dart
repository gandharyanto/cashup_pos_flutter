/// A single product card in the browse grid/list, used by both the phone
/// and tablet catalogue pages.
library;

import 'package:flutter/material.dart';

import '../../config/pos_theme.dart';
import 'image_thumb.dart';
import 'money_text.dart';

// `Color`'s wide-gamut fields aren't const-evaluable, so this is a
// module-level `final`, built once at load — not `const`, and never
// rebuilt inside `build`.
final _spacing = const PosTheme.cashup().spacing;

/// How [PosProductTile] arranges its image, name and price.
enum ProductTileLayout {
  /// A square-ish card for a grid of products.
  grid,

  /// A wide row for a dense product list.
  list,
}

/// A product card. Takes primitives, not a `PosProduct`, so product
/// management and the browse grid can both use it without either owning
/// the other's model.
class PosProductTile extends StatelessWidget {
  /// Creates a product tile.
  const PosProductTile({
    super.key,
    required this.name,
    required this.price,
    required this.layout,
    this.imageUrl,
    this.sku,
    this.stockLabel,
    this.outOfStock = false,
    this.badgeLabel,
    this.quantityInCart = 0,
    this.onTap,
    this.onLongPress,
    this.trailing,
  });

  /// The product name.
  final String name;

  /// The unit price.
  final double price;

  /// Grid card vs. list row arrangement.
  final ProductTileLayout layout;

  /// The product's image url, already resolved (see `resolveImageUrl`).
  final String? imageUrl;

  /// Optional SKU, shown as small secondary text.
  final String? sku;

  /// Optional stock caption, e.g. `'Sisa 4'`. Ignored when [outOfStock].
  final String? stockLabel;

  /// When true, shows `'Stok habis'` in place of [stockLabel] and disables
  /// [onTap] / [onLongPress].
  final bool outOfStock;

  /// Optional small corner badge, e.g. a promo tag such as `'-31%'`.
  final String? badgeLabel;

  /// Quantity of this product already in the cart. Renders a small numbered
  /// badge when greater than zero.
  final int quantityInCart;

  /// Called when the tile is tapped. Ignored when [outOfStock].
  final VoidCallback? onTap;

  /// Called on long-press. Ignored when [outOfStock].
  final VoidCallback? onLongPress;

  /// Optional trailing widget, e.g. an "add" affordance.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(12);

    return RepaintBoundary(
      child: Opacity(
        opacity: outOfStock ? 0.55 : 1,
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: outOfStock ? null : onTap,
            onLongPress: outOfStock ? null : onLongPress,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: radius,
              ),
              padding: EdgeInsets.all(_spacing.s),
              child: layout == ProductTileLayout.grid
                  ? _buildGrid(context, theme)
                  : _buildList(context, theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _thumb(context, size: 96),
        SizedBox(height: _spacing.s),
        _name(theme),
        if (sku != null) _sku(theme),
        SizedBox(height: _spacing.xs),
        _price(theme),
        _stockCaption(theme),
        if (trailing != null) ...[SizedBox(height: _spacing.s), trailing!],
      ],
    );
  }

  Widget _buildList(BuildContext context, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _thumb(context, size: 64),
        SizedBox(width: _spacing.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _name(theme),
              if (sku != null) _sku(theme),
              SizedBox(height: _spacing.xs),
              _price(theme),
              _stockCaption(theme),
            ],
          ),
        ),
        if (trailing != null) ...[SizedBox(width: _spacing.s), trailing!],
      ],
    );
  }

  Widget _thumb(BuildContext context, {required double size}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ImageThumb(
          url: imageUrl,
          width: size,
          height: size,
          placeholderIcon: Icons.fastfood_outlined,
        ),
        if (badgeLabel != null)
          Positioned(top: 0, left: 0, child: _CornerBadge(badgeLabel!)),
        if (quantityInCart > 0)
          Positioned(top: -6, right: -6, child: _QuantityBadge(quantityInCart)),
      ],
    );
  }

  Widget _name(ThemeData theme) => Text(
    name,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
  );

  Widget _sku(ThemeData theme) => Text(
    sku!,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ),
  );

  Widget _price(ThemeData theme) => MoneyText(
    price,
    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
  );

  Widget _stockCaption(ThemeData theme) {
    if (outOfStock) {
      return Padding(
        padding: EdgeInsets.only(top: _spacing.xs),
        child: Text(
          'Stok habis',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    if (stockLabel != null) {
      return Padding(
        padding: EdgeInsets.only(top: _spacing.xs),
        child: Text(
          stockLabel!,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// A small corner tag over the product image, e.g. a promo badge.
class _CornerBadge extends StatelessWidget {
  const _CornerBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _spacing.xs, vertical: 2),
      decoration: const BoxDecoration(
        color: Color(0xFFF97316),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A small circular badge showing the quantity of a product already in the
/// cart.
class _QuantityBadge extends StatelessWidget {
  const _QuantityBadge(this.quantity);

  final int quantity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$quantity',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
