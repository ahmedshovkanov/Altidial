import 'package:altidial/app/theme/app_theme.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/features/clock/data/event_repository.dart';
import 'package:altidial/features/clock/widgets/delete_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_event_repository.dart';

void main() {
  late FakeEventRepository repository;
  final day = DateTime(2026, 10, 3);
  bool? result;

  setUp(() {
    repository = FakeEventRepository();
    result = null;
  });

  tearDown(() {
    repository.dispose();
  });

  Future<void> open(WidgetTester tester) async {
    await repository.createEvent(
      day: day,
      title: 'Deep work',
      tone: Tone.focus,
      range: const MinuteRange(540, 720),
    );
    final CalendarEvent event = (await repository.eventsForDay(day)).single;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [eventRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await confirmAndDeleteEvent(context, ref, event);
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'confirming deletes the event and returns true',
    (tester) async {
      await open(tester);
      expect(find.text(Strings.deleteConfirmTitle), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, Strings.delete));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(await repository.eventsForDay(day), isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'cancelling keeps the event and returns false',
    (tester) async {
      await open(tester);
      await tester.tap(find.widgetWithText(TextButton, Strings.cancel));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(await repository.eventsForDay(day), hasLength(1));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
