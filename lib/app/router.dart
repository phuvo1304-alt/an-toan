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
import '../features/training/training_data.dart';
import '../features/training/training_list_screen.dart';
import '../features/training/training_scenario_screen.dart';
import '../features/voice_check/voice_check_screen.dart';

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
      // /result takes its content via `extra` (a ScamResult object), which
      // only exists in memory for a navigation made within the running app
      // -- it never survives a web page reload or a typed/shared /result
      // URL. Without this, state.extra would be null there and the route's
      // `as ScamResult` cast would crash the whole app on load. Redirect
      // Home instead of crashing; there's no check content to show anyway.
      if (state.uri.path == '/result' && state.extra is! ScamResult) return '/';
      // Same for the Voice check's result page.
      if (state.uri.path == '/voice/result' && state.extra is! ScamResult) return '/voice';
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
        path: '/voice',
        builder: (context, state) => const VoiceCheckScreen(),
        routes: [
          GoRoute(
            path: 'result',
            builder: (context, state) => ResultScreen(
              result: state.extra as ScamResult,
              showVoiceNotice: true,
            ),
          ),
        ],
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
        path: '/training',
        builder: (context, state) => const TrainingListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final id = state.pathParameters['id'];
              final matches = trainingScenarios.where((s) => s.id == id);
              // Unknown id (e.g. an old link): show the list instead.
              return matches.isEmpty
                  ? const TrainingListScreen()
                  : TrainingScenarioScreen(scenario: matches.first);
            },
          ),
        ],
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
