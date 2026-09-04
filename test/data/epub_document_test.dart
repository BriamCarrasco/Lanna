// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/epub/epub_document.dart';

void main() {
  EpubDocument parse(String body, {String href = 'OEBPS/text/cap1.xhtml'}) =>
      EpubDocumentParser.parse(
        '<html><body>$body</body></html>',
        spineIndex: 3,
        href: href,
      );

  group('estructura', () {
    test('cada bloque de nivel superior se emite por separado', () {
      final doc = parse('<p>Uno</p><p>Dos</p><h2>Tres</h2>');

      expect(doc.blocks.map((b) => b.kind), [
        BlockKind.paragraph,
        BlockKind.paragraph,
        BlockKind.heading,
      ]);
      expect(doc.blocks.map((b) => b.text), ['Uno', 'Dos', 'Tres']);
      expect(doc.blocks.last.level, 2);
      expect(doc.spineIndex, 3);
    });

    test('los contenedores no generan bloques propios', () {
      final doc = parse('<div><section><p>Solo uno</p></section></div>');

      expect(doc.blocks, hasLength(1));
      expect(doc.blocks.single.text, 'Solo uno');
    });

    test('un div de contenido en línea es un párrafo', () {
      final doc = parse('<div>Uno</div><div>Dos</div>');

      expect(doc.blocks.map((b) => b.kind), [
        BlockKind.paragraph,
        BlockKind.paragraph,
      ]);
      expect(doc.blocks.map((b) => b.text), ['Uno', 'Dos']);
    });

    test('un div con bloques dentro sigue siendo contenedor', () {
      final doc = parse('<div>suelto<p>dentro</p></div>');

      expect(doc.blocks.map((b) => b.text), ['suelto', 'dentro']);
    });

    test('un bloque anidado corta el bloque que lo contiene', () {
      final doc = parse('<blockquote>Antes<p>Dentro</p>Después</blockquote>');

      expect(doc.blocks.map((b) => b.text), ['Antes', 'Dentro', 'Después']);
      expect(doc.blocks.first.kind, BlockKind.quote);
      expect(doc.blocks[1].kind, BlockKind.paragraph);
    });

    test('hr y saltos de página son bloques de longitud cero', () {
      final doc = parse(
        '<p>A</p><hr/><span epub:type="pagebreak" id="p12"/><p>B</p>',
      );

      final separator = doc.blocks.firstWhere(
        (b) => b.kind == BlockKind.separator,
      );
      final pageBreak = doc.blocks.firstWhere(
        (b) => b.kind == BlockKind.pageBreak,
      );
      expect(separator.isEmpty, isTrue);
      expect(pageBreak.isEmpty, isTrue);
      expect(pageBreak.id, 'p12');
    });

    test('role=doc-pagebreak también se reconoce', () {
      final doc = parse('<p>A</p><div role="doc-pagebreak"></div><p>B</p>');

      expect(
        doc.blocks.where((b) => b.kind == BlockKind.pageBreak),
        hasLength(1),
      );
    });
  });

  group('tramos en línea', () {
    test('las marcas se acumulan y se cierran al salir', () {
      final doc = parse(
        '<p>Un <em>texto <strong>muy</strong> raro</em> más</p>',
      );

      final runs = doc.blocks.single.runs;
      expect(runs.map((r) => r.text), [
        'Un ',
        'texto ',
        'muy',
        ' raro',
        ' más',
      ]);
      expect(runs[0].marks, isEmpty);
      expect(runs[1].marks, {InlineMark.italic});
      expect(runs[2].marks, {InlineMark.italic, InlineMark.bold});
      expect(runs[3].marks, {InlineMark.italic});
      expect(runs[4].marks, isEmpty);
    });

    test('los enlaces conservan su destino', () {
      final doc = parse('<p>Ver <a href="notas.xhtml#n1">la nota</a>.</p>');

      final link = doc.blocks.single.runs.firstWhere((r) => r.href != null);
      expect(link.text, 'la nota');
      expect(link.href, 'notas.xhtml#n1');
    });

    test('el texto contiguo con la misma marca no se fragmenta', () {
      final doc = parse('<p>Hola <span>mundo</span> otra vez</p>');

      expect(doc.blocks.single.runs, hasLength(1));
      expect(doc.blocks.single.text, 'Hola mundo otra vez');
    });
  });

  group('espacios', () {
    test('el espacio en blanco se colapsa y se recorta en los bordes', () {
      final doc = parse('<p>   Hola\n\n   mundo   </p>');

      expect(doc.blocks.single.text, 'Hola mundo');
    });

    test('pre conserva el espacio tal cual', () {
      final doc = parse('<pre>uno\n  dos\n</pre>');

      expect(doc.blocks.single.kind, BlockKind.preformatted);
      expect(doc.blocks.single.text, 'uno\n  dos\n');
    });

    test('br introduce un salto dentro del párrafo', () {
      final doc = parse('<p>Verso uno<br/>Verso dos</p>');

      expect(doc.blocks.single.text, 'Verso uno\nVerso dos');
    });

    test('dos br seguidos separan párrafos', () {
      final doc = parse('<p>Uno<br/><br/>Dos<br/><br/>Tres</p>');

      expect(doc.blocks.map((b) => b.text), ['Uno', 'Dos', 'Tres']);
      expect(doc.blocks.map((b) => b.kind), everyElement(BlockKind.paragraph));
    });

    test('tres br seguidos no dejan un bloque vacío', () {
      final doc = parse('<p>Uno<br/><br/><br/>Dos</p>');

      expect(doc.blocks.map((b) => b.text), ['Uno', 'Dos']);
    });

    test('un br al principio se ignora', () {
      final doc = parse('<p><br/>Uno</p>');

      expect(doc.blocks.single.text, 'Uno');
    });

    test('los desplazamientos siguen cuadrando tras separar por br', () {
      final doc = parse('<p>Uno<br/><br/>Dos</p>');

      expect(doc.text, 'UnoDos');
      expect(doc.length, 6);
      expect(doc.blocks[1].start, 3);
    });

    test('el espacio entre bloques no contamina el siguiente', () {
      final doc = parse('<p>Uno</p>\n\n  <p>Dos</p>');

      expect(doc.blocks.map((b) => b.text), ['Uno', 'Dos']);
    });
  });

  group('desplazamientos', () {
    test('son contiguos y coinciden con el texto plano', () {
      final doc = parse('<p>Hola</p><p>mundo</p><h1>fin</h1>');

      expect(doc.text, 'Holamundofin');
      expect(doc.length, doc.text.length);

      var expected = 0;
      for (final block in doc.blocks) {
        expect(block.start, expected);
        for (final run in block.runs) {
          expect(run.start, expected);
          expect(doc.text.substring(run.start, run.end), run.text);
          expected = run.end;
        }
        expect(block.end, expected);
      }
      expect(expected, doc.length);
    });

    test('las anclas apuntan al desplazamiento donde empiezan', () {
      final doc = parse('<p>Hola</p><p id="dos">mundo</p>');

      expect(doc.offsetForAnchor('dos'), 4);
      expect(doc.offsetForAnchor(null), 0);
      expect(doc.offsetForAnchor('inexistente'), 0);
    });

    test('un ancla en mitad de un párrafo cae en su posición', () {
      final doc = parse('<p>Hola <span id="medio">mundo</span></p>');

      expect(doc.offsetForAnchor('medio'), 5);
    });

    test('blockAt localiza el bloque que contiene el desplazamiento', () {
      final doc = parse('<p>Hola</p><p>mundo</p>');

      expect(doc.blockAt(0)!.text, 'Hola');
      expect(doc.blockAt(3)!.text, 'Hola');
      expect(doc.blockAt(4)!.text, 'mundo');
    });
  });

  group('imágenes', () {
    test('ocupan un carácter y resuelven la ruta contra el documento', () {
      final doc = parse(
        '<p>Antes</p><img src="../images/cover.jpg" alt="Portada"/>',
      );

      final image = doc.blocks.firstWhere((b) => b.kind == BlockKind.image);
      expect(image.src, 'OEBPS/images/cover.jpg');
      expect(image.alt, 'Portada');
      expect(image.end - image.start, 1);
      expect(doc.text.substring(image.start, image.end), objectReplacement);
    });

    test('la imagen dentro de un svg se reconoce', () {
      final doc = parse(
        '<div class="cubierta"><svg viewBox="0 0 600 800">'
        '<image xlink:href="../images/portada.png"/></svg></div>',
      );

      final image = doc.blocks.single;
      expect(image.kind, BlockKind.image);
      expect(image.src, 'OEBPS/images/portada.png');
    });

    test('las rutas con escapes se decodifican', () {
      final doc = parse('<img src="../im%C3%A1genes/uno.jpg"/>');

      expect(doc.blocks.single.src, 'OEBPS/imágenes/uno.jpg');
    });

    test('las fuentes remotas y data: se dejan intactas', () {
      final doc = parse('<img src="data:image/png;base64,AAAA"/>');

      expect(doc.blocks.single.src, 'data:image/png;base64,AAAA');
    });
  });

  group('listas', () {
    test('numeran y anidan', () {
      final doc = parse(
        '<ol><li>Uno</li><li>Dos<ul><li>Anidado</li></ul></li></ol>',
      );

      final items = doc.blocks
          .where((b) => b.kind == BlockKind.listItem)
          .toList();
      expect(items.map((b) => b.text), ['Uno', 'Dos', 'Anidado']);
      expect(items[0].listIndex, 1);
      expect(items[0].listOrdered, isTrue);
      expect(items[1].listIndex, 2);
      expect(items[2].level, 2);
      expect(items[2].listOrdered, isFalse);
    });
  });

  group('alineación', () {
    test('se lee del estilo en línea y del atributo align', () {
      final doc = parse(
        '<p style="text-align: center">Centrado</p>'
        '<p align="right">Derecha</p>'
        '<p>Normal</p>',
      );

      expect(doc.blocks[0].align, BlockAlign.center);
      expect(doc.blocks[1].align, BlockAlign.end);
      expect(doc.blocks[2].align, BlockAlign.start);
    });

    test('se hereda del contenedor', () {
      final doc = parse('<div style="text-align:center"><p>Hola</p></div>');

      expect(doc.blocks.single.align, BlockAlign.center);
    });
  });

  group('entrada real', () {
    test('script, style y head se ignoran', () {
      final doc = EpubDocumentParser.parse(
        '<html><head><title>Título</title><style>p{color:red}</style></head>'
        '<body><script>var x = 1;</script><p>Texto</p></body></html>',
        spineIndex: 0,
        href: 'a.xhtml',
      );

      expect(doc.blocks.map((b) => b.text), ['Texto']);
    });

    test('las entidades se resuelven', () {
      final doc = parse('<p>caf&#233; &amp; t&eacute;</p>');

      expect(doc.blocks.single.text, 'café & té');
    });

    test('el marcado mal cerrado no rompe el análisis', () {
      final doc = parse('<p>Uno<p>Dos<em>tres</p>');

      expect(doc.blocks.map((b) => b.text), ['Uno', 'Dostres']);
    });

    test('parseBytes acepta UTF-8 con BOM', () {
      final bytes = Uint8List.fromList([
        0xEF,
        0xBB,
        0xBF,
        ...utf8.encode('<html><body><p>Añejo</p></body></html>'),
      ]);

      final doc = EpubDocumentParser.parseBytes(
        bytes,
        spineIndex: 1,
        href: 'a.xhtml',
      );

      expect(doc.blocks.single.text, 'Añejo');
    });

    test('un documento vacío no produce bloques', () {
      final doc = parse('   \n  ');

      expect(doc.blocks, isEmpty);
      expect(doc.length, 0);
      expect(doc.blockAt(0), isNull);
    });
  });
}
