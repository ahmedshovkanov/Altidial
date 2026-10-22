import 'package:altidial/app/theme/tone_colors.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/features/clock/model/calendar_event.dart';
import 'package:altidial/features/clock/widgets/todays_plan_list.dart';
import 'package:altidial/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;
  CalendarEvent? opened;

  setUp(() {
    harness = ClockHarness(); // Wednesday 7 October 2026, 10:30
    opened = null;
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> add(
    String title,
    Tone tone,
    int start,
    int end, {
    DateTime? day,
  }) => harness.repository.createEvent(
    day: day ?? DateTime(2026, 10, 7),
    title: title,
    tone: tone,
    range: MinuteRange(start, end),
  );

  Future<void> show(WidgetTester tester, {double height = 600}) async {
    await tester.pumpWidget(
      harness.app(
        SizedBox(
          width: 400,
          height: height,
          child: TodaysPlanList(onOpenEvent: (e) => opened = e),
        ),
      ),
    );
    await tester.pump();
  }

  Color? rowFill(WidgetTester tester, int id) {
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byKey(ValueKey('plan-$id')),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    return (box.decoration as ShapeDecoration).color;
  }

  testWidgets('draws nothing when the day has no events', (tester) async {
    await show(tester);
    expect(find.byType(AppCard), findsNothing);
    expect(find.text("Today's plan"), findsNothing);
  });

  testWidgets('lists the events in start order with their time and duration', (
    tester,
  ) async {
    await add('Lunch', Tone.life, 750, 795); // 12:30
    await add('Deep work', Tone.focus, 540, 720); // 09:00
    await show(tester);

    expect(find.text("Today's plan"), findsOneWidget);
    expect(find.text('Deep work'), findsOneWidget);
    expect(find.text('09:00 – 12:00 · 3h'), findsOneWidget);
    expect(find.text('12:30 – 13:15 · 45m'), findsOneWidget);

    final first = tester.getTopLeft(find.text('Deep work')).dy;
    final second = tester.getTopLeft(find.text('Lunch')).dy;
    expect(first, lessThan(second));
  });

  testWidgets('another day is titled with its weekday', (tester) async {
    harness = ClockHarness(selected: DateTime(2026, 10, 8));
    await add('Plan', Tone.focus, 540, 600, day: DateTime(2026, 10, 8));
    await show(tester);
    expect(find.text("Thursday's plan"), findsOneWidget);
    expect(find.text("Today's plan"), findsNothing);
  });

  testWidgets('the running event is tinted, the others are not', (
    tester,
  ) async {
    await add('Deep work', Tone.focus, 540, 720); // running at 10:30
    await add('Lunch', Tone.life, 750, 795);
    await show(tester);

    final events = await harness.repository.eventsForDay(DateTime(2026, 10, 7));
    final running = events.firstWhere((e) => e.title == 'Deep work').id;
    final later = events.firstWhere((e) => e.title == 'Lunch').id;

    expect(rowFill(tester, running), ToneColors.light.softFor(Tone.focus));
    expect(rowFill(tester, later), isNot(ToneColors.light.softFor(Tone.life)));
  });

  testWidgets('only the latest-started of several running events is tinted', (
    tester,
  ) async {
    await add('Long', Tone.focus, 540, 720);
    await add('Call', Tone.inbox, 600, 660);
    await show(tester);

    final events = await harness.repository.eventsForDay(DateTime(2026, 10, 7));
    final long = events.firstWhere((e) => e.title == 'Long').id;
    final call = events.firstWhere((e) => e.title == 'Call').id;
    expect(rowFill(tester, call), ToneColors.light.softFor(Tone.inbox));
    expect(rowFill(tester, long), isNot(ToneColors.light.softFor(Tone.focus)));
  });

  testWidgets('tapping a row opens that event', (tester) async {
    await add('Deep work', Tone.focus, 540, 720);
    await add('Lunch', Tone.life, 750, 795);
    await show(tester);

    await tester.tap(find.text('Lunch'));
    expect(opened?.title, 'Lunch');
  });

  testWidgets('a row reads as one sentence', (tester) async {
    final handle = tester.ensureSemantics();
    await add('Deep work', Tone.focus, 540, 720);
    await show(tester);

    expect(
      tester.getSemantics(
        find.bySemanticsLabel('Deep work, Focus, 09:00 to 12:00, 3 hours'),
      ),
      matchesSemantics(
        label: 'Deep work, Focus, 09:00 to 12:00, 3 hours',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('a long day scrolls inside its pane', (tester) async {
    for (var i = 0; i < 12; i++) {
      await add('Event $i', Tone.focus, i * 60, i * 60 + 30);
    }
    await show(tester, height: 300);

    expect(tester.takeException(), isNull);
    expect(find.byType(ListView), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
