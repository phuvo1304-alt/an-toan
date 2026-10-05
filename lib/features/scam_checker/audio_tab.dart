import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/locale_provider.dart';
import '../../l10n/app_localizations.dart';
import 'speech_service.dart';

/// Longest a single voice input may run (CLAUDE.md: cap the length).
const maxListenDuration = Duration(seconds: 60);

/// Counts listening time, one tick per second, and says when the cap is hit.
/// Plain Dart so the cap logic can be unit-tested without real timers.
class ListenCountdown {
  ListenCountdown({this.limit = maxListenDuration});

  final Duration limit;
  int _elapsed = 0;

  int get elapsedSeconds => _elapsed;
  int get secondsLeft => limit.inSeconds - _elapsed;
  bool get reachedCap => _elapsed >= limit.inSeconds;
  double get progress => _elapsed / limit.inSeconds;

  /// Adds one second. Returns true only on the tick that reaches the cap.
  bool tick() {
    if (reachedCap) return false;
    _elapsed++;
    return reachedCap;
  }

  void reset() => _elapsed = 0;
}

/// Picks the device locale for the app language: vi -> vi_VN, en -> en_US.
/// Accepts both "vi-VN" (Android) and "vi_VN" (iOS). Prefers the exact
/// country, then any locale of that language. Null if none is installed.
String? pickSpeechLocale(List<String> deviceIds, String appLanguage) {
  final wanted = appLanguage == 'en' ? 'en_us' : 'vi_vn';
  String norm(String id) => id.replaceAll('-', '_').toLowerCase();
  for (final id in deviceIds) {
    if (norm(id) == wanted) return id;
  }
  for (final id in deviceIds) {
    final n = norm(id);
    if (n == appLanguage || n.startsWith('${appLanguage}_')) return id;
  }
  return null;
}

/// The Voice tab: speak (or play a voice message near the phone), watch the
/// words appear in the box, edit them, then press Check. Only the TEXT is sent;
/// speech is transcribed live on the phone and no audio file is ever saved.
class AudioTab extends ConsumerStatefulWidget {
  /// Owned by the checker screen, so the transcript survives tab switches and
  /// is what _check() sends.
  final TextEditingController controller;
  final ValueChanged<bool> onListeningChanged;
  final bool enabled;

  const AudioTab({
    super.key,
    required this.controller,
    required this.onListeningChanged,
    this.enabled = true,
  });

  @override
  ConsumerState<AudioTab> createState() => _AudioTabState();
}

enum _Problem { none, notSupported, permissionDenied, localeUnavailable, noSpeech, failed }

class _AudioTabState extends ConsumerState<AudioTab> {
  late final SpeechService _speech = ref.read(speechServiceProvider);
  final _countdown = ListenCountdown();
  Timer? _timer;

  SpeechInitResult? _init; // null = still setting up
  bool _listening = false;
  _Problem _problem = _Problem.none;
  String _baseText = ''; // what was in the box before this listening session

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_listening) {
      _speech.cancel();
      // Can't rebuild the parent while this widget is being removed.
      final notify = widget.onListeningChanged;
      Future.microtask(() => notify(false));
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    final result = await _speech.initialize(onStatus: _onStatus, onError: _onError);
    if (!mounted) return;
    setState(() {
      _init = result;
      _problem = switch (result) {
        SpeechInitResult.ready => _Problem.none,
        SpeechInitResult.permissionDenied => _Problem.permissionDenied,
        SpeechInitResult.notSupported => _Problem.notSupported,
      };
    });
  }

  void _onStatus(String status) {
    // The recognizer stopped by itself (silence, its own limit, an error).
    if ((status == 'notListening' || status == 'done') && _listening) {
      _finishListening();
    }
  }

  void _onError(String error) {
    if (!mounted) return;
    final problem = error.contains('permission')
        ? _Problem.permissionDenied
        : (error == 'error_no_match' || error == 'error_speech_timeout')
            ? _Problem.noSpeech
            : error.startsWith('error_language')
                ? _Problem.localeUnavailable
                : _Problem.failed;
    _finishListening(problem: problem);
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _speech.stop();
      _finishListening();
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    // Permission may have been granted in system settings since last time.
    if (_init != SpeechInitResult.ready) {
      await _initialize();
      if (_init != SpeechInitResult.ready) return;
    }

    final lang = ref.read(localeProvider).languageCode;
    final ids = await _speech.localeIds();
    // Some Android phones only list on-device languages, or list none at all.
    // An empty list tells us nothing, so then we just try the standard id.
    final localeId = ids.isEmpty
        ? (lang == 'en' ? 'en-US' : 'vi-VN')
        : pickSpeechLocale(ids, lang);
    if (!mounted) return;
    if (localeId == null) {
      setState(() => _problem = _Problem.localeUnavailable);
      return;
    }

    _baseText = widget.controller.text.trim();
    _countdown.reset();
    setState(() {
      _listening = true;
      _problem = _Problem.none;
    });
    widget.onListeningChanged(true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());

    try {
      await _speech.listen(
        localeId: localeId,
        listenFor: maxListenDuration,
        onResult: _onWords,
      );
    } catch (_) {
      _finishListening(problem: _Problem.failed);
    }
  }

  void _onTick() {
    if (!mounted || !_listening) return;
    final hitCap = _countdown.tick();
    setState(() {});
    if (hitCap) {
      _speech.stop(); // hard 60-second cap
      _finishListening();
    }
  }

  void _onWords(String words) {
    if (!mounted || !_listening) return;
    final text = [_baseText, words.trim()].where((s) => s.isNotEmpty).join(' ');
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _finishListening({_Problem? problem}) {
    _timer?.cancel();
    _timer = null;
    if (!mounted) return;
    final wasListening = _listening;
    setState(() {
      _listening = false;
      if (problem != null) {
        _problem = problem;
      } else if (wasListening && widget.controller.text.trim().isEmpty) {
        _problem = _Problem.noSpeech;
      }
    });
    if (wasListening) widget.onListeningChanged(false);
  }

  String? _problemText(AppLocalizations t) {
    switch (_problem) {
      case _Problem.none:
        return null;
      case _Problem.notSupported:
        return t.audioNotSupported;
      case _Problem.permissionDenied:
        return t.audioPermissionDenied;
      case _Problem.localeUnavailable:
        return t.audioLocaleUnavailable;
      case _Problem.noSpeech:
        return t.noSpeechDetected;
      case _Problem.failed:
        return t.audioFailed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final unsupported = _init == SpeechInitResult.notSupported;
    final micUsable = _init != null && !unsupported && widget.enabled;
    final problem = _problemText(t);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton.filled(
              iconSize: 28,
              tooltip: _listening ? t.recordStop : t.recordStart,
              onPressed: micUsable ? _toggle : null,
              style: _listening
                  ? IconButton.styleFrom(backgroundColor: scheme.error)
                  : null,
              icon: Icon(_listening ? Icons.stop : Icons.mic),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _init == null
                    ? t.audioPreparing
                    : _listening
                        ? t.listening
                        : unsupported
                            ? t.audioNotSupportedShort
                            : t.recordStart,
                style: textTheme.titleSmall,
              ),
            ),
            if (_listening)
              Text(t.audioSecondsLeft(_countdown.secondsLeft),
                  style: textTheme.titleSmall),
          ],
        ),
        if (_listening) ...[
          const SizedBox(height: 6),
          LinearProgressIndicator(value: _countdown.progress),
        ],
        if (problem != null) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: scheme.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(problem,
                    style: textTheme.bodySmall?.copyWith(color: scheme.error)),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: TextField(
            controller: widget.controller,
            // Read-only while words are streaming in, editable afterwards.
            readOnly: _listening,
            maxLines: null,
            expands: true,
            maxLength: 4000,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              hintText: t.transcriptHint,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }
}
