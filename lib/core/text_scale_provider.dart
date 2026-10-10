import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The four text-size choices in Settings. `factor` is the app's OWN
/// multiplier; it is combined with the OS text-scale setting (never used
/// alone) -- see lib/app/text_scaling.dart for how the two combine.
enum TextSizeOption {
  small(0.85),
  medium(1.0),
  large(1.3),
  extraLarge(1.6);

  const TextSizeOption(this.factor);
  final double factor;
}

/// Holds the chosen app text-size option. Medium (no extra scaling) is the
/// default. Same pattern as LocaleNotifier/OnboardingNotifier: start with a
/// default, then load the saved value from shared_preferences.
class TextScaleNotifier extends Notifier<TextSizeOption> {
  static const _key = 'text_size';

  /// Finishes when the saved value has been loaded (handy in tests).
  late Future<void> loaded;

  @override
  TextSizeOption build() {
    loaded = _load();
    return TextSizeOption.medium;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_key);
    for (final option in TextSizeOption.values) {
      if (option.name == name) {
        state = option;
        return;
      }
    }
  }

  Future<void> setOption(TextSizeOption option) async {
    state = option;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, option.name);
  }
}

final textScaleProvider =
    NotifierProvider<TextScaleNotifier, TextSizeOption>(TextScaleNotifier.new);
