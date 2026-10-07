import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
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
          padding: const EdgeInsets.all(AppSpace.md),
          children: [
            SectionTitle(t.language),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'vi', label: Text(t.languageVi)),
                ButtonSegment(value: 'en', label: Text(t.languageEn)),
              ],
              selected: {locale.languageCode},
              onSelectionChanged: (s) => notifier.setLanguage(s.first),
            ),
            const SizedBox(height: AppSpace.lg),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                minVerticalPadding: 12,
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(t.privacyPolicy, style: textTheme.titleSmall),
                trailing: const Icon(Icons.open_in_new, size: 20),
                onTap: () => _openPrivacyPolicy(context),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            SectionTitle(t.disclaimerTitle),
            Text(t.disclaimerBody),
            const SizedBox(height: AppSpace.lg),
            SectionTitle(t.officialHelpTitle),
            Text(t.officialHelpBody),
          ],
        ),
      ),
    );
  }
}
