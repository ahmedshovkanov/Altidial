import 'package:altidial/app/theme/app_theme.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/features/clock/widgets/event_sheet.dart';
import 'package:altidial/features/projects/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_event_repository.dart';

/// Finds the [IconButton] carrying the given [tooltip] text.
///
/// `find.bySemanticsLabel` does not match here: on this Flutter version
/// `Tooltip` attaches its message to `SemanticsNode.tooltip`, not
/// `SemanticsNode.label`, so the semantics-label finder never sees it.
/// Matching on the widget's `tooltip` field directly is the stable
/// equivalent. See `test/features/clock/day_header_test.dart`.
Finder iconButtonWithTooltip(String tooltip) => find.byWidgetPredicate(
  (widget) => widget is IconButton && widget.tooltip == tooltip,
);

void main() {
  late FakeEventRepository repository;

  final day = DateTime(2026, 8, 23);

  setUp(() {
    repository = FakeEventRepository();
  });

  tearDown(() {
    repository.dispose();
  });

  Future<void> openSheet(WidgetTester tester) async {
    // The Task 5 project row made the sheet taller than the default 800x600
    // window, leaving Save below the fold: pump tall like the repeat suite.
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventRepositoryProvider.overrideWithValue(repository),
          projectListProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => EventSheet.show(
                  context,
                  day: day,
                  initialRange: const MinuteRange(540, 720),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    final finder = find.text(Strings.save);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('saving without a title shows an error and writes nothing', (
    tester,
  ) async {
    await openSheet(tester);

    await tapSave(tester);

    expect(find.text(Strings.titleRequired), findsOneWidget);
    expect(await repository.eventsForDay(day), isEmpty);
  });

  testWidgets('saving with a title and tone creates the event', (tester) async {
    await openSheet(tester);

    await tester.enterText(find.byType(TextField), 'Deep work');
    await tester.tap(find.text(Tone.life.label));
    await tester.pumpAndSettle();
    await tapSave(tester);

    final events = await repository.eventsForDay(day);
    expect(events.single.title, 'Deep work');
    expect(events.single.tone, Tone.life);
    expect(events.single.range, const MinuteRange(540, 720));
  });

  testWidgets('the end stepper never drops below the minimum duration', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), 'Deep work');

    // 720 down to 540 would be 36 taps; 40 taps must still leave 15 minutes.
    for (var i = 0; i < 40; i++) {
      await tester.tap(
        iconButtonWithTooltip(Strings.stepperDecrease(Strings.endLabel)),
      );
      await tester.pump();
    }
    await tapSave(tester);

    final events = await repository.eventsForDay(day);
    expect(events.single.range, const MinuteRange(540, 555));
  });

  testWidgets('a fourth overlapping event is refused with a message', (
    tester,
  ) async {
    for (final range in const [
      MinuteRange(540, 720),
      MinuteRange(600, 660),
      MinuteRange(610, 620),
    ]) {
      await repository.createEvent(
        day: day,
        title: 'Existing',
        tone: Tone.focus,
        range: range,
      );
    }

    await openSheet(tester);
    await tester.enterText(find.byType(TextField), 'Fourth');
    await tapSave(tester);

    expect(find.text(Strings.ringOverflow), findsOneWidget);
    expect(await repository.eventsForDay(day), hasLength(3));
  });
}
