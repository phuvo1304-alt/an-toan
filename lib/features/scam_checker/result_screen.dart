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

class _ResultScreenState extends State<ResultScreen> with SingleTickerProviderStateMixin {
  late final Future<List<ReferenceCase>> _casesFuture;

  // One-time entrance animation for the risk bar filling in (never loops,
  // never affects risk_score/risk_level -- only how the bar's fill is drawn
  // in). Skipped (jumps straight to the final value) when the OS asks for
  // reduced motion, via the current MediaQuery.disableAnimationsOf API.
  late final AnimationController _barController;
  late final Animation<double> _barAnimation;
  bool _barAnimationStarted = false;

  @override
  void initState() {
    super.initState();
    // Picked once per screen instance: a rebuild (e.g. theme change) must
    // not reshuffle which two cases are shown.
    _casesFuture = loadReferenceCases()
        .then((all) => pickReferenceCases(all, widget.result.scamType));

    _barController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _barAnimation = CurvedAnimation(parent: _barController, curve: Curves.easeOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery.disableAnimationsOf needs an inherited-widget lookup, which
    // isn't allowed yet in initState -- didChangeDependencies is the
    // earliest safe place. Guarded so the animation only ever starts once.
    if (_barAnimationStarted) return;
    _barAnimationStarted = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _barController.value = 1;
    } else {
      _barController.forward();
    }
  }

  @override
  void dispose() {
    _barController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final t = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final risk = context.risk;

    // One switch drives every risk-dependent visual: colors always come from
    // the RiskPalette theme extension (never hardcoded here), so light/dark
    // mode and the three-tier distinction stay consistent.
    //
    // likely_scam gets the full "hazard label" treatment: a solid, saturated
    // fill (scamStrong) edge-to-edge (zero margin, square corners), white
    // text/icon/bar on top of it, the biggest icon and headline, the
    // thickest bar. scamStrong was chosen and measured (not eyeballed) to
    // give white text/icon at least 4.5:1 contrast on top of it in BOTH
    // modes: 10.02:1 in light, 4.83:1 in dark (see the WCAG test in
    // result_screen_test.dart).
    //
    // suspicious gets a smaller bump in the same direction: a bigger icon
    // and thicker bar than before, a smaller inset than safe's (not full
    // bleed, but tighter), but keeps its calmer pale tint fill -- no solid
    // white-on-color treatment, so it never reads as seriously as
    // likely_scam.
    //
    // safe is visually unchanged -- same fill, margin, icon size and bar as
    // before, just structurally moved outside the scrolling list so all
    // three share one layout.
    //
    // The risk_score number and the bar's target value are never altered --
    // only this framing is.
    final style = switch (result.riskLevel) {
      RiskLevel.safe => (
          fill: risk.safeContainer,
          onFill: risk.safe,
          accent: risk.safe,
          border: risk.safe.withValues(alpha: 0.45),
          borderWidth: 1.5,
          icon: Icons.check_circle,
          iconSize: AppIconSize.xl,
          label: t.riskSafe,
          labelWeight: FontWeight.w600,
          headlineStyle: textTheme.headlineSmall,
          barHeight: 8.0,
          barColor: risk.safe,
          barTrackColor: risk.safe.withValues(alpha: 0.18),
          margin: const EdgeInsets.all(AppSpace.md),
          radius: AppRadius.xl,
          whatToDoStyle: null,
          actionFirst: false,
        ),
      RiskLevel.suspicious => (
          fill: risk.suspiciousContainer,
          onFill: risk.suspicious,
          accent: risk.suspicious,
          border: risk.suspicious.withValues(alpha: 0.6),
          borderWidth: 2.5,
          icon: Icons.warning_amber_rounded,
          iconSize: AppIconSize.xl + 4,
          label: t.riskSuspicious,
          labelWeight: FontWeight.w700,
          headlineStyle: textTheme.headlineSmall,
          barHeight: 10.0,
          barColor: risk.suspicious,
          barTrackColor: risk.suspicious.withValues(alpha: 0.18),
          margin: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
          radius: AppRadius.lg,
          whatToDoStyle: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          actionFirst: true,
        ),
      RiskLevel.likelyScam => (
          fill: risk.scamStrong,
          onFill: Colors.white,
          accent: risk.scam,
          border: null,
          borderWidth: 0.0,
          icon: Icons.gpp_bad,
          iconSize: AppIconSize.xl + 8,
          label: t.riskLikelyScam,
          labelWeight: FontWeight.w800,
          headlineStyle: textTheme.headlineMedium,
          barHeight: 14.0,
          barColor: Colors.white,
          barTrackColor: Colors.white.withValues(alpha: 0.3),
          margin: EdgeInsets.zero,
          radius: 0.0,
          // This text sits on the PAGE below the banner, not on top of
          // `fill` -- stays `risk.scam`, already contrast-verified against
          // the page surface in both modes (6.17:1 light / 6.72:1 dark).
          // `onFill` (white) is only for content drawn directly on the
          // solid banner itself.
          whatToDoStyle: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: risk.scam),
          actionFirst: true,
        ),
    };

    // "What to do" steps: built once, placed either right after the summary
    // (suspicious/likely_scam -- act-on-it-now order) or in their original
    // spot after the reference cases (safe -- nothing urgent to act on).
    final whatToDoWidgets = result.whatToDo.isEmpty
        ? const <Widget>[]
        : [
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
                        style: textTheme.labelLarge?.copyWith(color: scheme.onPrimaryContainer),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(result.whatToDo[i], style: style.whatToDoStyle),
                      ),
                    ),
                  ],
                ),
              ),
          ];

    return Scaffold(
      appBar: AppBar(title: Text(t.resultTitle)),
      body: SafeArea(
        child: Column(
          children: [
            // ---- Risk hero: the visual anchor of the screen.
            // Color + icon + words + number + bar, never color alone.
            Container(
              key: const Key('resultHero'),
              width: double.infinity,
              margin: style.margin,
              padding: const EdgeInsets.all(AppSpace.lg),
              decoration: BoxDecoration(
                color: style.fill,
                borderRadius: BorderRadius.circular(style.radius),
                border: style.border == null
                    ? null
                    : Border.all(color: style.border!, width: style.borderWidth),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(style.icon, color: style.onFill, size: style.iconSize),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Text(
                          style.label,
                          style: style.headlineStyle
                              ?.copyWith(color: style.onFill, fontWeight: style.labelWeight),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.md),
                  Text(
                    '${t.scoreLabel}: ${result.riskScore}/100',
                    style: textTheme.titleSmall?.copyWith(color: style.onFill),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  AnimatedBuilder(
                    animation: _barAnimation,
                    builder: (context, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: LinearProgressIndicator(
                        value: (result.riskScore.clamp(0, 100) / 100) * _barAnimation.value,
                        color: style.barColor,
                        backgroundColor: style.barTrackColor,
                        minHeight: style.barHeight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.md, AppSpace.lg, AppSpace.md, AppSpace.md),
                children: [
                  if (result.summary.isNotEmpty) Text(result.summary, style: textTheme.bodyLarge),
                  const SizedBox(height: AppSpace.lg),

                  if (style.actionFirst) ...[
                    ...whatToDoWidgets,
                    if (whatToDoWidgets.isNotEmpty) const SizedBox(height: AppSpace.lg),
                  ],

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
                                  Icon(Icons.flag, color: style.accent, size: 20),
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

                  if (!style.actionFirst && whatToDoWidgets.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.md),
                    ...whatToDoWidgets,
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
            // FilledButton.tonalIcon (not a plain text link) so this reads as
            // a real, inviting button -- filled background + icon -- rather
            // than disabled-looking text. Keeps the theme's 48x48 minimum
            // tap target (CLAUDE.md section 7) via filledButtonTheme.
            FilledButton.tonalIcon(
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
