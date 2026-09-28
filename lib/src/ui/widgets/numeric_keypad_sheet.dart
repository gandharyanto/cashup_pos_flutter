/// A numeric keypad presented in the SDK's standard bottom-sheet chrome —
/// the entry point most callers use instead of composing [NumericKeypad]
/// and [showPosBottomSheet] themselves.
library;

import 'package:flutter/material.dart';

import '../../config/pos_theme.dart';
import 'numeric_keypad.dart';
import 'pos_bottom_sheet.dart';

// `Color`'s wide-gamut fields aren't const-evaluable, so this is a
// module-level `final`, built once at load — not `const`, and never
// rebuilt inside `build`.
final _spacing = const PosTheme.cashup().spacing;

/// Shows a [NumericKeypad] in a bottom sheet and resolves with the entered
/// value once the submit button is tapped, or `null` if the sheet is
/// dismissed without submitting.
Future<String?> showNumericKeypadSheet(
  BuildContext context, {
  required String title,
  String initialValue = '',
  NumericKeypadConfig config = const NumericKeypadConfig(),
  String? subtitle,
  String submitLabel = 'Simpan',
}) {
  final value = ValueNotifier<String>(initialValue);
  return showPosBottomSheet<String>(
    context,
    title: title,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (subtitle != null) ...[
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: _spacing.s),
          ],
          ValueListenableBuilder<String>(
            valueListenable: value,
            builder: (context, current, _) => Text(
              current.isEmpty ? '0' : current,
              textAlign: TextAlign.end,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: _spacing.l),
          NumericKeypad(
            value: value,
            config: config,
            submitLabel: submitLabel,
            onSubmit: () => Navigator.of(sheetContext).pop(value.value),
          ),
        ],
      );
    },
  ).whenComplete(value.dispose);
}
