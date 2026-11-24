// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/local/app_database.dart';
import 'package:lanna/data/models/book_format.dart';
import 'package:lanna/features/library/widgets/book_grid.dart';
import 'package:lanna/l10n/app_localizations.dart';

class _SmallTextGrows extends TextScaler {
  const _SmallTextGrows();

  @override
  double scale(double fontSize) => fontSize * 1.3 + 3;

  @override
  double get textScaleFactor => 1.3;

  @override
  TextScaler clamp({
    double minScaleFactor = 0,
    double maxScaleFactor = double.infinity,
  }) => this;
}

Book _book(int i) => Book(
  id: 'b$i',
  title: 'Un título bastante largo para ocupar dos líneas completas $i',
  author: 'Autora con un nombre también largo',
  filePath: '/l/$i.epub',
  format: i.isEven ? BookFormat.epub : BookFormat.pdf,
  available: true,
  hidden: false,
  addedAt: DateTime(2026),
  readingDirection: null,
  favoritedAt: i % 3 == 0 ? DateTime(2026) : null,
  series: null,
  coverPath: null,
  fileSizeBytes: null,
  contentHash: null,
  folderId: null,
  relativePath: null,
  fileModified: null,
  lastOpenedAt: null,
  finishedAt: null,
);

void main() {
  for (final (name, scaler) in const [
    ('sin escalar', TextScaler.noScaling),
    ('al 150 %', TextScaler.linear(1.5)),
    ('con escalado no lineal', _SmallTextGrows()),
  ]) {
    for (final width in const [400.0, 900.0, 1600.0]) {
      testWidgets('la grilla no desborda $name a ${width.toInt()} px', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('es'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: scaler),
              child: child!,
            ),
            home: Scaffold(
              body: CustomScrollView(
                slivers: [
                  BookGridSliver(
                    books: [for (var i = 0; i < 12; i++) _book(i)],
                    onMenu: (_, _) {},
                    progress: const {'b0': 0.4, 'b1': 0.8},
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  test('el alto del texto crece con el escalado del sistema', () {
    final plain = tileTextExtent(TextScaler.noScaling);
    expect(tileTextExtent(const TextScaler.linear(1.5)), greaterThan(plain));
    expect(tileTextExtent(const _SmallTextGrows()), greaterThan(plain));
  });
}
