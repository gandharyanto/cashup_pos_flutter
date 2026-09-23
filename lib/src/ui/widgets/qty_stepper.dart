import 'package:flutter/material.dart';

/// A decrement/value/increment row for adjusting an integer quantity.
///
/// The current quantity lives entirely with the caller — this widget reads
/// [value] and reports changes through [onChanged]; it holds no state of its
/// own, so it never needs to reload or resync.
///
/// At a bound (`value == min` or `value == max`), the corresponding button's
/// `onPressed` is `null` rather than a no-op callback — the button is
/// genuinely disabled (greyed out, not tappable), not merely ignoring taps.
class QtyStepper extends StatelessWidget {
  const QtyStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max,
    this.compact = false,
    this.onEditRequested,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int? max;

  /// Smaller buttons/typography for dense contexts such as a cart line.
  final bool compact;

  /// Tapping the numeric label invokes this instead of nothing — a page can
  /// use it to open [showNumericKeypadSheet] for direct entry. `null`
  /// (default) leaves the label inert.
  final VoidCallback? onEditRequested;

  bool get _canDecrement => value > min;
  bool get _canIncrement => max == null || value < max!;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonSize = compact ? 28.0 : 36.0;
    final valueStyle = compact
        ? theme.textTheme.bodyLarge
        : theme.textTheme.titleMedium;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: Icons.remove,
          size: buttonSize,
          onPressed: _canDecrement ? () => onChanged(value - 1) : null,
        ),
        InkWell(
          onTap: onEditRequested,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
            child: Text('$value', style: valueStyle),
          ),
        ),
        _StepButton(
          icon: Icons.add,
          size: buttonSize,
          onPressed: _canIncrement ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.size,
    required this.onPressed,
  });

  final IconData icon;
  final double size;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: IconButton(
        icon: Icon(icon),
        iconSize: size * 0.6,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
      ),
    );
  }
}
