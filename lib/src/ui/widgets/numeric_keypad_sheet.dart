import 'package:flutter/material.dart';

import 'numeric_keypad.dart';
import 'pos_bottom_sheet.dart';

/// Shows a [NumericKeypad] in a [showPosBottomSheet], with a title/subtitle
/// header above it, and resolves with the final value when the submit
/// button is pressed (or `null` if the sheet is dismissed another way).
Future<String?> showNumericKeypadSheet(
  BuildContext context, {
  required String title,
  String initialValue = '',
  NumericKeypadConfig config = const NumericKeypadConfig(),
  String? subtitle,
  String submitLabel = 'Simpan',
}) {
  return showPosBottomSheet<String>(
    context,
    title: title,
    builder: (sheetContext) => _NumericKeypadSheetBody(
      initialValue: initialValue,
      subtitle: subtitle,
      config: config,
      submitLabel: submitLabel,
    ),
  );
}

/// Owns the [ValueNotifier] the sheet's [NumericKeypad] and amount label
/// share, and disposes it when the sheet closes.
///
/// The amount label below is the "caller's amount display" the keypad's own
/// doc comment refers to: it is wrapped in a [ValueListenableBuilder], so a
/// keystroke rebuilds only this label — [NumericKeypad] itself never
/// rebuilds in response to the notifier changing.
class _NumericKeypadSheetBody extends StatefulWidget {
  const _NumericKeypadSheetBody({
    required this.initialValue,
    required this.subtitle,
    required this.config,
    required this.submitLabel,
  });

  final String initialValue;
  final String? subtitle;
  final NumericKeypadConfig config;
  final String submitLabel;

  @override
  State<_NumericKeypadSheetBody> createState() =>
      _NumericKeypadSheetBodyState();
}

class _NumericKeypadSheetBodyState extends State<_NumericKeypadSheetBody> {
  late final ValueNotifier<String> _value = ValueNotifier(widget.initialValue);

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_value.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.subtitle != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              widget.subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: ValueListenableBuilder<String>(
            valueListenable: _value,
            builder: (context, current, _) {
              return Text(
                current.isEmpty ? '0' : current,
                style: theme.textTheme.headlineMedium,
              );
            },
          ),
        ),
        NumericKeypad(
          value: _value,
          config: widget.config,
          onSubmit: _submit,
          submitLabel: widget.submitLabel,
        ),
      ],
    );
  }
}
