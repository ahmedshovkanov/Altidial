import 'package:altidial/app/navigation/clock_tab.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/features/clock/clock_screen.dart';
import 'package:altidial/features/session/session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/clock_harness.dart';
import '../support/dial_pump.dart';

/// The whole loop through the Clock tab: Start on the Now card, the session
/// screen, and back to the day with the event done.
void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Future<int> addEvent() => harness.repository.createEvent(
    day: DateTime(2026, 10, 7),
    title: 'Deep work',
    tone: Tone.focus,
    range: const MinuteRange(540, 720),
  );

  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(harness.app(const ClockTab()));
    await pumpDial(tester);
  }

  testWidgets('pressing Start on the Now card starts a session', (
    tester,
  ) async {
    await addEvent(); // 09:00-12:00, running at the harness's 10:30
    await show(tester);

    await tester.tap(find.text(Strings.sessionStartShort));
    await pumpDial(tester);

    expect(find.byType(SessionScreen), findsOneWidget);
    expect(find.byType(ClockScreen), findsNothing);
    expect(find.text('Deep work'), findsOneWidget);
    expect(harness.sessions.running, isNotNull);
  });

  testWidgets('finishing returns to the day, with the event done', (
    tester,
  ) async {
    await addEvent();
    await show(tester);
    await tester.tap(find.text(Strings.sessionStartShort));
    await pumpDial(tester);

    await tester.tap(find.byKey(const ValueKey('session-finish')));
    await pumpDial(tester);

    expect(find.byType(ClockScreen), findsOneWidget);
    expect(find.byType(SessionScreen), findsNothing);
    expect(find.text(Strings.sessionDone), findsOneWidget);
    expect(find.text(Strings.sessionStartShort), findsNothing);
  });
}
