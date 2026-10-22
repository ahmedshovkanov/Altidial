import 'package:altidial/features/session/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('untilNextSecond', () {
    test('waits for the next whole second', () {
      expect(
        untilNextSecond(DateTime(2026, 10, 7, 10, 0, 0, 400)),
        const Duration(milliseconds: 600),
      );
    });

    test('waits a full second when exactly on a boundary', () {
      expect(
        untilNextSecond(DateTime(2026, 10, 7, 10, 0, 5)),
        const Duration(seconds: 1),
      );
    });

    test('keeps microsecond precision', () {
      expect(
        untilNextSecond(DateTime(2026, 10, 7, 10, 0, 5, 999, 500)),
        const Duration(microseconds: 500),
      );
    });
  });

  group('SessionNowNotifier', () {
    late DateTime now;

    setUp(() {
      now = DateTime(2026, 10, 7, 10, 0, 0, 250);
    });

    Future<void> show(WidgetTester tester) {
      return tester.pumpWidget(
        ProviderScope(
          overrides: [sessionNowSourceProvider.overrideWithValue(() => now)],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) => Text(
                ref.watch(sessionNowProvider).toIso8601String(),
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('starts at the current time', (tester) async {
      await show(tester);
      expect(find.text(now.toIso8601String()), findsOneWidget);
    });

    testWidgets('ticks when the next whole second arrives, not before', (
      tester,
    ) async {
      await show(tester);
      final first = now.toIso8601String();

      now = DateTime(2026, 10, 7, 10, 0, 1, 0);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text(first), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text(now.toIso8601String()), findsOneWidget);
    });

    testWidgets('keeps ticking every second after that', (tester) async {
      await show(tester);
      await tester.pump(const Duration(milliseconds: 750));

      now = DateTime(2026, 10, 7, 10, 0, 1);
      await tester.pump(const Duration(seconds: 1));
      now = DateTime(2026, 10, 7, 10, 0, 2);
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(now.toIso8601String()), findsOneWidget);
    });

    testWidgets('refreshes at once when the app returns to the foreground', (
      tester,
    ) async {
      await show(tester);
      now = DateTime(2026, 10, 7, 11, 30, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(find.text(now.toIso8601String()), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text(now.toIso8601String()), findsOneWidget);
    });

    testWidgets('stops its timer when nothing watches it any more', (
      tester,
    ) async {
      await show(tester);
      await tester.pumpWidget(const SizedBox());
      // A timer left running would fail the test as still pending.
    });
  });
}
