import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/app_theme.dart';
import 'package:altidial/app/theme/tone_colors.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/features/clock/widgets/event_sheet.dart';
import 'package:altidial/features/projects/providers.dart';
import 'package:altidial/shared/widgets/app_button.dart';
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

  Future<void> openSheet(
    WidgetTester tester, {
    MinuteRange range = const MinuteRange(540, 720),
    double textScale = 1,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventRepositoryProvider.overrideWithValue(repository),
          projectListProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () =>
                    EventSheet.show(context, day: day, initialRange: range),
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

  testWidgets('has a drag handle and is capped at 560 pt wide', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openSheet(tester);
    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.showDragHandle, isTrue);
    // The BottomSheet widget fills the width; the surface inside it is capped.
    final surface = find
        .descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Material),
        )
        .first;
    expect(tester.getSize(surface).width, 560);
  });

  testWidgets('shows the start and end times and the duration', (tester) async {
    await openSheet(tester);
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
    expect(find.text('3h'), findsOneWidget);
  });

  testWidgets('the tone tiles are at least 72 pt tall, in their tone colours', (
    tester,
  ) async {
    await openSheet(tester);
    for (final tone in Tone.values) {
      final tile = find.ancestor(
        of: find.text(tone.label),
        matching: find.byWidgetPredicate(
          (w) => w is DecoratedBox && w.decoration is BoxDecoration,
        ),
      );
      expect(tester.getSize(tile.first).height, greaterThanOrEqualTo(72));
      final decoration =
          tester.widget<DecoratedBox>(tile.first).decoration as BoxDecoration;
      expect(decoration.color, ToneColors.light.fillFor(tone));
    }
  });

  testWidgets('the selected tone has an ink outline and a check', (
    tester,
  ) async {
    await openSheet(tester);
    BoxDecoration decorationFor(Tone tone) {
      final tile = find.ancestor(
        of: find.text(tone.label),
        matching: find.byWidgetPredicate(
          (w) => w is DecoratedBox && w.decoration is BoxDecoration,
        ),
      );
      return tester.widget<DecoratedBox>(tile.first).decoration
          as BoxDecoration;
    }

    // Focus is selected by default.
    expect(decorationFor(Tone.focus).border!.top.color, AppColors.light.ink);
    expect(decorationFor(Tone.focus).border!.top.width, 3);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.tap(find.text(Tone.life.label));
    await tester.pump();
    expect(decorationFor(Tone.life).border!.top.color, AppColors.light.ink);
    expect(
      decorationFor(Tone.focus).border!.top.color,
      isNot(AppColors.light.ink),
    );
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('tone tiles read as selectable buttons', (tester) async {
    final handle = tester.ensureSemantics();
    await openSheet(tester);

    expect(
      tester.getSemantics(find.bySemanticsLabel(Tone.focus.label)),
      matchesSemantics(
        label: Tone.focus.label,
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel(Tone.life.label)),
      matchesSemantics(
        label: Tone.life.label,
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('the stepper buttons are at least 44 x 44', (tester) async {
    await openSheet(tester);
    for (final label in [Strings.startLabel, Strings.endLabel]) {
      for (final tooltip in [
        Strings.stepperDecrease(label),
        Strings.stepperIncrease(label),
      ]) {
        final button = find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == tooltip,
        );
        final size = tester.getSize(button);
        expect(size.width, greaterThanOrEqualTo(44), reason: tooltip);
        expect(size.height, greaterThanOrEqualTo(44), reason: tooltip);
      }
    }
  });

  testWidgets('a stepper moves the time by five minutes', (tester) async {
    await openSheet(tester);
    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is IconButton &&
            w.tooltip == Strings.stepperIncrease(Strings.startLabel),
      ),
    );
    await tester.pump();
    expect(find.text('09:05'), findsOneWidget);
    expect(find.text('2h 55m'), findsOneWidget);
  });

  testWidgets('Save is a full-width primary button', (tester) async {
    await openSheet(tester);
    final button = find.widgetWithText(AppButton, Strings.save);
    expect(button, findsOneWidget);
    expect(tester.widget<AppButton>(button).variant, AppButtonVariant.primary);
  });

  testWidgets('edit mode is titled and prefilled', (tester) async {
    await repository.createEvent(
      day: day,
      title: 'Deep work',
      tone: Tone.inbox,
      range: const MinuteRange(540, 720),
    );
    final existing = (await repository.eventsForDay(day)).single;

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
                  initialRange: existing.range,
                  existing: existing,
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

    expect(find.text(Strings.editEvent), findsOneWidget);
    // Not find.text: the field's hint is also 'Deep work' and stays in the tree.
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'Deep work',
    );
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('scrolls instead of overflowing on a short window at double '
      'text size', (tester) async {
    tester.view.physicalSize = const Size(375, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openSheet(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });

  testWidgets('works in dark mode', (tester) async {
    await openSheet(tester, theme: AppTheme.dark);
    expect(tester.takeException(), isNull);
    expect(find.text(Strings.save), findsOneWidget);
  });
}
