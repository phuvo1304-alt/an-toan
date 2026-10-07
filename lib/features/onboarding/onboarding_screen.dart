import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/locale_provider.dart';
import '../../core/onboarding_provider.dart';
import '../../l10n/app_localizations.dart';

/// First-run slides: 1) what the app is, 2) language, 3) privacy note.
/// "Skip" jumps to the privacy slide (it never skips it): users must see that
/// their content is sent to an AI service before they start.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pageCount = 3;
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _pages.animateToPage(page,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Future<void> _finish() async {
    await ref.read(onboardingProvider.notifier).markComplete();
    // go = replace the whole stack, so Back cannot return to onboarding.
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isLast = _page == _pageCount - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Visibility(
                visible: !isLast,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: TextButton(
                  onPressed: () => _goTo(_pageCount - 1),
                  child: Text(t.onboardingSkip),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (p) => setState(() => _page = p),
                children: const [
                  _WelcomeSlide(),
                  _LanguageSlide(),
                  _PrivacySlide(),
                ],
              ),
            ),
            _Dots(count: _pageCount, current: _page),
            Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isLast ? _finish : () => _goTo(_page + 1),
                  child: Text(isLast ? t.onboardingGetStarted : t.onboardingNext),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared layout: big icon, title, body text, optional extra widget.
class _Slide extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? extra;

  const _Slide({required this.icon, required this.title, required this.body, this.extra});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md),
      child: Column(
        children: [
          const SizedBox(height: AppSpace.lg),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: AppIconSize.hero, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(title, textAlign: TextAlign.center, style: textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(body,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
          if (extra != null) ...[const SizedBox(height: AppSpace.lg), extra!],
        ],
      ),
    );
  }
}

class _WelcomeSlide extends StatelessWidget {
  const _WelcomeSlide();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return _Slide(
      icon: Icons.shield_outlined,
      title: t.appName,
      body: t.onboardingWelcomeBody,
    );
  }
}

class _LanguageSlide extends ConsumerWidget {
  const _LanguageSlide();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    return _Slide(
      icon: Icons.translate,
      title: t.onboardingLanguageTitle,
      body: t.onboardingLanguageBody,
      // Same control as in Settings.
      extra: SegmentedButton<String>(
        segments: [
          ButtonSegment(value: 'vi', label: Text(t.languageVi)),
          ButtonSegment(value: 'en', label: Text(t.languageEn)),
        ],
        selected: {locale.languageCode},
        onSelectionChanged: (s) =>
            ref.read(localeProvider.notifier).setLanguage(s.first),
      ),
    );
  }
}

class _PrivacySlide extends StatelessWidget {
  const _PrivacySlide();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return _Slide(
      icon: Icons.privacy_tip_outlined,
      title: t.onboardingPrivacyTitle,
      body: t.onboardingPrivacyBody,
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int current;
  const _Dots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '${current + 1}/$count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == current ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == current ? scheme.primary : scheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}
