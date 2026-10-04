import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import 'scam_result.dart';

class ResultScreen extends StatelessWidget {
  final ScamResult result;
  const ResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    final (Color color, IconData icon, String label) = switch (result.riskLevel) {
      RiskLevel.safe => (RiskColors.safe, Icons.check_circle, t.riskSafe),
      RiskLevel.suspicious => (RiskColors.suspicious, Icons.warning_amber_rounded, t.riskSuspicious),
      RiskLevel.likelyScam => (RiskColors.scam, Icons.dangerous, t.riskLikelyScam),
    };

    return Scaffold(
      appBar: AppBar(title: Text(t.resultTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Risk banner: color + icon + text + number (never color alone)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${t.scoreLabel}: ${result.riskScore}/100',
                          style: textTheme.bodyMedium
                              ?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (result.summary.isNotEmpty)
              Text(result.summary, style: textTheme.bodyLarge),
            const SizedBox(height: 20),

            Text(t.redFlags, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            if (result.redFlags.isEmpty)
              Text(t.noRedFlags)
            else
              ...result.redFlags.map(
                (f) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.flag, color: color, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                f.title,
                                style: textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(f.explanation),
                        if (f.quote.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '"${f.quote}"',
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

            if (result.whatToDo.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(t.whatToDo, style: textTheme.titleMedium),
              const SizedBox(height: 8),
              for (var i = 0; i < result.whatToDo.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${i + 1}. ',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text(result.whatToDo[i])),
                    ],
                  ),
                ),
            ],

            if (result.confidenceNote.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(t.notVerified, style: textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(result.confidenceNote),
            ],

            const SizedBox(height: 20),
            // Disclaimer on every result
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(t.disclaimerBody, style: textTheme.bodySmall),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
