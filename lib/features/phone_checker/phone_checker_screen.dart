import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'phone_api.dart';

/// Phone Checker: look up community reports for a number, and report one.
/// Wording rule (CLAUDE.md section 8): "reported by users", never "scammer".
class PhoneCheckerScreen extends StatefulWidget {
  const PhoneCheckerScreen({super.key});

  @override
  State<PhoneCheckerScreen> createState() => _PhoneCheckerScreenState();
}

class _PhoneCheckerScreenState extends State<PhoneCheckerScreen> {
  final _api = PhoneApi();
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

  @override
  void dispose() {
    _phoneController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String _errorText(PhoneError e, AppLocalizations t) {
    switch (e) {
      case PhoneError.notConfigured:
        return t.errorNotConfigured;
      case PhoneError.invalidPhone:
        return t.phoneInvalid;
      case PhoneError.rateLimited:
        return t.phoneReportRateLimited;
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
        _checkError = _errorText(e.error, t);
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(t.phoneTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Community data, not verification (CLAUDE.md section 2.2).
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.groups_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(t.phoneCommunityNote)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: t.phoneNumberLabel,
                hintText: t.phoneNumberHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
              onSubmitted: (_) => _check(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _checking ? null : _check,
              icon: _checking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(t.phoneCheck),
            ),
            if (_checkError != null) ...[
              const SizedBox(height: 12),
              _Message(text: _checkError!, isError: true),
            ],
            if (_summary != null) ...[
              const SizedBox(height: 16),
              _SummaryCard(summary: _summary!),
            ],
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),

            // ---- Report form ------------------------------------------------
            Text(t.phoneReportTitle,
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(t.phoneReportIntro),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(_formVersion),
              initialValue: _category,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: t.phoneCategoryLabel,
                border: const OutlineInputBorder(),
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
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.flag_outlined),
              label: Text(t.phoneSubmit),
            ),
            if (_reportError != null) ...[
              const SizedBox(height: 12),
              _Message(text: _reportError!, isError: true),
            ],
            if (_reportSent) ...[
              const SizedBox(height: 12),
              _Message(text: t.phoneReportSuccess, isError: false),
            ],
          ],
        ),
      ),
    );
  }
}

String categoryLabel(String category, AppLocalizations t) {
  switch (category) {
    case 'impersonation':
      return t.phoneCatImpersonation;
    case 'fake_bank':
      return t.phoneCatFakeBank;
    case 'fake_job':
      return t.phoneCatFakeJob;
    case 'investment':
      return t.phoneCatInvestment;
    case 'loan':
      return t.phoneCatLoan;
    case 'shopping':
      return t.phoneCatShopping;
    case 'spam':
      return t.phoneCatSpam;
    default:
      return t.phoneCatOther;
  }
}

class _SummaryCard extends StatelessWidget {
  final PhoneReportSummary summary;
  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final hasReports = summary.reportCount > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(hasReports ? Icons.report_outlined : Icons.info_outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasReports
                        ? t.phoneReportedBy(summary.reportCount)
                        : t.phoneNoReports,
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!hasReports) Text(t.phoneNoReportsNote),
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
              const SizedBox(height: 8),
              Text(t.phoneReportsNote, style: textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final bool isError;
  const _Message({required this.text, required this.isError});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isError ? scheme.error : scheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: color))),
      ],
    );
  }
}
