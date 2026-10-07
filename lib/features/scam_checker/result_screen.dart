import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../l10n/app_localizations.dart';
import 'scam_result.dart';

class ResultScreen extends StatelessWidget {
  final ScamResult result;
  const ResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final risk = context.risk;

    final (Color color, Color container, IconData icon, String label) =
        switch (result.riskLevel) {
      RiskLevel.safe => (risk.safe, risk.safeContainer, Icons.check_circle, t.riskSafe),
      RiskLevel.suspicious =>
        (risk.suspicious, risk.suspiciousContainer, Icons.warning_amber_rounded, t.riskSuspicious),
      RiskLevel.likelyScam =>
        (risk.scam, risk.scamContainer, Icons.dangerous, t.riskLikelyScam),
    };

    return Scaffold(
      appBar: AppBar(title: Text(t.resultTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.md),
          children: [
            // ---- Risk hero: the visual anchor of the screen.
            // Color + icon + words + number + bar, never color alone.
            Container(
              padding: const EdgeInsets.all(AppSpace.lg),
              decoration: BoxDecoration(
                color: container,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: color, size: AppIconSize.xl),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Text(
                          label,
                          style: textTheme.headlineSmall?.copyWith(color: color),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.md),
                  Text(
                    '${t.scoreLabel}: ${result.riskScore}/100',
                    style: textTheme.titleSmall?.copyWith(color: color),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: LinearProgressIndicator(
                      value: (result.riskScore.clamp(0, 100)) / 100,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.18),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
            if (result.summary.isNotEmpty) ...[
              const SizedBox(height: AppSpace.lg),
              Text(result.summary, style: textTheme.bodyLarge),
            ],
            const SizedBox(height: AppSpace.lg),

            SectionTitle(t.redFlags),
            if (result.redFlags.isEmpty)
              Text(t.noRedFlags, style: TextStyle(color: scheme.onSurfaceVariant))
            else
              ...result.redFlags.map(
                (f) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.flag, color: color, size: 20),
                            const SizedBox(width: AppSpace.sm),
                            Expanded(child: Text(f.title, style: textTheme.titleSmall)),
                          ],
                        ),
                        const SizedBox(height: AppSpace.sm),
                        Text(f.explanation),
                        if (f.quote.isNotEmpty) ...[
                          const SizedBox(height: AppSpace.sm),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: AppSpace.sm),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              '"${f.quote}"',
                              style: const TextStyle(fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

            if (result.whatToDo.isNotEmpty) ...[
              const SizedBox(height: AppSpace.md),
              SectionTitle(t.whatToDo),
              for (var i = 0; i < result.whatToDo.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Numbered step marker: the order of the steps matters.
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: textTheme.labelLarge
                              ?.copyWith(color: scheme.onPrimaryContainer),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(result.whatToDo[i]),
                        ),
                      ),
                    ],
                  ),
                ),
            ],

            if (result.confidenceNote.isNotEmpty) ...[
              const SizedBox(height: AppSpace.md),
              SectionTitle(t.notVerified),
              Text(result.confidenceNote),
            ],

            const SizedBox(height: AppSpace.lg),
            // Disclaimer on every result.
            StatusBanner(message: t.disclaimerBody, kind: BannerKind.info),
            const SizedBox(height: AppSpace.lg),
            FilledButton(
              onPressed: () => context.pop(),
              child: Text(t.checkAnother),
            ),
          ],
        ),
      ),
    );
  }
}
