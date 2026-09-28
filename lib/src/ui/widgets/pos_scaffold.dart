import 'package:flutter/material.dart';

/// The page shell every POS screen builds on: an [AppBar] carrying [title],
/// [actions] and an optional back button, a padded [body], and optional
/// [bottomBar] / [floatingActionButton] slots.
///
/// Colours come entirely from the ambient [AppBarTheme] (set by
/// `PosTheme.toThemeData`), so this widget carries no colour literals.
class PosScaffold extends StatelessWidget {
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

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? bottomBar;
  final Widget? floatingActionButton;

  /// Shows a small status dot next to [title] — a page wires this to its
  /// own connectivity signal; this widget only renders it.
  final bool showConnectivityDot;

  /// When set, replaces the default back button with this callback. When
  /// `null`, [AppBar]'s own `automaticallyImplyLeading` behaviour applies
  /// (a back arrow appears only if the route can pop).
  final VoidCallback? onBack;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: onBack == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Kembali',
                onPressed: onBack,
              ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(title)),
            if (showConnectivityDot) ...[
              const SizedBox(width: 8),
              const _ConnectivityDot(),
            ],
          ],
        ),
        actions: actions,
      ),
      body: Padding(padding: padding ?? const EdgeInsets.all(16), child: body),
      bottomNavigationBar: bottomBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

class _ConnectivityDot extends StatelessWidget {
  const _ConnectivityDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        shape: BoxShape.circle,
      ),
    );
  }
}
