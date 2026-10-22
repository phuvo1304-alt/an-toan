import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/config.dart';
import '../../core/feature_flags.dart';
import '../../l10n/app_localizations.dart';
import '../settings/donation_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.homeTitle),
        actions: [
          IconButton(
            tooltip: t.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.md),
          children: [
            Text(t.homeSubtitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: AppSpace.md),
            // The main feature gets the brand tint; the others are standard cards.
            _HomeCard(
              icon: Icons.message_outlined,
              title: t.cardCheckMessage,
              subtitle: t.cardCheckMessageDesc,
              onTap: () => context.push('/check'),
              primary: true,
            ),
            if (ref.watch(voiceScamEnabledProvider))
              _HomeCard(
                icon: Icons.record_voice_over_outlined,
                title: t.cardVoiceScan,
                subtitle: t.cardVoiceScanDesc,
                onTap: () => context.push('/voice'),
              ),
            _HomeCard(
              icon: Icons.phone_in_talk_outlined,
              title: t.cardCheckPhone,
              subtitle: t.cardCheckPhoneDesc,
              onTap: () => context.push('/phone'),
            ),
            _HomeCard(
              icon: Icons.school_outlined,
              title: t.cardTraining,
              subtitle: t.cardTrainingDesc,
              onTap: () => context.push('/training'),
            ),
            _HomeCard(
              icon: Icons.quiz_outlined,
              title: t.cardQuiz,
              subtitle: t.cardQuizDesc,
              onTap: () => context.push('/quiz'),
            ),
            // Same component, same gating check as Settings -- see
            // lib/features/settings/settings_screen.dart and
            // lib/core/config.dart. Deliberately not a second copy: showing
            // the same content from two code paths is how this story drifted
            // (shortened, then a line dropped) across earlier commits.
            if (isDonationInfoConfigured(
                kDonationAccountNumber, kDonationAccountHolderName)) ...[
              const SizedBox(height: AppSpace.lg),
              SectionTitle(t.donationTitle),
              DonationCard(
                bankCode: kDonationBankCode,
                accountNumber: kDonationAccountNumber,
                accountHolderName: kDonationAccountHolderName,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;

  const _HomeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final fg = primary ? scheme.onPrimaryContainer : scheme.onSurface;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: primary ? scheme.primaryContainer : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: primary ? scheme.primary : scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon,
                    size: 28,
                    color: primary ? scheme.onPrimary : scheme.onSecondaryContainer),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.titleMedium?.copyWith(color: fg)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: textTheme.bodyMedium?.copyWith(
                            color: primary
                                ? scheme.onPrimaryContainer
                                : scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}
