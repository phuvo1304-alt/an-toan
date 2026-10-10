// Tests for lib/core/text_scale_provider.dart. Same pattern as
// onboarding_test.dart: await `.loaded` for a deterministic read of the
// saved value, and setMockInitialValues for shared_preferences.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:an_toan/core/text_scale_provider.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to medium (factor 1.0, no extra scaling)', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(textScaleProvider), TextSizeOption.medium);
    await container.read(textScaleProvider.notifier).loaded;
    expect(container.read(textScaleProvider), TextSizeOption.medium); // nothing saved yet
    expect(TextSizeOption.medium.factor, 1.0);
  });

  test('setOption() updates state and persists across a fresh provider', () async {
    final first = ProviderContainer();
    final notifier = first.read(textScaleProvider.notifier);
    await notifier.loaded;
    await notifier.setOption(TextSizeOption.extraLarge);
    expect(first.read(textScaleProvider), TextSizeOption.extraLarge);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('text_size'), 'extraLarge');
    first.dispose();

    // A brand-new provider instance, same shared_preferences.
    final second = ProviderContainer();
    addTearDown(second.dispose);
    await second.read(textScaleProvider.notifier).loaded;
    expect(second.read(textScaleProvider), TextSizeOption.extraLarge);
  });

  test('an unrecognized saved value is ignored, stays at the default', () async {
    SharedPreferences.setMockInitialValues({'text_size': 'huge'}); // not a real option
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(textScaleProvider.notifier).loaded;
    expect(container.read(textScaleProvider), TextSizeOption.medium);
  });

  test('factors are ordered and span roughly the documented range', () {
    expect(TextSizeOption.small.factor, lessThan(TextSizeOption.medium.factor));
    expect(TextSizeOption.medium.factor, lessThan(TextSizeOption.large.factor));
    expect(TextSizeOption.large.factor, lessThan(TextSizeOption.extraLarge.factor));
    expect(TextSizeOption.small.factor, closeTo(0.85, 0.001));
    expect(TextSizeOption.extraLarge.factor, closeTo(1.6, 0.001));
  });
}
