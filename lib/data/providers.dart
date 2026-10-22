import 'dart:async';

import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/notifications/local_notification_service.dart';
import 'package:energy_clock/data/notifications/notification_service.dart';
import 'package:energy_clock/data/repositories/calendar_repository.dart';
import 'package:energy_clock/data/repositories/coach_repository.dart';
import 'package:energy_clock/data/repositories/export_repository.dart';
import 'package:energy_clock/data/repositories/notification_scheduler.dart';
import 'package:energy_clock/data/repositories/progress_repository.dart';
import 'package:energy_clock/data/repositories/project_repository.dart';
import 'package:energy_clock/data/repositories/reflections_repository.dart';
import 'package:energy_clock/data/repositories/reuse_repository.dart';
import 'package:energy_clock/data/repositories/roundup_repository.dart';
import 'package:energy_clock/data/repositories/series_materialiser.dart';
import 'package:energy_clock/data/repositories/series_repository.dart';
import 'package:energy_clock/data/repositories/session_repository.dart';
import 'package:energy_clock/data/repositories/settings_repository.dart';
import 'package:energy_clock/data/repositories/stats_repository.dart';
import 'package:energy_clock/data/repositories/task_repository.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app's single database. It lives in the data layer so that any feature,
/// and the app layer, can read it without importing another feature.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return DriftSettingsRepository(ref.watch(appDatabaseProvider).settingsDao);
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return DriftSessionRepository(ref.watch(appDatabaseProvider).sessionDao);
});

/// Expands recurring series into events (spec §4.3). The event repository and
/// the calendar repository both call it when a day or a month is read.
final seriesMaterialiserProvider = Provider<SeriesMaterialiser>((ref) {
  return SeriesMaterialiser(ref.watch(appDatabaseProvider).seriesDao);
});

/// Makes events repeat, and edits or deletes "this and all future".
final seriesRepositoryProvider = Provider<SeriesRepository>((ref) {
  return DriftSeriesRepository(ref.watch(appDatabaseProvider).seriesDao);
});

/// Day templates and copy-yesterday.
final reuseRepositoryProvider = Provider<ReuseRepository>((ref) {
  return DriftReuseRepository(ref.watch(appDatabaseProvider).templateDao);
});

/// Grouped statistics over a week or month, for the Stats tab (spec §8).
final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return DriftStatsRepository(
    ref.watch(appDatabaseProvider),
    materialiser: ref.watch(seriesMaterialiserProvider),
  );
});

/// Scores, streaks, XP and badges, for the Profile tab (spec §9).
final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return DriftProgressRepository(ref.watch(appDatabaseProvider));
});

/// Generated weekly roundups, for Profile's archive (spec §9.6).
final roundupRepositoryProvider = Provider<RoundupRepository>((ref) {
  return DriftRoundupRepository(ref.watch(appDatabaseProvider));
});

/// The JSON export and the platform share sheet (spec §9.7). Tests replace
/// the share service with a fake, so nothing in a test run reaches the OS.
final exportRepositoryProvider = Provider<ExportRepository>((ref) {
  return DriftExportRepository(ref.watch(appDatabaseProvider));
});

final shareServiceProvider = Provider<ShareService>((ref) {
  return SharePlusService();
});

/// How each day of a month is planned, for the Calendar tab.
final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return DriftCalendarRepository(
    ref.watch(appDatabaseProvider).eventDao,
    materialiser: ref.watch(seriesMaterialiserProvider),
  );
});

/// The day-planner's events.
final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return DriftEventRepository(
    ref.watch(appDatabaseProvider).eventDao,
    materialiser: ref.watch(seriesMaterialiserProvider),
  );
});

/// Durable user outcomes (Projects feature): CRUD + link/unlink via ProjectDao.
/// Single canonical definition; `features/projects/providers.dart` aliases it
/// as `projectsRepositoryProvider` and adds the list stream.
final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return DriftProjectRepository(ref.watch(appDatabaseProvider));
});

/// First-class tasks under projects (schema v12). Single canonical definition;
/// `features/projects/providers.dart` aliases it as `tasksRepositoryProvider`.
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return DriftTaskRepository(ref.watch(appDatabaseProvider));
});

final coachRepositoryProvider = Provider<CoachRepository>((ref) {
  return DriftCoachRepository(ref.watch(appDatabaseProvider));
});

/// Post-session debriefs timeline + patterns (Reflections feature).
final reflectionsRepositoryProvider = Provider<ReflectionsRepository>((ref) {
  return DriftReflectionsRepository(ref.watch(appDatabaseProvider));
});

/// Local notifications. Tests replace it with a fake, so nothing in a test run
/// reaches the plugin.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return LocalNotificationService();
});

/// The foreground notification reconciler (spec §10).
final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  return DriftNotificationScheduler(
    ref.watch(appDatabaseProvider),
    ref.watch(notificationServiceProvider),
    materialiser: ref.watch(seriesMaterialiserProvider),
  );
});

/// Materialises the next 7 days, then reconciles notifications: once on first
/// watch, on every foreground, and on every events-table write. Watch it from
/// a widget that lives as long as the app (ClockTab). Passes serialize inside
/// the scheduler; a failing plugin never surfaces here.
final foregroundRefreshProvider = Provider<void>((ref) {
  final scheduler = ref.watch(notificationSchedulerProvider);
  final db = ref.watch(appDatabaseProvider);

  void refresh() {
    unawaited(scheduler.reconcile());
  }

  // Broadcast tableUpdates; payload is ignored as per spec.
  final tables = db.tableUpdates().listen((_) => refresh());
  ref.onDispose(tables.cancel);
  final lifecycle = AppLifecycleListener(onResume: refresh);
  ref.onDispose(lifecycle.dispose);
  refresh();
});
