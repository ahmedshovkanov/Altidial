import 'package:altidial/app/theme/app_theme.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/features/clock/data/event_repository.dart';
import 'package:altidial/features/clock/widgets/event_detail_sheet.dart';
import 'package:altidial/features/clock/widgets/event_sheet.dart';
import 'package:altidial/features/projects/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_event_repository.dart';

void main() {
  late FakeEventRepository repository;

  final day = DateTime(2026, 8, 23);

  setUp(() {
    repository = FakeEventRepository();
  });

  tearDown(() {
    repository.dispose();
  });

  Future<CalendarEvent> seed() async {
    await repository.createEvent(
      day: day,
      title: 'Deep work',
      tone: Tone.focus,
      range: const MinuteRange(540, 720),
    );
    return (await repository.eventsForDay(day)).single;
  }

  Future<void> openSheet(
    WidgetTester tester,
    CalendarEvent event, {
    bool readOnly = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventRepositoryProvider.overrideWithValue(repository),
          // The edit action opens EventSheet, which watches the project list.
          projectListProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => EventDetailSheet.show(
                  context,
                  event: event,
                  readOnly: readOnly,
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

  testWidgets('shows the title, range, and tone', (tester) async {
    await openSheet(tester, await seed());

    expect(find.text('Deep work'), findsOneWidget);
    expect(find.text('09:00 – 12:00'), findsOneWidget);
    expect(find.text(Tone.focus.label), findsOneWidget);
  });

  testWidgets('deleting asks for confirmation and then removes the event', (
    tester,
  ) async {
    await openSheet(tester, await seed());

    await tester.tap(find.text(Strings.delete));
    await tester.pumpAndSettle();
    expect(find.text(Strings.deleteConfirmTitle), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, Strings.delete),
      ),
    );
    await tester.pumpAndSettle();

    expect(await repository.eventsForDay(day), isEmpty);
  });

  testWidgets('cancelling the confirmation keeps the event', (tester) async {
    await openSheet(tester, await seed());

    await tester.tap(find.text(Strings.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.cancel));
    await tester.pumpAndSettle();

    expect(await repository.eventsForDay(day), hasLength(1));
  });

  testWidgets('a read-only day hides edit and delete', (tester) async {
    await openSheet(tester, await seed(), readOnly: true);

    expect(find.text(Strings.edit), findsNothing);
    expect(find.text(Strings.delete), findsNothing);
  });

  testWidgets('edit opens the event sheet prefilled', (tester) async {
    await openSheet(tester, await seed());

    await tester.tap(find.text(Strings.edit));
    await tester.pumpAndSettle();

    expect(find.byType(EventSheet), findsOneWidget);
    expect(find.text(Strings.editEvent), findsOneWidget);
  });
}
