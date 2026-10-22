import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/geometry/dial_geometry.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/dial_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/dial_pump.dart';
import '../../support/fake_clock.dart';

final DateTime today = DateTime(2026, 10, 3);
final DateTime fakeNow = DateTime(2026, 10, 3, 10, 30);

CalendarEvent event(int id, MinuteRange range, Tone tone) => CalendarEvent(
  id: id,
  seriesId: null,
  date: today,
  title: 'Event $id',
  tone: tone,
  range: range,
  status: EventStatus.planned,
);

Widget harness({
  List<CalendarEvent> events = const [],
  bool readOnly = false,
  bool reduceMotion = false,
  void Function(MinuteRange)? onCreateRequested,
  void Function(CalendarEvent)? onEventTapped,
}) {
  return ProviderScope(
    overrides: [clockProvider.overrideWith(() => FakeClock(fakeNow))],
    child: MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 390,
            height: 390,
            child: DialView(
              events: events,
              day: today,
              readOnly: readOnly,
              onCreateRequested: onCreateRequested,
              onEventTapped: onEventTapped,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  const box = Size(390, 390);
  final oneRing = DialGeometry.fitted(box, ringCount: 1);
  final twoRings = DialGeometry.fitted(box, ringCount: 2);

  /// Where a touch at [radius] from the centre, straight above it, lands.
  Offset above(WidgetTester tester, double radius) =>
      tester.getCenter(find.byType(DialView)) + Offset(0, -radius);

  // NOTE on Flutter's actual gesture semantics (verified against
  // packages/flutter/lib/src/gestures/monodrag.dart in this checkout's SDK,
  // and against this widget by instrumenting it directly):
  //
  // GestureDetector's pan family is backed by PanGestureRecognizer, whose
  // internal state machine is ready -> possible -> accepted -> ready.
  // `onPanStart` fires exactly when the recognizer transitions from
  // `possible` to `accepted`. `onPanCancel` fires only when pointer tracking
  // stops while the recognizer is still `possible`; once `accepted`, the same
  // path always routes to `onPanEnd`, even for a raw PointerCancelEvent. So a
  // pan that has already called onPanStart can never subsequently invoke
  // onPanCancel — only onPanEnd. `onPanCancel` covers a touch that begins
  // inside the orbit band but is interrupted before it ever starts a drag, in
  // which case `_onPanStart` never runs and no drag field is touched.
  //
  // The tests below pin down that such a touch is inert and that the dial
  // keeps working normally for the next real gesture.

  testWidgets('a completed drag in the orbit band creates once', (
    tester,
  ) async {
    var created = 0;
    await tester.pumpWidget(harness(onCreateRequested: (_) => created++));
    await pumpDial(tester);

    final start = above(
      tester,
      oneRing.orbitInnerRadius + oneRing.ringWidth / 2,
    );
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 20));
    // A tangential (sideways) move, not a move toward the centre: with the
    // default DragStartBehavior.start, DragStartDetails.localPosition is the
    // pointer's position once the pan is *recognised* (after crossing
    // kPanSlop), not the original down position.
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 20));
    await gesture.up();
    await pumpDial(tester);

    expect(created, 1);
  });

  testWidgets('a touch that never starts a drag is cancelled cleanly and the '
      'dial keeps working', (tester) async {
    var created = 0;
    await tester.pumpWidget(harness(onCreateRequested: (_) => created++));
    await pumpDial(tester);

    final start = above(
      tester,
      oneRing.orbitInnerRadius + oneRing.ringWidth / 2,
    );
    final firstTouch = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 20));
    await firstTouch.cancel();
    await pumpDial(tester);
    expect(created, 0);

    final secondTouch = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 20));
    await secondTouch.moveBy(const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 20));
    await secondTouch.up();
    await pumpDial(tester);

    expect(created, 1);
  });

  testWidgets('a drag starting inside the face creates on the ring at the '
      'dragged angle', (tester) async {
    MinuteRange? created;
    await tester.pumpWidget(harness(onCreateRequested: (r) => created = r));
    await pumpDial(tester);

    // Inside the face of a one-ring dial: the entry still paints on the ring
    // (the usual place) but its angle follows where the user dragged.
    final gesture = await tester.startGesture(
      above(tester, oneRing.faceRadius * 0.9),
    );
    await tester.pump(const Duration(milliseconds: 20));
    await gesture.moveBy(const Offset(40, 0));
    await gesture.up();
    await pumpDial(tester);

    expect(created, isNotNull);
    // Top of the dial is minute 0: the range must be near the drag, not the
    // 09:00 default slot.
    expect(created!.start, lessThan(180));
    expect(created, isNot(const MinuteRange(540, 600)));
  });

  testWidgets('two overlapping events bring the creation band inwards', (
    tester,
  ) async {
    var created = 0;
    await tester.pumpWidget(
      harness(
        events: [
          event(1, const MinuteRange(540, 720), Tone.focus),
          event(2, const MinuteRange(600, 660), Tone.life),
        ],
        onCreateRequested: (_) => created++,
      ),
    );
    await pumpDial(tester);

    // The same spot that missed above is now in the band: the rings crowd the
    // face to a smaller size. Minute 0 (the top) has no event on it.
    final start = above(
      tester,
      twoRings.orbitInnerRadius + twoRings.ringWidth / 2,
    );
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 20));
    await gesture.moveBy(const Offset(40, 0));
    await gesture.up();
    await pumpDial(tester);

    expect(created, 1);
  });

  testWidgets('tapping an arc reports the event', (tester) async {
    CalendarEvent? tapped;
    final focus = event(1, const MinuteRange(540, 720), Tone.focus);
    await tester.pumpWidget(
      harness(events: [focus], onEventTapped: (e) => tapped = e),
    );
    await pumpDial(tester);
    await tester.pump(
      const Duration(seconds: 1),
    ); // let the arc finish sweeping

    final centre = tester.getCenter(find.byType(DialView));
    final spot = oneRing.pointOnCircle(
      oneRing.ringCenterRadius(0),
      oneRing.angleForMinute(630),
    );
    await tester.tapAt(centre + (spot - oneRing.center));
    await pumpDial(tester);

    expect(tapped, focus);
  });

  group('tap to create', () {
    testWidgets('tapping empty orbit creates at the tapped minute', (
      tester,
    ) async {
      MinuteRange? created;
      await tester.pumpWidget(harness(onCreateRequested: (r) => created = r));
      await pumpDial(tester);

      final spot = oneRing.pointOnCircle(
        oneRing.ringCenterRadius(0),
        oneRing.angleForMinute(720),
      );
      final centre = tester.getCenter(find.byType(DialView));
      await tester.tapAt(centre + (spot - oneRing.center));
      await pumpDial(tester);

      expect(created, const MinuteRange(720, 780));
    });

    testWidgets('tapping inside the face creates at the tapped minute', (
      tester,
    ) async {
      MinuteRange? created;
      await tester.pumpWidget(harness(onCreateRequested: (r) => created = r));
      await pumpDial(tester);

      final spot = oneRing.pointOnCircle(
        oneRing.faceRadius * 0.5,
        oneRing.angleForMinute(900),
      );
      final centre = tester.getCenter(find.byType(DialView));
      await tester.tapAt(centre + (spot - oneRing.center));
      await pumpDial(tester);

      expect(created, const MinuteRange(900, 960));
    });

    testWidgets('tapping an event still opens it instead of creating', (
      tester,
    ) async {
      MinuteRange? created;
      CalendarEvent? tapped;
      final focus = event(1, const MinuteRange(540, 720), Tone.focus);
      await tester.pumpWidget(
        harness(
          events: [focus],
          onCreateRequested: (r) => created = r,
          onEventTapped: (e) => tapped = e,
        ),
      );
      await pumpDial(tester);
      await tester.pump(const Duration(seconds: 1));

      final centre = tester.getCenter(find.byType(DialView));
      final spot = oneRing.pointOnCircle(
        oneRing.ringCenterRadius(0),
        oneRing.angleForMinute(630),
      );
      await tester.tapAt(centre + (spot - oneRing.center));
      await pumpDial(tester);

      expect(tapped, focus);
      expect(created, isNull);
    });

    testWidgets('tapping a read-only day creates nothing', (tester) async {
      MinuteRange? created;
      await tester.pumpWidget(
        harness(readOnly: true, onCreateRequested: (r) => created = r),
      );
      await tester.pump(const Duration(seconds: 1));

      final spot = oneRing.pointOnCircle(
        oneRing.ringCenterRadius(0),
        oneRing.angleForMinute(720),
      );
      final centre = tester.getCenter(find.byType(DialView));
      await tester.tapAt(centre + (spot - oneRing.center));
      await tester.pump(const Duration(seconds: 1));

      expect(created, isNull);
    });

    testWidgets('tapping outside the dial creates nothing', (tester) async {
      MinuteRange? created;
      await tester.pumpWidget(harness(onCreateRequested: (r) => created = r));
      await pumpDial(tester);

      final topLeft = tester.getTopLeft(find.byType(DialView));
      await tester.tapAt(topLeft + const Offset(5, 5));
      await pumpDial(tester);

      expect(created, isNull);
    });
  });

  group('the centre', () {
    testWidgets('shows the clock time', (tester) async {
      await tester.pumpWidget(harness());
      await pumpDial(tester);
      expect(find.text('10:30'), findsOneWidget);
    });

    testWidgets('names the tone of the event running now', (tester) async {
      await tester.pumpWidget(
        harness(events: [event(1, const MinuteRange(540, 720), Tone.focus)]),
      );
      await pumpDial(tester);
      expect(find.text('Focus'), findsOneWidget);
    });

    testWidgets('names no tone when nothing is running', (tester) async {
      await tester.pumpWidget(
        harness(events: [event(1, const MinuteRange(780, 840), Tone.life)]),
      );
      await pumpDial(tester);
      expect(find.text('Life'), findsNothing);
    });

    testWidgets(
      'when two events run at once the latest-started names the tone',
      (tester) async {
        await tester.pumpWidget(
          harness(
            events: [
              event(1, const MinuteRange(540, 720), Tone.focus),
              event(2, const MinuteRange(600, 660), Tone.inbox),
            ],
          ),
        );
        await pumpDial(tester);
        expect(find.text('Inbox'), findsOneWidget);
        expect(find.text('Focus'), findsNothing);
      },
    );
  });

  group('motion', () {
    testWidgets('an empty editable day pulses its hint arc', (tester) async {
      await tester.pumpWidget(harness());
      await pumpDial(tester);
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('reduced motion stops the pulse', (tester) async {
      await tester.pumpWidget(harness(reduceMotion: true));
      await pumpDial(tester);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a read-only day has no hint to pulse', (tester) async {
      await tester.pumpWidget(harness(readOnly: true));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('arcs sweep in on first paint and then settle', (tester) async {
      await tester.pumpWidget(
        harness(events: [event(1, const MinuteRange(540, 720), Tone.focus)]),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a newly created event pops in and then settles', (
      tester,
    ) async {
      final events = ValueNotifier<List<CalendarEvent>>([
        event(1, const MinuteRange(540, 720), Tone.focus),
      ]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [clockProvider.overrideWith(() => FakeClock(fakeNow))],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: ValueListenableBuilder<List<CalendarEvent>>(
                valueListenable: events,
                builder: (context, value, _) => SizedBox(
                  width: 390,
                  height: 390,
                  child: DialView(events: value, day: today, readOnly: false),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);

      events.value = [
        ...events.value,
        event(2, const MinuteRange(780, 840), Tone.life),
      ];
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets(
      'growing from one ring to two animates the face, then settles',
      (tester) async {
        final events = ValueNotifier<List<CalendarEvent>>([
          event(1, const MinuteRange(540, 720), Tone.focus),
        ]);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [clockProvider.overrideWith(() => FakeClock(fakeNow))],
            child: MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                body: ValueListenableBuilder<List<CalendarEvent>>(
                  valueListenable: events,
                  builder: (context, value, _) => SizedBox(
                    width: 390,
                    height: 390,
                    child: DialView(events: value, day: today, readOnly: false),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        events.value = [
          ...events.value,
          event(2, const MinuteRange(600, 660), Tone.life),
        ];
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.hasRunningAnimations, isTrue);
        await tester.pump(const Duration(seconds: 1));
        expect(tester.hasRunningAnimations, isFalse);
      },
    );
  });
}
