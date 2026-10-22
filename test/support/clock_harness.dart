import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/projects/providers.dart';
import 'package:energy_clock/features/reflections/providers.dart';
import 'package:energy_clock/features/session/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fake_calendar_repository.dart';
import 'fake_clock.dart';
import 'fake_event_repository.dart';
import 'fake_notification_service.dart';
import 'fake_reuse_repository.dart';
import 'fake_series_repository.dart';
import 'fake_progress_repository.dart';
import 'fake_roundup_repository.dart';
import 'fake_share_service.dart';
import 'fake_session_repository.dart';
import 'fake_settings_repository.dart';
import 'fake_stats_repository.dart';

/// A provider container with a fake clock, in-memory event, series, reuse,
/// calendar, session, settings and stats repositories (the series, reuse and
/// calendar fakes share the event fake's events) and a fake notification
/// service, fake progress and roundup repositories, plus
/// helpers to mount
/// a widget under it. The default clock is Wednesday 7 October 2026, 10:30, and
/// that day is selected. The one fake clock also drives the session repository
/// and the session screen's clock, so `clock.set(...)` moves everything.
/// [overrides] adds more provider overrides.
class ClockHarness {
  ClockHarness({
    DateTime? now,
    DateTime? selected,
    List<Override> overrides = const [],
  }) : clock = FakeClock(now ?? DateTime(2026, 10, 7, 10, 30)),
       repository = FakeEventRepository() {
    series = FakeSeriesRepository(repository);
    reuse = FakeReuseRepository(repository);
    calendar = FakeCalendarRepository(repository);
    sessions = FakeSessionRepository(
      events: repository,
      clock: () => clock.current,
    );
    container = ProviderContainer(
      overrides: [
        clockProvider.overrideWith(() => clock),
        eventRepositoryProvider.overrideWithValue(repository),
        // EventSheet watches the project list; default to empty so widget
        // tests never touch the real database. Tests that need projects pass
        // their own projectListProvider override via [overrides].
        projectListProvider.overrideWith((ref) => Stream.value([])),
        // Stats shows the energy patterns card, which derives from the
        // reflections timeline; default to empty so widget tests never reach
        // the real database through reflectionsRepositoryProvider.
        reflectionsTimelineProvider.overrideWith((ref) => Stream.value(const [])),
        seriesRepositoryProvider.overrideWithValue(series),
        reuseRepositoryProvider.overrideWithValue(reuse),
        calendarRepositoryProvider.overrideWithValue(calendar),
        sessionRepositoryProvider.overrideWithValue(sessions),
        notificationServiceProvider.overrideWithValue(notifications),
        settingsRepositoryProvider.overrideWithValue(settings),
        statsRepositoryProvider.overrideWithValue(stats),
        progressRepositoryProvider.overrideWithValue(progress),
        roundupRepositoryProvider.overrideWithValue(roundups),
        shareServiceProvider.overrideWithValue(share),
        sessionNowSourceProvider.overrideWithValue(() => clock.current),
        sessionNowProvider.overrideWith(() => FakeSessionNow(clock)),
        ...overrides,
      ],
    );
    if (selected != null) {
      container.read(selectedDateProvider.notifier).select(selected);
    }
  }

  final FakeClock clock;
  final FakeEventRepository repository;
  late final FakeSeriesRepository series;
  late final FakeReuseRepository reuse;
  late final FakeCalendarRepository calendar;
  late final FakeSessionRepository sessions;
  final FakeNotificationService notifications = FakeNotificationService();
  final FakeSettingsRepository settings = FakeSettingsRepository();
  final FakeStatsRepository stats = FakeStatsRepository();
  final FakeProgressRepository progress = FakeProgressRepository();
  final FakeRoundupRepository roundups = FakeRoundupRepository();
  final FakeShareService share = FakeShareService();
  late final ProviderContainer container;

  /// [home] inside a themed app (light unless [theme] says otherwise).
  /// [textScale] and [reduceMotion] override the system settings.
  Widget app(
    Widget home, {
    double textScale = 1,
    bool reduceMotion = false,
    ThemeData? theme,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: theme ?? AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: child!,
        ),
        home: Scaffold(body: home),
      ),
    );
  }

  void dispose() {
    container.dispose();
    roundups.dispose();
    progress.dispose();
    stats.dispose();
    sessions.dispose();
    reuse.dispose();
    repository.dispose();
  }
}
