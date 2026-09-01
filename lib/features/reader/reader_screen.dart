// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/book_repository.dart';
import '../../data/epub/epub_book.dart';
import '../../data/local/app_database.dart';
import '../../data/models/book_format.dart';
import 'epub_view.dart';
import 'epub_view_factory.dart';
import 'reader_prepare.dart';
import 'reader_settings_provider.dart';
import 'reader_theme.dart';
import 'server/reader_server.dart';
import 'widgets/appearance_panel.dart';
import 'widgets/toc_drawer.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final _focusNode = FocusNode();

  ReaderServer? _server;
  EpubViewController? _controller;
  Book? _book;
  EpubBook? _epubBook;
  Uri? _readerUrl;
  ReaderLocation? _location;

  List<EpubTocEntry> _fallbackToc = const [];
  double _lastPercent = 0;
  String? _cachedLocations;
  int _pageCount = 0;

  ReaderSettings _settings = const ReaderSettings();

  String? _error;
  bool _chromeVisible = true;
  bool _showAppearance = false;
  bool _showToc = false;

  Timer? _saveTimer;
  ProviderSubscription<AsyncValue<ReaderSettings>>? _settingsSub;

  @override
  void initState() {
    super.initState();
    _settings =
        ref.read(readerSettingsProvider).valueOrNull ?? const ReaderSettings();
    _settingsSub = ref.listenManual(readerSettingsProvider, (_, next) {
      final s = next.valueOrNull;
      if (s == null || !mounted) return;
      setState(() => _settings = s);
      _applySettings(s);
    });
    _open();
  }

  Future<void> _open() async {
    final repo = ref.read(bookRepositoryProvider);
    final book = await repo.findBook(widget.bookId);
    if (book == null) {
      setState(() => _error = 'El libro no está en la biblioteca');
      return;
    }
    if (book.format != BookFormat.epub) {
      setState(() => _error = 'Por ahora solo se pueden leer archivos EPUB');
      return;
    }
    final file = File(book.filePath);
    if (!file.existsSync()) {
      setState(() => _error = 'No se encontró el archivo del libro');
      return;
    }

    final progress = await repo.readProgress(widget.bookId);
    _lastPercent = progress?.percent ?? 0;
    _cachedLocations = await repo.readLocations(widget.bookId);

    final cache = await getApplicationCacheDirectory();
    final extractDir = Directory(p.join(cache.path, 'reader', widget.bookId));

    EpubBook? epubBook;
    try {
      epubBook = await compute(prepareEpub, (
        bytes: await file.readAsBytes(),
        extractDir: extractDir.path,
      ));
    } catch (_) {}

    final server = await ReaderServer.start(extractDir);
    await repo.markOpened(widget.bookId);

    if (!mounted) {
      await server.dispose();
      return;
    }
    setState(() {
      _book = book;
      _epubBook = epubBook;
      _server = server;
      _readerUrl = server.readerUrl(
        opfPath: epubBook?.opfPath,
        cfi: progress?.locator,
        hasLocations: _cachedLocations != null,
      );
    });
  }

  List<EpubTocEntry> get _toc {
    final parsed = _epubBook?.toc ?? const [];
    return parsed.isNotEmpty ? parsed : _fallbackToc;
  }

  int get _chapterTotal => _epubBook?.spine.where((s) => s.linear).length ?? 0;

  void _onLocation(ReaderLocation loc) {
    if (!mounted) return;
    if (loc.percentage != null) _lastPercent = loc.percentage!;
    setState(() => _location = loc);

    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), () {
      ref
          .read(bookRepositoryProvider)
          .saveProgress(
            bookId: widget.bookId,
            locator: loc.cfi,
            percent: _lastPercent,
            chapterIndex: loc.chapterIndex,
          );
    });
  }

  void _applySettings(ReaderSettings settings) {
    if (!mounted) return;
    _controller?.applyPresentation(settings.toPresentation());
  }

  @override
  void dispose() {
    _settingsSub?.close();
    _saveTimer?.cancel();
    final loc = _location;
    if (loc != null) {
      ref
          .read(bookRepositoryProvider)
          .saveProgress(
            bookId: widget.bookId,
            locator: loc.cfi,
            percent: _lastPercent,
            chapterIndex: loc.chapterIndex,
          );
    }
    _server?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.pageDown:
      case LogicalKeyboardKey.space:
        _controller?.next();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.pageUp:
        _controller?.previous();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        if (_showToc || _showAppearance) {
          setState(() => _showToc = _showAppearance = false);
          return KeyEventResult.handled;
        }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;

    return Scaffold(
      backgroundColor: settings.preset.background,
      body: _error != null
          ? _ErrorView(message: _error!)
          : _readerUrl == null
          ? const Center(child: CircularProgressIndicator())
          : Focus(
              focusNode: _focusNode,
              autofocus: true,
              onKeyEvent: _onKey,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        if (_showToc || _showAppearance) {
                          setState(() => _showToc = _showAppearance = false);
                        } else {
                          setState(() => _chromeVisible = !_chromeVisible);
                        }
                      },
                      child: createEpubView(
                        key: ValueKey(_readerUrl.toString()),
                        readerUrl: _readerUrl!,
                        callbacks: EpubViewCallbacks(
                          onReady: (c) {
                            _controller = c;
                            _applySettings(settings);
                            final cached = _cachedLocations;
                            if (cached != null) c.loadLocations(cached);
                            _focusNode.requestFocus();
                          },
                          onLocationChanged: _onLocation,
                          onTocLoaded: (toc) => setState(() {
                            _fallbackToc = [
                              for (final e in toc)
                                EpubTocEntry(label: e.label, href: e.href),
                            ];
                          }),
                          onLocationsGenerated: (json) {
                            _cachedLocations = json;
                            ref
                                .read(bookRepositoryProvider)
                                .saveLocations(widget.bookId, json);
                          },
                          onPageCount: (n) => setState(() => _pageCount = n),
                          onError: (m) => setState(() => _error = m),
                        ),
                      ),
                    ),
                  ),
                  if (_chromeVisible && !_showToc) _topBar(),
                  if (_chromeVisible && !_showToc) _bottomBar(),
                  if (_showAppearance)
                    Positioned(
                      right: 26,
                      bottom: 58,
                      child: AppearancePanel(
                        settings: settings,
                        onPreset: (p) => ref
                            .read(readerSettingsControllerProvider)
                            .setPreset(p),
                        onFontFamily: (f) => ref
                            .read(readerSettingsControllerProvider)
                            .setFontFamily(f),
                        onFontScale: (v) => ref
                            .read(readerSettingsControllerProvider)
                            .setFontScale(v),
                        onLineHeight: (v) => ref
                            .read(readerSettingsControllerProvider)
                            .setLineHeight(v),
                        onColumns: (m) => ref
                            .read(readerSettingsControllerProvider)
                            .setColumns(m),
                      ),
                    ),
                  if (_showToc)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: TocDrawer(
                        toc: _toc,
                        currentHref: _location?.href,
                        chapterCount: _chapterTotal,
                        pageCount: _pageCount,
                        onSelect: (entry) {
                          if (entry.href.isNotEmpty) {
                            _controller?.goToCfi(entry.href);
                          }
                          setState(() => _showToc = false);
                        },
                        onClose: () => setState(() => _showToc = false),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Color get _barColor => _settings.preset.background.withValues(alpha: 0.94);

  Widget _topBar() {
    final author = _book?.author;
    final title = _book?.title ?? '';
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _barColor,
          border: const Border(bottom: BorderSide(color: Color(0xFF1C1B21))),
        ),
        child: Row(
          children: [
            _BarButton(
              icon: Icons.chevron_left,
              size: 22,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Text(
                author == null ? title : '$title  ·  $author',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.reading(
                  fontSize: 13.5,
                  color: LannaColors.textMuted,
                ),
              ),
            ),
            _BarButton(
              icon: Icons.format_list_bulleted,
              active: _showToc,
              tooltip: 'Índice',
              onTap: () => setState(() {
                _showToc = !_showToc;
                _showAppearance = false;
              }),
            ),
            _BarButton(
              label: 'Aa',
              active: _showAppearance,
              tooltip: 'Apariencia',
              onTap: () => setState(() {
                _showAppearance = !_showAppearance;
                _showToc = false;
              }),
            ),
            _BarButton(
              icon: Icons.bookmark_border,
              tooltip: 'Marcador',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Marcadores: próximamente')),
              ),
            ),
            _BarButton(
              icon: Icons.search,
              tooltip: 'Buscar',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Búsqueda: próximamente')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar() {
    final pct = (_location?.percentage ?? _lastPercent).clamp(0.0, 1.0);
    final chapter = _location?.chapterIndex;
    final total = _chapterTotal;
    final mins = _location?.remainingMinutes;

    const style = TextStyle(
      fontSize: 11.5,
      color: Color(0xFF7A756B),
      fontFamily: AppFonts.ui,
    );

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 26),
        decoration: BoxDecoration(
          color: _barColor,
          border: const Border(top: BorderSide(color: Color(0xFF1C1B21))),
        ),
        child: Row(
          children: [
            if (chapter != null)
              Text(
                total > 0
                    ? 'Capítulo ${chapter + 1} de $total'
                    : 'Capítulo ${chapter + 1}',
                style: style,
              ),
            const SizedBox(width: 14),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 3,
                  backgroundColor: const Color(0xFF2A2831),
                  valueColor: const AlwaysStoppedAnimation(LannaColors.accent),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Text('${(pct * 100).round()} %', style: style),
            if (mins != null && mins > 0) ...[
              const Text('  ·  ', style: style),
              Text('quedan ~$mins min', style: style),
            ],
          ],
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    this.icon,
    this.label,
    this.active = false,
    this.tooltip,
    this.size = 19,
    required this.onTap,
  });

  final IconData? icon;
  final String? label;
  final bool active;
  final String? tooltip;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? LannaColors.accent : LannaColors.textMuted;
    final child = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: icon != null
            ? Icon(icon, size: size, color: color)
            : Text(
                label!,
                style: TextStyle(
                  fontFamily: AppFonts.serif,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
      ),
    );
    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: LannaColors.textMuted),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: LannaColors.textMuted)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Volver'),
          ),
        ],
      ),
    );
  }
}
