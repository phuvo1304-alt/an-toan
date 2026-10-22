import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';

/// The card that is always shown with the Voice check, before, during and
/// after a check: An Toàn does NOT judge whether a voice is real or
/// computer-made, and what to do instead. Text lives in the ARB files.
class VoiceHonestyCard extends StatelessWidget {
  const VoiceHonestyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.phone_callback_outlined,
                size: AppIconSize.md, color: scheme.onSecondaryContainer),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.voiceHonestyTitle,
                      style: textTheme.titleSmall?.copyWith(
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpace.xs),
                  Text(t.voiceHonestyBody,
                      style: textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSecondaryContainer)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
