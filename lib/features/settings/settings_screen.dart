import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/locale_provider.dart';
import '../../l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final notifier = ref.read(localeProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(t.language, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'vi', label: Text(t.languageVi)),
                ButtonSegment(value: 'en', label: Text(t.languageEn)),
              ],
              selected: {locale.languageCode},
              onSelectionChanged: (s) => notifier.setLanguage(s.first),
            ),
            const SizedBox(height: 24),
            Text(t.disclaimerTitle, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(t.disclaimerBody),
            const SizedBox(height: 24),
            Text(t.officialHelpTitle, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(t.officialHelpBody),
          ],
        ),
      ),
    );
  }
}
