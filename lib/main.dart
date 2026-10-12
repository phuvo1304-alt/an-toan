import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/onboarding_provider.dart';

Future<void> main() async {
  // Web only: clean "/settings" URLs instead of "/#/settings". A documented
  // no-op on Android/iOS/desktop, called unconditionally (Flutter's own
  // recommended pattern -- no kIsWeb guard needed).
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  // Read the onboarding flag BEFORE the router is built, so its redirect
  // already knows whether to show onboarding on the very first frame.
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool(OnboardingNotifier.key) ?? false;

  runApp(ProviderScope(
    overrides: [
      onboardingInitialValueProvider.overrideWithValue(onboardingDone),
    ],
    child: const AnToanApp(),
  ));
}
