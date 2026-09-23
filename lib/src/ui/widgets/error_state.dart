import 'package:flutter/material.dart';

import '../../data/pos_exception.dart';

/// A centred error message with an optional retry action, shown when an
/// [AsyncView] (or any page) fails to load.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry, this.code});

  /// User-facing (Indonesian) message — pass [PosException.friendlyMessage]
  /// rather than [PosException.message] where one is available; see
  /// [ErrorState.fromException].
  final String message;
  final VoidCallback? onRetry;
  final String? code;

  /// Builds an [ErrorState] from any caught [error], using
  /// [PosException.friendlyMessage] and [PosException.code] when [error] is
  /// a [PosException], and [Object.toString] otherwise.
  factory ErrorState.fromException(Object error, {VoidCallback? onRetry}) {
    if (error is PosException) {
      return ErrorState(
        message: error.friendlyMessage,
        onRetry: onRetry,
        code: error.code,
      );
    }
    return ErrorState(message: error.toString(), onRetry: onRetry);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (code != null) ...[
              const SizedBox(height: 4),
              Text(
                'Kode: $code',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Coba Lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
