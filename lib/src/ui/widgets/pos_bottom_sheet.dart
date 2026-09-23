import 'package:flutter/material.dart';

/// Shows a modal bottom sheet with the SDK's standard chrome: a title row
/// with a close button, then whatever [builder] returns.
///
/// [isScrollControlled] defaults to `true` so the sheet can grow to fit
/// content taller than half the screen (a numeric keypad, a long form)
/// without being clipped. Pass [maxHeightFactor] (0–1) to additionally cap
/// the sheet's height and let [builder]'s content scroll internally.
Future<T?> showPosBottomSheet<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext) builder,
  bool isScrollControlled = true,
  double? maxHeightFactor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final media = MediaQuery.of(sheetContext);
      final header = Row(
        children: [
          Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Tutup',
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
        ],
      );

      final body = Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 16 + media.viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: 12),
            if (maxHeightFactor != null)
              Flexible(child: builder(sheetContext))
            else
              builder(sheetContext),
          ],
        ),
      );

      if (maxHeightFactor == null) {
        return SafeArea(child: body);
      }

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: media.size.height * maxHeightFactor,
          ),
          child: body,
        ),
      );
    },
  );
}
