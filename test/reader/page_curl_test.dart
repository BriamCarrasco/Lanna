// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/features/reader/widgets/page_curl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ui.Image> pageImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 40, 60),
      Paint()..color = const Color(0xFF884422),
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 20, 30),
      Paint()..color = const Color(0xFFEEDDCC),
    );
    return recorder.endRecording().toImage(40, 60);
  }

  Future<PageCurlController> host(WidgetTester tester) async {
    late PageCurlController curl;
    await tester.pumpWidget(_Host(onCreate: (c) => curl = c));
    return curl;
  }

  testWidgets('el giro anima siempre que haya página de salida', (
    tester,
  ) async {
    final curl = await host(tester);
    var advanced = 0;

    final started = await curl.start(
      1,
      outgoing: pageImage,
      advance: () => advanced++,
    );

    expect(started, isTrue);
    expect(curl.busy, isTrue);
    expect(advanced, 1);
    await tester.pump();
    expect(find.byType(PageCurl), findsOneWidget);

    await tester.pumpAndSettle();
    expect(curl.busy, isFalse);
    expect(find.byType(PageCurl), findsNothing);
  });

  testWidgets('sin página de salida no anima pero tampoco se rompe', (
    tester,
  ) async {
    final curl = await host(tester);
    var advanced = 0;

    final started = await curl.start(
      1,
      outgoing: () async => null,
      advance: () => advanced++,
    );

    expect(started, isFalse);
    expect(curl.busy, isFalse);
    expect(
      advanced,
      0,
      reason: 'quien llama decide qué hacer cuando no hay animación',
    );
  });

  testWidgets('no se solapan dos giros', (tester) async {
    final curl = await host(tester);
    var advanced = 0;
    var asked = 0;

    Future<ui.Image> source() {
      asked++;
      return pageImage();
    }

    final first = curl.start(1, outgoing: source, advance: () => advanced++);
    final second = curl.start(1, outgoing: source, advance: () => advanced++);

    expect(await first, isTrue);
    expect(await second, isFalse);
    expect(advanced, 1);
    expect(asked, 1, reason: 'no se captura dos veces a la vez');
  });

  testWidgets('el arrastre completado se queda en la página nueva', (
    tester,
  ) async {
    final curl = await host(tester);
    var advanced = 0;
    var reverted = 0;

    final started = await curl.beginDrag(
      1,
      outgoing: pageImage,
      advance: () => advanced++,
      revert: () => reverted++,
    );

    expect(started, isTrue);
    expect(curl.dragging, isTrue);

    curl.updateDrag(0.6);
    await tester.pump();
    curl.endDrag(complete: true);
    await tester.pumpAndSettle();

    expect(curl.dragging, isFalse);
    expect(curl.busy, isFalse);
    expect(advanced, 1);
    expect(reverted, 0);
  });

  testWidgets('el arrastre cancelado deshace el avance', (tester) async {
    final curl = await host(tester);
    var advanced = 0;
    var reverted = 0;

    await curl.beginDrag(
      1,
      outgoing: pageImage,
      advance: () => advanced++,
      revert: () => reverted++,
    );
    curl.updateDrag(0.2);
    await tester.pump();
    curl.endDrag(complete: false);
    await tester.pumpAndSettle();

    expect(advanced, 1);
    expect(reverted, 1);
    expect(curl.busy, isFalse);
    expect(curl.dragging, isFalse);
  });

  testWidgets('updateDrag y endDrag fuera de un arrastre no hacen nada', (
    tester,
  ) async {
    final curl = await host(tester);

    curl.updateDrag(0.5);
    curl.endDrag(complete: true);

    expect(curl.busy, isFalse);
    expect(curl.dragging, isFalse);
  });

  testWidgets('el modo fundido no usa la malla del curl', (tester) async {
    final curl = await host(tester);

    await curl.start(1, outgoing: pageImage, advance: () {}, fade: true);
    await tester.pump();

    expect(find.byType(PageCurl), findsNothing);
    expect(find.byType(RawImage), findsOneWidget);

    await tester.pumpAndSettle();
    expect(curl.busy, isFalse);
  });
}

class _Host extends StatefulWidget {
  const _Host({required this.onCreate});

  final void Function(PageCurlController) onCreate;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final PageCurlController _curl = PageCurlController(
    vsync: this,
    onChange: () {
      if (mounted) setState(() {});
    },
  );

  @override
  void initState() {
    super.initState();
    widget.onCreate(_curl);
  }

  @override
  void dispose() {
    _curl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Stack(children: [const SizedBox.expand(), ?_curl.overlay()]),
  );
}
