import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:energy_clock/features/clock/widgets/event_detail_sheet.dart';
import 'package:energy_clock/features/projects/providers.dart';
import 'package:energy_clock/shared/widgets/app_button.dart';
import 'package:energy_clock/shared/widgets/tone_chip.dart';
import 'package:flutter/cupertino.dart';
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
    double textScale = 1,
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
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

  testWidgets('shows a tone chip, the title, the range and the duration', (
    tester,
  ) async {
    await openSheet(tester, await seed());

    expect(find.byType(ToneChip), findsOneWidget);
    expect(find.text('Deep work'), findsOneWidget);
    expect(find.text('09:00 – 12:00'), findsOneWidget);
    expect(find.text('3h'), findsOneWidget);
  });

  testWidgets('has a drag handle and is capped at 560 pt wide', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openSheet(tester, await seed());
    expect(
      tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle,
      isTrue,
    );
    // The BottomSheet widget fills the width; the surface inside it is capped.
    final surface = find
        .descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Material),
        )
        .first;
    expect(tester.getSize(surface).width, 560);
  });

  testWidgets('Edit is a secondary button and Delete is destructive', (
    tester,
  ) async {
    await openSheet(tester, await seed());

    expect(
      tester
          .widget<AppButton>(find.widgetWithText(AppButton, Strings.edit))
          .variant,
      AppButtonVariant.secondary,
    );
    expect(
      tester
          .widget<AppButton>(find.widgetWithText(AppButton, Strings.delete))
          .variant,
      AppButtonVariant.destructive,
    );
  });

  testWidgets('a read-only day shows the details but no buttons', (
    tester,
  ) async {
    await openSheet(tester, await seed(), readOnly: true);
    expect(find.text('Deep work'), findsOneWidget);
    expect(find.byType(AppButton), findsNothing);
  });

  testWidgets(
    'deleting closes the sheet and removes the event',
    (tester) async {
      await openSheet(tester, await seed());

      await tester.tap(find.text(Strings.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, Strings.delete));
      await tester.pumpAndSettle();

      expect(await repository.eventsForDay(day), isEmpty);
      expect(find.byType(EventDetailSheet), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'on iOS the delete confirmation is the native alert',
    (tester) async {
      await openSheet(tester, await seed());

      await tester.tap(find.text(Strings.delete));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      await tester.tap(
        find.widgetWithText(CupertinoDialogAction, Strings.delete),
      );
      await tester.pumpAndSettle();
      expect(await repository.eventsForDay(day), isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('Edit closes the sheet and opens the editor for the same event', (
    tester,
  ) async {
    await openSheet(tester, await seed());

    await tester.tap(find.text(Strings.edit));
    await tester.pumpAndSettle();

    expect(find.byType(EventDetailSheet), findsNothing);
    expect(find.text(Strings.editEvent), findsOneWidget);
    // Not find.text: the field's hint is also 'Deep work' and stays in the tree.
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'Deep work',
    );
  });

  testWidgets('scrolls instead of overflowing on a short window at double '
      'text size', (tester) async {
    tester.view.physicalSize = const Size(375, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openSheet(tester, await seed(), textScale: 2);
    expect(tester.takeException(), isNull);
  });
}
