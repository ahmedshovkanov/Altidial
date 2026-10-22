import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/event_detail_sheet.dart';
import 'package:energy_clock/features/clock/widgets/now_card.dart';
import 'package:energy_clock/features/clock/widgets/start_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  final today = DateTime(2026, 10, 7);
  final now = DateTime(2026, 10, 7, 10, 30);

  CalendarEvent event({
    DateTime? date,
    EventStatus status = EventStatus.planned,
  }) => CalendarEvent(
    id: 1,
    seriesId: null,
    date: date ?? today,
    title: 'Deep work',
    tone: Tone.focus,
    range: const MinuteRange(540, 720),
    status: status,
  );

  group('canStartSession', () {
    test('a planned event today can be started', () {
      expect(canStartSession(event(), now), isTrue);
    });

    test('an event that is already done cannot', () {
      expect(
        canStartSession(event(status: EventStatus.completed), now),
        isFalse,
      );
    });

    test('a skipped event cannot', () {
      expect(canStartSession(event(status: EventStatus.skipped), now), isFalse);
    });

    test('a future day cannot', () {
      expect(canStartSession(event(date: DateTime(2026, 10, 8)), now), isFalse);
    });

    test('a past day cannot', () {
      expect(canStartSession(event(date: DateTime(2026, 10, 6)), now), isFalse);
    });

    test('uses the given time, so late on the day still counts as today', () {
      expect(canStartSession(event(), DateTime(2026, 10, 7, 23, 59)), isTrue);
      expect(canStartSession(event(), DateTime(2026, 10, 8, 0, 1)), isFalse);
    });
  });

  group('the Now card', () {
    late ClockHarness harness;
    CalendarEvent? opened;
    CalendarEvent? started;

    setUp(() {
      harness = ClockHarness(); // Wednesday 7 October 2026, 10:30
      opened = null;
      started = null;
    });

    tearDown(() {
      harness.dispose();
    });

    Future<int> add(
      String title,
      int start,
      int end, {
      Tone tone = Tone.focus,
    }) => harness.repository.createEvent(
      day: today,
      title: title,
      tone: tone,
      range: MinuteRange(start, end),
    );

    Future<void> show(
      WidgetTester tester, {
      bool compact = false,
      bool withStart = true,
    }) async {
      await tester.pumpWidget(
        harness.app(
          UnconstrainedBox(
            constrainedAxis: Axis.horizontal,
            alignment: Alignment.topCenter,
            child: NowCard(
              compact: compact,
              onOpenEvent: (e) => opened = e,
              onStartSession: withStart ? (e) => started = e : null,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('a running event has a Start button that starts it', (
      tester,
    ) async {
      final id = await add('Deep work', 540, 720);
      await show(tester);

      expect(find.text(Strings.sessionStartShort), findsOneWidget);
      await tester.tap(find.text(Strings.sessionStartShort));

      expect(started?.id, id);
      expect(opened, isNull);
    });

    testWidgets('tapping the rest of the card still opens the details', (
      tester,
    ) async {
      final id = await add('Deep work', 540, 720);
      await show(tester);

      await tester.tap(find.text('Deep work'));

      expect(opened?.id, id);
      expect(started, isNull);
    });

    testWidgets('the next event has one too', (tester) async {
      final id = await add('Lunch walk', 750, 795, tone: Tone.life);
      await show(tester);

      await tester.tap(find.text(Strings.sessionStartShort));

      expect(started?.id, id);
    });

    testWidgets('the button is at least 44 points tall', (tester) async {
      await add('Deep work', 540, 720);
      await show(tester);

      final size = tester.getSize(
        find
            .ancestor(
              of: find.text(Strings.sessionStartShort),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('without a callback there is no button', (tester) async {
      await add('Deep work', 540, 720);
      await show(tester, withStart: false);

      expect(find.text(Strings.sessionStartShort), findsNothing);
    });

    testWidgets('the one-row card leaves it out', (tester) async {
      await add('Deep work', 540, 720);
      await show(tester, compact: true);

      expect(find.text(Strings.sessionStartShort), findsNothing);
    });

    testWidgets('an event whose session is finished says Done instead', (
      tester,
    ) async {
      final id = await add('Deep work', 540, 720);
      harness.repository.setStatus(id, EventStatus.completed);
      await show(tester);

      expect(find.text(Strings.sessionStartShort), findsNothing);
      expect(find.text(Strings.sessionDone), findsOneWidget);
    });

    testWidgets('a future day has no Start button', (tester) async {
      harness.container
          .read(selectedDateProvider.notifier)
          .select(DateTime(2026, 10, 8));
      await add('Deep work', 540, 720);
      await show(tester);

      expect(find.text(Strings.sessionStartShort), findsNothing);
    });

    testWidgets('VoiceOver gets a Start session action', (tester) async {
      final handle = tester.ensureSemantics();
      final id = await add('Deep work', 540, 720);
      await show(tester);

      final node = find.semantics.byLabel(RegExp('^Now:'));
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('^Now:'))),
        matchesSemantics(
          label: 'Now: Deep work, Focus, 1 hour 30 minutes left',
          isButton: true,
          hasTapAction: true,
          customActions: const [
            CustomSemanticsAction(label: Strings.sessionStart),
          ],
        ),
      );

      tester.semantics.performAction(
        node,
        SemanticsAction.customAction,
        args: CustomSemanticsAction.getIdentifier(
          const CustomSemanticsAction(label: Strings.sessionStart),
        ),
      );
      expect(started?.id, id);
      handle.dispose();
    });

    testWidgets('a completed event is spoken as completed', (tester) async {
      final handle = tester.ensureSemantics();
      final id = await add('Deep work', 540, 720);
      harness.repository.setStatus(id, EventStatus.completed);
      await show(tester);

      expect(
        find.bySemanticsLabel(RegExp('^Now: Deep work.*, completed\$')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('the detail sheet', () {
    late ClockHarness harness;

    setUp(() {
      harness = ClockHarness();
    });

    tearDown(() {
      harness.dispose();
    });

    Future<CalendarEvent> seed({
      DateTime? day,
      EventStatus status = EventStatus.planned,
    }) async {
      final id = await harness.repository.createEvent(
        day: day ?? today,
        title: 'Deep work',
        tone: Tone.focus,
        range: const MinuteRange(540, 720),
      );
      if (status != EventStatus.planned) {
        harness.repository.setStatus(id, status);
      }
      return harness.repository.eventById(id)!;
    }

    Future<void> open(
      WidgetTester tester,
      CalendarEvent event, {
      bool readOnly = false,
    }) async {
      await tester.pumpWidget(
        harness.app(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => EventDetailSheet.show(
                context,
                event: event,
                readOnly: readOnly,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets("today's planned event can be started from the sheet", (
      tester,
    ) async {
      final event = await seed();
      await open(tester, event);

      await tester.tap(find.byKey(const ValueKey('detail-start-session')));
      await tester.pumpAndSettle();

      expect(harness.sessions.running?.eventId, event.id);
      expect(find.byType(EventDetailSheet), findsNothing);
    });

    testWidgets('Start sits above Edit', (tester) async {
      await open(tester, await seed());

      final start = tester.getTopLeft(find.text(Strings.sessionStart)).dy;
      final edit = tester.getTopLeft(find.text(Strings.edit)).dy;
      expect(start, lessThan(edit));
    });

    testWidgets('a future day has no Start button', (tester) async {
      await open(tester, await seed(day: DateTime(2026, 10, 8)));
      expect(find.text(Strings.sessionStart), findsNothing);
    });

    testWidgets('a read-only sheet has none either', (tester) async {
      await open(tester, await seed(), readOnly: true);
      expect(find.text(Strings.sessionStart), findsNothing);
    });

    testWidgets('a finished event shows Completed and no Start', (
      tester,
    ) async {
      await open(tester, await seed(status: EventStatus.completed));

      expect(find.text(Strings.eventCompleted), findsOneWidget);
      expect(find.text(Strings.sessionStart), findsNothing);
    });

    testWidgets('while another session runs the sheet says so', (tester) async {
      final event = await seed();
      final other = await harness.repository.createEvent(
        day: today,
        title: 'Email',
        tone: Tone.inbox,
        range: const MinuteRange(900, 930),
      );
      await harness.sessions.start(eventId: other);
      await open(tester, event);

      await tester.tap(find.byKey(const ValueKey('detail-start-session')));
      await tester.pumpAndSettle();

      expect(find.text(Strings.sessionAlreadyRunning), findsOneWidget);
    });
  });
}
