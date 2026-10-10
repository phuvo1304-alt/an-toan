// Tests for lib/app/text_scaling.dart: the pure composition/clamping logic,
// independent of any widget tree.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:an_toan/app/text_scaling.dart';

void main() {
  test('multiplies the ambient scaler by the app factor', () {
    final combined = combinedTextScaler(TextScaler.noScaling, 1.3);
    expect(combined.scale(20), closeTo(26, 0.001)); // 20 * 1.0 (ambient) * 1.3
  });

  test('composes with a non-trivial ambient (system) scaler', () {
    final combined = combinedTextScaler(TextScaler.linear(1.2), 1.0);
    expect(combined.scale(20), closeTo(24, 0.001)); // 20 * 1.2 * 1.0
  });

  test('clamps the COMBINED result, not just the app factor', () {
    // OS at its largest (2.0x) plus the app's own extra-large (1.6x) would be
    // 3.2x uncapped -- this is exactly the case the clamp exists for.
    final combined = combinedTextScaler(TextScaler.linear(2.0), 1.6);
    final scaled = combined.scale(20);
    expect(scaled, lessThanOrEqualTo(20 * maxCombinedTextScale + 0.001));
    expect(scaled, closeTo(20 * maxCombinedTextScale, 0.001));
  });

  test('clamps the low end too (tiny OS setting plus app small)', () {
    final combined = combinedTextScaler(TextScaler.linear(0.5), 0.85);
    final scaled = combined.scale(20);
    expect(scaled, greaterThanOrEqualTo(20 * minCombinedTextScale - 0.001));
    expect(scaled, closeTo(20 * minCombinedTextScale, 0.001));
  });

  test('a typical combination (no OS scaling, app medium) is unclamped and exact', () {
    final combined = combinedTextScaler(TextScaler.noScaling, 1.0);
    expect(combined.scale(20), 20);
  });
}
