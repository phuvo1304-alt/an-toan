import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/config.dart';
import '../../core/locale_provider.dart';
import '../../core/text_scale_provider.dart';
import '../../l10n/app_localizations.dart';
import 'donation_card.dart';
import 'official_contacts.dart';

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

  /// Dials [contact]'s phone (`primary_action: "call"`) or opens its URL
  /// (`"open_url"`) -- the action each contact's own sourcing determined is
  /// realistic (e.g. a VN shortcode vs. a line that costs international
  /// rates to dial from Vietnam, see data/official_contacts.json).
  Future<void> _openContact(BuildContext context, OfficialContact contact) async {
    final t = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final useUrl = contact.primaryAction == 'open_url' && contact.url != null;
    final uri = useUrl
        ? Uri.tryParse(contact.url!)
        : (contact.phone != null ? Uri(scheme: 'tel', path: contact.phone) : null);
    var opened = false;
    if (uri != null) {
      try {
        opened = await launchUrl(uri,
            mode: useUrl ? LaunchMode.externalApplication : LaunchMode.platformDefault);
      } catch (_) {
        opened = false;
      }
    }
    if (!opened && messenger.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(t.errorGeneric)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final notifier = ref.read(localeProvider.notifier);
    final textSize = ref.watch(textScaleProvider);
    final textScaleNotifier = ref.read(textScaleProvider.notifier);
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
            SectionTitle(t.textSize),
            SegmentedButton<TextSizeOption>(
              segments: [
                ButtonSegment(value: TextSizeOption.small, label: Text(t.textSizeSmall)),
                ButtonSegment(value: TextSizeOption.medium, label: Text(t.textSizeMedium)),
                ButtonSegment(value: TextSizeOption.large, label: Text(t.textSizeLarge)),
                ButtonSegment(
                    value: TextSizeOption.extraLarge, label: Text(t.textSizeExtraLarge)),
              ],
              selected: {textSize},
              onSelectionChanged: (s) => textScaleNotifier.setOption(s.first),
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
            const SizedBox(height: AppSpace.lg),
            SectionTitle(t.officialContactsListTitle),
            FutureBuilder<List<OfficialContact>>(
              future: loadOfficialContacts(),
              builder: (context, snapshot) {
                final contacts = snapshot.data ?? const [];
                return Column(
                  children: contacts
                      .map((c) => Card(
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              minVerticalPadding: 12,
                              leading: Icon(c.primaryAction == 'open_url'
                                  ? Icons.open_in_new
                                  : Icons.call_outlined),
                              title: Text(c.orgName(locale.languageCode),
                                  style: textTheme.titleSmall),
                              subtitle: Text(c.purpose(locale.languageCode)),
                              isThreeLine: true,
                              onTap: () => _openContact(context, c),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
            // Donation card: Settings only, never in the Scam Checker result
            // flow. Hidden entirely while the account info is still the
            // placeholder, so an incomplete/fake-looking QR never ships --
            // see lib/core/config.dart.
            if (kDonationAccountNumber != 'REPLACE_ME' &&
                kDonationAccountHolderName != 'REPLACE_ME') ...[
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
