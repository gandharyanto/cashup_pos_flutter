/// Visual theme tokens for the SDK's UI, ported from the Kotlin tablet
/// feature module's design-token resources.
///
/// Source: `feature/pos-tablet/src/main/res/values/pos_design_tokens.xml`
/// (colours) and the `spacing_*` entries of
/// `feature/pos-tablet/src/main/res/values/dimens.xml` (spacing). Corner
/// radii, icon sizes and component heights from that same `dimens.xml` are
/// layout-specific and belong to individual widgets in later tasks, not
/// here.
library;

import 'package:flutter/material.dart';

/// The colour tokens the POS shell and its screens are built from.
///
/// Field names carry the semantic role, not the token's numeric or literal
/// value, mirroring the `pos_token_*` resource names with the prefix
/// dropped.
class PosColors {
  /// Creates a set of colour tokens.
  const PosColors({
    required this.shellBg,
    required this.surface,
    required this.surfaceSoft,
    required this.textOnShell,
    required this.textPrimary,
    required this.textSecondary,
    required this.strokeSoft,
    required this.accentSuccess,
  });

  /// Background of the outer POS shell/chrome. `pos_token_shell_bg`.
  final Color shellBg;

  /// Default surface colour for cards and panels. `pos_token_surface`.
  final Color surface;

  /// A softer, secondary surface colour. `pos_token_surface_soft`.
  final Color surfaceSoft;

  /// Text colour used against [shellBg]. `pos_token_text_on_shell`.
  final Color textOnShell;

  /// Primary body text colour. `pos_token_text_primary`.
  final Color textPrimary;

  /// Secondary/muted text colour. `pos_token_text_secondary`.
  final Color textSecondary;

  /// Soft borders and dividers. `pos_token_stroke_soft`.
  final Color strokeSoft;

  /// Success/positive accent colour. `pos_token_accent_success`.
  final Color accentSuccess;
}

/// The spacing scale used throughout the SDK's layouts, ported 1:1 from the
/// `spacing_*` dimens (`dp` maps to logical pixels).
class PosSpacing {
  /// Creates a spacing scale.
  const PosSpacing({
    required this.xs,
    required this.s,
    required this.m,
    required this.l,
    required this.xl,
    required this.xxl,
  });

  /// `spacing_xs` — 4dp.
  final double xs;

  /// `spacing_s` — 6dp.
  final double s;

  /// `spacing_m` — 12dp.
  final double m;

  /// `spacing_l` — 16dp.
  final double l;

  /// `spacing_xl` — 24dp.
  final double xl;

  /// `spacing_xxl` — 32dp.
  final double xxl;
}

/// The SDK's theme: colour and spacing tokens plus a [toThemeData] bridge
/// into Flutter's Material theming.
class PosTheme {
  /// Creates a theme from explicit tokens.
  const PosTheme({required this.colors, required this.spacing});

  /// The default Cashup POS theme, built from the tablet feature module's
  /// design tokens.
  const PosTheme.cashup()
    : colors = const PosColors(
        shellBg: Color(0xFF212B52),
        surface: Color(0xFFFFFFFF),
        surfaceSoft: Color(0xFFF8FAFC),
        textOnShell: Color(0xFFFFFFFF),
        textPrimary: Color(0xFF0F172A),
        textSecondary: Color(0xFF475569),
        strokeSoft: Color(0xFFE2E8F0),
        accentSuccess: Color(0xFF10B981),
      ),
      spacing = const PosSpacing(xs: 4, s: 6, m: 12, l: 16, xl: 24, xxl: 32);

  /// The colour tokens.
  final PosColors colors;

  /// The spacing scale.
  final PosSpacing spacing;

  /// Builds a Material 3 [ThemeData] for [brightness] from these tokens.
  ///
  /// There is no Kotlin dark-mode counterpart to mirror, so this seeds a
  /// standard Material 3 colour scheme from the shell colour; in light mode
  /// the token colours are overlaid onto their obvious Material roles, and
  /// in dark mode the seeded scheme is used as-is.
  ThemeData toThemeData(Brightness brightness) {
    final colorScheme = brightness == Brightness.dark
        ? ColorScheme.fromSeed(
            seedColor: colors.shellBg,
            brightness: Brightness.dark,
          )
        : ColorScheme.fromSeed(
            seedColor: colors.shellBg,
            brightness: Brightness.light,
            primary: colors.shellBg,
            secondary: colors.accentSuccess,
            surface: colors.surface,
            onSurface: colors.textPrimary,
            outline: colors.strokeSoft,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? null
          : colors.surfaceSoft,
      dividerColor: colors.strokeSoft,
    );
  }
}
