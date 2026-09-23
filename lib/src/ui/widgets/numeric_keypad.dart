import 'package:flutter/material.dart';

/// What the special key (`config.specialKeyText`, `"00"` by default) does
/// when pressed. Mirrors Kotlin `SpecialKeyAction`, with `CLEAR` swapped for
/// `decimalPoint` — the port has no use for a dedicated clear key, but every
/// amount-entry keypad that allows decimals needs a `.` key.
enum SpecialKeyAction {
  /// Appends `config.specialKeyText` verbatim (Kotlin `APPEND`).
  append,

  /// Appends a single `.`, subject to the same rules a typed `.` would
  /// follow: ignored when [NumericKeypadConfig.allowDecimal] is false, and
  /// ignored if the value already contains a `.`.
  decimalPoint,

  /// The key is rendered but does nothing (Kotlin's `NONE`).
  none,
}

/// Behaviour for a [NumericKeypad]. Field-for-field port of Kotlin
/// `NumericKeypadConfig`, minus the view-visibility flags (`isTitleVisible`,
/// `isDoneButtonVisible`, ...) that belong to the Kotlin bottom sheet's own
/// chrome rather than to keypad behaviour — this port's title/subtitle/done
/// chrome lives in `showNumericKeypadSheet` instead.
class NumericKeypadConfig {
  const NumericKeypadConfig({
    this.maxLength = 12,
    this.allowDecimal = false,
    this.normalizeLeadingZero = true,
    this.specialKeyText = '00',
    this.specialKeyAction = SpecialKeyAction.append,
  });

  final int maxLength;
  final bool allowDecimal;
  final bool normalizeLeadingZero;
  final String specialKeyText;
  final SpecialKeyAction specialKeyAction;
}

final RegExp _nonDigit = RegExp(r'[^0-9]');
final RegExp _leadingZeros = RegExp(r'^0+');

/// Digits-only keypad. Drives a [ValueNotifier<String>] so a keypress
/// rebuilds the amount label, not the twelve buttons.
///
/// Performance: [build] never reads `value.value`, only `value` itself (to
/// bind press handlers that *write* to it). So nothing here depends on the
/// current text, and the digit/special-key/backspace buttons below are built
/// once when this widget is inserted into the tree and never rebuilt by a
/// keypress — a press mutates the notifier directly, which notifies only
/// whatever the *caller* wrapped in a `ValueListenableBuilder` (the amount
/// label in `showNumericKeypadSheet`), not this widget. There is no
/// `ValueListenableBuilder` anywhere in this file.
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    super.key,
    required this.value,
    this.config = const NumericKeypadConfig(),
    this.onSubmit,
    this.submitLabel,
  });

  final ValueNotifier<String> value;
  final NumericKeypadConfig config;
  final VoidCallback? onSubmit;
  final String? submitLabel;

  void _append(String text) {
    if (text.isEmpty) return;
    if (text == '.') {
      if (!config.allowDecimal) return;
      if (value.value.contains('.')) return;
    }

    var next = '${value.value}$text';
    if (next.length > config.maxLength) {
      next = next.substring(0, config.maxLength);
    }
    value.value = _sanitize(next);
  }

  void _backspace() {
    final current = value.value;
    if (current.isEmpty) return;
    value.value = _sanitize(current.substring(0, current.length - 1));
  }

  void _pressSpecialKey() {
    switch (config.specialKeyAction) {
      case SpecialKeyAction.append:
        _append(config.specialKeyText);
      case SpecialKeyAction.decimalPoint:
        _append('.');
      case SpecialKeyAction.none:
        break;
    }
  }

  String _sanitize(String raw) {
    final digitsOnly = config.allowDecimal
        ? _sanitizeDecimal(raw)
        : raw.replaceAll(_nonDigit, '');
    final truncated = digitsOnly.length > config.maxLength
        ? digitsOnly.substring(0, config.maxLength)
        : digitsOnly;
    return config.normalizeLeadingZero
        ? _normalizeLeadingZeros(truncated)
        : truncated;
  }

  String _sanitizeDecimal(String raw) {
    final buffer = StringBuffer();
    var hasDecimalPoint = false;
    for (final char in raw.split('')) {
      if (_nonDigit.hasMatch(char) == false) {
        buffer.write(char);
      } else if (char == '.' && !hasDecimalPoint) {
        if (buffer.isEmpty) buffer.write('0');
        buffer.write('.');
        hasDecimalPoint = true;
      }
    }
    return buffer.toString();
  }

  String _normalizeLeadingZeros(String value) {
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
    if (parts.length > 1) return '$normalizedInteger.${parts[1]}';
    return normalizedInteger;
  }

  @override
  Widget build(BuildContext context) {
    final showSpecialKey = config.specialKeyAction != SpecialKeyAction.none;

    final grid = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _KeyRow(
          children: [
            _DigitKey('1', onPressed: () => _append('1')),
            _DigitKey('2', onPressed: () => _append('2')),
            _DigitKey('3', onPressed: () => _append('3')),
          ],
        ),
        _KeyRow(
          children: [
            _DigitKey('4', onPressed: () => _append('4')),
            _DigitKey('5', onPressed: () => _append('5')),
            _DigitKey('6', onPressed: () => _append('6')),
          ],
        ),
        _KeyRow(
          children: [
            _DigitKey('7', onPressed: () => _append('7')),
            _DigitKey('8', onPressed: () => _append('8')),
            _DigitKey('9', onPressed: () => _append('9')),
          ],
        ),
        _KeyRow(
          children: [
            _KeypadKey(
              onPressed: showSpecialKey ? _pressSpecialKey : null,
              child: showSpecialKey
                  ? Text(config.specialKeyText)
                  : const SizedBox.shrink(),
            ),
            _DigitKey('0', onPressed: () => _append('0')),
            _KeypadKey(
              onPressed: _backspace,
              child: const Icon(Icons.backspace_outlined),
            ),
          ],
        ),
      ],
    );

    if (onSubmit == null) return grid;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        grid,
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onSubmit,
            child: Text(submitLabel ?? 'Simpan'),
          ),
        ),
      ],
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(children: children.map((key) => Expanded(child: key)).toList());
  }
}

/// A single keypad button. Deliberately dumb: it renders [child] and calls
/// [onPressed] on tap, nothing more — every rule about *what* pressing a key
/// does lives in [NumericKeypad], not here. Its own subtree ([child], an
/// [Icon] or [Text] built from `const`/static data) never changes once
/// built, which is what lets [NumericKeypad] treat these as effectively
/// static children.
class _KeypadKey extends StatelessWidget {
  const _KeypadKey({required this.child, required this.onPressed});

  final Widget child;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 20),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _DigitKey extends StatelessWidget {
  const _DigitKey(this.digit, {required this.onPressed});

  final String digit;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _KeypadKey(onPressed: onPressed, child: Text(digit));
  }
}
