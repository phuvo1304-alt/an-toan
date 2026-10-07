import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// An Toàn design tokens. Every screen takes its colors, spacing, corner radii
// and type from here, so the app looks like one product.
//
// Identity: "Trust blue". Blue is the one hue no risk level uses, so green,
// amber and red stay the only colors that carry a meaning (CLAUDE.md §7).
// ---------------------------------------------------------------------------

/// Brand seed. Material 3 derives every light and dark brand color from it.
const appSeedColor = Color(0xFF1E5AA8);

/// Bundled in assets/fonts (no runtime download). Full Vietnamese coverage.
const appFontFamily = 'BeVietnamPro';

/// Spacing scale. Use these instead of ad-hoc numbers.
abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Corner radius scale.
abstract final class AppRadius {
  static const double sm = 8; // small chips inside text, tags
  static const double md = 12; // buttons, inputs, banners
  static const double lg = 16; // cards
  static const double xl = 24; // dialogs, the result hero
}

/// Icon sizes.
abstract final class AppIconSize {
  static const double sm = 18; // inline with body text
  static const double md = 24; // default
  static const double lg = 32; // list/card leading icons
  static const double xl = 48; // the result hero
  static const double hero = 64; // empty states and intros
}

/// Minimum tap target (Material accessibility guideline).
const double minTapTarget = 48;

/// Risk colors, different for light and dark mode so text stays readable:
/// at least 5.3:1 contrast in light and 5.7:1 in dark against the page and
/// cards (WCAG AA needs 4.5:1). Always shown with an icon AND words, never
/// color alone.
@immutable
class RiskPalette extends ThemeExtension<RiskPalette> {
  final Color safe;
  final Color safeContainer;
  final Color suspicious;
  final Color suspiciousContainer;
  final Color scam;
  final Color scamContainer;

  const RiskPalette({
    required this.safe,
    required this.safeContainer,
    required this.suspicious,
    required this.suspiciousContainer,
    required this.scam,
    required this.scamContainer,
  });

  static const light = RiskPalette(
    safe: Color(0xFF166534),
    safeContainer: Color(0xFFDCFCE7),
    suspicious: Color(0xFF92400E),
    suspiciousContainer: Color(0xFFFEF3C7),
    scam: Color(0xFFB91C1C),
    scamContainer: Color(0xFFFEE2E2),
  );

  static const dark = RiskPalette(
    safe: Color(0xFF4ADE80),
    safeContainer: Color(0xFF12301F),
    suspicious: Color(0xFFFBBF24),
    suspiciousContainer: Color(0xFF3A2B08),
    scam: Color(0xFFF87171),
    scamContainer: Color(0xFF3D1616),
  );

  @override
  RiskPalette copyWith({
    Color? safe,
    Color? safeContainer,
    Color? suspicious,
    Color? suspiciousContainer,
    Color? scam,
    Color? scamContainer,
  }) =>
      RiskPalette(
        safe: safe ?? this.safe,
        safeContainer: safeContainer ?? this.safeContainer,
        suspicious: suspicious ?? this.suspicious,
        suspiciousContainer: suspiciousContainer ?? this.suspiciousContainer,
        scam: scam ?? this.scam,
        scamContainer: scamContainer ?? this.scamContainer,
      );

  @override
  RiskPalette lerp(RiskPalette? other, double t) {
    if (other == null) return this;
    return RiskPalette(
      safe: Color.lerp(safe, other.safe, t)!,
      safeContainer: Color.lerp(safeContainer, other.safeContainer, t)!,
      suspicious: Color.lerp(suspicious, other.suspicious, t)!,
      suspiciousContainer: Color.lerp(suspiciousContainer, other.suspiciousContainer, t)!,
      scam: Color.lerp(scam, other.scam, t)!,
      scamContainer: Color.lerp(scamContainer, other.scamContainer, t)!,
    );
  }
}

/// `context.risk.safe` etc.
extension RiskPaletteContext on BuildContext {
  RiskPalette get risk => Theme.of(this).extension<RiskPalette>()!;
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: appSeedColor, brightness: brightness);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: appFontFamily,
  );
  final text = base.textTheme.copyWith(
    headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
    titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    titleSmall: base.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.5),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.45),
    labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  );

  final controlShape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md));
  const buttonText = TextStyle(
      fontFamily: appFontFamily, fontSize: 16, fontWeight: FontWeight.w600);

  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    extensions: [brightness == Brightness.dark ? RiskPalette.dark : RiskPalette.light],
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: AppSpace.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: controlShape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: controlShape,
        textStyle: buttonText,
        side: BorderSide(color: scheme.outline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(minTapTarget, minTapTarget),
        shape: controlShape,
        textStyle: buttonText.copyWith(fontSize: 15),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(minTapTarget, minTapTarget),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(minTapTarget, minTapTarget),
        textStyle: buttonText.copyWith(fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      // Slightly raised from the page in both modes (Lowest is darker than the page in dark mode).
      fillColor: scheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.all(AppSpace.md),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorColor: scheme.primary,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: scheme.outlineVariant,
      labelStyle: text.labelLarge,
      unselectedLabelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w500),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: AppSpace.xl),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      linearMinHeight: 6,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      minVerticalPadding: AppSpace.md,
      shape: controlShape,
    ),
  );
}
