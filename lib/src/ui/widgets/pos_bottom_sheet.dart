/// The SDK's modal bottom sheet chrome: a drag handle, a title, and the
/// caller's content — the shell every sheet (numeric keypad, variant
/// picker, schedule picker) is built on.
library;

import 'package:flutter/material.dart';

import '../../config/pos_theme.dart';
import 'section_header.dart';

// `Color`'s wide-gamut fields aren't const-evaluable, so this is a
// module-level `final`, built once at load — not `const`, and never
// rebuilt inside `build`.
final _spacing = const PosTheme.cashup().spacing;

/// Shows a modal bottom sheet with the SDK's standard chrome: rounded top
/// corners, a small drag handle, and [title] above content built by
/// [builder].
///
/// [maxHeightFactor], a fraction of the screen height, caps the sheet's
/// height; content taller than that scrolls. Defaults to 90% of the screen.
Future<T?> showPosBottomSheet<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext) builder,
  bool isScrollControlled = true,
  double? maxHeightFactor,
}) {
  final theme = Theme.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      final maxHeight = media.size.height * (maxHeightFactor ?? 0.9);
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: _spacing.s),
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    _spacing.l,
                    _spacing.m,
                    _spacing.l,
                    0,
                  ),
                  child: SectionHeader(title),
                ),
                Flexible(
                  child: Padding(
                    padding: EdgeInsets.all(_spacing.l),
                    child: builder(sheetContext),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
