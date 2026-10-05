import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale_provider.dart';
import '../../l10n/app_localizations.dart';

/// Public privacy policy page (GitHub Pages, served from docs/ on main).
final privacyPolicyUrl =
    Uri.parse('https://phuvo1304-alt.github.io/an-toan/privacy-policy/');

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final t = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(privacyPolicyUrl,
          mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger.showSnackBar(SnackBar(
          content: Text(t.privacyPolicyOpenError(privacyPolicyUrl.toString()))));
    }
  }

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
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(t.privacyPolicy),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _openPrivacyPolicy(context),
            ),
            const SizedBox(height: 8),
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
