import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/locale_provider.dart';
import '../../l10n/app_localizations.dart';
import 'training_data.dart';
import 'training_session.dart';

/// One scenario: tap the suspicious parts of the message, then submit.
/// After submit the SAME layout is re-colored in place with explanations.
class TrainingScenarioScreen extends ConsumerStatefulWidget {
  final TrainingScenario scenario;
  const TrainingScenarioScreen({super.key, required this.scenario});

  @override
  ConsumerState<TrainingScenarioScreen> createState() =>
      _TrainingScenarioScreenState();
}

class _TrainingScenarioScreenState extends ConsumerState<TrainingScenarioScreen> {
  @override
  void initState() {
    super.initState();
    // Providers must not change while the tree is building, so start the
    // session right after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(trainingSessionProvider.notifier).start(widget.scenario);
      }
    });
  }

  void _backToList() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/training');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final lang = ref.watch(localeProvider).languageCode;
    final textTheme = Theme.of(context).textTheme;
    final notifier = ref.read(trainingSessionProvider.notifier);
    var session = ref.watch(trainingSessionProvider);
    // Before start() runs (first frame), show this scenario with nothing marked.
    if (session.scenario?.id != widget.scenario.id) {
      session = TrainingSessionState(
          scenario: widget.scenario, tapped: const {}, submitted: false);
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.scenario.title(lang))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(session.submitted ? t.trainingResultIntro : t.trainingInstructions,
                style: textTheme.bodyLarge),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                // Segments sit next to each other and wrap like normal text.
                child: Wrap(
                  runSpacing: 4,
                  children: [
                    for (final segment in widget.scenario.segments)
                      _SegmentView(
                        segment: segment,
                        lang: lang,
                        status: _statusOf(segment, session),
                        onTap: () => notifier.toggleSegment(segment.id),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!session.submitted)
              FilledButton(
                onPressed: notifier.submit,
                child: Text(t.trainingSubmit),
              )
            else ...[
              _Summary(session: session),
              const SizedBox(height: 16),
              FilledButton(onPressed: notifier.reset, child: Text(t.trainingTryAgain)),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: _backToList, child: Text(t.trainingBackToList)),
            ],
          ],
        ),
      ),
    );
  }

  _SegmentStatus _statusOf(ScenarioSegment s, TrainingSessionState session) {
    final tapped = session.tapped.contains(s.id);
    if (!session.submitted) return tapped ? _SegmentStatus.selected : _SegmentStatus.idle;
    if (s.isSuspicious) return tapped ? _SegmentStatus.caught : _SegmentStatus.missed;
    return tapped ? _SegmentStatus.falsePositive : _SegmentStatus.fine;
  }
}

enum _SegmentStatus { idle, selected, caught, missed, falsePositive, fine }

/// One tappable piece of the message. At least 48x48 so even a one-word
/// segment is easy to tap.
class _SegmentView extends StatelessWidget {
  final ScenarioSegment segment;
  final String lang;
  final _SegmentStatus status;
  final VoidCallback onTap;

  const _SegmentView({
    required this.segment,
    required this.lang,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.bodyLarge!;

    // Result colors always come with an icon and a label, never color alone.
    final (Color? color, IconData? icon, String? label) = switch (status) {
      _SegmentStatus.caught => (RiskColors.safe, Icons.check_circle, t.trainingCaughtLabel),
      _SegmentStatus.missed => (RiskColors.scam, Icons.error, t.trainingMissedLabel),
      _SegmentStatus.falsePositive =>
        (RiskColors.suspicious, Icons.info, t.trainingFalsePositiveLabel),
      _ => (null, null, null),
    };
    final selected = status == _SegmentStatus.selected;
    final showResult = color != null;

    final Color? background = showResult
        ? color.withValues(alpha: 0.12)
        : selected
            ? scheme.secondaryContainer
            : null;
    final Border? border = showResult
        ? Border.all(color: color, width: 1.5)
        : selected
            ? Border.all(color: scheme.secondary)
            : null;

    return Semantics(
      button: status == _SegmentStatus.idle || selected,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            decoration: BoxDecoration(
              color: background,
              border: border,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected) ...[
                      Icon(Icons.flag, size: 18, color: scheme.secondary),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        segment.text(lang),
                        style: selected
                            ? textStyle.copyWith(
                                decoration: TextDecoration.underline,
                                decorationColor: scheme.secondary,
                                decorationThickness: 2)
                            : textStyle,
                      ),
                    ),
                  ],
                ),
                if (showResult) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: color),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(label!,
                            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(segment.explanation(lang)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final TrainingSessionState session;
  const _Summary({required this.session});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.trainingSummaryCaught(session.caught.length, session.suspiciousCount),
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(t.trainingSummaryFalsePositives(session.falsePositives.length)),
          ],
        ),
      ),
    );
  }
}
