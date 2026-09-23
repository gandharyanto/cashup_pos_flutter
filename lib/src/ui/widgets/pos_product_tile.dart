import 'package:flutter/material.dart';

import 'image_thumb.dart';
import 'money_text.dart';

/// Which shape [PosProductTile] renders itself as: a square-image grid cell
/// for the browse grid, or a compact row for admin/search lists.
enum ProductTileLayout { grid, list }

/// A single product's tile, used by the browse grid and by product
/// management (list and grid views alike).
///
/// Takes primitives (`name`, `price`, ...), not a `PosProduct`, so product
/// management and the browse grid can both use it without either owning the
/// other's model.
///
/// A browse grid renders dozens of these at once, and every tile is wrapped
/// in a [RepaintBoundary] at the root of [build] — see the citation in the
/// class body — so panning the grid, or a badge changing on one tile (e.g.
/// [quantityInCart] ticking up after an add-to-cart), never forces its
/// neighbours to repaint.
class PosProductTile extends StatelessWidget {
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

  final String name;
  final double price;
  final ProductTileLayout layout;
  final String? imageUrl;
  final String? sku;
  final String? stockLabel;
  final bool outOfStock;
  final String? badgeLabel;
  final int quantityInCart;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  static const double _listThumbSize = 56;
  static const double _gridImageHeight = 120;
  static const double _quantityBadgeSize = 22;
  static const double _gridCornerRadius = 12;

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary is the outermost widget this build() returns — see
    // the class doc comment. Everything below it (image decode, the
    // in-cart quantity badge, the InkWell ripple) repaints inside this
    // tile's own layer without touching siblings in the grid.
    return RepaintBoundary(
      child: _PosProductTileBody(
        name: name,
        price: price,
        layout: layout,
        imageUrl: imageUrl,
        sku: sku,
        stockLabel: stockLabel,
        outOfStock: outOfStock,
        badgeLabel: badgeLabel,
        quantityInCart: quantityInCart,
        onTap: onTap,
        onLongPress: onLongPress,
        trailing: trailing,
      ),
    );
  }
}

class _PosProductTileBody extends StatelessWidget {
  const _PosProductTileBody({
    required this.name,
    required this.price,
    required this.layout,
    required this.imageUrl,
    required this.sku,
    required this.stockLabel,
    required this.outOfStock,
    required this.badgeLabel,
    required this.quantityInCart,
    required this.onTap,
    required this.onLongPress,
    required this.trailing,
  });

  final String name;
  final double price;
  final ProductTileLayout layout;
  final String? imageUrl;
  final String? sku;
  final String? stockLabel;
  final bool outOfStock;
  final String? badgeLabel;
  final int quantityInCart;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tappable = !outOfStock;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: tappable ? onTap : null,
        onLongPress: tappable ? onLongPress : null,
        child: layout == ProductTileLayout.grid
            ? _buildGrid(context, theme)
            : _buildList(context, theme),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            // The image fills the tile's available width (set by the
            // caller's grid cell) at a fixed height, rather than a square
            // tied to width — a tile dropped into an unbounded-height
            // parent (as in a couple of these widget tests) would otherwise
            // blow past the available height and overflow.
            LayoutBuilder(
              builder: (context, constraints) {
                return ImageThumb(
                  url: imageUrl,
                  width: constraints.maxWidth,
                  height: PosProductTile._gridImageHeight,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(PosProductTile._gridCornerRadius),
                  ),
                );
              },
            ),
            if (badgeLabel != null)
              Positioned(
                left: 6,
                top: 6,
                child: _Pill(
                  label: badgeLabel!,
                  background: theme.colorScheme.secondary,
                  foreground: theme.colorScheme.onSecondary,
                ),
              ),
            if (quantityInCart > 0)
              Positioned(
                right: 6,
                top: 6,
                child: _QuantityBadge(quantity: quantityInCart),
              ),
            if (outOfStock) const Positioned.fill(child: _OutOfStockOverlay()),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: _details(theme, priceStyle: theme.textTheme.titleSmall),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Stack(
            children: [
              ImageThumb(
                url: imageUrl,
                width: PosProductTile._listThumbSize,
                height: PosProductTile._listThumbSize,
                borderRadius: BorderRadius.circular(
                  PosProductTile._gridCornerRadius / 2,
                ),
              ),
              if (outOfStock)
                const Positioned.fill(child: _OutOfStockOverlay(compact: true)),
              if (quantityInCart > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: _QuantityBadge(quantity: quantityInCart),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _details(theme, priceStyle: theme.textTheme.bodyMedium),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _details(ThemeData theme, {TextStyle? priceStyle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (badgeLabel != null && layout == ProductTileLayout.list)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _Pill(
              label: badgeLabel!,
              background: theme.colorScheme.secondary,
              foreground: theme.colorScheme.onSecondary,
            ),
          ),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
        if (sku != null)
          Text(
            sku!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 4),
        MoneyText(price, style: priceStyle),
        // "Stok habis" itself is rendered once, in the image overlay
        // (`_OutOfStockOverlay`) below — not repeated here, so an
        // out-of-stock tile shows the label exactly once.
        if (!outOfStock && stockLabel != null)
          Text(
            stockLabel!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// Darkens the photo and shows the "Stok habis" label, at full opacity so
/// it stays legible over any photo.
class _OutOfStockOverlay extends StatelessWidget {
  const _OutOfStockOverlay({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Text(
          'Stok habis',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: compact ? 9 : 11,
          ),
        ),
      ),
    );
  }
}

class _QuantityBadge extends StatelessWidget {
  const _QuantityBadge({required this.quantity});

  final int quantity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(
        minWidth: PosProductTile._quantityBadgeSize,
        minHeight: PosProductTile._quantityBadgeSize,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        shape: quantity < 10 ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: quantity < 10
            ? null
            : BorderRadius.circular(PosProductTile._quantityBadgeSize),
      ),
      child: Text(
        '$quantity',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: foreground),
      ),
    );
  }
}
