import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's appearance choices in Settings. `system` mirrors the OS
/// light/dark setting -- this is the app's existing behavior today (there
/// was no explicit theme choice before this setting existed, so `system`
/// IS the default everyone already has; adding this setting must not change
/// what anyone sees unless they deliberately open it and pick something
/// else). `sepia` is a warm, reduced-blue-light "reading mode" and is
/// always opt-in, never auto-selected.
enum AppThemeOption { system, light, dark, sepia }

/// Holds the chosen appearance option. Same pattern as
/// LocaleNotifier/TextScaleNotifier: start with the default, then load the
/// saved value from shared_preferences.
class ThemeOptionNotifier extends Notifier<AppThemeOption> {
  static const _key = 'theme_option';

  /// Finishes when the saved value has been loaded (handy in tests).
  late Future<void> loaded;

  @override
  AppThemeOption build() {
    loaded = _load();
    return AppThemeOption.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_key);
    for (final option in AppThemeOption.values) {
      if (option.name == name) {
        state = option;
        return;
      }
    }
  }

  Future<void> setOption(AppThemeOption option) async {
    state = option;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, option.name);
  }
}

final themeOptionProvider =
    NotifierProvider<ThemeOptionNotifier, AppThemeOption>(ThemeOptionNotifier.new);
