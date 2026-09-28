/// A `- N +` quantity control, used on cart lines, product tiles and the
/// product-detail sheet.
library;

import 'package:flutter/material.dart';

import '../../config/pos_theme.dart';

// `Color`'s wide-gamut fields aren't const-evaluable, so this is a
// module-level `final`, built once at load — not `const`, and never
// rebuilt inside `build`.
final _spacing = const PosTheme.cashup().spacing;

/// A quantity stepper: two circular +/- buttons around the current [value].
///
/// The decrement button is genuinely disabled (`onPressed: null`) at [min],
/// and the increment button at [max] — not merely a callback that does
/// nothing when tapped.
class QtyStepper extends StatelessWidget {
  /// Creates a quantity stepper.
  const QtyStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max,
    this.compact = false,
    this.onEditRequested,
  });

  /// The current quantity.
  final int value;

  /// Called with the new quantity when a step button is tapped.
  final ValueChanged<int> onChanged;

  /// The lowest quantity the decrement button will reach.
  final int min;

  /// The highest quantity the increment button will reach. Unbounded when
  /// null.
  final int? max;

  /// Renders smaller buttons for dense rows (e.g. a cart line on phone).
  final bool compact;

  /// Called when the number itself is tapped, e.g. to open a numeric
  /// keypad for direct entry. The number is not tappable when this is null.
  final VoidCallback? onEditRequested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canDecrement = value > min;
    final canIncrement = max == null || value < max!;
    final buttonSize = compact ? 28.0 : 36.0;

    final numberStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );

    Widget number = SizedBox(
      width: compact ? 24 : 32,
      child: Text('$value', textAlign: TextAlign.center, style: numberStyle),
    );
    if (onEditRequested != null) {
      number = InkWell(onTap: onEditRequested, child: number);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: Icons.remove,
          size: buttonSize,
          onPressed: canDecrement ? () => onChanged(value - 1) : null,
        ),
        SizedBox(width: _spacing.s),
        number,
        SizedBox(width: _spacing.s),
        _StepButton(
          icon: Icons.add,
          size: buttonSize,
          onPressed: canIncrement ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

/// A circular outline button used by [QtyStepper]'s +/- controls.
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
    final theme = Theme.of(context);
    final enabled = onPressed != null;
    return SizedBox(
      width: size,
      height: size,
      child: IconButton(
        icon: Icon(icon, size: size * 0.5),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: enabled
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurface.withValues(alpha: 0.35),
          side: BorderSide(
            color: enabled
                ? theme.dividerColor
                : theme.dividerColor.withValues(alpha: 0.5),
          ),
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}
