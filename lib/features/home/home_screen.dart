import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    void comingSoon() {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.comingSoon)));
    }

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
          padding: const EdgeInsets.all(16),
          children: [
            Text(t.homeSubtitle,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            _HomeCard(
              icon: Icons.message_outlined,
              title: t.cardCheckMessage,
              subtitle: t.cardCheckMessageDesc,
              onTap: () => context.push('/check'),
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
              onTap: comingSoon,
            ),
            _HomeCard(
              icon: Icons.quiz_outlined,
              title: t.cardQuiz,
              subtitle: t.cardQuizDesc,
              onTap: () => context.push('/quiz'),
            ),
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

  const _HomeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(subtitle),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
