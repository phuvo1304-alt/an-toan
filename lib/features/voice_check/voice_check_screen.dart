import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/locale_provider.dart';
import '../../l10n/app_localizations.dart';
import '../scam_checker/audio_tab.dart';
import '../scam_checker/scam_api.dart';
import '../scam_checker/scam_error_text.dart';
import 'voice_honesty_card.dart';

/// "Check a call or voice". Speech is turned into TEXT by the device's (or the
/// browser's) own recognizer, exactly like the Scam Checker's Voice tab; only
/// that text, which the user can edit, goes to analyze-scam. No audio is
/// recorded, stored or sent by the app, and the screen never says whether a
/// voice is real or computer-made. Where speech recognition is unavailable
/// the same box works as a plain text box.
class VoiceCheckScreen extends ConsumerStatefulWidget {
  const VoiceCheckScreen({super.key});

  @override
  ConsumerState<VoiceCheckScreen> createState() => _VoiceCheckScreenState();
}

class _VoiceCheckScreenState extends ConsumerState<VoiceCheckScreen> {
  final _transcript = TextEditingController();
  late final ScamApi _api = ref.read(scamApiProvider);
  bool _loading = false;
  bool _listening = false;
  String? _errorText;

  @override
  void dispose() {
    _transcript.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final t = AppLocalizations.of(context)!;
    final text = _transcript.text.trim();
    if (text.isEmpty) {
      setState(() => _errorText = t.audioTranscriptEmpty);
      return;
    }
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final result = await _api.analyze(
        text: text,
        language: ref.read(localeProvider).languageCode,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      context.push('/voice/result', extra: result);
    } on ScamApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText = scamErrorText(e.error, t);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(t.voiceCheckTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.md),
          children: [
            const VoiceHonestyCard(),
            const SizedBox(height: AppSpace.md),
            Text(t.voiceCheckIntro,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: AppSpace.md),
            SizedBox(
              height: 260,
              child: AudioTab(
                controller: _transcript,
                enabled: !_loading,
                standalone: true,
                onListeningChanged: (listening) {
                  if (mounted) setState(() => _listening = listening);
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline,
                    size: AppIconSize.sm, color: scheme.onSurfaceVariant),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    t.privacyNote,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            if (_errorText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: StatusBanner(message: _errorText!),
              ),
            FilledButton.icon(
              // Not while still listening: stop first, then check.
              onPressed: _loading || _listening ? null : _check,
              icon: _loading
                  ? const ButtonSpinner()
                  : const Icon(Icons.shield_outlined),
              label: Text(_loading ? t.checking : t.checkButton),
            ),
            const SizedBox(height: AppSpace.md),
            StatusBanner(message: t.disclaimerBody, kind: BannerKind.info),
          ],
        ),
      ),
    );
  }
}
