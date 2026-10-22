// Renders the app icon master and the launch logo from the same RingMark
// painter the Clock tab icon uses.
//
// Run from the repository root:
//
//     flutter test tool/brand/generate_brand_assets.dart
//     python3 tool/brand/make_icons.py
//
// It writes `build/brand/icon-master-rgba.png` (1024 x 1024) and
// `build/brand/launch-logo-{1,2,3}x.png`. `make_icons.py` then resizes them
// into the asset catalog. (Running it under `flutter test` is only a way to get
// `dart:ui` rendering; this is a generator, not a test.)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/shared/widgets/ring_mark.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The near-black of the icon square (the light theme's `ink`).
const Color _iconBackground = Color(0xFF17141F);

Future<void> _render(
  WidgetTester tester, {
  required Widget child,
  required double logicalSize,
  required int pixels,
  required String path,
}) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: logicalSize,
            height: logicalSize,
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixels / logicalSize);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote $path (${image.width} x ${image.height})');
  });
}

void main() {
  testWidgets('generate the brand assets', (tester) async {
    final tones = ToneColors.light;
    final arcs = [tones.focus.solid, tones.life.solid, tones.inbox.solid];

    // The icon: a near-black square with the ring at 70% of its width. The
    // master is 1024 px; the alpha channel is removed by make_icons.py.
    await _render(
      tester,
      logicalSize: 512,
      pixels: 1024,
      path: 'build/brand/icon-master-rgba.png',
      child: ColoredBox(
        color: _iconBackground,
        child: Center(
          child: RingMark(colors: arcs, size: 360, strokeFraction: 0.2),
        ),
      ),
    );

    // The launch logo: the ring alone, 120 pt, with a transparent background
    // so it sits on the light or dark launch colour.
    for (final scale in [1, 2, 3]) {
      await _render(
        tester,
        logicalSize: 120,
        pixels: 120 * scale,
        path: 'build/brand/launch-logo-${scale}x.png',
        child: RingMark(colors: arcs, size: 120, strokeFraction: 0.2),
      );
    }
  });
}
