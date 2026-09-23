/// Screen-width breakpoints and the derived layout metadata every page and
/// widget in `ui/` reads to decide phone/tablet/wide behaviour (grid column
/// count, panel arrangement, and so on).
///
/// This deliberately depends on [BuildContext] (via [PosLayout.of]), unlike
/// the rest of `util/` — layout resolution is inherently about the current
/// [MediaQuery], and every later UI task needs a single, consistent place to
/// ask "what form factor am I in?" rather than re-deriving breakpoints per
/// page.
library;

import 'package:flutter/widgets.dart';

/// Width thresholds separating [PosFormFactor.phone], [PosFormFactor.tablet]
/// and [PosFormFactor.wide] layouts.
class PosBreakpoints {
  PosBreakpoints._();

  /// Below this width the layout is [PosFormFactor.phone].
  static const double tablet = 720;

  /// At or above this width the layout is [PosFormFactor.wide]; between
  /// [tablet] and this the layout is [PosFormFactor.tablet].
  static const double wide = 1080;
}

/// The form factors the SDK lays pages out for.
enum PosFormFactor { phone, tablet, wide }

/// Resolved layout information for the current [BuildContext].
///
/// Obtain one via [PosLayout.of] inside `build` — it reads
/// [MediaQuery.sizeOf], so a widget that calls it only rebuilds when the
/// screen size actually changes, not on unrelated `MediaQuery` changes
/// (text scale, padding, brightness, ...).
class PosLayout {
  const PosLayout(this.formFactor, this.size);

  final PosFormFactor formFactor;
  final Size size;

  bool get isPhone => formFactor == PosFormFactor.phone;
  bool get isTablet => formFactor == PosFormFactor.tablet;
  bool get isWide => formFactor == PosFormFactor.wide;

  /// Product grid column count for this form factor.
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

  static PosLayout of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return PosLayout(_formFactorFor(size.width), size);
  }

  static PosFormFactor _formFactorFor(double width) {
    if (width >= PosBreakpoints.wide) return PosFormFactor.wide;
    if (width >= PosBreakpoints.tablet) return PosFormFactor.tablet;
    return PosFormFactor.phone;
  }
}
