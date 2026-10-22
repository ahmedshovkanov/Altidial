import 'package:altidial/shared/layout/content_width.dart';
import 'package:altidial/shared/layout/window_class.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('windowClassFor', () {
    test('splits at 600 and 900', () {
      expect(windowClassFor(320), WindowClass.narrow);
      expect(windowClassFor(599), WindowClass.narrow);
      expect(windowClassFor(599.9), WindowClass.narrow);
      expect(windowClassFor(600), WindowClass.medium);
      expect(windowClassFor(899), WindowClass.medium);
      expect(windowClassFor(899.9), WindowClass.medium);
      expect(windowClassFor(900), WindowClass.wide);
      expect(windowClassFor(1376), WindowClass.wide);
    });
  });

  group('ContentWidths', () {
    test('hold the specified maximum widths', () {
      expect(ContentWidths.column, 560);
      expect(ContentWidths.sheet, 560);
      expect(ContentWidths.onboarding, 480);
      expect(ContentWidths.tabBar, 480);
    });
  });

  testWidgets('context.windowClass follows the window width', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late WindowClass read;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            read = context.windowClass;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(read, WindowClass.wide);

    tester.view.physicalSize = const Size(400, 800);
    await tester.pump();
    expect(read, WindowClass.narrow);
  });

  testWidgets('ContentWidth centres its child and caps the width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: ContentWidth(
          maxWidth: 560,
          child: SizedBox(key: Key('content'), height: 40),
        ),
      ),
    );
    final box = tester.getRect(find.byKey(const Key('content')));
    expect(box.width, 560);
    expect(box.center.dx, 500);
    expect(box.top, 0);
  });

  testWidgets('ContentWidth lets a narrower window through unchanged', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: ContentWidth(
          maxWidth: 560,
          child: SizedBox(key: Key('content'), height: 40),
        ),
      ),
    );
    expect(tester.getRect(find.byKey(const Key('content'))).width, 400);
  });
}
