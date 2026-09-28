/// Breakpoints and form-factor detection for the SDK's responsive layouts.
///
/// A single POS screen adapts across phone, tablet and wide/desktop-class
/// layouts rather than shipping separate widget trees per device class, so
/// every page reads its target layout through [PosLayout.of] rather than
/// branching on raw pixel widths itself.
library;

import 'package:flutter/widgets.dart';

/// The pixel-width thresholds that separate [PosFormFactor]s.
class PosBreakpoints {
  PosBreakpoints._();

  /// Width at or above which the layout is [PosFormFactor.tablet].
  static const double tablet = 720;

  /// Width at or above which the layout is [PosFormFactor.wide].
  static const double wide = 1080;
}

/// The three layout classes a POS screen adapts to.
enum PosFormFactor {
  /// Narrower than [PosBreakpoints.tablet].
  phone,

  /// From [PosBreakpoints.tablet] up to (excluding) [PosBreakpoints.wide].
  tablet,

  /// [PosBreakpoints.wide] and above.
  wide,
}

/// The resolved layout for the current screen size, computed once per
/// [BuildContext] via [PosLayout.of] and threaded down instead of every
/// widget re-deriving its own breakpoint checks.
class PosLayout {
  /// Creates a layout from an already-resolved [formFactor] and [size].
  const PosLayout(this.formFactor, this.size);

  /// The resolved form factor.
  final PosFormFactor formFactor;

  /// The screen size this layout was resolved from.
  final Size size;

  /// True when [formFactor] is [PosFormFactor.phone].
  bool get isPhone => formFactor == PosFormFactor.phone;

  /// True when [formFactor] is [PosFormFactor.tablet].
  bool get isTablet => formFactor == PosFormFactor.tablet;

  /// True when [formFactor] is [PosFormFactor.wide].
  bool get isWide => formFactor == PosFormFactor.wide;

  /// The number of columns a product grid should use at this form factor.
  int get productGridColumns {
    switch (formFactor) {
      case PosFormFactor.phone:
        return 2;
      case PosFormFactor.tablet:
        return 3;
      case PosFormFactor.wide:
        return 4;
    }
  }

  /// Resolves the [PosLayout] for the current screen size.
  static PosLayout of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final PosFormFactor formFactor;
    if (size.width >= PosBreakpoints.wide) {
      formFactor = PosFormFactor.wide;
    } else if (size.width >= PosBreakpoints.tablet) {
      formFactor = PosFormFactor.tablet;
    } else {
      formFactor = PosFormFactor.phone;
    }
    return PosLayout(formFactor, size);
  }
}
