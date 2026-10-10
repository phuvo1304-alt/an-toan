import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// How the app's own text-size setting (Settings -> Text size) interacts with
// the OS/system text-scale setting.
//
// Deliberate choice: MULTIPLY on top of the system setting, not override it.
// Someone who already turned on a large system font (their own accessibility
// choice) gets it larger still if they also raise the in-app setting, instead
// of the app silently discarding what they already asked their phone to do.
//
// To keep that combination from ever breaking layout (OS "largest" plus the
// app's own "extra large" could otherwise multiply into something huge), the
// COMBINED result is clamped here, not just the app's own factor.
// ---------------------------------------------------------------------------

const double minCombinedTextScale = 0.85;
const double maxCombinedTextScale = 1.6;

/// The ambient (system) text scaler multiplied by the app's own [appFactor],
/// then clamped to [minCombinedTextScale]-[maxCombinedTextScale] overall.
TextScaler combinedTextScaler(TextScaler ambient, double appFactor) {
  return _ComposedTextScaler(ambient, appFactor).clamp(
    minScaleFactor: minCombinedTextScale,
    maxScaleFactor: maxCombinedTextScale,
  );
}

class _ComposedTextScaler extends TextScaler {
  const _ComposedTextScaler(this.ambient, this.appFactor);

  final TextScaler ambient;
  final double appFactor;

  @override
  double scale(double fontSize) => ambient.scale(fontSize) * appFactor;

  // Backward-compat getter the abstract class still requires an
  // implementation for (see TextScaler docs: kept only for old code, slated
  // for removal). Defined the same way the scale computation itself works:
  // the scaled size for one logical pixel of unscaled font size.
  @override
  double get textScaleFactor => scale(1.0);

  @override
  bool operator ==(Object other) =>
      other is _ComposedTextScaler &&
      other.ambient == ambient &&
      other.appFactor == appFactor;

  @override
  int get hashCode => Object.hash(ambient, appFactor);
}
