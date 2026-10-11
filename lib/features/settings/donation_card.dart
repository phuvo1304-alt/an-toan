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
/// a placeholder" decision.
///
/// The account holder's name is shown exactly as given, right next to the
/// QR: an unnamed bank QR asking for money is precisely the pattern this app
/// teaches people to distrust, so a visible, consistent name here is the
/// credibility mechanism the whole feature depends on, not polish.
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
            Center(
              child: Column(
                children: [
                  // A solid white backdrop, regardless of app theme: in dark
                  // mode the surrounding card background is dark, which would
                  // make a transparent-background QR unscannable.
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
            const SizedBox(height: AppSpace.md),
            _DonationField(
              label: t.donationBankLabel,
              value: bankLabel,
              onCopy: () => _copy(context, bankLabel),
            ),
            const SizedBox(height: AppSpace.sm),
            _DonationField(
              label: t.donationAccountLabel,
              value: accountNumber,
              onCopy: () => _copy(context, accountNumber),
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              t.donationDisclosure,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labeled value with its own copy button -- the accessible path for a
/// screen-reader user (who cannot use the QR at all) and for anyone whose
/// banking app cannot scan a QR reliably, not a convenience-only fallback.
class _DonationField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCopy;

  const _DonationField({required this.label, required this.value, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
              Text(value, style: textTheme.titleSmall),
            ],
          ),
        ),
        IconButton(
          onPressed: onCopy,
          icon: const Icon(Icons.copy),
          tooltip: t.donationCopy,
        ),
      ],
    );
  }
}
