// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/app.dart';

void main() {
  testWidgets('arranca en la biblioteca', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LannaApp()));
    await tester.pumpAndSettle();

    expect(find.text('Lanna'), findsOneWidget);
    expect(find.text('Tu biblioteca está vacía'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
