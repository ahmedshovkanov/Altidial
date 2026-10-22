import 'dart:async';

import 'package:altidial/app/navigation/clock_tab.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/data/repositories/session_repository.dart';
import 'package:altidial/features/clock/clock_screen.dart';
import 'package:altidial/features/session/session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/clock_harness.dart';
import '../support/dial_pump.dart';
import '../support/fake_session_repository.dart';

/// A session repository whose running-session stream the test controls.
class _GatedSessions extends FakeSessionRepository {
  _GatedSessions({required super.events, required super.clock});

  final Completer<void> gate = Completer<void>();
  bool failReads = false;

  @override
  Stream<RunningSession?> watchRunning() async* {
    await gate.future;
    if (failReads) throw StateError('the sessions are unreadable');
    yield* super.watchRunning();
  }
}

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

  testWidgets('shows the day when no session is running', (tester) async {
    await show(tester);
    expect(find.byType(ClockScreen), findsOneWidget);
    expect(find.byType(SessionScreen), findsNothing);
  });

  testWidgets('shows nothing at all until the session is known', (
    tester,
  ) async {
    final gated = _GatedSessions(
      events: harness.repository,
      clock: () => harness.clock.current,
    );
    addTearDown(gated.dispose);
    final id = await addEvent();
    gated.seedRunning(eventId: id, startedAt: DateTime(2026, 10, 7, 10, 10));
    final own = ClockHarness(
      overrides: [sessionRepositoryProvider.overrideWithValue(gated)],
    );
    addTearDown(own.dispose);

    await tester.pumpWidget(own.app(const ClockTab()));
    await pumpDial(tester);
    expect(find.byType(ClockScreen), findsNothing);
    expect(find.byType(SessionScreen), findsNothing);

    gated.gate.complete();
    await pumpDial(tester);
    expect(find.byType(SessionScreen), findsOneWidget);
  });

  testWidgets('a session left running opens straight on the recovery card', (
    tester,
  ) async {
    final id = await addEvent();
    harness.sessions.seedRunning(
      eventId: id,
      startedAt: DateTime(2026, 10, 7, 10, 10),
    );

    await tester.pumpWidget(harness.app(const ClockTab()));
    // Frame by frame: the controls and the day must never show, even briefly.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byKey(const ValueKey('session-pause')), findsNothing);
      expect(find.byType(ClockScreen), findsNothing);
    }
    expect(find.text(Strings.recoveryTitle), findsOneWidget);
  });

  testWidgets('if sessions cannot be read, the day is shown', (tester) async {
    final broken = _GatedSessions(
      events: harness.repository,
      clock: () => harness.clock.current,
    )..failReads = true;
    addTearDown(broken.dispose);
    final own = ClockHarness(
      overrides: [sessionRepositoryProvider.overrideWithValue(broken)],
    );
    addTearDown(own.dispose);

    await tester.pumpWidget(own.app(const ClockTab()));
    broken.gate.complete();
    await pumpDial(tester);

    expect(find.byType(ClockScreen), findsOneWidget);
  });
}
