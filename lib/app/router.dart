import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/onboarding_provider.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/phone_checker/phone_checker_screen.dart';
import '../features/quiz/quiz_screen.dart';
import '../features/scam_checker/scam_checker_screen.dart';
import '../features/scam_checker/scam_result.dart';
import '../features/scam_checker/result_screen.dart';
import '../features/settings/settings_screen.dart';

/// The app's router. It lives in a provider so its redirect can read the
/// onboarding flag. Built once: the redirect reads the flag through a
/// ValueNotifier, and refreshListenable re-runs the redirect when it changes.
final routerProvider = Provider<GoRouter>((ref) {
  final onboardingDone = ValueNotifier<bool>(ref.read(onboardingProvider));
  ref.listen<bool>(onboardingProvider, (_, next) => onboardingDone.value = next);

  final router = GoRouter(
    refreshListenable: onboardingDone,
    // Runs on EVERY navigation, including a web reload or a typed URL, so
    // nobody can skip onboarding by going straight to "/".
    redirect: (context, state) {
      final atOnboarding = state.uri.path == '/onboarding';
      if (!onboardingDone.value && !atOnboarding) return '/onboarding';
      if (onboardingDone.value && atOnboarding) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/check',
        builder: (context, state) => const ScamCheckerScreen(),
      ),
      GoRoute(
        path: '/result',
        builder: (context, state) {
          final result = state.extra as ScamResult;
          return ResultScreen(result: result);
        },
      ),
      GoRoute(
        path: '/phone',
        builder: (context, state) => const PhoneCheckerScreen(),
      ),
      GoRoute(
        path: '/quiz',
        builder: (context, state) => const QuizScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    onboardingDone.dispose();
  });
  return router;
});
