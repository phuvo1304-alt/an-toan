import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/locale_provider.dart';
import '../../l10n/app_localizations.dart';
import 'audio_tab.dart';
import 'image_prep.dart';
import 'image_selection.dart';
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

  final _images = ImageSelection(); // Screenshot tab, in sending order
  bool _preparingImages = false;
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

  /// Adds screenshots (up to the 3-image limit), keeping the order they were
  /// added in. Each one is made upright, shrunk and stripped of EXIF in a
  /// background isolate (prepareImage), so the UI does not freeze.
  Future<void> _addImages() async {
    final t = AppLocalizations.of(context)!;
    final remaining = _images.remaining;
    if (remaining <= 0) return;
    final raw = await ref.read(imageSourceProvider)(remaining);
    if (raw.isEmpty || !mounted) return;

    setState(() {
      _preparingImages = true;
      _errorText = null;
    });
    final prepared = <Uint8List>[];
    var unreadable = 0;
    for (final bytes in raw) {
      final p = await prepareImage(bytes, singleImageLongSide);
      if (p == null) {
        unreadable++;
      } else {
        prepared.add(p.bytes);
      }
    }
    if (!mounted) return;
    setState(() {
      final dropped = _images.addAll(prepared); // some platforms ignore the limit
      _preparingImages = false;
      if (unreadable > 0) {
        _errorText = t.imageUnsupported;
      } else if (dropped > 0) {
        _errorText = t.imagesLimitReached;
      }
    });
  }

  void _removeImage(int id) => setState(() {
        _images.remove(id);
        _errorText = null;
      });

  /// The screenshots to send. One keeps the 1600 px version; 2-3 are each
  /// shrunk again to 1024 px on the long side (off the UI thread).
  Future<List<ImageUpload>> _imagesToSend() async {
    final items = _images.items;
    if (items.length == 1) return [ImageUpload(items.first.bytes)];
    final uploads = <ImageUpload>[];
    for (final item in items) {
      final p = await prepareImage(item.bytes, multiImageLongSide);
      if (p == null) throw const ScamApiException(ScamError.unsupportedImage);
      uploads.add(ImageUpload(p.bytes));
    }
    return uploads;
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
    if ((!useImage && text.isEmpty) || (useImage && _images.isEmpty)) {
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
        images: useImage ? await _imagesToSend() : null,
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
      case ScamError.tooManyImages:
        return t.errorTooManyImages;
      case ScamError.unsupportedImage:
        return t.imageUnsupported;
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
          padding: const EdgeInsets.all(AppSpace.md),
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
                    decoration: InputDecoration(hintText: t.pasteHint),
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
              // Not while the Voice tab is still listening: stop first, then check.
              onPressed:
                  _loading || _audioListening || _preparingImages ? null : _check,
              icon: _loading
                  ? const ButtonSpinner()
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
    final items = _images.items;
    final busy = _loading || _preparingImages;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      padding: const EdgeInsets.all(AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: items.isEmpty && !_preparingImages
                ? EmptyState(icon: Icons.image_outlined, message: t.noImageSelected)
                : Row(
                    children: [
                      for (var i = 0; i < maxImages; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpace.xs),
                            child: i < items.length
                                ? _Thumbnail(
                                    key: ValueKey('thumb-${items[i].id}'),
                                    bytes: items[i].bytes,
                                    number: i + 1,
                                    removeLabel: t.removeImage(i + 1),
                                    onRemove: busy ? null : () => _removeImage(items[i].id),
                                  )
                                : (i == items.length && _preparingImages)
                                    ? const Center(child: CircularProgressIndicator())
                                    : const SizedBox.shrink(),
                          ),
                        ),
                    ],
                  ),
          ),
          if (items.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.xs),
              child: Text(t.imagesOrderHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          const SizedBox(height: AppSpace.xs),
          OutlinedButton.icon(
            onPressed: busy || _images.isFull ? null : _addImages,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(items.isEmpty
                ? t.pickImage
                : _images.isFull
                    ? t.imagesLimitReached
                    : t.addImages(items.length, maxImages)),
          ),
        ],
      ),
    );
  }
}

/// One picked screenshot: its number in the sending order (1, 2, 3) and a
/// remove button. The number is what the server presents as the order.
class _Thumbnail extends StatelessWidget {
  final Uint8List bytes;
  final int number;
  final String removeLabel;
  final VoidCallback? onRemove;

  const _Thumbnail({
    super.key,
    required this.bytes,
    required this.number,
    required this.removeLabel,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          // Screenshots are tall; show their TOP, where a chat's messages start,
          // so each thumbnail is recognizable (the middle is often blank).
          child: Image.memory(bytes, fit: BoxFit.cover, alignment: Alignment.topCenter),
        ),
        Positioned(
          left: AppSpace.xs,
          top: AppSpace.xs,
          child: Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
            child: Text('$number',
                style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w700)),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          // A small 28 px circle, but still a full 48x48 tap area (padded).
          child: IconButton.filledTonal(
            tooltip: removeLabel,
            onPressed: onRemove,
            iconSize: 16,
            style: IconButton.styleFrom(
              minimumSize: const Size(28, 28),
              fixedSize: const Size(28, 28),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            icon: const Icon(Icons.close),
          ),
        ),
      ],
    );
  }
}
