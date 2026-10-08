import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../l10n/app_localizations.dart';
import 'reference_cases.dart';
import 'scam_result.dart';

class ResultScreen extends StatefulWidget {
  final ScamResult result;
  const ResultScreen({super.key, required this.result});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final Future<List<ReferenceCase>> _casesFuture;

  @override
  void initState() {
    super.initState();
    // Picked once per screen instance: a rebuild (e.g. theme change) must
    // not reshuffle which two cases are shown.
    _casesFuture = loadReferenceCases()
        .then((all) => pickReferenceCases(all, widget.result.scamType));
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
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

            // Real reported cases: client-side lookup by scam_type in the
            // bundled dataset (data/scam_case_reference.json). Never
            // changes the verdict above and never claims to be about this
            // specific message — see realCasesDisclaimer.
            FutureBuilder<List<ReferenceCase>>(
              future: _casesFuture,
              builder: (context, snapshot) {
                final cases = snapshot.data ?? const [];
                if (cases.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(t.realCasesTitle),
                      Text(
                        t.realCasesDisclaimer,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      ...cases.map((c) => _ReferenceCaseCard(
                            caseData: c,
                            languageCode: result.language,
                          )),
                    ],
                  ),
                );
              },
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

/// One entry from the real-case dataset: headline, source, a short
/// paraphrase snippet, and a tappable link to the original article.
class _ReferenceCaseCard extends StatelessWidget {
  final ReferenceCase caseData;
  final String languageCode;

  const _ReferenceCaseCard({
    required this.caseData,
    required this.languageCode,
  });

  static const _snippetMaxLength = 160;

  Future<void> _openSource(BuildContext context) async {
    final t = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(caseData.sourceUrl);
    var opened = false;
    if (uri != null) {
      try {
        opened =
            await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = false;
      }
    }
    if (!opened && messenger.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(t.errorGeneric)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final summary = caseData.summary(languageCode);
    final snippet = summary.length > _snippetMaxLength
        ? '${summary.substring(0, _snippetMaxLength).trimRight()}…'
        : summary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(caseData.headline, style: textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              caseData.sourceName,
              style: textTheme.labelMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (snippet.isNotEmpty) ...[
              const SizedBox(height: AppSpace.sm),
              Text(snippet),
            ],
            const SizedBox(height: AppSpace.xs),
            // TextButton (not a bare InkWell) so the app's textButtonTheme
            // gives it the 48x48 minimum tap target (CLAUDE.md section 7).
            TextButton.icon(
              onPressed: () => _openSource(context),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(t.readArticle),
            ),
          ],
        ),
      ),
    );
  }
}
