import 'package:flutter/material.dart';

/// The SDK's standard modal dialog chrome: a title row with an optional
/// close button, [child] content, and an optional trailing [actions] row —
/// used with `showDialog(builder: (_) => PosDialog(...))`.
class PosDialog extends StatelessWidget {
  const PosDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.onClose,
    this.maxWidth = 420,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final VoidCallback? onClose;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleLarge),
                  ),
                  if (onClose != null)
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Tutup',
                      onPressed: onClose,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              child,
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var i = 0; i < actions!.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
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
