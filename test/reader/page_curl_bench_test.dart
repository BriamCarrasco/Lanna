// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/features/reader/widgets/page_curl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const size = Size(1080, 1920);

  testWidgets('coste de pintar un frame del pliegue', (tester) async {
    final image = (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF203040),
      );
      return recorder.endRecording().toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
    }))!;
    addTearDown(image.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox.fromSize(
          size: size,
          child: PageCurl(image: image, progress: 0.45, direction: 1),
        ),
      ),
    );

    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((c) => c.painter)
        .whereType<CustomPainter>()
        .first;

    await tester.runAsync(() async {
      for (var i = 0; i < 20; i++) {
        final r = ui.PictureRecorder();
        painter.paint(Canvas(r), size);
        r.endRecording().dispose();
      }

      const vueltas = 300;
      final reloj = Stopwatch()..start();
      for (var i = 0; i < vueltas; i++) {
        final r = ui.PictureRecorder();
        painter.paint(Canvas(r), size);
        r.endRecording().dispose();
      }
      reloj.stop();

      final us = reloj.elapsedMicroseconds / vueltas;
      // ignore: avoid_print
      print(
        'PLIEGUE: ${us.toStringAsFixed(1)} us por frame '
        '(presupuesto 60fps = 16666 us)',
      );
    });

    expect(true, isTrue);
  });
}
