import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/locale_provider.dart';
import '../../l10n/app_localizations.dart';
import 'audio_capture.dart';
import 'audio_picker.dart';
import 'recording_countdown.dart';
import 'voice_api.dart';
import 'voice_consent.dart';
import 'voice_honesty_card.dart';

/// "Voice scam detection": record with the microphone or upload an audio file
/// (up to 60 s), then analyze what is said and make a guess about the voice.
///
/// Order of events, by design: (1) the consent notice, before first use;
/// (2) the user records or picks a clip, which stays in memory on the device;
/// (3) on "Analyze" the app first makes a tiny availability call that carries
/// NO audio; only if that answers OK is the audio uploaded. If it does not,
/// the user sees a friendly message and nothing has been sent.
class VoiceCheckScreen extends ConsumerStatefulWidget {
  const VoiceCheckScreen({super.key});

  @override
  ConsumerState<VoiceCheckScreen> createState() => _VoiceCheckScreenState();
}

class _VoiceCheckScreenState extends ConsumerState<VoiceCheckScreen> {
  late final AudioCapture _capture = ref.read(audioCaptureProvider);
  late final AudioPicker _picker = ref.read(audioPickerProvider);
  late final VoiceApi _api = ref.read(voiceApiProvider);
  final _countdown = ListenCountdown();
  Timer? _timer;

  AudioClip? _clip;
  bool _recording = false;
  bool _loading = false;
  bool _waking = false; // the health check is slow: the model server is probably starting up
  Timer? _wakeTimer;
  String? _errorText;

  @override
  void dispose() {
    _timer?.cancel();
    _wakeTimer?.cancel();
    if (_recording) _capture.cancel(); // never leave the microphone running
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    final t = AppLocalizations.of(context)!;
    if (_recording) {
      await _stopRecording();
      return;
    }
    if (!await _capture.hasPermission()) {
      if (mounted) setState(() => _errorText = t.voiceErrMicDenied);
      return;
    }
    try {
      await _capture.start();
    } on CaptureException {
      if (mounted) setState(() => _errorText = t.voiceErrMicUnavailable);
      return;
    }
    if (!mounted) return;
    _countdown.reset();
    setState(() {
      _recording = true;
      _clip = null;
      _errorText = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _onTick() {
    if (!mounted || !_recording) return;
    final hitCap = _countdown.tick();
    setState(() {});
    if (hitCap) _stopRecording(); // hard 60-second cap
  }

  Future<void> _stopRecording() async {
    final t = AppLocalizations.of(context)!;
    _timer?.cancel();
    _timer = null;
    final clip = await _capture.stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _clip = clip;
      if (clip == null) _errorText = t.voiceErrNoAudio;
    });
  }

  Future<void> _pickFile() async {
    final t = AppLocalizations.of(context)!;
    try {
      final clip = await _picker.pick();
      if (clip == null || !mounted) return;
      setState(() {
        _clip = clip;
        _errorText = null;
      });
    } on PickException catch (e) {
      if (!mounted) return;
      setState(() => _errorText =
          e.problem == PickProblem.tooLarge ? t.voiceErrTooLarge : t.voiceErrUnreadable);
    }
  }

  Future<void> _analyze() async {
    final t = AppLocalizations.of(context)!;
    final clip = _clip;
    if (clip == null) {
      setState(() => _errorText = t.voiceErrNoAudio);
      return;
    }
    // Belt and braces: never upload without the user's agreement.
    if (ref.read(voiceConsentProvider).value != true) return;

    setState(() {
      _loading = true;
      _errorText = null;
    });
    // 1. Availability first: a tiny call with NO audio and no user data.
    _wakeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _loading) setState(() => _waking = true);
    });
    final available = await _api.isAvailable();
    _wakeTimer?.cancel();
    if (!mounted) return;
    setState(() => _waking = false);
    if (!available) {
      setState(() {
        _loading = false;
        _errorText = t.voiceErrUnavailable;
      });
      return;
    }
    // 2. Only now does the audio leave the device.
    try {
      final result = await _api.analyze(
        bytes: clip.bytes,
        mime: clip.mime,
        language: ref.read(localeProvider).languageCode,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      context.push('/voice/result', extra: result);
    } on VoiceApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText = _messageFor(e.error, t);
      });
    }
  }

  String _messageFor(VoiceError e, AppLocalizations t) {
    switch (e) {
      case VoiceError.unavailable:
        return t.voiceErrUnavailable;
      case VoiceError.tooLarge:
        return t.voiceErrTooLarge;
      case VoiceError.unsupported:
        return t.voiceErrUnsupported;
      case VoiceError.rateLimited:
        return t.voiceErrRateLimited;
      case VoiceError.tooLong:
        return t.voiceErrTooLong;
      case VoiceError.silent:
        return t.voiceErrSilent;
      case VoiceError.unreadable:
        return t.voiceErrUnreadable;
      case VoiceError.network:
        return t.voiceErrNetwork;
      case VoiceError.generic:
        return t.voiceErrGeneric;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final consent = ref.watch(voiceConsentProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.cardVoiceScan)),
      body: SafeArea(
        child: consent.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _ConsentView(onAgree: () => ref.read(voiceConsentProvider.notifier).agree()),
          data: (agreed) => agreed
              ? _mainView(context, t)
              : _ConsentView(onAgree: () => ref.read(voiceConsentProvider.notifier).agree()),
        ),
      ),
    );
  }

  Widget _mainView(BuildContext context, AppLocalizations t) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final busy = _loading;
    return ListView(
      padding: const EdgeInsets.all(AppSpace.md),
      children: [
        const VoiceHonestyCard(),
        const SizedBox(height: AppSpace.md),
        Text(t.voiceIntro,
            style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: AppSpace.md),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : _toggleRecording,
                style: _recording
                    ? FilledButton.styleFrom(
                        backgroundColor: scheme.error, foregroundColor: scheme.onError)
                    : null,
                icon: Icon(_recording ? Icons.stop : Icons.mic),
                label: Text(_recording ? t.voiceStop : t.voiceRecord),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy || _recording ? null : _pickFile,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(t.voiceUpload),
              ),
            ),
          ],
        ),
        if (_recording) ...[
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              Expanded(child: Text(t.voiceRecording, style: textTheme.titleSmall)),
              Text(t.voiceSecondsLeft(_countdown.secondsLeft), style: textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(value: _countdown.progress),
          ),
        ],
        if (_clip != null && !_recording) ...[
          const SizedBox(height: AppSpace.md),
          _ClipCard(
            clip: _clip!,
            onRemove: busy ? null : () => setState(() => _clip = null),
          ),
        ],
        const SizedBox(height: AppSpace.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, size: AppIconSize.sm, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(t.voicePrivacyShort,
                  style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        if (_errorText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: StatusBanner(message: _errorText!),
          ),
        if (_waking)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: StatusBanner(message: t.voiceWakingUp, kind: BannerKind.info),
          ),
        FilledButton.icon(
          onPressed: busy || _recording || _clip == null ? null : _analyze,
          icon: busy ? const ButtonSpinner() : const Icon(Icons.shield_outlined),
          label: Text(busy ? t.voiceAnalyzing : t.voiceAnalyze),
        ),
        const SizedBox(height: AppSpace.md),
        StatusBanner(message: t.disclaimerBody, kind: BannerKind.info),
      ],
    );
  }
}

class _ClipCard extends StatelessWidget {
  final AudioClip clip;
  final VoidCallback? onRemove;
  const _ClipCard({required this.clip, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final label = clip.isRecording
        ? t.voiceClipRecorded(clip.seconds ?? 0)
        : t.voiceClipFile(clip.name ?? '');
    return Container(
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(clip.isRecording ? Icons.mic : Icons.audio_file_outlined),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Text(label, key: const ValueKey('voice-clip-label'))),
          IconButton(
            tooltip: t.voiceRemove,
            onPressed: onRemove,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

/// The consent notice, shown before first use. Nothing is recorded, picked or
/// sent until the user agrees; the choice is remembered on the device.
class _ConsentView extends StatelessWidget {
  final VoidCallback onAgree;
  const _ConsentView({required this.onAgree});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpace.md),
      children: [
        Icon(Icons.privacy_tip_outlined, size: AppIconSize.hero, color: scheme.primary),
        const SizedBox(height: AppSpace.md),
        Text(t.voiceConsentTitle,
            key: const ValueKey('voice-consent-title'),
            style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpace.md),
        Text(t.voiceConsentBody, style: textTheme.bodyLarge),
        const SizedBox(height: AppSpace.lg),
        FilledButton(
          key: const ValueKey('voice-consent-agree'),
          onPressed: onAgree,
          child: Text(t.voiceConsentAgree),
        ),
        const SizedBox(height: AppSpace.sm),
        OutlinedButton(
          onPressed: () => context.pop(),
          child: Text(t.voiceConsentDecline),
        ),
      ],
    );
  }
}
