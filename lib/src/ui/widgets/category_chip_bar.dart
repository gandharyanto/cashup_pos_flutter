/// A horizontal-scroll row of category filter chips, topped by an "all
/// categories" chip, used above the product browse grid.
library;

import 'package:flutter/material.dart';

import '../../config/pos_theme.dart';

// `Color`'s wide-gamut fields aren't const-evaluable, so this is a
// module-level `final`, built once at load — not `const`, and never
// rebuilt inside `build`.
final _spacing = const PosTheme.cashup().spacing;

/// A scrollable row of category pill chips.
///
/// An "all categories" chip labelled [allLabel] always leads the row;
/// tapping it calls [onSelected] with `null`.
class CategoryChipBar extends StatelessWidget {
  /// Creates a category chip bar.
  const CategoryChipBar({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    this.allLabel = 'Semua',
  });

  /// The categories to show, in order.
  final List<({int id, String name})> categories;

  /// The currently-selected category id, or `null` for "all".
  final int? selectedId;

  /// Called with the tapped category's id, or `null` for the "all" chip.
  final ValueChanged<int?> onSelected;

  /// Label of the leading "all categories" chip.
  final String allLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        separatorBuilder: (context, index) => SizedBox(width: _spacing.s),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CategoryChip(
              label: allLabel,
              selected: selectedId == null,
              onTap: () => onSelected(null),
            );
          }
          final category = categories[index - 1];
          return _CategoryChip(
            label: category.name,
            selected: selectedId == category.id,
            onTap: () => onSelected(category.id),
          );
        },
      ),
    );
  }
}

/// A single rounded-pill chip, filled when selected and outlined otherwise —
/// the same pill shape [SearchField] and [StatusBadge] use.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.primary : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: _spacing.m,
            vertical: _spacing.xs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: selected ? null : Border.all(color: theme.dividerColor),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: selected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
