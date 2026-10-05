import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The saved value read in main() before the first frame, so the router's
/// redirect knows the answer right away (no flash of the onboarding screen for
/// returning users). main() overrides this; it is false if nobody does.
final onboardingInitialValueProvider = Provider<bool>((ref) => false);

/// Has the user finished the onboarding slides? Same pattern as LocaleNotifier:
/// start with a default, then load the saved value from shared_preferences.
class OnboardingNotifier extends Notifier<bool> {
  static const key = 'onboarding_complete';

  /// Finishes when the saved value has been loaded (handy in tests).
  late Future<void> loaded;

  @override
  bool build() {
    loaded = _load();
    return ref.read(onboardingInitialValueProvider);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // Only ever switch false -> true here, so a slow load can never undo
    // a markComplete() that happened in the meantime.
    if (prefs.getBool(key) == true) state = true;
  }

  Future<void> markComplete() async {
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, true);
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);
