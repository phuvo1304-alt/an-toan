import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/onboarding_provider.dart';

Future<void> main() async {
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
