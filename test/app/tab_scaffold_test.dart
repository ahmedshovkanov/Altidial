import 'package:energy_clock/app/navigation/tab_bar_inset.dart';
import 'package:energy_clock/app/navigation/tab_scaffold.dart';
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/calendar/calendar_screen.dart';
import 'package:energy_clock/features/clock/clock_screen.dart'
    show ClockScreen;
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/flight_deck/flight_deck_screen.dart';
import 'package:energy_clock/features/projects/projects_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';

import '../support/dial_pump.dart';
import '../support/fake_calendar_repository.dart';
import '../support/fake_event_repository.dart';
import '../support/fake_notification_service.dart';
import '../support/fake_progress_repository.dart';
import '../support/fake_roundup_repository.dart';
import '../support/fake_session_repository.dart';
import '../support/fake_settings_repository.dart';
import '../support/fake_stats_repository.dart';

void main() {
  late FakeEventRepository repository;
  late FakeSessionRepository sessions;

  setUp(() {
    repository = FakeEventRepository();
    sessions = FakeSessionRepository(events: repository, clock: DateTime.now);
  });

  tearDown(() {
    sessions.dispose();
    repository.dispose();
  });

  Widget harness() {
    return ProviderScope(
      overrides: [
        eventRepositoryProvider.overrideWithValue(repository),
        calendarRepositoryProvider.overrideWithValue(
          FakeCalendarRepository(repository),
        ),
        sessionRepositoryProvider.overrideWithValue(sessions),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        statsRepositoryProvider.overrideWithValue(FakeStatsRepository()),
        progressRepositoryProvider.overrideWithValue(FakeProgressRepository()),
        roundupRepositoryProvider.overrideWithValue(FakeRoundupRepository()),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const TabScaffold()),
    );
  }

  testWidgets('starts on Clock with five tabs', (tester) async {
    await tester.pumpWidget(harness());
    await pumpDial(tester);

    for (var i = 0; i < 5; i++) {
      expect(find.byKey(ValueKey('tab-$i')), findsOneWidget);
    }
    expect(find.byType(ClockScreen), findsOneWidget);
    expect(find.text(Strings.tabClock), findsOneWidget);
  });

  testWidgets('tapping the projects tab shows the projects hub', (tester) async {
    await tester.pumpWidget(harness());
    await pumpDial(tester);

    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await pumpDial(tester);

    expect(find.byType(ProjectsTabBody), findsOneWidget);
    expect(find.text(Strings.tabClock), findsNothing);
  });

  testWidgets('tapping the calendar tab shows the calendar', (tester) async {
    await tester.pumpWidget(harness());
    await pumpDial(tester);

    await tester.tap(find.byKey(const ValueKey('tab-2')));
    await pumpDial(tester);

    expect(find.byType(CalendarScreen), findsOneWidget);
    expect(find.text(Strings.tabCalendar), findsOneWidget);
    expect(find.text(Strings.tabStats), findsNothing);
  });

  testWidgets('tapping the profile tab shows the progress sections', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await pumpDial(tester);

    await tester.tap(find.byKey(const ValueKey('tab-3')));
    await pumpDial(tester);

    expect(find.text(Strings.profileScoreTitle), findsOneWidget);
    expect(find.text(Strings.profileScoreEmpty), findsOneWidget);
    expect(find.text(Strings.profileBadgesTitle), findsOneWidget);
  });

  testWidgets('tapping the deck tab shows the flight deck', (tester) async {
    await tester.pumpWidget(harness());
    await pumpDial(tester);

    await tester.tap(find.byKey(const ValueKey('tab-4')));
    await pumpDial(tester);

    expect(find.byType(FlightDeckScreen), findsOneWidget);
    expect(find.text(Strings.tabDeck), findsOneWidget);
  });

  testWidgets('tabs are built the first time they are visited', (tester) async {
    await tester.pumpWidget(harness());
    await pumpDial(tester);

    expect(find.byType(ProjectsTabBody), findsNothing);
    expect(find.byType(CalendarScreen), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tab-2')));
    await pumpDial(tester);
    expect(find.byType(CalendarScreen), findsOneWidget);
  });

  testWidgets('a visited tab keeps its state when you switch away and back', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await pumpDial(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TabScaffold)),
    );
    container.read(selectedDateProvider.notifier).select(DateTime(2031, 5, 4));
    await pumpDial(tester);

    await tester.tap(find.byKey(const ValueKey('tab-3')));
    await pumpDial(tester);
    await tester.tap(find.byKey(const ValueKey('tab-0')));
    await pumpDial(tester);

    expect(find.byType(ClockScreen), findsOneWidget);
    expect(container.read(selectedDateProvider), DateTime(2031, 5, 4));
  });

  testWidgets('screens receive the space the floating bar covers', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await pumpDial(tester);

    final inset = TabBarInset.of(tester.element(find.byType(ClockScreen)));
    expect(inset, greaterThanOrEqualTo(64 + 12));
  });

  testWidgets('TabBarInset.of is zero outside a tab shell', (tester) async {
    late double inset;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            inset = TabBarInset.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(inset, 0);
  });
}
