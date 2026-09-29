import 'package:flutter/material.dart';

/// A horizontal, scrollable row of category filter chips, with a leading
/// "Semua" (all) chip that clears the filter.
///
/// [selectedId] is `null` when no single category is selected (the "all"
/// chip is active); [onSelected] is called with `null` for that chip and
/// with a category's `id` for any other.
class CategoryChipBar extends StatelessWidget {
  const CategoryChipBar({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    this.allLabel = 'Semua',
  });

  final List<({int id, String name})> categories;
  final int? selectedId;
  final ValueChanged<int?> onSelected;
  final String allLabel;

  static const double _chipGap = 8;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: _chipGap),
        itemBuilder: (context, index) {
          if (index == 0) {
            return ChoiceChip(
              label: Text(allLabel),
              selected: selectedId == null,
              onSelected: (_) => onSelected(null),
              showCheckmark: false,
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: _labelStyle(context, selectedId == null),
              side: _side(context, selectedId == null),
              shape: const StadiumBorder(),
            );
          }
          final category = categories[index - 1];
          return ChoiceChip(
            label: Text(category.name),
            selected: selectedId == category.id,
            onSelected: (_) => onSelected(category.id),
            showCheckmark: false,
            selectedColor: Theme.of(context).colorScheme.primary,
            labelStyle: _labelStyle(context, selectedId == category.id),
            side: _side(context, selectedId == category.id),
            shape: const StadiumBorder(),
          );
        },
      ),
    );
  }

  TextStyle? _labelStyle(BuildContext context, bool selected) =>
      Theme.of(context).textTheme.labelLarge?.copyWith(
        color: selected
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      );

  BorderSide _side(BuildContext context, bool selected) => BorderSide(
    color: selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outlineVariant,
  );
}
