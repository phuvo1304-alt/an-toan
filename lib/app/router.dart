import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/quiz/quiz_screen.dart';
import '../features/scam_checker/scam_checker_screen.dart';
import '../features/scam_checker/scam_result.dart';
import '../features/scam_checker/result_screen.dart';
import '../features/settings/settings_screen.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
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
      path: '/quiz',
      builder: (context, state) => const QuizScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
