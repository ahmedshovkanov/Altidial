import 'package:altidial/core/recurrence/recurrence_rule.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/features/clock/widgets/repeat_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;

  // Wednesday 7 October 2026.
  final firstDay = DateTime(2026, 10, 7);

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  /// Mounts the picker with its state held here, as the event sheet holds it,
  /// and records every change.
  Future<List<RecurrenceRule>> pump(
    WidgetTester tester, {
    RecurrenceRule rule = const RecurrenceRule.none(),
    double textScale = 1,
  }) async {
    final changes = <RecurrenceRule>[];
    await tester.pumpWidget(
      harness.app(
        StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: RepeatPicker(
              rule: rule,
              firstDay: firstDay,
              onChanged: (next) {
                changes.add(next);
                setState(() => rule = next);
              },
            ),
          ),
        ),
        textScale: textScale,
      ),
    );
    return changes;
  }

  testWidgets('shows the four kinds and no end row while not repeating', (
    tester,
  ) async {
    await pump(tester);

    for (final label in [
      Strings.repeatNever,
      Strings.repeatDaily,
      Strings.repeatWeekdays,
      Strings.repeatCustom,
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text(Strings.repeatEndsLabel), findsNothing);
    expect(find.text('M'), findsNothing);
  });

  testWidgets('the current kind reads as selected', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, rule: RecurrenceRule.weekdays());

    expect(
      tester.getSemantics(find.bySemanticsLabel(Strings.repeatWeekdays)),
      matchesSemantics(
        label: Strings.repeatWeekdays,
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel(Strings.repeatDaily)),
      matchesSemantics(
        label: Strings.repeatDaily,
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('weekday toggles are spoken as the full day name', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, rule: RecurrenceRule.custom({DateTime.wednesday}));

    expect(
      tester.getSemantics(find.byKey(const ValueKey('repeat-day-3'))),
      matchesSemantics(
        label: 'Wednesday',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('repeat-day-4'))),
      matchesSemantics(
        label: 'Thursday',
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('tapping a kind reports the rule', (tester) async {
    final changes = await pump(tester);

    await tester.tap(find.text(Strings.repeatDaily));
    await tester.pump();
    expect(changes.last, RecurrenceRule.daily());

    await tester.tap(find.text(Strings.repeatWeekdays));
    await tester.pump();
    expect(changes.last, RecurrenceRule.weekdays());

    await tester.tap(find.text(Strings.repeatNever));
    await tester.pump();
    expect(changes.last, const RecurrenceRule.none());
  });

  testWidgets('custom starts with the first day selected and shows the days', (
    tester,
  ) async {
    final changes = await pump(tester);

    await tester.tap(find.text(Strings.repeatCustom));
    await tester.pump();

    expect(changes.last, RecurrenceRule.custom({DateTime.wednesday}));
    expect(find.text('M'), findsOneWidget);
    expect(find.text('S'), findsNWidgets(2));
  });

  testWidgets('weekday toggles add and remove days', (tester) async {
    final changes = await pump(
      tester,
      rule: RecurrenceRule.custom({DateTime.wednesday}),
    );

    await tester.tap(find.byKey(const ValueKey('repeat-day-5')));
    await tester.pump();
    expect(changes.last, RecurrenceRule.custom({3, 5}));

    await tester.tap(find.byKey(const ValueKey('repeat-day-3')));
    await tester.pump();
    expect(changes.last, RecurrenceRule.custom({5}));
  });

  testWidgets('the last selected day cannot be switched off', (tester) async {
    final changes = await pump(
      tester,
      rule: RecurrenceRule.custom({DateTime.friday}),
    );

    await tester.tap(find.byKey(const ValueKey('repeat-day-5')));
    await tester.pump();

    expect(changes, isEmpty);
  });

  testWidgets('switching kind keeps the end day, switching to never drops it', (
    tester,
  ) async {
    final changes = await pump(
      tester,
      rule: RecurrenceRule.daily(until: DateTime(2026, 12, 31)),
    );

    await tester.tap(find.text(Strings.repeatWeekdays));
    await tester.pump();
    expect(
      changes.last,
      RecurrenceRule.weekdays(until: DateTime(2026, 12, 31)),
    );

    await tester.tap(find.text(Strings.repeatNever));
    await tester.pump();
    expect(changes.last, const RecurrenceRule.none());
    expect(find.text(Strings.repeatEndsLabel), findsNothing);
  });

  testWidgets('the end row appears once the event repeats', (tester) async {
    await pump(tester, rule: RecurrenceRule.daily());

    expect(find.text(Strings.repeatEndsLabel), findsOneWidget);
    expect(find.text(Strings.repeatNoEnd), findsOneWidget);
    expect(find.text(Strings.repeatEndsOnDate), findsOneWidget);
  });

  testWidgets('picking an end date reports it and shows it on the pill', (
    tester,
  ) async {
    final changes = await pump(tester, rule: RecurrenceRule.daily());

    await tester.tap(find.text(Strings.repeatEndsOnDate));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);

    // The picker opens on a month after the first day; accept it.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(changes.last, RecurrenceRule.daily(until: DateTime(2026, 11, 7)));
    expect(find.text(Strings.repeatEndsOn('7 Nov 2026')), findsOneWidget);
  });

  testWidgets('no end clears the end day', (tester) async {
    final changes = await pump(
      tester,
      rule: RecurrenceRule.daily(until: DateTime(2026, 12, 31)),
    );
    expect(find.text(Strings.repeatEndsOn('31 Dec 2026')), findsOneWidget);

    await tester.tap(find.text(Strings.repeatNoEnd));
    await tester.pump();

    expect(changes.last, RecurrenceRule.daily());
  });

  testWidgets('cancelling the date picker changes nothing', (tester) async {
    final changes = await pump(tester, rule: RecurrenceRule.daily());

    await tester.tap(find.text(Strings.repeatEndsOnDate));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(changes, isEmpty);
  });

  testWidgets('every pill and toggle is at least 44 points tall', (
    tester,
  ) async {
    await pump(tester, rule: RecurrenceRule.custom({DateTime.wednesday}));

    for (final label in [
      Strings.repeatNever,
      Strings.repeatDaily,
      Strings.repeatWeekdays,
      Strings.repeatCustom,
      Strings.repeatNoEnd,
      Strings.repeatEndsOnDate,
    ]) {
      final pill = find.ancestor(
        of: find.text(label),
        matching: find.byType(DecoratedBox),
      );
      expect(
        tester.getSize(pill.first).height,
        greaterThanOrEqualTo(44),
        reason: label,
      );
    }
    for (var weekday = 1; weekday <= 7; weekday++) {
      expect(
        tester.getSize(find.byKey(ValueKey('repeat-day-$weekday'))).height,
        greaterThanOrEqualTo(44),
      );
    }
  });

  for (final width in [320.0, 375.0, 402.0]) {
    for (final textScale in [1.0, 2.0, 3.12]) {
      testWidgets(
        'fits a ${width.toInt()} pt window at text ${(textScale * 100).toInt()}%',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await pump(
            tester,
            rule: RecurrenceRule.custom({
              DateTime.monday,
              DateTime.thursday,
            }, until: DateTime(2026, 12, 31)),
            textScale: textScale,
          );

          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
