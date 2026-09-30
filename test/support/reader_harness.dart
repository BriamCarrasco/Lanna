// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/local/app_database.dart';
import 'package:lanna/data/local/database_provider.dart';
import 'package:lanna/data/models/book_format.dart';
import 'package:lanna/features/reader/native/book_source.dart';
import 'package:lanna/features/reader/native/native_epub_view.dart';
import 'package:lanna/features/reader/reader_screen.dart';
import 'package:lanna/features/reader/reader_theme.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:wakelock_plus/wakelock_plus.dart' as wakelock;
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class FakePathProvider extends PathProviderPlatform {
  FakePathProvider(this.root);

  final String root;

  Future<String> _sub(String name) async {
    final dir = Directory(p.join(root, name));
    await dir.create(recursive: true);
    return dir.path;
  }

  @override
  Future<String?> getTemporaryPath() => _sub('tmp');

  @override
  Future<String?> getApplicationSupportPath() => _sub('support');

  @override
  Future<String?> getApplicationCachePath() => _sub('cache');

  @override
  Future<String?> getApplicationDocumentsPath() => _sub('docs');

  @override
  Future<String?> getLibraryPath() => _sub('library');

  @override
  Future<String?> getDownloadsPath() => _sub('downloads');
}

class FakeWakelock extends WakelockPlusPlatformInterface {
  bool on = false;
  int toggles = 0;

  @override
  Future<void> toggle({required bool enable}) async {
    on = enable;
    toggles++;
  }

  @override
  Future<bool> get enabled async => on;
}

String chapterXhtml(String body) =>
    '<?xml version="1.0" encoding="utf-8"?>'
    '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>c</title></head>'
    '<body>$body</body></html>';

Uint8List buildReaderEpub({
  required List<String> chapters,
  String title = 'Libro de prueba',
  String author = 'Autora',
  String spineAttrs = '',
}) {
  const opf = 'OEBPS/content.opf';
  final items = StringBuffer();
  final refs = StringBuffer();
  final archive = Archive()
    ..addFile(ArchiveFile.string('mimetype', 'application/epub+zip'))
    ..addFile(
      ArchiveFile.string(
        'META-INF/container.xml',
        '<?xml version="1.0"?>'
            '<container version="1.0" '
            'xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
            '<rootfiles><rootfile full-path="$opf" '
            'media-type="application/oebps-package+xml"/></rootfiles></container>',
      ),
    );

  for (var i = 0; i < chapters.length; i++) {
    final href = 'c$i.xhtml';
    archive.addFile(
      ArchiveFile.string('OEBPS/$href', chapterXhtml(chapters[i])),
    );
    items.write(
      '<item id="c$i" href="$href" media-type="application/xhtml+xml"/>',
    );
    refs.write('<itemref idref="c$i"/>');
  }

  archive.addFile(
    ArchiveFile.string(
      opf,
      '<?xml version="1.0"?>'
      '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" '
      'unique-identifier="pub-id">'
      '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">'
      '<dc:identifier id="pub-id">urn:uuid:lanna-test</dc:identifier>'
      '<dc:title>$title</dc:title><dc:creator>$author</dc:creator>'
      '<dc:language>es</dc:language></metadata>'
      '<manifest>$items</manifest>'
      '<spine $spineAttrs>$refs</spine>'
      '</package>',
    ),
  );

  return Uint8List.fromList(ZipEncoder().encode(archive));
}

final tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

Uint8List buildComicZip({required List<String> pages, String? comicInfo}) {
  final archive = Archive();
  for (final name in pages) {
    archive.addFile(ArchiveFile.bytes(name, tinyPng));
  }
  if (comicInfo != null) {
    archive.addFile(ArchiveFile.string('ComicInfo.xml', comicInfo));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

class ReaderHarness {
  ReaderHarness._(this.root, this.db, this.wakelock);

  final Directory root;
  final AppDatabase db;
  final FakeWakelock wakelock;

  String words(int count) =>
      List.generate(count, (i) => 'palabra${i % 10}').join(' ');
}

ReaderHarness setUpReader() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final root = Directory.systemTemp.createTempSync('lanna_reader_');
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final fake = FakeWakelock();

  final previousPaths = PathProviderPlatform.instance;
  final previousWakelock = WakelockPlusPlatformInterface.instance;
  final previousFacade = wakelock.wakelockPlusPlatformInstance;
  PathProviderPlatform.instance = FakePathProvider(root.path);
  // WakelockPlus cachea la instancia al cargar la libreria, asi que sustituir
  // solo la del interface llega tarde.
  WakelockPlusPlatformInterface.instance = fake;
  wakelock.wakelockPlusPlatformInstance = fake;

  addTearDown(() async {
    PathProviderPlatform.instance = previousPaths;
    WakelockPlusPlatformInterface.instance = previousWakelock;
    wakelock.wakelockPlusPlatformInstance = previousFacade;
    await db.close();
    try {
      root.deleteSync(recursive: true);
    } catch (_) {}
  });

  return ReaderHarness._(root, db, fake);
}

extension ReaderHarnessX on ReaderHarness {
  Future<String> seedBook({
    required List<String> chapters,
    String id = 'libro',
    String title = 'Libro de prueba',
    String? spineAttrs,
    double percent = 0,
    String? locator,
  }) async {
    final file = File(p.join(root.path, '$id.epub'))
      ..writeAsBytesSync(
        buildReaderEpub(
          chapters: chapters,
          title: title,
          spineAttrs: spineAttrs ?? '',
        ),
      );

    await db.upsertBook(
      BooksCompanion.insert(
        id: id,
        title: title,
        filePath: file.path,
        format: BookFormat.epub,
        author: const Value('Autora'),
      ),
    );
    if (percent > 0 || locator != null) {
      await db.saveProgress(bookId: id, percent: percent, locator: locator);
    }
    return id;
  }

  Future<String> seedComic({
    required List<String> pages,
    String id = 'comic',
    String? comicInfo,
    List<int>? bytes,
    String? locator,
  }) async {
    final file = File(p.join(root.path, '$id.cbz'))
      ..writeAsBytesSync(
        bytes ?? buildComicZip(pages: pages, comicInfo: comicInfo),
      );
    await db.upsertBook(
      BooksCompanion.insert(
        id: id,
        title: 'Cómic de prueba',
        filePath: file.path,
        format: BookFormat.comic,
      ),
    );
    if (locator != null) {
      await db.saveProgress(bookId: id, percent: 0, locator: locator);
    }
    return id;
  }

  void corrupt({String id = 'libro'}) {
    File(p.join(root.path, '$id.epub')).writeAsBytesSync([1, 2, 3, 4]);
  }

  /// Los `watch` de drift no resuelven dentro de la zona fake de los tests:
  /// para leer estado hay que ir por consulta directa.
  Future<List<Bookmark>> bookmarks() => db.select(db.bookmarks).get();

  NativeBookSource sourceOf(WidgetTester tester) =>
      tester.widget<NativeEpubView>(find.byType(NativeEpubView)).source;

  Future<void> setAnimation(String mode) => db.saveReaderPrefs(
    const ReaderSettings().copyWith(pageAnimation: mode).toCompanion(),
  );

  Future<void> turnForward(WidgetTester tester, {bool back = false}) async {
    await tester.runAsync(() async {
      await tester.sendKeyEvent(
        back ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight,
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pump();
  }

  Future<void> pumpReader(
    WidgetTester tester, {
    String id = 'libro',
    Size size = const Size(600, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: ReaderScreen(bookId: id)),
      ),
    );
    await settleReader(tester);
  }
}

/// Monta el entorno, corre el cuerpo y desmonta el arbol dentro del propio
/// test: las consultas `watch` de drift difieren su limpieza con un Timer y
/// el binding lo da por pendiente si el arbol muere en el teardown.
void readerTest(
  String description,
  Future<void> Function(WidgetTester tester, ReaderHarness h) body,
) {
  testWidgets(description, (tester) async {
    final h = setUpReader();
    try {
      await body(tester, h);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
    }
  });
}

Future<void> settleReader(WidgetTester tester, {int rounds = 40}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 10),
  );
}
