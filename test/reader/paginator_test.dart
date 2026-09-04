// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/epub/epub_document.dart';
import 'package:lanna/features/reader/native/paginator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  EpubDocument doc(String body) => EpubDocumentParser.parse(
    '<html><body>$body</body></html>',
    spineIndex: 0,
    href: 'OEBPS/cap1.xhtml',
  );

  String words(int count) =>
      List.generate(count, (i) => 'palabra${i % 10}').join(' ');

  DocumentPagination paginate(
    EpubDocument document, {
    Size size = const Size(400, 600),
    int columns = 1,
    double fontSize = 18,
    ImageSizeResolver? images,
  }) => Paginator(
    style: PaginationStyle(fontSize: fontSize),
    metrics: PaginationMetrics(size: size, columns: columns),
    images: images,
  ).paginate(document);

  void expectContiguous(EpubDocument document, DocumentPagination result) {
    expect(result.pages, isNotEmpty);
    expect(result.pages.first.start, 0);
    for (var i = 1; i < result.pages.length; i++) {
      expect(
        result.pages[i].start,
        result.pages[i - 1].end,
        reason: 'hueco entre la página ${i - 1} y la $i',
      );
    }
    expect(result.pages.last.end, document.length);
  }

  group('cobertura', () {
    test('las páginas son contiguas y cubren el documento entero', () {
      final document = doc('<p>${words(400)}</p>');
      final result = paginate(document);

      expect(result.pageCount, greaterThan(1));
      expectContiguous(document, result);
    });

    test('varios bloques de tipos distintos se cubren por completo', () {
      final document = doc(
        '<h1>Capítulo</h1>'
        '<p>${words(120)}</p>'
        '<blockquote>${words(40)}</blockquote>'
        '<hr/>'
        '<ul><li>${words(20)}</li><li>${words(20)}</li></ul>'
        '<p>${words(120)}</p>',
      );
      final result = paginate(document);

      expectContiguous(document, result);
    });

    test('un documento vacío no produce páginas', () {
      final result = paginate(doc('   '));

      expect(result.pages, isEmpty);
      expect(result.pageForOffset(0), 0);
    });

    test('un documento corto cabe en una página', () {
      final document = doc('<p>Hola mundo</p>');
      final result = paginate(document);

      expect(result.pageCount, 1);
      expect(result.pages.single.start, 0);
      expect(result.pages.single.end, document.length);
    });
  });

  group('altura de columna', () {
    test('ningún fragmento se sale de la columna', () {
      final document = doc(
        '<p>${words(300)}</p><h2>Otro</h2><p>${words(300)}</p>',
      );
      final result = paginate(document);
      const columnHeight = 600 - 48.0;

      for (final page in result.pages) {
        for (final fragment in page.fragments) {
          expect(
            fragment.top + fragment.height,
            lessThanOrEqualTo(columnHeight + 0.5),
            reason: 'fragmento desbordado en la página ${page.index}',
          );
          expect(fragment.top, greaterThanOrEqualTo(-0.01));
        }
      }
    });

    test('una columna más baja produce más páginas', () {
      final document = doc('<p>${words(400)}</p>');

      final alto = paginate(document, size: const Size(400, 900));
      final bajo = paginate(document, size: const Size(400, 400));

      expect(bajo.pageCount, greaterThan(alto.pageCount));
      expectContiguous(document, alto);
      expectContiguous(document, bajo);
    });

    test('una letra más grande produce más páginas', () {
      final document = doc('<p>${words(400)}</p>');

      final pequena = paginate(document, fontSize: 14);
      final grande = paginate(document, fontSize: 28);

      expect(grande.pageCount, greaterThan(pequena.pageCount));
    });
  });

  group('corte de bloques', () {
    test('un párrafo largo se parte marcando la continuación', () {
      final document = doc('<p>${words(400)}</p>');
      final result = paginate(document);

      final fragments = [for (final page in result.pages) ...page.fragments];
      expect(fragments.length, greaterThan(1));
      expect(fragments.first.continuesBefore, isFalse);
      expect(fragments.first.continuesAfter, isTrue);
      expect(fragments.last.continuesBefore, isTrue);
      expect(fragments.last.continuesAfter, isFalse);

      for (var i = 1; i < fragments.length; i++) {
        expect(fragments[i].start, fragments[i - 1].end);
      }
    });

    test('el corte cae en un límite de línea, no a mitad de palabra', () {
      final document = doc('<p>${words(400)}</p>');
      final result = paginate(document);
      final text = document.text;

      for (var i = 1; i < result.pages.length; i++) {
        final cut = result.pages[i].start;
        final before = text[cut - 1];
        final after = text[cut];
        expect(
          before == ' ' || after == ' ' || before == '\n',
          isTrue,
          reason: 'corte a mitad de palabra en $cut: "$before|$after"',
        );
      }
    });

    test('los tramos del fragmento conservan sus marcas', () {
      final document = doc(
        '<p>${words(60)} <em>cursiva</em> ${words(200)}</p>',
      );
      final result = paginate(document);

      final italic = [
        for (final page in result.pages)
          for (final fragment in page.fragments)
            for (final piece in fragment.runs)
              if (piece.marks.contains(InlineMark.italic)) piece,
      ];
      expect(italic.map((r) => r.text).join(), 'cursiva');
    });

    test('el texto de todos los fragmentos reconstruye el documento', () {
      final document = doc('<p>${words(150)}</p><p>${words(150)}</p>');
      final result = paginate(document);

      final rebuilt = [
        for (final page in result.pages)
          for (final fragment in page.fragments)
            for (final piece in fragment.runs) piece.text,
      ].join();

      expect(rebuilt, document.text);
    });
  });

  group('imágenes', () {
    test('nunca se parten entre páginas', () {
      final document = doc(
        '<p>${words(200)}</p><img src="a.png"/><p>${words(200)}</p>',
      );
      final result = paginate(document, images: (_) => const Size(600, 900));

      final image = [
        for (final page in result.pages)
          for (final fragment in page.fragments)
            if (fragment.block.kind == BlockKind.image) fragment,
      ];
      expect(image, hasLength(1));
      expect(image.single.isPartial, isFalse);
      expect(image.single.imageSize, isNotNull);
    });

    test('se escalan para caber en la columna', () {
      final document = doc('<img src="a.png"/>');
      final result = paginate(
        document,
        size: const Size(400, 600),
        images: (_) => const Size(2000, 1000),
      );

      final size = result.pages.single.fragments.single.imageSize!;
      expect(size.width, lessThanOrEqualTo(400 - 48 + 0.01));
      expect(size.height, lessThanOrEqualTo(600 - 48 + 0.01));
      expect(size.width / size.height, closeTo(2.0, 0.01));
    });

    test('sin tamaño conocido se usa una proporción por defecto', () {
      final document = doc('<img src="a.png"/>');
      final result = paginate(document);

      expect(result.pages.single.fragments.single.imageSize, isNotNull);
    });
  });

  group('dos columnas', () {
    test(
      'cada página llena las dos columnas antes de pasar a la siguiente',
      () {
        final document = doc('<p>${words(600)}</p>');
        final result = paginate(
          document,
          size: const Size(800, 600),
          columns: 2,
        );

        expectContiguous(document, result);
        for (final page in result.pages.take(result.pageCount - 1)) {
          expect(page.fragments.map((f) => f.column).toSet(), {
            0,
            1,
          }, reason: 'la página ${page.index} no usó las dos columnas');
        }
      },
    );

    test(
      'con el mismo ancho de columna, dos columnas hacen la mitad de páginas',
      () {
        final document = doc('<p>${words(600)}</p>');

        final una = paginate(document, size: const Size(400, 600));
        final dos = paginate(document, size: const Size(800, 600), columns: 2);

        expect(dos.pageCount, lessThan(una.pageCount));
        expect(
          dos.pageCount,
          greaterThanOrEqualTo((una.pageCount / 2).floor()),
        );
      },
    );

    test('dos columnas no ensanchan la página, solo acortan la línea', () {
      final document = doc('<p>${words(600)}</p>');

      final una = paginate(document, size: const Size(800, 600));
      final dos = paginate(document, size: const Size(800, 600), columns: 2);

      expect(dos.pageCount, greaterThanOrEqualTo(una.pageCount));
    });
  });

  group('localización', () {
    test('pageForOffset encuentra la página de cada desplazamiento', () {
      final document = doc('<p>${words(400)}</p>');
      final result = paginate(document);

      for (final page in result.pages) {
        expect(result.pageForOffset(page.start), page.index);
        expect(result.pageForOffset(page.end - 1), page.index);
      }
    });

    test('un desplazamiento fuera de rango cae en los extremos', () {
      final document = doc('<p>${words(100)}</p>');
      final result = paginate(document);

      expect(result.pageForOffset(-5), 0);
      expect(result.pageForOffset(document.length + 50), result.pageCount - 1);
    });
  });

  group('bloques enormes', () {
    test('un bloque con muchos saltos duros se pagina sin colapsar', () {
      final line = words(12);
      final document = doc('<p>${List.filled(400, line).join('<br/>')}</p>');

      expect(document.blocks, hasLength(1));
      expect(document.blocks.single.text.length, greaterThan(20000));

      final sw = Stopwatch()..start();
      final result = paginate(document);
      sw.stop();

      expectContiguous(document, result);
      expect(result.pageCount, greaterThan(10));
      expect(
        sw.elapsedMilliseconds,
        lessThan(4000),
        reason: 'la medición incremental no debería tardar tanto',
      );
    });

    test('los saltos duros no se pierden al paginar', () {
      final document = doc('<p>uno<br/>dos<br/>tres</p>');
      final result = paginate(document);

      final rebuilt = [
        for (final page in result.pages)
          for (final fragment in page.fragments)
            for (final piece in fragment.runs) piece.text,
      ].join();

      expect(rebuilt, 'uno\ndos\ntres');
    });
  });

  group('trabajo reanudable', () {
    PaginationJob jobFor(EpubDocument document) => Paginator(
      style: const PaginationStyle(fontSize: 18),
      metrics: const PaginationMetrics(size: Size(400, 600)),
    ).jobFor(document);

    test('avanzar a trozos da el mismo resultado que de una vez', () {
      final document = doc(
        '<p>${words(500)}</p><h2>Fin</h2><p>${words(200)}</p>',
      );

      final entero = paginate(document);
      final job = jobFor(document);
      var steps = 0;
      while (!job.isDone && steps < 10000) {
        job.step(budget: const Duration(microseconds: 1));
        steps++;
      }

      expect(job.isDone, isTrue);
      expect(steps, greaterThan(1), reason: 'no se troceó nada');
      final troceado = job.snapshot();
      expect(troceado.pageCount, entero.pageCount);
      for (var i = 0; i < troceado.pageCount; i++) {
        expect(troceado.pages[i].start, entero.pages[i].start);
        expect(troceado.pages[i].end, entero.pages[i].end);
      }
    });

    test('hay páginas utilizables antes de terminar', () {
      final document = doc('<p>${words(800)}</p>');
      final job = jobFor(document);

      var steps = 0;
      while (job.pageCount == 0 && !job.isDone && steps < 100) {
        job.step(budget: const Duration(microseconds: 1));
        steps++;
      }

      expect(job.isDone, isFalse);
      expect(job.pageCount, greaterThan(0));
      expect(job.coveredOffset, greaterThan(0));
      expect(job.coveredOffset, lessThan(document.length));
    });

    test('un bloque con saltos duros se mide segmento a segmento', () {
      final line = words(12);
      final document = doc('<p>${List.filled(300, line).join('<br/>')}</p>');

      expect(document.blocks, hasLength(1));

      final job = jobFor(document);
      var steps = 0;
      while (job.pageCount < 3 && !job.isDone && steps < 100) {
        job.step(budget: const Duration(microseconds: 1));
        steps++;
      }

      expect(job.isDone, isFalse);
      expect(job.pageCount, greaterThanOrEqualTo(3));
      expect(
        job.coveredOffset,
        lessThan(document.length ~/ 2),
        reason: 'el bloque entero se midió de golpe',
      );
    });

    test('run completa lo que quede tras avanzar a medias', () {
      final document = doc('<p>${words(500)}</p>');
      final job = jobFor(document);

      job.step(budget: const Duration(microseconds: 1));
      job.run();

      expect(job.isDone, isTrue);
      expect(job.snapshot().pages.last.end, document.length);
    });
  });

  group('altura contra contenido', () {
    test('la altura del fragmento corresponde a su propio texto', () {
      const style = PaginationStyle(fontSize: 18);
      const metrics = PaginationMetrics(size: Size(400, 600));
      final document = doc('<p>${words(300)}</p><p>${words(120)}</p>');
      final result = Paginator(
        style: style,
        metrics: metrics,
      ).paginate(document);

      for (final page in result.pages) {
        for (final fragment in page.fragments) {
          if (fragment.block.kind == BlockKind.image) continue;
          final painter = TextPainter(
            text: TextSpan(
              children: [
                for (final piece in fragment.runs)
                  TextSpan(
                    text: piece.text,
                    style: style.styleForRun(fragment.block, piece),
                  ),
              ],
            ),
            textDirection: TextDirection.ltr,
            textAlign: style.alignFor(fragment.block),
            strutStyle: StrutStyle(
              fontSize: style.sizeFor(fragment.block),
              height: style.lineHeight,
              forceStrutHeight: true,
            ),
          )..layout(maxWidth: metrics.columnWidth);

          expect(
            painter.height,
            closeTo(fragment.height, 1.0),
            reason:
                'el fragmento ${fragment.start}..${fragment.end} reserva '
                '${fragment.height} pero su texto ocupa ${painter.height}',
          );
          painter.dispose();
        }
      }
    });
  });

  group('familia tipográfica', () {
    test('de una pila CSS se queda con la primera familia real', () {
      expect(fontFamilyFromCss('Newsreader, Georgia, serif'), 'Newsreader');
      expect(fontFamilyFromCss('Manrope, system-ui, sans-serif'), 'Manrope');
      expect(fontFamilyFromCss('"Iowan Old Style", serif'), 'Iowan Old Style');
    });

    test('una pila solo genérica no da familia', () {
      expect(fontFamilyFromCss('serif'), isNull);
      expect(fontFamilyFromCss('system-ui, sans-serif'), isNull);
      expect(fontFamilyFromCss(null), isNull);
      expect(fontFamilyFromCss(''), isNull);
    });
  });

  group('clave de composición', () {
    test('cambia con la tipografía y con el viewport', () {
      final document = doc('<p>Hola</p>');

      final a = paginate(document);
      final b = paginate(document, fontSize: 22);
      final c = paginate(document, size: const Size(500, 600));

      expect(a.key, isNot(b.key));
      expect(a.key, isNot(c.key));
      expect(a.key, paginate(document).key);
    });
  });
}
