// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/epub/epub_fonts.dart';

void main() {
  test('lee una familia con sus variantes', () {
    final sheet = EpubFonts.parse({
      'OEBPS/Styles/stylesheet.css': '''
        @font-face {
          font-family: "Bitter";
          src: url(../Fonts/Bitter-Regular.ttf);
        }
        @font-face {
          font-family: "Bitter";
          font-weight: bold;
          src: url(../Fonts/Bitter-Bold.ttf);
        }
        @font-face {
          font-family: 'Bitter';
          font-style: italic;
          src: url("../Fonts/Bitter-Italic.otf");
        }
      ''',
    });

    expect(sheet.faces, hasLength(3));
    expect(sheet.families, {'Bitter'});
    expect(sheet.preferred, 'Bitter');
    expect(sheet.faces[0].href, 'OEBPS/Fonts/Bitter-Regular.ttf');
    expect(sheet.faces[1].weight, 700);
    expect(sheet.faces[2].italic, isTrue);
    expect(sheet.faces[2].href, 'OEBPS/Fonts/Bitter-Italic.otf');
  });

  test('prefiere la familia que el libro usa para el cuerpo', () {
    final sheet = EpubFonts.parse({
      'st.css': '''
        @font-face { font-family: "Titulos"; src: url(t.ttf); }
        @font-face { font-family: "Cuerpo"; src: url(c.ttf); }
        @font-face { font-family: "Cuerpo"; font-weight: 700; src: url(cb.ttf); }
        h1, h2 { font-family: "Titulos"; }
        body { font-family: "Cuerpo", Georgia, serif; }
      ''',
    });

    expect(sheet.preferred, 'Cuerpo');
  });

  test('sin regla de cuerpo se queda con la de más variantes', () {
    final sheet = EpubFonts.parse({
      'st.css': '''
        @font-face { font-family: "Rara"; src: url(r.ttf); }
        @font-face { font-family: "Comun"; src: url(a.ttf); }
        @font-face { font-family: "Comun"; font-weight: 700; src: url(b.ttf); }
      ''',
    });

    expect(sheet.preferred, 'Comun');
  });

  test('ignora formatos que Flutter no sabe cargar', () {
    final sheet = EpubFonts.parse({
      'st.css': '''
        @font-face {
          font-family: "SoloWoff";
          src: url(a.woff2) format("woff2"), url(a.woff) format("woff");
        }
        @font-face {
          font-family: "Mixta";
          src: url(b.woff2) format("woff2"), url(b.otf) format("opentype");
        }
      ''',
    });

    expect(sheet.families, {'Mixta'});
    expect(sheet.faces.single.href, 'b.otf');
  });

  test('ignora fuentes incrustadas como data URI', () {
    final sheet = EpubFonts.parse({
      'st.css':
          '@font-face { font-family: "X"; src: url(data:font/ttf;base64,AA); }',
    });

    expect(sheet.isEmpty, isTrue);
    expect(sheet.preferred, isNull);
  });

  test('una familia genérica en body no cuenta como preferida', () {
    final sheet = EpubFonts.parse({
      'st.css': '''
        @font-face { font-family: "Real"; src: url(r.ttf); }
        body { font-family: serif; }
      ''',
    });

    expect(sheet.preferred, 'Real');
  });

  test('resuelve rutas con escapes y hojas en varias carpetas', () {
    final sheet = EpubFonts.parse({
      'OEBPS/css/a.css':
          '@font-face { font-family: "A"; src: url(../fuentes/a%C3%B1o.ttf); }',
      'OEBPS/otro/b.css': '@font-face { font-family: "B"; src: url(./b.ttf); }',
    });

    final hrefs = sheet.faces.map((f) => f.href).toSet();
    expect(hrefs, {'OEBPS/fuentes/año.ttf', 'OEBPS/otro/b.ttf'});
  });

  test('un CSS sin fuentes no da nada', () {
    final sheet = EpubFonts.parse({'st.css': 'body { color: red; }'});

    expect(sheet.isEmpty, isTrue);
    expect(sheet.preferred, isNull);
  });
}
