import 'package:flutter/material.dart';

/// A bordered content card with an optional title row.
///
/// Styling (background, border, corner radius) comes entirely from the
/// ambient [CardTheme] — set by `PosTheme.toThemeData` — so this widget
/// carries no colour or radius literals of its own.
class PosPanel extends StatelessWidget {
  const PosPanel({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasHeader = title != null || trailing != null;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.max,
          children: [
            if (hasHeader)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    if (title != null)
                      Expanded(
                        child: Text(title!, style: theme.textTheme.titleMedium),
                      ),
                    ?trailing,
                  ],
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}
