import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/locale_provider.dart';
import '../../l10n/app_localizations.dart';
import 'training_data.dart';

/// Training Mode: the list of bundled scenarios.
class TrainingListScreen extends ConsumerWidget {
  const TrainingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final lang = ref.watch(localeProvider).languageCode;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(t.trainingTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(t.trainingIntro, style: textTheme.bodyLarge),
            const SizedBox(height: 16),
            for (final scenario in trainingScenarios)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push('/training/${scenario.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.school_outlined, size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(scenario.title(lang),
                                  style: textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _TypeBadge(label: scamTypeLabel(scenario.scamType, t)),
                                  _TypeBadge(
                                    label: difficultyLabel(scenario.difficulty, t),
                                    tertiary: true,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String label;
  final bool tertiary;
  const _TypeBadge({required this.label, this.tertiary = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tertiary ? scheme.tertiaryContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              color: tertiary
                  ? scheme.onTertiaryContainer
                  : scheme.onSecondaryContainer,
              fontSize: 13)),
    );
  }
}

/// Readable name for a difficulty level.
String difficultyLabel(TrainingDifficulty d, AppLocalizations t) {
  switch (d) {
    case TrainingDifficulty.easy:
      return t.trainingDifficultyEasy;
    case TrainingDifficulty.medium:
      return t.trainingDifficultyMedium;
    case TrainingDifficulty.hard:
      return t.trainingDifficultyHard;
  }
}

/// Readable name for a SCAM_TYPES value.
String scamTypeLabel(String scamType, AppLocalizations t) {
  switch (scamType) {
    case 'fake_job':
      return t.scamTypeFakeJob;
    case 'fake_scholarship':
      return t.scamTypeFakeScholarship;
    case 'phishing':
      return t.scamTypePhishing;
    case 'impersonation':
      return t.scamTypeImpersonation;
    case 'investment':
      return t.scamTypeInvestment;
    case 'romance':
      return t.scamTypeRomance;
    case 'loan':
      return t.scamTypeLoan;
    default:
      return t.scamTypeOther;
  }
}
