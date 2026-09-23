/// Design tokens for the SDK's UI.
///
/// The colour tokens are ported verbatim from the Kotlin source of truth:
/// `feature/pos-tablet/src/main/res/values/pos_design_tokens.xml`
/// (`pos_token_*` colour resources — see each field's doc comment for the
/// exact resource it mirrors and its hex value). That XML file defines only
/// colours, no dimensions, so the spacing scale below is an original choice
/// for this port rather than a ported value — the brief leaves the
/// mapping/grouping to judgement as long as every XML token has a field and
/// the hex values match exactly.
library;

import 'package:flutter/material.dart';

/// Immutable colour and spacing tokens, plus a [toThemeData] bridge to
/// Flutter's [ThemeData]. Every field is `final` and the constructors carry
/// no logic, so a `const PosTheme(...)` (or the default [PosTheme.cashup])
/// can be built once and read on every widget build starting from later
/// tasks without ever being rebuilt.
class PosTheme {
  const PosTheme({
    required this.shellBackground,
    required this.surface,
    required this.surfaceSoft,
    required this.textOnShell,
    required this.textPrimary,
    required this.textSecondary,
    required this.strokeSoft,
    required this.accentSuccess,
    this.spacingXs = 4,
    this.spacingSm = 8,
    this.spacingMd = 16,
    this.spacingLg = 24,
    this.spacingXl = 32,
    this.cornerRadius = 12,
  });

  /// The package default — the tokens as they stand in
  /// `pos_design_tokens.xml` today, unmodified. A host that wants its own
  /// palette constructs [PosTheme] directly instead.
  const PosTheme.cashup()
    : shellBackground = const Color(0xFF212B52),
      surface = const Color(0xFFFFFFFF),
      surfaceSoft = const Color(0xFFF8FAFC),
      textOnShell = const Color(0xFFFFFFFF),
      textPrimary = const Color(0xFF0F172A),
      textSecondary = const Color(0xFF475569),
      strokeSoft = const Color(0xFFE2E8F0),
      accentSuccess = const Color(0xFF10B981),
      spacingXs = 4,
      spacingSm = 8,
      spacingMd = 16,
      spacingLg = 24,
      spacingXl = 32,
      cornerRadius = 12;

  /// `pos_token_shell_bg` — the dark shell chrome behind the POS content
  /// (app bar, nav rail, bottom bar).
  final Color shellBackground;

  /// `pos_token_surface` — the default card/page background on top of the
  /// shell.
  final Color surface;

  /// `pos_token_surface_soft` — a muted surface used for grouped or
  /// secondary content areas.
  final Color surfaceSoft;

  /// `pos_token_text_on_shell` — text/icon colour painted directly on
  /// [shellBackground].
  final Color textOnShell;

  /// `pos_token_text_primary` — the primary text colour on [surface].
  final Color textPrimary;

  /// `pos_token_text_secondary` — secondary/muted text on [surface].
  final Color textSecondary;

  /// `pos_token_stroke_soft` — hairline borders and dividers.
  final Color strokeSoft;

  /// `pos_token_accent_success` — success state accent (paid, in stock,
  /// confirmation actions).
  final Color accentSuccess;

  /// Spacing scale, smallest to largest. Not present in the XML source —
  /// see the library doc comment.
  final double spacingXs;
  final double spacingSm;
  final double spacingMd;
  final double spacingLg;
  final double spacingXl;

  /// Default corner radius for cards, buttons and dialogs.
  final double cornerRadius;

  /// Builds a Material [ThemeData] for [brightness] from these tokens.
  ThemeData toThemeData(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: shellBackground,
      brightness: brightness,
      primary: shellBackground,
      onPrimary: textOnShell,
      secondary: accentSuccess,
      onSecondary: textOnShell,
      surface: isDark ? shellBackground : surface,
      onSurface: isDark ? textOnShell : textPrimary,
    );

    final radius = BorderRadius.circular(cornerRadius);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? shellBackground : surfaceSoft,
      appBarTheme: AppBarTheme(
        backgroundColor: shellBackground,
        foregroundColor: textOnShell,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: isDark ? shellBackground : surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: strokeSoft),
        ),
      ),
      dividerTheme: DividerThemeData(color: strokeSoft, space: spacingMd),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: EdgeInsets.symmetric(
            horizontal: spacingLg,
            vertical: spacingSm,
          ),
        ),
      ),
      textTheme: ThemeData(brightness: brightness).textTheme.apply(
        bodyColor: isDark ? textOnShell : textPrimary,
        displayColor: isDark ? textOnShell : textPrimary,
      ),
    );
  }
}
