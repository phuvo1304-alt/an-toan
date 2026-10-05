import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/locale_provider.dart';
import '../../l10n/app_localizations.dart';
import 'audio_tab.dart';
import 'scam_api.dart';

class ScamCheckerScreen extends ConsumerStatefulWidget {
  const ScamCheckerScreen({super.key});

  @override
  ConsumerState<ScamCheckerScreen> createState() => _ScamCheckerScreenState();
}

class _ScamCheckerScreenState extends ConsumerState<ScamCheckerScreen>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _transcriptController = TextEditingController(); // Voice tab
  // Tabs: 0 = Text, 1 = Screenshot, 2 = Voice.
  late final TabController _tabs = TabController(length: 3, vsync: this);
  late final ScamApi _api = ref.read(scamApiProvider);

  Uint8List? _imageBytes;
  String? _imageMime;
  bool _loading = false;
  String? _errorText;
  bool _audioListening = false;

  @override
  void dispose() {
    _textController.dispose();
    _transcriptController.dispose();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    // Shrink the image on the phone first: faster upload and cheaper AI call.
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final name = file.path.toLowerCase();
    setState(() {
      _imageBytes = bytes;
      _imageMime = name.endsWith('.png')
          ? 'image/png'
          : name.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';
      _errorText = null;
    });
  }

  Future<void> _check() async {
    final t = AppLocalizations.of(context)!;
    final tab = _tabs.index;
    final useImage = tab == 1;
    // The Voice tab sends its (edited) transcript through the same text path.
    final text =
        (tab == 2 ? _transcriptController : _textController).text.trim();

    if (tab == 2 && text.isEmpty) {
      setState(() => _errorText = t.audioTranscriptEmpty);
      return;
    }
    if ((!useImage && text.isEmpty) || (useImage && _imageBytes == null)) {
      setState(() => _errorText = t.errorEmpty);
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final result = await _api.analyze(
        text: useImage ? null : text,
        imageBytes: useImage ? _imageBytes : null,
        imageMime: useImage ? _imageMime : null,
        language: ref.read(localeProvider).languageCode,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      context.push('/result', extra: result);
    } on ScamApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText = _messageFor(e.error, t);
      });
    }
  }

  String _messageFor(ScamError e, AppLocalizations t) {
    switch (e) {
      case ScamError.notConfigured:
        return t.errorNotConfigured;
      case ScamError.empty:
        return t.errorEmpty;
      case ScamError.tooLong:
        return t.errorTooLong;
      case ScamError.imageTooLarge:
        return t.errorImageTooLarge;
      case ScamError.rateLimited:
        return t.errorRateLimited;
      case ScamError.network:
        return t.errorNetwork;
      case ScamError.generic:
        return t.errorGeneric;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.checkerTitle),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(icon: const Icon(Icons.notes), text: t.tabText),
            Tab(icon: const Icon(Icons.image_outlined), text: t.tabScreenshot),
            Tab(icon: const Icon(Icons.mic_none), text: t.tabAudio),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SizedBox(
              height: 260,
              child: TabBarView(
                controller: _tabs,
                children: [
                  TextField(
                    controller: _textController,
                    maxLines: null,
                    expands: true,
                    maxLength: 4000,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      hintText: t.pasteHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  _imageTab(t),
                  AudioTab(
                    controller: _transcriptController,
                    enabled: !_loading,
                    onListeningChanged: (listening) {
                      if (mounted) setState(() => _audioListening = listening);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, size: 18, color: scheme.outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.privacyNote,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.outline),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_errorText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: scheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorText!,
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            FilledButton.icon(
              // Not while the Voice tab is still listening: stop first, then check.
              onPressed: _loading || _audioListening ? null : _check,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.shield_outlined),
              label: Text(_loading ? t.checking : t.checkButton),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageTab(AppLocalizations t) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_imageBytes != null)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Image.memory(_imageBytes!, fit: BoxFit.contain),
              ),
            )
          else
            Expanded(
              child: Center(
                child: Text(t.noImageSelected,
                    style: TextStyle(color: scheme.outline)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _pickImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(_imageBytes == null ? t.pickImage : t.changeImage),
            ),
          ),
        ],
      ),
    );
  }
}
