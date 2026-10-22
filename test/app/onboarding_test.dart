import 'package:altidial/app/onboarding/onboarding_flow.dart';
import 'package:altidial/app/onboarding/onboarding_providers.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/shared/widgets/tone_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/clock_harness.dart';
import '../support/fake_event_repository.dart';
import '../support/fake_settings_repository.dart';

class _FailingRepository extends FakeEventRepository {
  @override
  Future<int> createEvent({
    required DateTime day,
    required String title,
    required Tone tone,
    required MinuteRange range,
    bool isFlight = false,
    String? flightNumber,
    String? fromCode,
    String? toCode,
    int? projectId,
  }) => throw StateError('disk full');
}

void main() {
  late FakeSettingsRepository settings;
  late ClockHarness harness;

  setUp(() {
    settings = FakeSettingsRepository();
    harness = ClockHarness(
      overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
    );
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> show(
    WidgetTester tester, {
    double textScale = 1,
    bool reduceMotion = false,
  }) async {
    await tester.pumpWidget(
      harness.app(
        const OnboardingFlow(),
        textScale: textScale,
        reduceMotion: reduceMotion,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.text(Strings.onboardingNext));
    await tester.pumpAndSettle();
  }

  testWidgets('starts on the intro, with Skip and Next', (tester) async {
    await show(tester);
    expect(find.text(Strings.onboardingTitle1), findsOneWidget);
    expect(find.text(Strings.onboardingBody1), findsOneWidget);
    expect(find.text(Strings.onboardingSkip), findsOneWidget);
    expect(find.text(Strings.onboardingNext), findsOneWidget);
  });

  testWidgets('the second page shows the three tones with examples', (
    tester,
  ) async {
    await show(tester);
    await next(tester);

    expect(find.text(Strings.onboardingTitle2), findsOneWidget);
    expect(find.byType(ToneChip), findsNWidgets(3));
    expect(find.text(Strings.toneExampleFocus), findsOneWidget);
    expect(find.text(Strings.toneExampleLife), findsOneWidget);
    expect(find.text(Strings.toneExampleInbox), findsOneWidget);
    expect(find.text(Strings.onboardingSkip), findsOneWidget);
  });

  testWidgets(
    'the last page offers a sample day or an empty start, and no Skip',
    (tester) async {
      await show(tester);
      await next(tester);
      await next(tester);

      expect(find.text(Strings.onboardingTitle3), findsOneWidget);
      expect(find.text(Strings.onboardingSampleDay), findsOneWidget);
      expect(find.text(Strings.onboardingStartEmpty), findsOneWidget);
      expect(find.text(Strings.onboardingNext), findsNothing);
      expect(find.text(Strings.onboardingSkip), findsNothing);
    },
  );

  testWidgets('swiping moves between pages too', (tester) async {
    await show(tester);
    // A drag past the halfway point, not a fling: a fling carries on for a
    // second page.
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text(Strings.onboardingTitle2), findsOneWidget);
  });

  testWidgets('Skip finishes without creating anything', (tester) async {
    await show(tester);
    await tester.tap(find.text(Strings.onboardingSkip));
    await tester.pumpAndSettle();

    expect(settings.values[onboardingDoneKey], isTrue);
    expect(
      await harness.repository.eventsForDay(DateTime(2026, 10, 7)),
      isEmpty,
    );
  });

  testWidgets('Start empty finishes without creating anything', (tester) async {
    await show(tester);
    await next(tester);
    await next(tester);
    await tester.tap(find.text(Strings.onboardingStartEmpty));
    await tester.pumpAndSettle();

    expect(settings.values[onboardingDoneKey], isTrue);
    expect(
      await harness.repository.eventsForDay(DateTime(2026, 10, 7)),
      isEmpty,
    );
  });

  testWidgets(
    'Start with a sample day adds four events to the clock\'s today',
    (tester) async {
      await show(tester);
      await next(tester);
      await next(tester);
      await tester.tap(find.text(Strings.onboardingSampleDay));
      await tester.pumpAndSettle();

      expect(settings.values[onboardingDoneKey], isTrue);
      final events = await harness.repository.eventsForDay(
        DateTime(2026, 10, 7),
      );
      expect(events.map((e) => e.title), [
        'Deep work',
        'Email and calls',
        'Lunch walk',
        'Writing',
      ]);
    },
  );

  testWidgets('a sample day that cannot be saved says so, and still finishes', (
    tester,
  ) async {
    final failing = _FailingRepository();
    addTearDown(failing.dispose);
    harness.dispose();
    harness = ClockHarness(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        eventRepositoryProvider.overrideWithValue(failing),
      ],
    );

    await show(tester);
    await next(tester);
    await next(tester);
    await tester.tap(find.text(Strings.onboardingSampleDay));
    await tester.pumpAndSettle();

    expect(find.text(Strings.sampleDayFailed), findsOneWidget);
    expect(settings.values[onboardingDoneKey], isTrue);
  });

  testWidgets('the buttons are disabled once one has been pressed', (
    tester,
  ) async {
    await show(tester);
    await next(tester);
    await next(tester);

    await tester.tap(find.text(Strings.onboardingSampleDay));
    await tester.pump(); // before the finish has completed
    await tester.tap(
      find.text(Strings.onboardingSampleDay),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(
      (await harness.repository.eventsForDay(DateTime(2026, 10, 7))).length,
      4,
      reason: 'a second tap must not add the sample day twice',
    );
  });

  testWidgets('with reduced motion Next jumps to the next page', (
    tester,
  ) async {
    await show(tester, reduceMotion: true);
    await tester.tap(find.text(Strings.onboardingNext));
    await tester.pump();
    expect(find.text(Strings.onboardingTitle2), findsOneWidget);
  });

  testWidgets('the page dots are announced', (tester) async {
    final handle = tester.ensureSemantics();
    await show(tester);
    expect(find.semantics.byLabel('Page 1 of 3'), findsOneWidget);
    await next(tester);
    expect(find.semantics.byLabel('Page 2 of 3'), findsOneWidget);
    handle.dispose();
  });

  for (final textScale in const [1.0, 2.0]) {
    testWidgets(
      'no page overflows on a small phone at ${textScale * 100}% text',
      (tester) async {
        tester.view.physicalSize = const Size(375, 667);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await show(tester, textScale: textScale);
        expect(tester.takeException(), isNull);
        await next(tester);
        expect(tester.takeException(), isNull);
        await next(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('on an iPad the flow is a centred column', (tester) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await show(tester);
    final width = tester.getSize(find.byType(PageView)).width;
    expect(width, 480);
  });
}
