/// A bordered surface card, the basic content container used throughout the
/// POS pages (cart summary, product detail, settings sections).
library;

import 'package:flutter/material.dart';

import '../../config/pos_theme.dart';
import 'section_header.dart';

// `Color`'s wide-gamut fields aren't const-evaluable, so this is a
// module-level `final`, built once at load — not `const`, and never
// rebuilt inside `build`.
final _spacing = const PosTheme.cashup().spacing;

/// A rounded, bordered content panel with an optional [SectionHeader].
class PosPanel extends StatelessWidget {
  /// Creates a panel.
  const PosPanel({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding,
  });

  /// The panel's content.
  final Widget child;

  /// Optional heading shown above [child], via [SectionHeader].
  final String? title;

  /// Optional trailing widget on the heading row. Only shown when [title]
  /// is also set.
  final Widget? trailing;

  /// Overrides the default padding around [child].
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      padding: padding ?? EdgeInsets.all(_spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            SectionHeader(title!, trailing: trailing),
            SizedBox(height: _spacing.s),
          ],
          child,
        ],
      ),
    );
  }
}
