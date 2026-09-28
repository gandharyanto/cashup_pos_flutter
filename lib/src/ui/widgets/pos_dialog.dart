/// The SDK's modal dialog chrome — a titled, optionally closable card used
/// for confirmations and short forms (e.g. cash payment entry).
library;

import 'package:flutter/material.dart';

import '../../config/pos_theme.dart';

// `Color`'s wide-gamut fields aren't const-evaluable, so this is a
// module-level `final`, built once at load — not `const`, and never
// rebuilt inside `build`.
final _spacing = const PosTheme.cashup().spacing;

/// A titled dialog card. Show it via Flutter's `showDialog`, passing a
/// [PosDialog] as the builder's result.
class PosDialog extends StatelessWidget {
  /// Creates a POS dialog.
  const PosDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.onClose,
    this.maxWidth = 420,
  });

  /// The dialog's title.
  final String title;

  /// The dialog's body content.
  final Widget child;

  /// Buttons shown right-aligned below [child]. Omitted entirely when null.
  final List<Widget>? actions;

  /// Shows a close (`x`) button in the header when set.
  final VoidCallback? onClose;

  /// Caps the dialog's width — dialogs stay narrow even on a wide tablet
  /// screen.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.all(_spacing.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (onClose != null)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: onClose,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              SizedBox(height: _spacing.m),
              Flexible(child: child),
              if (actions != null) ...[
                SizedBox(height: _spacing.l),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var i = 0; i < actions!.length; i++) ...[
                      if (i > 0) SizedBox(width: _spacing.s),
                      actions![i],
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
