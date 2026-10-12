// Tests for lib/core/theme_option_provider.dart. Same pattern as
// text_scale_provider_test.dart: await `.loaded` for a deterministic read
// of the saved value, and setMockInitialValues for shared_preferences.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:an_toan/core/theme_option_provider.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Hard requirement from the owner: anyone who hasn't explicitly opened
  // Settings and picked an appearance must see exactly what they see today
  // -- the OS light/dark setting, nothing new, nothing opt-out needed.
  test('defaults to system (no explicit choice saved yet)', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(themeOptionProvider), AppThemeOption.system);
    await container.read(themeOptionProvider.notifier).loaded;
    expect(container.read(themeOptionProvider), AppThemeOption.system); // nothing saved yet
  });

  test('setOption() updates state and persists across a fresh provider '
      '(simulated app restart)', () async {
    final first = ProviderContainer();
    final notifier = first.read(themeOptionProvider.notifier);
    await notifier.loaded;
    await notifier.setOption(AppThemeOption.sepia);
    expect(first.read(themeOptionProvider), AppThemeOption.sepia);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_option'), 'sepia');
    first.dispose();

    // A brand-new provider instance, same shared_preferences -- stands in
    // for the app being killed and relaunched.
    final second = ProviderContainer();
    addTearDown(second.dispose);
    await second.read(themeOptionProvider.notifier).loaded;
    expect(second.read(themeOptionProvider), AppThemeOption.sepia);
  });

  test('persists each of light, dark and system too, not just sepia', () async {
    for (final option in [AppThemeOption.light, AppThemeOption.dark, AppThemeOption.system]) {
      SharedPreferences.setMockInitialValues({});
      final first = ProviderContainer();
      await first.read(themeOptionProvider.notifier).loaded;
      await first.read(themeOptionProvider.notifier).setOption(option);
      first.dispose();

      final second = ProviderContainer();
      await second.read(themeOptionProvider.notifier).loaded;
      expect(second.read(themeOptionProvider), option, reason: option.name);
      second.dispose();
    }
  });

  test('an unrecognized saved value is ignored, stays at the default', () async {
    SharedPreferences.setMockInitialValues({'theme_option': 'midnight'}); // not a real option
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(themeOptionProvider.notifier).loaded;
    expect(container.read(themeOptionProvider), AppThemeOption.system);
  });
}
