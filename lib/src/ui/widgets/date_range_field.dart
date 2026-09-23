import 'package:flutter/material.dart';

import '../../util/pos_date_utils.dart';

/// A tappable field showing a `start – end` date range, backed by the
/// platform [showDateRangePicker]. Display text goes through [PosDates] —
/// never a raw `DateFormat` built here.
///
/// The selected range lives with the caller: this widget renders [start]/
/// [end] and reports a new pair through [onChanged]; it holds no state.
class DateRangeField extends StatelessWidget {
  const DateRangeField({
    super.key,
    required this.start,
    required this.end,
    required this.onChanged,
    this.label,
  });

  final DateTime? start;
  final DateTime? end;
  final void Function(DateTime start, DateTime end) onChanged;
  final String? label;

  String get _displayText {
    if (start == null || end == null) return 'Pilih tanggal';
    return '${PosDates.display(start!)} – ${PosDates.display(end!)}';
  }

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final initialRange = (start != null && end != null)
        ? DateTimeRange(start: start!, end: end!)
        : null;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDateRange: initialRange,
    );

    if (picked != null) {
      onChanged(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _pickRange(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label ?? 'Rentang tanggal',
          suffixIcon: const Icon(Icons.date_range),
        ),
        child: Text(_displayText),
      ),
    );
  }
}
