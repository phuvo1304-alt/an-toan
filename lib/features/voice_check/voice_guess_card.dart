import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import 'voice_result.dart';

/// Section (b) of the result: the voice guess. Exactly three outcomes, never a
/// number, and the full "this is our own system's guess" note is ALWAYS shown
/// right with it (never collapsed, never behind a tap). Icon + text, not
/// colour alone, and deliberately neutral colours: this is a guess, not a
/// warning level.
class VoiceGuessCard extends StatelessWidget {
  final VoiceGuess guess;
  const VoiceGuessCard({super.key, required this.guess});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final (icon, label) = switch (guess) {
      VoiceGuess.human => (Icons.person_outline, t.voiceGuessHuman),
      VoiceGuess.ai => (Icons.smart_toy_outlined, t.voiceGuessAi),
      VoiceGuess.cantTell => (Icons.help_outline, t.voiceGuessCantTell),
    };
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: scheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: AppIconSize.lg, color: scheme.onSurface),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(label,
                      key: const ValueKey('voice-guess-label'),
                      style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Text(t.voiceGuessNote,
                key: const ValueKey('voice-guess-note'), style: textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
