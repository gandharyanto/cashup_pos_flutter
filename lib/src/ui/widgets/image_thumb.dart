/// A rounded-square product/option thumbnail, the single place an
/// `Image.network` is constructed for catalogue and cart imagery.
library;

import 'package:flutter/material.dart';

/// Renders [url] as a thumbnail, always decoded at display size.
///
/// [width] and [height] feed `cacheWidth` / `cacheHeight` (scaled by the
/// device pixel ratio) so a full-resolution product photo never decodes
/// larger than the pixels it is shown at — rule 4 of the performance
/// budget. Falls back to a muted placeholder box with [placeholderIcon]
/// when [url] is null/empty or fails to load.
class ImageThumb extends StatelessWidget {
  /// Creates an image thumbnail.
  const ImageThumb({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.borderRadius,
    this.placeholderIcon,
  });

  /// The image url. Shows the placeholder when null or empty.
  final String? url;

  /// Display width, also used to derive `cacheWidth`.
  final double width;

  /// Display height, also used to derive `cacheHeight`.
  final double height;

  /// Corner radius. Defaults to a 12dp rounded square.
  final BorderRadius? borderRadius;

  /// Icon shown in the placeholder box. Defaults to a generic image icon.
  final IconData? placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(12);
    final imageUrl = url;

    return ClipRRect(
      borderRadius: radius,
      child: imageUrl == null || imageUrl.isEmpty
          ? _placeholder(context)
          : Image.network(
              imageUrl,
              width: width,
              height: height,
              fit: BoxFit.cover,
              cacheWidth: _cachePixels(context, width),
              cacheHeight: _cachePixels(context, height),
              errorBuilder: (context, error, stackTrace) =>
                  _placeholder(context),
            ),
    );
  }

  int _cachePixels(BuildContext context, double logical) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return (logical * dpr).round();
  }

  Widget _placeholder(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            placeholderIcon ?? Icons.image_outlined,
            size: (width < height ? width : height) * 0.4,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
