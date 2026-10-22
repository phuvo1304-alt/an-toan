import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';

/// The advice card shown with the Voice scam detection, on the screen and on
/// its result: whatever the analysis says, hang up and call back on a number
/// you already know, and never send money or an OTP because of a call. Text
/// lives in the ARB files.
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
                  Text(t.voiceAdviceTitle,
                      style: textTheme.titleSmall?.copyWith(
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpace.xs),
                  Text(t.voiceAdviceBody,
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
