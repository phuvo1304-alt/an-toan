// Tests for lib/app/responsive.dart -- the wide-screen (desktop web) content
// constraint applied app-wide via AnToanApp's MaterialApp.builder.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:an_toan/app/responsive.dart';

const _markerKey = Key('marker');

Widget _probe() => MaterialApp(
      builder: (context, child) => ResponsiveMaxWidth(child: child!),
      home: const Scaffold(
        body: SizedBox(key: _markerKey, width: double.infinity, height: 50),
      ),
    );

void main() {
  testWidgets('at a phone width, content is unconstrained (full-bleed, '
      'unchanged from before this feature existed)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_probe());
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byKey(_markerKey)).width, 390);
  });

  testWidgets('exactly at the breakpoint, still unconstrained', (tester) async {
    tester.view.physicalSize = Size(kWideScreenBreakpoint, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_probe());
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byKey(_markerKey)).width, kWideScreenBreakpoint);
  });

  testWidgets('just above the breakpoint, content is capped at '
      'kContentMaxWidth and centered', (tester) async {
    tester.view.physicalSize = Size(kWideScreenBreakpoint + 1, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_probe());
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byKey(_markerKey)).width, kContentMaxWidth);
  });

  testWidgets('at a wide desktop width, content stays capped and centered',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_probe());
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byKey(_markerKey)).width, kContentMaxWidth);
    // Centered: equal space on both sides.
    final left = tester.getTopLeft(find.byKey(_markerKey)).dx;
    final right = 1440 - tester.getTopRight(find.byKey(_markerKey)).dx;
    expect(left, closeTo(right, 0.5));
  });
}
