import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:energy_clock/data/daos/coach_dao.dart';
import 'package:energy_clock/data/daos/event_dao.dart';
import 'package:energy_clock/data/daos/project_dao.dart';
import 'package:energy_clock/data/daos/series_dao.dart';
import 'package:energy_clock/data/daos/session_dao.dart';
import 'package:energy_clock/data/daos/progress_dao.dart';
import 'package:energy_clock/data/daos/roundup_dao.dart';
import 'package:energy_clock/data/daos/settings_dao.dart';
import 'package:energy_clock/data/daos/stats_dao.dart';
import 'package:energy_clock/data/daos/task_dao.dart';
import 'package:energy_clock/data/daos/template_dao.dart';
import 'package:energy_clock/data/tables/coach_tables.dart';
import 'package:energy_clock/data/tables/day_scores_table.dart';
import 'package:energy_clock/data/tables/day_templates_table.dart';
import 'package:energy_clock/data/tables/event_series_table.dart';
import 'package:energy_clock/data/tables/events_table.dart';
import 'package:energy_clock/data/tables/progress_table.dart';
import 'package:energy_clock/data/tables/projects_table.dart';
import 'package:energy_clock/data/tables/sessions_table.dart';
import 'package:energy_clock/data/tables/tasks_table.dart';
import 'package:energy_clock/data/tables/settings_table.dart';
import 'package:energy_clock/data/tables/weekly_roundups_table.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Events,
    EventSeries,
    AppSettings,
    Sessions,
    DayTemplates,
    DayTemplateItems,
    DayScores,
    Progress,
    BadgeUnlocks,
    WeeklyRoundups,
    Projects,
    Tasks,
    CoachIntents,
    CoachReviews,
    CoachInsights,
  ],
  daos: [
    EventDao,
    ProjectDao,
    TaskDao,
    CoachDao,
    SettingsDao,
    SessionDao,
    SeriesDao,
    TemplateDao,
    StatsDao,
    ProgressDao,
    RoundupDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'energy_clock'));

  AppDatabase.forTesting(super.executor);

/// Version 1: events, event series, settings. Version 2: sessions. Version 3:
/// day templates, and the indexes on events. Version 4: day scores, progress,
/// badge unlocks, weekly roundups. Version 5: flight columns on events.
/// Version 6: projects table + events.project_id.
/// Version 7: coach_intents, coach_reviews, coach_insights + CoachDao.
/// Version 8: reflection columns on sessions (energyRating, focusRating, tagsCsv, note).
/// Version 9: coach_intents.predicted_energy.
/// Version 10: projects.notes + projects.priority.
/// Version 11: project_subtasks checklist steps, cascade-deleted with the project.
/// Version 12: `tasks` replaces `project_subtasks`; subtask rows are copied
/// into tasks (done → Done column) and the old table is dropped.
/// Every bump needs a step in [migration] and
/// a test in `test/data/migration_test.dart`; see `drift_schemas/`.
@override
int get schemaVersion => 12;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(sessions);
      }
      if (from < 3) {
        await migrator.createTable(dayTemplates);
        await migrator.createTable(dayTemplateItems);
        await migrator.createIndex(eventsDate);
        await migrator.createIndex(eventsSeriesDate);
      }
      if (from < 4) {
        await migrator.createTable(dayScores);
        await migrator.createTable(progress);
        await migrator.createTable(badgeUnlocks);
        await migrator.createTable(weeklyRoundups);
      }
      if (from < 5) {
        await migrator.addColumn(events, events.isFlight);
        await migrator.addColumn(events, events.flightNumber);
        await migrator.addColumn(events, events.fromCode);
        await migrator.addColumn(events, events.toCode);
      }
      if (from < 6) {
        await migrator.createTable(projects);
        await migrator.addColumn(events, events.projectId);
      }
      if (from < 7) {
        await migrator.database.customStatement(
          'CREATE TABLE "coach_intents" ('
          '"date" INTEGER NOT NULL, '
          '"focus_goal" TEXT NOT NULL, '
          '"top_event_ids" TEXT NULL, '
          '"created_at" INTEGER NOT NULL, '
          'PRIMARY KEY ("date")'
          ');',
        );
        await migrator.createTable(coachReviews);
        await migrator.createTable(coachInsights);
      }
      // Sessions is created fresh with all columns when from < 2.
      // to >= 8 keeps v7 validation clean: 6->7 must not add v8 columns
      // (extra columns fail strictly, unlike extra tables).
      if (to >= 8 && from >= 2 && from < 8) {
        await migrator.addColumn(sessions, sessions.energyRating);
        await migrator.addColumn(sessions, sessions.focusRating);
        await migrator.addColumn(sessions, sessions.tagsCsv);
        await migrator.addColumn(sessions, sessions.note);
      }
      // coach_intents table is created in v7, so only add predictedEnergy
      // when upgrading to v9.
      if (from < 9 && to >= 9) {
        await migrator.addColumn(coachIntents, coachIntents.predictedEnergy);
      }
      // Projects is created fresh with all columns when from < 6, so only
      // add notes/priority when the table already exists.
      if (from >= 6 && from < 10 && to >= 10) {
        await migrator.addColumn(projects, projects.notes);
        await migrator.addColumn(projects, projects.priority);
      }
      // project_subtasks is brand-new in v11 (nothing to add on top), so it is
      // only created when the upgrade actually targets v11 — mirroring the
      // `to >=` guard used for v8/v9/v10 so intermediate-version validation
      // tests (e.g. 6 -> 7) don't see a table their reference schema lacks.
      // v12 removes the table from the schema, so it no longer has a generated
      // accessor; the v11 shape is recreated with raw DDL because the v12 step
      // below copies from it and then drops it.
      if (to >= 11 && from < 11) {
        await migrator.database.customStatement(
          'CREATE TABLE "project_subtasks" ('
          '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
          '"project_id" INTEGER NOT NULL REFERENCES projects (id) '
          'ON DELETE CASCADE, '
          '"title" TEXT NOT NULL, '
          '"is_done" INTEGER NOT NULL DEFAULT 0 '
          'CHECK ("is_done" IN (0, 1)), '
          '"sort_order" INTEGER NOT NULL, '
          '"created_at" INTEGER NOT NULL'
          ');',
        );
      }
      if (from < 12 && to >= 12) {
        await migrator.createTable(tasks);
        await migrator.database.customStatement(
          'INSERT INTO tasks (project_id, title, board_status, completed_at, '
          'sort_order, created_at, updated_at) '
          'SELECT project_id, title, CASE WHEN is_done = 1 THEN 4 ELSE 1 END, '
          'CASE WHEN is_done = 1 THEN created_at ELSE NULL END, '
          'sort_order, created_at, created_at FROM project_subtasks',
        );
        await migrator.deleteTable('project_subtasks');
      }
    },
  );

  /// Deletes every row of every table — support's full reset (spec §9.7).
  /// Sessions go before events for the foreign key. The schema is untouched,
  /// and so are the table-update streams (they re-emit empty).
  Future<void> resetAll() => transaction(() async {
    await delete(sessions).go();
    await delete(dayTemplateItems).go();
    await delete(dayTemplates).go();
    await delete(events).go();
    await delete(eventSeries).go();
    await delete(dayScores).go();
    await delete(progress).go();
    await delete(badgeUnlocks).go();
    await delete(weeklyRoundups).go();
    await delete(tasks).go();
    await delete(projects).go();
    await delete(coachInsights).go();
    await delete(coachReviews).go();
    await delete(coachIntents).go();
    await delete(appSettings).go();
  });
}
