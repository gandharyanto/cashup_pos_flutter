/// A digits-only entry keypad, ported from the Kotlin `custom-component`
/// module's `NumericKeypadBottomSheet` / `NumericKeypadConfig`.
///
/// Source: `custom-component/src/main/java/com/cz/custom/component/
/// NumericKeypadBottomSheet.kt`, as used by `CashPaymentDialog`.
library;

import 'package:flutter/material.dart';

import '../../config/pos_theme.dart';

// `Color`'s wide-gamut fields aren't const-evaluable, so this is a
// module-level `final`, built once at load — not `const`, and never
// rebuilt inside `build`.
final _spacing = const PosTheme.cashup().spacing;

/// What the keypad's special key (bottom-left, default `'00'`) does.
enum SpecialKeyAction {
  /// Appends [NumericKeypadConfig.specialKeyText] to the value.
  append,

  /// Appends a decimal point, subject to the same sanitisation as any other
  /// character (a no-op when [NumericKeypadConfig.allowDecimal] is false).
  decimalPoint,

  /// The special key is not shown.
  none,
}

/// Behaviour of a [NumericKeypad]: how many digits it accepts, whether a
/// decimal point is allowed, and what the special key does.
class NumericKeypadConfig {
  /// Creates a keypad configuration.
  const NumericKeypadConfig({
    this.maxLength = 12,
    this.allowDecimal = false,
    this.normalizeLeadingZero = true,
    this.specialKeyText = '00',
    this.specialKeyAction = SpecialKeyAction.append,
  });

  /// The longest value the keypad will produce, after sanitisation.
  final int maxLength;

  /// Whether a single decimal point is accepted in the value.
  final bool allowDecimal;

  /// Whether leading zeros are stripped after every keystroke (`'007'` →
  /// `'7'`).
  final bool normalizeLeadingZero;

  /// The label of the special key, e.g. `'00'` or `'.'`.
  final String specialKeyText;

  /// What tapping the special key does.
  final SpecialKeyAction specialKeyAction;
}

/// Digits-only keypad. Drives a [ValueNotifier<String>] so a keypress
/// rebuilds the amount label, not the twelve buttons.
///
/// The keypad itself never listens to [value] — it only writes to it on a
/// tap — so its own twelve buttons are built once per [build] call rather
/// than rebuilding on every keystroke. Wrapping the caller's amount display
/// in a `ValueListenableBuilder` (not done here) is what makes the display
/// update.
class NumericKeypad extends StatelessWidget {
  /// Creates a numeric keypad bound to [value].
  const NumericKeypad({
    super.key,
    required this.value,
    this.config = const NumericKeypadConfig(),
    this.onSubmit,
    this.submitLabel,
  });

  /// The buffer the keypad reads from and writes to.
  final ValueNotifier<String> value;

  /// Sanitisation and special-key behaviour.
  final NumericKeypadConfig config;

  /// Called when the submit button is tapped. The submit row is omitted
  /// entirely when this is null.
  final VoidCallback? onSubmit;

  /// Label for the submit button. Ignored when [onSubmit] is null.
  final String? submitLabel;

  void _append(String text) {
    if (text.isEmpty) return;
    value.value = _sanitize(value.value + text, config);
  }

  void _backspace() {
    final current = value.value;
    if (current.isEmpty) return;
    value.value = _sanitize(current.substring(0, current.length - 1), config);
  }

  void _onSpecialKey() {
    switch (config.specialKeyAction) {
      case SpecialKeyAction.append:
        _append(config.specialKeyText);
      case SpecialKeyAction.decimalPoint:
        _append('.');
      case SpecialKeyAction.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = <List<Widget>>[
      [
        _DigitKey('1', onPressed: () => _append('1')),
        _DigitKey('2', onPressed: () => _append('2')),
        _DigitKey('3', onPressed: () => _append('3')),
      ],
      [
        _DigitKey('4', onPressed: () => _append('4')),
        _DigitKey('5', onPressed: () => _append('5')),
        _DigitKey('6', onPressed: () => _append('6')),
      ],
      [
        _DigitKey('7', onPressed: () => _append('7')),
        _DigitKey('8', onPressed: () => _append('8')),
        _DigitKey('9', onPressed: () => _append('9')),
      ],
      [
        if (config.specialKeyAction != SpecialKeyAction.none)
          _DigitKey(config.specialKeyText, onPressed: _onSpecialKey)
        else
          const SizedBox.shrink(),
        _DigitKey('0', onPressed: () => _append('0')),
        _KeypadIconKey(Icons.backspace_outlined, onPressed: _backspace),
      ],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Row(children: [for (final key in row) Expanded(child: key)]),
        if (onSubmit != null) ...[
          SizedBox(height: _spacing.m),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onSubmit,
              child: Text(submitLabel ?? 'Simpan'),
            ),
          ),
        ],
      ],
    );
  }
}

/// One calculator-grid cell showing [label].
class _DigitKey extends StatelessWidget {
  const _DigitKey(this.label, {required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.all(_spacing.xs),
      child: SizedBox(
        height: 56,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// One calculator-grid cell showing an icon, used by the backspace key.
class _KeypadIconKey extends StatelessWidget {
  const _KeypadIconKey(this.icon, {required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.all(_spacing.xs),
      child: SizedBox(
        height: 56,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Icon(icon, color: theme.colorScheme.onSurface),
        ),
      ),
    );
  }
}

/// Sanitises [raw] per [config]: strips disallowed characters, truncates to
/// [NumericKeypadConfig.maxLength] and normalises leading zeros.
///
/// Mirrors the Kotlin `NumericKeypadBottomSheet.sanitizeValue` /
/// `sanitizeDecimal` / `normalizeLeadingZeros`.
final _nonDigit = RegExp(r'[^0-9]');
final _leadingZeros = RegExp(r'^0+');

String _sanitize(String raw, NumericKeypadConfig config) {
  final cleaned = config.allowDecimal
      ? _sanitizeDecimal(raw)
      : raw.replaceAll(_nonDigit, '');
  final truncated = cleaned.length > config.maxLength
      ? cleaned.substring(0, config.maxLength)
      : cleaned;
  return config.normalizeLeadingZero
      ? _normalizeLeadingZeros(truncated, config)
      : truncated;
}

final _digit = RegExp(r'[0-9]');

String _sanitizeDecimal(String raw) {
  final buffer = StringBuffer();
  var hasDecimalPoint = false;
  for (final char in raw.split('')) {
    if (_digit.hasMatch(char)) {
      buffer.write(char);
    } else if (char == '.' && !hasDecimalPoint) {
      if (buffer.isEmpty) buffer.write('0');
      buffer.write('.');
      hasDecimalPoint = true;
    }
  }
  return buffer.toString();
}

String _normalizeLeadingZeros(String value, NumericKeypadConfig config) {
  if (value.isEmpty) return value;

  if (!config.allowDecimal) {
    final trimmed = value.replaceFirst(_leadingZeros, '');
    return trimmed.isEmpty ? '0' : trimmed;
  }

  final hasTrailingDot = value.endsWith('.');
  final parts = value.split('.');
  final integerPart = parts.first.replaceFirst(_leadingZeros, '');
  final normalizedInteger = integerPart.isEmpty ? '0' : integerPart;

  if (hasTrailingDot) return '$normalizedInteger.';
  if (parts.length == 2) return '$normalizedInteger.${parts[1]}';
  return normalizedInteger;
}
