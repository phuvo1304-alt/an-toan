import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../settings/official_contacts.dart';
import '../voice_check/voice_guess_card.dart';
import '../voice_check/voice_honesty_card.dart';
import '../voice_check/voice_result.dart';
import 'reference_cases.dart';
import 'scam_result.dart';

/// The static, scam_type-keyed consequence sentence for the likely_scam
/// Consequences section (Part C, layer 1) -- l10n ARB strings, never
/// AI-generated, so this carries zero prompt-change risk. [scamType] is the
/// AI's own classification (already tested separately); an unrecognized
/// value (e.g. a future scam_type, or "none"/"" which the prompt never
/// pairs with likely_scam) falls back to a generic sentence rather than
/// showing nothing.
String _consequenceFor(AppLocalizations t, String scamType) {
  switch (scamType) {
    case 'fake_job':
      return t.consequenceFakeJob;
    case 'fake_scholarship':
      return t.consequenceFakeScholarship;
    case 'phishing':
      return t.consequencePhishing;
    case 'impersonation':
      return t.consequenceImpersonation;
    case 'investment':
      return t.consequenceInvestment;
    case 'romance':
      return t.consequenceRomance;
    case 'loan':
      return t.consequenceLoan;
    case 'other':
      return t.consequenceOther;
    default:
      return t.consequenceGeneric;
  }
}

class ResultScreen extends StatefulWidget {
  final ScamResult result;

  /// Set when the result comes from Voice scam detection: adds the voice guess
  /// (with its always-visible note), the call-back advice and what was heard.
  final VoiceResult? voice;
  const ResultScreen({super.key, required this.result, this.voice});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with SingleTickerProviderStateMixin {
  late final Future<List<ReferenceCase>> _casesFuture;
  late final Future<OfficialContact?> _contactFuture;

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
    // not re-rank which cases are shown.
    _casesFuture = loadReferenceCases().then((all) => pickReferenceCases(
          all,
          widget.result.scamType,
          redFlagText: widget.result.redFlags
              .map((f) => '${f.title} ${f.explanation}')
              .toList(),
          summary: widget.result.summary,
          language: widget.result.language,
        ));

    // Picked once per screen instance, same reasoning as _casesFuture.
    _contactFuture = loadOfficialContacts()
        .then((all) => pickContactForScamType(all, widget.result.scamType));

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

  /// Opens a matched reference case's original source (Part D) -- same
  /// pattern as _ReferenceCaseCard._openSource and Settings' contact links:
  /// externalApplication mode, generic error snackbar on failure.
  Future<void> _openMatchSource(BuildContext context, ReferenceCase match) async {
    final t = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(match.sourceUrl);
    var opened = false;
    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
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

    // Official-contact shortcut: ONE contextually-relevant line appended to
    // "what to do", chosen by scam_type (pickContactForScamType), never for
    // safe results -- it links through to the full Settings list rather
    // than repeating the contact's number/URL here.
    final showContactShortcut = result.riskLevel != RiskLevel.safe;

    // "What to do" steps: built once, placed either right after the summary
    // (suspicious/likely_scam -- act-on-it-now order) or in their original
    // spot after the reference cases (safe -- nothing urgent to act on).
    final whatToDoWidgets = (result.whatToDo.isEmpty && !showContactShortcut)
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
            if (showContactShortcut)
              FutureBuilder<OfficialContact?>(
                future: _contactFuture,
                builder: (context, snapshot) {
                  final contact = snapshot.data;
                  if (contact == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      onTap: () => context.push('/settings'),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.support_agent,
                                size: 16, color: scheme.onPrimaryContainer),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                t.officialContactShortcut(contact.orgName(result.language)),
                                style: style.whatToDoStyle ?? textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
                  if (widget.voice != null) SectionTitle(t.voiceSectionScam),
                  if (result.summary.isNotEmpty) Text(result.summary, style: textTheme.bodyLarge),
                  const SizedBox(height: AppSpace.lg),

                  // Consequences section: ONLY for likely_scam (never
                  // suspicious/safe -- those tiers stay calm, per the lesson
                  // from the bank-message false-positive fix, bf52f8b).
                  // Supersedes B1's quiet one-line citation (folded in here,
                  // not duplicated): a static, scam_type-keyed sentence
                  // (l10n ARB, never AI-generated, so this carries zero
                  // prompt-change risk) always shows; when pickReferenceCases'
                  // top result is a confident same-type match (not the
                  // widened-fallback tier), its real summary and a tappable
                  // link to the original source are appended too. Never
                  // changes risk_score/risk_level -- only this framing.
                  if (result.riskLevel == RiskLevel.likelyScam) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpace.md),
                      decoration: BoxDecoration(
                        // errorContainer/onErrorContainer is Material 3's own
                        // guaranteed-contrast error pair (already used by
                        // StatusBanner's error kind in this app) -- chosen
                        // deliberately over a RiskPalette color here so the
                        // text/icon inside this card never needs a fresh,
                        // hand-verified contrast number.
                        color: scheme.errorContainer,
                        border: Border.all(color: risk.scamStrong, width: 2),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.dangerous,
                                  color: scheme.onErrorContainer, size: AppIconSize.lg),
                              const SizedBox(width: AppSpace.sm),
                              Expanded(
                                child: Text(
                                  t.consequencesTitle,
                                  style: textTheme.titleMedium?.copyWith(
                                    color: scheme.onErrorContainer,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpace.sm),
                          Text(
                            _consequenceFor(t, result.scamType),
                            style: textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer),
                          ),
                          FutureBuilder<List<ReferenceCase>>(
                            future: _casesFuture,
                            builder: (context, snapshot) {
                              final cases = snapshot.data ?? const [];
                              if (cases.isEmpty || cases.first.scamType != result.scamType) {
                                return const SizedBox.shrink();
                              }
                              final match = cases.first;
                              return Padding(
                                padding: const EdgeInsets.only(top: AppSpace.sm),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.realOutcomeLabel,
                                      style: textTheme.labelLarge
                                          ?.copyWith(color: scheme.onErrorContainer),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      match.summary(result.language),
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: scheme.onErrorContainer,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpace.sm),
                                    FilledButton.tonalIcon(
                                      onPressed: () => _openMatchSource(context, match),
                                      iconAlignment: IconAlignment.end,
                                      icon: const Icon(Icons.open_in_new, size: 16),
                                      label: Text(t.readOriginalArticle),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),
                  ],

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
                      // A subtle trust-blue tint/border (never a risk color)
                      // so this group visually invites a look without
                      // competing with the risk banner above -- supporting
                      // evidence, not the main event.
                      return Container(
                        margin: const EdgeInsets.only(top: AppSpace.md),
                        padding: const EdgeInsets.all(AppSpace.md),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(alpha: 0.15),
                          border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Semantics(
                                  label: t.realCasesIconLabel,
                                  child: Icon(Icons.fact_check_outlined,
                                      color: scheme.primary, size: AppIconSize.md),
                                ),
                                const SizedBox(width: AppSpace.sm),
                                Expanded(
                                  child: Text(
                                    t.realCasesTitle,
                                    style: textTheme.titleMedium?.copyWith(
                                        color: scheme.primary, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpace.xs),
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

                  if (widget.voice != null) ...[
                    const SizedBox(height: AppSpace.lg),
                    SectionTitle(t.voiceSectionGuess),
                    VoiceGuessCard(guess: widget.voice!.guess),
                    const SizedBox(height: AppSpace.md),
                    const VoiceHonestyCard(),
                    if (widget.voice!.transcript.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpace.md),
                      SectionTitle(t.voiceTranscriptTitle),
                      Text(widget.voice!.transcript),
                    ],
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
            // Bumped a weight over titleSmall's theme default so the
            // headline unmistakably reads as the card's main content, with
            // the source badge and button below clearly secondary to it.
            Text(caseData.headline,
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            _SourceBadge(sourceName: caseData.sourceName),
            if (snippet.isNotEmpty) ...[
              const SizedBox(height: AppSpace.sm),
              Text(snippet),
            ],
            const SizedBox(height: AppSpace.xs),
            // Plain FilledButton (not .tonal) -- a solid scheme.primary fill
            // with white/onPrimary text+icon reads as "this is clickable"
            // far more than a pale tint does. Still the theme's default
            // FilledButton colors (no hardcoded color here), so it keeps the
            // same 48x48 minimum tap target (CLAUDE.md section 7) via
            // filledButtonTheme.
            FilledButton.icon(
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

/// A small bordered pill naming the outlet a reference case came from (e.g.
/// "Tuổi Trẻ"), with a newspaper icon -- gives the source more visual weight
/// than a plain grey subtitle, so the card visibly says "this is from a real
/// outlet" rather than relying on size/color alone to earn a tap.
class _SourceBadge extends StatelessWidget {
  final String sourceName;
  const _SourceBadge({required this.sourceName});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.newspaper, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            sourceName,
            style: textTheme.labelMedium
                ?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
