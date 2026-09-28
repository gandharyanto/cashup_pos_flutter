/// The outer page shell every POS screen is built on: an app bar with title,
/// back button and actions, a padded body, and optional bottom bar / FAB
/// slots.
library;

import 'package:flutter/material.dart';

import '../../config/pos_theme.dart';

// `Color`'s wide-gamut fields aren't const-evaluable, so this is a
// module-level `final`, built once at load — not `const`, and never
// rebuilt inside `build`.
final _spacing = const PosTheme.cashup().spacing;

/// The standard POS page shell.
class PosScaffold extends StatelessWidget {
  /// Creates a POS scaffold.
  const PosScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.bottomBar,
    this.floatingActionButton,
    this.showConnectivityDot = false,
    this.onBack,
    this.padding,
  });

  /// The app-bar title.
  final String title;

  /// The page's main content, placed below the app bar with [padding].
  final Widget body;

  /// App-bar trailing actions.
  final List<Widget>? actions;

  /// Optional bottom bar (e.g. checkout total + pay button).
  final Widget? bottomBar;

  /// Optional floating action button.
  final Widget? floatingActionButton;

  /// Shows a small connectivity indicator dot next to the title.
  final bool showConnectivityDot;

  /// When set, shows a back button in the app bar that calls this instead
  /// of the default `Navigator.pop`.
  final VoidCallback? onBack;

  /// Overrides the default padding around [body].
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: onBack != null
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack)
            : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title),
            if (showConnectivityDot) ...[
              SizedBox(width: _spacing.s),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        actions: actions,
      ),
      body: Padding(
        padding: padding ?? EdgeInsets.all(_spacing.m),
        child: body,
      ),
      bottomNavigationBar: bottomBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
