import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../util/currency.dart';

/// One selectable choice inside a [PosOptionGroup] — a variant ("Large") or
/// a modifier ("Extra shot") — with its own price adjustment.
typedef PosOptionChoice = ({int id, String name, double priceDelta});

/// One variant or modifier group rendered by [OptionGroupSelector].
///
/// [multiSelect] `false` renders the group as single-choice (radio); `true`
/// renders it as multi-choice (checkboxes) with [min]/[max] selections
/// enforced.
typedef PosOptionGroup = ({
  int id,
  String name,
  bool multiSelect,
  int min,
  int max,
  List<PosOptionChoice> options,
});

/// One group's current selection: the chosen option ids within [groupId].
///
/// Kept separately from [PosOptionGroup] (rather than an `isSelected` flag
/// on each option) so the caller's selection state stays a plain,
/// immutable value it can diff and persist on its own.
class OptionGroupSelection {
  const OptionGroupSelection({required this.groupId, required this.optionIds});

  final int groupId;
  final List<int> optionIds;
}

/// Renders variant and modifier groups with single/multi selection, min/max
/// enforcement and running price adjustment. Used by the add-to-cart sheet
/// and the product editor.
///
/// Holds no selection state itself: every tap builds a brand-new
/// [OptionGroupSelection] list from [selections] and hands it to
/// [onChanged] — the caller owns the source of truth, matching the
/// immutable-update convention used across the SDK.
class OptionGroupSelector extends StatelessWidget {
  const OptionGroupSelector({
    super.key,
    required this.groups,
    required this.selections,
    required this.onChanged,
  });

  final List<PosOptionGroup> groups;
  final List<OptionGroupSelection> selections;
  final ValueChanged<List<OptionGroupSelection>> onChanged;

  List<int> _selectedIdsFor(int groupId) {
    for (final selection in selections) {
      if (selection.groupId == groupId) return selection.optionIds;
    }
    return const [];
  }

  void _replaceGroupSelection(int groupId, List<int> optionIds) {
    final next = [
      for (final selection in selections)
        if (selection.groupId != groupId) selection,
      OptionGroupSelection(groupId: groupId, optionIds: optionIds),
    ];
    onChanged(next);
  }

  /// Handles a [RadioGroup.onChanged] callback for a single-select group.
  /// `null` arrives when the selected [RadioListTile] is toggled off (only
  /// possible when [PosOptionGroup.min] is 0, since that is the only case a
  /// radio row is built with `toggleable: true`).
  void _handleSingleSelect(PosOptionGroup group, int? optionId) {
    _replaceGroupSelection(group.id, optionId == null ? const [] : [optionId]);
  }

  void _handleMultiToggle(PosOptionGroup group, int optionId, bool select) {
    final current = _selectedIdsFor(group.id);
    if (select) {
      if (current.contains(optionId)) return;
      if (current.length >= group.max) return;
      _replaceGroupSelection(group.id, [...current, optionId]);
      return;
    }
    if (!current.contains(optionId)) return;
    if (current.length <= group.min) return;
    _replaceGroupSelection(
      group.id,
      current.where((id) => id != optionId).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final group in groups) ...[
          _GroupHeader(group: group),
          if (group.multiSelect)
            for (final option in group.options)
              _MultiOptionRow(
                option: option,
                selected: _selectedIdsFor(group.id).contains(option.id),
                onToggle: (value) =>
                    _handleMultiToggle(group, option.id, value ?? false),
                atMax:
                    !_selectedIdsFor(group.id).contains(option.id) &&
                    _selectedIdsFor(group.id).length >= group.max,
              )
          else
            RadioGroup<int>(
              groupValue: _selectedIdsFor(group.id).firstOrNull,
              onChanged: (value) => _handleSingleSelect(group, value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in group.options)
                    _SingleOptionRow(
                      option: option,
                      toggleable: group.min == 0,
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});

  final PosOptionGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = group.multiSelect
        ? 'Pilih ${group.min}-${group.max}'
        : (group.min > 0 ? 'Wajib pilih 1' : 'Opsional');
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(group.name, style: theme.textTheme.titleSmall)),
          Text(
            hint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders [option]'s price adjustment as `+Rp 5.000`, or nothing for a
/// zero-cost option.
Widget? _priceLabel(BuildContext context, PosOptionChoice option) {
  if (option.priceDelta == 0) return null;
  final theme = Theme.of(context);
  return Text(
    '+${Money.format(option.priceDelta)}',
    style: theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ),
  );
}

class _MultiOptionRow extends StatelessWidget {
  const _MultiOptionRow({
    required this.option,
    required this.selected,
    required this.onToggle,
    required this.atMax,
  });

  final PosOptionChoice option;
  final bool selected;
  final ValueChanged<bool?> onToggle;
  final bool atMax;

  @override
  Widget build(BuildContext context) {
    final disabled = !selected && atMax;
    return CheckboxListTile(
      value: selected,
      onChanged: disabled ? null : onToggle,
      title: Text(option.name),
      secondary: _priceLabel(context, option),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}

class _SingleOptionRow extends StatelessWidget {
  const _SingleOptionRow({required this.option, required this.toggleable});

  final PosOptionChoice option;
  final bool toggleable;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<int>(
      value: option.id,
      toggleable: toggleable,
      title: Text(option.name),
      secondary: _priceLabel(context, option),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
