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
      height: 40,
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
            );
          }
          final category = categories[index - 1];
          return ChoiceChip(
            label: Text(category.name),
            selected: selectedId == category.id,
            onSelected: (_) => onSelected(category.id),
          );
        },
      ),
    );
  }
}
