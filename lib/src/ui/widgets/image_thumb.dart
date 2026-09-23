import 'package:flutter/material.dart';

/// A fixed-size product/category photo, or a placeholder icon when [url] is
/// missing or fails to load.
///
/// Always decodes at display size — [width] and [height] (scaled by the
/// device pixel ratio) feed `cacheWidth` / `cacheHeight` on the underlying
/// [Image.network], so a full-resolution backend photo is never decoded
/// larger than the pixels it is actually shown at. This is rule 4 of the
/// performance budget: a product grid renders dozens of these at once, and
/// decoding at full resolution there is a real jank source, not a
/// theoretical one.
class ImageThumb extends StatelessWidget {
  const ImageThumb({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.borderRadius,
    this.placeholderIcon,
  });

  final String? url;
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final IconData? placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.zero;
    final imageUrl = url;

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: width,
        height: height,
        child: imageUrl == null || imageUrl.isEmpty
            ? _placeholder(context)
            : _networkImage(context, imageUrl),
      ),
    );
  }

  Widget _networkImage(BuildContext context, String imageUrl) {
    final devicePixelRatio =
        MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    final cacheWidth = (width * devicePixelRatio).round();
    final cacheHeight = (height * devicePixelRatio).round();

    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth > 0 ? cacheWidth : null,
      cacheHeight: cacheHeight > 0 ? cacheHeight : null,
      errorBuilder: (context, error, stackTrace) => _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          placeholderIcon ?? Icons.image_outlined,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
