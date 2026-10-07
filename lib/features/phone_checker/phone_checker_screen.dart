import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../l10n/app_localizations.dart';
import 'phone_api.dart';

/// Phone Checker: look up community reports for a number, and report one.
/// Wording rule (CLAUDE.md section 8): "reported by users", never "scammer".
class PhoneCheckerScreen extends ConsumerStatefulWidget {
  const PhoneCheckerScreen({super.key});

  @override
  ConsumerState<PhoneCheckerScreen> createState() => _PhoneCheckerScreenState();
}

class _PhoneCheckerScreenState extends ConsumerState<PhoneCheckerScreen> {
  late final PhoneApi _api = ref.read(phoneApiProvider);
  final _phoneController = TextEditingController();
  final _descController = TextEditingController();

  // Lookup
  bool _checking = false;
  String? _checkError;
  PhoneReportSummary? _summary;
  String? _summaryFor; // normalized number the summary belongs to

  // Report form
  String? _category;
  int _formVersion = 0; // bump to reset the dropdown after a report
  bool _submitting = false;
  String? _reportError;
  bool _reportSent = false;

  // Dispute ("this looks wrong")
  bool _disputing = false;
  String? _disputeMessage;
  bool _disputeIsError = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String _errorText(PhoneError e, AppLocalizations t,
      {bool dispute = false, bool lookup = false}) {
    switch (e) {
      case PhoneError.notConfigured:
        return t.errorNotConfigured;
      case PhoneError.invalidPhone:
        return t.phoneInvalid;
      case PhoneError.rateLimited:
        if (lookup) return t.errorRateLimited;
        return dispute ? t.phoneDisputeRateLimited : t.phoneReportRateLimited;
      case PhoneError.alreadyReported:
        return t.phoneAlreadyReported;
      case PhoneError.alreadyDisputed:
        return t.phoneAlreadyDisputed;
      case PhoneError.nothingToDispute:
        return t.phoneNothingToDispute;
      case PhoneError.network:
        return t.errorNetwork;
      case PhoneError.generic:
        return t.errorGeneric;
    }
  }

  Future<void> _check() async {
    final t = AppLocalizations.of(context)!;
    FocusScope.of(context).unfocus();
    final normalized = normalizePhone(_phoneController.text);
    if (normalized == null) {
      setState(() {
        _checkError = t.phoneInvalid;
        _summary = null;
      });
      return;
    }
    setState(() {
      _checking = true;
      _checkError = null;
    });
    try {
      final summary = await _api.getSummary(normalized);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _summaryFor = normalized;
      });
    } on PhoneApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _checkError = _errorText(e.error, t, lookup: true);
        _summary = null;
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context)!;
    FocusScope.of(context).unfocus();
    final formError = validateReport(
      phone: _phoneController.text,
      category: _category,
      description: _descController.text,
    );
    if (formError != null) {
      setState(() {
        _reportSent = false;
        _reportError = switch (formError) {
          ReportFormError.invalidPhone => t.phoneInvalid,
          ReportFormError.noCategory => t.phoneCategoryRequired,
          ReportFormError.descriptionTooLong => t.phoneDescriptionTooLong,
        };
      });
      return;
    }

    setState(() {
      _submitting = true;
      _reportError = null;
      _reportSent = false;
    });
    try {
      await _api.submitReport(
        phone: _phoneController.text,
        category: _category!,
        description: _descController.text,
      );
      if (!mounted) return;
      setState(() {
        _reportSent = true;
        _category = null;
        _formVersion++;
        _descController.clear();
      });
      // If the summary on screen is for this number, refresh it.
      if (_summaryFor == normalizePhone(_phoneController.text)) await _check();
    } on PhoneApiException catch (e) {
      if (!mounted) return;
      setState(() => _reportError = _errorText(e.error, t));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// "This looks wrong? Flag it": asks for confirmation, then flags the
  /// number's most recent counted report and refreshes the summary.
  Future<void> _dispute() async {
    final t = AppLocalizations.of(context)!;
    final number = _summaryFor;
    if (number == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.phoneDisputeConfirmTitle),
        content: Text(t.phoneDisputeConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.phoneDisputeCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.phoneDisputeConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _disputing = true;
      _disputeMessage = null;
    });
    try {
      await _api.disputeReports(number);
      if (!mounted) return;
      setState(() {
        _disputeMessage = t.phoneDisputeSuccess;
        _disputeIsError = false;
      });
      await _check(); // the disputed report may no longer count
    } on PhoneApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _disputeMessage = _errorText(e.error, t, dispute: true);
        _disputeIsError = true;
      });
    } finally {
      if (mounted) setState(() => _disputing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(t.phoneTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.md),
          children: [
            // Community data, not verification (CLAUDE.md section 2.2).
            StatusBanner(message: t.phoneCommunityNote, kind: BannerKind.info),
            const SizedBox(height: AppSpace.md),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: t.phoneNumberLabel,
                hintText: t.phoneNumberHint,
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
              onSubmitted: (_) => _check(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _checking ? null : _check,
              icon: _checking
                  ? const ButtonSpinner()
                  : const Icon(Icons.search),
              label: Text(t.phoneCheck),
            ),
            if (_checkError != null) ...[
              const SizedBox(height: 12),
              StatusBanner(message: _checkError!),
            ],
            if (_summary != null) ...[
              const SizedBox(height: 16),
              _SummaryCard(
                summary: _summary!,
                disputing: _disputing,
                onDispute: _dispute,
              ),
            ],
            if (_disputeMessage != null) ...[
              const SizedBox(height: 12),
              StatusBanner(
                  message: _disputeMessage!,
                  kind: _disputeIsError ? BannerKind.error : BannerKind.success),
            ],
            const Divider(height: AppSpace.xl * 1.5),

            // ---- Report form ------------------------------------------------
            SectionTitle(t.phoneReportTitle),
            Text(t.phoneReportIntro),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(_formVersion),
              initialValue: _category,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: t.phoneCategoryLabel,
              ),
              items: [
                for (final c in reportCategories)
                  DropdownMenuItem(value: c, child: Text(categoryLabel(c, t))),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLength: maxDescriptionLength,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: t.phoneDescriptionLabel,
              ),
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const ButtonSpinner()
                  : const Icon(Icons.flag_outlined),
              label: Text(t.phoneSubmit),
            ),
            if (_reportError != null) ...[
              const SizedBox(height: 12),
              StatusBanner(message: _reportError!),
            ],
            if (_reportSent) ...[
              const SizedBox(height: 12),
              StatusBanner(message: t.phoneReportSuccess, kind: BannerKind.success),
            ],
          ],
        ),
      ),
    );
  }
}

/// Same labels as the Scam Checker / Training scam types (one taxonomy).
String categoryLabel(String category, AppLocalizations t) {
  switch (category) {
    case 'fake_job':
      return t.scamTypeFakeJob;
    case 'fake_scholarship':
      return t.scamTypeFakeScholarship;
    case 'phishing':
      return t.scamTypePhishing;
    case 'impersonation':
      return t.scamTypeImpersonation;
    case 'investment':
      return t.scamTypeInvestment;
    case 'romance':
      return t.scamTypeRomance;
    case 'loan':
      return t.scamTypeLoan;
    default:
      return t.scamTypeOther;
  }
}

class _SummaryCard extends StatelessWidget {
  final PhoneReportSummary summary;
  final bool disputing;
  final VoidCallback onDispute;
  const _SummaryCard({
    required this.summary,
    required this.disputing,
    required this.onDispute,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final hasReports = summary.reportCount > 0;
    // Reports are community data, not a verdict: the card stays neutral and
    // only the icon signals caution (always next to the words).
    final iconColor = hasReports ? context.risk.suspicious : scheme.onSurfaceVariant;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(hasReports ? Icons.report_outlined : Icons.info_outline,
                    color: iconColor, size: AppIconSize.lg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasReports
                        ? t.phoneReportedBy(summary.reportCount)
                        : t.phoneNoReports,
                    style: textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasReports)
              Text(t.phoneNoReportsNote,
                  style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            if (hasReports) ...[
              for (final c in summary.categories)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('• ${t.phoneCategoryCount(categoryLabel(c.category, t), c.count)}'),
                ),
              if (summary.lastReportedAt != null) ...[
                const SizedBox(height: 8),
                Text(t.phoneLastReported(MaterialLocalizations.of(context)
                    .formatMediumDate(summary.lastReportedAt!.toLocal()))),
              ],
              const SizedBox(height: 12),
              Text(t.phoneReportsNote,
                  style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: disputing ? null : onDispute,
                  icon: disputing
                      ? const ButtonSpinner()
                      : const Icon(Icons.outlined_flag),
                  label: Text(t.phoneDisputeAction),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
