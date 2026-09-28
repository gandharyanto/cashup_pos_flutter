/// A centered failure placeholder with an optional retry action, shown by
/// [AsyncView] when a value carries an error.
library;

import 'package:flutter/material.dart';

import '../../config/pos_theme.dart';
import '../../data/pos_exception.dart';

// `Color`'s wide-gamut fields aren't const-evaluable, so this is a
// module-level `final`, built once at load — not `const`, and never
// rebuilt inside `build`.
final _spacing = const PosTheme.cashup().spacing;

/// A full-space error placeholder.
///
/// Build one directly with an already-translated [message], or use
/// [ErrorState.fromException] to translate a caught error (a [PosException]
/// or anything else) into Indonesian copy automatically.
class ErrorState extends StatelessWidget {
  /// Creates an error state from an already-translated [message].
  const ErrorState({super.key, required this.message, this.onRetry, this.code});

  /// Indonesian copy ready for direct display.
  final String message;

  /// Called when the cashier taps the "Coba Lagi" button. The button is
  /// omitted entirely when this is null.
  final VoidCallback? onRetry;

  /// An optional error code, rendered as small secondary text.
  final String? code;

  /// Builds an [ErrorState] from a caught [error].
  ///
  /// Uses [PosException.friendlyMessage] (and its `code`) when [error] is a
  /// [PosException]; falls back to a generic Indonesian message otherwise,
  /// since [error] may be any exception a provider surfaced.
  factory ErrorState.fromException(Object error, {VoidCallback? onRetry}) {
    if (error is PosException) {
      return ErrorState(
        message: error.friendlyMessage,
        onRetry: onRetry,
        code: error.code,
      );
    }
    return ErrorState(
      message: 'Terjadi kesalahan. Coba lagi.',
      onRetry: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(_spacing.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
            SizedBox(height: _spacing.m),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (code != null) ...[
              SizedBox(height: _spacing.xs),
              Text(
                'Kode: $code',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (onRetry != null) ...[
              SizedBox(height: _spacing.l),
              FilledButton(onPressed: onRetry, child: const Text('Coba Lagi')),
            ],
          ],
        ),
      ),
    );
  }
}
