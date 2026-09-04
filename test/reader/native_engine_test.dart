// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/epub/epub_book.dart';
import 'package:lanna/features/reader/epub_view.dart';
import 'package:lanna/features/reader/native/book_source.dart';
import 'package:lanna/features/reader/native/native_epub_view.dart';

void main() {
  late Directory root;

  String words(int count) =>
      List.generate(count, (i) => 'palabra${i % 10}').join(' ');

  setUp(() {
    root = Directory.systemTemp.createTempSync('lanna_native');
  });

  tearDown(() {
    try {
      if (root.existsSync()) root.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 24; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
  }

  Future<void> act(WidgetTester tester, Future<void> Function() action) async {
    unawaited(action());
    await settle(tester);
  }

  NativeBookSource sourceWith(List<String> bodies, {List<EpubTocEntry>? toc}) {
    final manifest = <ManifestItem>[];
    final spine = <SpineItem>[];
    for (var i = 0; i < bodies.length; i++) {
      final href = 'cap$i.xhtml';
      File('${root.path}/$href')
          .writeAsStringSync('<html><body>${bodies[i]}</body></html>');
      manifest.add(
        ManifestItem(
          id: 'c$i',
          href: href,
          mediaType: 'application/xhtml+xml',
          properties: const {},
        ),
      );
      spine.add(SpineItem(index: i, idref: 'c$i', href: href, linear: true));
    }
    return NativeBookSource(
      root: root,
      book: EpubBook(
        opfPath: 'content.opf',
        metadata: const EpubMetadata(title: 'Prueba', author: 'Autora'),
        manifest: manifest,
        spine: spine,
        toc: toc ?? const [EpubTocEntry(label: 'Uno', href: 'cap0.xhtml')],
      ),
    );
  }

  Future<EpubViewController> mount(
    WidgetTester tester,
    NativeBookSource source, {
    EpubViewCallbacks? callbacks,
    String? locator,
    double? percent,
    Size size = const Size(400, 600),
  }) async {
    EpubViewController? controller;
    final wired = EpubViewCallbacks(
      onReady: (c) => controller = c,
      onLocationChanged: callbacks?.onLocationChanged,
      onTocLoaded: callbacks?.onTocLoaded,
      onTextSelected: callbacks?.onTextSelected,
      onSelectionCleared: callbacks?.onSelectionCleared,
      onPageCount: callbacks?.onPageCount,
      onSearchResults: callbacks?.onSearchResults,
      onHighlightTapped: callbacks?.onHighlightTapped,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: MediaQuery(
                data: MediaQueryData(size: size),
                child: NativeEpubView(
                  source: source,
                  callbacks: wired,
                  initialLocator: locator,
                  initialPercent: percent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    expect(controller, isNotNull, reason: 'el motor no llegó a estar listo');
    return controller!;
  }

  testWidgets('pinta la primera página y avisa del índice', (tester) async {
    final tocs = <List<TocEntry>>[];
    final source = sourceWith(['<h1>Capítulo uno</h1><p>${words(80)}</p>']);

    await mount(
      tester,
      source,
      callbacks: EpubViewCallbacks(onTocLoaded: tocs.add),
    );

    expect(find.byType(Text), findsWidgets);
    expect(tocs.single.single.label, 'Uno');
  });

  testWidgets('next avanza de página y luego de capítulo', (tester) async {
    final locations = <ReaderLocation>[];
    final source = sourceWith(['<p>${words(300)}</p>', '<p>${words(300)}</p>']);

    final controller = await mount(
      tester,
      source,
      callbacks: EpubViewCallbacks(onLocationChanged: locations.add),
    );

    final first = locations.last;
    expect(first.chapterIndex, 0);
    expect(first.atStart, isTrue);

    await act(tester, () => controller.next());
    final second = locations.last;
    expect(second.chapterIndex, 0);
    expect(
      ReaderLocator.parse(second.cfi)!.offset,
      greaterThan(ReaderLocator.parse(first.cfi)!.offset),
    );

    for (var i = 0; i < 40; i++) {
      await act(tester, () => controller.next());
      if (locations.last.chapterIndex == 1) break;
    }
    expect(locations.last.chapterIndex, 1);
  });

  testWidgets('previous vuelve al capítulo anterior por su última página', (
    tester,
  ) async {
    final locations = <ReaderLocation>[];
    final source = sourceWith(['<p>${words(200)}</p>', '<p>${words(30)}</p>']);

    final controller = await mount(
      tester,
      source,
      callbacks: EpubViewCallbacks(onLocationChanged: locations.add),
    );

    await act(tester, () => controller.goToCfi('spine:1#0'));
    expect(locations.last.chapterIndex, 1);

    await act(tester, () => controller.previous());

    expect(locations.last.chapterIndex, 0);
    expect(
      ReaderLocator.parse(locations.last.cfi)!.offset,
      greaterThan(0),
      reason: 'debería volver al final del capítulo, no al principio',
    );
  });

  testWidgets('el localizador inicial restaura la posición', (tester) async {
    final locations = <ReaderLocation>[];
    final source = sourceWith(['<p>${words(400)}</p>']);

    await mount(
      tester,
      source,
      callbacks: EpubViewCallbacks(onLocationChanged: locations.add),
      locator: 'spine:0#1200',
    );

    final offset = ReaderLocator.parse(locations.last.cfi)!.offset;
    expect(offset, greaterThan(600));
    expect(offset, lessThanOrEqualTo(1200));
  });

  testWidgets('el porcentaje crece de forma monótona', (tester) async {
    final locations = <ReaderLocation>[];
    final source = sourceWith([
      '<p>${words(150)}</p>',
      '<p>${words(150)}</p>',
      '<p>${words(150)}</p>',
    ]);

    final controller = await mount(
      tester,
      source,
      callbacks: EpubViewCallbacks(onLocationChanged: locations.add),
    );

    var previous = -1.0;
    for (var i = 0; i < 25; i++) {
      final percentage = locations.last.percentage ?? 0;
      expect(percentage, greaterThanOrEqualTo(previous));
      expect(percentage, inInclusiveRange(0, 1));
      previous = percentage;
      await act(tester, () => controller.next());
    }
    expect(previous, greaterThan(0));
  });

  testWidgets('goToPercentage cae en el capítulo correcto', (tester) async {
    final locations = <ReaderLocation>[];
    final source = sourceWith([
      '<p>${words(200)}</p>',
      '<p>${words(200)}</p>',
      '<p>${words(200)}</p>',
    ]);

    final controller = await mount(
      tester,
      source,
      callbacks: EpubViewCallbacks(onLocationChanged: locations.add),
    );

    await act(tester, () => controller.goToPercentage(0.9));

    expect(locations.last.chapterIndex, 2);
  });

  testWidgets('la selección devuelve desplazamientos exactos', (tester) async {
    final selections = <ReaderSelection>[];
    final source = sourceWith(['<p>${words(60)}</p>']);

    await mount(
      tester,
      source,
      callbacks: EpubViewCallbacks(onTextSelected: selections.add),
    );

    final document = await source.document(0);
    final paragraph = find.byType(Text).first;
    final topLeft = tester.getTopLeft(paragraph);
    final size = tester.getSize(paragraph);

    final gesture = await tester.startGesture(
      topLeft + const Offset(4, 8),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await gesture.moveTo(topLeft + Offset(size.width - 8, 8));
    await tester.pump();
    await gesture.up();
    await settle(tester);

    expect(selections, isNotEmpty, reason: 'no se reportó ninguna selección');
    final selection = selections.last;
    final locator = ReaderLocator.parse(selection.cfi)!;

    expect(selection.text, isNotEmpty);
    expect(
      locator.isRange,
      isTrue,
      reason: 'el localizador de la selección debe llevar rango',
    );
    expect(
      locator.end! - locator.offset,
      selection.text.length,
      reason: 'el rango no cubre el texto seleccionado',
    );
    expect(
      selection.text,
      document.text.substring(
        locator.offset,
        locator.offset + selection.text.length,
      ),
      reason: 'los desplazamientos no corresponden al texto seleccionado',
    );
  });

  testWidgets('cambiar la tipografía conserva la posición', (tester) async {
    final locations = <ReaderLocation>[];
    final source = sourceWith(['<p>${words(500)}</p>']);

    final controller = await mount(
      tester,
      source,
      callbacks: EpubViewCallbacks(onLocationChanged: locations.add),
    );

    for (var i = 0; i < 4; i++) {
      await act(tester, () => controller.next());
    }
    final before = ReaderLocator.parse(locations.last.cfi)!.offset;
    expect(before, greaterThan(0));

    await act(
      tester,
      () => controller.applyPresentation(
        const ReaderPresentation(
          background: '#101014',
          foreground: '#E8E4E9',
          fontSizePercent: 140,
        ),
      ),
    );

    final after = ReaderLocator.parse(locations.last.cfi)!.offset;
    expect(
      (after - before).abs(),
      lessThan(400),
      reason: 'la posición se perdió al cambiar el tamaño de letra',
    );
  });

  testWidgets('un CFI antiguo cae en el porcentaje guardado', (tester) async {
    final locations = <ReaderLocation>[];
    final source = sourceWith([
      '<p>${words(200)}</p>',
      '<p>${words(200)}</p>',
      '<p>${words(200)}</p>',
    ]);

    await mount(
      tester,
      source,
      callbacks: EpubViewCallbacks(onLocationChanged: locations.add),
      locator: 'epubcfi(/6/14[cap3]!/4/2/2)',
      percent: 0.85,
    );

    expect(
      locations.last.chapterIndex,
      2,
      reason: 'debía respaldarse en el porcentaje',
    );
  });

  testWidgets('goToCfi acepta un href del índice con ancla', (tester) async {
    final locations = <ReaderLocation>[];
    final source = sourceWith([
      '<p>${words(50)}</p>',
      '<p>${words(80)}</p><p id="medio">${words(80)}</p>',
    ]);

    final controller = await mount(
      tester,
      source,
      callbacks: EpubViewCallbacks(onLocationChanged: locations.add),
    );

    await act(tester, () => controller.goToCfi('cap1.xhtml#medio'));

    expect(locations.last.chapterIndex, 1);
    expect(ReaderLocator.parse(locations.last.cfi)!.offset, greaterThan(300));
  });

  testWidgets('goToCfi ignora un epubcfi sin romperse', (tester) async {
    final source = sourceWith(['<p>${words(50)}</p>']);
    final controller = await mount(tester, source);

    await act(tester, () => controller.goToCfi('epubcfi(/6/4!/4/2)'));

    expect(tester.takeException(), isNull);
  });

  testWidgets('la búsqueda encuentra en todos los capítulos', (tester) async {
    final results = <List<SearchHit>>[];
    final source = sourceWith([
      '<p>uno dos tres pistacho cuatro</p>',
      '<p>cinco seis</p>',
      '<p>pistacho al final</p>',
    ]);

    final controller = await mount(
      tester,
      source,
      callbacks: EpubViewCallbacks(
        onSearchResults: (_, hits) => results.add(hits),
      ),
    );

    await tester.runAsync(() => controller.search('pistacho'));
    await settle(tester);

    expect(results, isNotEmpty);
    final hits = results.last;
    expect(hits, hasLength(2));
    expect(ReaderLocator.parse(hits[0].cfi)!.chapter, 0);
    expect(ReaderLocator.parse(hits[1].cfi)!.chapter, 2);
    expect(hits[0].excerpt, contains('pistacho'));
  });

  testWidgets('ir a un resultado de búsqueda lleva a su posición', (
    tester,
  ) async {
    final results = <List<SearchHit>>[];
    final locations = <ReaderLocation>[];
    final source = sourceWith([
      '<p>${words(100)}</p>',
      '<p>${words(100)} pistacho ${words(100)}</p>',
    ]);

    final controller = await mount(
      tester,
      source,
      callbacks: EpubViewCallbacks(
        onLocationChanged: locations.add,
        onSearchResults: (_, hits) => results.add(hits),
      ),
    );

    await tester.runAsync(() => controller.search('pistacho'));
    await settle(tester);
    expect(results.last, hasLength(1));

    await act(tester, () => controller.goToCfi(results.last.single.cfi));
    expect(locations.last.chapterIndex, 1);
  });

  testWidgets('un resaltado tiñe su texto en la página', (tester) async {
    final source = sourceWith(['<p>${words(40)}</p>']);
    final controller = await mount(tester, source);
    final document = await source.document(0);

    Iterable<TextSpan> spans() sync* {
      for (final widget in tester.widgetList<Text>(find.byType(Text))) {
        final span = widget.textSpan;
        if (span is TextSpan) {
          for (final child in span.children ?? const <InlineSpan>[]) {
            if (child is TextSpan) yield child;
          }
        }
      }
    }

    expect(
      spans().where((s) => s.style?.backgroundColor != null),
      isEmpty,
      reason: 'no debía haber nada resaltado todavía',
    );

    await act(
      tester,
      () => controller.applyHighlights([
        HighlightSpec(
          cfi: const ReaderLocator(chapter: 0, offset: 5, end: 20).toString(),
          color: 'yellow',
        ),
      ]),
    );

    final tinted = spans().where((s) => s.style?.backgroundColor != null);
    expect(tinted, isNotEmpty, reason: 'el resaltado no se pintó');
    expect(
      tinted.map((s) => s.text).join(),
      document.text.substring(5, 20),
      reason: 'el resaltado no cubre el texto correcto',
    );
  });

  testWidgets('quitar un resaltado lo borra de la página', (tester) async {
    final source = sourceWith(['<p>${words(40)}</p>']);
    final controller = await mount(tester, source);
    final cfi = const ReaderLocator(chapter: 0, offset: 5, end: 20).toString();

    await act(
      tester,
      () =>
          controller.applyHighlights([HighlightSpec(cfi: cfi, color: 'green')]),
    );
    await act(tester, () => controller.removeHighlight(cfi));

    for (final widget in tester.widgetList<Text>(find.byType(Text))) {
      final span = widget.textSpan;
      if (span is! TextSpan) continue;
      for (final child in span.children ?? const <InlineSpan>[]) {
        expect((child as TextSpan).style?.backgroundColor, isNull);
      }
    }
  });

  group('resolución de href del índice', () {
    NativeBookSource src(List<String> hrefs, List<EpubTocEntry> toc) {
      final manifest = <ManifestItem>[];
      final spine = <SpineItem>[];
      for (var i = 0; i < hrefs.length; i++) {
        final dir = hrefs[i].contains('/')
            ? hrefs[i].substring(0, hrefs[i].lastIndexOf('/'))
            : '';
        Directory('${root.path}/$dir').createSync(recursive: true);
        File('${root.path}/${hrefs[i]}')
            .writeAsStringSync('<html><body><p>cap $i</p></body></html>');
        manifest.add(
          ManifestItem(
            id: 'c$i',
            href: hrefs[i],
            mediaType: 'application/xhtml+xml',
            properties: const {},
          ),
        );
        spine.add(
          SpineItem(index: i, idref: 'c$i', href: hrefs[i], linear: true),
        );
      }
      return NativeBookSource(
        root: root,
        book: EpubBook(
          opfPath: 'OEBPS/content.opf',
          metadata: const EpubMetadata(title: 'T', author: 'A'),
          manifest: manifest,
          spine: spine,
          toc: toc,
        ),
      );
    }

    test('coincidencia exacta', () {
      final s = src(['Text/a.xhtml', 'Text/b.xhtml'], const []);
      expect(s.chapterForHref('Text/b.xhtml'), 1);
      expect(s.chapterForHref('Text/b.xhtml#x'), 1);
    });

    test('el índice trae una ruta con prefijo extra', () {
      final s = src(['Text/a.xhtml', 'Text/b.xhtml'], const []);
      expect(s.chapterForHref('OEBPS/Text/b.xhtml'), 1);
    });

    test('el índice trae una ruta más corta que el spine', () {
      final s = src(['OEBPS/Text/a.xhtml', 'OEBPS/Text/b.xhtml'], const []);
      expect(s.chapterForHref('Text/b.xhtml'), 1);
    });

    test('nombre de archivo ambiguo no resuelve a ciegas', () {
      final s = src(['p1/ch.xhtml', 'p2/ch.xhtml'], const []);
      expect(s.chapterForHref('ch.xhtml'), isNull);
    });

    test('nombre de archivo inequívoco sí resuelve', () {
      final s = src(['p1/intro.xhtml', 'p2/final.xhtml'], const []);
      expect(s.chapterForHref('final.xhtml'), 1);
    });

    test('rutas con ./ y escapes', () {
      final s = src(['Text/a b.xhtml'], const []);
      expect(s.chapterForHref('./Text/a%20b.xhtml'), 0);
    });
  });

  group('navegación por el índice', () {
    testWidgets('un href sin ancla lleva al inicio de su capítulo', (
      tester,
    ) async {
      final locations = <ReaderLocation>[];
      final source = sourceWith(
        ['<p>${words(60)}</p>', '<p>${words(400)}</p>', '<p>${words(60)}</p>'],
        toc: const [
          EpubTocEntry(label: 'Uno', href: 'cap0.xhtml'),
          EpubTocEntry(label: 'Dos', href: 'cap1.xhtml'),
          EpubTocEntry(label: 'Tres', href: 'cap2.xhtml'),
        ],
      );

      final controller = await mount(
        tester,
        source,
        callbacks: EpubViewCallbacks(onLocationChanged: locations.add),
      );

      await act(tester, () => controller.goToCfi('cap2.xhtml'));

      expect(locations.last.chapterIndex, 2);
      expect(ReaderLocator.parse(locations.last.cfi)!.offset, 0);
    });

    testWidgets('un href con ancla cae en la sección, no al inicio', (
      tester,
    ) async {
      final locations = <ReaderLocation>[];
      final source = sourceWith(
        [
          '<p>${words(60)}</p>',
          '<h2 id="s1">Sección uno</h2><p>${words(400)}</p>'
              '<h2 id="s2">Sección dos</h2><p>${words(400)}</p>'
              '<h2 id="s3">Sección tres</h2><p>${words(200)}</p>',
        ],
        toc: const [
          EpubTocEntry(label: 'Uno', href: 'cap0.xhtml'),
          EpubTocEntry(label: 'S1', href: 'cap1.xhtml#s1'),
          EpubTocEntry(label: 'S3', href: 'cap1.xhtml#s3'),
        ],
      );

      final controller = await mount(
        tester,
        source,
        callbacks: EpubViewCallbacks(onLocationChanged: locations.add),
      );

      late int s3Offset;
      await tester.runAsync(() async {
        final doc = await source.document(1);
        s3Offset = doc.offsetForAnchor('s3');
      });
      expect(s3Offset, greaterThan(0));

      await act(tester, () => controller.goToCfi('cap1.xhtml#s3'));
      expect(locations.last.chapterIndex, 1);
      final pageStart = ReaderLocator.parse(locations.last.cfi)!.offset;

      expect(
        pageStart,
        lessThanOrEqualTo(s3Offset),
        reason: 'la página no debe empezar después del ancla',
      );
      expect(
        s3Offset - pageStart,
        lessThan(500),
        reason:
            'la página de destino debe contener el ancla, '
            'no quedar una página corta (pageStart=\$pageStart s3=\$s3Offset)',
      );
    });

    testWidgets('saltar a un ancla de un capítulo nunca visitado', (
      tester,
    ) async {
      final locations = <ReaderLocation>[];
      final source = sourceWith(
        [
          '<p>${words(40)}</p>',
          '<p>${words(40)}</p>',
          '<p>${words(500)}</p><h2 id="final">Final</h2><p>${words(80)}</p>',
        ],
        toc: const [
          EpubTocEntry(label: 'Uno', href: 'cap0.xhtml'),
          EpubTocEntry(label: 'Inicio c2', href: 'cap2.xhtml'),
          EpubTocEntry(label: 'Final', href: 'cap2.xhtml#final'),
        ],
      );

      final controller = await mount(
        tester,
        source,
        callbacks: EpubViewCallbacks(onLocationChanged: locations.add),
      );

      await act(tester, () => controller.goToCfi('cap2.xhtml#final'));
      expect(locations.last.chapterIndex, 2);
      final atFinal = ReaderLocator.parse(locations.last.cfi)!.offset;

      await act(tester, () => controller.goToCfi('cap2.xhtml'));
      final atStart = ReaderLocator.parse(locations.last.cfi)!.offset;

      expect(
        atFinal,
        greaterThan(atStart + 800),
        reason: '"Final" está tras 500 palabras; no debe caer junto al inicio',
      );
    });

    testWidgets('cada salto cae en la página que contiene su ancla', (
      tester,
    ) async {
      final locations = <ReaderLocation>[];
      final buffer = StringBuffer();
      final toc = <EpubTocEntry>[
        const EpubTocEntry(label: 'Uno', href: 'cap0.xhtml'),
      ];
      for (var i = 0; i < 12; i++) {
        buffer.write('<h3 id="sec$i">Sección $i</h3><p>${words(220)}</p>');
        toc.add(EpubTocEntry(label: 'Sec $i', href: 'cap1.xhtml#sec$i'));
      }
      final source = sourceWith([
        '<p>${words(30)}</p>',
        buffer.toString(),
      ], toc: toc);

      final controller = await mount(
        tester,
        source,
        callbacks: EpubViewCallbacks(onLocationChanged: locations.add),
      );

      late Map<int, int> anchorAt;
      await tester.runAsync(() async {
        final doc = await source.document(1);
        anchorAt = {
          for (var i = 0; i < 12; i++) i: doc.offsetForAnchor('sec$i'),
        };
      });
      expect(anchorAt[11]! > anchorAt[0]!, isTrue);

      for (final i in [3, 8, 11, 5, 0]) {
        await act(tester, () => controller.goToCfi('cap1.xhtml#sec$i'));
        final start = ReaderLocator.parse(locations.last.cfi)!.offset;
        final anchor = anchorAt[i]!;
        expect(
          start,
          lessThanOrEqualTo(anchor),
          reason: 'sec$i: la página empieza en $start, tras el ancla $anchor',
        );
        expect(
          anchor - start,
          lessThan(500),
          reason: 'sec$i: cayó una página corta (inicio $start, ancla $anchor)',
        );
      }
    });
  });

  testWidgets('un documento vacío no rompe el motor', (tester) async {
    final source = sourceWith(['   ']);

    final controller = await mount(tester, source);
    await act(tester, () => controller.next());

    expect(tester.takeException(), isNull);
  });
}
