/// Renders variant and modifier groups with single/multi selection and
/// min/max enforcement. Used by the add-to-cart sheet and the product
/// editor.
library;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../config/pos_theme.dart';
import '../../models/option_group.dart';
import '../../util/currency.dart';

// `Color`'s wide-gamut fields aren't const-evaluable, so this is a
// module-level `final`, built once at load — not `const`, and never
// rebuilt inside `build`.
final _spacing = const PosTheme.cashup().spacing;

/// The chosen option ids for one [OptionGroup].
class OptionGroupSelection {
  /// Creates a group selection.
  const OptionGroupSelection({required this.groupId, required this.optionIds});

  /// The group these option ids belong to.
  final int groupId;

  /// The selected option ids within that group.
  final List<int> optionIds;
}

/// Renders variant and modifier groups with single/multi selection, min/max
/// enforcement and running price adjustment. Used by the add-to-cart sheet
/// and the product editor.
///
/// Each option row shows only its own price delta (e.g. `'+Rp 5.000'`) —
/// this widget does not sum a grand total; that is a page-level concern
/// composed alongside it (e.g. a totals panel driven off [selections]).
class OptionGroupSelector extends StatelessWidget {
  /// Creates an option group selector.
  const OptionGroupSelector({
    super.key,
    required this.groups,
    required this.selections,
    required this.onChanged,
  });

  /// The variant/modifier groups to render, in order.
  final List<OptionGroup> groups;

  /// The current selection, one entry per group that has at least one
  /// option chosen.
  final List<OptionGroupSelection> selections;

  /// Called with the full, updated selection list whenever a row's checked
  /// state changes.
  final ValueChanged<List<OptionGroupSelection>> onChanged;

  List<int> _selectedIdsFor(int groupId) =>
      selections.firstWhereOrNull((s) => s.groupId == groupId)?.optionIds ??
      const [];

  void _toggle(OptionGroup group, OptionItem option) {
    final current = _selectedIdsFor(group.groupId);
    final List<int> updated;
    if (group.isSingleSelection) {
      updated = [option.optionId];
    } else if (current.contains(option.optionId)) {
      updated = List.of(current)..remove(option.optionId);
    } else if (group.hasSelectionLimit &&
        current.length >= group.maxSelection) {
      // Row should already be disabled in this state; guard defensively.
      return;
    } else {
      updated = List.of(current)..add(option.optionId);
    }

    final next = selections
        .where((s) => s.groupId != group.groupId)
        .toList(growable: true);
    if (updated.isNotEmpty) {
      next.add(
        OptionGroupSelection(groupId: group.groupId, optionIds: updated),
      );
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) SizedBox(height: _spacing.l),
          _buildGroup(context, groups[i]),
        ],
      ],
    );
  }

  Widget _buildGroup(BuildContext context, OptionGroup group) {
    final theme = Theme.of(context);
    final requiredWord = group.isRequired ? 'Wajib' : 'Opsional';
    final ruleWord = group.isSingleSelection
        ? '1'
        : (group.hasSelectionLimit ? 'maks ${group.maxSelection}' : 'beberapa');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          group.name,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '$requiredWord • Pilih $ruleWord',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: _spacing.xs),
        for (var i = 0; i < group.options.length; i++) ...[
          if (i > 0) Divider(height: 1, color: theme.dividerColor),
          _OptionRow(
            group: group,
            option: group.options[i],
            selectedIds: _selectedIdsFor(group.groupId),
            onTap: () => _toggle(group, group.options[i]),
          ),
        ],
      ],
    );
  }
}

/// One selectable option row: a radio/checkbox indicator, the option name
/// and its price delta.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.group,
    required this.option,
    required this.selectedIds,
    required this.onTap,
  });

  final OptionGroup group;
  final OptionItem option;
  final List<int> selectedIds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = selectedIds.contains(option.optionId);
    final limitReached =
        !group.isSingleSelection &&
        group.hasSelectionLimit &&
        selectedIds.length >= group.maxSelection;
    final disabled = !selected && limitReached;
    final icon = group.isSingleSelection
        ? (selected ? Icons.radio_button_checked : Icons.radio_button_unchecked)
        : (selected ? Icons.check_box : Icons.check_box_outline_blank);
    final deltaText = _priceDeltaText(option.priceAdjustment);
    final indicatorColor = disabled
        ? theme.disabledColor
        : (selected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant);

    return InkWell(
      onTap: disabled ? null : onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: _spacing.s),
        child: Row(
          children: [
            Icon(icon, color: indicatorColor, size: 20),
            SizedBox(width: _spacing.s),
            Expanded(
              child: Text(
                option.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: disabled ? theme.disabledColor : null,
                ),
              ),
            ),
            if (deltaText.isNotEmpty)
              Text(
                deltaText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: disabled
                      ? theme.disabledColor
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _priceDeltaText(double adjustment) {
    if (adjustment == 0) return '';
    final formatted = Money.format(adjustment.abs());
    return adjustment > 0 ? '+$formatted' : '-$formatted';
  }
}
