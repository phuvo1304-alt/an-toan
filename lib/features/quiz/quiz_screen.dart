import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import 'quiz_data.dart';
import 'quiz_record_provider.dart';
import 'quiz_session.dart';

/// Quiz Mode: start view -> one question at a time -> summary.
class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  QuizSession? _session; // null = start view, not playing yet
  bool _newRecord = false;

  void _startRound() {
    setState(() {
      _session = QuizSession(quizQuestions); // shuffles a fresh copy
      _newRecord = false;
    });
  }

  void _answer(bool saidScam) {
    setState(() => _session!.answer(saidScam: saidScam));
  }

  Future<void> _next() async {
    final session = _session!;
    setState(session.next);
    if (!session.isFinished) return;

    final newRecord = await ref
        .read(quizRecordProvider.notifier)
        .saveRound(score: session.correct, streak: session.bestStreak);
    if (mounted) setState(() => _newRecord = newRecord);
  }

  void _goHome() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final record = ref.watch(quizRecordProvider);
    final session = _session;

    final Widget body;
    if (session == null) {
      body = _StartView(record: record, onStart: _startRound);
    } else if (session.isFinished) {
      body = _SummaryView(
        session: session,
        record: record,
        newRecord: _newRecord,
        onPlayAgain: _startRound,
        onHome: _goHome,
      );
    } else {
      body = _QuestionView(session: session, onAnswer: _answer, onNext: _next);
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.quizTitle)),
      body: SafeArea(child: body),
    );
  }
}

// ---- Start -----------------------------------------------------------------
class _StartView extends StatelessWidget {
  final QuizRecord record;
  final VoidCallback onStart;

  const _StartView({required this.record, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Icon(Icons.quiz_outlined, size: 64),
        const SizedBox(height: 16),
        Text(t.quizIntro, style: textTheme.bodyLarge, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        _RecordCard(record: record),
        const SizedBox(height: 24),
        FilledButton(onPressed: onStart, child: Text(t.quizStart)),
      ],
    );
  }
}

/// "Best: X/12" and best streak, or a hint if the quiz was never played.
class _RecordCard extends StatelessWidget {
  final QuizRecord record;

  const _RecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.emoji_events_outlined, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: record.hasPlayed
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.quizBest(record.bestScore, quizQuestions.length),
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(t.quizBestStreak(record.bestStreak)),
                      ],
                    )
                  : Text(t.quizNoBestYet),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Question --------------------------------------------------------------
class _QuestionView extends StatelessWidget {
  final QuizSession session;
  final void Function(bool saidScam) onAnswer;
  final VoidCallback onNext;

  const _QuestionView({
    required this.session,
    required this.onAnswer,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final question = session.current;
    final done = session.index + (session.isAnswered ? 1 : 0);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Progress, score and streak
        Row(
          children: [
            Expanded(
              child: Text(
                t.quizQuestionProgress(session.index + 1, session.total),
                style: textTheme.titleSmall,
              ),
            ),
            Text(t.quizScore(session.correct, session.total)),
            const SizedBox(width: 12),
            const Icon(Icons.local_fire_department_outlined, size: 20),
            Text(t.quizStreak(session.streak)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: done / session.total),
        const SizedBox(height: 20),

        // The message to judge
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.sms_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(question.message(lang), style: textTheme.bodyLarge),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        if (!session.isAnswered) ...[
          Text(t.quizPrompt, style: textTheme.titleMedium),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.dangerous_outlined),
            label: Text(t.quizAnswerScam),
            onPressed: () => onAnswer(true),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52), // large tap target
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: Text(t.quizAnswerNotScam),
            onPressed: () => onAnswer(false),
          ),
        ] else ...[
          _Feedback(
            correct: session.lastAnswerCorrect!,
            isScam: question.isScam,
            explanation: question.explanation(lang),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onNext,
            child: Text(session.isLastQuestion ? t.quizSeeResults : t.quizNext),
          ),
        ],
      ],
    );
  }
}

/// Right/wrong banner (color + icon + text, never color alone) and the explanation.
class _Feedback extends StatelessWidget {
  final bool correct;
  final bool isScam;
  final String explanation;

  const _Feedback({
    required this.correct,
    required this.isScam,
    required this.explanation,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final color = correct ? RiskColors.safe : RiskColors.scam;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                correct ? Icons.check_circle : Icons.cancel,
                color: Colors.white,
                size: 36,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      correct ? t.quizCorrect : t.quizWrong,
                      style: textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isScam ? t.quizItWasScam : t.quizItWasNotScam,
                      style: textTheme.bodyMedium?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(explanation, style: textTheme.bodyLarge),
      ],
    );
  }
}

// ---- Summary ---------------------------------------------------------------
class _SummaryView extends StatelessWidget {
  final QuizSession session;
  final QuizRecord record;
  final bool newRecord;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  const _SummaryView({
    required this.session,
    required this.record,
    required this.newRecord,
    required this.onPlayAgain,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Icon(Icons.flag_outlined, size: 64),
        const SizedBox(height: 8),
        Text(t.quizSummaryTitle,
            style: textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Text(
          t.quizScore(session.correct, session.total),
          style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(t.quizRoundBestStreak(session.bestStreak),
            style: textTheme.titleMedium, textAlign: TextAlign.center),
        if (newRecord) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, color: RiskColors.suspicious),
              const SizedBox(width: 6),
              Text(t.quizNewRecord,
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
        const SizedBox(height: 24),
        _RecordCard(record: record),
        const SizedBox(height: 24),
        FilledButton(onPressed: onPlayAgain, child: Text(t.quizPlayAgain)),
        const SizedBox(height: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: onHome,
          child: Text(t.quizBackHome),
        ),
      ],
    );
  }
}
