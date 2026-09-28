/// A title/subtitle/trailing-action header, used above a [PosPanel]'s
/// content or to open a section of a page.
library;

import 'package:flutter/material.dart';

/// A single-line section heading with an optional subtitle and a trailing
/// widget (e.g. a "lihat semua" link).
class SectionHeader extends StatelessWidget {
  /// Creates a section header.
  const SectionHeader(this.title, {super.key, this.subtitle, this.trailing});

  /// The heading text.
  final String title;

  /// Optional supporting text below [title].
  final String? subtitle;

  /// Optional trailing widget, aligned to the end of the row.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
