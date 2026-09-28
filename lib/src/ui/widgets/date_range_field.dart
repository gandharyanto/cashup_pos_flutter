/// A tappable field that opens the platform date-range picker, used by the
/// transaction and summary report filters.
library;

import 'package:flutter/material.dart';

import '../../config/pos_theme.dart';
import '../../util/pos_date_utils.dart';

// `Color`'s wide-gamut fields aren't const-evaluable, so this is a
// module-level `final`, built once at load — not `const`, and never
// rebuilt inside `build`.
final _spacing = const PosTheme.cashup().spacing;

/// A read-only field showing `[start, end]` that opens a date-range picker
/// on tap and reports the new range through [onChanged].
class DateRangeField extends StatelessWidget {
  /// Creates a date range field.
  const DateRangeField({
    super.key,
    required this.start,
    required this.end,
    required this.onChanged,
    this.label,
  });

  /// The start of the current range.
  final DateTime start;

  /// The end of the current range.
  final DateTime end;

  /// Called with the newly picked range.
  final void Function(DateTime start, DateTime end) onChanged;

  /// Optional caption shown above the formatted range.
  final String? label;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(start: start, end: end),
    );
    if (picked != null) onChanged(picked.start, picked.end);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _pick(context),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: _spacing.m,
          vertical: _spacing.s,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: _spacing.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (label != null)
                    Text(
                      label!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  Text(
                    '${PosDates.display(start)} - ${PosDates.display(end)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
