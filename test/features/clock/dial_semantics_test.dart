import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/geometry/dial_geometry.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/dial_semantics.dart';
import 'package:energy_clock/features/clock/widgets/dial_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/dial_pump.dart';
import '../../support/fake_clock.dart';

final DateTime today = DateTime(2026, 10, 3);

CalendarEvent event(int id, String title, MinuteRange range, Tone tone) =>
    CalendarEvent(
      id: id,
      seriesId: null,
      date: today,
      title: title,
      tone: tone,
      range: range,
      status: EventStatus.planned,
    );

Widget harness({
  required List<CalendarEvent> events,
  bool readOnly = false,
  void Function(CalendarEvent)? onTapped,
  void Function(CalendarEvent)? onEdit,
  void Function(CalendarEvent)? onDelete,
}) {
  return ProviderScope(
    overrides: [
      clockProvider.overrideWith(
        () => FakeClock(DateTime(2026, 10, 3, 10, 30)),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
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
              onEventTapped: onTapped,
              onEditRequested: onEdit,
              onDeleteRequested: onDelete,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  final deepWork = event(
    1,
    'Deep work',
    const MinuteRange(540, 660),
    Tone.focus,
  );
  final lunch = event(2, 'Lunch', const MinuteRange(750, 810), Tone.life);

  testWidgets('the dial is a labelled group', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(harness(events: [deepWork]));
    await pumpDial(tester);

    expect(find.semantics.byLabel(Strings.dialSemanticsLabel), findsOneWidget);
    handle.dispose();
  });

  testWidgets('each event reads as one sentence', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      harness(events: [deepWork, lunch], onTapped: (_) {}),
    );
    await pumpDial(tester);

    expect(
      find.semantics.byLabel('Deep work, Focus, 09:00 to 11:00, 2 hours'),
      findsOneWidget,
    );
    expect(
      find.semantics.byLabel('Lunch, Life, 12:30 to 13:30, 1 hour'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('an editable day offers open, edit and delete', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      harness(
        events: [deepWork],
        onTapped: (_) {},
        onEdit: (_) {},
        onDelete: (_) {},
      ),
    );
    await pumpDial(tester);

    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp('Deep work'))),
      matchesSemantics(
        label: 'Deep work, Focus, 09:00 to 11:00, 2 hours',
        isButton: true,
        hasTapAction: true,
        customActions: const [
          DialSemantics.editAction,
          DialSemantics.deleteAction,
        ],
      ),
    );
    handle.dispose();
  });

  testWidgets('a read-only day offers open only', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      harness(
        events: [deepWork],
        readOnly: true,
        onTapped: (_) {},
        onEdit: (_) {},
        onDelete: (_) {},
      ),
    );
    await pumpDial(tester);

    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp('Deep work'))),
      matchesSemantics(
        label: 'Deep work, Focus, 09:00 to 11:00, 2 hours',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('the actions call back with the event', (tester) async {
    final handle = tester.ensureSemantics();
    CalendarEvent? opened;
    CalendarEvent? edited;
    CalendarEvent? deleted;
    await tester.pumpWidget(
      harness(
        events: [deepWork],
        onTapped: (e) => opened = e,
        onEdit: (e) => edited = e,
        onDelete: (e) => deleted = e,
      ),
    );
    await pumpDial(tester);

    final node = find.semantics.byLabel(RegExp('Deep work'));
    tester.semantics.tap(node);
    expect(opened, deepWork);

    tester.semantics.performAction(
      node,
      SemanticsAction.customAction,
      args: CustomSemanticsAction.getIdentifier(DialSemantics.editAction),
    );
    expect(edited, deepWork);

    tester.semantics.performAction(
      node,
      SemanticsAction.customAction,
      args: CustomSemanticsAction.getIdentifier(DialSemantics.deleteAction),
    );
    expect(deleted, deepWork);
    handle.dispose();
  });

  testWidgets('the nodes follow their arcs', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(harness(events: [deepWork], onTapped: (_) {}));
    await pumpDial(tester);

    final geometry = DialGeometry.fitted(const Size(390, 390), ringCount: 1);
    // The Semantics widget sits exactly where its node is, so its global rect
    // is the node's footprint on screen.
    final nodeRect = tester.getRect(find.bySemanticsLabel(RegExp('Deep work')));
    final dialTopLeft = tester.getTopLeft(find.byType(DialView));
    final arcMiddle =
        dialTopLeft +
        geometry.pointOnCircle(
          geometry.ringCenterRadius(0),
          geometry.angleForMinute(600),
        );
    expect(nodeRect.contains(arcMiddle), isTrue);
    handle.dispose();
  });

  testWidgets('the overlay lets touches through to the dial', (tester) async {
    CalendarEvent? tapped;
    await tester.pumpWidget(
      harness(events: [deepWork], onTapped: (e) => tapped = e),
    );
    await pumpDial(tester);

    final geometry = DialGeometry.fitted(const Size(390, 390), ringCount: 1);
    final centre = tester.getCenter(find.byType(DialView));
    final spot = geometry.pointOnCircle(
      geometry.ringCenterRadius(0),
      geometry.angleForMinute(600),
    );
    await tester.tapAt(centre + (spot - geometry.center));
    await pumpDial(tester);
    expect(tapped, deepWork);
  });
}
