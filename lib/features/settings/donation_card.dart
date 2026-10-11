import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:vietqr_gen/vietqr_generator.dart' show Bank, VietQR;

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';

/// Personal/family bank-transfer donation card (VietQR, generated entirely
/// locally -- no API key, no network call). Parameterized (not reading the
/// `kDonation*` constants directly) so it's testable with synthetic values
/// independent of the real, placeholder-gated config -- see
/// lib/core/config.dart and SettingsScreen, which owns the "hide while still
/// a placeholder" decision and the headline above this card
/// (SectionTitle(t.donationTitle) -- the ask, stated before this card's
/// story explains the why).
///
/// Deliberately uses the theme's `tertiary` accent, not `primary` (already
/// the app's workhorse button/link color everywhere else, so reusing it here
/// wouldn't read as distinct) and never the RiskPalette reds/oranges (those
/// mean danger elsewhere in the app; reusing them here would send the wrong
/// signal). `tertiary`/`onTertiaryContainer` contrast was measured at ~6.5:1
/// (light) / ~7.7:1 (dark) against their pair -- see the color dump this was
/// checked with, same discipline as RiskPalette's own documented ratios.
///
/// The account holder's name is shown next to the QR, not just in the
/// story's byline: an unnamed bank QR asking for money is precisely the
/// pattern this app teaches people to distrust, so a visible, consistent
/// name at the point of payment is the credibility mechanism this feature
/// depends on, not polish.
class DonationCard extends StatelessWidget {
  final Bank bankCode;
  final String accountNumber;
  final String accountHolderName;

  const DonationCard({
    super.key,
    required this.bankCode,
    required this.accountNumber,
    required this.accountHolderName,
  });

  Future<void> _copy(BuildContext context, String value) async {
    final t = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.donationCopied)));
    }
  }

  /// First letter of the holder's given name (the last token in Vietnamese
  /// name order) -- a stand-in avatar initial, since there's no photo asset.
  String get _initial {
    final parts = accountHolderName.trim().split(RegExp(r'\s+'));
    final last = parts.isNotEmpty ? parts.last : '';
    return last.isNotEmpty ? last.substring(0, 1).toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final bankLabel = bankCode.name.toUpperCase();
    // Static QR (no pre-filled amount) -- this is a general support ask, not
    // a request for a specific amount.
    final payload = VietQR.generate(bank: bankCode, accountNumber: accountNumber);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The personal story, styled as a pull-quote: tinted background +
            // left accent bar + a large opening quotation mark, so it reads
            // as a human note, not a wall of body text.
            Container(
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border(left: BorderSide(color: scheme.tertiary, width: 4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: scheme.tertiary,
                    child: Text(
                      _initial,
                      style: textTheme.titleMedium
                          ?.copyWith(color: scheme.onTertiary, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.format_quote, color: scheme.tertiary, size: AppIconSize.lg),
                        Text(
                          t.donationStory,
                          style: textTheme.bodyLarge?.copyWith(
                            color: scheme.onTertiaryContainer,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: AppSpace.sm),
                        Semantics(
                          label: '${t.donationHolderLabel}: $accountHolderName',
                          child: Text(
                            accountHolderName,
                            style: textTheme.labelLarge
                                ?.copyWith(color: scheme.onTertiaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            // The QR, framed as its own panel with an instruction line -- the
            // natural next step after reading the story, not a QR plopped in
            // the middle of the card.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                children: [
                  Text(
                    t.donationScanInstruction,
                    style: textTheme.titleSmall?.copyWith(color: scheme.onSurface),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  // A solid white backdrop, regardless of app theme: in dark
                  // mode the surrounding panel is dark, which would make a
                  // transparent-background QR unscannable.
                  Container(
                    padding: const EdgeInsets.all(AppSpace.sm),
                    color: Colors.white,
                    child: QrImageView(
                      data: payload,
                      version: QrVersions.auto,
                      size: 180,
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  // Shown again, right at the QR: this is the name the
                  // user's banking app will show them to confirm against
                  // during a real transfer -- an unnamed QR asking for money
                  // is exactly the pattern this app teaches people to
                  // distrust, so this is the credibility mechanism, not
                  // decoration.
                  Semantics(
                    label: '${t.donationHolderLabel}: $accountHolderName',
                    child: Text(
                      accountHolderName,
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            _DonationRow(
              icon: Icons.account_balance_outlined,
              label: t.donationBankLabel,
              value: bankLabel,
              copyLabel: t.donationCopy,
              onCopy: () => _copy(context, bankLabel),
            ),
            const SizedBox(height: AppSpace.sm),
            _DonationRow(
              icon: Icons.pin_outlined,
              label: t.donationAccountLabel,
              value: accountNumber,
              copyLabel: t.donationCopy,
              onCopy: () => _copy(context, accountNumber),
            ),
            const SizedBox(height: AppSpace.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: AppIconSize.sm, color: scheme.onSurfaceVariant),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    t.donationDisclosure,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A labeled value with its own deliberate "Copy" button -- the accessible
/// path for a screen-reader user (who cannot use the QR at all) and for
/// anyone whose banking app cannot scan a QR reliably, not a convenience-only
/// fallback. Styled with more visual weight than a bare icon, so it isn't
/// easy to miss, and still well above the 48px minimum tap target.
class _DonationRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String copyLabel;
  final VoidCallback onCopy;

  const _DonationRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.copyLabel,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.onSurfaceVariant, size: AppIconSize.lg),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                Text(value, style: textTheme.titleSmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          OutlinedButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy, size: AppIconSize.sm),
            label: Text(copyLabel),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, minTapTarget),
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            ),
          ),
        ],
      ),
    );
  }
}
