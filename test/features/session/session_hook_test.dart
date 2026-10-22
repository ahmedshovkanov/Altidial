import 'package:energy_clock/app/navigation/clock_tab.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';
import '../../support/dial_pump.dart';

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  /// Creates a 30-minute focus event.
  Future<int> createEvent() async {
    return harness.repository.createEvent(
      day: DateTime(2026, 10, 7),
      title: 'Deep work',
      tone: Tone.focus,
      range: const MinuteRange(600, 630),
    );
  }

  /// Starts a session on [eventId] and pumps until the SessionScreen appears.
  Future<void> startAndShowSession(WidgetTester tester, int eventId) async {
    await harness.sessions.start(eventId: eventId);
    await pumpDial(tester);
  }

  /// Pumps the app showing the Clock tab, then starts a session.
  Future<void> showClockThenStart(WidgetTester tester, int eventId) async {
    await tester.pumpWidget(harness.app(const ClockTab()));
    await pumpDial(tester);
    await startAndShowSession(tester, eventId);
  }

  testWidgets('finishing advances progress for the event day', (tester) async {
    final eventId = await createEvent();
    await showClockThenStart(tester, eventId);

    await tester.tap(find.byKey(const ValueKey('session-finish')));
    await pumpDial(tester);

    expect(harness.sessions.ended, hasLength(1));
    expect(harness.progress.endedDates, [DateTime(2026, 10, 7)]);
  });

  testWidgets('abandoning advances progress too', (tester) async {
    final eventId = await createEvent();
    await showClockThenStart(tester, eventId);

    await tester.tap(find.byKey(const ValueKey('session-abandon')));
    await pumpDial(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, Strings.sessionAbandon),
      ),
    );
    await pumpDial(tester);

    expect(harness.sessions.ended, hasLength(1));
    expect(harness.progress.endedDates, [DateTime(2026, 10, 7)]);
  });

  testWidgets('a failing progress update still ends the session', (
    tester,
  ) async {
    harness.progress.failOnSessionEnded = true;
    final eventId = await createEvent();
    await showClockThenStart(tester, eventId);

    await tester.tap(find.byKey(const ValueKey('session-finish')));
    await pumpDial(tester);

    expect(harness.sessions.ended, hasLength(1));
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
