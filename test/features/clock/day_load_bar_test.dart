import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/widgets/day_load_bar.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> add(Tone tone, int start, int end) =>
      harness.repository.createEvent(
        day: DateTime(2026, 10, 7),
        title: 'Event',
        tone: tone,
        range: MinuteRange(start, end),
      );

  Future<void> show(WidgetTester tester, {double textScale = 1}) async {
    await tester.pumpWidget(
      harness.app(const DayLoadBar(), textScale: textScale),
    );
    await tester.pump();
  }

  testWidgets('is hidden when the day has no events', (tester) async {
    await show(tester);
    expect(find.byType(AppCard), findsNothing);
  });

  testWidgets('lists each tone with its time, and the total', (tester) async {
    await add(Tone.focus, 540, 660); // 2h
    await add(Tone.life, 720, 780); // 1h
    await add(Tone.focus, 900, 1020); // 2h
    await show(tester);

    expect(find.text('Focus 4h'), findsOneWidget);
    expect(find.text('Life 1h'), findsOneWidget);
    expect(find.text('Inbox 0m'), findsNothing);
    expect(find.textContaining('Inbox'), findsNothing);
    expect(find.text('5h planned'), findsOneWidget);
  });

  testWidgets('the segments are proportional to the planned time', (
    tester,
  ) async {
    await add(Tone.focus, 0, 240); // 4h
    await add(Tone.life, 300, 360); // 1h
    await show(tester);

    final focus = tester
        .getSize(find.byKey(const ValueKey('load-focus')))
        .width;
    final life = tester.getSize(find.byKey(const ValueKey('load-life'))).width;
    expect(focus / life, closeTo(4, 0.1));
    expect(find.byKey(const ValueKey('load-inbox')), findsNothing);
  });

  testWidgets('a tiny segment stays visible', (tester) async {
    await add(Tone.focus, 0, 720); // 12h
    await add(Tone.inbox, 800, 815); // 15m
    await show(tester);

    expect(
      tester.getSize(find.byKey(const ValueKey('load-inbox'))).width,
      greaterThanOrEqualTo(8),
    );
  });

  testWidgets('overlapping events count twice', (tester) async {
    await add(Tone.focus, 540, 600);
    await add(Tone.life, 540, 600);
    await show(tester);
    expect(find.text('2h planned'), findsOneWidget);
  });

  testWidgets('reads as one sentence for a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await add(Tone.focus, 540, 780); // 4h
    await add(Tone.life, 800, 860); // 1h
    await show(tester);

    expect(
      find.semantics.byLabel('Planned load: Focus 4 hours, Life 1 hour'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('does not overflow on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await add(Tone.focus, 0, 240);
    await add(Tone.life, 300, 360);
    await add(Tone.inbox, 400, 460);
    await show(tester);
    expect(tester.takeException(), isNull);
  });

  test('height budget', () {
    expect(DayLoadBar.height, 68);
  });
}
