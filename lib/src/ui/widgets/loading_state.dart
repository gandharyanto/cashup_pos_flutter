/// A centered progress indicator with an optional caption, shown by
/// [AsyncView] while a value is pending.
library;

import 'package:flutter/material.dart';

import '../../config/pos_theme.dart';

// `Color`'s wide-gamut fields aren't const-evaluable, so this is a
// module-level `final`, built once at load — not `const`, and never
// rebuilt inside `build`.
final _spacing = const PosTheme.cashup().spacing;

/// A full-space loading indicator, optionally captioned.
class LoadingState extends StatelessWidget {
  /// Creates a loading state.
  const LoadingState({super.key, this.message});

  /// Optional caption shown below the spinner (e.g. `'Memuat produk...'`).
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            SizedBox(height: _spacing.m),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}
