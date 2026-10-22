# Energy Clock — Step 4: Statistics, Progress and Profile — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Stats tab shows a week or month of tone balance, planned-vs-actual, focus depth and an hour-of-day heatmap; the Profile tab shows level, XP, streak, badges, weekly roundups and the settings (theme, focus target, first day of week, recalculate, export, erase) — every number derived from `events` and `sessions`, never accumulated.

**Architecture:** Stats reads one grouped SQL aggregate per section over `events ⋈ sessions` for the selected window, after materialising recurring events into it (spec §8, Step 3's row 1). Progress (score, streak, XP, badges) is a pure calculator in `lib/core/progress/` fed by queries in `lib/data/repositories/progress_repository.dart`, cached in the four new schema-v4 tables and rebuilt wholesale by `recalculateAll()` (spec §9.1). Weekly roundups are generated for finished weeks when the archive is read, frozen as JSON in `weekly_roundups` (spec §9.6). Repositories stay in the data layer so features never import each other; `lib/app/` composes.

**Tech Stack:** Flutter 3.44.7, Dart 3.12.2, `flutter_riverpod` 2.6, `drift` + `drift_flutter` (schema **v4**), `intl`, **`share_plus` (the one new runtime package**, for the export share sheet). No charting library: four hand-rolled `CustomPainter`s.

**Specs:** `docs/superpowers/specs/2026-10-07-step-4-stats-and-progress-design.md` (this step) over `docs/superpowers/specs/2026-08-23-energy-clock-design.md` (§8 Statistics, §9 Progress, §14 Phases 4–5). **It must run after Steps 1–3** (design system, Clock, session, calendar, the test harness and the layout matrix it builds on).

## Global Constraints

These apply to every task. Copied from the earlier plans, schema line updated.

- **Platform:** iOS 15+. iPhone in portrait; iPad in all four orientations with resizable windows. Flutter 3.44.7 / Dart 3.12.2.
- **Language:** English-only. All user-facing copy lives in `lib/core/strings.dart`. No localisation framework.
- **Tones are fixed:** exactly three — Focus (purple), Life (green), Inbox (orange). Not addable, removable, renameable, or recolourable.
- **Colour only ever encodes a tone.** UI accent is near-black in light mode, near-white in dark. Chart colours come from `context.toneColors` / `context.appColors` passed into painters; painters never read the theme themselves.
- **No hard-coded colours in feature code.** Nothing under `lib/features/` may contain `Color(0x` or `Colors.`. Enforced by `test/architecture/no_hardcoded_colors_test.dart`. (Painters live in `lib/shared/charts/`, outside that scan, but still take every colour as a parameter — the tests in this plan assert it by example.)
- **Boundary rule:** no file under `lib/features/<a>/` may import from `lib/features/<b>/`. `lib/app/` composes features and may import them; features may import `lib/app/` (they already import `app/theme`, `app/navigation`). Cross-feature communication goes through repositories exposed as Riverpod providers in `lib/data/providers.dart`. The data layer and `lib/core/` import no feature.
- **Minute domain:** `startMinute` 0–1439, `endMinute` 1–1440 exclusive. Stats and scores work in whole minutes; SQL truncates seconds with integer division *after* grouping (`SUM(activeSeconds) / 60`), and the fakes match it (`totalSeconds ~/ 60`).
- **Derived, never accumulated:** every statistic and every progress number is recomputed from `events` and `sessions` when shown or written; `day_scores`, `progress` and `badge_unlocks` are caches rebuildable by `recalculateAll()`. Past-day scores are never silently recomputed (spec §9.3).
- **The one minute pool:** `countsAsDone` sessions only (`completed` or `finishedEarly`), attributed to `events.date` of the joined event; planned minutes are event durations regardless of status (Step 4 spec, amendment 3). Abandoned sessions appear only in the abandonment rate.
- **Local dates:** every date is a local midnight; day/week/month arithmetic uses the `DateTime(y, m, d ± n)` constructor, never a 24-hour `Duration`.
- **Window classes:** narrow under 600 pt, medium 600–899, wide 900+. Eight sizes in the layout matrix: 320, 375, 402, 744, 834, 1032, 1194, 1366 wide (as named in the matrix file).
- **Tap targets** ≥ 44 pt. **Contrast:** text ≥ 4.5:1, chart marks ≥ 3:1 against their background.
- **Reduce Motion:** any animation added here (there is almost none) becomes a jump under Reduce Motion.
- **New runtime packages:** exactly one — `share_plus`. No `path_provider` import: the export file goes to `Directory.systemTemp` from `dart:io`.
- **Schema:** version 4. Every schema change ships with a migration step and migration tests (`test/data/migration_test.dart`), built on `drift_schemas/` and `test/generated_migrations/`.
- **Tooling:** run Dart commands (`build_runner`, `drift_dev`, `dart format`) with the Flutter SDK's dart (`DART="$(dirname "$(which flutter)")/dart"`). The first `dart` on this machine's PATH is 3.10 and fails on this project. `rg` is unavailable; use the grep tool or `Select-String`.
- **Style:** `flutter analyze` clean; `dart format` output committed; lints in `analysis_options.yaml` (single quotes, `unawaited_futures`, `prefer_final_locals`, `always_declare_return_types`). The code in this plan is already formatted; Task 24 confirms it.
- **Commit messages** use the repo's conventional prefixes and end with a blank line and the trailer `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Plan checkboxes stay unticked in this file.

## Decisions and amendments

Settled while writing this plan from the Step 4 spec. **Rows 1, 3, 6 and 9 are the ones most worth a second look.**

| # | Area | Decision | Why |
|---|---|---|---|
| 1 | Where the code lives | Pure progress logic (score, streak, XP, badges, ISO weeks, roundup payload) in `lib/core/progress/` and `lib/core/roundup/`; repositories (`StatsRepository`, `ProgressRepository`, `RoundupRepository`, `ExportRepository`) in `lib/data/repositories/` with providers in `lib/data/providers.dart`; UI in `lib/features/stats/` and `lib/features/progress/`. | The session screen (features/session) must call the progress hook, Profile must show it, and Step 5's notification job will read roundups — none of them may import another feature, so the shared edge goes through `lib/data/`. |
| 2 | Chart painters | All four painters live in `lib/shared/charts/` (donut, stacked bars, paired bars, heatmap). | Profile's roundup reuses the donut (spec §7.3); a feature may not import a feature, so the charts are shared, like `shared/widgets/`. Every colour is a constructor parameter. |
| 3 | Heatmap bucketing | SQL returns `(startedAt, activeSeconds)` rows; the 7×24 matrix is built in Dart (`lib/features/stats/model/heatmap.dart`). | Drift stores `DateTime` as epoch seconds; local weekday/hour buckets cannot be computed with SQLite `strftime` without mis-bucketing across timezones and DST. |
| 4 | Where settings providers live | `themeModeProvider`, `focusTargetProvider`, `firstDayOfWeekProvider` in `lib/app/settings/settings_providers.dart`. | The app, the Clock, the Calendar, Stats and Profile all read them; `lib/app/` is the one directory everything may import. |
| 5 | Recompute triggers | `onSessionEnded` (called by the session screen after finish/abandon/closeOut), `ensureFresh()` (Profile build and app foreground via a lifecycle observer in `ProfileScreen`), `recalculateAll()` (Profile row only). Past-day edits recompute nothing. | Spec §4.5. |
| 6 | Focus-depth definition | Totals/longest/average over `countsAsDone` Focus sessions; abandonment rate = abandoned ÷ all ended Focus sessions; `—` when the denominator is 0. | Keeps the minute pool single (spec §3) while still reporting failure honestly. |
| 7 | Roundup week | Always Monday–Sunday, ISO week numbers (`isoYear`+`isoWeek` PK), independent of the first-day-of-week setting; generated inside `RoundupRepository.ensureCurrent()` when the archive stream is first listened. | Spec §9.6; no scheduler exists until Step 5. |
| 8 | Export file location | `Directory.systemTemp` via `dart:io`, written with synchronous calls, shared with `share_plus`, deleted in a `finally` when sharing fails. | Avoids a `path_provider` import (Step 4's spec says one new package; `path_provider` is only present transitively for Drift). |
| 9 | Score breakdown on Profile | Always visible — three rows (adherence / focus / balance points) plus one caption line. No expansion, no dialog. | Spec §9.3 wants the breakdown interrogable; always-visible is the simplest thing that satisfies it. |
| 10 | First day of week | `startOfWeek`, `daysOfWeek`, `monthWeeks` gain `{int firstWeekday = DateTime.monday}`; WeekStrip and MonthPage read `firstDayOfWeekProvider` (Sunday = `DateTime.sunday`); weekday labels rotate. | Default-preserving: every existing caller and test keeps passing without change. |
| 11 | Badge facts | Facts (ended-session count, qualifying days, four-hour days, all-tone weeks, clean weeks, early focus) are queried from source tables at evaluation time, never read back from `day_scores`. | Spec §9.1 — the cache must never be the source of a rebuild. |
| 12 | Roundup example dates | The Step 4 spec's JSON example labels ISO week 40 of 2026 as "29 Sep – 5 Oct"; the correct range is **28 Sep – 4 Oct 2026** (week 41 starts Mon 5 Oct). The plan's fixtures use the corrected dates. | The example was illustrative and off by one day. |

## Out of scope (Step 5 and later)

- Every notification: roundup announcement, "event starting soon", permission prompts, and the notification toggles on Profile.
- The foreground "next 7 days" materialising job (deferred by Step 3).
- Chart tooltips / tap-to-inspect, trends beyond the selected period, per-event statistics.
- A settings screen of its own (all settings live on Profile); export to anything but the share sheet.

## How to read the steps

- **Create / Replace / Edit** blocks give the exact file change. An **Edit** block shows the exact text to find (`Replace:`) and what to put there (`With:`); each find text appears exactly once in the file at plan-writing time.
- A bash block whose first line is `# expect: PASS` must succeed; `# expect: FAIL` must fail for the stated reason; `# expect: RUN` and `# expect: UPDATE` are setup commands that must succeed; `# expect: MANUAL` is done by a person or the controller.
- Generated files (`*.g.dart`, `drift_schemas/*.json`, `test/generated_migrations/*`, golden images) are produced by the bash steps, not by file blocks. Commit them with the task.
- Golden images must be **looked at**, not just generated. Steps that say so name what to check.
- If a snippet does not compile against Flutter 3.44.7 / the installed `share_plus`, fix the API usage minimally, keep the behaviour and the tests' intent, and say so in your report.
- `testWidgets` runs in fake time. Use `harness.app(..., reduceMotion: true)` before `pumpAndSettle` where a widget pulses.
- Test counts in `# expect: PASS` lines are the tests that task adds. The baseline before this step is **1,361** tests; the whole suite is expected to grow by roughly 150.

## File Structure

**Created:**

| File | Responsibility |
|---|---|
| `lib/data/tables/day_scores_table.dart` | `day_scores` table |
| `lib/data/tables/progress_table.dart` | `progress` (single row) and `badge_unlocks` tables |
| `lib/data/tables/weekly_roundups_table.dart` | `weekly_roundups` table |
| `lib/data/daos/stats_dao.dart` | The four stats queries + `watchSnapshot` |
| `lib/data/daos/progress_dao.dart` | Reads/writes `day_scores`, `progress`, `badge_unlocks`, `weekly_roundups` |
| `lib/data/repositories/stats_repository.dart` | `StatsRepository`, `StatsSnapshot` and its typedefs |
| `lib/data/repositories/progress_repository.dart` | `ProgressRepository`: recalc day, ensureFresh, onSessionEnded, recalculateAll, watches |
| `lib/data/repositories/roundup_repository.dart` | `RoundupRepository`: ensureCurrent, archive stream, payload read |
| `lib/data/repositories/export_repository.dart` | `ExportRepository.buildJson`, `ShareService` + `SharePlusService` |
| `lib/core/progress/score.dart` | `scoreFor`, `ScoreBreakdown` |
| `lib/core/progress/streak.dart` | `streaks`, `Streaks` |
| `lib/core/progress/xp.dart` | session/badge/streak XP, `levelForXp`, `xpToReachLevel` |
| `lib/core/progress/badges.dart` | `BadgeDefinition`, `BadgeFacts`, `badgeDefinitions`, `badgesToUnlock` |
| `lib/core/roundup/iso_week.dart` | `isoWeekOf`, `isoWeekStart` |
| `lib/core/roundup/roundup_payload.dart` | `RoundupPayload` + hand-written JSON codec |
| `lib/app/settings/settings_providers.dart` | `themeModeProvider`, `focusTargetProvider`, `firstDayOfWeekProvider` |
| `lib/shared/charts/stacked_bars_painter.dart` | Tone balance day stacks |
| `lib/shared/charts/donut_painter.dart` | Period / roundup donut |
| `lib/shared/charts/paired_bars_painter.dart` | Planned vs completed bars |
| `lib/shared/charts/heatmap_painter.dart` | 7×24 focus heatmap |
| `lib/features/stats/model/stats_period.dart` | `StatsPeriod`, `StatsPeriodKind`, `StatsWindow` |
| `lib/features/stats/model/heatmap.dart` | `buildHeatmap`: instants → 7×24 matrix |
| `lib/features/stats/providers.dart` | `statsPeriodProvider`, `statsWindowProvider`, `statsDataProvider` |
| `lib/features/stats/stats_layout.dart` | Single- vs two-column decision |
| `lib/features/stats/stats_screen.dart` | The Stats tab |
| `lib/features/stats/widgets/period_header.dart` | Week/Month toggle, range label, chevrons |
| `lib/features/stats/widgets/section_card.dart` | Card chrome + empty state + semantics wrapper |
| `lib/features/stats/widgets/tone_balance_card.dart` | Section 1 |
| `lib/features/stats/widgets/planned_actual_card.dart` | Section 2 |
| `lib/features/stats/widgets/focus_depth_card.dart` | Section 3 (metric tiles) |
| `lib/features/stats/widgets/heatmap_card.dart` | Section 4 |
| `lib/features/progress/providers.dart` | `progressRowProvider`, `todayScoreProvider`, `unlockedBadgesProvider`, `roundupArchiveProvider` |
| `lib/features/progress/progress_layout.dart` | Content width helper for Profile |
| `lib/features/progress/profile_screen.dart` | **Replaced** — the real Profile tab |
| `lib/features/progress/widgets/level_card.dart` | Level, XP bar, streaks |
| `lib/features/progress/widgets/score_card.dart` | Today's score + breakdown |
| `lib/features/progress/widgets/badge_grid.dart` | Ten slots, locked/unlocked |
| `lib/features/progress/widgets/roundup_archive.dart` | Archive list + snapshot view |
| `lib/features/progress/widgets/settings_card.dart` | Theme, focus target, first day, recalculate, export, erase |
| `drift_schemas/drift_schema_v4.json`, `test/generated_migrations/schema_v4.dart` | Schema v4 snapshot (generated) |
| `test/support/fake_stats_repository.dart`, `fake_progress_repository.dart`, `fake_roundup_repository.dart`, `fake_share_service.dart` | In-memory fakes |
| Test files named in each task | See each task |

**Replaced:** `lib/features/progress/profile_screen.dart`, `test/data/migration_test.dart`.

**Modified:** `lib/data/database.dart`, `lib/data/providers.dart`, `lib/data/repositories/settings_repository.dart`, `lib/core/strings.dart`, `lib/core/time/day_time.dart`, `lib/core/time/month_time.dart`, `lib/features/clock/widgets/week_strip.dart`, `lib/features/calendar/widgets/month_page.dart`, `lib/features/session/session_screen.dart`, `lib/features/stats/stats_screen.dart`, `lib/app/app.dart`, `pubspec.yaml`, `README.md`, `test/support/fake_settings_repository.dart`, `test/support/fake_session_repository.dart`, `test/support/clock_harness.dart`, `test/data/settings_test.dart`, `test/core/strings_test.dart`, `test/core/time/month_time_test.dart`, `test/core/time/day_time_test.dart`, the generated `*.g.dart` files, and the new golden images.

---

## Stage 1 — Schema, settings, first day of week

### Task 1: Schema v4 — the four progress tables

The caches first. `day_scores`, `progress`, `badge_unlocks` and `weekly_roundups` land exactly as spec §4.2 defines them, with the migration, the schema dumps and the migration tests. Nothing reads them yet.

**Files:**
- Create: `lib/data/tables/day_scores_table.dart`, `lib/data/tables/progress_table.dart`, `lib/data/tables/weekly_roundups_table.dart`
- Modify: `lib/data/database.dart`
- Test: `test/data/migration_test.dart` (replaced)

**Interfaces:**
- Produces: drift classes `DayScores` (`DayScoreRow`), `Progress` (`ProgressRow`), `BadgeUnlocks` (`BadgeUnlockRow`), `WeeklyRoundups` (`WeeklyRoundupRow`); `AppDatabase.schemaVersion == 4`; table getters `db.dayScores`, `db.progress`, `db.badgeUnlocks`, `db.weeklyRoundups`.

- [ ] **Step 1: Write the failing migration tests**

**Replace `test/data/migration_test.dart`**

```dart
import 'package:drift_dev/api/migrations_native.dart';
import 'package:energy_clock/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../generated_migrations/schema.dart';

/// Every shipped schema version must upgrade to the current one without losing
/// data. The `drift_schemas/` dumps and `test/generated_migrations/` come from
/// `drift_dev schema dump` and `drift_dev schema generate`.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  // Seconds since the epoch, which is how Drift stores a DateTime.
  final seconds = DateTime(2026, 10, 7).millisecondsSinceEpoch ~/ 1000;

  const insertEvent =
      'INSERT INTO events (date, title, tone_index, start_minute, end_minute, '
      'status, created_at, updated_at) ';

  test('version 1 upgrades to version 4', () async {
    final schema = await verifier.schemaAt(1);
    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 4);
  });

  test('version 2 upgrades to version 4', () async {
    final schema = await verifier.schemaAt(2);
    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 4);
  });

  test('version 3 upgrades to version 4', () async {
    final schema = await verifier.schemaAt(3);
    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 4);
  });

  test('upgrading from version 1 keeps the events that were stored', () async {
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase.execute(
      "$insertEvent VALUES ($seconds, 'Deep work', 0, 540, 660, 0, $seconds, $seconds)",
    );

    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 4);

    final events = await database.eventDao.eventsForDay(DateTime(2026, 10, 7));
    expect(events.single.title, 'Deep work');
    expect(await database.sessionDao.running(), isNull);
  });

  test('upgrading from version 2 keeps events and sessions', () async {
    final schema = await verifier.schemaAt(2);
    schema.rawDatabase.execute(
      "$insertEvent VALUES ($seconds, 'Deep work', 0, 540, 660, 0, $seconds, $seconds)",
    );
    schema.rawDatabase.execute(
      'INSERT INTO sessions (event_id, started_at, planned_seconds, '
      'paused_seconds, active_seconds, overtime_seconds, outcome) '
      'VALUES (1, $seconds, 3600, 0, 0, 0, 0)',
    );

    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 4);

    final events = await database.eventDao.eventsForDay(DateTime(2026, 10, 7));
    expect(events.single.title, 'Deep work');
    final running = await database.sessionDao.running();
    expect(running, isNotNull);
    expect(running!.session.plannedSeconds, 3600);
    expect(await database.select(database.dayTemplates).get(), isEmpty);
  });

  test('upgrading from version 3 creates the progress tables empty', () async {
    final schema = await verifier.schemaAt(3);
    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 4);

    expect(await database.select(database.dayScores).get(), isEmpty);
    expect(await database.select(database.progress).get(), isEmpty);
    expect(await database.select(database.badgeUnlocks).get(), isEmpty);
    expect(await database.select(database.weeklyRoundups).get(), isEmpty);
  });

  test('a new install creates the same schema as the upgrade', () async {
    final schema = await verifier.schemaAt(4);
    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 4);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL - `SchemaInstantiationHelper` has no case for version 4 (drift_schema_v4.json does not exist yet), so `migrateAndValidate(database, 4)` throws MissingSchemaException / the test file fails to resolve schema version 4.
flutter test test/data/migration_test.dart
```

- [ ] **Step 3: Create the table files**

**Create `lib/data/tables/day_scores_table.dart`**

```dart
import 'package:drift/drift.dart';

/// One day's cached score, always recomputable from `events` and `sessions`
/// (spec §9.1). Days with no plan and no sessions have no row.
@DataClassName('DayScoreRow')
class DayScores extends Table {
  /// Local midnight of the scored day.
  DateTimeColumn get date => dateTime()();

  /// 0–100, the sum of the three points columns.
  IntColumn get energyScore => integer()();

  /// 0–50.
  IntColumn get adherencePoints => integer()();

  /// 0–30.
  IntColumn get focusPoints => integer()();

  /// 0–20.
  IntColumn get balancePoints => integer()();

  /// The minute pool (countsAsDone), by tone.
  IntColumn get focusMinutes => integer().withDefault(const Constant(0))();
  IntColumn get lifeMinutes => integer().withDefault(const Constant(0))();
  IntColumn get inboxMinutes => integer().withDefault(const Constant(0))();

  IntColumn get plannedMinutes => integer().withDefault(const Constant(0))();
  IntColumn get completedMinutes => integer().withDefault(const Constant(0))();

  DateTimeColumn get computedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {date};
}
```

**Create `lib/data/tables/progress_table.dart`**

```dart
import 'package:drift/drift.dart';

/// The single cached progress row (spec §4.2): one row, id always 1.
@DataClassName('ProgressRow')
class Progress extends Table {
  IntColumn get id => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  IntColumn get xp => integer().withDefault(const Constant(0))();
  IntColumn get level => integer().withDefault(const Constant(1))();
  IntColumn get currentStreak => integer().withDefault(const Constant(0))();
  IntColumn get longestStreak => integer().withDefault(const Constant(0))();

  /// The last local day this row was computed for; drives `ensureFresh()`.
  DateTimeColumn get lastStreakDate => dateTime().nullable()();
}

/// Badge unlocks, keyed by the stable id of a code-side definition (spec §9.4).
@DataClassName('BadgeUnlockRow')
class BadgeUnlocks extends Table {
  TextColumn get badgeId => text()();

  DateTimeColumn get unlockedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {badgeId};
}
```

**Create `lib/data/tables/weekly_roundups_table.dart`**

```dart
import 'package:drift/drift.dart';

/// A generated Weekly Roundup, frozen as JSON (spec §9.6). One row per ISO
/// week; rows are never rewritten.
@DataClassName('WeeklyRoundupRow')
class WeeklyRoundups extends Table {
  IntColumn get isoYear => integer()();

  IntColumn get isoWeek => integer()();

  DateTimeColumn get generatedAt => dateTime()();

  TextColumn get payloadJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {isoYear, isoWeek};
}
```

- [ ] **Step 4: Wire the tables into the database**

**Edit `lib/data/database.dart`** (four `Replace:` / `With:` pairs, in order)

Replace:
```dart
import 'package:energy_clock/data/tables/day_templates_table.dart';
import 'package:energy_clock/data/tables/event_series_table.dart';
import 'package:energy_clock/data/tables/events_table.dart';
import 'package:energy_clock/data/tables/sessions_table.dart';
import 'package:energy_clock/data/tables/settings_table.dart';
```
With:
```dart
import 'package:energy_clock/data/tables/day_scores_table.dart';
import 'package:energy_clock/data/tables/day_templates_table.dart';
import 'package:energy_clock/data/tables/event_series_table.dart';
import 'package:energy_clock/data/tables/events_table.dart';
import 'package:energy_clock/data/tables/progress_table.dart';
import 'package:energy_clock/data/tables/sessions_table.dart';
import 'package:energy_clock/data/tables/settings_table.dart';
import 'package:energy_clock/data/tables/weekly_roundups_table.dart';
```

Replace:
```dart
    DayTemplates,
    DayTemplateItems,
  ],
```
With:
```dart
    DayTemplates,
    DayTemplateItems,
    DayScores,
    Progress,
    BadgeUnlocks,
    WeeklyRoundups,
  ],
```

Replace:
```dart
  /// Version 1: events, event series, settings. Version 2: sessions. Version 3:
  /// day templates, and the indexes on events. Every bump needs a step in
  /// [migration] and a test in `test/data/migration_test.dart`; see
  /// `drift_schemas/`.
  @override
  int get schemaVersion => 3;
```
With:
```dart
  /// Version 1: events, event series, settings. Version 2: sessions. Version 3:
  /// day templates, and the indexes on events. Version 4: day scores, progress,
  /// badge unlocks, weekly roundups. Every bump needs a step in [migration] and
  /// a test in `test/data/migration_test.dart`; see `drift_schemas/`.
  @override
  int get schemaVersion => 4;
```

Replace:
```dart
      if (from < 3) {
        await migrator.createTable(dayTemplates);
        await migrator.createTable(dayTemplateItems);
        await migrator.createIndex(eventsDate);
        await migrator.createIndex(eventsSeriesDate);
      }
    },
```
With:
```dart
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
    },
```

- [ ] **Step 5: Generate the schema artifacts**

```bash
# expect: RUN - regenerates database.g.dart, drift_schema_v4.json, schema_v4.dart and schema.dart
DART="$(dirname "$(which flutter)")/dart"
"$DART" run build_runner build --delete-conflicting-outputs
"$DART" run drift_dev schema dump lib/data/database.dart drift_schemas/
"$DART" run drift_dev schema generate drift_schemas/ test/generated_migrations/
ls drift_schemas test/generated_migrations
```

- [ ] **Step 6: Run the migration tests to verify they pass**

```bash
# expect: PASS - 6 migration tests pass
flutter test test/data/migration_test.dart
```

- [ ] **Step 7: Analyze, run the suite, commit**

```bash
# expect: PASS - analyzer clean; the whole suite stays green (1,361 tests)
flutter analyze && flutter test
```

```bash
# expect: RUN
git add lib/data/tables/day_scores_table.dart lib/data/tables/progress_table.dart \
  lib/data/tables/weekly_roundups_table.dart lib/data/database.dart lib/data/database.g.dart \
  drift_schemas/drift_schema_v4.json test/generated_migrations/ test/data/migration_test.dart
git commit -m "feat: schema v4 with day scores, progress, badge unlocks and roundups

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

### Task 2: Settings repository — strings and integers

The three new settings need more than booleans. `SettingsRepository` gains `getString`/`setString` and `getInt`/`setInt`; integers are stored as their decimal string (the table only has a text value column), and a value that does not parse reads as null.

**Files:**
- Modify: `lib/data/repositories/settings_repository.dart`, `test/support/fake_settings_repository.dart`
- Test: `test/data/settings_test.dart`

**Interfaces:**
- `SettingsRepository` gains `Future<String?> getString(String key)`, `Future<void> setString(String key, String value)`, `Future<int?> getInt(String key)`, `Future<void> setInt(String key, int value)`. All nullable, no default parameter: the caller applies its default.
- `FakeSettingsRepository.values` widens from `Map<String, bool>` to `Map<String, Object>` (booleans stay stored as-is; integers are stored as strings, exactly like the Drift implementation). `gate`, `failReads` and `failWrites` keep working for every read.

- [ ] **Step 1: Write the failing tests**

**Edit `test/data/settings_test.dart`** — insert before the line `  test('settingsRepositoryProvider is built on the shared database', () {`

```dart
    test('a key that was never set reads as null for strings and ints', () async {
      expect(await repository.getString('missing'), isNull);
      expect(await repository.getInt('missing'), isNull);
    });

    test('a stored string reads back, and a later write wins', () async {
      await repository.setString('theme', 'dark');
      expect(await repository.getString('theme'), 'dark');
      await repository.setString('theme', 'light');
      expect(await repository.getString('theme'), 'light');
    });

    test('an integer round-trips through its stored string form', () async {
      await repository.setInt('daily_focus_target', 240);
      expect(await repository.getInt('daily_focus_target'), 240);
      expect(await db.settingsDao.valueFor('daily_focus_target'), '240');
    });

    test('a stored value that is not an integer reads as null', () async {
      await db.settingsDao.setValue('weird', 'nope');
      expect(await repository.getInt('weird'), isNull);
    });

    test('a stored integer survives a later unrelated write', () async {
      await repository.setInt('first_day_of_week', 7);
      await repository.setBool('flag', true);
      expect(await repository.getInt('first_day_of_week'), 7);
    });
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL - compile error: SettingsRepository has no getString/getInt/setString/setInt.
flutter test test/data/settings_test.dart
```

- [ ] **Step 3: Implement the repository**

**Replace `lib/data/repositories/settings_repository.dart`**

```dart
import 'package:energy_clock/data/daos/settings_dao.dart';

/// Typed access to the app's settings. Booleans are stored as '1' and '0',
/// integers as their decimal string; the table holds only text.
abstract interface class SettingsRepository {
  Future<bool> getBool(String key, {bool defaultValue = false});
  Future<void> setBool(String key, bool value);

  /// The stored string, or null when the key was never set.
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);

  /// The stored integer, or null when the key was never set or does not parse.
  Future<int?> getInt(String key);
  Future<void> setInt(String key, int value);
}

class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._dao);

  final SettingsDao _dao;

  @override
  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final stored = await _dao.valueFor(key);
    return stored == null ? defaultValue : stored == '1';
  }

  @override
  Future<void> setBool(String key, bool value) =>
      _dao.setValue(key, value ? '1' : '0');

  @override
  Future<String?> getString(String key) => _dao.valueFor(key);

  @override
  Future<void> setString(String key, String value) => _dao.setValue(key, value);

  @override
  Future<int?> getInt(String key) async => int.tryParse(await _dao.valueFor(key) ?? '');

  @override
  Future<void> setInt(String key, int value) => _dao.setValue(key, '$value');
}
```

- [ ] **Step 4: Widen the fake**

**Edit `test/support/fake_settings_repository.dart`**

Replace:
```dart
  FakeSettingsRepository({Map<String, bool>? values}) : values = {...?values};

  /// The stored settings; tests read and seed it directly.
  final Map<String, bool> values;
```
With:
```dart
  FakeSettingsRepository({Map<String, Object>? values}) : values = {...?values};

  /// The stored settings; tests read and seed it directly. Booleans are stored
  /// as-is, integers as strings — the same shapes the Drift repository writes.
  final Map<String, Object> values;
```

Replace:
```dart
  @override
  Future<void> setBool(String key, bool value) async {
    if (failWrites) throw StateError('settings are unwritable');
    values[key] = value;
  }
}
```
With:
```dart
  @override
  Future<void> setBool(String key, bool value) async {
    if (failWrites) throw StateError('settings are unwritable');
    values[key] = value;
  }

  @override
  Future<String?> getString(String key) async {
    if (failReads) throw StateError('settings are unreadable');
    final held = gate;
    if (held != null) await held.future;
    return values[key] is String ? values[key] as String : null;
  }

  @override
  Future<void> setString(String key, String value) async {
    if (failWrites) throw StateError('settings are unwritable');
    values[key] = value;
  }

  @override
  Future<int?> getInt(String key) async {
    final stored = await getString(key);
    return stored == null ? null : int.tryParse(stored);
  }

  @override
  Future<void> setInt(String key, int value) => setString(key, '$value');
}
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
# expect: PASS - 10 tests (5 existing + 5 new)
flutter test test/data/settings_test.dart
```

- [ ] **Step 6: Analyze, run the suite, commit**

```bash
# expect: PASS - analyzer clean; whole suite green (1,366 tests)
flutter analyze && flutter test
```

```bash
# expect: RUN
git add lib/data/repositories/settings_repository.dart test/support/fake_settings_repository.dart test/data/settings_test.dart
git commit -m "feat: string and integer settings access

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

### Task 3: Settings providers and theme wiring

The three Step-4 settings become Riverpod providers with their defaults (system theme, 180-minute focus target, Monday first day), and the app's `themeMode` starts watching the stored one.

**Files:**
- Create: `lib/app/settings/settings_providers.dart`
- Modify: `lib/app/app.dart`
- Test: `test/app/settings_test.dart` (new)

**Interfaces:**
- `themeModeKey = 'theme_mode'`, `dailyFocusTargetKey = 'daily_focus_target'`, `firstDayOfWeekKey = 'first_day_of_week'` — constants in `settings_providers.dart`.
- `themeModeProvider` (`AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>`, default `ThemeMode.system`, unknown stored string reads as system; `set(ThemeMode)`).
- `focusTargetProvider` (`AsyncNotifierProvider<FocusTargetNotifier, int>`, default `defaultDailyFocusTargetMinutes = 180`; `set(int)`).
- `firstDayOfWeekProvider` (`AsyncNotifierProvider<FirstDayOfWeekNotifier, int>`, default `DateTime.monday` = 1, any stored value other than 1 or 7 reads as 1; `set(int weekday)` accepting `DateTime.monday`/`DateTime.sunday`).

- [ ] **Step 1: Write the failing tests**

**Create `test/app/settings_test.dart`**

```dart
import 'package:energy_clock/app/navigation/tab_scaffold.dart';
import 'package:energy_clock/app/app.dart';
import 'package:energy_clock/app/settings/settings_providers.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_settings_repository.dart';

void main() {
  ProviderContainer containerWith(FakeSettingsRepository settings) {
    final container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('the theme falls back to following the system', () async {
    final container = containerWith(FakeSettingsRepository());
    expect(await container.read(themeModeProvider.future), ThemeMode.system);
  });

  test('a stored theme is read, and an unknown one reads as system', () async {
    final dark = containerWith(FakeSettingsRepository(values: {'theme_mode': 'dark'}));
    expect(await dark.read(themeModeProvider.future), ThemeMode.dark);

    final bogus = containerWith(FakeSettingsRepository(values: {'theme_mode': 'chartreuse'}));
    expect(await bogus.read(themeModeProvider.future), ThemeMode.system);
  });

  test('setting the theme stores its name', () async {
    final settings = FakeSettingsRepository();
    final container = containerWith(settings);
    await container.read(themeModeProvider.notifier).set(ThemeMode.light);
    expect(settings.values['theme_mode'], 'light');
    expect(container.read(themeModeProvider), const AsyncData(ThemeMode.light));
  });

  test('the focus target defaults to 180 minutes and reads a stored one', () async {
    final fallback = containerWith(FakeSettingsRepository());
    expect(await fallback.read(focusTargetProvider.future), 180);

    final stored = containerWith(
      FakeSettingsRepository(values: {dailyFocusTargetKey: '240'}),
    );
    expect(await stored.read(focusTargetProvider.future), 240);
  });

  test('setting the focus target stores its minutes', () async {
    final settings = FakeSettingsRepository();
    final container = containerWith(settings);
    await container.read(focusTargetProvider.notifier).set(300);
    expect(settings.values[dailyFocusTargetKey], '300');
    expect(await container.read(focusTargetProvider.future), 300);
  });

  test('the first day of week defaults to Monday, accepts Sunday, rejects anything else', () async {
    final fallback = containerWith(FakeSettingsRepository());
    expect(await fallback.read(firstDayOfWeekProvider.future), DateTime.monday);

    final sunday = containerWith(
      FakeSettingsRepository(values: {firstDayOfWeekKey: '7'}),
    );
    expect(await sunday.read(firstDayOfWeekProvider.future), DateTime.sunday);

    final bogus = containerWith(
      FakeSettingsRepository(values: {firstDayOfWeekKey: '3'}),
    );
    expect(await bogus.read(firstDayOfWeekProvider.future), DateTime.monday);
  });

  test('setting the first day of week stores the weekday', () async {
    final settings = FakeSettingsRepository();
    final container = containerWith(settings);
    await container.read(firstDayOfWeekNotifier);
    await container.read(firstDayOfWeekProvider.notifier).set(DateTime.sunday);
    expect(settings.values[firstDayOfWeekKey], '7');
  });

  test('unreadable settings leave every provider in error', () async {
    final settings = FakeSettingsRepository()..failReads = true;
    final container = containerWith(settings);
    expect(
      container.read(themeModeProvider.future),
      throwsA(isA<StateError>()),
    );
  });

  testWidgets('the app renders in dark mode when the setting says dark', (tester) async {
    final settings = FakeSettingsRepository(
      values: {onboardingDoneSettingKey: true, 'theme_mode': 'dark'},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
        child: const EnergyClockApp(),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(TabScaffold));
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}
```

> Note for the implementer: `onboardingDoneSettingKey` above stands for the existing `onboardingDoneKey` from `package:energy_clock/app/onboarding/onboarding_providers.dart` — import it and use that constant, never a literal string. If `container.read(firstDayOfWeekNotifier)` is flagged as unnecessary, drop that line; the `.set(...)` call builds the notifier itself.

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL - compile error: settings_providers.dart does not exist yet.
flutter test test/app/settings_test.dart
```

- [ ] **Step 3: Create the providers**

**Create `lib/app/settings/settings_providers.dart`**

```dart
import 'package:energy_clock/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The `settings` keys this file owns.
const String themeModeKey = 'theme_mode';
const String dailyFocusTargetKey = 'daily_focus_target';
const String firstDayOfWeekKey = 'first_day_of_week';

/// The focus target every score measures against, in minutes (spec §9.3).
const int defaultDailyFocusTargetMinutes = 180;

/// Light, dark, or following the system. A stored value that is not
/// 'light' or 'dark' reads as system, so a corrupt key never blocks the app.
final themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final stored = await ref.watch(settingsRepositoryProvider).getString(themeModeKey);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode mode) async {
    final name = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await ref.read(settingsRepositoryProvider).setString(themeModeKey, name);
    state = AsyncData(mode);
  }
}

/// The daily focus target in minutes. The settings card offers whole hours and
/// half hours; anything stored reads as-is once it parses.
final focusTargetProvider =
    AsyncNotifierProvider<FocusTargetNotifier, int>(FocusTargetNotifier.new);

class FocusTargetNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final stored = await ref.watch(settingsRepositoryProvider).getInt(dailyFocusTargetKey);
    return stored ?? defaultDailyFocusTargetMinutes;
  }

  Future<void> set(int minutes) async {
    await ref.read(settingsRepositoryProvider).setInt(dailyFocusTargetKey, minutes);
    state = AsyncData(minutes);
  }
}

/// The first day of the week: `DateTime.monday` (1) or `DateTime.sunday` (7).
/// Anything else reads as Monday, so a corrupt key cannot scramble calendars.
final firstDayOfWeekProvider =
    AsyncNotifierProvider<FirstDayOfWeekNotifier, int>(FirstDayOfWeekNotifier.new);

class FirstDayOfWeekNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final stored = await ref.watch(settingsRepositoryProvider).getInt(firstDayOfWeekKey);
    return stored == DateTime.sunday ? DateTime.sunday : DateTime.monday;
  }

  Future<void> set(int weekday) async {
    assert(weekday == DateTime.monday || weekday == DateTime.sunday);
    await ref.read(settingsRepositoryProvider).setInt(firstDayOfWeekKey, weekday);
    state = AsyncData(weekday);
  }
}
```

- [ ] **Step 4: Watch the theme in the app**

**Edit `lib/app/app.dart`** — three `Replace:` / `With:` pairs

Replace:
```dart
import 'package:energy_clock/app/navigation/tab_scaffold.dart';
```
With:
```dart
import 'package:energy_clock/app/navigation/tab_scaffold.dart';
import 'package:energy_clock/app/settings/settings_providers.dart';
```
(This import block is alphabetical: `navigation`, then `onboarding`, then `settings` — put `settings_providers` after `onboarding_providers`.)

Replace:
```dart
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
```
With:
```dart
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // While the stored choice is still loading, follow the system.
      themeMode: ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system,
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
# expect: PASS - 9 tests
flutter test test/app/settings_test.dart
```

- [ ] **Step 6: Analyze, run the suite, commit**

```bash
# expect: PASS - analyzer clean; whole suite green (1,375 tests)
flutter analyze && flutter test
```

```bash
# expect: RUN
git add lib/app/settings/settings_providers.dart lib/app/app.dart test/app/settings_test.dart
git commit -m "feat: theme, focus target and first-day-of-week settings providers

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

### Task 4: First day of week, threaded through the calendars

`startOfWeek`, `daysOfWeek` and `monthWeeks` gain an optional `firstWeekday` (default `DateTime.monday`, so every existing caller and test keeps its week); WeekStrip and MonthPage read `firstDayOfWeekProvider` and rotate their weekday labels.

**Files:**
- Modify: `lib/core/time/day_time.dart`, `lib/core/time/month_time.dart`, `lib/core/strings.dart`, `lib/features/clock/widgets/week_strip.dart`, `lib/features/calendar/widgets/month_page.dart`
- Test: `test/core/time/week_and_speech_test.dart`, `test/core/time/month_time_test.dart`, `test/core/strings_test.dart`, `test/features/clock/week_strip_test.dart`, `test/features/calendar/month_page_test.dart`

**Interfaces:**
- `startOfWeek(DateTime day, {int firstWeekday = DateTime.monday})`, `daysOfWeek(DateTime day, {int firstWeekday = DateTime.monday})` — `firstWeekday` is 1–7 (`DateTime.monday`…`DateTime.sunday`).
- `monthWeeks(DateTime month, {int firstWeekday = DateTime.monday})`.
- `Strings.weekdayShortStarting(int firstWeekday)` → the seven short names rotated so the first starts on `firstWeekday`.

- [ ] **Step 1: Write the failing tests**

**Edit `test/core/time/week_and_speech_test.dart`** — insert before the final closing `}` of `main()`:

```dart
    group('first day of week', () {
      test('a week can start on Sunday', () {
        // Wednesday 7 October 2026 sits in the Sunday 4 – Saturday 10 week.
        expect(
          startOfWeek(DateTime(2026, 10, 7), firstWeekday: DateTime.sunday),
          DateTime(2026, 10, 4),
        );
        // Monday belongs to the week that began the previous Sunday.
        expect(
          startOfWeek(DateTime(2026, 10, 5), firstWeekday: DateTime.sunday),
          DateTime(2026, 10, 4),
        );
      });

      test('a Sunday-start week enumerates Sunday first', () {
        final days = daysOfWeek(DateTime(2026, 10, 7), firstWeekday: DateTime.sunday);
        expect(days.first, DateTime(2026, 10, 4));
        expect(days.last, DateTime(2026, 10, 10));
        expect(days, hasLength(7));
      });

      test('the default is still Monday', () {
        expect(startOfWeek(DateTime(2026, 10, 7)), DateTime(2026, 10, 5));
        expect(startOfWeek(DateTime(2026, 10, 7), firstWeekday: DateTime.monday), DateTime(2026, 10, 5));
      });
    });
```

**Edit `test/core/time/month_time_test.dart`** — insert before the final closing `}` of `main()`:

```dart
    group('first day of week', () {
      test('a Sunday-first October starts its first row on 27 September', () {
        final weeks = monthWeeks(DateTime(2026, 10), firstWeekday: DateTime.sunday);
        expect(weeks.first, hasLength(7));
        // 1 October 2026 is a Thursday, so Sunday-first leaves four blanks.
        expect(weeks.first.take(4), everyElement(isNull));
        expect(weeks.first[4], DateTime(2026, 10, 1));
        expect(weeks, hasLength(5));
      });

      test('the default is still Monday', () {
        expect(monthWeeks(DateTime(2026, 10)), monthWeeks(DateTime(2026, 10), firstWeekday: DateTime.monday));
      });
    });
```

**Edit `test/core/strings_test.dart`** — insert before the final closing `}` of `main()`:

```dart
    test('weekdayShortStarting rotates the short names', () {
      expect(
        Strings.weekdayShortStarting(DateTime.sunday),
        ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
      );
      expect(Strings.weekdayShortStarting(DateTime.monday), Strings.weekdayShort);
      expect(Strings.weekdayShortStarting(DateTime.saturday), hasLength(7));
    });
```

**Edit `test/features/clock/week_strip_test.dart`** — insert after the first test ('shows the seven days of the selected week, Monday first'):

```dart
  testWidgets('shows the week Sunday-first when the setting says so', (tester) async {
    harness.settings.values['first_day_of_week'] = '7';
    await tester.pumpWidget(harness.app(const WeekStrip()));
    await tester.pumpAndSettle();

    // The same week, 4–10 October 2026, now starting on Sunday.
    for (final label in ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']) {
      expect(find.text(label), findsOneWidget);
    }
    for (final date in ['4', '5', '6', '7', '8', '9', '10']) {
      expect(find.text(date), findsOneWidget);
    }
  });
```

**Edit `test/features/calendar/month_page_test.dart`** — insert after the 'shows the weekday labels, Monday first' test:

```dart
  testWidgets('shows the weekday labels Sunday first when the setting says so', (tester) async {
    harness.settings.values['first_day_of_week'] = '7';
    await mount(tester);

    final rotated = Strings.weekdayShortStarting(DateTime.sunday);
    for (final name in rotated) {
      expect(find.text(name), findsOneWidget);
    }
    final labels = [
      for (final name in rotated) tester.getTopLeft(find.text(name)).dx,
    ];
    expect(labels, orderedEquals([...labels]..sort()));
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL - compile error: startOfWeek/dayWeeks/monthWeeks/weekdayShortStarting take no firstWeekday.
flutter test test/core/time/week_and_speech_test.dart test/core/time/month_time_test.dart \
  test/core/strings_test.dart test/features/clock/week_strip_test.dart \
  test/features/calendar/month_page_test.dart
```

- [ ] **Step 3: Thread the parameter through core**

**Edit `lib/core/time/day_time.dart`** — replace the `startOfWeek`/`daysOfWeek` pair:

Replace:
```dart
/// The Monday on or before [day], at local midnight. Weeks start on Monday
/// until the first-day-of-week setting exists. Calendar arithmetic, so a DST
/// change inside the week cannot move the result by a day.
DateTime startOfWeek(DateTime day) {
  final midnight = startOfDay(day);
  return DateTime(
    midnight.year,
    midnight.month,
    midnight.day - (midnight.weekday - DateTime.monday),
  );
}

/// The seven local midnights of the week containing [day], Monday first.
List<DateTime> daysOfWeek(DateTime day) {
  final first = startOfWeek(day);
  return [
    for (var i = 0; i < 7; i++)
      DateTime(first.year, first.month, first.day + i),
  ];
}
```
With:
```dart
/// The [firstWeekday] on or before [day], at local midnight. [firstWeekday] is
/// `DateTime.monday` … `DateTime.sunday` and defaults to Monday, so callers
/// that have not heard of the setting keep their week. Calendar arithmetic, so
/// a DST change inside the week cannot move the result by a day.
DateTime startOfWeek(DateTime day, {int firstWeekday = DateTime.monday}) {
  final midnight = startOfDay(day);
  final shift = (midnight.weekday - firstWeekday + 7) % 7;
  return DateTime(midnight.year, midnight.month, midnight.day - shift);
}

/// The seven local midnights of the week containing [day], starting on
/// [firstWeekday].
List<DateTime> daysOfWeek(DateTime day, {int firstWeekday = DateTime.monday}) {
  final first = startOfWeek(day, firstWeekday: firstWeekday);
  return [
    for (var i = 0; i < 7; i++)
      DateTime(first.year, first.month, first.day + i),
  ];
}
```

**Edit `lib/core/time/month_time.dart`** — replace `monthWeeks`:

Replace:
```dart
/// [month]'s month laid out as rows of seven cells, Monday first. A cell is
/// that day's local midnight, or null where the row runs outside the month.
List<List<DateTime?>> monthWeeks(DateTime month) {
  final first = startOfMonth(month);
  final leading = first.weekday - DateTime.monday;
```
With:
```dart
/// [month]'s month laid out as rows of seven cells, starting on [firstWeekday]
/// (`DateTime.monday` … `DateTime.sunday`, default Monday). A cell is that
/// day's local midnight, or null where the row runs outside the month.
List<List<DateTime?>> monthWeeks(
  DateTime month, {
  int firstWeekday = DateTime.monday,
}) {
  final first = startOfMonth(month);
  final leading = (first.weekday - firstWeekday + 7) % 7;
```

**Edit `lib/core/strings.dart`** — insert after the `weekdayInitials` list:

Replace:
```dart
  static const List<String> weekdayInitials = [
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];
```
With:
```dart
  static const List<String> weekdayInitials = [
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  /// The short weekday names reordered so they start on [firstWeekday]
  /// (`DateTime.monday` … `DateTime.sunday`).
  static List<String> weekdayShortStarting(int firstWeekday) => [
    for (var i = 0; i < 7; i++)
      weekdayShort[(firstWeekday - DateTime.monday + i) % 7],
  ];
```

- [ ] **Step 4: Watch the setting in WeekStrip**

**Edit `lib/features/clock/widgets/week_strip.dart`** — four `Replace:` / `With:` pairs

Replace:
```dart
import 'package:energy_clock/app/theme/app_colors.dart';
```
With:
```dart
import 'package:energy_clock/app/settings/settings_providers.dart';
import 'package:energy_clock/app/theme/app_colors.dart';
```

Replace:
```dart
/// Seven day pills for the week containing the selected day, Monday first.
```
With:
```dart
/// Seven day pills for the week containing the selected day, starting on the
/// first day of the week (the setting, Monday by default).
```

Replace:
```dart
  late final DateTime _anchorWeek;
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _anchorWeek = startOfWeek(ref.read(selectedDateProvider));
    _controller = PageController(initialPage: _centerPage);
  }
```
With:
```dart
  /// Mutable: the first-day-of-week setting may change after the strip was
  /// built, and the anchor is recomputed around the selected day then.
  late DateTime _anchorWeek;
  late final PageController _controller;

  int get _firstWeekday =>
      ref.read(firstDayOfWeekProvider).valueOrNull ?? DateTime.monday;

  @override
  void initState() {
    super.initState();
    _anchorWeek = startOfWeek(
      ref.read(selectedDateProvider),
      firstWeekday: _firstWeekday,
    );
    _controller = PageController(initialPage: _centerPage);
  }
```

Replace:
```dart
  void _onPageChanged(int page) {
    final weekStart = _weekForPage(page);
    final selected = ref.read(selectedDateProvider);
    final selectedWeek = startOfWeek(selected);
```
With:
```dart
  void _onPageChanged(int page) {
    final weekStart = _weekForPage(page);
    final selected = ref.read(selectedDateProvider);
    final selectedWeek = startOfWeek(selected, firstWeekday: _firstWeekday);
```

Replace:
```dart
    ref.listen(selectedDateProvider, (previous, next) {
      final page = _pageForWeek(startOfWeek(next));
      if (!_controller.hasClients || _controller.page?.round() == page) return;
```
With:
```dart
    final firstWeekday =
        ref.watch(firstDayOfWeekProvider).valueOrNull ?? DateTime.monday;

    ref.listen(selectedDateProvider, (previous, next) {
      final page = _pageForWeek(startOfWeek(next, firstWeekday: firstWeekday));
      if (!_controller.hasClients || _controller.page?.round() == page) return;
```

- [ ] **Step 5: Re-anchor when the setting changes, and order the row**

**Edit `lib/features/clock/widgets/week_strip.dart`** — two more pairs

Replace:
```dart
        );
      }
    });

    return SizedBox(
```
With:
```dart
        );
      }
    });

    // The first-day-of-week setting changed: rebuild the anchor around the
    // selected day and snap the page view to its week.
    ref.listen(firstDayOfWeekProvider, (previous, next) {
      final weekday = next.valueOrNull;
      if (weekday == null) return;
      final anchor = startOfWeek(
        ref.read(selectedDateProvider),
        firstWeekday: weekday,
      );
      if (anchor == _anchorWeek) return;
      setState(() => _anchorWeek = anchor);
      if (!_controller.hasClients) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.jumpToPage(_centerPage);
      } else {
        unawaited(
          _controller.animateToPage(
            _centerPage,
            duration: AppMotion.base,
            curve: AppMotion.standard,
          ),
        );
      }
    });

    return SizedBox(
```

Replace:
```dart
          child: _WeekRow(weekStart: _weekForPage(page), showDots: showDots),
```
With:
```dart
          child: _WeekRow(
            weekStart: _weekForPage(page),
            showDots: showDots,
            firstWeekday: firstWeekday,
          ),
```

Then in the same file, `_WeekRow` gains the field and uses it:

Replace:
```dart
class _WeekRow extends ConsumerWidget {
  const _WeekRow({required this.weekStart, required this.showDots});

  final DateTime weekStart;
  final bool showDots;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDateProvider);
```
With:
```dart
class _WeekRow extends ConsumerWidget {
  const _WeekRow({
    required this.weekStart,
    required this.showDots,
    required this.firstWeekday,
  });

  final DateTime weekStart;
  final bool showDots;
  final int firstWeekday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDateProvider);
```

Replace:
```dart
          for (final day in daysOfWeek(weekStart))
```
With:
```dart
          for (final day in daysOfWeek(weekStart, firstWeekday: firstWeekday))
```

- [ ] **Step 6: Watch the setting in MonthPage**

**Edit `lib/features/calendar/widgets/month_page.dart`** — four pairs

Replace:
```dart
import 'package:energy_clock/app/theme/app_colors.dart';
```
With:
```dart
import 'package:energy_clock/app/settings/settings_providers.dart';
import 'package:energy_clock/app/theme/app_colors.dart';
```

Replace:
```dart
/// Weeks start on Monday; days outside the month are blank. The page scrolls
```
With:
```dart
/// Weeks start on the first day of the week (Monday by default); days outside
/// the month are blank. The page scrolls
```

Replace:
```dart
    final load = ref.watch(monthLoadProvider(startOfMonth(month)));
    final planned = load.valueOrNull ?? const <DateTime, ToneMinutes>{};
```
With:
```dart
    final load = ref.watch(monthLoadProvider(startOfMonth(month)));
    final planned = load.valueOrNull ?? const <DateTime, ToneMinutes>{};
    final firstWeekday =
        ref.watch(firstDayOfWeekProvider).valueOrNull ?? DateTime.monday;
```

Replace:
```dart
                                for (final name in Strings.weekdayShort)
```
With:
```dart
                                for (final name
                                    in Strings.weekdayShortStarting(firstWeekday))
```

Replace:
```dart
                        for (final week in monthWeeks(month)) ...[
```
With:
```dart
                        for (final week
                            in monthWeeks(month, firstWeekday: firstWeekday)) ...[
```

- [ ] **Step 7: Run the tests to verify they pass**

```bash
# expect: PASS - the five test files pass (core defaults unchanged, Sunday variants green)
flutter test test/core/time/week_and_speech_test.dart test/core/time/month_time_test.dart \
  test/core/strings_test.dart test/features/clock/week_strip_test.dart \
  test/features/calendar/month_page_test.dart
```

- [ ] **Step 8: Analyze, run the suite, commit**

```bash
# expect: PASS - analyzer clean; whole suite green (all existing calendar/clock tests untouched by design)
flutter analyze && flutter test
```

```bash
# expect: RUN
git add lib/core/time/day_time.dart lib/core/time/month_time.dart lib/core/strings.dart \
  lib/features/clock/widgets/week_strip.dart lib/features/calendar/widgets/month_page.dart \
  test/core/time/week_and_speech_test.dart test/core/time/month_time_test.dart \
  test/core/strings_test.dart test/features/clock/week_strip_test.dart \
  test/features/calendar/month_page_test.dart
git commit -m "feat: first day of week drives weeks and month grids

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

## Stage 2 — Stats data, charts, screen

### Task 5: StatsDao and StatsRepository

Four grouped queries over `events ⋈ sessions` plus the materialise-then-watch stream. Seconds are summed per `(day, tone)` cell and truncated to minutes in Dart, so the repository and its fake agree exactly. One `tableUpdates()` stream (no filter: every table update) triggers reloads; materialisation failure shows the window as stored, exactly like the Calendar.

**Files:**
- Create: `lib/data/daos/stats_dao.dart`, `lib/data/repositories/stats_repository.dart`
- Modify: `lib/data/database.dart` (register `StatsDao`), `lib/data/providers.dart` (add `statsRepositoryProvider`)
- Test: `test/data/stats_dao_test.dart` (new)

**Interfaces:**
- `StatsDao` (drift accessor on `[Events, Sessions]`): `toneSecondsByDay(from, to)` → `List<({DateTime date, int toneIndex, int seconds})>`; `plannedMinutesByTone(from, to)` → `List<({int toneIndex, int minutes})>`; `focusInstants(from, to, toneIndex)` → `List<({DateTime startedAt, int activeSeconds})>` ordered by `startedAt`; `focusOutcomeCounts(from, to, toneIndex)` → `({int ended, int abandoned})`.
- `StatsRepository` interface: `Stream<StatsSnapshot> watchWindow(DateTime from, DateTime toExclusive)`.
- `StatsSnapshot` (const, plus `StatsSnapshot.empty()`): `toneByDay: List<ToneDayMinutes>`, `plannedByTone: List<TonePlannedActual>` (all three tones, even at 0), `focus: FocusDepth`, `focusInstants: List<FocusInstant>`; getters `plannedTotal`, `completedTotal`, `adherencePercent` (`int?`, null when nothing was planned, `.round()`), `isEmpty`.
- `FocusDepth` (const, plus `FocusDepth.zero()`): `minutes`, `longestSeconds`, `averageSeconds`, `ended`, `abandoned`; `abandonmentRate` (`double?`, null when `ended == 0`).
- Truncation rule, stated once: per `(day, tone)` cell (`seconds ~/ 60`); per-tone completed minutes are the sum of their day cells; focus totals truncate the window sum once.

- [ ] **Step 1: Write the failing tests**

**Create `test/data/stats_dao_test.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:energy_clock/core/session/session_outcome.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/stats_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftStatsRepository repository;

  // October 2026: the 5th is a Monday.
  final monday = DateTime(2026, 10, 5);
  final nextMonday = DateTime(2026, 10, 12);
  final now = DateTime(2026, 10, 7, 12);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftStatsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> seedEvent({
    required DateTime date,
    Tone tone = Tone.focus,
    int start = 540,
    int end = 600,
    int status = 0,
  }) => db.eventDao.insertEvent(
    EventsCompanion.insert(
      date: date,
      title: 'Event',
      toneIndex: tone.dbIndex,
      startMinute: start,
      endMinute: end,
      status: Value(status),
      createdAt: now,
      updatedAt: now,
    ),
  );

  Future<void> seedSession({
    required int eventId,
    SessionOutcome outcome = SessionOutcome.completed,
    int activeSeconds = 3600,
    DateTime? startedAt,
  }) => db.sessionDao.insertSession(
    SessionsCompanion.insert(
      eventId: eventId,
      startedAt: startedAt ?? DateTime(2026, 10, 6, 9),
      plannedSeconds: 3600,
      activeSeconds: Value(activeSeconds),
      outcome: Value(outcome.dbIndex),
    ),
  );

  Future<StatsSnapshot> snapshot() =>
      repository.watchWindow(monday, nextMonday).first;

  test('countsAsDone minutes group per day and tone, on the event date', () async {
    final focus = await seedEvent(date: DateTime(2026, 10, 6));
    final life = await seedEvent(date: DateTime(2026, 10, 6), tone: Tone.life, start: 660, end: 720);
    await seedSession(eventId: focus, activeSeconds: 5400);
    await seedSession(eventId: focus, outcome: SessionOutcome.finishedEarly, activeSeconds: 1800);
    await seedSession(eventId: life, activeSeconds: 3600);

    final stats = await snapshot();
    expect(stats.toneByDay, [
      (date: DateTime(2026, 10, 6), tone: Tone.focus, minutes: 120),
      (date: DateTime(2026, 10, 6), tone: Tone.life, minutes: 60),
    ]);
  });

  test('abandoned, running and deleted sessions contribute nothing', () async {
    final focus = await seedEvent(date: DateTime(2026, 10, 6));
    final deleted = await seedEvent(date: DateTime(2026, 10, 6), status: 2);
    await seedSession(eventId: focus, outcome: SessionOutcome.abandoned, activeSeconds: 1800);
    await seedSession(eventId: focus, outcome: SessionOutcome.running, activeSeconds: 600);
    await seedSession(eventId: deleted, activeSeconds: 3600);

    final stats = await snapshot();
    expect(stats.toneByDay, isEmpty);
    expect(stats.completedTotal, 0);
    expect(stats.focus.ended, 1);
  });

  test('seconds truncate after grouping, not per session', () async {
    final focus = await seedEvent(date: DateTime(2026, 10, 6));
    await seedSession(eventId: focus, activeSeconds: 50);
    await seedSession(eventId: focus, activeSeconds: 50);

    final stats = await snapshot();
    // 100 seconds in one cell is a minute; truncated per session it would be 0.
    expect(stats.toneByDay.single.minutes, 1);
  });

  test('planned counts every stored event, completed folds the pool', () async {
    final focus = await seedEvent(date: DateTime(2026, 10, 6), start: 540, end: 660);
    await seedEvent(date: DateTime(2026, 10, 6), tone: Tone.life, start: 660, end: 720);
    await seedSession(eventId: focus, activeSeconds: 5400);

    final stats = await snapshot();
    expect(stats.plannedTotal, 180);
    expect(stats.completedTotal, 150);
    expect(stats.adherencePercent, 83);
    expect(stats.plannedByTone, [
      (tone: Tone.focus, plannedMinutes: 120, completedMinutes: 90),
      (tone: Tone.life, plannedMinutes: 60, completedMinutes: 60),
      (tone: Tone.inbox, plannedMinutes: 0, completedMinutes: 0),
    ]);
  });

  test('focus depth totals the pool but rates every ended session', () async {
    final focus = await seedEvent(date: DateTime(2026, 10, 6));
    final life = await seedEvent(date: DateTime(2026, 10, 6), tone: Tone.life);
    await seedSession(eventId: focus, activeSeconds: 900);
    await seedSession(eventId: focus, activeSeconds: 300);
    await seedSession(eventId: focus, outcome: SessionOutcome.abandoned, activeSeconds: 1200);
    await seedSession(eventId: life, activeSeconds: 3600);

    final stats = await snapshot();
    expect(stats.focus.minutes, 20);
    expect(stats.focus.longestSeconds, 900);
    expect(stats.focus.averageSeconds, 600);
    expect(stats.focus.ended, 3);
    expect(stats.focus.abandoned, 1);
  });

  test('focus instants are ordered, focus-only and countsAsDone-only', () async {
    final focus = await seedEvent(date: DateTime(2026, 10, 6));
    final life = await seedEvent(date: DateTime(2026, 10, 6), tone: Tone.life);
    await seedSession(eventId: focus, startedAt: DateTime(2026, 10, 6, 14), activeSeconds: 1800);
    await seedSession(eventId: focus, startedAt: DateTime(2026, 10, 6, 9), activeSeconds: 900);
    await seedSession(eventId: focus, outcome: SessionOutcome.abandoned, startedAt: DateTime(2026, 10, 6, 8));
    await seedSession(eventId: life, startedAt: DateTime(2026, 10, 6, 7));

    final stats = await snapshot();
    expect(stats.focusInstants, [
      (startedAt: DateTime(2026, 10, 6, 9), activeSeconds: 900),
      (startedAt: DateTime(2026, 10, 6, 14), activeSeconds: 1800),
    ]);
  });

  test('days outside the window are excluded either side', () async {
    await seedSession(eventId: await seedEvent(date: DateTime(2026, 10, 4)));
    await seedSession(eventId: await seedEvent(date: DateTime(2026, 10, 5)));
    await seedSession(eventId: await seedEvent(date: DateTime(2026, 10, 11)));
    await seedSession(eventId: await seedEvent(date: DateTime(2026, 10, 12)));

    final stats = await snapshot();
    expect(
      stats.toneByDay.map((cell) => cell.date),
      [DateTime(2026, 10, 5), DateTime(2026, 10, 11)],
    );
  });

  test('an empty window reads empty, with no adherence and no rate', () async {
    final stats = await snapshot();
    expect(stats.isEmpty, isTrue);
    expect(stats.adherencePercent, isNull);
    expect(stats.focus.abandonmentRate, isNull);
  });

  test('the stream emits again when a session is added', () async {
    final id = await seedEvent(date: DateTime(2026, 10, 6));
    final emissions = repository.watchWindow(monday, nextMonday).take(2).toList();
    await Future<void>.delayed(Duration.zero);
    await seedSession(eventId: id, activeSeconds: 3600);

    final snapshots = await emissions;
    expect(snapshots, hasLength(2));
    expect(snapshots.first.isEmpty, isTrue);
    expect(snapshots.last.completedTotal, 60);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL - compile error: StatsRepository, DriftStatsRepository and StatsDao do not exist yet.
flutter test test/data/stats_dao_test.dart
```

- [ ] **Step 3: Create the DAO**

**Create `lib/data/daos/stats_dao.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:energy_clock/core/session/session_outcome.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/tables/events_table.dart';
import 'package:energy_clock/data/tables/sessions_table.dart';

part 'stats_dao.g.dart';

/// Grouped statistics over `events ⋈ sessions` (spec §8). Every query filters
/// to one window, attributes minutes to the event's local date, and counts
/// only `completed` and `finishedEarly` sessions. Minutes are derived from the
/// returned seconds in the repository, after grouping.
@DriftAccessor(tables: [Events, Sessions])
class StatsDao extends DatabaseAccessor<AppDatabase> with _$StatsDaoMixin {
  StatsDao(super.attachedDatabase);

  /// `events.status == 2` is a deleted occurrence of a series (see EventDao):
  /// it contributes nothing to any total.
  static const _skipped = 2;

  static Expression<bool> get _countsAsDone => sessions.outcome.isIn([
    SessionOutcome.completed.dbIndex,
    SessionOutcome.finishedEarly.dbIndex,
  ]);

  Expression<bool> _inWindow(DateTime from, DateTime toExclusive) =>
      events.date.isBiggerOrEqualValue(from) &
      events.date.isSmallerThanValue(toExclusive) &
      events.status.isNotValue(_skipped);

  /// `countsAsDone` seconds per (event date, tone): one row per cell that has
  /// sessions.
  Future<List<({DateTime date, int toneIndex, int seconds})>> toneSecondsByDay(
    DateTime from,
    DateTime toExclusive,
  ) {
    final seconds = sessions.activeSeconds.sum();
    final query =
        selectOnly(events)
          ..addColumns([events.date, events.toneIndex, seconds])
          ..join([
            innerJoin(sessions, sessions.eventId.equalsExp(events.id)),
          ])
          ..where(_inWindow(from, toExclusive) & _countsAsDone)
          ..groupBy([events.date, events.toneIndex]);
    return query
        .map(
          (row) => (
            date: row.read(events.date)!,
            toneIndex: row.read(events.toneIndex)!,
            seconds: row.read(seconds) ?? 0,
          ),
        )
        .get();
  }

  /// Planned whole minutes per tone, for every stored event regardless of
  /// sessions. Overlapping events count twice, like the Calendar's rings.
  Future<List<({int toneIndex, int minutes})>> plannedMinutesByTone(
    DateTime from,
    DateTime toExclusive,
  ) {
    final minutes = (events.endMinute - events.startMinute).sum();
    final query =
        selectOnly(events)
          ..addColumns([events.toneIndex, minutes])
          ..where(_inWindow(from, toExclusive))
          ..groupBy([events.toneIndex]);
    return query
        .map(
          (row) => (
            toneIndex: row.read(events.toneIndex)!,
            minutes: row.read(minutes) ?? 0,
          ),
        )
        .get();
  }

  /// `(startedAt, activeSeconds)` of every `countsAsDone` session on [toneIndex]
  /// in the window, oldest first. The heatmap buckets these in Dart.
  Future<List<({DateTime startedAt, int activeSeconds})>> focusInstants(
    DateTime from,
    DateTime toExclusive,
    int toneIndex,
  ) {
    final query =
        select(sessions).join([
            innerJoin(events, events.id.equalsExp(sessions.eventId)),
          ])
          ..where(
            _inWindow(from, toExclusive) &
                events.toneIndex.equals(toneIndex) &
                _countsAsDone,
          )
          ..orderBy([OrderingTerm.asc(sessions.startedAt)]);
    return query.map((row) {
      final session = row.readTable(sessions);
      return (
        startedAt: session.startedAt,
        activeSeconds: session.activeSeconds,
      );
    }).get();
  }

  /// Ended versus abandoned sessions on [toneIndex] in the window: the two
  /// denominators the focus section rates with.
  Future<({int ended, int abandoned})> focusOutcomeCounts(
    DateTime from,
    DateTime toExclusive,
    int toneIndex,
  ) {
    final ended = countAll(
      filter: sessions.outcome.isNotValue(SessionOutcome.running.dbIndex),
    );
    final abandoned = countAll(
      filter: sessions.outcome.equals(SessionOutcome.abandoned.dbIndex),
    );
    final query =
        selectOnly(events)
          ..addColumns([ended, abandoned])
          ..join([
            innerJoin(sessions, sessions.eventId.equalsExp(events.id)),
          ])
          ..where(
            _inWindow(from, toExclusive) &
                events.toneIndex.equals(toneIndex) &
                sessions.outcome.isNotValue(SessionOutcome.running.dbIndex),
          );
    return query
        .map(
          (row) => (
            ended: row.read(ended) ?? 0,
            abandoned: row.read(abandoned) ?? 0,
          ),
        )
        .getSingle();
  }
}
```

- [ ] **Step 4: Create the repository and register everything**

**Create `lib/data/repositories/stats_repository.dart`**

```dart
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/series_materialiser.dart';

/// Completed minutes for one tone on one local day.
typedef ToneDayMinutes = ({DateTime date, Tone tone, int minutes});

/// Planned against completed minutes for one tone over a whole window.
typedef TonePlannedActual = ({
  Tone tone,
  int plannedMinutes,
  int completedMinutes,
});

/// One `countsAsDone` focus session: when it began, how long was worked.
typedef FocusInstant = ({DateTime startedAt, int activeSeconds});

/// Focus depth over a window (spec §8.3): totals over the `countsAsDone` pool,
/// the abandonment rate over every ended session.
class FocusDepth {
  const FocusDepth({
    required this.minutes,
    required this.longestSeconds,
    required this.averageSeconds,
    required this.ended,
    required this.abandoned,
  });

  const FocusDepth.zero()
    : this(minutes: 0, longestSeconds: 0, averageSeconds: 0, ended: 0, abandoned: 0);

  final int minutes;
  final int longestSeconds;
  final int averageSeconds;
  final int ended;
  final int abandoned;

  /// Null when nothing ended: callers show `—`.
  double? get abandonmentRate => ended == 0 ? null : abandoned / ended;
}

/// Everything the Stats tab shows for one window.
class StatsSnapshot {
  const StatsSnapshot({
    required this.toneByDay,
    required this.plannedByTone,
    required this.focus,
    required this.focusInstants,
  });

  const StatsSnapshot.empty()
    : this(
        toneByDay: const [],
        plannedByTone: const [],
        focus: const FocusDepth.zero(),
        focusInstants: const [],
      );

  /// Completed minutes per (day, tone) cell, day then tone order.
  final List<ToneDayMinutes> toneByDay;

  /// One row per tone, even at zero.
  final List<TonePlannedActual> plannedByTone;
  final FocusDepth focus;
  final List<FocusInstant> focusInstants;

  int get plannedTotal =>
      plannedByTone.fold(0, (sum, row) => sum + row.plannedMinutes);
  int get completedTotal =>
      plannedByTone.fold(0, (sum, row) => sum + row.completedMinutes);

  /// Rounded percent, or null when nothing was planned.
  int? get adherencePercent =>
      plannedTotal == 0 ? null : (completedTotal * 100 / plannedTotal).round();

  bool get isEmpty =>
      plannedTotal == 0 && completedTotal == 0 && focus.ended == 0;
}

/// What the Stats tab reads: one snapshot per window.
abstract interface class StatsRepository {
  /// Materialises recurring events into `[from, toExclusive)` first, then
  /// emits the snapshot and emits again on every database change.
  Stream<StatsSnapshot> watchWindow(DateTime from, DateTime toExclusive);
}

class DriftStatsRepository implements StatsRepository {
  DriftStatsRepository(this._db, {SeriesMaterialiser? materialiser})
    : _materialiser = materialiser;

  final AppDatabase _db;
  final SeriesMaterialiser? _materialiser;

  @override
  Stream<StatsSnapshot> watchWindow(
    DateTime from,
    DateTime toExclusive,
  ) async* {
    final materialiser = _materialiser;
    if (materialiser != null) {
      try {
        await materialiser.materialise(from, toExclusive);
      } on Object {
        // Show the window as stored: a failed expansion must not blank Stats.
      }
    }
    yield await _load(from, toExclusive);
    await for (final _ in _db.tableUpdates()) {
      yield await _load(from, toExclusive);
    }
  }

  /// Seconds truncate to minutes once per (day, tone) cell; per-tone
  /// completed minutes are the sum of their day cells.
  Future<StatsSnapshot> _load(DateTime from, DateTime toExclusive) =>
      _db.transaction(() async {
        final cells = await _db.statsDao.toneSecondsByDay(from, toExclusive);
        final planned = await _db.statsDao.plannedMinutesByTone(
          from,
          toExclusive,
        );
        final instants = await _db.statsDao.focusInstants(
          from,
          toExclusive,
          Tone.focus.dbIndex,
        );
        final outcomes = await _db.statsDao.focusOutcomeCounts(
          from,
          toExclusive,
          Tone.focus.dbIndex,
        );

        final toneByDay = <ToneDayMinutes>[
          for (final cell in cells)
            (
              date: cell.date,
              tone: Tone.fromDbIndex(cell.toneIndex),
              minutes: cell.seconds ~/ 60,
            ),
        ]..sort((a, b) {
          final days = a.date.compareTo(b.date);
          return days != 0
              ? days
              : a.tone.dbIndex.compareTo(b.tone.dbIndex);
        });

        final plannedByToneIndex = <int, int>{
          for (final row in planned) row.toneIndex: row.minutes,
        };
        final completedByTone = <Tone, int>{};
        for (final cell in toneByDay) {
          completedByTone[cell.tone] =
              (completedByTone[cell.tone] ?? 0) + cell.minutes;
        }
        final plannedByTone = <TonePlannedActual>[
          for (final tone in Tone.values)
            (
              tone: tone,
              plannedMinutes: plannedByToneIndex[tone.dbIndex] ?? 0,
              completedMinutes: completedByTone[tone] ?? 0,
            ),
        ];

        final focusSeconds = instants.fold(
          0,
          (sum, instant) => sum + instant.activeSeconds,
        );
        return StatsSnapshot(
          toneByDay: toneByDay,
          plannedByTone: plannedByTone,
          focus: FocusDepth(
            minutes: focusSeconds ~/ 60,
            longestSeconds: instants.fold(
              0,
              (longest, instant) =>
                  instant.activeSeconds > longest
                      ? instant.activeSeconds
                      : longest,
            ),
            averageSeconds:
                instants.isEmpty ? 0 : focusSeconds ~/ instants.length,
            ended: outcomes.ended,
            abandoned: outcomes.abandoned,
          ),
          focusInstants: instants,
        );
      });
}
```

**Edit `lib/data/database.dart`** — two pairs

Replace:
```dart
import 'package:energy_clock/data/daos/settings_dao.dart';
```
With:
```dart
import 'package:energy_clock/data/daos/settings_dao.dart';
import 'package:energy_clock/data/daos/stats_dao.dart';
```

Replace:
```dart
  daos: [EventDao, SettingsDao, SessionDao, SeriesDao, TemplateDao],
```
With:
```dart
  daos: [EventDao, SettingsDao, SessionDao, SeriesDao, TemplateDao, StatsDao],
```

**Edit `lib/data/providers.dart`** — two pairs

Replace:
```dart
import 'package:energy_clock/data/repositories/settings_repository.dart';
```
With:
```dart
import 'package:energy_clock/data/repositories/settings_repository.dart';
import 'package:energy_clock/data/repositories/stats_repository.dart';
```

Replace:
```dart
/// How each day of a month is planned, for the Calendar tab.
```
With:
```dart
/// Grouped statistics over a week or month, for the Stats tab (spec §8).
final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return DriftStatsRepository(
    ref.watch(appDatabaseProvider),
    materialiser: ref.watch(seriesMaterialiserProvider),
  );
});

/// How each day of a month is planned, for the Calendar tab.
```

- [ ] **Step 5: Regenerate**

```bash
# expect: RUN - regenerates stats_dao.g.dart and database.g.dart (StatsDao accessor)
DART="$(dirname "$(which flutter)")/dart"
"$DART" run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 6: Run the tests to verify they pass**

```bash
# expect: PASS - 9 tests
flutter test test/data/stats_dao_test.dart
```

- [ ] **Step 7: Analyze, run the suite, commit**

```bash
# expect: PASS - analyzer clean; whole suite green
flutter analyze && flutter test
```

```bash
# expect: RUN
git add lib/data/daos/stats_dao.dart lib/data/daos/stats_dao.g.dart \
  lib/data/repositories/stats_repository.dart lib/data/database.dart lib/data/database.g.dart \
  lib/data/providers.dart test/data/stats_dao_test.dart
git commit -m "feat: stats repository with grouped week and month queries

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

### Task 6: Stats period, window, heatmap bucketing, providers, fake

The UI state: which week or month is shown, the concrete window it maps to (first-day-of-week aware), and the 7×24 heatmap matrix built in Dart. Plus the in-memory fake the screen tests will use.

**Files:**
- Create: `lib/features/stats/model/stats_period.dart`, `lib/features/stats/model/heatmap.dart`, `lib/features/stats/providers.dart`, `test/support/fake_stats_repository.dart`
- Test: `test/features/stats/stats_providers_test.dart` (new)

**Interfaces:**
- `StatsPeriodKind { week, month }`; `StatsPeriod.week(anchor)` / `.month(anchor)` (anchor: local midnight inside the period); `StatsWindow = ({DateTime from, DateTime toExclusive, int dayCount})`.
- `StatsPeriodNotifier` (`NotifierProvider`): `build()` = current week; `setKind`, `previous()`, `next()` (never into the future), `returnToNow()` (keeps the kind).
- `statsPeriodProvider`, `statsWindowProvider` (week: 7 days from `startOfWeek(anchor, firstWeekday:)`; month: `startOfMonth` → `addMonths(+1)`, `daysInMonth`), `statsDataProvider` (`StreamProvider<StatsSnapshot>`; watches the period *and* the first-day setting, so a setting change re-queries the new window).
- `buildHeatmap(List<FocusInstant> instants, {int firstWeekday})` → 7 rows × 24 columns of whole minutes, row 0 = `firstWeekday`; seconds summed per cell, then truncated.
- `FakeStatsRepository`: seeded `snapshot`, `requests` log, `emit(next)` re-emits, `dispose()`.

- [ ] **Step 1: Write the failing tests**

**Create `test/features/stats/stats_providers_test.dart`**

```dart
import 'package:energy_clock/app/settings/settings_providers.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/stats_repository.dart';
import 'package:energy_clock/features/stats/model/heatmap.dart';
import 'package:energy_clock/features/stats/model/stats_period.dart';
import 'package:energy_clock/features/stats/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_settings_repository.dart';
import '../../../support/fake_stats_repository.dart';

void main() {
  late FakeSettingsRepository settings;
  late FakeStatsRepository stats;
  late ProviderContainer container;

  // Wednesday 7 October 2026.
  final wednesday = DateTime(2026, 10, 7);

  setUp(() {
    settings = FakeSettingsRepository();
    stats = FakeStatsRepository();
    container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        statsRepositoryProvider.overrideWithValue(stats),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    stats.dispose();
  });

  void setWeek(DateTime anchor) {
    container.read(statsPeriodProvider.notifier).state = StatsPeriod.week(
      anchor,
    );
  }

  test('the initial period is the current week', () {
    final period = container.read(statsPeriodProvider);
    expect(period.kind, StatsPeriodKind.week);
    expect(period.anchor.isBefore(DateTime.now().add(const Duration(days: 1))), isTrue);
  });

  test('switching kind keeps the anchor', () {
    setWeek(wednesday);
    container.read(statsPeriodProvider.notifier).setKind(StatsPeriodKind.month);
    final period = container.read(statsPeriodProvider);
    expect(period.kind, StatsPeriodKind.month);
    expect(period.anchor, wednesday);
  });

  test('previous moves a week and a month back', () {
    setWeek(wednesday);
    container.read(statsPeriodProvider.notifier).previous();
    expect(
      container.read(statsPeriodProvider).anchor,
      DateTime(2026, 9, 30),
    );

    container.read(statsPeriodProvider.notifier).setKind(StatsPeriodKind.month);
    container.read(statsPeriodProvider.notifier).previous();
    expect(
      container.read(statsPeriodProvider).anchor,
      DateTime(2026, 9, 7),
    );
  });

  test('next never enters the future', () {
    setWeek(DateTime(2026, 9, 30));
    final notifier = container.read(statsPeriodProvider.notifier);
    notifier.next();
    final back = container.read(statsPeriodProvider).anchor;
    expect(back.isAfter(DateTime(2026, 9, 30)), isTrue);
    expect(back.isBefore(DateTime.now().add(const Duration(days: 8))), isTrue);

    // From the current week, next is a no-op.
    notifier.returnToNow();
    final current = container.read(statsPeriodProvider).anchor;
    notifier.next();
    expect(container.read(statsPeriodProvider).anchor, current);
  });

  test('a month window spans the calendar month', () {
    container.read(statsPeriodProvider.notifier).state = StatsPeriod.month(
      DateTime(2026, 10, 15),
    );
    expect(container.read(statsWindowProvider), (
      from: DateTime(2026, 10),
      toExclusive: DateTime(2026, 11),
      dayCount: 31,
    ));
  });

  test('a week window starts on the first day of the week', () {
    setWeek(wednesday);
    expect(container.read(statsWindowProvider).from, DateTime(2026, 10, 5));

    settings.values['first_day_of_week'] = '7';
    container.invalidate(firstDayOfWeekProvider);
    expect(container.read(statsWindowProvider).from, DateTime(2026, 10, 4));
  });

  test('the heatmap buckets by local weekday and hour, rows rotated', () {
    final instants = [
      (startedAt: DateTime(2026, 10, 5, 9, 5), activeSeconds: 3600),
      (startedAt: DateTime(2026, 10, 5, 9, 40), activeSeconds: 1800),
      (startedAt: DateTime(2026, 10, 11, 22), activeSeconds: 600),
    ];
    final mondayFirst = buildHeatmap(instants);
    expect(mondayFirst, hasLength(7));
    expect(mondayFirst.every((row) => row.length == 24), isTrue);
    expect(mondayFirst[0][9], 90);
    expect(mondayFirst[6][22], 10);

    // Sunday-first: Monday's 09:00 cell moves to row 1, Sunday's to row 0.
    final sundayFirst = buildHeatmap(instants, firstWeekday: DateTime.sunday);
    expect(sundayFirst[1][9], 90);
    expect(sundayFirst[0][22], 10);
  });

  test('the heatmap truncates per cell after summing', () {
    final instants = [
      (startedAt: DateTime(2026, 10, 5, 9), activeSeconds: 30),
      (startedAt: DateTime(2026, 10, 5, 9, 30), activeSeconds: 30),
    ];
    expect(buildHeatmap(instants)[0][9], 1);
    expect(buildHeatmap(const [])[3][12], 0);
  });

  test('the data provider serves the fake snapshot and records its window', () async {
    setWeek(wednesday);
    stats.emit(
      StatsSnapshot(
        toneByDay: const [
          (date: DateTime(2026, 10, 6), tone: Tone.focus, minutes: 90),
        ],
        plannedByTone: const [],
        focus: const FocusDepth.zero(),
        focusInstants: const [],
      ),
    );

    final snapshot = await container.read(statsDataProvider.future);
    expect(snapshot.completedTotal, 90);
    expect(stats.requests.single, (
      from: DateTime(2026, 10, 5),
      to: DateTime(2026, 10, 12),
    ));
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL - compile error: stats_period.dart, heatmap.dart, providers.dart and FakeStatsRepository do not exist yet.
flutter test test/features/stats/stats_providers_test.dart
```

- [ ] **Step 3: Create the period model**

**Create `lib/features/stats/model/stats_period.dart`**

```dart
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/time/month_time.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which shape of past the Stats tab shows.
enum StatsPeriodKind { week, month }

/// One week or one month, pinned by a local midnight inside it.
class StatsPeriod {
  const StatsPeriod.week(this.anchor) : kind = StatsPeriodKind.week;
  const StatsPeriod.month(this.anchor) : kind = StatsPeriodKind.month;

  final StatsPeriodKind kind;
  final DateTime anchor;
}

/// The concrete window a period maps to. `toExclusive` is a local midnight.
typedef StatsWindow = ({DateTime from, DateTime toExclusive, int dayCount});

/// The shown period. Starts on the current week; the chevrons never move past
/// it. Uses the wall clock directly: no feature may import the Clock's
/// providers, and the tests pin the state explicitly.
class StatsPeriodNotifier extends Notifier<StatsPeriod> {
  @override
  StatsPeriod build() => StatsPeriod.week(startOfDay(DateTime.now()));

  void setKind(StatsPeriodKind kind) {
    if (state.kind == kind) return;
    state =
        kind == StatsPeriodKind.week
            ? StatsPeriod.week(state.anchor)
            : StatsPeriod.month(state.anchor);
  }

  void previous() {
    final anchor = state.anchor;
    state = switch (state.kind) {
      StatsPeriodKind.week => StatsPeriod.week(
        DateTime(anchor.year, anchor.month, anchor.day - 7),
      ),
      StatsPeriodKind.month => StatsPeriod.month(addMonths(anchor, -1)),
    };
  }

  void next() {
    final anchor = state.anchor;
    final candidate = switch (state.kind) {
      StatsPeriodKind.week => StatsPeriod.week(
        DateTime(anchor.year, anchor.month, anchor.day + 7),
      ),
      StatsPeriodKind.month => StatsPeriod.month(addMonths(anchor, 1)),
    };
    if (_startsAfterNow(candidate)) return;
    state = candidate;
  }

  void returnToNow() {
    final today = startOfDay(DateTime.now());
    state =
        state.kind == StatsPeriodKind.week
            ? StatsPeriod.week(today)
            : StatsPeriod.month(today);
  }

  bool _startsAfterNow(StatsPeriod candidate) {
    final now = startOfDay(DateTime.now());
    return switch (candidate.kind) {
      StatsPeriodKind.week => startOfWeek(
        candidate.anchor,
      ).isAfter(startOfWeek(now)),
      StatsPeriodKind.month => startOfMonth(
        candidate.anchor,
      ).isAfter(startOfMonth(now)),
    };
  }
}
```

- [ ] **Step 4: Create the heatmap bucketer**

**Create `lib/features/stats/model/heatmap.dart`**

```dart
import 'package:energy_clock/data/repositories/stats_repository.dart'
    show FocusInstant;

/// The 7×24 focus matrix: seven rows starting on [firstWeekday], each with 24
/// hour cells of whole minutes. Bucketing happens in Dart because the database
/// stores instants as epoch seconds, which SQLite cannot bucket into local
/// weekdays without mis-bucketing across timezones and DST. Seconds are summed
/// per cell, then truncated.
List<List<int>> buildHeatmap(
  List<FocusInstant> instants, {
  int firstWeekday = DateTime.monday,
}) {
  final secondsByCell = List.generate(7, (_) => List.filled(24, 0));
  for (final instant in instants) {
    final row = (instant.startedAt.weekday - firstWeekday + 7) % 7;
    secondsByCell[row][instant.startedAt.hour] += instant.activeSeconds;
  }
  return [
    for (final row in secondsByCell)
      [for (final seconds in row) seconds ~/ 60],
  ];
}
```

- [ ] **Step 5: Create the providers and the fake**

**Create `lib/features/stats/providers.dart`**

```dart
import 'package:energy_clock/app/settings/settings_providers.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/time/month_time.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/stats_repository.dart';
import 'package:energy_clock/features/stats/model/stats_period.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The week or month the Stats tab shows.
final statsPeriodProvider =
    NotifierProvider<StatsPeriodNotifier, StatsPeriod>(StatsPeriodNotifier.new);

/// The concrete window of the shown period. Weeks start on the first day of
/// the week (the setting, Monday by default).
final statsWindowProvider = Provider<StatsWindow>((ref) {
  final period = ref.watch(statsPeriodProvider);
  final firstWeekday =
      ref.watch(firstDayOfWeekProvider).valueOrNull ?? DateTime.monday;
  return switch (period.kind) {
    StatsPeriodKind.week => _weekWindow(period.anchor, firstWeekday),
    StatsPeriodKind.month => _monthWindow(period.anchor),
  };
});

StatsWindow _weekWindow(DateTime anchor, int firstWeekday) {
  final from = startOfWeek(anchor, firstWeekday: firstWeekday);
  return (
    from: from,
    toExclusive: DateTime(from.year, from.month, from.day + 7),
    dayCount: 7,
  );
}

StatsWindow _monthWindow(DateTime anchor) {
  final from = startOfMonth(anchor);
  return (
    from: from,
    toExclusive: addMonths(from, 1),
    dayCount: daysInMonth(anchor),
  );
}

/// The snapshot for the shown window. Watches the window, so a period or
/// first-day change re-queries.
final statsDataProvider = StreamProvider<StatsSnapshot>((ref) {
  final window = ref.watch(statsWindowProvider);
  return ref
      .watch(statsRepositoryProvider)
      .watchWindow(window.from, window.toExclusive);
});
```

**Create `test/support/fake_stats_repository.dart`**

```dart
import 'dart:async';

import 'package:energy_clock/data/repositories/stats_repository.dart';

/// In-memory [StatsRepository] for widget tests. Tests seed [snapshot] (or
/// call [emit]) and read [requests] to assert which window was asked for.
class FakeStatsRepository implements StatsRepository {
  FakeStatsRepository({StatsSnapshot? snapshot})
    : snapshot = snapshot ?? const StatsSnapshot.empty();

  StatsSnapshot snapshot;

  /// Every `(from, toExclusive)` the repository was asked to watch.
  final List<({DateTime from, DateTime to})> requests = [];

  final _updates = StreamController<StatsSnapshot>.broadcast();

  @override
  Stream<StatsSnapshot> watchWindow(DateTime from, DateTime toExclusive) async* {
    requests.add((from: from, to: toExclusive));
    yield snapshot;
    yield* _updates.stream;
  }

  /// Replaces the snapshot and re-emits to every watcher.
  void emit(StatsSnapshot next) {
    snapshot = next;
    _updates.add(next);
  }

  void dispose() => _updates.close();
}
```

- [ ] **Step 6: Run the tests to verify they pass**

```bash
# expect: PASS - 9 tests
flutter test test/features/stats/stats_providers_test.dart
```

- [ ] **Step 7: Analyze, run the suite, commit**

```bash
# expect: PASS - analyzer clean; whole suite green
flutter analyze && flutter test
```

```bash
# expect: RUN
git add lib/features/stats/model/stats_period.dart lib/features/stats/model/heatmap.dart \
  lib/features/stats/providers.dart test/support/fake_stats_repository.dart \
  test/features/stats/stats_providers_test.dart
git commit -m "feat: stats period, window, heatmap bucketing and fake

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

### Task 7: The four chart painters

Hand-rolled `CustomPainter`s in `lib/shared/charts/`, shared by Stats and (for the donut) Profile's roundup snapshots. Every colour is a constructor parameter — painters never read the theme. Pure layout helpers carry the unit tests; painting itself is covered by the golden tests in Task 9.

**Files:**
- Create: `lib/shared/charts/stacked_bars_painter.dart`, `lib/shared/charts/donut_painter.dart`, `lib/shared/charts/paired_bars_painter.dart`, `lib/shared/charts/heatmap_painter.dart`
- Test: `test/shared/charts/charts_test.dart` (new)

**Interfaces:**
- `StackedBarsPainter({days: List<Map<Tone, int>>, colors: Map<Tone, Color>, trackColor, barRadius})`; pure `stackFractions(Map<Tone, int>) → Map<Tone, double>` (share of the day total; all 0 when empty) and `stackGeometry(Size, int barCount) → ({double slot, double barWidth})` (bar width clamped to 28).
- `DonutPainter({segments: List<DonutSegment>, colors, trackColor, strokeWidth})` with `DonutSegment = ({Tone tone, int minutes})`; pure `donutSweeps(List<DonutSegment>) → List<double>` (fractions of the total; empty when total is 0).
- `PairedBarsPainter({rows: List<PlannedActualRow>, colors, plannedColor, barRadius})` with `PlannedActualRow = ({Tone tone, int planned, int completed})`; pure `pairedFractions(row, maxValue) → ({double planned, double completed})`.
- `HeatmapPainter({matrix: List<List<int>>, base, peak, gap})` (matrix must be 7×24, asserted); pure `heatmapColor(base, peak, minutes, maxMinutes) → Color` (`base` at 0, `peak` at the max, linear lerp between).

- [ ] **Step 1: Write the failing tests**

**Create `test/shared/charts/charts_test.dart`**

```dart
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/shared/charts/donut_painter.dart';
import 'package:energy_clock/shared/charts/heatmap_painter.dart';
import 'package:energy_clock/shared/charts/paired_bars_painter.dart';
import 'package:energy_clock/shared/charts/stacked_bars_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const track = Color(0xFFEEEEEE);
  const focus = Color(0xFF7C5CFF);
  final colors = {for (final tone in Tone.values) tone: focus};

  test('stack fractions share the day total, or are all zero', () {
    final fractions = stackFractions({Tone.focus: 90, Tone.life: 30});
    expect(fractions[Tone.focus], closeTo(0.75, 0.0001));
    expect(fractions[Tone.life], closeTo(0.25, 0.0001));
    expect(fractions[Tone.inbox], 0);
    expect(stackFractions(const {}).values, everyElement(0));
  });

  test('stack geometry divides the width and clamps the bar', () {
    final narrow = stackGeometry(const Size(350, 120), 7);
    expect(narrow.slot, 50);
    expect(narrow.barWidth, lessThanOrEqualTo(28));

    final tiny = stackGeometry(const Size(70, 120), 7);
    expect(tiny.slot, 10);
    expect(tiny.barWidth, 2);
  });

  test('stacked bars repaint only when their inputs change', () {
    final days = [
      {Tone.focus: 60},
    ];
    final first = StackedBarsPainter(days: days, colors: colors, trackColor: track);
    expect(first.shouldRepaint(StackedBarsPainter(days: days, colors: colors, trackColor: track)), isFalse);
    expect(
      first.shouldRepaint(StackedBarsPainter(days: [{Tone.focus: 30}], colors: colors, trackColor: track)),
      isTrue,
    );
  });

  test('donut sweeps cover the whole circle, or are empty', () {
    expect(donutSweeps(const []), isEmpty);
    expect(donutSweeps([(tone: Tone.focus, minutes: 0)]), isEmpty);

    final sweeps = donutSweeps([
      (tone: Tone.focus, minutes: 90),
      (tone: Tone.life, minutes: 30),
    ]);
    expect(sweeps.reduce((a, b) => a + b), closeTo(1, 0.0001));
    expect(sweeps.first, closeTo(0.75, 0.0001));
  });

  test('the donut repaints only when its inputs change', () {
    const segments = [(tone: Tone.focus, minutes: 60)];
    final first = DonutPainter(segments: segments, colors: colors, trackColor: track);
    expect(first.shouldRepaint(DonutPainter(segments: segments, colors: colors, trackColor: track)), isFalse);
    expect(
      first.shouldRepaint(DonutPainter(segments: const [(tone: Tone.focus, minutes: 30)], colors: colors, trackColor: track)),
      isTrue,
    );
  });

  test('paired fractions are relative to the shared maximum', () {
    final fractions = pairedFractions((tone: Tone.focus, planned: 120, completed: 90), 120);
    expect(fractions.planned, 1);
    expect(fractions.completed, closeTo(0.75, 0.0001));

    final zero = pairedFractions((tone: Tone.life, planned: 0, completed: 0), 0);
    expect(zero, (planned: 0, completed: 0));
  });

  test('paired bars repaint only when their inputs change', () {
    const rows = [(tone: Tone.focus, planned: 120, completed: 90)];
    final first = PairedBarsPainter(rows: rows, colors: colors, plannedColor: track);
    expect(first.shouldRepaint(PairedBarsPainter(rows: rows, colors: colors, plannedColor: track)), isFalse);
    expect(
      first.shouldRepaint(PairedBarsPainter(rows: const [(tone: Tone.focus, planned: 60, completed: 60)], colors: colors, plannedColor: track)),
      isTrue,
    );
  });

  test('heatmap cells run from base to peak', () {
    const base = Color(0xFFEEEEEE);
    const peak = Color(0xFF1A1A1A);
    expect(heatmapColor(base, peak, 0, 60), base);
    expect(heatmapColor(base, peak, 60, 60), peak);
    expect(heatmapColor(base, peak, 30, 60), Color.lerp(base, peak, 0.5));
    expect(heatmapColor(base, peak, 10, 0), base);
  });

  test('the heatmap painter requires a 7 by 24 matrix', () {
    expect(() => HeatmapPainter(matrix: const [], base: track, peak: track), throwsA(isA<AssertionError>()));
    expect(
      () => HeatmapPainter(matrix: List.generate(7, (_) => List.filled(23, 0)), base: track, peak: track),
      throwsA(isA<AssertionError>()),
    );
  });

  test('the heatmap repaints only when its inputs change', () {
    final matrix = List.generate(7, (_) => List.filled(24, 0));
    final first = HeatmapPainter(matrix: matrix, base: track, peak: track);
    expect(first.shouldRepaint(HeatmapPainter(matrix: matrix, base: track, peak: track)), isFalse);
    expect(
      first.shouldRepaint(HeatmapPainter(matrix: List.generate(7, (_) => List.filled(24, 1)), base: track, peak: track)),
      isTrue,
    );
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL - compile error: none of the painters exist yet.
flutter test test/shared/charts/charts_test.dart
```

- [ ] **Step 3: Create the stacked bars painter**

**Create `lib/shared/charts/stacked_bars_painter.dart`**

```dart
import 'dart:math' as math;

import 'package:energy_clock/core/tone.dart';
import 'package:flutter/material.dart';

/// One day's column: completed minutes per tone.
typedef ToneStack = Map<Tone, int>;

/// Each tone's share of the day total; all zero when the day is empty.
Map<Tone, double> stackFractions(ToneStack day) {
  final total = day.values.fold(0, (sum, minutes) => sum + minutes);
  return {
    for (final tone in Tone.values)
      tone: total == 0 ? 0 : (day[tone] ?? 0) / total,
  };
}

/// The horizontal slot per bar and the bar width inside it (clamped to 28).
({double slot, double barWidth}) stackGeometry(Size size, int barCount) {
  final slot = size.width / barCount;
  return (slot: slot, barWidth: math.min(slot - 8, 28));
}

/// One vertical bar per day, tones stacked from the bottom in [Tone.values]
/// order, heights relative to the fullest day. Empty days show the track.
class StackedBarsPainter extends CustomPainter {
  StackedBarsPainter({
    required this.days,
    required this.colors,
    required this.trackColor,
    this.barRadius = 3,
  });

  final List<ToneStack> days;
  final Map<Tone, Color> colors;
  final Color trackColor;
  final double barRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    final geometry = stackGeometry(size, days.length);
    final maxTotal = days.fold(
      0,
      (max, day) => math.max(max, day.values.fold(0, (sum, m) => sum + m)),
    );
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < days.length; i++) {
      final x =
          geometry.slot * i + (geometry.slot - geometry.barWidth) / 2;
      final full = Rect.fromLTWH(x, 0, geometry.barWidth, size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(full, Radius.circular(barRadius)),
        paint..color = trackColor,
      );
      final total = days[i].values.fold(0, (sum, m) => sum + m);
      if (total == 0 || maxTotal == 0) continue;
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(full, Radius.circular(barRadius)),
      );
      var y = size.height;
      for (final tone in Tone.values) {
        final minutes = days[i][tone] ?? 0;
        if (minutes == 0) continue;
        final height = minutes / maxTotal * size.height;
        y -= height;
        canvas.drawRect(
          Rect.fromLTWH(x, y, geometry.barWidth, height),
          paint..color = colors[tone] ?? trackColor,
        );
      }
      canvas.restore();
    }
  }

  bool _stacksEqual(List<ToneStack> a, List<ToneStack> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      for (final tone in Tone.values) {
        if ((a[i][tone] ?? 0) != (b[i][tone] ?? 0)) return false;
      }
    }
    return true;
  }

  @override
  bool shouldRepaint(covariant StackedBarsPainter oldDelegate) =>
      !_stacksEqual(oldDelegate.days, days) ||
      oldDelegate.colors != colors ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.barRadius != barRadius;
}
```

- [ ] **Step 4: Create the donut painter**

**Create `lib/shared/charts/donut_painter.dart`**

```dart
import 'dart:math' as math;

import 'package:energy_clock/core/tone.dart';
import 'package:flutter/material.dart';

/// Completed minutes for one tone.
typedef DonutSegment = ({Tone tone, int minutes});

/// Each segment's share of the whole circle; empty when there is nothing.
List<double> donutSweeps(List<DonutSegment> segments) {
  final total = segments.fold(0, (sum, segment) => sum + segment.minutes);
  if (total == 0) return const [];
  return [
    for (final segment in segments)
      if (segment.minutes > 0) segment.minutes / total,
  ];
}

/// A ring split into tone shares, starting at the top. An empty period shows
/// the track all the way round.
class DonutPainter extends CustomPainter {
  DonutPainter({
    required this.segments,
    required this.colors,
    required this.trackColor,
    this.strokeWidth = 14,
  });

  final List<DonutSegment> segments;
  final Map<Tone, Color> colors;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = trackColor);
    final sweeps = donutSweeps(segments);
    var start = -math.pi / 2;
    var i = 0;
    for (final segment in segments) {
      if (segment.minutes == 0) continue;
      final sweep = sweeps[i];
      i++;
      canvas.drawArc(
        rect,
        start,
        sweep * math.pi * 2,
        false,
        paint..color = colors[segment.tone] ?? trackColor,
      );
      start += sweep * math.pi * 2;
    }
  }

  bool _segmentsEqual(List<DonutSegment> a, List<DonutSegment> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].tone != b[i].tone || a[i].minutes != b[i].minutes) {
        return false;
      }
    }
    return true;
  }

  @override
  bool shouldRepaint(covariant DonutPainter oldDelegate) =>
      !_segmentsEqual(oldDelegate.segments, segments) ||
      oldDelegate.colors != colors ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
```

- [ ] **Step 5: Create the paired bars painter**

**Create `lib/shared/charts/paired_bars_painter.dart`**

```dart
import 'dart:math' as math;

import 'package:energy_clock/core/tone.dart';
import 'package:flutter/material.dart';

/// Planned against completed minutes for one tone.
typedef PlannedActualRow = ({Tone tone, int planned, int completed});

/// Each bar's share of the shared maximum. Zero when the maximum is 0.
({double planned, double completed}) pairedFractions(
  PlannedActualRow row,
  int maxValue,
) {
  if (maxValue <= 0) return (planned: 0, completed: 0);
  return (
    planned: row.planned / maxValue,
    completed: row.completed / maxValue,
  );
}

/// Two bars per tone — planned in [plannedColor], completed in the tone
/// colour — heights relative to the largest value anywhere.
class PairedBarsPainter extends CustomPainter {
  PairedBarsPainter({
    required this.rows,
    required this.colors,
    required this.plannedColor,
    this.barRadius = 3,
  });

  final List<PlannedActualRow> rows;
  final Map<Tone, Color> colors;
  final Color plannedColor;
  final double barRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (rows.isEmpty) return;
    final maxValue = math.max(
      1,
      rows.fold(
        0,
        (max, row) => math.max(max, math.max(row.planned, row.completed)),
      ),
    );
    final slot = size.width / rows.length;
    final barWidth = math.min((slot - 12) / 2, 22);
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < rows.length; i++) {
      final fractions = pairedFractions(rows[i], maxValue);
      final groupX = slot * i + (slot - barWidth * 2 - 4) / 2;
      _bar(
        canvas,
        paint,
        Rect.fromLTWH(
          groupX,
          size.height * (1 - fractions.planned),
          barWidth,
          size.height * fractions.planned,
        ),
        plannedColor,
      );
      _bar(
        canvas,
        paint,
        Rect.fromLTWH(
          groupX + barWidth + 4,
          size.height * (1 - fractions.completed),
          barWidth,
          size.height * fractions.completed,
        ),
        colors[rows[i].tone] ?? plannedColor,
      );
    }
  }

  void _bar(Canvas canvas, Paint paint, Rect rect, Color color) {
    if (rect.height <= 0) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(barRadius)),
      paint..color = color,
    );
  }

  bool _rowsEqual(List<PlannedActualRow> a, List<PlannedActualRow> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].tone != b[i].tone ||
          a[i].planned != b[i].planned ||
          a[i].completed != b[i].completed) {
        return false;
      }
    }
    return true;
  }

  @override
  bool shouldRepaint(covariant PairedBarsPainter oldDelegate) =>
      !_rowsEqual(oldDelegate.rows, rows) ||
      oldDelegate.colors != colors ||
      oldDelegate.plannedColor != plannedColor ||
      oldDelegate.barRadius != barRadius;
}
```

- [ ] **Step 6: Create the heatmap painter**

**Create `lib/shared/charts/heatmap_painter.dart`**

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The colour of one heatmap cell: [base] when empty, [peak] at the busiest
/// cell, a straight lerp between.
Color heatmapColor(Color base, Color peak, int minutes, int maxMinutes) {
  if (maxMinutes <= 0 || minutes <= 0) return base;
  return Color.lerp(base, peak, minutes / maxMinutes)!;
}

/// A 7×24 grid of rounded cells, Monday (or the first weekday) on top, hours
/// across. Callers build the matrix with `buildHeatmap`.
class HeatmapPainter extends CustomPainter {
  HeatmapPainter({
    required this.matrix,
    required this.base,
    required this.peak,
    this.gap = 2,
  }) : assert(
         matrix.length == 7 && matrix.every((row) => row.length == 24),
         'The heatmap matrix must be 7 rows of 24 hours',
       );

  final List<List<int>> matrix;
  final Color base;
  final Color peak;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final maxMinutes = matrix.fold(
      0,
      (max, row) => math.max(max, row.fold(0, math.max)),
    );
    final cellWidth = (size.width - gap * 23) / 24;
    final cellHeight = (size.height - gap * 6) / 7;
    final paint = Paint()..style = PaintingStyle.fill;
    for (var row = 0; row < 7; row++) {
      for (var col = 0; col < 24; col++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              col * (cellWidth + gap),
              row * (cellHeight + gap),
              cellWidth,
              cellHeight,
            ),
            const Radius.circular(2),
          ),
          paint
            ..color = heatmapColor(base, peak, matrix[row][col], maxMinutes),
        );
      }
    }
  }

  bool _matrixEqual(List<List<int>> a, List<List<int>> b) {
    for (var row = 0; row < 7; row++) {
      for (var col = 0; col < 24; col++) {
        if (a[row][col] != b[row][col]) return false;
      }
    }
    return true;
  }

  @override
  bool shouldRepaint(covariant HeatmapPainter oldDelegate) =>
      !_matrixEqual(oldDelegate.matrix, matrix) ||
      oldDelegate.base != base ||
      oldDelegate.peak != peak ||
      oldDelegate.gap != gap;
}
```

- [ ] **Step 7: Run the tests to verify they pass**

```bash
# expect: PASS - 10 tests
flutter test test/shared/charts/charts_test.dart
```

- [ ] **Step 8: Analyze, run the suite, commit**

```bash
# expect: PASS - analyzer clean; whole suite green
flutter analyze && flutter test
```

```bash
# expect: RUN
git add lib/shared/charts/stacked_bars_painter.dart lib/shared/charts/donut_painter.dart \
  lib/shared/charts/paired_bars_painter.dart lib/shared/charts/heatmap_painter.dart \
  test/shared/charts/charts_test.dart
git commit -m "feat: shared chart painters for stats and roundups

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

### Task 8: The Stats screen

The placeholder becomes the real tab: period header, four section cards, single column on narrow windows and two columns from medium up, every chart wrapped in a spoken summary, every section with its own empty state. The harness gains the stats fake, and the tab-scaffold test learns the new tab content.

**Files:**
- Replace: `lib/features/stats/stats_screen.dart`
- Create: `lib/features/stats/stats_layout.dart`, `lib/features/stats/widgets/period_header.dart`, `lib/features/stats/widgets/section_card.dart`, `lib/features/stats/widgets/tone_balance_card.dart`, `lib/features/stats/widgets/planned_actual_card.dart`, `lib/features/stats/widgets/focus_depth_card.dart`, `lib/features/stats/widgets/heatmap_card.dart`
- Modify: `lib/core/strings.dart` (Statistics block), `lib/shared/layout/content_width.dart` (`ContentWidths.stats = 800`), `test/support/clock_harness.dart` (stats fake), `test/app/tab_scaffold_test.dart` (tab-2 expectation + stats override)
- Test: `test/features/stats/stats_screen_test.dart` (new), `test/core/strings_test.dart` (1 new test)

**Interfaces:**
- `StatsLayout.of(context)` → `({bool twoColumn})`: single column on narrow, two columns otherwise.
- `StatsSectionCard({title, trailing, empty, emptyMessage, semanticsLabel, child})`: card chrome + `SectionHeader`; empty shows the message as plain text, otherwise the child wrapped in `Semantics(label:, excludeSemantics:)`.
- Cards take `(snapshot, window)` and read `firstDayOfWeekProvider` themselves for label order.

- [ ] **Step 1: Write the failing tests**

**Create `test/features/stats/stats_screen_test.dart`**

```dart
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/stats_repository.dart';
import 'package:energy_clock/features/stats/stats_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

class _ThrowingStatsRepository implements StatsRepository {
  @override
  Stream<StatsSnapshot> watchWindow(DateTime from, DateTime toExclusive) async* {
    throw StateError('unreadable');
  }
}

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  StatsSnapshot filled() => StatsSnapshot(
    toneByDay: const [
      (date: DateTime(2026, 10, 5), tone: Tone.focus, minutes: 150),
      (date: DateTime(2026, 10, 5), tone: Tone.life, minutes: 60),
      (date: DateTime(2026, 10, 6), tone: Tone.focus, minutes: 90),
      (date: DateTime(2026, 10, 6), tone: Tone.inbox, minutes: 30),
    ],
    plannedByTone: const [
      (tone: Tone.focus, plannedMinutes: 300, completedMinutes: 240),
      (tone: Tone.life, plannedMinutes: 60, completedMinutes: 60),
      (tone: Tone.inbox, plannedMinutes: 30, completedMinutes: 30),
    ],
    focus: const FocusDepth(
      minutes: 240,
      longestSeconds: 5400,
      averageSeconds: 3600,
      ended: 5,
      abandoned: 1,
    ),
    focusInstants: const [
      (startedAt: DateTime(2026, 10, 5, 9), activeSeconds: 5400),
      (startedAt: DateTime(2026, 10, 5, 10), activeSeconds: 3600),
      (startedAt: DateTime(2026, 10, 6, 21), activeSeconds: 5400),
    ],
  );

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(harness.app(const StatsScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the four sections with the current range', (tester) async {
    harness.stats.emit(filled());
    await mount(tester);

    for (final title in [
      Strings.statsToneBalance,
      Strings.statsPlannedActual,
      Strings.statsFocusDepth,
      Strings.statsHeatmap,
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text(Strings.statsPeriodWeek), findsOneWidget);
    expect(find.textContaining('–'), findsOneWidget);
  });

  testWidgets('the month toggle re-queries a month window', (tester) async {
    harness.stats.emit(filled());
    await mount(tester);

    await tester.tap(find.text(Strings.statsPeriodMonth));
    await tester.pumpAndSettle();

    final first = harness.stats.requests.first;
    final last = harness.stats.requests.last;
    expect(first.to.difference(first.from).inDays, 7);
    expect(last.dayCount, last.to.difference(last.from).inDays);
    expect(last.dayCount, greaterThanOrEqualTo(28));
  });

  testWidgets('chevrons move the window and back again', (tester) async {
    harness.stats.emit(filled());
    await mount(tester);

    await tester.tap(find.byKey(const ValueKey('stats-previous')));
    await tester.pumpAndSettle();
    final back = harness.stats.requests.last;
    final start = harness.stats.requests.first;
    expect(
      back.from,
      DateTime(start.from.year, start.from.month, start.from.day - 7),
    );

    await tester.tap(find.byKey(const ValueKey('stats-next')));
    await tester.pumpAndSettle();
    expect(harness.stats.requests.last.from, start.from);
  });

  testWidgets('an empty snapshot shows all four empty states', (tester) async {
    await mount(tester);

    for (final message in [
      Strings.statsEmptyToneBalance,
      Strings.statsEmptyPlanned,
      Strings.statsEmptyFocus,
      Strings.statsEmptyHeatmap,
    ]) {
      expect(find.text(message), findsOneWidget);
    }
    expect(find.byType(CustomPaint), findsNothing);
  });

  testWidgets('the charts announce their numbers to screen readers', (tester) async {
    tester.ensureSemantics();
    harness.stats.emit(filled());
    await mount(tester);

    final tone = tester.getSemantics(find.byKey(const ValueKey('stats-tone-balance')));
    expect(tone.label, contains('Focus'));
    final planned = tester.getSemantics(find.byKey(const ValueKey('stats-planned-actual')));
    expect(planned.label, contains('adherence'));
    final depth = tester.getSemantics(find.byKey(const ValueKey('stats-focus-depth')));
    expect(depth.label, contains('Total focus'));
    final heatmap = tester.getSemantics(find.byKey(const ValueKey('stats-heatmap')));
    expect(heatmap.label, contains('Busiest'));
  });

  testWidgets('a failed read explains itself', (tester) async {
    final broken = ClockHarness(
      overrides: [
        statsRepositoryProvider.overrideWithValue(_ThrowingStatsRepository()),
      ],
    );
    addTearDown(broken.dispose);
    await tester.pumpWidget(broken.app(const StatsScreen()));
    await tester.pumpAndSettle();

    expect(find.text(Strings.statsLoadError), findsOneWidget);
  });
}
```

**Edit `test/core/strings_test.dart`** — insert before the final closing `}` of `main()`:

```dart
    test('statistics copy formats its numbers', () {
      expect(Strings.statsAdherence(83), '83% adherence');
      expect(Strings.statsAbandonedCount(1, 3), '1 of 3');
      expect(Strings.statsPlannedDone('2h planned', '1h 30m'), '2h planned · 1h 30m done');
    });
```

> Note for the implementer: the filled snapshot's dates (5–6 Oct 2026) may fall outside the *current* week when these tests run years from now — the fake serves the same snapshot for every window, so the assertions hold regardless. The chevron test only compares requests relatively for the same reason.

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL - compile error: StatsScreen is still the placeholder (not a ConsumerWidget, no sections); tab_scaffold_test still expects the coming-soon text.
flutter test test/features/stats/stats_screen_test.dart test/core/strings_test.dart test/app/tab_scaffold_test.dart
```

- [ ] **Step 3: Add the strings, the content width and the harness fake**

**Edit `lib/core/strings.dart`** — replace the `weekdayShortStarting` block:

Replace:
```dart
  /// The short weekday names reordered so they start on [firstWeekday]
  /// (`DateTime.monday` … `DateTime.sunday`).
  static List<String> weekdayShortStarting(int firstWeekday) => [
    for (var i = 0; i < 7; i++)
      weekdayShort[(firstWeekday - DateTime.monday + i) % 7],
  ];
```
With:
```dart
  /// The short weekday names reordered so they start on [firstWeekday]
  /// (`DateTime.monday` … `DateTime.sunday`).
  static List<String> weekdayShortStarting(int firstWeekday) => [
    for (var i = 0; i < 7; i++)
      weekdayShort[(firstWeekday - DateTime.monday + i) % 7],
  ];

  // Statistics.
  static const String statsLoadError = 'Could not load these statistics.';
  static const String statsPeriodWeek = 'Week';
  static const String statsPeriodMonth = 'Month';
  static const String statsPreviousWeek = 'Previous week';
  static const String statsNextWeek = 'Next week';
  static const String statsPreviousMonth = 'Previous month';
  static const String statsNextMonth = 'Next month';
  static const String statsThisWeek = 'This week';
  static const String statsThisMonth = 'This month';
  static const String statsToneBalance = 'Tone balance';
  static const String statsPlannedActual = 'Planned vs actual';
  static const String statsFocusDepth = 'Focus depth';
  static const String statsHeatmap = 'Where focus happens';
  static const String statsEmptyToneBalance =
      'Run your first session to see where your focus goes.';
  static const String statsEmptyPlanned =
      'Plan a day and come back to see how it went.';
  static const String statsEmptyFocus =
      'Your longest session will show up here.';
  static const String statsEmptyHeatmap =
      'A week of focus sessions reveals your peak hours.';
  static String statsAdherence(int percent) => '$percent% adherence';
  static const String statsTotalFocus = 'Total focus';
  static const String statsLongestSession = 'Longest session';
  static const String statsAverageSession = 'Average session';
  static const String statsAbandoned = 'Abandoned';
  static String statsAbandonedLabel(int percent) =>
      'Abandoned · $percent%';
  static String statsAbandonedCount(int abandoned, int ended) =>
      '$abandoned of $ended';
  static String statsPlannedDone(String planned, String done) =>
      '$planned planned · $done done';
  static String statsToneShare(String tone, String duration) =>
      '$tone $duration';
  static String statsFocusSummary(
    String total,
    String longest,
    String average,
    String abandoned,
  ) =>
      'Total focus $total, longest session $longest, '
      'average session $average, abandoned $abandoned';
  static String statsHeatmapBusiest(
    String weekday,
    String hour,
    String duration,
  ) =>
      'Busiest: $weekday $hour ($duration)';
```

**Edit `lib/shared/layout/content_width.dart`** — one pair

Replace:
```dart
  /// The Calendar's month card.
  static const double calendar = 640;
```
With:
```dart
  /// The Calendar's month card.
  static const double calendar = 640;

  /// Stats and Profile: a two-column spread on medium windows and up.
  static const double stats = 800;
```

**Edit `test/support/clock_harness.dart`** — four pairs

Replace:
```dart
import 'fake_session_repository.dart';
import 'fake_settings_repository.dart';
```
With:
```dart
import 'fake_session_repository.dart';
import 'fake_settings_repository.dart';
import 'fake_stats_repository.dart';
```

Replace:
```dart
/// calendar, session and settings repositories (the series, reuse and calendar
/// fakes share the event fake's events) and a fake notification service, plus
```
With:
```dart
/// calendar, session, settings and stats repositories (the series, reuse and
/// calendar fakes share the event fake's events) and a fake notification
/// service, plus
```

Replace:
```dart
  final FakeNotificationService notifications = FakeNotificationService();
  final FakeSettingsRepository settings = FakeSettingsRepository();
```
With:
```dart
  final FakeNotificationService notifications = FakeNotificationService();
  final FakeSettingsRepository settings = FakeSettingsRepository();
  final FakeStatsRepository stats = FakeStatsRepository();
```

Replace:
```dart
        settingsRepositoryProvider.overrideWithValue(settings),
```
With:
```dart
        settingsRepositoryProvider.overrideWithValue(settings),
        statsRepositoryProvider.overrideWithValue(stats),
```

Replace:
```dart
  void dispose() {
    container.dispose();
    sessions.dispose();
    reuse.dispose();
    repository.dispose();
  }
```
With:
```dart
  void dispose() {
    container.dispose();
    stats.dispose();
    sessions.dispose();
    reuse.dispose();
    repository.dispose();
  }
```

- [ ] **Step 4: Create the layout, section card and period header**

**Create `lib/features/stats/stats_layout.dart`**

```dart
import 'package:energy_clock/shared/layout/window_class.dart';
import 'package:flutter/widgets.dart';

/// Single column on narrow windows, two columns from medium up.
class StatsLayout {
  const StatsLayout({required this.twoColumn});

  factory StatsLayout.of(BuildContext context) =>
      StatsLayout(twoColumn: context.windowClass != WindowClass.narrow);

  final bool twoColumn;
}
```

**Create `lib/features/stats/widgets/section_card.dart`**

```dart
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:energy_clock/shared/widgets/section_header.dart';
import 'package:flutter/material.dart';

/// The chrome every Stats section shares: a card, a header, then either an
/// empty-state message or the chart wrapped in its spoken summary.
class StatsSectionCard extends StatelessWidget {
  const StatsSectionCard({
    required this.title,
    required this.empty,
    required this.emptyMessage,
    required this.semanticsLabel,
    required this.child,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget? trailing;
  final bool empty;
  final String emptyMessage;
  final String semanticsLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: title, trailing: trailing),
          const SizedBox(height: AppSpacing.sm),
          if (empty)
            Text(
              emptyMessage,
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            Semantics(
              label: semanticsLabel,
              excludeSemantics: true,
              child: child,
            ),
        ],
      ),
    );
  }
}
```

**Create `lib/features/stats/widgets/period_header.dart`**

```dart
import 'package:energy_clock/app/settings/settings_providers.dart';
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/time/month_time.dart';
import 'package:energy_clock/features/stats/model/stats_period.dart';
import 'package:energy_clock/features/stats/providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The Stats header: week/month toggle, the range label, chevrons, and a jump
/// back to the current period. The forward chevron disables at the current
/// period; the range never reaches into the future.
class PeriodHeader extends ConsumerWidget {
  const PeriodHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(statsPeriodProvider);
    final notifier = ref.read(statsPeriodProvider.notifier);
    final firstWeekday =
        ref.watch(firstDayOfWeekProvider).valueOrNull ?? DateTime.monday;
    final isWeek = period.kind == StatsPeriodKind.week;
    final from =
        isWeek
            ? startOfWeek(period.anchor, firstWeekday: firstWeekday)
            : startOfMonth(period.anchor);
    final label = isWeek ? _weekLabel(from) : DateFormat('MMMM y').format(from);

    final now = startOfDay(DateTime.now());
    final atCurrent =
        isWeek
            ? startOfWeek(period.anchor) == startOfWeek(now) &&
                startOfWeek(period.anchor, firstWeekday: firstWeekday) ==
                    startOfWeek(now, firstWeekday: firstWeekday)
            : startOfMonth(period.anchor) == startOfMonth(now);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _Chevron(
              key: const ValueKey('stats-previous'),
              icon: CupertinoIcons.chevron_left,
              tooltip:
                  isWeek ? Strings.statsPreviousWeek : Strings.statsPreviousMonth,
              onTap: notifier.previous,
            ),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            _Chevron(
              key: const ValueKey('stats-next'),
              icon: CupertinoIcons.chevron_right,
              tooltip: isWeek ? Strings.statsNextWeek : Strings.statsNextMonth,
              onTap: atCurrent ? null : notifier.next,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _KindPill(
              label: Strings.statsPeriodWeek,
              selected: isWeek,
              onTap: () => notifier.setKind(StatsPeriodKind.week),
            ),
            const SizedBox(width: AppSpacing.sm),
            _KindPill(
              label: Strings.statsPeriodMonth,
              selected: !isWeek,
              onTap: () => notifier.setKind(StatsPeriodKind.month),
            ),
            if (!atCurrent) ...[
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                key: const ValueKey('stats-today'),
                onPressed: notifier.returnToNow,
                child: Text(
                  isWeek ? Strings.statsThisWeek : Strings.statsThisMonth,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// '5 – 11 Oct 2026', widening the start only as far as it must differ.
  String _weekLabel(DateTime from) {
    final to = DateTime(from.year, from.month, from.day + 6);
    final end = DateFormat('d MMM y').format(to);
    if (from.year == to.year && from.month == to.month) {
      return "${DateFormat('d').format(from)} – $end";
    }
    if (from.year == to.year) {
      return "${DateFormat('d MMM').format(from)} – $end";
    }
    return "${DateFormat('d MMM y').format(from)} – $end";
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onTap,
    );
  }
}

class _KindPill extends StatelessWidget {
  const _KindPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? colors.ink : AppColors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              label,
              style: theme.textTheme.labelLarge!.copyWith(
                color: selected ? colors.onInk : colors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

> Note for the implementer: the `atCurrent` week comparison above is deliberately belt-and-braces (both Monday- and setting-based starts must agree). If the analyzer flags the first comparison as redundant, keep only the setting-based one.

- [ ] **Step 5: Create the four section cards**

**Create `lib/features/stats/widgets/tone_balance_card.dart`**

```dart
import 'package:energy_clock/app/settings/settings_providers.dart';
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/repositories/stats_repository.dart';
import 'package:energy_clock/features/stats/model/stats_period.dart';
import 'package:energy_clock/features/stats/widgets/section_card.dart';
import 'package:energy_clock/shared/charts/stacked_bars_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Completed minutes per day, tones stacked, heights relative to the fullest
/// day. Month windows show one thin bar per day without labels.
class ToneBalanceCard extends ConsumerWidget {
  const ToneBalanceCard({
    required this.snapshot,
    required this.window,
    super.key,
  });

  final StatsSnapshot snapshot;
  final StatsWindow window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstWeekday =
        ref.watch(firstDayOfWeekProvider).valueOrNull ?? DateTime.monday;
    final toneColors = context.toneColors;
    final theme = Theme.of(context);

    final stacks = <DateTime, ToneStack>{};
    for (final cell in snapshot.toneByDay) {
      (stacks[cell.date] ??= <Tone, int>{})[cell.tone] = cell.minutes;
    }
    final bars = <ToneStack>[
      for (var i = 0; i < window.dayCount; i++)
        stacks[DateTime(
              window.from.year,
              window.from.month,
              window.from.day + i,
            )] ??
            const <Tone, int>{},
    ];

    final totals = <Tone, int>{for (final tone in Tone.values) tone: 0};
    for (final cell in snapshot.toneByDay) {
      totals[cell.tone] = totals[cell.tone]! + cell.minutes;
    }
    final summary = Strings.joinWords([
      for (final tone in Tone.values)
        Strings.statsToneShare(tone.label, formatDurationMinutes(totals[tone]!)),
    ]);

    return StatsSectionCard(
      title: Strings.statsToneBalance,
      empty: snapshot.completedTotal == 0,
      emptyMessage: Strings.statsEmptyToneBalance,
      semanticsLabel: summary,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 140,
            width: double.infinity,
            child: CustomPaint(
              painter: StackedBarsPainter(
                days: bars,
                colors: {
                  for (final tone in Tone.values)
                    tone: toneColors.fillFor(tone),
                },
                trackColor: context.appColors.outline,
              ),
            ),
          ),
          if (window.dayCount == 7) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                for (final name
                    in Strings.weekdayShortStarting(firstWeekday))
                  Expanded(
                    child: Center(
                      child: Text(name[0], style: theme.textTheme.bodySmall),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
```

**Create `lib/features/stats/widgets/planned_actual_card.dart`**

```dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/repositories/stats_repository.dart';
import 'package:energy_clock/features/stats/model/stats_period.dart';
import 'package:energy_clock/features/stats/widgets/section_card.dart';
import 'package:energy_clock/shared/charts/paired_bars_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Planned (muted) against completed (tone) minutes per tone, with the
/// adherence percent in the header.
class PlannedActualCard extends ConsumerWidget {
  const PlannedActualCard({
    required this.snapshot,
    required this.window,
    super.key,
  });

  final StatsSnapshot snapshot;
  final StatsWindow window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toneColors = context.toneColors;
    final theme = Theme.of(context);
    final adherence = snapshot.adherencePercent;

    final summary = Strings.joinWords([
      if (adherence != null) Strings.statsAdherence(adherence),
      for (final row in snapshot.plannedByTone)
        Strings.statsToneShare(
          row.tone.label,
          Strings.statsPlannedDone(
            formatDurationMinutes(row.plannedMinutes),
            formatDurationMinutes(row.completedMinutes),
          ),
        ),
    ]);

    return StatsSectionCard(
      title: Strings.statsPlannedActual,
      trailing:
          adherence == null
              ? null
              : Text(
                Strings.statsAdherence(adherence),
                style: theme.textTheme.titleMedium,
              ),
      empty: snapshot.plannedTotal == 0,
      emptyMessage: Strings.statsEmptyPlanned,
      semanticsLabel: summary,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 140,
            width: double.infinity,
            child: CustomPaint(
              painter: PairedBarsPainter(
                rows: [
                  for (final row in snapshot.plannedByTone)
                    (
                      tone: row.tone,
                      planned: row.plannedMinutes,
                      completed: row.completedMinutes,
                    ),
                ],
                colors: {
                  for (final tone in Tone.values)
                    tone: toneColors.fillFor(tone),
                },
                plannedColor: context.appColors.outline,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final row in snapshot.plannedByTone)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: toneColors.fillFor(row.tone),
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox.square(dimension: 10),
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Expanded(
                    child: Text(
                      '${row.tone.label}: ${Strings.statsPlannedDone(formatDurationMinutes(row.plannedMinutes), formatDurationMinutes(row.completedMinutes))}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
```

**Create `lib/features/stats/widgets/focus_depth_card.dart`**

```dart
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/repositories/stats_repository.dart';
import 'package:energy_clock/features/stats/model/stats_period.dart';
import 'package:energy_clock/features/stats/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Four tiles: total, longest and average focus plus the abandoned count.
class FocusDepthCard extends ConsumerWidget {
  const FocusDepthCard({
    required this.snapshot,
    required this.window,
    super.key,
  });

  final StatsSnapshot snapshot;
  final StatsWindow window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = snapshot.focus;
    final rate = focus.abandonmentRate;
    final summary = Strings.statsFocusSummary(
      formatDurationMinutes(focus.minutes),
      formatDurationMinutes(focus.longestSeconds ~/ 60),
      formatDurationMinutes(focus.averageSeconds ~/ 60),
      Strings.statsAbandonedCount(focus.abandoned, focus.ended),
    );

    return StatsSectionCard(
      title: Strings.statsFocusDepth,
      empty: focus.ended == 0,
      emptyMessage: Strings.statsEmptyFocus,
      semanticsLabel: summary,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _Metric(
                  value: formatDurationMinutes(focus.minutes),
                  label: Strings.statsTotalFocus,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Metric(
                  value: formatDurationMinutes(focus.longestSeconds ~/ 60),
                  label: Strings.statsLongestSession,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  value: formatDurationMinutes(focus.averageSeconds ~/ 60),
                  label: Strings.statsAverageSession,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Metric(
                  value: Strings.statsAbandonedCount(
                    focus.abandoned,
                    focus.ended,
                  ),
                  label:
                      rate == null
                          ? Strings.statsAbandoned
                          : Strings.statsAbandonedLabel(
                            (rate * 100).round(),
                          ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: theme.textTheme.titleLarge),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
```

**Create `lib/features/stats/widgets/heatmap_card.dart`**

```dart
import 'package:energy_clock/app/settings/settings_providers.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/repositories/stats_repository.dart';
import 'package:energy_clock/features/stats/model/heatmap.dart';
import 'package:energy_clock/features/stats/model/stats_period.dart';
import 'package:energy_clock/features/stats/widgets/section_card.dart';
import 'package:energy_clock/shared/charts/heatmap_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// When focus happens: a 7×24 grid, weekday rows starting on the first day of
/// the week, hours across.
class HeatmapCard extends ConsumerWidget {
  const HeatmapCard({required this.snapshot, required this.window, super.key});

  final StatsSnapshot snapshot;
  final StatsWindow window;

  static const double _cellHeight = 16;
  static const double _gap = 2;
  static const double _chartHeight = _cellHeight * 7 + _gap * 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstWeekday =
        ref.watch(firstDayOfWeekProvider).valueOrNull ?? DateTime.monday;
    final theme = Theme.of(context);
    final toneColors = context.toneColors;

    final matrix = buildHeatmap(
      snapshot.focusInstants,
      firstWeekday: firstWeekday,
    );
    var bestRow = 0;
    var bestCol = 0;
    for (var row = 0; row < 7; row++) {
      for (var col = 0; col < 24; col++) {
        if (matrix[row][col] > matrix[bestRow][bestCol]) {
          bestRow = row;
          bestCol = col;
        }
      }
    }
    final bestWeekday =
        Strings.weekdayLong[(firstWeekday - DateTime.monday + bestRow) % 7];
    final summary = Strings.statsHeatmapBusiest(
      bestWeekday,
      DateFormat('ha').format(DateTime(2026, 1, 1, bestCol)),
      formatDurationMinutes(matrix[bestRow][bestCol]),
    );

    return StatsSectionCard(
      title: Strings.statsHeatmap,
      empty: snapshot.focusInstants.isEmpty,
      emptyMessage: Strings.statsEmptyHeatmap,
      semanticsLabel: summary,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            height: _chartHeight,
            child: Column(
              children: [
                for (var row = 0; row < 7; row++) ...[
                  SizedBox(
                    height: _cellHeight,
                    child: Center(
                      child: Text(
                        Strings.weekdayShortStarting(firstWeekday)[row][0],
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                  if (row < 6) const SizedBox(height: _gap),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SizedBox(
              height: _chartHeight,
              child: CustomPaint(
                painter: HeatmapPainter(
                  matrix: matrix,
                  base: toneColors.fillFor(Tone.focus).withValues(alpha: 0.12),
                  peak: toneColors.fillFor(Tone.focus),
                  gap: _gap,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Replace the screen**

**Replace `lib/features/stats/stats_screen.dart`**

```dart
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/stats/providers.dart';
import 'package:energy_clock/features/stats/stats_layout.dart';
import 'package:energy_clock/features/stats/widgets/focus_depth_card.dart';
import 'package:energy_clock/features/stats/widgets/heatmap_card.dart';
import 'package:energy_clock/features/stats/widgets/period_header.dart';
import 'package:energy_clock/features/stats/widgets/planned_actual_card.dart';
import 'package:energy_clock/features/stats/widgets/tone_balance_card.dart';
import 'package:energy_clock/shared/layout/content_width.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Stats tab: a week or month of tone balance, planned-vs-actual, focus
/// depth and the focus heatmap.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(statsDataProvider);
    return data.when(
      data: (snapshot) => _StatsBody(snapshot: snapshot),
      loading:
          () => const Center(child: CircularProgressIndicator.adaptive()),
      error:
          (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                Strings.statsLoadError,
                textAlign: TextAlign.center,
              ),
            ),
          ),
    );
  }
}

class _StatsBody extends ConsumerWidget {
  const _StatsBody({required this.snapshot});

  final AsyncSnapshotShim _sentinel = const AsyncSnapshotShim();
```

> Stop — the draft above has a leftover placeholder (`AsyncSnapshotShim` does not exist). The real `_StatsBody` is:

```dart
class _StatsBody extends ConsumerWidget {
  const _StatsBody({required this.snapshot});

  final StatsSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(statsWindowProvider);
    final twoColumn = StatsLayout.of(context).twoColumn;

    Widget gap() => const SizedBox(height: AppSpacing.lg);
    final tone = ToneBalanceCard(
      key: const ValueKey('stats-tone-balance'),
      snapshot: snapshot,
      window: window,
    );
    final planned = PlannedActualCard(
      key: const ValueKey('stats-planned-actual'),
      snapshot: snapshot,
      window: window,
    );
    final depth = FocusDepthCard(
      key: const ValueKey('stats-focus-depth'),
      snapshot: snapshot,
      window: window,
    );
    final heatmap = HeatmapCard(
      key: const ValueKey('stats-heatmap'),
      snapshot: snapshot,
      window: window,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: ContentWidth(
        maxWidth: ContentWidths.stats,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PeriodHeader(),
            gap(),
            if (twoColumn) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: tone),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: planned),
                ],
              ),
              gap(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: depth),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: heatmap),
                ],
              ),
            ] else ...[
              tone,
              gap(),
              planned,
              gap(),
              depth,
              gap(),
              heatmap,
            ],
          ],
        ),
      ),
    );
  }
}
```

> Note for the implementer: `Widget gap()` as a local function returning a fresh `SizedBox` each call is deliberate (the same widget instance must not appear twice in the tree). It needs the `StatsSnapshot` import from `package:energy_clock/data/repositories/stats_repository.dart` — add it. `AppSpacing.xl` must exist in tokens (it does: month layout uses page margins; if not, use `AppSpacing.lg * 2`).

- [ ] **Step 7: Teach the tab-scaffold test the new tab**

**Edit `test/app/tab_scaffold_test.dart`** — three pairs

Replace:
```dart
import 'package:energy_clock/data/providers.dart';
```
With:
```dart
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/stats_repository.dart';
```
(This file already imports `data/providers.dart` — confirm at implementation time and add the stats import after it. It also needs `test/support/fake_stats_repository.dart` — add that import in the support group.)

Replace:
```dart
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
      ],
```
With:
```dart
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        statsRepositoryProvider.overrideWithValue(FakeStatsRepository()),
      ],
```

Replace:
```dart
    await tester.tap(find.byKey(const ValueKey('tab-2')));
    await pumpDial(tester);

    expect(find.text(Strings.comingSoon(Strings.tabStats)), findsOneWidget);
    expect(find.text(Strings.tabStats), findsOneWidget);
    expect(find.text(Strings.tabClock), findsNothing);
```
With:
```dart
    await tester.tap(find.byKey(const ValueKey('tab-2')));
    await pumpDial(tester);

    // The empty stats window: four sections, each with its empty state.
    expect(find.text(Strings.statsToneBalance), findsOneWidget);
    expect(find.text(Strings.statsEmptyToneBalance), findsOneWidget);
    expect(find.text(Strings.tabStats), findsOneWidget);
    expect(find.text(Strings.tabClock), findsNothing);
```

- [ ] **Step 8: Run the tests to verify they pass**

```bash
# expect: PASS - stats screen (6), strings (incl. 1 new), tab scaffold
flutter test test/features/stats/stats_screen_test.dart test/core/strings_test.dart test/app/tab_scaffold_test.dart
```

- [ ] **Step 9: Analyze, run the suite, commit**

```bash
# expect: PASS - analyzer clean; whole suite green
flutter analyze && flutter test
```

```bash
# expect: RUN
git add lib/features/stats/stats_screen.dart lib/features/stats/stats_layout.dart \
  lib/features/stats/widgets/ test/support/clock_harness.dart lib/core/strings.dart \
  lib/shared/layout/content_width.dart test/app/tab_scaffold_test.dart \
  test/features/stats/stats_screen_test.dart test/core/strings_test.dart
git commit -m "feat: stats tab with period header and four sections

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

### Task 9: Stats layout matrix and goldens

The eight-size matrix from the Clock and Calendar, extended to Stats: busy week, empty week, busy month × four text scales. Plus three golden images. The period is pinned to the week of 7 October 2026 in every image so the range label never flakes with the wall clock.

**Files:**
- Test: `test/features/stats/stats_layout_matrix_test.dart` (new), `test/features/stats/stats_screen_golden_test.dart` (new)
- Generated: `test/features/stats/goldens/stats_iphone_light.png`, `stats_iphone_dark.png`, `stats_iphone_empty_light.png`

- [ ] **Step 1: Write the matrix test**

**Create `test/features/stats/stats_layout_matrix_test.dart`**

```dart
// The Stats tab at every window size the app supports, four text scales, a
// busy week, an empty week and a busy month: nothing overflows, everything
// scrolls into view, and no frame throws.
import 'package:energy_clock/app/navigation/tab_bar_inset.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/repositories/stats_repository.dart';
import 'package:energy_clock/features/stats/model/stats_period.dart';
import 'package:energy_clock/features/stats/providers.dart';
import 'package:energy_clock/features/stats/stats_screen.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

/// The window sizes every tab is tested at.
const sizes = <String, Size>{
  'iPhone SE': Size(375, 667),
  'iPhone 17 Pro': Size(402, 874),
  'iPad mini portrait': Size(744, 1133),
  'iPad 11" portrait': Size(834, 1194),
  'iPad 11" landscape': Size(1194, 834),
  'iPad 13" portrait': Size(1032, 1376),
  'iPad 13" landscape': Size(1376, 1032),
  'narrow Split View': Size(320, 1000),
};

/// The tab bar's reserve on a phone with no home indicator.
const double shellInset = 84;

StatsSnapshot filled() => StatsSnapshot(
  toneByDay: [
    for (var day = 5; day <= 11; day++)
      for (final tone in Tone.values)
        (
          date: DateTime(2026, 10, day),
          tone: tone,
          minutes: 20 + ((day * (tone.dbIndex + 2)) % 120),
        ),
  ],
  plannedByTone: const [
    (tone: Tone.focus, plannedMinutes: 900, completedMinutes: 640),
    (tone: Tone.life, plannedMinutes: 420, completedMinutes: 380),
    (tone: Tone.inbox, plannedMinutes: 180, completedMinutes: 200),
  ],
  focus: const FocusDepth(
    minutes: 640,
    longestSeconds: 7200,
    averageSeconds: 3200,
    ended: 13,
    abandoned: 2,
  ),
  focusInstants: [
    for (var day = 5; day <= 11; day++)
      for (final hour in [8, 12, 19])
        (
          startedAt: DateTime(2026, 10, day, hour),
          activeSeconds: 1800 + ((day * hour) % 3600),
        ),
  ],
);

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  for (final entry in sizes.entries) {
    final size = entry.value;
    for (final textScale in const [1.0, 1.3, 2.0, 3.12]) {
      for (final (label, seed, month) in const [
        ('a busy week', true, false),
        ('an empty week', false, false),
        ('a busy month', true, true),
      ]) {
        testWidgets(
          '${entry.key} (${size.width.toInt()} x ${size.height.toInt()}), '
          'text ${(textScale * 100).toInt()}%, $label',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            if (seed) harness.stats.emit(filled());
            if (month) {
              harness.container.read(statsPeriodProvider.notifier).state =
                  StatsPeriod.month(DateTime(2026, 10, 15));
            } else {
              // Pin the week so the range label is deterministic.
              harness.container.read(statsPeriodProvider.notifier).state =
                  StatsPeriod.week(DateTime(2026, 10, 7));
            }

            await tester.pumpWidget(
              harness.app(
                TabBarInset(
                  height: shellInset,
                  child: const StatsScreen(),
                ),
                textScale: textScale,
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            for (final title in [
              Strings.statsToneBalance,
              Strings.statsPlannedActual,
              Strings.statsFocusDepth,
              Strings.statsHeatmap,
            ]) {
              expect(find.text(title), findsOneWidget);
            }

            // Every card stays inside the window horizontally.
            for (final card in find.byType(AppCard).evaluate()) {
              final rect = tester.getRect(find.byWidget(card));
              expect(rect.left, greaterThanOrEqualTo(-0.5));
              expect(rect.right, lessThanOrEqualTo(size.width + 0.5));
            }

            // The last section scrolls into view without throwing.
            await tester.drag(
              find.byType(SingleChildScrollView),
              const Offset(0, -3000),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.text(Strings.statsHeatmap), findsOneWidget);
          },
        );
      }
    }
  }
}
```

- [ ] **Step 2: Run the matrix to verify it passes**

```bash
# expect: PASS - 96 matrix tests pass
flutter test test/features/stats/stats_layout_matrix_test.dart
```

- [ ] **Step 3: Write the golden test**

**Create `test/features/stats/stats_screen_golden_test.dart`**

```dart
// Golden images of the Stats tab, with the floating tab bar: an iPhone in
// light and dark with a busy week, and an iPhone with an empty week. The
// period is pinned to the week of 7 October 2026, animations are off, and
// `test/flutter_test_config.dart` loads Nunito, so every image is
// deterministic and shows real text.
import 'package:energy_clock/app/navigation/tab_scaffold.dart';
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/features/stats/model/stats_period.dart';
import 'package:energy_clock/features/stats/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';
import 'stats_layout_matrix_test.dart' show filled;

const screenKey = ValueKey('stats-screen-golden');

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
    harness.container.read(statsPeriodProvider.notifier).state =
        StatsPeriod.week(DateTime(2026, 10, 7));
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> check(
    WidgetTester tester, {
    required Size size,
    required ThemeData theme,
    required String file,
    bool seeded = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (seeded) harness.stats.emit(filled());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: RepaintBoundary(
          key: screenKey,
          child: MaterialApp(
            theme: theme,
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const TabScaffold(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tab-2')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(screenKey),
      matchesGoldenFile('goldens/$file'),
    );
  }

  testWidgets('iPhone 17 Pro, light', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.light,
      file: 'stats_iphone_light.png',
    );
  });

  testWidgets('iPhone 17 Pro, dark', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.dark,
      file: 'stats_iphone_dark.png',
    );
  });

  testWidgets('iPhone 17 Pro, an empty week, light', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.light,
      file: 'stats_iphone_empty_light.png',
      seeded: false,
    );
  });
}
```

> Note for the implementer: importing `filled()` from the matrix test file works because both live in the same directory, but if the test runner complains about the shared import, copy `filled()` into the golden file instead.

- [ ] **Step 4: Generate the goldens and look at them**

```bash
# expect: RUN - three new images appear under test/features/stats/goldens/
flutter test test/features/stats/stats_screen_golden_test.dart --update-goldens
```

```bash
# expect: MANUAL - open the three images and check: the header shows '5 – 11 Oct 2026'
# with Week selected; tone stacks, paired bars, four metric tiles and the heatmap
# all render inside their cards in both themes; the empty week shows all four
# empty messages and no charts. CupertinoIcons render as tofu on this machine
# (pre-existing baseline) - judge layout, not the chevron glyphs.
```

- [ ] **Step 5: Run the golden test to verify it passes**

```bash
# expect: PASS - 3 golden tests pass
flutter test test/features/stats/stats_screen_golden_test.dart
```

- [ ] **Step 6: Analyze, run the suite, commit**

```bash
# expect: PASS - analyzer clean; whole suite green
flutter analyze && flutter test
```

```bash
# expect: RUN
git add test/features/stats/stats_layout_matrix_test.dart \
  test/features/stats/stats_screen_golden_test.dart test/features/stats/goldens/
git commit -m "test: stats layout matrix and golden images

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Stage 3 — Progress engine, data, roundups

### Task 10: Score, streak and XP — the pure engine

The three pure calculators, with no database and no clock inside: `scoreFor`, `streaks`, and the XP/level functions. Everything takes plain values and returns plain values, so the tests are exhaustive and instant.

**Files:**
- Create: `lib/core/progress/score.dart`, `lib/core/progress/streak.dart`, `lib/core/progress/xp.dart`
- Test: `test/core/progress/score_test.dart`, `test/core/progress/streak_test.dart`, `test/core/progress/xp_test.dart` (new)

**Interfaces:**
- `DayMinutes = ({int focus, int life, int inbox, int planned, int completed})`.
- `ScoreBreakdown({adherencePoints, focusPoints, balancePoints})`, `total`; `scoreFor({required DayMinutes day, required int focusTargetMinutes})`.
  - Adherence: `planned == 0 ? 50 : (completed * 50 / planned).clamp(0, 50).round()`, capped at 50 when over-completing.
  - Focus: `(focusMinutes * 30 / target).clamp(0, 30).round()`; `target <= 0` reads as the default 180.
  - Balance: 20 when all three tones > 0; 8 when exactly two; 0 otherwise. No plan at all (all five inputs 0) scores 0 total, not 70.
- `Streaks = ({int current, int longest, DateTime? lastDate})`; `streaks(List<DateTime> qualifyingDays, {required DateTime today})` — input unsorted with duplicates tolerated; counts back from today (today or yesterday must qualify, else current is 0); `longest` is the longest run anywhere; `lastDate` the latest qualifying day or null.
- XP: `sessionXpMinutes(int minutes, {required bool focus})` (1 per minute, ×1.5 rounded for focus — i.e. `(minutes * 3 / 2).round()`); `badgeXp(int unlocks) = unlocks * 50`; `streakXp(List<DateTime> allQualifying)` = 5 per day beyond the first 7 of *each* run; `xpToReachLevel(int level) = 100 * (level - 1) * level ~/ 2`; `levelForXp(int xp)` = largest L with `xpToReachLevel(L) <= xp` (min 1); `xpIntoLevel(int xp)` and `xpForNextLevel(int level)` helpers for the progress bar.

- [ ] **Step 1: Write the failing tests**

**Create `test/core/progress/score_test.dart`**

```dart
import 'package:energy_clock/core/progress/score.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const target = defaultDailyFocusTargetMinutes;

  test('a perfect day scores 100', () {
    final score = scoreFor(
      day: (focus: 180, life: 60, inbox: 60, planned: 300, completed: 300),
      focusTargetMinutes: target,
    );
    expect(score, (adherencePoints: 50, focusPoints: 30, balancePoints: 20));
    expect(score.total, 100);
  });

  test('adherence is proportional and caps at 50', () {
    expect(
      scoreFor(
        day: (focus: 60, life: 0, inbox: 0, planned: 200, completed: 100),
        focusTargetMinutes: target,
      ).adherencePoints,
      25,
    );
    expect(
      scoreFor(
        day: (focus: 60, life: 0, inbox: 0, planned: 200, completed: 400),
        focusTargetMinutes: target,
      ).adherencePoints,
      50,
    );
  });

  test('an unplanned day still earns focus and balance, not adherence', () {
    final score = scoreFor(
      day: (focus: 90, life: 30, inbox: 0, planned: 0, completed: 120),
      focusTargetMinutes: target,
    );
    expect(score.adherencePoints, 50);
    expect(score.focusPoints, 15);
    expect(score.balancePoints, 8);
  });

  test('focus points scale to the target and cap at 30', () {
    expect(
      scoreFor(
        day: (focus: 360, life: 0, inbox: 0, planned: 60, completed: 60),
        focusTargetMinutes: target,
      ).focusPoints,
      30,
    );
    expect(
      scoreFor(
        day: (focus: 60, life: 0, inbox: 0, planned: 60, completed: 60),
        focusTargetMinutes: 120,
      ).focusPoints,
      15,
    );
  });

  test('a non-positive target reads as the default', () {
    expect(
      scoreFor(
        day: (focus: 90, life: 0, inbox: 0, planned: 60, completed: 60),
        focusTargetMinutes: 0,
      ).focusPoints,
      15,
    );
  });

  test('balance pays 20, 8 or 0', () {
    int balance(DayMinutes day) =>
        scoreFor(day: day, focusTargetMinutes: target).balancePoints;
    expect(
      balance((focus: 10, life: 10, inbox: 10, planned: 30, completed: 30)),
      20,
    );
    expect(
      balance((focus: 10, life: 10, inbox: 0, planned: 30, completed: 20)),
      8,
    );
    expect(
      balance((focus: 10, life: 0, inbox: 0, planned: 30, completed: 10)),
      0,
    );
  });

  test('a day with nothing scores nothing', () {
    expect(
      scoreFor(
        day: (focus: 0, life: 0, inbox: 0, planned: 0, completed: 0),
        focusTargetMinutes: target,
      ).total,
      0,
    );
  });
}
```

**Create `test/core/progress/streak_test.dart`**

```dart
import 'package:energy_clock/core/progress/streak.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 7);

  List<DateTime> days(List<int> octoberDays) => [
    for (final day in octoberDays) DateTime(2026, 10, day),
  ];

  test('an unbroken run to today counts fully', () {
    expect(
      streaks(days([3, 4, 5, 6, 7]), today: today),
      (current: 5, longest: 5, lastDate: DateTime(2026, 10, 7)),
    );
  });

  test('a run ending yesterday still counts today', () {
    expect(
      streaks(days([5, 6]), today: today).current,
      2,
    );
  });

  test('a gap before today breaks the current run but not the longest', () {
    final result = streaks(days([1, 2, 3, 5]), today: today);
    expect(result.current, 0);
    expect(result.longest, 3);
    expect(result.lastDate, DateTime(2026, 10, 5));
  });

  test('duplicates and shuffling do not matter', () {
    expect(
      streaks(days([7, 5, 6, 5, 7]), today: today).current,
      3,
    );
  });

  test('no qualifying days means no streak', () {
    expect(
      streaks(const [], today: today),
      (current: 0, longest: 0, lastDate: null),
    );
  });

  test('a future day never extends the run', () {
    expect(
      streaks(days([7, 8]), today: today).current,
      1,
    );
  });
}
```

**Create `test/core/progress/xp_test.dart`**

```dart
import 'package:energy_clock/core/progress/xp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sessions pay a point a minute, focus pays half as much again', () {
    expect(sessionXpMinutes(60, focus: false), 60);
    expect(sessionXpMinutes(60, focus: true), 90);
    expect(sessionXpMinutes(1, focus: true), 2);
  });

  test('badges pay fifty each', () {
    expect(badgeXp(0), 0);
    expect(badgeXp(3), 150);
  });

  test('streaks pay five a day past the first week of each run', () {
    // One 10-day run: 3 paid days.
    expect(
      streakXp([for (var d = 1; d <= 10; d++) DateTime(2026, 10, d)]),
      15,
    );
    // Two short runs pay nothing; a 7-day run pays nothing either.
    expect(
      streakXp([
        for (var d = 1; d <= 4; d++) DateTime(2026, 10, d),
        for (var d = 20; d <= 26; d++) DateTime(2026, 10, d),
      ]),
      0,
    );
  });

  test('levels rise every hundred-times-triangular XP', () {
    expect(xpToReachLevel(1), 0);
    expect(xpToReachLevel(2), 100);
    expect(xpToReachLevel(3), 300);
    expect(xpToReachLevel(4), 600);
    expect(levelForXp(0), 1);
    expect(levelForXp(99), 1);
    expect(levelForXp(100), 2);
    expect(levelForXp(599), 3);
    expect(levelForXp(600), 4);
  });

  test('the progress bar helpers agree with the level', () {
    expect(xpIntoLevel(250), (current: 250, start: 100, end: 300));
    expect(xpForNextLevel(1), 100);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL - compile error: lib/core/progress/ does not exist yet.
flutter test test/core/progress/score_test.dart test/core/progress/streak_test.dart test/core/progress/xp_test.dart
```

- [ ] **Step 3: Create the engine**

**Create `lib/core/progress/score.dart`**

```dart
/// The focus target every score measures against, in minutes (spec §9.3). It
/// lives here — not in `lib/app/settings/` — so `lib/core/` never imports
/// `lib/app/`. The settings provider imports this constant as its default.
const int defaultDailyFocusTargetMinutes = 180;

/// One day's minute pool: completed minutes by tone, plus the planned and
/// completed totals.
typedef DayMinutes = ({
  int focus,
  int life,
  int inbox,
  int planned,
  int completed,
});

/// A day's score split into its three parts (spec §9.3).
typedef ScoreBreakdown = ({
  int adherencePoints,
  int focusPoints,
  int balancePoints,
});

/// The total of a breakdown.
extension ScoreTotal on ScoreBreakdown {
  int get total => adherencePoints + focusPoints + balancePoints;
}

/// Scores one day, 0–100. A day with nothing planned and nothing done scores 0
/// outright; any other day earns up to 50 adherence (an unplanned day with
/// sessions still earns the full 50), up to 30 focus against
/// [focusTargetMinutes], and 20/8/0 balance for three/two/one tones used.
ScoreBreakdown scoreFor({
  required DayMinutes day,
  required int focusTargetMinutes,
}) {
  if (day.planned == 0 &&
      day.completed == 0 &&
      day.focus == 0 &&
      day.life == 0 &&
      day.inbox == 0) {
    return (adherencePoints: 0, focusPoints: 0, balancePoints: 0);
  }
  final adherence =
      day.planned == 0
          ? 50
          : (day.completed * 50 / day.planned).clamp(0, 50).round();
  final target =
      focusTargetMinutes <= 0
          ? defaultDailyFocusTargetMinutes
          : focusTargetMinutes;
  final focus = (day.focus * 30 / target).clamp(0, 30).round();
  final tonesUsed = [
    day.focus,
    day.life,
    day.inbox,
  ].where((minutes) => minutes > 0).length;
  final balance = switch (tonesUsed) {
    3 => 20,
    2 => 8,
    _ => 0,
  };
  return (
    adherencePoints: adherence,
    focusPoints: focus,
    balancePoints: balance,
  );
}
```

**Create `lib/core/progress/streak.dart`**

```dart
/// True when [b] is the calendar day after [a]. Calendar arithmetic, not a
/// 24-hour duration: across a DST change two consecutive local midnights are
/// 23 or 25 real hours apart, and `inDays` would misread them.
bool isNextCalendarDay(DateTime a, DateTime b) =>
    b == DateTime(a.year, a.month, a.day + 1);

/// A streak evaluation: the run ending today (or yesterday), the longest run
/// anywhere, and the latest qualifying day.
typedef Streaks = ({int current, int longest, DateTime? lastDate});

/// Evaluates [qualifyingDays] (local midnights with at least one `countsAsDone`
/// session) against [today]. Duplicates, shuffling and future days are
/// tolerated. A run ending yesterday still counts — the user has until tonight.
Streaks streaks(List<DateTime> qualifyingDays, {required DateTime today}) {
  final days = {
    for (final day in qualifyingDays)
      if (!day.isAfter(today)) DateTime(day.year, day.month, day.day),
  }.toList()..sort();
  if (days.isEmpty) return (current: 0, longest: 0, lastDate: null);

  var longest = 1;
  var run = 1;
  for (var i = 1; i < days.length; i++) {
    if (isNextCalendarDay(days[i - 1], days[i])) {
      run++;
      if (run > longest) longest = run;
    } else {
      run = 1;
    }
  }

  final last = days.last;
  final gap = today.difference(last).inDays;
  var current = 0;
  if (gap <= 1) {
    current = 1;
    for (var i = days.length - 1; i > 0; i--) {
      if (isNextCalendarDay(days[i - 1], days[i])) {
        current++;
      } else {
        break;
      }
    }
  }
  return (current: current, longest: longest, lastDate: last);
}
```

**Create `lib/core/progress/xp.dart`**

```dart
import 'package:energy_clock/core/progress/streak.dart'
    show isNextCalendarDay;

/// A timed session pays a point a minute; focus pays half as much again.
int sessionXpMinutes(int minutes, {required bool focus}) =>
    focus ? (minutes * 3 / 2).round() : minutes;

/// Every badge unlock pays 50.
int badgeXp(int unlocks) => unlocks * 50;

/// Long streaks pay 5 XP per day past the first 7 of *each* run. Runs are
/// maximal consecutive-day runs over the sorted unique input.
int streakXp(List<DateTime> allQualifying) {
  final days = {
    for (final day in allQualifying) DateTime(day.year, day.month, day.day),
  }.toList()..sort();
  var xp = 0;
  var run = 0;
  for (var i = 0; i < days.length; i++) {
    if (i > 0 && isNextCalendarDay(days[i - 1], days[i])) {
      run++;
    } else {
      run = 1;
    }
    if (run > 7) xp += 5;
  }
  return xp;
}

/// The cumulative XP a level starts at: 100 times the triangular number, so
/// level 1 starts at 0, level 2 at 100, level 3 at 300, level 4 at 600.
int xpToReachLevel(int level) => 100 * (level - 1) * level ~/ 2;

/// The level [xp] has reached: the largest level it can afford, at least 1.
int levelForXp(int xp) {
  var level = 1;
  while (xpToReachLevel(level + 1) <= xp) {
    level++;
  }
  return level;
}

/// Where [xp] sits inside its level, for the progress bar.
({int current, int start, int end}) xpIntoLevel(int xp) {
  final level = levelForXp(xp);
  return (current: xp, start: xpToReachLevel(level), end: xpToReachLevel(level + 1));
}

/// The XP the next level starts at.
int xpForNextLevel(int level) => xpToReachLevel(level + 1);
```

- [ ] **Step 3b: Point the settings provider at the moved constant**

**Edit `lib/app/settings/settings_providers.dart`** — two pairs

Replace:
```dart
import 'package:energy_clock/data/providers.dart';
```
With:
```dart
import 'package:energy_clock/core/progress/score.dart';
import 'package:energy_clock/data/providers.dart';
```

Replace:
```dart
/// The focus target every score measures against, in minutes (spec §9.3).
const int defaultDailyFocusTargetMinutes = 180;
```
With:
```dart
/// The focus target every score measures against, in minutes (spec §9.3).
/// Declared in `lib/core/progress/score.dart` so `lib/core/` never imports
/// `lib/app/`; re-exported here by import for existing readers.
export 'package:energy_clock/core/progress/score.dart'
    show defaultDailyFocusTargetMinutes;
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
# expect: PASS - 18 tests (7 score + 6 streak + 5 XP)
flutter test test/core/progress/score_test.dart test/core/progress/streak_test.dart test/core/progress/xp_test.dart
```

- [ ] **Step 5: Analyze, run the suite, commit**

```bash
# expect: PASS - analyzer clean; whole suite green
flutter analyze && flutter test
```

```bash
# expect: RUN
git add lib/core/progress/score.dart lib/core/progress/streak.dart lib/core/progress/xp.dart \
  lib/app/settings/settings_providers.dart \
  test/core/progress/score_test.dart test/core/progress/streak_test.dart test/core/progress/xp_test.dart
git commit -m "feat: pure score, streak and XP calculators

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

### Task 11: Badges — definitions and evaluation

The ten badges as data plus the pure evaluator. Facts come from source tables at evaluation time (Task 13); this task only decides, given facts, which stable ids are newly earned.

**Files:**
- Create: `lib/core/progress/badges.dart`
- Modify: `lib/core/strings.dart` (badge titles + descriptions), `test/core/strings_test.dart` (1 new test)
- Test: `test/core/progress/badges_test.dart` (new)

**Interfaces:**
- `BadgeFacts({endedSessions, qualifyingDates, fourHourFocusDays, allToneWeeks, cleanWeeks, hasEarlyFocus})` — weeks are Monday starts, always (spec §9.4).
- `BadgeDefinition({id, title, description, test})`; `badgeDefinitions` (10, spec §9.4 order); `badgesToUnlock(BadgeFacts, Set<String> alreadyUnlocked) → List<String>` (definition order, excluding unlocked).
- `longestRun(List<DateTime>) → int` (maximal consecutive-day run; shared by the streak badges; DST-safe via `isNextCalendarDay`).

- [ ] **Step 1: Write the failing tests**

**Create `test/core/progress/badges_test.dart`**

```dart
import 'package:energy_clock/core/progress/badges.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const empty = BadgeFacts(
    endedSessions: 0,
    qualifyingDates: [],
    fourHourFocusDays: {},
    allToneWeeks: {},
    cleanWeeks: {},
    hasEarlyFocus: false,
  );

  BadgeFacts withSessions(int count) => BadgeFacts(
    endedSessions: count,
    qualifyingDates: const [],
    fourHourFocusDays: const {},
    allToneWeeks: const {},
    cleanWeeks: const {},
    hasEarlyFocus: false,
  );

  test('the definitions are ten stable ids in spec order', () {
    expect(
      badgeDefinitions.map((badge) => badge.id),
      [
        'first_session',
        'sessions_10',
        'sessions_50',
        'sessions_100',
        'focus_day_4h',
        'week_all_tones',
        'streak_7',
        'streak_30',
        'week_no_abandoned',
        'early_bird',
      ],
    );
    for (final badge in badgeDefinitions) {
      expect(badge.title, isNotEmpty);
      expect(badge.description, isNotEmpty);
    }
  });

  test('empty facts earn nothing', () {
    expect(badgesToUnlock(empty, const {}), isEmpty);
  });

  test('session counts unlock their badges together', () {
    expect(badgesToUnlock(withSessions(1), const {}), ['first_session']);
    expect(
      badgesToUnlock(withSessions(100), const {}),
      ['first_session', 'sessions_10', 'sessions_50', 'sessions_100'],
    );
  });

  test('already-unlocked badges are not awarded again', () {
    expect(
      badgesToUnlock(withSessions(100), {'first_session', 'sessions_10'}),
      ['sessions_50', 'sessions_100'],
    );
  });

  test('day, week and early badges read their own facts', () {
    final facts = BadgeFacts(
      endedSessions: 5,
      qualifyingDates: const [],
      fourHourFocusDays: {DateTime(2026, 10, 6)},
      allToneWeeks: {DateTime(2026, 10, 5)},
      cleanWeeks: {DateTime(2026, 10, 5)},
      hasEarlyFocus: true,
    );
    expect(
      badgesToUnlock(facts, const {}),
      ['first_session', 'focus_day_4h', 'week_all_tones', 'week_no_abandoned', 'early_bird'],
    );
  });

  test('streak badges need a long enough run', () {
    BadgeFacts run(int days) => BadgeFacts(
      endedSessions: days,
      qualifyingDates: [for (var d = 1; d <= days; d++) DateTime(2026, 9, d)],
      fourHourFocusDays: const {},
      allToneWeeks: const {},
      cleanWeeks: const {},
      hasEarlyFocus: false,
    );
    expect(badgesToUnlock(run(7), const {}), contains('streak_7'));
    expect(badgesToUnlock(run(7), const {}), isNot(contains('streak_30')));
    expect(
      badgesToUnlock(run(30), const {}),
      containsAll(['streak_7', 'streak_30']),
    );
  });

  test('longestRun tolerates shuffling and duplicates', () {
    expect(longestRun(const []), 0);
    expect(
      longestRun([
        DateTime(2026, 10, 7),
        DateTime(2026, 10, 5),
        DateTime(2026, 10, 6),
        DateTime(2026, 10, 6),
      ]),
      3,
    );
  });
}
```

**Edit `test/core/strings_test.dart`** — insert before the final closing `}` of `main()`:

```dart
    test('every badge has a title and a description', () {
      expect(badgeDefinitions, hasLength(10));
      for (final badge in badgeDefinitions) {
        expect(badge.title, isNotEmpty);
        expect(badge.description, isNotEmpty);
      }
    });
```

> Note for the implementer: that test imports `package:energy_clock/core/progress/badges.dart` — add the import.

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL - compile error: badges.dart does not exist yet.
flutter test test/core/progress/badges_test.dart test/core/strings_test.dart
```

- [ ] **Step 3: Add the badge strings**

**Edit `lib/core/strings.dart`** — insert after the Statistics block's last entry (`statsHeatmapBusiest`):

Replace:
```dart
  static String statsHeatmapBusiest(
    String weekday,
    String hour,
    String duration,
  ) =>
      'Busiest: $weekday $hour ($duration)';
```
With:
```dart
  static String statsHeatmapBusiest(
    String weekday,
    String hour,
    String duration,
  ) =>
      'Busiest: $weekday $hour ($duration)';

  // Badges (spec §9.4).
  static const String badgeFirstSessionTitle = 'First session';
  static const String badgeFirstSessionDescription = 'Finish any session.';
  static const String badgeSessions10Title = '10 sessions';
  static const String badgeSessions10Description = 'End 10 sessions.';
  static const String badgeSessions50Title = '50 sessions';
  static const String badgeSessions50Description = 'End 50 sessions.';
  static const String badgeSessions100Title = '100 sessions';
  static const String badgeSessions100Description = 'End 100 sessions.';
  static const String badgeFocusDayTitle = 'Four-hour focus day';
  static const String badgeFocusDayDescription =
      'Focus for four hours in a single day.';
  static const String badgeWeekTonesTitle = 'Full spectrum';
  static const String badgeWeekTonesDescription =
      'Use all three tones in one week.';
  static const String badgeStreak7Title = 'Seven-day streak';
  static const String badgeStreak7Description =
      'Keep a streak going for seven days.';
  static const String badgeStreak30Title = 'Thirty-day streak';
  static const String badgeStreak30Description =
      'Keep a streak going for thirty days.';
  static const String badgeCleanWeekTitle = 'Clean week';
  static const String badgeCleanWeekDescription =
      'A week with sessions and nothing abandoned.';
  static const String badgeEarlyBirdTitle = 'Early bird';
  static const String badgeEarlyBirdDescription =
      'Start a focus session before 08:00.';
```

- [ ] **Step 4: Create the badges engine**

**Create `lib/core/progress/badges.dart`**

```dart
import 'package:energy_clock/core/progress/streak.dart'
    show isNextCalendarDay;
import 'package:energy_clock/core/strings.dart';

/// Everything the badge predicates read, queried from source tables at
/// evaluation time (spec §9.1) — never from the `day_scores` cache. Weeks are
/// Monday starts, always.
class BadgeFacts {
  const BadgeFacts({
    required this.endedSessions,
    required this.qualifyingDates,
    required this.fourHourFocusDays,
    required this.allToneWeeks,
    required this.cleanWeeks,
    required this.hasEarlyFocus,
  });

  /// Every non-running session ever: the denominator of the count badges.
  final int endedSessions;

  /// Sorted unique local midnights with a `countsAsDone` session.
  final List<DateTime> qualifyingDates;

  /// Days with at least 240 `countsAsDone` focus minutes.
  final Set<DateTime> fourHourFocusDays;

  /// Monday starts of weeks with minutes in all three tones.
  final Set<DateTime> allToneWeeks;

  /// Monday starts of weeks with at least one ended session and none abandoned.
  final Set<DateTime> cleanWeeks;

  /// Whether a `countsAsDone` focus session ever started before 08:00.
  final bool hasEarlyFocus;
}

/// One badge: a stable id, its copy, and its predicate over the facts.
class BadgeDefinition {
  const BadgeDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.test,
  });

  final String id;
  final String title;
  final String description;
  final bool Function(BadgeFacts facts) test;
}

/// The longest maximal consecutive-day run in [days]. Order- and
/// duplicate-tolerant.
int longestRun(List<DateTime> days) {
  final sorted = {
    for (final day in days) DateTime(day.year, day.month, day.day),
  }.toList()..sort();
  var longest = 0;
  var run = 0;
  for (var i = 0; i < sorted.length; i++) {
    if (i > 0 && isNextCalendarDay(sorted[i - 1], sorted[i])) {
      run++;
    } else {
      run = 1;
    }
    if (run > longest) longest = run;
  }
  return longest;
}

/// The ten badges, in spec §9.4 order.
final List<BadgeDefinition> badgeDefinitions = [
  BadgeDefinition(
    id: 'first_session',
    title: Strings.badgeFirstSessionTitle,
    description: Strings.badgeFirstSessionDescription,
    test: (facts) => facts.endedSessions >= 1,
  ),
  BadgeDefinition(
    id: 'sessions_10',
    title: Strings.badgeSessions10Title,
    description: Strings.badgeSessions10Description,
    test: (facts) => facts.endedSessions >= 10,
  ),
  BadgeDefinition(
    id: 'sessions_50',
    title: Strings.badgeSessions50Title,
    description: Strings.badgeSessions50Description,
    test: (facts) => facts.endedSessions >= 50,
  ),
  BadgeDefinition(
    id: 'sessions_100',
    title: Strings.badgeSessions100Title,
    description: Strings.badgeSessions100Description,
    test: (facts) => facts.endedSessions >= 100,
  ),
  BadgeDefinition(
    id: 'focus_day_4h',
    title: Strings.badgeFocusDayTitle,
    description: Strings.badgeFocusDayDescription,
    test: (facts) => facts.fourHourFocusDays.isNotEmpty,
  ),
  BadgeDefinition(
    id: 'week_all_tones',
    title: Strings.badgeWeekTonesTitle,
    description: Strings.badgeWeekTonesDescription,
    test: (facts) => facts.allToneWeeks.isNotEmpty,
  ),
  BadgeDefinition(
    id: 'streak_7',
    title: Strings.badgeStreak7Title,
    description: Strings.badgeStreak7Description,
    test: (facts) => longestRun(facts.qualifyingDates) >= 7,
  ),
  BadgeDefinition(
    id: 'streak_30',
    title: Strings.badgeStreak30Title,
    description: Strings.badgeStreak30Description,
    test: (facts) => longestRun(facts.qualifyingDates) >= 30,
  ),
  BadgeDefinition(
    id: 'week_no_abandoned',
    title: Strings.badgeCleanWeekTitle,
    description: Strings.badgeCleanWeekDescription,
    test: (facts) => facts.cleanWeeks.isNotEmpty,
  ),
  BadgeDefinition(
    id: 'early_bird',
    title: Strings.badgeEarlyBirdTitle,
    description: Strings.badgeEarlyBirdDescription,
    test: (facts) => facts.hasEarlyFocus,
  ),
];

/// The ids in [badgeDefinitions] order that [facts] newly earn: predicates
/// that hold, minus [alreadyUnlocked].
List<String> badgesToUnlock(BadgeFacts facts, Set<String> alreadyUnlocked) => [
  for (final badge in badgeDefinitions)
    if (!alreadyUnlocked.contains(badge.id) && badge.test(facts)) badge.id,
];
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
# expect: PASS - 8 tests (7 badges + 1 strings)
flutter test test/core/progress/badges_test.dart test/core/strings_test.dart
```

- [ ] **Step 6: Analyze, run the suite, commit**

```bash
# expect: PASS - analyzer clean; whole suite green
flutter analyze && flutter test
```

```bash
# expect: RUN
git add lib/core/progress/badges.dart lib/core/strings.dart \
  test/core/progress/badges_test.dart test/core/strings_test.dart
git commit -m "feat: badge definitions and pure evaluation

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

### Task 12: ProgressDao and ProgressRepository

The write side of progress: per-day score finalisation, the single progress row, badge unlocks, and the three entry points (`onSessionEnded`, `ensureFresh`, `recalculateAll`). Facts are always queried from source tables. The focus target is injected (`readFocusTarget`, defaulting to the settings table) and the clock is injected (`now`), so tests pin both.

**Files:**
- Create: `lib/data/daos/progress_dao.dart`, `lib/data/repositories/progress_repository.dart`, `test/support/fake_progress_repository.dart`
- Modify: `lib/data/database.dart` (register `ProgressDao`), `lib/data/providers.dart` (`progressRepositoryProvider`), `test/support/clock_harness.dart` (progress fake)
- Test: `test/data/progress_repository_test.dart` (new)

**Interfaces:**
- `ProgressDao` (accessor on `[DayScores, Progress, BadgeUnlocks, Sessions, Events]`): `dayScoreFor(date)`, `upsertDayScore`, `deleteDayScore(date)`, `clearDayScores()`, `progressRow()`, `upsertProgress`, `unlockedBadgeIds()`, `unlockBadges(ids, now)`, `plannedMinutesByDay(from, to)`, `datesWithData()`, `endedSessionCount()`, `qualifyingDates()` (ascending), `focusSecondsByDay()` (all-time per date), `tonePresence()` (`List<({DateTime date, int toneIndex, int seconds})>`), `dayOutcomes()` (`List<({DateTime date, int ended, int abandoned})>`), `focusStartTimes()`, `sessionXpInputs()` (`List<({int seconds, int toneIndex})>`).
- `ProgressRepository`: `watchProgress() → Stream<ProgressRow?>`, `watchDayScore(date) → Stream<DayScoreRow?>`, `watchBadges() → Stream<List<BadgeUnlockRow>>`, `onSessionEnded(eventDate)`, `ensureFresh()`, `recalculateAll()`.
- `DriftProgressRepository(db, {now, readFocusTarget})`.
- `FakeProgressRepository`: plain-Dart state (`progress` row, `scores` map, `badges` list), call counters (`ensureFreshCalls`, `recalculateAllCalls`, `endedDates`), `setProgress/setScore/emitBadges` re-emit, `dispose()`.

- [ ] **Step 1: Write the failing tests**

**Create `test/data/progress_repository_test.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:energy_clock/core/session/session_outcome.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/progress_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftProgressRepository repository;
  DateTime now = DateTime(2026, 10, 7, 18);

  final monday = DateTime(2026, 10, 5);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    now = DateTime(2026, 10, 7, 18);
    repository = DriftProgressRepository(db, now: () => now);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> seedEvent({
    required DateTime date,
    Tone tone = Tone.focus,
    int start = 540,
    int end = 660,
  }) => db.eventDao.insertEvent(
    EventsCompanion.insert(
      date: date,
      title: 'Event',
      toneIndex: tone.dbIndex,
      startMinute: start,
      endMinute: end,
      createdAt: now,
      updatedAt: now,
    ),
  );

  Future<void> seedSession({
    required int eventId,
    SessionOutcome outcome = SessionOutcome.completed,
    int activeSeconds = 3600,
    DateTime? startedAt,
  }) => db.sessionDao.insertSession(
    SessionsCompanion.insert(
      eventId: eventId,
      startedAt: startedAt ?? DateTime(2026, 10, 7, 9),
      plannedSeconds: 3600,
      activeSeconds: Value(activeSeconds),
      outcome: Value(outcome.dbIndex),
    ),
  );

  test('ending a session writes the day score and the progress row', () async {
    final id = await seedEvent(date: DateTime(2026, 10, 7));
    await seedSession(eventId: id, activeSeconds: 5400);
    await repository.onSessionEnded(DateTime(2026, 10, 7));

    final score = await db.progressDao.dayScoreFor(DateTime(2026, 10, 7));
    expect(score, isNotNull);
    // 120 planned, 90 completed: 38 adherence; 90 focus of 180: 15; one tone: 0.
    expect(score!.energyScore, 53);
    expect(score.focusMinutes, 90);
    expect(score.plannedMinutes, 120);
    final progress = await db.progressDao.progressRow();
    expect(progress, isNotNull);
    expect(progress!.currentStreak, 1);
    // 90 focus minutes pay 135 XP plus 50 for the first badge: level 2.
    expect(progress.xp, 185);
    expect(progress.level, 2);
    expect(progress.lastStreakDate, DateTime(2026, 10, 7));
  });

  test('the first ended session unlocks the first badge', () async {
    await seedSession(eventId: await seedEvent(date: monday));
    await repository.onSessionEnded(monday);

    expect(await db.progressDao.unlockedBadgeIds(), ['first_session']);
  });

  test('consecutive qualifying days build the streak', () async {
    await seedSession(eventId: await seedEvent(date: monday));
    await seedSession(eventId: await seedEvent(date: DateTime(2026, 10, 6)));
    await repository.onSessionEnded(DateTime(2026, 10, 6));

    final progress = await db.progressDao.progressRow();
    expect(progress!.currentStreak, 2);
    expect(progress.longestStreak, 2);
  });

  test('ensureFresh finalises yesterday after the day rolls over', () async {
    await seedSession(eventId: await seedEvent(date: monday));
    await seedSession(eventId: await seedEvent(date: DateTime(2026, 10, 6)));
    await repository.onSessionEnded(DateTime(2026, 10, 6));
    expect((await db.progressDao.progressRow())!.currentStreak, 2);

    now = DateTime(2026, 10, 9, 8);
    await repository.ensureFresh();

    final progress = await db.progressDao.progressRow();
    expect(progress!.currentStreak, 0);
    expect(progress.longestStreak, 2);
    expect(progress.lastStreakDate, DateTime(2026, 10, 9));
    // Yesterday had nothing: no row was invented for it.
    expect(await db.progressDao.dayScoreFor(DateTime(2026, 10, 8)), isNull);
  });

  test('a fresh progress row needs no work', () async {
    await seedSession(eventId: await seedEvent(date: DateTime(2026, 10, 7)));
    await repository.onSessionEnded(DateTime(2026, 10, 7));
    final progress = await db.progressDao.progressRow();

    await repository.ensureFresh();
    expect(await db.progressDao.progressRow(), progress);
  });

  test('past day scores are never silently recomputed', () async {
    final id = await seedEvent(date: monday);
    await seedSession(eventId: id, activeSeconds: 3600);
    await repository.onSessionEnded(monday);
    final frozen = await db.progressDao.dayScoreFor(monday);

    now = DateTime(2026, 10, 6, 18);
    await seedSession(
      eventId: await seedEvent(date: DateTime(2026, 10, 6)),
      activeSeconds: 7200,
      startedAt: DateTime(2026, 10, 6, 9),
    );
    await repository.onSessionEnded(DateTime(2026, 10, 6));

    final reread = await db.progressDao.dayScoreFor(monday);
    expect(reread!.computedAt, frozen!.computedAt);
    expect(reread.energyScore, frozen.energyScore);
  });

  test('recalculateAll rebuilds every row from source', () async {
    final id = await seedEvent(date: monday, start: 540, end: 660);
    await seedSession(eventId: id, activeSeconds: 3600);
    await repository.onSessionEnded(monday);
    final before = await db.progressDao.dayScoreFor(monday);

    await db.progressDao.clearDayScores();
    expect(await db.progressDao.dayScoreFor(monday), isNull);
    await repository.recalculateAll();

    final after = await db.progressDao.dayScoreFor(monday);
    expect(after!.energyScore, before!.energyScore);
    expect(after.focusMinutes, before.focusMinutes);
    expect((await db.progressDao.progressRow())!.currentStreak, 1);
    expect(await db.progressDao.unlockedBadgeIds(), ['first_session']);
  });

  test('the stored focus target scales focus points', () async {
    await db.settingsDao.setValue('daily_focus_target', '60');
    final id = await seedEvent(date: DateTime(2026, 10, 7));
    await seedSession(eventId: id, activeSeconds: 3600);
    await repository.onSessionEnded(DateTime(2026, 10, 7));

    final score = await db.progressDao.dayScoreFor(DateTime(2026, 10, 7));
    expect(score!.focusPoints, 30);
  });

  test('progress watches emit on session end', () async {
    final id = await seedEvent(date: DateTime(2026, 10, 7));
    await seedSession(eventId: id);
    final emissions = repository.watchProgress().take(2).toList();
    await Future<void>.delayed(Duration.zero);
    await repository.onSessionEnded(DateTime(2026, 10, 7));

    final rows = await emissions;
    expect(rows.first, isNull);
    expect(rows.last!.currentStreak, 1);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL - compile error: ProgressDao, ProgressRepository and DriftProgressRepository do not exist yet.
flutter test test/data/progress_repository_test.dart
```

- [ ] **Step 3: Create the DAO**

**Create `lib/data/daos/progress_dao.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:energy_clock/core/session/session_outcome.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/tables/day_scores_table.dart';
import 'package:energy_clock/data/tables/events_table.dart';
import 'package:energy_clock/data/tables/progress_table.dart';
import 'package:energy_clock/data/tables/sessions_table.dart';
import 'package:energy_clock/data/tables/weekly_roundups_table.dart';

part 'progress_dao.g.dart';

/// Reads and writes the progress caches, and the source-table aggregates the
/// progress evaluation needs (spec §9.1). Everything recomputable lives behind
/// `recalculateAll()` in the repository; this DAO only moves rows.
@DriftAccessor(
  tables: [DayScores, Progress, BadgeUnlocks, WeeklyRoundups, Sessions, Events],
)
class ProgressDao extends DatabaseAccessor<AppDatabase>
    with _$ProgressDaoMixin {
  ProgressDao(super.attachedDatabase);

  static const _skipped = 2;

  static int get _running => SessionOutcome.running.dbIndex;
  static Expression<bool> get _countsAsDone => sessions.outcome.isIn([
    SessionOutcome.completed.dbIndex,
    SessionOutcome.finishedEarly.dbIndex,
  ]);

  Future<DayScoreRow?> dayScoreFor(DateTime date) =>
      (select(dayScores)..where((row) => row.date.equals(date))).getSingleOrNull();

  Future<void> upsertDayScore(DayScoresCompanion row) =>
      into(dayScores).insertOnConflictUpdate(row);

  Future<void> deleteDayScore(DateTime date) =>
      (delete(dayScores)..where((row) => row.date.equals(date))).go();

  Future<void> clearDayScores() => delete(dayScores).go();

  Future<ProgressRow?> progressRow() =>
      (select(progress)..where((row) => row.id.equals(1))).getSingleOrNull();

  Future<void> upsertProgress(ProgressCompanion row) =>
      into(progress).insertOnConflictUpdate(row);

  Future<List<String>> unlockedBadgeIds() =>
      (select(badgeUnlocks)..orderBy([
          (row) => OrderingTerm.asc(row.unlockedAt),
        ]))
          .map((row) => row.badgeId)
          .get();

  Future<void> unlockBadges(List<String> ids, DateTime now) => batch((batch) {
    for (final id in ids) {
      batch.insert(
        badgeUnlocks,
        BadgeUnlocksCompanion.insert(badgeId: id, unlockedAt: now),
        mode: InsertMode.insertOrReplace,
      );
    }
  });

  Stream<ProgressRow?> watchProgress() =>
      (select(progress)..where((row) => row.id.equals(1))).watchSingleOrNull();

  Stream<DayScoreRow?> watchDayScore(DateTime date) =>
      (select(dayScores)..where((row) => row.date.equals(date))).watchSingleOrNull();

  Stream<List<BadgeUnlockRow>> watchBadges() =>
      (select(badgeUnlocks)..orderBy([
          (row) => OrderingTerm.asc(row.unlockedAt),
        ])).watch();

  /// Planned whole minutes per date in `[from, toExclusive)`, skipping deleted
  /// occurrences.
  Future<List<({DateTime date, int minutes})>> plannedMinutesByDay(
    DateTime from,
    DateTime toExclusive,
  ) {
    final minutes = (events.endMinute - events.startMinute).sum();
    final query =
        selectOnly(events)
          ..addColumns([events.date, minutes])
          ..where(
            events.date.isBiggerOrEqualValue(from) &
                events.date.isSmallerThanValue(toExclusive) &
                events.status.isNotValue(_skipped),
          )
          ..groupBy([events.date]);
    return query
        .map(
          (row) => (
            date: row.read(events.date)!,
            minutes: row.read(minutes) ?? 0,
          ),
        )
        .get();
  }

  /// Every local midnight that has an event, ascending. Sessions always belong
  /// to an event, so this is every day `recalculateAll()` must visit.
  Future<List<DateTime>> datesWithData() {
    final query =
        selectOnly(events, distinct: true)
          ..addColumns([events.date])
          ..orderBy([OrderingTerm.asc(events.date)]);
    return query.map((row) => row.read(events.date)!).get();
  }

  Future<int> endedSessionCount() {
    final ended = countAll(
      filter: sessions.outcome.isNotValue(_running),
    );
    return selectOnly(sessions)
        .addColumns([ended])
        .map((row) => row.read(ended) ?? 0)
        .getSingle();
  }

  /// Distinct event dates with a `countsAsDone` session, ascending.
  Future<List<DateTime>> qualifyingDates() {
    final query =
        selectOnly(events, distinct: true)
          ..addColumns([events.date])
          ..join([
            innerJoin(sessions, sessions.eventId.equalsExp(events.id)),
          ])
          ..where(_countsAsDone)
          ..orderBy([OrderingTerm.asc(events.date)]);
    return query.map((row) => row.read(events.date)!).get();
  }

  /// `countsAsDone` focus seconds per date, all time.
  Future<List<({DateTime date, int seconds})>> focusSecondsByDay() {
    final seconds = sessions.activeSeconds.sum();
    final query =
        selectOnly(events)
          ..addColumns([events.date, seconds])
          ..join([
            innerJoin(sessions, sessions.eventId.equalsExp(events.id)),
          ])
          ..where(
            events.status.isNotValue(_skipped) &
                events.toneIndex.equals(0) &
                _countsAsDone,
          )
          ..groupBy([events.date]);
    return query
        .map(
          (row) => (
            date: row.read(events.date)!,
            seconds: row.read(seconds) ?? 0,
          ),
        )
        .get();
  }

  /// `countsAsDone` seconds per (date, tone), all time. Weeks fold in Dart.
  Future<List<({DateTime date, int toneIndex, int seconds})>> tonePresence() {
    final seconds = sessions.activeSeconds.sum();
    final query =
        selectOnly(events)
          ..addColumns([events.date, events.toneIndex, seconds])
          ..join([
            innerJoin(sessions, sessions.eventId.equalsExp(events.id)),
          ])
          ..where(events.status.isNotValue(_skipped) & _countsAsDone)
          ..groupBy([events.date, events.toneIndex]);
    return query
        .map(
          (row) => (
            date: row.read(events.date)!,
            toneIndex: row.read(events.toneIndex)!,
            seconds: row.read(seconds) ?? 0,
          ),
        )
        .get();
  }

  /// Per date, all time: ended sessions and abandoned sessions.
  Future<List<({DateTime date, int ended, int abandoned})>> dayOutcomes() {
    final ended = countAll(
      filter: sessions.outcome.isNotValue(_running),
    );
    final abandoned = countAll(
      filter: sessions.outcome.equals(SessionOutcome.abandoned.dbIndex),
    );
    final query =
        selectOnly(events)
          ..addColumns([events.date, ended, abandoned])
          ..join([
            innerJoin(sessions, sessions.eventId.equalsExp(events.id)),
          ])
          ..groupBy([events.date]);
    return query
        .map(
          (row) => (
            date: row.read(events.date)!,
            ended: row.read(ended) ?? 0,
            abandoned: row.read(abandoned) ?? 0,
          ),
        )
        .get();
  }

  /// When every `countsAsDone` focus session began. Hours bucket in Dart.
  Future<List<DateTime>> focusStartTimes() {
    final query =
        selectOnly(sessions)
          ..addColumns([sessions.startedAt])
          ..join([
            innerJoin(events, events.id.equalsExp(sessions.eventId)),
          ])
          ..where(events.toneIndex.equals(0) & _countsAsDone);
    return query.map((row) => row.read(sessions.startedAt)!).get();
  }

  /// Every `countsAsDone` session's seconds with its event's tone.
  Future<List<({int seconds, int toneIndex})>> sessionXpInputs() {
    final query = select(sessions).join([
      innerJoin(events, events.id.equalsExp(sessions.eventId)),
    ])..where(_countsAsDone);
    return query
        .map(
          (row) => (
            seconds: row.readTable(sessions).activeSeconds,
            toneIndex: row.readTable(events).toneIndex,
          ),
        )
        .get();
  }
}
```

> Notes for the implementer: `events.toneIndex.equals(0)` is `Tone.focus.dbIndex` spelled out — the DAO deliberately does not import `Tone` (it deals in stored indexes; the repository maps them). If the analyzer prefers a named constant, add `static const _focusTone = 0;` with that comment. `endedSessionCount` builds a `selectOnly(sessions)` with no `where`: that reads the whole table for one number, which is correct at this app's scale.

- [ ] **Step 4: Create the repository, the fake, and register everything**

**Create `lib/data/repositories/progress_repository.dart`**

```dart
import 'package:energy_clock/core/progress/badges.dart';
import 'package:energy_clock/core/progress/score.dart';
import 'package:energy_clock/core/progress/streak.dart';
import 'package:energy_clock/core/progress/xp.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/tables/day_scores_table.dart';
import 'package:energy_clock/data/tables/progress_table.dart';

/// What Profile reads and what the session screen advances.
abstract interface class ProgressRepository {
  Stream<ProgressRow?> watchProgress();
  Stream<DayScoreRow?> watchDayScore(DateTime date);
  Stream<List<BadgeUnlockRow>> watchBadges();

  /// A session on [eventDate] just ended: finalise that day (and today, if
  /// different), then recompute streaks, XP, level and badges.
  Future<void> onSessionEnded(DateTime eventDate);

  /// After launch and when the app returns to the foreground: finalise
  /// yesterday if the day has rolled over, then recompute today.
  Future<void> ensureFresh();

  /// Wipe the caches and rebuild every day from source. Past edits never
  /// trigger this on their own; only the Profile row calls it.
  Future<void> recalculateAll();
}

class DriftProgressRepository implements ProgressRepository {
  DriftProgressRepository(
    this._db, {
    DateTime Function()? now,
    Future<int?> Function()? readFocusTarget,
  }) : _now = now ?? DateTime.now,
       _readFocusTarget = readFocusTarget;

  final AppDatabase _db;
  final DateTime Function() _now;
  final Future<int?> Function()? _readFocusTarget;

  /// The settings table's stored target, or null. The key is declared as
  /// `dailyFocusTargetKey` in `lib/app/settings/settings_providers.dart`;
  /// the literal stays here so `lib/data/` never imports `lib/app/`.
  Future<int> _focusTarget() async {
    final read = _readFocusTarget;
    final stored =
        read == null
            ? int.tryParse(
              await _db.settingsDao.valueFor('daily_focus_target') ?? '',
            )
            : await read();
    return stored ?? defaultDailyFocusTargetMinutes;
  }

  @override
  Stream<ProgressRow?> watchProgress() => _db.progressDao.watchProgress();

  @override
  Stream<DayScoreRow?> watchDayScore(DateTime date) =>
      _db.progressDao.watchDayScore(date);

  @override
  Stream<List<BadgeUnlockRow>> watchBadges() =>
      _db.progressDao.watchBadges();

  @override
  Future<void> onSessionEnded(DateTime eventDate) =>
      _db.transaction(() async {
        final day = startOfDay(eventDate);
        final today = startOfDay(_now());
        await _recalcDay(day);
        if (day != today) await _recalcDay(today);
        await _recompute(today);
      });

  @override
  Future<void> ensureFresh() => _db.transaction(() async {
    final today = startOfDay(_now());
    final last = (await _db.progressDao.progressRow())?.lastStreakDate;
    if (last == null || last.isBefore(previousDay(today))) {
      // The day has rolled over (or nothing was ever computed): finalise
      // yesterday — `_recalcDay` writes nothing when the day has no data —
      // then recompute today.
      await _recalcDay(previousDay(today));
    }
    if (last == null || last.isBefore(today)) {
      await _recalcDay(today);
      await _recompute(today);
    }
  });

  @override
  Future<void> recalculateAll() => _db.transaction(() async {
    await _db.progressDao.clearDayScores();
    for (final date in await _db.progressDao.datesWithData()) {
      await _recalcDay(date);
    }
    await _recompute(startOfDay(_now()));
  });

  /// Scores [day] from source and upserts its row — or deletes the row when
  /// the day holds nothing. Never touches any other day.
  Future<void> _recalcDay(DateTime day) async {
    final next = nextDay(day);
    final cells = await _db.statsDao.toneSecondsByDay(day, next);
    final plannedRows = await _db.progressDao.plannedMinutesByDay(day, next);
    var focus = 0;
    var life = 0;
    var inbox = 0;
    for (final cell in cells) {
      final minutes = cell.seconds ~/ 60;
      switch (Tone.fromDbIndex(cell.toneIndex)) {
        case Tone.focus:
          focus += minutes;
        case Tone.life:
          life += minutes;
        case Tone.inbox:
          inbox += minutes;
      }
    }
    final planned = plannedRows.fold(0, (sum, row) => sum + row.minutes);
    final completed = focus + life + inbox;
    if (planned == 0 && completed == 0) {
      await _db.progressDao.deleteDayScore(day);
      return;
    }
    final score = scoreFor(
      day: (
        focus: focus,
        life: life,
        inbox: inbox,
        planned: planned,
        completed: completed,
      ),
      focusTargetMinutes: await _focusTarget(),
    );
    await _db.progressDao.upsertDayScore(
      DayScoresCompanion.insert(
        date: day,
        energyScore: score.total,
        adherencePoints: score.adherencePoints,
        focusPoints: score.focusPoints,
        balancePoints: score.balancePoints,
        focusMinutes: Value(focus),
        lifeMinutes: Value(life),
        inboxMinutes: Value(inbox),
        plannedMinutes: Value(planned),
        completedMinutes: Value(completed),
        computedAt: _now(),
      ),
    );
  }

  /// Recomputes streaks, XP, level and badge unlocks from source for [today].
  Future<void> _recompute(DateTime today) async {
    final dao = _db.progressDao;
    final qualifying = await dao.qualifyingDates();
    final evaluated = streaks(qualifying, today: today);

    var sessionPoints = 0;
    for (final input in await dao.sessionXpInputs()) {
      sessionPoints += sessionXpMinutes(
        input.seconds ~/ 60,
        focus: input.toneIndex == Tone.focus.dbIndex,
      );
    }

    final unlocked = await dao.unlockedBadgeIds();
    final fresh = badgesToUnlock(
      BadgeFacts(
        endedSessions: await dao.endedSessionCount(),
        qualifyingDates: qualifying,
        fourHourFocusDays: {
          for (final row in await dao.focusSecondsByDay())
            if (row.seconds >= 4 * 3600) row.date,
        },
        allToneWeeks: _weeksWithAllTones(await dao.tonePresence()),
        cleanWeeks: _cleanWeeks(await dao.dayOutcomes()),
        hasEarlyFocus: (await dao.focusStartTimes()).any(
          (started) => started.hour < 8,
        ),
      ),
      unlocked.toSet(),
    );
    if (fresh.isNotEmpty) await dao.unlockBadges(fresh, _now());

    final total =
        sessionPoints +
        badgeXp(unlocked.length + fresh.length) +
        streakXp(qualifying);
    await dao.upsertProgress(
      ProgressCompanion.insert(
        id: const Value(1),
        xp: Value(total),
        level: Value(levelForXp(total)),
        currentStreak: Value(evaluated.current),
        longestStreak: Value(evaluated.longest),
        lastStreakDate: Value(today),
      ),
    );
  }

  /// Monday starts of weeks whose `countsAsDone` minutes touch all three
  /// tones. Weeks are Monday-based here regardless of the first-day setting.
  Set<DateTime> _weeksWithAllTones(
    List<({DateTime date, int toneIndex, int seconds})> cells,
  ) {
    final byWeek = <DateTime, Set<int>>{};
    for (final cell in cells) {
      if (cell.seconds <= 0) continue;
      (byWeek[startOfWeek(cell.date)] ??= {}).add(cell.toneIndex);
    }
    return {
      for (final entry in byWeek.entries)
        if (entry.value.length >= 3) entry.key,
    };
  }

  /// Monday starts of weeks with at least one ended session and none
  /// abandoned, over every tone.
  Set<DateTime> _cleanWeeks(
    List<({DateTime date, int ended, int abandoned})> days,
  ) {
    final byWeek = <DateTime, ({int ended, int abandoned})>{};
    for (final day in days) {
      final week = startOfWeek(day.date);
      final acc = byWeek[week] ?? (ended: 0, abandoned: 0);
      byWeek[week] = (
        ended: acc.ended + day.ended,
        abandoned: acc.abandoned + day.abandoned,
      );
    }
    return {
      for (final entry in byWeek.entries)
        if (entry.value.ended > 0 && entry.value.abandoned == 0) entry.key,
    };
  }
}
```

> Notes for the implementer: `DayScoresCompanion.insert` needs `import 'package:drift/drift.dart';` for `Value` — add it. `previousDay` comes from `day_time.dart` (already imported). If `insertOnConflictUpdate` on `ProgressCompanion` complains about the explicit `id`, the id column is the primary key (Task 1), so the upsert targets it correctly.

**Create `test/support/fake_progress_repository.dart`**

```dart
import 'dart:async';

import 'package:energy_clock/data/repositories/progress_repository.dart';
import 'package:energy_clock/data/tables/day_scores_table.dart';
import 'package:energy_clock/data/tables/progress_table.dart';

export 'package:energy_clock/data/tables/day_scores_table.dart';
export 'package:energy_clock/data/tables/progress_table.dart';

/// In-memory [ProgressRepository] for widget tests. Tests seed [progress],
/// [scores] and [badges] (or call the setters, which re-emit) and read the
/// call counters to assert the triggers fired.
class FakeProgressRepository implements ProgressRepository {
  FakeProgressRepository({
    ProgressRow? progress,
    Map<DateTime, DayScoreRow>? scores,
    List<BadgeUnlockRow>? badges,
  }) : progress = progress ?? ProgressRow(
         id: 1,
         xp: 0,
         level: 1,
         currentStreak: 0,
         longestStreak: 0,
       ),
       scores = scores ?? {},
       badges = badges ?? [];

  ProgressRow? progress;
  final Map<DateTime, DayScoreRow> scores;
  final List<BadgeUnlockRow> badges;

  int ensureFreshCalls = 0;
  int recalculateAllCalls = 0;

  /// Every `eventDate` passed to [onSessionEnded].
  final List<DateTime> endedDates = [];

  final _progressUpdates = StreamController<ProgressRow?>.broadcast();
  final _scoreUpdates =
      StreamController<({DateTime date, DayScoreRow? score})>.broadcast();
  final _badgeUpdates = StreamController<List<BadgeUnlockRow>>.broadcast();

  @override
  Stream<ProgressRow?> watchProgress() async* {
    yield progress;
    yield* _progressUpdates.stream;
  }

  @override
  Stream<DayScoreRow?> watchDayScore(DateTime date) async* {
    yield scores[date];
    await for (final update in _scoreUpdates.stream) {
      if (update.date == date) yield update.score;
    }
  }

  @override
  Stream<List<BadgeUnlockRow>> watchBadges() async* {
    yield badges;
    yield* _badgeUpdates.stream;
  }

  @override
  Future<void> onSessionEnded(DateTime eventDate) async {
    endedDates.add(eventDate);
  }

  @override
  Future<void> ensureFresh() async {
    ensureFreshCalls++;
  }

  @override
  Future<void> recalculateAll() async {
    recalculateAllCalls++;
  }

  void setProgress(ProgressRow? row) {
    progress = row;
    _progressUpdates.add(row);
  }

  void setScore(DateTime date, DayScoreRow? score) {
    if (score == null) {
      scores.remove(date);
    } else {
      scores[date] = score;
    }
    _scoreUpdates.add((date: date, score: score));
  }

  void emitBadges(List<BadgeUnlockRow> rows) {
    badges
      ..clear()
      ..addAll(rows);
    _badgeUpdates.add(badges);
  }

  void dispose() {
    _progressUpdates.close();
    _scoreUpdates.close();
    _badgeUpdates.close();
  }
}
```

> Note for the implementer: the `export` lines re-export the row types so widget tests can name `ProgressRow`/`DayScoreRow`/`BadgeUnlockRow` from one import. If the analyzer flags the exports as unnecessary, drop them and import the table files in the tests instead. `ProgressRow(id: 1, xp: 0, ...)` relies on the generated constructor — confirm its parameter names (`lastStreakDate` nullable, omittable) at implementation time.

**Edit `lib/data/database.dart`** — two pairs

Replace:
```dart
import 'package:energy_clock/data/daos/settings_dao.dart';
```
With:
```dart
import 'package:energy_clock/data/daos/progress_dao.dart';
import 'package:energy_clock/data/daos/settings_dao.dart';
```

Replace:
```dart
  daos: [EventDao, SettingsDao, SessionDao, SeriesDao, TemplateDao, StatsDao],
```
With:
```dart
  daos: [
    EventDao,
    SettingsDao,
    SessionDao,
    SeriesDao,
    TemplateDao,
    StatsDao,
    ProgressDao,
  ],
```

**Edit `lib/data/providers.dart`** — two pairs

Replace:
```dart
import 'package:energy_clock/data/repositories/settings_repository.dart';
```
With:
```dart
import 'package:energy_clock/data/repositories/progress_repository.dart';
import 'package:energy_clock/data/repositories/settings_repository.dart';
```

Replace:
```dart
/// How each day of a month is planned, for the Calendar tab.
```
With:
```dart
/// Scores, streaks, XP and badges, for the Profile tab (spec §9).
final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return DriftProgressRepository(ref.watch(appDatabaseProvider));
});

/// How each day of a month is planned, for the Calendar tab.
```

**Edit `test/support/clock_harness.dart`** — four pairs

Replace:
```dart
import 'fake_session_repository.dart';
```
With:
```dart
import 'fake_progress_repository.dart';
import 'fake_session_repository.dart';
```

Replace:
```dart
/// service, plus
```
With:
```dart
/// service, a fake progress repository, plus
```

Replace:
```dart
  final FakeSettingsRepository settings = FakeSettingsRepository();
  final FakeStatsRepository stats = FakeStatsRepository();
```
With:
```dart
  final FakeSettingsRepository settings = FakeSettingsRepository();
  final FakeStatsRepository stats = FakeStatsRepository();
  final FakeProgressRepository progress = FakeProgressRepository();
```

Replace:
```dart
        statsRepositoryProvider.overrideWithValue(stats),
```
With:
```dart
        statsRepositoryProvider.overrideWithValue(stats),
        progressRepositoryProvider.overrideWithValue(progress),
```

Replace:
```dart
  void dispose() {
    container.dispose();
    stats.dispose();
```
With:
```dart
  void dispose() {
    container.dispose();
    progress.dispose();
    stats.dispose();
```

- [ ] **Step 5: Regenerate**

```bash
# expect: RUN - regenerates progress_dao.g.dart and database.g.dart (ProgressDao accessor)
DART="$(dirname "$(which flutter)")/dart"
"$DART" run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 6: Run the tests to verify they pass**

```bash
# expect: PASS - 9 tests
flutter test test/data/progress_repository_test.dart
```

- [ ] **Step 7: Analyze, run the suite, commit**

```bash
# expect: PASS - analyzer clean; whole suite green
flutter analyze && flutter test
```

```bash
# expect: RUN
git add lib/data/daos/progress_dao.dart lib/data/daos/progress_dao.g.dart \
  lib/data/repositories/progress_repository.dart lib/data/database.dart lib/data/database.g.dart \
  lib/data/providers.dart test/support/fake_progress_repository.dart \
  test/support/clock_harness.dart test/data/progress_repository_test.dart
git commit -m "feat: progress repository with score, streak, XP and badges

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

### Task 13: The session-end hook

The session screen advances progress after every ending — finish, abandon and close-out — without letting a progress failure break ending the session. `data/providers.dart` is already imported by the screen, so no import changes except `foundation` for the failure log.

**Files:**
- Modify: `lib/features/session/session_screen.dart`, `test/support/fake_progress_repository.dart`
- Test: `test/features/session/session_hook_test.dart` (new)

**Interfaces:**
- Private `SessionScreen._advanceProgress(ref)` → `progressRepositoryProvider.onSessionEnded(session.eventDate)`, guarded so a throw only logs.
- `FakeProgressRepository.failOnSessionEnded` (default false): when true, `onSessionEnded` throws `StateError`.

- [ ] **Step 1: Write the failing tests**

**Create `test/features/session/session_hook_test.dart`**

```dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/models/session.dart';
import 'package:energy_clock/features/session/session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';
import '../../support/dial_pump.dart';

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  /// A 30-minute focus event with a session running since 10:00, shown on the
  /// session screen.
  Future<RunningSession> showSession(WidgetTester tester) async {
    final eventId = await harness.repository.createEvent(
      day: DateTime(2026, 10, 7),
      title: 'Deep work',
      tone: Tone.focus,
      range: const MinuteRange(600, 630),
    );
    await harness.sessions.start(eventId: eventId);
    final running = await harness.sessions.runningSession();
    await tester.pumpWidget(harness.app(SessionScreen(session: running!)));
    await pumpDial(tester);
    return running;
  }

  testWidgets('finishing advances progress for the event day', (tester) async {
    await showSession(tester);

    await tester.tap(find.byKey(const ValueKey('session-finish')));
    await pumpDial(tester);

    expect(harness.sessions.ended, hasLength(1));
    expect(harness.progress.endedDates, [DateTime(2026, 10, 7)]);
  });

  testWidgets('abandoning advances progress too', (tester) async {
    await showSession(tester);

    await tester.tap(find.byKey(const ValueKey('session-abandon')));
    await pumpDial(tester);
    await tester.tap(find.text(Strings.sessionAbandon));
    await pumpDial(tester);

    expect(harness.sessions.ended, hasLength(1));
    expect(harness.progress.endedDates, [DateTime(2026, 10, 7)]);
  });

  testWidgets('a failing progress update still ends the session', (tester) async {
    harness.progress.failOnSessionEnded = true;
    await showSession(tester);

    await tester.tap(find.byKey(const ValueKey('session-finish')));
    await pumpDial(tester);

    expect(harness.sessions.ended, hasLength(1));
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL - `harness.progress.endedDates` stays empty: nothing calls onSessionEnded yet.
flutter test test/features/session/session_hook_test.dart
```

- [ ] **Step 3: Add the hook**

**Edit `lib/features/session/session_screen.dart`** — four pairs

Replace:
```dart
import 'package:flutter/material.dart';
```
With:
```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
```
(Confirm at implementation time that `foundation` is not already imported; if it is, skip this pair.)

Replace:
```dart
  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    unawaited(HapticFeedback.mediumImpact());
    final done = await _repository(ref).finish(session.id);
    if (done != null) _announceLogged(messenger, done);
  }
```
With:
```dart
  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    unawaited(HapticFeedback.mediumImpact());
    final done = await _repository(ref).finish(session.id);
    await _advanceProgress(ref);
    if (done != null) _announceLogged(messenger, done);
  }
```

Replace:
```dart
    if (!confirmed) return;
    await _repository(ref).abandon(session.id);
    messenger.showSnackBar(
```
With:
```dart
    if (!confirmed) return;
    await _repository(ref).abandon(session.id);
    await _advanceProgress(ref);
    messenger.showSnackBar(
```

Replace:
```dart
    final done = await _repository(ref).closeOut(session.id);
    ref.read(sessionRecoveryProvider.notifier).resolve();
    if (done != null) _announceLogged(messenger, done);
  }
```
With:
```dart
    final done = await _repository(ref).closeOut(session.id);
    ref.read(sessionRecoveryProvider.notifier).resolve();
    await _advanceProgress(ref);
    if (done != null) _announceLogged(messenger, done);
  }
```

Replace:
```dart
  void _announceLogged(ScaffoldMessengerState messenger, SessionRecord done) {
```
With:
```dart
  /// Advances scores, streaks, XP and badges after a session ends. A failure
  /// here must never break ending the session: the session writes already
  /// committed, and the caches self-heal on the next `ensureFresh()`.
  Future<void> _advanceProgress(WidgetRef ref) async {
    try {
      await ref
          .read(progressRepositoryProvider)
          .onSessionEnded(session.eventDate);
    } on Object catch (error) {
      debugPrint('EnergyClock: progress update failed: $error');
    }
  }

  void _announceLogged(ScaffoldMessengerState messenger, SessionRecord done) {
```

**Edit `test/support/fake_progress_repository.dart`** — two pairs

Replace:
```dart
  int ensureFreshCalls = 0;
  int recalculateAllCalls = 0;
```
With:
```dart
  int ensureFreshCalls = 0;
  int recalculateAllCalls = 0;

  /// Makes [onSessionEnded] throw, as an unwritable database would.
  bool failOnSessionEnded = false;
```

Replace:
```dart
  @override
  Future<void> onSessionEnded(DateTime eventDate) async {
    endedDates.add(eventDate);
  }
```
With:
```dart
  @override
  Future<void> onSessionEnded(DateTime eventDate) async {
    if (failOnSessionEnded) throw StateError('progress is unwritable');
    endedDates.add(eventDate);
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
# expect: PASS - 3 tests
flutter test test/features/session/session_hook_test.dart
```

- [ ] **Step 5: Analyze, run the suite, commit**

```bash
# expect: PASS - analyzer clean; whole suite green
flutter analyze && flutter test
```

```bash
# expect: RUN
git add lib/features/session/session_screen.dart test/support/fake_progress_repository.dart \
  test/features/session/session_hook_test.dart
git commit -m "feat: advance progress when a session ends

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

### Task 14: ISO weeks and the roundup payload

Pure week arithmetic and the frozen roundup codec. Roundup weeks are Monday–Sunday ISO weeks regardless of the first-day setting; the payload is plain JSON with a hand-written codec that rejects malformed shapes.

**Files:**
- Create: `lib/core/roundup/iso_week.dart`, `lib/core/roundup/roundup_payload.dart`
- Test: `test/core/roundup/iso_week_test.dart`, `test/core/roundup/roundup_payload_test.dart` (new)

**Interfaces:**
- `isoWeekOf(DateTime date) → ({int year, int week})` (Thursday rule); `isoWeekStart(int isoYear, int isoWeek) → DateTime` (that week's Monday, local midnight).
- `RoundupPayload` (const): `isoYear`, `isoWeek`, `weekStart`, `adherencePercent (int?)`, `plannedMinutes`, `completedMinutes`, `totalMinutes`, `bestFocusDay (DateTime?)`, `bestFocusMinutes`, `currentStreak`, `longestStreak`, `badgesUnlocked (List<String>)`, `xpEarned`, `previousAdherencePercent (int?)`; `toJson() → Map<String, Object?>`, `fromJson(Map) ` (throws `FormatException` on a bad shape). Dates serialise as `yyyy-MM-dd`.

- [ ] **Step 1: Write the failing tests**

**Create `test/core/roundup/iso_week_test.dart`**

```dart
import 'package:energy_clock/core/roundup/iso_week.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('known dates land in their ISO weeks', () {
    expect(isoWeekOf(DateTime(2026, 1, 1)), (year: 2026, week: 1));
    expect(isoWeekOf(DateTime(2025, 12, 29)), (year: 2026, week: 1));
    expect(isoWeekOf(DateTime(2026, 12, 31)), (year: 2026, week: 53));
    expect(isoWeekOf(DateTime(2026, 10, 7)), (year: 2026, week: 41));
    expect(isoWeekOf(DateTime(2025, 12, 28)), (year: 2025, week: 52));
  });

  test('week starts are the Mondays of those weeks', () {
    expect(isoWeekStart(2026, 41), DateTime(2026, 10, 5));
    expect(isoWeekStart(2026, 1), DateTime(2025, 12, 29));
    expect(isoWeekStart(2026, 53), DateTime(2026, 12, 28));
  });

  test('every date sits inside its own week', () {
    for (final date in [
      DateTime(2026, 1, 1),
      DateTime(2026, 3, 8), // US clocks change; local math must not care
      DateTime(2026, 10, 7),
      DateTime(2026, 12, 31),
      DateTime(2027, 1, 3),
    ]) {
      final week = isoWeekOf(date);
      final start = isoWeekStart(week.year, week.week);
      expect(start.isAfter(date), isFalse);
      expect(date.isAfter(DateTime(start.year, start.month, start.day + 6)), isFalse);
    }
  });

  test('week 1 always contains the 4th of January', () {
    for (final year in [2025, 2026, 2027]) {
      expect(isoWeekOf(DateTime(year, 1, 4)), (year: year, week: 1));
    }
  });

  test('a time of day never changes the week', () {
    expect(
      isoWeekOf(DateTime(2026, 10, 7, 23, 59)),
      isoWeekOf(DateTime(2026, 10, 7)),
    );
  });
}

**Create `test/core/roundup/roundup_payload_test.dart`**

```dart
import 'package:energy_clock/core/roundup/roundup_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const payload = RoundupPayload(
    isoYear: 2026,
    isoWeek: 40,
    weekStart: DateTime(2026, 9, 28),
    adherencePercent: 83,
    plannedMinutes: 900,
    completedMinutes: 750,
    totalMinutes: 750,
    focusMinutes: 480,
    lifeMinutes: 180,
    inboxMinutes: 90,
    bestFocusDay: DateTime(2026, 10, 1),
    bestFocusMinutes: 240,
    currentStreak: 5,
    longestStreak: 12,
    badgesUnlocked: ['first_session', 'streak_7'],
    xpEarned: 320,
    previousAdherencePercent: 71,
  );

  test('round-trips through JSON, nulls included', () {
    final decoded = RoundupPayload.fromJson(payload.toJson());
    expect(decoded.toJson(), payload.toJson());

    const empty = RoundupPayload(
      isoYear: 2026,
      isoWeek: 41,
      weekStart: DateTime(2026, 10, 5),
      adherencePercent: null,
      plannedMinutes: 0,
      completedMinutes: 0,
      totalMinutes: 0,
      focusMinutes: 0,
      lifeMinutes: 0,
      inboxMinutes: 0,
      bestFocusDay: null,
      bestFocusMinutes: 0,
      currentStreak: 0,
      longestStreak: 0,
      badgesUnlocked: [],
      xpEarned: 0,
      previousAdherencePercent: null,
    );
    expect(RoundupPayload.fromJson(empty.toJson()).toJson(), empty.toJson());
  });

  test('decodes the documented shape', () {
    final decoded = RoundupPayload.fromJson({
      'isoYear': 2026,
      'isoWeek': 40,
      'weekStart': '2026-09-28',
      'adherencePercent': 83,
      'plannedMinutes': 900,
      'completedMinutes': 750,
      'totalMinutes': 750,
      'focusMinutes': 480,
      'lifeMinutes': 180,
      'inboxMinutes': 90,
      'bestFocusDay': '2026-10-01',
      'bestFocusMinutes': 240,
      'currentStreak': 5,
      'longestStreak': 12,
      'badgesUnlocked': ['first_session'],
      'xpEarned': 320,
      'previousAdherencePercent': null,
    });
    expect(decoded.weekStart, DateTime(2026, 9, 28));
    expect(decoded.badgesUnlocked, ['first_session']);
    expect(decoded.previousAdherencePercent, isNull);
  });

  test('malformed payloads throw a FormatException', () {
    expect(() => RoundupPayload.fromJson({}), throwsA(isA<FormatException>()));
    expect(
      () => RoundupPayload.fromJson({...payload.toJson(), 'isoWeek': 'forty'}),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => RoundupPayload.fromJson({...payload.toJson(), 'weekStart': 'next friday'}),
      throwsA(isA<FormatException>()),
    );
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL - compile error: lib/core/roundup/ does not exist yet.
flutter test test/core/roundup/iso_week_test.dart test/core/roundup/roundup_payload_test.dart
```

- [ ] **Step 3: Create the week arithmetic**

**Create `lib/core/roundup/iso_week.dart`**

```dart
/// ISO-8601 weeks: Monday–Sunday, week 1 containing the first Thursday, weeks
/// numbered against the year their Thursday falls in. Calendar arithmetic
/// throughout, so DST never shifts a week.
int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// The ISO week [date] falls in. Verified edges: 2026-01-01 → (2026, 1),
/// 2025-12-29 → (2026, 1), 2026-12-31 → (2026, 53), 2026-10-07 → (2026, 41).
({int year, int week}) isoWeekOf(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  final thursday = DateTime(
    day.year,
    day.month,
    day.day + (DateTime.thursday - day.weekday),
  );
  final jan4 = DateTime(thursday.year, 1, 4);
  final week1Monday = DateTime(
    jan4.year,
    jan4.month,
    jan4.day - (jan4.weekday - DateTime.monday),
  );
  return (
    year: thursday.year,
    week: _daysBetween(week1Monday, day) ~/ 7 + 1,
  );
}

/// The Monday of ISO week [isoWeek] in [isoYear], at local midnight.
DateTime isoWeekStart(int isoYear, int isoWeek) {
  final jan4 = DateTime(isoYear, 1, 4);
  final week1Monday = DateTime(
    jan4.year,
    jan4.month,
    jan4.day - (jan4.weekday - DateTime.monday),
  );
  return DateTime(
    week1Monday.year,
    week1Monday.month,
    week1Monday.day + (isoWeek - 1) * 7,
  );
}
```

- [ ] **Step 4: Create the payload codec**

**Create `lib/core/roundup/roundup_payload.dart`**

```dart
/// A generated Weekly Roundup, frozen as JSON in `weekly_roundups` (spec
/// §9.6). Hand-written codec: every field is read with an explicit cast, and
/// anything off-shape throws [FormatException].
class RoundupPayload {
  const RoundupPayload({
    required this.isoYear,
    required this.isoWeek,
    required this.weekStart,
    required this.adherencePercent,
    required this.plannedMinutes,
    required this.completedMinutes,
    required this.totalMinutes,
    required this.focusMinutes,
    required this.lifeMinutes,
    required this.inboxMinutes,
    required this.bestFocusDay,
    required this.bestFocusMinutes,
    required this.currentStreak,
    required this.longestStreak,
    required this.badgesUnlocked,
    required this.xpEarned,
    required this.previousAdherencePercent,
  });

  final int isoYear;
  final int isoWeek;

  /// The week's Monday, local midnight.
  final DateTime weekStart;

  /// Rounded percent, or null when nothing was planned that week.
  final int? adherencePercent;
  final int plannedMinutes;
  final int completedMinutes;

  /// Completed minutes over every tone.
  final int totalMinutes;

  /// Completed minutes per tone: the roundup's tone balance.
  final int focusMinutes;
  final int lifeMinutes;
  final int inboxMinutes;

  /// The week's highest focus-minutes day, or null when there was none.
  final DateTime? bestFocusDay;
  final int bestFocusMinutes;
  final int currentStreak;
  final int longestStreak;

  /// Stable badge ids unlocked during the week.
  final List<String> badgesUnlocked;
  final int xpEarned;

  /// The previous finished week's adherence, or null when there is none.
  final int? previousAdherencePercent;

  static String _date(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  static DateTime _day(String value) {
    final parsed = DateTime.tryParse(value);
    final midnight =
        parsed == null
            ? null
            : DateTime(parsed.year, parsed.month, parsed.day);
    if (midnight == null ||
        _date(midnight) != value ||
        parsed!.hour != 0 ||
        parsed.minute != 0) {
      throw FormatException('Not a yyyy-MM-dd date', value);
    }
    return midnight;
  }

  Map<String, Object?> toJson() => {
    'isoYear': isoYear,
    'isoWeek': isoWeek,
    'weekStart': _date(weekStart),
    'adherencePercent': adherencePercent,
    'plannedMinutes': plannedMinutes,
    'completedMinutes': completedMinutes,
    'totalMinutes': totalMinutes,
    'focusMinutes': focusMinutes,
    'lifeMinutes': lifeMinutes,
    'inboxMinutes': inboxMinutes,
    'bestFocusDay': bestFocusDay == null ? null : _date(bestFocusDay!),
    'bestFocusMinutes': bestFocusMinutes,
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'badgesUnlocked': [...badgesUnlocked],
    'xpEarned': xpEarned,
    'previousAdherencePercent': previousAdherencePercent,
  };

  factory RoundupPayload.fromJson(Map<String, Object?> json) {
    int field(String key) {
      final value = json[key];
      if (value is! int) throw FormatException('Missing int $key', json);
      return value;
    }

    int? optionalInt(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! int) throw FormatException('Bad int $key', json);
      return value;
    }

    final weekStartValue = json['weekStart'];
    if (weekStartValue is! String) {
      throw FormatException('Missing weekStart', json);
    }
    final bestDayValue = json['bestFocusDay'];
    if (bestDayValue != null && bestDayValue is! String) {
      throw FormatException('Bad bestFocusDay', json);
    }
    final badgesValue = json['badgesUnlocked'];
    if (badgesValue is! List ||
        badgesValue.any((badge) => badge is! String)) {
      throw FormatException('Bad badgesUnlocked', json);
    }
    return RoundupPayload(
      isoYear: field('isoYear'),
      isoWeek: field('isoWeek'),
      weekStart: _day(weekStartValue),
      adherencePercent: optionalInt('adherencePercent'),
      plannedMinutes: field('plannedMinutes'),
      completedMinutes: field('completedMinutes'),
      totalMinutes: field('totalMinutes'),
      focusMinutes: field('focusMinutes'),
      lifeMinutes: field('lifeMinutes'),
      inboxMinutes: field('inboxMinutes'),
      bestFocusDay: bestDayValue == null ? null : _day(bestDayValue),
      bestFocusMinutes: field('bestFocusMinutes'),
      currentStreak: field('currentStreak'),
      longestStreak: field('longestStreak'),
      badgesUnlocked: [for (final badge in badgesValue) badge as String],
      xpEarned: field('xpEarned'),
      previousAdherencePercent: optionalInt('previousAdherencePercent'),
    );
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
# expect: PASS - 8 tests (5 ISO + 3 payload)
flutter test test/core/roundup/iso_week_test.dart test/core/roundup/roundup_payload_test.dart
```

- [ ] **Step 6: Analyze, run the suite, commit**

```bash
# expect: PASS - analyzer clean; whole suite green
flutter analyze && flutter test
```

```bash
# expect: RUN
git add lib/core/roundup/iso_week.dart lib/core/roundup/roundup_payload.dart \
  test/core/roundup/iso_week_test.dart test/core/roundup/roundup_payload_test.dart
git commit -m "feat: ISO weeks and roundup payload codec

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

### Task 15: RoundupRepository — generate-on-read archive

Finished ISO weeks generate their frozen payload the first time the archive is read; the current week never generates. XP earned in a week is session XP (from the week's per-day cells) plus 50 per badge unlocked that week — streak XP is level-based, not weekly, and is documented as excluded.

**Files:**
- Create: `lib/data/daos/roundup_dao.dart`, `lib/data/repositories/roundup_repository.dart`, `test/support/fake_roundup_repository.dart`
- Modify: `lib/data/database.dart` (register `RoundupDao`), `lib/data/providers.dart` (`roundupRepositoryProvider`), `test/support/clock_harness.dart` (roundup fake)
- Test: `test/data/roundup_repository_test.dart` (new)

**Interfaces:**
- `RoundupDao` (accessor on `[WeeklyRoundups, BadgeUnlocks]`): `roundupFor(isoYear, isoWeek)`, `insertRoundup(isoYear, isoWeek, payloadJson, generatedAt)`, `watchArchive()` (all rows, newest first), `unlocksInWeek(from, toExclusive) → List<String>`.
- `RoundupSummary = ({int isoYear, int isoWeek, DateTime generatedAt})`.
- `RoundupRepository`: `watchArchive() → Stream<List<RoundupSummary>>` (runs `ensureCurrent()` first), `payload(isoYear, isoWeek) → Future<RoundupPayload?>` (null when missing or corrupt), `ensureCurrent()`.
- `DriftRoundupRepository(db, {now})`.
- `FakeRoundupRepository`: `summaries`, `payloads` map, `ensureCurrentCalls`, `setArchive` re-emits, `dispose()`.

- [ ] **Step 1: Write the failing tests**

**Create `test/data/roundup_repository_test.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:energy_clock/core/session/session_outcome.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/roundup_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftRoundupRepository repository;
  DateTime now = DateTime(2026, 10, 13, 8);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    now = DateTime(2026, 10, 13, 8);
    repository = DriftRoundupRepository(db, now: () => now);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> seedEvent({
    required DateTime date,
    Tone tone = Tone.focus,
    int start = 540,
    int end = 660,
  }) => db.eventDao.insertEvent(
    EventsCompanion.insert(
      date: date,
      title: 'Event',
      toneIndex: tone.dbIndex,
      startMinute: start,
      endMinute: end,
      createdAt: now,
      updatedAt: now,
    ),
  );

  Future<void> seedSession({
    required int eventId,
    int activeSeconds = 3600,
    DateTime? startedAt,
  }) => db.sessionDao.insertSession(
    SessionsCompanion.insert(
      eventId: eventId,
      startedAt: startedAt ?? DateTime(2026, 10, 5, 9),
      plannedSeconds: 3600,
      activeSeconds: Value(activeSeconds),
      outcome: Value(SessionOutcome.completed.dbIndex),
    ),
  );

  test('an empty database generates nothing', () async {
    await repository.ensureCurrent();
    expect(await repository.watchArchive().first, isEmpty);
  });

  test('a finished week generates its payload, the current week never does', () async {
    // ISO week 41: 5–11 October 2026. Now is Tuesday the 13th (week 42).
    final id = await seedEvent(date: DateTime(2026, 10, 6));
    await seedSession(eventId: id, activeSeconds: 5400);

    await repository.ensureCurrent();

    final archive = await repository.watchArchive().first;
    expect(archive.map((row) => (row.isoYear, row.isoWeek)), [(2026, 41)]);

    final payload = await repository.payload(2026, 41);
    expect(payload, isNotNull);
    expect(payload!.weekStart, DateTime(2026, 10, 5));
    expect(payload.plannedMinutes, 120);
    expect(payload.completedMinutes, 90);
    expect(payload.focusMinutes, 90);
    expect(payload.lifeMinutes, 0);
    expect(payload.inboxMinutes, 0);
    expect(payload.adherencePercent, 75);
    expect(payload.bestFocusDay, DateTime(2026, 10, 6));
    expect(payload.bestFocusMinutes, 90);
    // Streaks freeze as of the week's Sunday: one Tuesday session is a
    // longest of 1 with nothing current by Sunday.
    expect(payload.currentStreak, 0);
    expect(payload.longestStreak, 1);
    // 90 focus minutes: 135 session XP, no badges, no previous week.
    expect(payload.xpEarned, 135);
    expect(payload.previousAdherencePercent, isNull);
  });

  test('an empty week between data weeks archives as empty', () async {
    await seedSession(eventId: await seedEvent(date: DateTime(2026, 9, 22)));
    await seedSession(eventId: await seedEvent(date: DateTime(2026, 10, 6)));
    await repository.ensureCurrent();

    final archive = await repository.watchArchive().first;
    expect(archive.map((row) => row.isoWeek), [41, 40, 39]);

    final empty = await repository.payload(2026, 40);
    expect(empty!.plannedMinutes, 0);
    expect(empty.adherencePercent, isNull);
    expect(empty.bestFocusDay, isNull);
  });

  test('the archive reads newest first', () async {
    await seedSession(eventId: await seedEvent(date: DateTime(2026, 9, 29)));
    await seedSession(eventId: await seedEvent(date: DateTime(2026, 10, 6)));
    await repository.ensureCurrent();

    final archive = await repository.watchArchive().first;
    expect(archive.map((row) => row.isoWeek), [41, 40]);
  });

  test('badges unlocked in the week are named, and the next week sees the last', () async {
    await seedSession(eventId: await seedEvent(date: DateTime(2026, 9, 29)));
    await db.progressDao.unlockBadges(['first_session'], DateTime(2026, 9, 30, 12));
    await seedSession(eventId: await seedEvent(date: DateTime(2026, 10, 6)));
    await repository.ensureCurrent();

    final week40 = await repository.payload(2026, 40);
    expect(week40!.badgesUnlocked, ['first_session']);
    expect(week40.xpEarned, greaterThan(50));

    final week41 = await repository.payload(2026, 41);
    expect(week41!.badgesUnlocked, isEmpty);
    expect(week41.previousAdherencePercent, week40.adherencePercent);
  });

  test('a corrupt row reads as null, not as a crash', () async {
    await db.roundupDao.insertRoundup(
      isoYear: 2026,
      isoWeek: 41,
      payloadJson: '{"isoWeek": "forty"}',
      generatedAt: now,
    );

    expect(await repository.payload(2026, 41), isNull);
    expect(
      await repository.watchArchive().first,
      hasLength(1),
    );
  });

  test('watching the archive generates first', () async {
    final id = await seedEvent(date: DateTime(2026, 10, 6));
    await seedSession(eventId: id);

    // No ensureCurrent call: the stream itself generates.
    final archive = await repository.watchArchive().first;
    expect(archive.map((row) => row.isoWeek), [41]);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL - compile error: RoundupDao, RoundupRepository and DriftRoundupRepository do not exist yet.
flutter test test/data/roundup_repository_test.dart
```

- [ ] **Step 3: Create the DAO**

**Create `lib/data/daos/roundup_dao.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/tables/progress_table.dart';
import 'package:energy_clock/data/tables/weekly_roundups_table.dart';

part 'roundup_dao.g.dart';

/// Stores and lists the frozen weekly roundups, plus the badge unlocks per
/// week the generator names.
@DriftAccessor(tables: [WeeklyRoundups, BadgeUnlocks])
class RoundupDao extends DatabaseAccessor<AppDatabase>
    with _$RoundupDaoMixin {
  RoundupDao(super.attachedDatabase);

  Future<WeeklyRoundupRow?> roundupFor(int isoYear, int isoWeek) =>
      (select(weeklyRoundups)
            ..where(
              (row) =>
                  row.isoYear.equals(isoYear) & row.isoWeek.equals(isoWeek),
            ))
          .getSingleOrNull();

  Future<void> insertRoundup({
    required int isoYear,
    required int isoWeek,
    required String payloadJson,
    required DateTime generatedAt,
  }) => into(weeklyRoundups).insert(
    WeeklyRoundupsCompanion.insert(
      isoYear: isoYear,
      isoWeek: isoWeek,
      generatedAt: generatedAt,
      payloadJson: payloadJson,
    ),
  );

  /// Every stored roundup, newest first.
  Stream<List<WeeklyRoundupRow>> watchArchive() =>
      (select(weeklyRoundups)..orderBy([
          (row) => OrderingTerm.desc(row.isoYear),
          (row) => OrderingTerm.desc(row.isoWeek),
        ])).watch();

  Future<List<WeeklyRoundupRow>> archive() =>
      (select(weeklyRoundups)..orderBy([
          (row) => OrderingTerm.desc(row.isoYear),
          (row) => OrderingTerm.desc(row.isoWeek),
        ])).get();

  /// Stable badge ids unlocked in `[from, toExclusive)`, in unlock order.
  Future<List<String>> unlocksInWeek(DateTime from, DateTime toExclusive) =>
      (select(badgeUnlocks)
            ..where(
              (row) =>
                  row.unlockedAt.isBiggerOrEqualValue(from) &
                  row.unlockedAt.isSmallerThanValue(toExclusive),
            )
            ..orderBy([(row) => OrderingTerm.asc(row.unlockedAt)]))
          .map((row) => row.badgeId)
          .get();
}
```

- [ ] **Step 4: Create the repository, the fake, and register everything**

**Create `lib/data/repositories/roundup_repository.dart`**

```dart
import 'dart:convert';

import 'package:energy_clock/core/progress/streak.dart';
import 'package:energy_clock/core/progress/xp.dart';
import 'package:energy_clock/core/roundup/iso_week.dart';
import 'package:energy_clock/core/roundup/roundup_payload.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';

/// One archived week: its ISO number and when it was generated.
typedef RoundupSummary = ({int isoYear, int isoWeek, DateTime generatedAt});

/// What Profile's archive reads. Finished weeks generate their frozen payload
/// on first read; the current week never generates (spec §9.6).
abstract interface class RoundupRepository {
  /// Generates every missing finished week, then emits the archive newest
  /// first, re-emitting on every database change.
  Stream<List<RoundupSummary>> watchArchive();

  /// The frozen payload, or null when the week was never generated or its
  /// JSON no longer parses.
  Future<RoundupPayload?> payload(int isoYear, int isoWeek);

  /// Generates every finished week that has no row yet.
  Future<void> ensureCurrent();
}

class DriftRoundupRepository implements RoundupRepository {
  DriftRoundupRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  @override
  Stream<List<RoundupSummary>> watchArchive() async* {
    await ensureCurrent();
    yield* _db.roundupDao.watchArchive().map(
      (rows) => [
        for (final row in rows)
          (
            isoYear: row.isoYear,
            isoWeek: row.isoWeek,
            generatedAt: row.generatedAt,
          ),
      ],
    );
  }

  @override
  Future<RoundupPayload?> payload(int isoYear, int isoWeek) async {
    final row = await _db.roundupDao.roundupFor(isoYear, isoWeek);
    if (row == null) return null;
    try {
      return RoundupPayload.fromJson(
        Map<String, Object?>.from(jsonDecode(row.payloadJson) as Map),
      );
    } on Object {
      // A corrupt row archives as unopenable, never as a crash.
      return null;
    }
  }

  @override
  Future<void> ensureCurrent() => _db.transaction(() async {
    final today = startOfDay(_now());
    final dataDates = await _db.progressDao.datesWithData();
    if (dataDates.isEmpty) return;
    final first = isoWeekOf(dataDates.first);
    var start = isoWeekStart(first.year, first.week);
    while (!_isFinished(start, today)) {
      // Only finished weeks generate; the loop walks week by week.
      start = DateTime(start.year, start.month, start.day + 7);
    }
    // `start` is now the first unfinished week: walk back and fill the gaps.
    var week = DateTime(start.year, start.month, start.day - 7);
    final firstStart = isoWeekStart(first.year, first.week);
    while (!week.isBefore(firstStart)) {
      final number = isoWeekOf(week);
      if (await _db.roundupDao.roundupFor(number.year, number.week) == null) {
        await _generate(number.year, number.week, week);
      }
      week = DateTime(week.year, week.month, week.day - 7);
    }
  });

  bool _isFinished(DateTime weekStart, DateTime today) =>
      !DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day + 7,
      ).isAfter(today);

  /// Builds and stores one finished week's frozen payload.
  Future<void> _generate(int isoYear, int isoWeek, DateTime start) async {
    final end = DateTime(start.year, start.month, start.day + 7);
    final cells = await _db.statsDao.toneSecondsByDay(start, end);
    final plannedRows = await _db.progressDao.plannedMinutesByDay(start, end);

    final completedByTone = <Tone, int>{};
    var bestDay = 0;
    var bestDate = start;
    for (final cell in cells) {
      final minutes = cell.seconds ~/ 60;
      final tone = Tone.fromDbIndex(cell.toneIndex);
      completedByTone[tone] = (completedByTone[tone] ?? 0) + minutes;
      if (tone == Tone.focus && minutes > bestDay) {
        bestDay = minutes;
        bestDate = cell.date;
      }
    }
    final planned = plannedRows.fold(0, (sum, row) => sum + row.minutes);
    final completed = completedByTone.values.fold(0, (a, b) => a + b);

    final sunday = DateTime(end.year, end.month, end.day - 1);
    final qualifying =
        (await _db.progressDao.qualifyingDates())
            .where((day) => !day.isAfter(sunday))
            .toList();
    final evaluated = streaks(qualifying, today: sunday);

    final unlocks = await _db.roundupDao.unlocksInWeek(start, end);
    var sessionPoints = 0;
    for (final cell in cells) {
      sessionPoints += sessionXpMinutes(
        cell.seconds ~/ 60,
        focus: cell.toneIndex == Tone.focus.dbIndex,
      );
    }

    final previousStart = DateTime(
      start.year,
      start.month,
      start.day - 7,
    );
    final previousAdherence = await _adherence(
      previousStart,
      start,
    );

    await _db.roundupDao.insertRoundup(
      isoYear: isoYear,
      isoWeek: isoWeek,
      payloadJson: jsonEncode(
        RoundupPayload(
          isoYear: isoYear,
          isoWeek: isoWeek,
          weekStart: start,
          adherencePercent:
              planned == 0 ? null : (completed * 100 / planned).round(),
          plannedMinutes: planned,
          completedMinutes: completed,
          totalMinutes: completed,
          focusMinutes: completedByTone[Tone.focus] ?? 0,
          lifeMinutes: completedByTone[Tone.life] ?? 0,
          inboxMinutes: completedByTone[Tone.inbox] ?? 0,
          bestFocusDay: bestDay == 0 ? null : bestDate,
          bestFocusMinutes: bestDay,
          currentStreak: evaluated.current,
          longestStreak: evaluated.longest,
          badgesUnlocked: unlocks,
          xpEarned: sessionPoints + badgeXp(unlocks.length),
          previousAdherencePercent: previousAdherence,
        ).toJson(),
      ),
      generatedAt: _now(),
    );
  }

  /// One week's adherence without writing a row: null when nothing was
  /// planned.
  Future<int?> _adherence(DateTime from, DateTime toExclusive) async {
    final cells = await _db.statsDao.toneSecondsByDay(from, toExclusive);
    final plannedRows = await _db.progressDao.plannedMinutesByDay(
      from,
      toExclusive,
    );
    final planned = plannedRows.fold(0, (sum, row) => sum + row.minutes);
    if (planned == 0) return null;
    final completed = cells.fold(0, (sum, cell) => sum + cell.seconds ~/ 60);
    return (completed * 100 / planned).round();
  }
}
```

**Create `test/support/fake_roundup_repository.dart`**

```dart
import 'dart:async';

import 'package:energy_clock/core/roundup/roundup_payload.dart';
import 'package:energy_clock/data/repositories/roundup_repository.dart';

export 'package:energy_clock/data/repositories/roundup_repository.dart'
    show RoundupSummary;

/// In-memory [RoundupRepository] for widget tests. Tests seed [summaries] and
/// [payloads] and read [ensureCurrentCalls].
class FakeRoundupRepository implements RoundupRepository {
  FakeRoundupRepository({
    List<RoundupSummary>? summaries,
    Map<(int, int), RoundupPayload>? payloads,
  }) : summaries = summaries ?? [],
       payloads = payloads ?? {};

  final List<RoundupSummary> summaries;
  final Map<(int, int), RoundupPayload> payloads;

  int ensureCurrentCalls = 0;

  final _updates = StreamController<List<RoundupSummary>>.broadcast();

  @override
  Stream<List<RoundupSummary>> watchArchive() async* {
    yield summaries;
    yield* _updates.stream;
  }

  @override
  Future<RoundupPayload?> payload(int isoYear, int isoWeek) async =>
      payloads[(isoYear, isoWeek)];

  @override
  Future<void> ensureCurrent() async {
    ensureCurrentCalls++;
  }

  void setArchive(List<RoundupSummary> rows) {
    summaries
      ..clear()
      ..addAll(rows);
    _updates.add(summaries);
  }

  void dispose() => _updates.close();
}
```

**Edit `lib/data/database.dart`** — two pairs

Replace:
```dart
import 'package:energy_clock/data/daos/progress_dao.dart';
```
With:
```dart
import 'package:energy_clock/data/daos/progress_dao.dart';
import 'package:energy_clock/data/daos/roundup_dao.dart';
```

Replace:
```dart
    StatsDao,
    ProgressDao,
  ],
```
With:
```dart
    StatsDao,
    ProgressDao,
    RoundupDao,
  ],
```

**Edit `lib/data/providers.dart`** — two pairs

Replace:
```dart
import 'package:energy_clock/data/repositories/progress_repository.dart';
```
With:
```dart
import 'package:energy_clock/data/repositories/progress_repository.dart';
import 'package:energy_clock/data/repositories/roundup_repository.dart';
```

Replace:
```dart
/// How each day of a month is planned, for the Calendar tab.
```
With:
```dart
/// Generated weekly roundups, for Profile's archive (spec §9.6).
final roundupRepositoryProvider = Provider<RoundupRepository>((ref) {
  return DriftRoundupRepository(ref.watch(appDatabaseProvider));
});

/// How each day of a month is planned, for the Calendar tab.
```

**Edit `test/support/clock_harness.dart`** — four pairs

Replace:
```dart
import 'fake_progress_repository.dart';
```
With:
```dart
import 'fake_progress_repository.dart';
import 'fake_roundup_repository.dart';
```

Replace:
```dart
/// service, a fake progress repository, plus
```
With:
```dart
/// service, fake progress and roundup repositories, plus
```

Replace:
```dart
  final FakeProgressRepository progress = FakeProgressRepository();
```
With:
```dart
  final FakeProgressRepository progress = FakeProgressRepository();
  final FakeRoundupRepository roundups = FakeRoundupRepository();
```

Replace:
```dart
        progressRepositoryProvider.overrideWithValue(progress),
```
With:
```dart
        progressRepositoryProvider.overrideWithValue(progress),
        roundupRepositoryProvider.overrideWithValue(roundups),
```

Replace:
```dart
  void dispose() {
    container.dispose();
    progress.dispose();
```
With:
```dart
  void dispose() {
    container.dispose();
    roundups.dispose();
    progress.dispose();
```

- [ ] **Step 5: Regenerate**

```bash
# expect: RUN - regenerates roundup_dao.g.dart and database.g.dart (RoundupDao accessor)
DART="$(dirname "$(which flutter)")/dart"
"$DART" run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 6: Run the tests to verify they pass**

```bash
# expect: PASS - 7 tests
flutter test test/data/roundup_repository_test.dart
```

- [ ] **Step 7: Analyze, run the suite, commit**

```bash
# expect: PASS - analyzer clean; whole suite green
flutter analyze && flutter test
```

```bash
# expect: RUN
git add lib/data/daos/roundup_dao.dart lib/data/daos/roundup_dao.g.dart \
  lib/data/repositories/roundup_repository.dart lib/data/database.dart lib/data/database.g.dart \
  lib/data/providers.dart test/support/fake_roundup_repository.dart \
  test/support/clock_harness.dart test/data/roundup_repository_test.dart
git commit -m "feat: weekly roundup archive generated on read

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

### Task 16: Export, share, and full reset

The JSON export (every table, via the drift rows' own `toJson`), the temp-file writer, the `share_plus` share sheet behind a faked service, and `AppDatabase.resetAll()` for support's full reset.

**Files:**
- Create: `lib/data/repositories/export_repository.dart`, `test/support/fake_share_service.dart`
- Modify: `lib/data/database.dart` (`resetAll`), `lib/data/providers.dart` (`exportRepositoryProvider`, `shareServiceProvider`), `test/support/clock_harness.dart` (share fake), `pubspec.yaml` (via `flutter pub add`)
- Test: `test/data/export_repository_test.dart` (new)

**Interfaces:**
- `ExportRepository`: `buildJson() → Future<String>` (top-level keys: `exportedAt`, `settings`, `events`, `eventSeries`, `sessions`, `dayTemplates`, `dayScores`, `progress`, `badgeUnlocks`, `weeklyRoundups`); `writeTempFile(String contents) → Future<String>` (path under `Directory.systemTemp`, `energy-clock-export-<epoch>.json`).
- `ShareService`: `shareFile(String path, {String? subject})`; `SharePlusService` implements it with `share_plus`; `FakeShareService` records `sharedPaths`, with a `fail` flag.
- `AppDatabase.resetAll()`: one transaction deleting every row of every table (sessions before events for the foreign key). Schema untouched.

- [ ] **Step 1: Write the failing tests**

**Create `test/data/export_repository_test.dart`**

```dart
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/export_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftExportRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftExportRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('the export holds every table as JSON', () async {
    final now = DateTime(2026, 10, 7, 12);
    await db.settingsDao.setValue('theme_mode', 'dark');
    await db.eventDao.insertEvent(
      EventsCompanion.insert(
        date: DateTime(2026, 10, 7),
        title: 'Deep work',
        toneIndex: 0,
        startMinute: 540,
        endMinute: 660,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final decoded = jsonDecode(await repository.buildJson()) as Map<String, Object?>;
    expect(decoded.keys, containsAll([
      'exportedAt',
      'settings',
      'events',
      'eventSeries',
      'sessions',
      'dayTemplates',
      'dayScores',
      'progress',
      'badgeUnlocks',
      'weeklyRoundups',
    ]));
    expect((decoded['settings'] as Map)['theme_mode'], 'dark');
    expect((decoded['events'] as List), hasLength(1));
  });

  test('the temp file round-trips its contents', () async {
    const contents = '{"hello": "world"}';
    final path = await repository.writeTempFile(contents);
    addTearDown(() => File(path).delete());

    expect(path, endsWith('.json'));
    expect(await File(path).readAsString(), contents);
  });

  test('resetAll wipes every row and keeps the schema usable', () async {
    final now = DateTime(2026, 10, 7, 12);
    await db.settingsDao.setValue('theme_mode', 'dark');
    final eventId = await db.eventDao.insertEvent(
      EventsCompanion.insert(
        date: DateTime(2026, 10, 7),
        title: 'Deep work',
        toneIndex: 0,
        startMinute: 540,
        endMinute: 660,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.sessionDao.insertSession(
      SessionsCompanion.insert(
        eventId: eventId,
        startedAt: now,
        plannedSeconds: 3600,
      ),
    );
    await db.progressDao.upsertProgress(
      ProgressCompanion.insert(id: const Value(1)),
    );

    await db.resetAll();

    expect(await db.settingsDao.valueFor('theme_mode'), isNull);
    expect(await db.eventDao.eventsForDay(DateTime(2026, 10, 7)), isEmpty);
    expect(await db.sessionDao.running(), isNull);
    expect(await db.progressDao.progressRow(), isNull);
    expect(await db.select(db.dayScores).get(), isEmpty);
    expect(await db.select(db.badgeUnlocks).get(), isEmpty);
    expect(await db.select(db.weeklyRoundups).get(), isEmpty);

    // The schema survives: new rows insert cleanly.
    await db.settingsDao.setValue('theme_mode', 'light');
    expect(await db.settingsDao.valueFor('theme_mode'), 'light');
  });
}
```

> Note for the implementer: the test uses `EventsCompanion`, `SessionsCompanion`, `ProgressCompanion` and `Value` — import `package:drift/drift.dart` and `package:energy_clock/data/database.dart` (which re-exports the table classes through the generated part).

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL - compile error: ExportRepository and resetAll do not exist yet.
flutter test test/data/export_repository_test.dart
```

- [ ] **Step 3: Add `share_plus`**

```bash
# expect: RUN - adds share_plus to pubspec.yaml
flutter pub add share_plus
```

- [ ] **Step 4: Create the export repository and share service**

**Create `lib/data/repositories/export_repository.dart`**

```dart
import 'dart:convert';
import 'dart:io';

import 'package:energy_clock/data/database.dart';
import 'package:share_plus/share_plus.dart';

/// The full-database JSON export (spec §9.7): every table's rows under their
/// own key, plus when the export was taken.
abstract interface class ExportRepository {
  Future<String> buildJson();

  /// Writes [contents] to a temp file and returns its path. The caller shares
  /// it, then deletes it.
  Future<String> writeTempFile(String contents);
}

class DriftExportRepository implements ExportRepository {
  DriftExportRepository(this._db);

  final AppDatabase _db;

  @override
  Future<String> buildJson() async {
    final settings = <String, String>{};
    for (final row in await _db.select(_db.appSettings).get()) {
      settings[row.key] = row.value;
    }
    return jsonEncode({
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': settings,
      'events': [
        for (final row in await _db.select(_db.events).get()) row.toJson(),
      ],
      'eventSeries': [
        for (final row in await _db.select(_db.eventSeries).get())
          row.toJson(),
      ],
      'sessions': [
        for (final row in await _db.select(_db.sessions).get()) row.toJson(),
      ],
      'dayTemplates': [
        for (final row in await _db.select(_db.dayTemplates).get())
          row.toJson(),
      ],
      'dayScores': [
        for (final row in await _db.select(_db.dayScores).get()) row.toJson(),
      ],
      'progress': [
        for (final row in await _db.select(_db.progress).get()) row.toJson(),
      ],
      'badgeUnlocks': [
        for (final row in await _db.select(_db.badgeUnlocks).get())
          row.toJson(),
      ],
      'weeklyRoundups': [
        for (final row in await _db.select(_db.weeklyRoundups).get())
          row.toJson(),
      ],
    });
  }

  @override
  Future<String> writeTempFile(String contents) async {
    final file = File(
      '${Directory.systemTemp.path}/energy-clock-export-'
      '${DateTime.now().millisecondsSinceEpoch}.json',
    );
    await file.writeAsString(contents, flush: true);
    return file.path;
  }
}

/// Opens the platform share sheet for one file. Faked in tests.
abstract interface class ShareService {
  Future<void> shareFile(String path, {String? subject});
}

class SharePlusService implements ShareService {
  @override
  Future<void> shareFile(String path, {String? subject}) =>
      Share.shareXFiles([XFile(path)], subject: subject);
}
```

> Notes for the implementer: the settings table's generated getters may be named differently (`appSettings` with `key`/`value` columns comes from `SettingsDao`'s table — confirm `db.appSettings`, `row.key`, `row.value` against `lib/data/tables/settings_table.dart` and `settings_dao.dart`). If `row.toJson()` needs a serializer import, the generated code already handles it. If the installed `share_plus` has moved to `SharePlus.instance.share(ShareParams(...))`, use that form instead and say so in the report — the behaviour and tests do not change.

**Create `test/support/fake_share_service.dart`**

```dart
import 'package:energy_clock/data/repositories/export_repository.dart';

/// In-memory [ShareService]: records what would have been shared.
class FakeShareService implements ShareService {
  /// Every path passed to [shareFile], in order.
  final List<String> sharedPaths = [];

  /// Makes every share throw, as a dismissed sheet with an error would.
  bool fail = false;

  @override
  Future<void> shareFile(String path, {String? subject}) async {
    if (fail) throw StateError('sharing failed');
    sharedPaths.add(path);
  }
}
```

- [ ] **Step 5: Add `resetAll`, the providers, and the harness fake**

**Edit `lib/data/database.dart`** — one pair (insert before the final closing `}` of the class):

Replace:
```dart
      if (from < 4) {
        await migrator.createTable(dayScores);
        await migrator.createTable(progress);
        await migrator.createTable(badgeUnlocks);
        await migrator.createTable(weeklyRoundups);
      }
    },
  );
}
```
With:
```dart
      if (from < 4) {
        await migrator.createTable(dayScores);
        await migrator.createTable(progress);
        await migrator.createTable(badgeUnlocks);
        await migrator.createTable(weeklyRoundups);
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
    await delete(appSettings).go();
  });
}
```

> Note for the implementer: the table getters here (`sessions`, `dayTemplateItems`, `eventSeries`, `appSettings`, …) must match the generated database mixin names — confirm against `database.g.dart` (they mirror the existing `migration` body, which already names `sessions`, `dayTemplates`, `dayTemplateItems`).

**Edit `lib/data/providers.dart`** — two pairs

Replace:
```dart
import 'package:energy_clock/data/repositories/progress_repository.dart';
```
With:
```dart
import 'package:energy_clock/data/repositories/export_repository.dart';
import 'package:energy_clock/data/repositories/progress_repository.dart';
```

Replace:
```dart
/// How each day of a month is planned, for the Calendar tab.
```
With:
```dart
/// The JSON export and the platform share sheet (spec §9.7). Tests replace
/// the share service with a fake, so nothing in a test run reaches the OS.
final exportRepositoryProvider = Provider<ExportRepository>((ref) {
  return DriftExportRepository(ref.watch(appDatabaseProvider));
});

final shareServiceProvider = Provider<ShareService>((ref) {
  return SharePlusService();
});

/// How each day of a month is planned, for the Calendar tab.
```

**Edit `test/support/clock_harness.dart`** — three pairs (the share provider
comes from the `data/providers.dart` import the harness already has)

Replace:
```dart
import 'fake_roundup_repository.dart';
```
With:
```dart
import 'fake_roundup_repository.dart';
import 'fake_share_service.dart';
```

Replace:
```dart
  final FakeRoundupRepository roundups = FakeRoundupRepository();
```
With:
```dart
  final FakeRoundupRepository roundups = FakeRoundupRepository();
  final FakeShareService share = FakeShareService();
```

Replace:
```dart
        roundupRepositoryProvider.overrideWithValue(roundups),
```
With:
```dart
        roundupRepositoryProvider.overrideWithValue(roundups),
        shareServiceProvider.overrideWithValue(share),
```

- [ ] **Step 6: Run the tests to verify they pass**

```bash
# expect: PASS - 3 tests
flutter test test/data/export_repository_test.dart
```

- [ ] **Step 7: Analyze, run the suite, commit**

```bash
# expect: PASS - analyzer clean; whole suite green
flutter analyze && flutter test
```

```bash
# expect: RUN
git add lib/data/repositories/export_repository.dart lib/data/database.dart \
  lib/data/providers.dart test/support/fake_share_service.dart \
  test/support/clock_harness.dart test/data/export_repository_test.dart pubspec.yaml pubspec.lock
git commit -m "feat: JSON export, share sheet service and full reset

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

## Stage 4 — Profile, settings, polish

### Task 17: Profile providers, shell, level and score cards

Profile's streams, the real `ProfileScreen` (which triggers `ensureFresh()` on build and on foregrounding), and the first two sections. A `ProfileSection` chrome lives here rather than reusing the stats one: features never import each other.

**Files:**
- Create: `lib/features/progress/providers.dart`, `lib/features/progress/widgets/profile_section.dart`, `lib/features/progress/widgets/level_card.dart`, `lib/features/progress/widgets/score_card.dart`
- Replace: `lib/features/progress/profile_screen.dart`
- Modify: `lib/core/strings.dart` (Profile block)
- Test: `test/features/progress/profile_screen_test.dart` (new), `test/core/strings_test.dart` (1 new test)

**Interfaces:**
- `progressRowProvider: StreamProvider<ProgressRow?>`, `todayScoreProvider: StreamProvider<DayScoreRow?>` (for `startOfDay(DateTime.now())`), `unlockedBadgesProvider: StreamProvider<List<BadgeUnlockRow>>`, `roundupArchiveProvider: StreamProvider<List<RoundupSummary>>`.
- `ProfileSection({title, trailing, empty, emptyMessage, child})` — same shape as the stats card, owned by this feature.
- `LevelCard({progress: ProgressRow?})`, `ScoreCard({score: DayScoreRow?})` — pure widgets.

- [ ] **Step 1: Write the failing tests**

**Create `test/features/progress/profile_screen_test.dart`**

```dart
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/tables/day_scores_table.dart';
import 'package:energy_clock/data/tables/progress_table.dart';
import 'package:energy_clock/features/progress/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  DateTime get today => startOfDay(DateTime.now());

  void seedProgress() {
    harness.progress.setProgress(
      ProgressRow(
        id: 1,
        xp: 120,
        level: 2,
        currentStreak: 5,
        longestStreak: 9,
        lastStreakDate: today,
      ),
    );
    harness.progress.setScore(
      today,
      DayScoreRow(
        date: today,
        energyScore: 73,
        adherencePoints: 50,
        focusPoints: 15,
        balancePoints: 8,
        focusMinutes: 90,
        lifeMinutes: 30,
        inboxMinutes: 0,
        plannedMinutes: 0,
        completedMinutes: 120,
        computedAt: DateTime.now(),
      ),
    );
  }

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(harness.app(const ProfileScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the level, XP progress and streaks', (tester) async {
    seedProgress();
    await mount(tester);

    expect(find.text(Strings.profileLevel(2)), findsOneWidget);
    expect(find.text(Strings.profileXp(120, 300)), findsOneWidget);
    expect(find.text(Strings.profileStreak(5)), findsOneWidget);
    expect(find.text(Strings.profileBestStreak(9)), findsOneWidget);
  });

  testWidgets('shows today score with its breakdown', (tester) async {
    seedProgress();
    await mount(tester);

    expect(find.text(Strings.profileScoreTitle), findsOneWidget);
    expect(find.text('73'), findsOneWidget);
    expect(find.text(Strings.profilePoints(50, 50)), findsOneWidget);
    expect(find.text(Strings.profilePoints(15, 30)), findsOneWidget);
    expect(find.text(Strings.profilePoints(8, 20)), findsOneWidget);
  });

  testWidgets('without a progress row the header invites a first session', (tester) async {
    harness.progress.setProgress(null);
    await mount(tester);

    expect(find.text(Strings.profileEmptyHeader), findsOneWidget);
    expect(find.text(Strings.profileLevel(1)), findsOneWidget);
  });

  testWidgets('without a score today the card says so', (tester) async {
    harness.progress.setProgress(
      ProgressRow(id: 1, xp: 0, level: 1, currentStreak: 0, longestStreak: 0),
    );
    await mount(tester);

    expect(find.text(Strings.profileScoreEmpty), findsOneWidget);
  });

  testWidgets('opening Profile refreshes progress', (tester) async {
    await mount(tester);

    expect(harness.progress.ensureFreshCalls, 1);
  });

  testWidgets('a failed read explains itself', (tester) async {
    harness.progress.setProgress(null);
    // Break the score stream: tested through the progress row staying null
    // while the score errors — covered instead by the null-score empty state
    // above. This test pins the loading spinner on first paint.
    await tester.pumpWidget(harness.app(const ProfileScreen()));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
```

> Note for the implementer: the last test only pins the loading state (the fakes cannot fail their streams). If `pump()` alone does not show the spinner because the fake emits synchronously, use `await tester.pump(Duration.zero)` and, if still settled, drop the spinner assertion to `findsNothing` — no, do not invert assertions to fit: instead gate the test on a `Completer` by wrapping the fake's stream. Simplest robust form: skip this test if flaky and rely on the Stats error test for the pattern. Your call at implementation time; report it.

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL - compile error: ProfileScreen is still the placeholder.
flutter test test/features/progress/profile_screen_test.dart
```

- [ ] **Step 3: Add the strings**

**Edit `lib/core/strings.dart`** — insert after the Badges block:

Replace:
```dart
  static const String badgeEarlyBirdDescription =
      'Start a focus session before 08:00.';
```
With:
```dart
  static const String badgeEarlyBirdDescription =
      'Start a focus session before 08:00.';

  // Profile.
  static const String profileLoadError = 'Could not load your progress.';
  static String profileLevel(int level) => 'Level $level';
  static String profileXp(int current, int next) => '$current / $next XP';
  static String profileStreak(int days) =>
      days == 1 ? '1-day streak' : '$days-day streak';
  static String profileBestStreak(int days) => 'Best $days days';
  static const String profileEmptyHeader =
      'Finish a session to start your streak.';
  static const String profileScoreTitle = 'Energy score';
  static const String profileScoreEmpty =
      'Today has no score yet. Finish a session to start one.';
  static String profilePoints(int earned, int total) => '$earned / $total';
  static const String profileScoreAdherence = 'Adherence';
  static const String profileScoreFocus = 'Focus';
  static const String profileScoreBalance = 'Balance';
  static const String profileScoreCaption =
      'How today adds up: up to 50 for planned time kept, 30 for focus '
      'against your target, 20 for a balanced mix.';
```

**Edit `test/core/strings_test.dart`** — insert before the final closing `}` of `main()`:

```dart
    test('profile copy formats its numbers', () {
      expect(Strings.profileLevel(3), 'Level 3');
      expect(Strings.profileXp(120, 300), '120 / 300 XP');
      expect(Strings.profileStreak(1), '1-day streak');
      expect(Strings.profilePoints(8, 20), '8 / 20');
    });
```

- [ ] **Step 4: Create the providers and section chrome**

**Create `lib/features/progress/providers.dart`**

```dart
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/progress_repository.dart';
import 'package:energy_clock/data/repositories/roundup_repository.dart';
import 'package:energy_clock/data/tables/day_scores_table.dart';
import 'package:energy_clock/data/tables/progress_table.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The cached progress row: level, XP and streaks.
final progressRowProvider = StreamProvider<ProgressRow?>((ref) {
  return ref.watch(progressRepositoryProvider).watchProgress();
});

/// Today's cached day score.
final todayScoreProvider = StreamProvider<DayScoreRow?>((ref) {
  return ref
      .watch(progressRepositoryProvider)
      .watchDayScore(startOfDay(DateTime.now()));
});

/// Badge unlocks, oldest first.
final unlockedBadgesProvider = StreamProvider<List<BadgeUnlockRow>>((ref) {
  return ref.watch(progressRepositoryProvider).watchBadges();
});

/// The roundup archive, newest first. Reading it generates missing weeks.
final roundupArchiveProvider = StreamProvider<List<RoundupSummary>>((ref) {
  return ref.watch(roundupRepositoryProvider).watchArchive();
});
```

**Create `lib/features/progress/widgets/profile_section.dart`**

```dart
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:energy_clock/shared/widgets/section_header.dart';
import 'package:flutter/material.dart';

/// The chrome every Profile section shares. A feature-local twin of the stats
/// section card — features never import each other, so the ten lines are
/// duplicated rather than shared.
class ProfileSection extends StatelessWidget {
  const ProfileSection({
    required this.title,
    required this.child,
    this.trailing,
    this.empty = false,
    this.emptyMessage = '',
    super.key,
  });

  final String title;
  final Widget? trailing;
  final bool empty;
  final String emptyMessage;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: title, trailing: trailing),
          const SizedBox(height: AppSpacing.sm),
          if (empty)
            Text(emptyMessage, style: Theme.of(context).textTheme.bodyMedium)
          else
            child,
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Create the level and score cards**

**Create `lib/features/progress/widgets/level_card.dart`**

```dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/progress/xp.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/tables/progress_table.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';

/// Level, the XP bar into the next level, and the streaks. A null row is a
/// brand-new user: level 1, no XP, and the invitation to start.
class LevelCard extends StatelessWidget {
  const LevelCard({required this.progress, super.key});

  final ProgressRow? progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final level = progress?.level ?? 1;
    final xp = progress?.xp ?? 0;
    final current = progress?.currentStreak ?? 0;
    final longest = progress?.longestStreak ?? 0;
    final position = xpIntoLevel(xp);
    final fraction =
        position.end == position.start
            ? 0.0
            : (position.current - position.start) / (position.end - position.start);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(Strings.profileLevel(level), style: theme.textTheme.titleLarge),
              const Spacer(),
              Text(
                Strings.profileXp(position.current, position.end),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.control),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: colors.outline,
              valueColor: AlwaysStoppedAnimation<Color>(colors.ink),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (progress == null)
            Text(Strings.profileEmptyHeader, style: theme.textTheme.bodyMedium)
          else
            Row(
              children: [
                Text(Strings.profileStreak(current), style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text(
                  Strings.profileBestStreak(longest),
                  style: theme.textTheme.bodyMedium!.copyWith(color: colors.muted),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
```

**Create `lib/features/progress/widgets/score_card.dart`**

```dart
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/tables/day_scores_table.dart';
import 'package:energy_clock/features/progress/widgets/profile_section.dart';
import 'package:flutter/material.dart';

/// Today's energy score, always with its three parts showing.
class ScoreCard extends StatelessWidget {
  const ScoreCard({required this.score, super.key});

  final DayScoreRow? score;

  @override
  Widget build(BuildContext context) {
    final row = score;
    return ProfileSection(
      title: Strings.profileScoreTitle,
      empty: row == null,
      emptyMessage: Strings.profileScoreEmpty,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${row!.energyScore}', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: AppSpacing.sm),
          _Points(label: Strings.profileScoreAdherence, earned: row.adherencePoints, total: 50),
          _Points(label: Strings.profileScoreFocus, earned: row.focusPoints, total: 30),
          _Points(label: Strings.profileScoreBalance, earned: row.balancePoints, total: 20),
          const SizedBox(height: AppSpacing.sm),
          Text(
            Strings.profileScoreCaption,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Points extends StatelessWidget {
  const _Points({required this.label, required this.earned, required this.total});

  final String label;
  final int earned;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(Strings.profilePoints(earned, total), style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Replace the screen**

**Replace `lib/features/progress/profile_screen.dart`**

```dart
import 'dart:async';

import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/progress/providers.dart';
import 'package:energy_clock/features/progress/widgets/level_card.dart';
import 'package:energy_clock/features/progress/widgets/score_card.dart';
import 'package:energy_clock/shared/layout/content_width.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Profile tab: level and streaks, today's score, badges, the roundup
/// archive and settings. Badge, archive and settings sections arrive in Tasks
/// 18–19; this shell already refreshes progress on open and on foregrounding.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    unawaited(ref.read(progressRepositoryProvider).ensureFresh());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressRowProvider);
    final score = ref.watch(todayScoreProvider);
    if (progress is AsyncLoading || score is AsyncLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (progress.hasError || score.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(Strings.profileLoadError, textAlign: TextAlign.center),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: ContentWidth(
        maxWidth: ContentWidths.stats,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LevelCard(progress: progress.valueOrNull),
            const SizedBox(height: AppSpacing.lg),
            ScoreCard(score: score.valueOrNull),
          ],
        ),
      ),
    );
  }
}
```

> Note for the implementer: `AppSpacing.xl` — confirm it exists in tokens (month layout work used page margins; if there is no `xl`, use `AppSpacing.lg * 2`). Same note as Task 8's screen.

- [ ] **Step 7: Run the tests to verify they pass**

```bash
# expect: PASS - 7 tests (6 profile + 1 strings)
flutter test test/features/progress/profile_screen_test.dart test/core/strings_test.dart
```

- [ ] **Step 8: Analyze, run the suite, commit**

```bash
# expect: PASS - analyzer clean; whole suite green
flutter analyze && flutter test
```

```bash
# expect: RUN
git add lib/features/progress/providers.dart lib/features/progress/profile_screen.dart \
  lib/features/progress/widgets/profile_section.dart lib/features/progress/widgets/level_card.dart \
  lib/features/progress/widgets/score_card.dart lib/core/strings.dart \
  test/features/progress/profile_screen_test.dart test/core/strings_test.dart
git commit -m "feat: profile shell with level and score sections

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

### Task 18: Badge grid and roundup archive

The remaining Profile sections: all ten badges locked or earned, and the archive list with inline roundup snapshots (donut included — the payload carries per-tone minutes since the Task 14 amendment).

**Files:**
- Create: `lib/features/progress/widgets/badge_grid.dart`, `lib/features/progress/widgets/roundup_archive.dart`
- Modify: `lib/features/progress/providers.dart` (`roundupPayloadProvider`), `lib/features/progress/profile_screen.dart` (badges + archive sections), `lib/core/strings.dart` (badges/archive copy)
- Test: `test/features/progress/profile_sections_test.dart` (new), `test/core/strings_test.dart` (1 new test)

**Interfaces:**
- `BadgeGrid({unlocked: List<BadgeUnlockRow>})` — pure; two columns, every definition, earned shows its description, locked shows `profileBadgeLocked`.
- `RoundupArchive({summaries: List<RoundupSummary>})` — `ConsumerStatefulWidget`; keeps the open week locally; loads its payload through `roundupPayloadProvider`.
- `roundupPayloadProvider = FutureProvider.family<RoundupPayload?, ({int year, int week})>`.

- [ ] **Step 1: Write the failing tests**

**Create `test/features/progress/profile_sections_test.dart`**

```dart
import 'package:energy_clock/core/roundup/roundup_payload.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/repositories/roundup_repository.dart';
import 'package:energy_clock/data/tables/progress_table.dart';
import 'package:energy_clock/features/progress/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  RoundupPayload testPayload({
    int week = 41,
    DateTime? weekStart,
    List<String> badges = const [],
  }) => RoundupPayload(
    isoYear: 2026,
    isoWeek: week,
    weekStart: weekStart ?? DateTime(2026, 10, 5),
    adherencePercent: 83,
    plannedMinutes: 900,
    completedMinutes: 750,
    totalMinutes: 750,
    focusMinutes: 480,
    lifeMinutes: 180,
    inboxMinutes: 90,
    bestFocusDay: DateTime(2026, 10, 8),
    bestFocusMinutes: 200,
    currentStreak: 5,
    longestStreak: 9,
    badgesUnlocked: badges,
    xpEarned: 400,
    previousAdherencePercent: 71,
  );

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(harness.app(const ProfileScreen()));
    await tester.pumpAndSettle();
  }

  /// The badge grid builds lazily and the archive sits below it: scroll first.
  Future<void> scrollDown(WidgetTester tester) async {
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -3000),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('all ten badges show, locked when unearned', (tester) async {
    await mount(tester);
    await scrollDown(tester);

    expect(find.text(Strings.profileBadgesTitle), findsOneWidget);
    expect(find.text(Strings.badgeStreak30Title), findsOneWidget);
    expect(find.text(Strings.profileBadgeLocked), findsNWidgets(10));
  });

  testWidgets('earned badges show their descriptions', (tester) async {
    harness.progress.emitBadges([
      BadgeUnlockRow(badgeId: 'first_session', unlockedAt: DateTime(2026, 10, 6)),
    ]);
    await mount(tester);
    await scrollDown(tester);

    expect(find.text(Strings.badgeFirstSessionDescription), findsOneWidget);
    expect(find.text(Strings.profileBadgeLocked), findsNWidgets(9));
  });

  testWidgets('the archive lists weeks newest first with ranges', (tester) async {
    harness.roundups.setArchive([
      (isoYear: 2026, isoWeek: 41, generatedAt: DateTime(2026, 10, 13)),
      (isoYear: 2026, isoWeek: 40, generatedAt: DateTime(2026, 10, 6)),
    ]);
    harness.roundups.payloads[(2026, 41)] = testPayload();
    harness.roundups.payloads[(2026, 40)] = testPayload(week: 40, weekStart: DateTime(2026, 9, 28));
    await mount(tester);
    await scrollDown(tester);

    expect(find.text(Strings.profileArchiveTitle), findsOneWidget);
    final top41 = tester.getTopLeft(find.text('Week 41')).dy;
    final top40 = tester.getTopLeft(find.text('Week 40')).dy;
    expect(top41, lessThan(top40));
    expect(find.text('5 – 11 Oct 2026'), findsOneWidget);
    expect(find.text('28 Sep – 4 Oct 2026'), findsOneWidget);
  });

  testWidgets('tapping a week opens its snapshot', (tester) async {
    harness.roundups.setArchive([
      (isoYear: 2026, isoWeek: 41, generatedAt: DateTime(2026, 10, 13)),
    ]);
    harness.roundups.payloads[(2026, 41)] = testPayload(badges: ['streak_7']);
    await mount(tester);
    await scrollDown(tester);

    await tester.tap(find.text('Week 41'));
    await tester.pumpAndSettle();

    expect(find.text(Strings.statsAdherence(83)), findsOneWidget);
    expect(
      find.text(Strings.roundupBestFocusDay('Thu 8 Oct', '3h 20m')),
      findsOneWidget,
    );
    expect(find.text(Strings.badgeStreak7Title), findsOneWidget);
    expect(find.byType(CustomPaint), findsOneWidget);
  });

  testWidgets('a week without a payload says it is unavailable', (tester) async {
    harness.roundups.setArchive([
      (isoYear: 2026, isoWeek: 42, generatedAt: DateTime(2026, 10, 20)),
    ]);
    await mount(tester);
    await scrollDown(tester);

    await tester.tap(find.text('Week 42'));
    await tester.pumpAndSettle();

    expect(find.text(Strings.roundupUnavailable), findsOneWidget);
  });

  testWidgets('an empty archive invites the first Monday', (tester) async {
    await mount(tester);
    await scrollDown(tester);

    expect(find.text(Strings.profileEmptyArchive), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL - compile error: BadgeGrid, RoundupArchive and the new strings do not exist yet.
flutter test test/features/progress/profile_sections_test.dart
```

- [ ] **Step 3: Add the strings and the payload provider**

**Edit `lib/core/strings.dart`** — insert after the Profile block's caption:

Replace:
```dart
  static const String profileScoreCaption =
      'How today adds up: up to 50 for planned time kept, 30 for focus '
      'against your target, 20 for a balanced mix.';
```
With:
```dart
  static const String profileScoreCaption =
      'How today adds up: up to 50 for planned time kept, 30 for focus '
      'against your target, 20 for a balanced mix.';
  static const String profileBadgesTitle = 'Badges';
  static const String profileBadgeLocked = 'Locked';
  static const String profileStreakLabel = 'Streak';
  static const String profileXpLabel = 'XP';
  static const String profileArchiveTitle = 'Weekly roundups';
  static const String profileEmptyArchive =
      'Your first roundup appears on Monday.';
  static String roundupWeek(int week) => 'Week $week';
  static String roundupXp(int xp) => '$xp XP';
  static String roundupBestFocusDay(String day, String duration) =>
      '$day · $duration';
  static String roundupPreviousAdherence(int percent) =>
      'Previous week: ${statsAdherence(percent)}';
  static const String roundupNothingPlanned = 'Nothing planned';
  static const String roundupUnavailable = 'This roundup is unavailable.';
```

**Edit `test/core/strings_test.dart`** — insert before the final closing `}` of `main()`:

```dart
    test('roundup copy formats its numbers', () {
      expect(Strings.roundupWeek(41), 'Week 41');
      expect(Strings.roundupXp(400), '400 XP');
      expect(
        Strings.roundupPreviousAdherence(71),
        'Previous week: 71% adherence',
      );
    });
```

**Edit `lib/features/progress/providers.dart`** — one pair

Replace:
```dart
/// The roundup archive, newest first. Reading it generates missing weeks.
final roundupArchiveProvider = StreamProvider<List<RoundupSummary>>((ref) {
  return ref.watch(roundupRepositoryProvider).watchArchive();
});
```
With:
```dart
/// The roundup archive, newest first. Reading it generates missing weeks.
final roundupArchiveProvider = StreamProvider<List<RoundupSummary>>((ref) {
  return ref.watch(roundupRepositoryProvider).watchArchive();
});

/// One frozen roundup, or null when it was never generated or no longer
/// parses.
final roundupPayloadProvider =
    FutureProvider.family<RoundupPayload?, ({int year, int week})>((
      ref,
      key,
    ) {
      return ref
          .watch(roundupRepositoryProvider)
          .payload(key.year, key.week);
    });
```

> Note for the implementer: `providers.dart` needs `import 'package:energy_clock/core/roundup/roundup_payload.dart';` — add it.

- [ ] **Step 4: Create the badge grid**

**Create `lib/features/progress/widgets/badge_grid.dart`**

```dart
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/progress/badges.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/tables/progress_table.dart';
import 'package:energy_clock/features/progress/widgets/profile_section.dart';
import 'package:flutter/material.dart';

/// All ten badges: earned ones with their descriptions, the rest locked.
class BadgeGrid extends StatelessWidget {
  const BadgeGrid({required this.unlocked, super.key});

  final List<BadgeUnlockRow> unlocked;

  @override
  Widget build(BuildContext context) {
    final earned = {for (final row in unlocked) row.badgeId};
    final theme = Theme.of(context);
    return ProfileSection(
      title: Strings.profileBadgesTitle,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.7,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
        ),
        itemCount: badgeDefinitions.length,
        itemBuilder: (context, index) {
          final badge = badgeDefinitions[index];
          final has = earned.contains(badge.id);
          return DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(badge.title, style: theme.textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    has ? badge.description : Strings.profileBadgeLocked,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
```

> Note for the implementer: `AppRadii.card` — confirm against tokens (week strip used `AppRadii.control`; if there is no `card`, use `AppRadii.control`).

- [ ] **Step 5: Create the roundup archive**

**Create `lib/features/progress/widgets/roundup_archive.dart`**

```dart
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/progress/badges.dart';
import 'package:energy_clock/core/roundup/iso_week.dart';
import 'package:energy_clock/core/roundup/roundup_payload.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/repositories/roundup_repository.dart';
import 'package:energy_clock/features/progress/providers.dart';
import 'package:energy_clock/features/progress/widgets/profile_section.dart';
import 'package:energy_clock/shared/charts/donut_painter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The archived weeks, newest first; tapping one opens its frozen snapshot
/// inline.
class RoundupArchive extends ConsumerStatefulWidget {
  const RoundupArchive({required this.summaries, super.key});

  final List<RoundupSummary> summaries;

  @override
  ConsumerState<RoundupArchive> createState() => _RoundupArchiveState();
}

class _RoundupArchiveState extends ConsumerState<RoundupArchive> {
  ({int year, int week})? _open;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ProfileSection(
      title: Strings.profileArchiveTitle,
      empty: widget.summaries.isEmpty,
      emptyMessage: Strings.profileEmptyArchive,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final summary in widget.summaries) ...[
            _Row(
              summary: summary,
              open: _open == (year: summary.isoYear, week: summary.isoWeek),
              onTap: () {
                final key = (year: summary.isoYear, week: summary.isoWeek);
                setState(() => _open = _open == key ? null : key);
              },
            ),
            if (_open == (year: summary.isoYear, week: summary.isoWeek))
              _SnapshotCard(summary: summary),
          ],
        ],
      ),
    );
  }
}

String _rangeLabel(DateTime start) {
  final end = DateTime(start.year, start.month, start.day + 6);
  final endText = DateFormat('d MMM y').format(end);
  if (start.year == end.year && start.month == end.month) {
    return "${DateFormat('d').format(start)} – $endText";
  }
  if (start.year == end.year) {
    return "${DateFormat('d MMM').format(start)} – $endText";
  }
  return "${DateFormat('d MMM y').format(start)} – $endText";
}

class _Row extends StatelessWidget {
  const _Row({required this.summary, required this.open, required this.onTap});

  final RoundupSummary summary;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.control),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Strings.roundupWeek(summary.isoWeek),
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    _rangeLabel(isoWeekStart(summary.isoYear, summary.isoWeek)),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(open ? CupertinoIcons.chevron_down : CupertinoIcons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _SnapshotCard extends ConsumerWidget {
  const _SnapshotCard({required this.summary});

  final RoundupSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payload = ref.watch(
      roundupPayloadProvider((year: summary.isoYear, week: summary.isoWeek)),
    );
    return payload.when(
      data:
          (roundup) =>
              roundup == null
                  ? Text(
                    Strings.roundupUnavailable,
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                  : _SnapshotBody(roundup: roundup),
      loading:
          () => const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: CircularProgressIndicator.adaptive(),
            ),
          ),
      error:
          (error, stack) => Text(
            Strings.roundupUnavailable,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
    );
  }
}

class _SnapshotBody extends StatelessWidget {
  const _SnapshotBody({required this.roundup});

  final RoundupPayload roundup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A ConsumerWidget in disguise: reads no provider, so StatelessWidget
    // would do — except the donut needs the tone colours from context.
    return _Body(roundup: roundup);
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.roundup});

  final RoundupPayload roundup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toneColors = context.toneColors;
    final adherence = roundup.adherencePercent;
    final badgeTitles = {
      for (final badge in badgeDefinitions) badge.id: badge.title,
    };
    final badgeNames = [
      for (final id in roundup.badgesUnlocked) badgeTitles[id] ?? id,
    ];

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (roundup.totalMinutes > 0)
            SizedBox(
              height: 120,
              child: CustomPaint(
                painter: DonutPainter(
                  segments: [
                    (tone: Tone.focus, minutes: roundup.focusMinutes),
                    (tone: Tone.life, minutes: roundup.lifeMinutes),
                    (tone: Tone.inbox, minutes: roundup.inboxMinutes),
                  ],
                  colors: {
                    for (final tone in Tone.values)
                      tone: toneColors.fillFor(tone),
                  },
                  trackColor: theme.dividerColor,
                ),
              ),
            ),
          row(
            Strings.statsPlannedActual,
            adherence == null
                ? Strings.roundupNothingPlanned
                : Strings.statsAdherence(adherence),
          ),
          row(
            Strings.statsTotalFocus,
            formatDurationMinutes(roundup.totalMinutes),
          ),
          if (roundup.bestFocusDay != null)
            row(
              Strings.statsFocusDepth,
              Strings.roundupBestFocusDay(
                DateFormat(
                  'EEE d MMM',
                ).format(roundup.bestFocusDay!),
                formatDurationMinutes(roundup.bestFocusMinutes),
              ),
            ),
          row(
            Strings.profileScoreTitle,
            Strings.profileStreak(roundup.currentStreak),
          ),
          if (badgeNames.isNotEmpty)
            row(Strings.profileBadgesTitle, Strings.joinWords(badgeNames)),
          row(Strings.profileXp(0, 0).split(' / ')[1], Strings.roundupXp(roundup.xpEarned)),
          if (roundup.previousAdherencePercent != null)
            row(
              Strings.statsThisWeek,
              Strings.roundupPreviousAdherence(
                roundup.previousAdherencePercent!,
              ),
            ),
        ],
      ),
    );
  }
}
```

> Notes for the implementer — three rough edges already half-smoothed:
>
> 1. `_SnapshotBody`/`_Body` split is silly: make `_SnapshotBody` itself read `context.toneColors` and drop `_Body`. (It was split in the draft only to think through the context read.)
> 2. The XP row label hack (`Strings.profileXp(0, 0).split(' / ')[1]`) and the misused `statsThisWeek`/`profileScoreTitle` labels in the streak/previous rows must go. Use the Step 3 strings instead:
> - `row(Strings.profileStreakLabel, Strings.profileStreak(roundup.currentStreak))`
> - `row(Strings.profileXpLabel, Strings.roundupXp(roundup.xpEarned))`
> - `Text(Strings.roundupPreviousAdherence(pct))` as its own line (no label).
> 3. `_open == (...)` record equality: records have value equality in Dart 3, so comparing against a record literal works; `_open` is nullable and `null == key` is false, which is exactly right.

- [ ] **Step 6: Wire the sections into the screen**

**Edit `lib/features/progress/profile_screen.dart`** — five pairs

Replace:
```dart
import 'package:energy_clock/features/progress/providers.dart';
import 'package:energy_clock/features/progress/widgets/level_card.dart';
import 'package:energy_clock/features/progress/widgets/score_card.dart';
```
With:
```dart
import 'package:energy_clock/features/progress/providers.dart';
import 'package:energy_clock/features/progress/widgets/badge_grid.dart';
import 'package:energy_clock/features/progress/widgets/level_card.dart';
import 'package:energy_clock/features/progress/widgets/roundup_archive.dart';
import 'package:energy_clock/features/progress/widgets/score_card.dart';
```

Replace:
```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressRowProvider);
    final score = ref.watch(todayScoreProvider);
    if (progress is AsyncLoading || score is AsyncLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (progress.hasError || score.hasError) {
```
With:
```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressRowProvider);
    final score = ref.watch(todayScoreProvider);
    final badges = ref.watch(unlockedBadgesProvider);
    final archive = ref.watch(roundupArchiveProvider);
    if (progress is AsyncLoading ||
        score is AsyncLoading ||
        badges is AsyncLoading ||
        archive is AsyncLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (progress.hasError ||
        score.hasError ||
        badges.hasError ||
        archive.hasError) {
```

Replace:
```dart
          children: [
            LevelCard(progress: progress.valueOrNull),
            const SizedBox(height: AppSpacing.lg),
            ScoreCard(score: score.valueOrNull),
          ],
```
With:
```dart
          children: [
            LevelCard(progress: progress.valueOrNull),
            const SizedBox(height: AppSpacing.lg),
            ScoreCard(score: score.valueOrNull),
            const SizedBox(height: AppSpacing.lg),
            BadgeGrid(unlocked: badges.valueOrNull ?? const []),
            const SizedBox(height: AppSpacing.lg),
            RoundupArchive(summaries: archive.valueOrNull ?? const []),
          ],
```

- [ ] **Step 7: Run the tests to verify they pass**

```bash
# expect: PASS - 7 tests (6 sections + 1 strings)
flutter test test/features/progress/profile_sections_test.dart test/core/strings_test.dart
```

- [ ] **Step 8: Analyze, run the suite, commit**

```bash
# expect: PASS - analyzer clean; whole suite green
flutter analyze && flutter test
```

```bash
# expect: RUN
git add lib/features/progress/widgets/badge_grid.dart lib/features/progress/widgets/roundup_archive.dart \
  lib/features/progress/providers.dart lib/features/progress/profile_screen.dart lib/core/strings.dart \
  test/features/progress/profile_sections_test.dart test/core/strings_test.dart
git commit -m "feat: profile badges and roundup archive

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

### Task 19: The settings card

Theme, focus target, first day of week, recalculate, export and erase — the last Profile section. Erase wipes the database, resets the three settings providers and returns the app to onboarding.

**Files:**
- Create: `lib/features/progress/widgets/settings_card.dart`
- Modify: `lib/features/progress/profile_screen.dart` (settings section), `lib/core/strings.dart` (settings copy)
- Test: `test/features/progress/settings_card_test.dart` (new), `test/core/strings_test.dart` (1 new test)

**Interfaces:**
- `SettingsCard` (`ConsumerWidget`): six rows with keys `settings-theme`, `settings-focus-target`, `settings-first-day`, `settings-recalculate`, `settings-export`, `settings-erase`.
- Focus target choices: 60, 90, 120, 180, 240, 300, 360 minutes.

- [ ] **Step 1: Write the failing tests**

**Create `test/features/progress/settings_card_test.dart`**

```dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/progress/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(harness.app(const ProfileScreen()));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -5000),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the stored settings', (tester) async {
    harness.settings.values['theme_mode'] = 'dark';
    harness.settings.values['daily_focus_target'] = '240';
    harness.settings.values['first_day_of_week'] = '7';
    await mount(tester);

    expect(find.text(Strings.themeDark), findsOneWidget);
    expect(find.text(formatDurationMinutes(240)), findsOneWidget);
    expect(find.text(Strings.weekdayLong[6]), findsOneWidget);
  });

  testWidgets('picking a theme stores it', (tester) async {
    await mount(tester);

    await tester.tap(find.byKey(const ValueKey('settings-theme')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.themeLight));
    await tester.pumpAndSettle();

    expect(harness.settings.values['theme_mode'], 'light');
    expect(find.text(Strings.themeLight), findsOneWidget);
  });

  testWidgets('picking a focus target stores its minutes', (tester) async {
    await mount(tester);

    await tester.tap(find.byKey(const ValueKey('settings-focus-target')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(formatDurationMinutes(300)));
    await tester.pumpAndSettle();

    expect(harness.settings.values['daily_focus_target'], '300');
  });

  testWidgets('picking Monday stores the first day', (tester) async {
    harness.settings.values['first_day_of_week'] = '7';
    await mount(tester);

    await tester.tap(find.byKey(const ValueKey('settings-first-day')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.weekdayLong[0]));
    await tester.pumpAndSettle();

    expect(harness.settings.values['first_day_of_week'], '1');
  });

  testWidgets('recalculating rebuilds every score', (tester) async {
    await mount(tester);

    await tester.tap(find.byKey(const ValueKey('settings-recalculate')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.settingsRecalculateConfirm));
    await tester.pumpAndSettle();

    expect(harness.progress.recalculateAllCalls, 1);
    expect(find.text(Strings.settingsRecalculated), findsOneWidget);
  });

  testWidgets('exporting shares a JSON file', (tester) async {
    // Export reads the database layer, so this test brings a memory database.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final exported = ClockHarness(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(exported.dispose);

    await tester.pumpWidget(exported.app(const ProfileScreen()));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -5000),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-export')));
    await tester.pumpAndSettle();

    expect(exported.share.sharedPaths, hasLength(1));
    final path = exported.share.sharedPaths.single;
    expect(path, endsWith('.json'));
    // The temp file is deleted once the sheet has it.
    expect(File(path).existsSync(), isFalse);
  });

  testWidgets('erasing wipes the database and returns to defaults', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final erased = ClockHarness(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(erased.dispose);
    await db.settingsDao.setValue('theme_mode', 'dark');

    await tester.pumpWidget(erased.app(const ProfileScreen()));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -5000),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-erase')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.settingsEraseConfirm));
    await tester.pumpAndSettle();

    expect(await db.settingsDao.valueFor('theme_mode'), isNull);
    expect(find.text(Strings.settingsErased), findsOneWidget);
  });
}
```

> Note for the implementer: the erase test overrides `appDatabaseProvider` because erase and export touch the real database layer (everything else in these tests runs on fakes). It needs `import 'package:energy_clock/data/database.dart';` and `package:drift/native.dart` — both already in the file above.

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL - compile error: SettingsCard and the settings strings do not exist yet.
flutter test test/features/progress/settings_card_test.dart
```

- [ ] **Step 3: Add the strings**

**Edit `lib/core/strings.dart`** — insert after the roundup strings:

Replace:
```dart
  static const String roundupUnavailable = 'This roundup is unavailable.';
```
With:
```dart
  static const String roundupUnavailable = 'This roundup is unavailable.';

  // Settings.
  static const String settingsTitle = 'Settings';
  static const String settingsTheme = 'Theme';
  static const String themeSystem = 'System';
  static const String themeLight = 'Light';
  static const String themeDark = 'Dark';
  static const String settingsFocusTarget = 'Daily focus target';
  static const String settingsFirstDay = 'First day of week';
  static const String settingsRecalculate = 'Recalculate all scores';
  static const String settingsRecalculateTitle = 'Rebuild every score?';
  static const String settingsRecalculateBody =
      'Scores, streaks and badges are recomputed from your events and '
      'sessions. This takes a moment.';
  static const String settingsRecalculateConfirm = 'Rebuild';
  static const String settingsRecalculated = 'Scores rebuilt.';
  static const String settingsExport = 'Export data';
  static const String settingsExportSubject = 'Energy Clock export';
  static const String settingsExportFailed = 'Export failed. Try again.';
  static const String settingsErase = 'Erase everything';
  static const String settingsEraseTitle = 'Erase everything?';
  static const String settingsEraseBody =
      'All events, sessions, scores and settings are deleted. '
      'This cannot be undone.';
  static const String settingsEraseConfirm = 'Erase';
  static const String settingsErased = 'Everything erased.';
```

**Edit `test/core/strings_test.dart`** — insert before the final closing `}` of `main()`:

```dart
    test('settings copy names its actions', () {
      expect(Strings.settingsRecalculateConfirm, 'Rebuild');
      expect(Strings.settingsEraseConfirm, 'Erase');
      expect(Strings.settingsExportSubject, 'Energy Clock export');
    });
```

- [ ] **Step 4: Create the settings card**

**Create `lib/features/progress/widgets/settings_card.dart`**

```dart
import 'dart:io';

import 'package:energy_clock/app/onboarding/onboarding_providers.dart';
import 'package:energy_clock/app/settings/settings_providers.dart';
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/progress/widgets/profile_section.dart';
import 'package:energy_clock/shared/widgets/adaptive_choice.dart';
import 'package:energy_clock/shared/widgets/adaptive_dialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Theme, focus target, first day of week, recalculate, export and erase
/// (spec §9.7). Erasing returns the app to onboarding.
class SettingsCard extends ConsumerWidget {
  const SettingsCard({super.key});

  static const List<int> _targetChoices = [60, 90, 120, 180, 240, 300, 360];

  String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => Strings.themeSystem,
    ThemeMode.light => Strings.themeLight,
    ThemeMode.dark => Strings.themeDark,
  };

  Future<void> _pickTheme(BuildContext context, WidgetRef ref) async {
    final picked = await chooseOne<ThemeMode>(
      context,
      title: Strings.settingsTheme,
      cancelLabel: Strings.cancel,
      options: [
        for (final mode in ThemeMode.values)
          ChoiceOption(label: _themeLabel(mode), value: mode),
      ],
    );
    if (picked == null || !context.mounted) return;
    await ref.read(themeModeProvider.notifier).set(picked);
  }

  Future<void> _pickTarget(BuildContext context, WidgetRef ref) async {
    final picked = await chooseOne<int>(
      context,
      title: Strings.settingsFocusTarget,
      cancelLabel: Strings.cancel,
      options: [
        for (final minutes in _targetChoices)
          ChoiceOption(
            label: formatDurationMinutes(minutes),
            value: minutes,
          ),
      ],
    );
    if (picked == null || !context.mounted) return;
    await ref.read(focusTargetProvider.notifier).set(picked);
  }

  Future<void> _pickFirstDay(BuildContext context, WidgetRef ref) async {
    final picked = await chooseOne<int>(
      context,
      title: Strings.settingsFirstDay,
      cancelLabel: Strings.cancel,
      options: const [
        ChoiceOption(label: 'Monday', value: DateTime.monday),
        ChoiceOption(label: 'Sunday', value: DateTime.sunday),
      ],
    );
    if (picked == null || !context.mounted) return;
    await ref.read(firstDayOfWeekProvider.notifier).set(picked);
  }

  Future<void> _recalculate(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDestructive(
      context,
      title: Strings.settingsRecalculateTitle,
      body: Strings.settingsRecalculateBody,
      confirmLabel: Strings.settingsRecalculateConfirm,
      cancelLabel: Strings.cancel,
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(progressRepositoryProvider).recalculateAll();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(Strings.settingsRecalculated)),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final repository = ref.read(exportRepositoryProvider);
      final path = await repository.writeTempFile(
        await repository.buildJson(),
      );
      try {
        await ref
            .read(shareServiceProvider)
            .shareFile(path, subject: Strings.settingsExportSubject);
      } finally {
        await File(path).delete();
      }
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(Strings.settingsExportFailed)),
      );
    }
  }

  Future<void> _erase(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDestructive(
      context,
      title: Strings.settingsEraseTitle,
      body: Strings.settingsEraseBody,
      confirmLabel: Strings.settingsEraseConfirm,
      cancelLabel: Strings.cancel,
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(appDatabaseProvider).resetAll();
    ref.invalidate(themeModeProvider);
    ref.invalidate(focusTargetProvider);
    ref.invalidate(firstDayOfWeekProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(Strings.settingsErased)),
    );
    ref.invalidate(onboardingDoneProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeModeProvider).valueOrNull;
    final target = ref.watch(focusTargetProvider).valueOrNull;
    final firstDay = ref.watch(firstDayOfWeekProvider).valueOrNull;
    return ProfileSection(
      title: Strings.settingsTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Row(
            key: const ValueKey('settings-theme'),
            label: Strings.settingsTheme,
            value: theme == null ? null : _themeLabel(theme),
            onTap: () => _pickTheme(context, ref),
          ),
          _Row(
            key: const ValueKey('settings-focus-target'),
            label: Strings.settingsFocusTarget,
            value:
                target == null ? null : formatDurationMinutes(target),
            onTap: () => _pickTarget(context, ref),
          ),
          _Row(
            key: const ValueKey('settings-first-day'),
            label: Strings.settingsFirstDay,
            value:
                firstDay == null
                    ? null
                    : Strings.weekdayLong[firstDay - DateTime.monday],
            onTap: () => _pickFirstDay(context, ref),
          ),
          _Row(
            key: const ValueKey('settings-recalculate'),
            label: Strings.settingsRecalculate,
            onTap: () => _recalculate(context, ref),
          ),
          _Row(
            key: const ValueKey('settings-export'),
            label: Strings.settingsExport,
            onTap: () => _export(context, ref),
          ),
          _Row(
            key: const ValueKey('settings-erase'),
            label: Strings.settingsErase,
            destructive: true,
            onTap: () => _erase(context, ref),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.onTap,
    this.value,
    this.destructive = false,
    super.key,
  });

  final String label;
  final String? value;
  final bool destructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.control),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge!.copyWith(
                  color: destructive ? colors.danger : null,
                ),
              ),
            ),
            if (value != null)
              Text(value!, style: theme.textTheme.bodyMedium),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              CupertinoIcons.chevron_right,
              size: 18,
              color: colors.muted,
            ),
          ],
        ),
      ),
    );
  }
}
```

> Notes for the implementer:
>
> - The first-day options hard-code `'Monday'`/`'Sunday'` as option labels while the row value uses `Strings.weekdayLong` — make the options use `Strings.weekdayLong[0]` and `[6]` instead (they cannot be `const` then; drop the `const` on the options list).
> - `confirmDestructive`'s exact named parameters were `title:`, `body:`, `confirmLabel:`, `cancelLabel:` in the session screen — confirmed above, no change needed.
> - Loading values (`value == null` while the provider loads) show the row without a value; the row still taps. That is the same fallback pattern as everywhere else.

- [ ] **Step 5: Wire the section into the screen**

**Edit `lib/features/progress/profile_screen.dart`** — two pairs

Replace:
```dart
import 'package:energy_clock/features/progress/widgets/roundup_archive.dart';
import 'package:energy_clock/features/progress/widgets/score_card.dart';
```
With:
```dart
import 'package:energy_clock/features/progress/widgets/roundup_archive.dart';
import 'package:energy_clock/features/progress/widgets/score_card.dart';
import 'package:energy_clock/features/progress/widgets/settings_card.dart';
```

Replace:
```dart
            BadgeGrid(unlocked: badges.valueOrNull ?? const []),
            const SizedBox(height: AppSpacing.lg),
            RoundupArchive(summaries: archive.valueOrNull ?? const []),
          ],
```
With:
```dart
            BadgeGrid(unlocked: badges.valueOrNull ?? const []),
            const SizedBox(height: AppSpacing.lg),
            RoundupArchive(summaries: archive.valueOrNull ?? const []),
            const SizedBox(height: AppSpacing.lg),
            const SettingsCard(),
          ],
```

- [ ] **Step 6: Run the tests to verify they pass**

```bash
# expect: PASS - 8 tests (7 settings + 1 strings)
flutter test test/features/progress/settings_card_test.dart test/core/strings_test.dart
```

- [ ] **Step 7: Analyze, run the suite, commit**

```bash
# expect: PASS - analyzer clean; whole suite green
flutter analyze && flutter test
```

```bash
# expect: RUN
git add lib/features/progress/widgets/settings_card.dart lib/features/progress/profile_screen.dart \
  lib/core/strings.dart test/features/progress/settings_card_test.dart test/core/strings_test.dart
git commit -m "feat: profile settings with export and erase

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

### Task 20: Profile goldens and tab hardening

Three golden images of Profile with seeded data, and the tab-scaffold harness learns the progress/roundup fakes so the real database is never constructed in widget tests.

**Files:**
- Test: `test/features/progress/profile_screen_golden_test.dart` (new)
- Modify: `test/app/tab_scaffold_test.dart` (progress + roundup overrides, one new test)
- Generated: `test/features/progress/goldens/profile_iphone_light.png`, `profile_iphone_dark.png`, `profile_ipad_landscape_light.png`

- [ ] **Step 1: Harden the tab-scaffold harness**

**Edit `test/app/tab_scaffold_test.dart`** — four pairs

Replace:
```dart
import 'package:energy_clock/data/repositories/stats_repository.dart';
```
With:
```dart
import 'package:energy_clock/data/repositories/progress_repository.dart';
import 'package:energy_clock/data/repositories/roundup_repository.dart';
import 'package:energy_clock/data/repositories/stats_repository.dart';
```
(Confirm at implementation time that the stats import from Task 8 is there; add the two imports beside it, plus `test/support/fake_progress_repository.dart` and `test/support/fake_roundup_repository.dart` in the support group.)

Replace:
```dart
        statsRepositoryProvider.overrideWithValue(FakeStatsRepository()),
      ],
```
With:
```dart
        statsRepositoryProvider.overrideWithValue(FakeStatsRepository()),
        progressRepositoryProvider.overrideWithValue(FakeProgressRepository()),
        roundupRepositoryProvider.overrideWithValue(FakeRoundupRepository()),
      ],
```

Insert after the 'tapping a tab switches the screen' test:

```dart
  testWidgets('tapping the profile tab shows the progress sections', (tester) async {
    await tester.pumpWidget(harness());
    await pumpDial(tester);

    await tester.tap(find.byKey(const ValueKey('tab-3')));
    await pumpDial(tester);

    expect(find.text(Strings.profileScoreTitle), findsOneWidget);
    expect(find.text(Strings.profileScoreEmpty), findsOneWidget);
    expect(find.text(Strings.profileBadgesTitle), findsOneWidget);
  });
```

- [ ] **Step 2: Write the golden test**

**Create `test/features/progress/profile_screen_golden_test.dart`**

```dart
// Golden images of the Profile tab, with the floating tab bar: an iPhone in
// light and dark, and an iPad in landscape, all with a streak, a score, three
// badges and two archived weeks. Animations are off, and
// `test/flutter_test_config.dart` loads Nunito, so every image is
// deterministic and shows real text.
import 'package:energy_clock/app/navigation/tab_scaffold.dart';
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/roundup/roundup_payload.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/tables/day_scores_table.dart';
import 'package:energy_clock/data/tables/progress_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

const screenKey = ValueKey('profile-screen-golden');

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
    final today = startOfDay(DateTime.now());
    harness.progress.setProgress(
      ProgressRow(
        id: 1,
        xp: 250,
        level: 2,
        currentStreak: 6,
        longestStreak: 14,
        lastStreakDate: today,
      ),
    );
    harness.progress.setScore(
      today,
      DayScoreRow(
        date: today,
        energyScore: 88,
        adherencePoints: 45,
        focusPoints: 23,
        balancePoints: 20,
        focusMinutes: 140,
        lifeMinutes: 45,
        inboxMinutes: 30,
        plannedMinutes: 300,
        completedMinutes: 215,
        computedAt: DateTime.now(),
      ),
    );
    harness.progress.emitBadges([
      BadgeUnlockRow(
        badgeId: 'first_session',
        unlockedAt: DateTime(2026, 9, 30),
      ),
      BadgeUnlockRow(badgeId: 'streak_7', unlockedAt: DateTime(2026, 10, 6)),
      BadgeUnlockRow(badgeId: 'early_bird', unlockedAt: DateTime(2026, 10, 7)),
    ]);
    harness.roundups.setArchive([
      (isoYear: 2026, isoWeek: 41, generatedAt: DateTime(2026, 10, 13)),
      (isoYear: 2026, isoWeek: 40, generatedAt: DateTime(2026, 10, 6)),
    ]);
    RoundupPayload payload({required int week, required DateTime start}) =>
        RoundupPayload(
          isoYear: 2026,
          isoWeek: week,
          weekStart: start,
          adherencePercent: 83,
          plannedMinutes: 900,
          completedMinutes: 750,
          totalMinutes: 750,
          focusMinutes: 480,
          lifeMinutes: 180,
          inboxMinutes: 90,
          bestFocusDay: DateTime(2026, 10, 8),
          bestFocusMinutes: 200,
          currentStreak: 5,
          longestStreak: 9,
          badgesUnlocked: const ['streak_7'],
          xpEarned: 400,
          previousAdherencePercent: 71,
        );
    harness.roundups.payloads[(2026, 41)] = payload(
      week: 41,
      start: DateTime(2026, 10, 5),
    );
    harness.roundups.payloads[(2026, 40)] = payload(
      week: 40,
      start: DateTime(2026, 9, 28),
    );
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> check(
    WidgetTester tester, {
    required Size size,
    required ThemeData theme,
    required String file,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: RepaintBoundary(
          key: screenKey,
          child: MaterialApp(
            theme: theme,
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const TabScaffold(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tab-3')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(screenKey),
      matchesGoldenFile('goldens/$file'),
    );
  }

  testWidgets('iPhone 17 Pro, light', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.light,
      file: 'profile_iphone_light.png',
    );
  });

  testWidgets('iPhone 17 Pro, dark', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.dark,
      file: 'profile_iphone_dark.png',
    );
  });

  testWidgets('iPad 11" landscape, light', (tester) async {
    await check(
      tester,
      size: const Size(1194, 834),
      theme: AppTheme.light,
      file: 'profile_ipad_landscape_light.png',
    );
  });
}
```

- [ ] **Step 3: Generate the goldens and look at them**

```bash
# expect: RUN - three new images appear under test/features/progress/goldens/
flutter test test/features/progress/profile_screen_golden_test.dart --update-goldens
```

```bash
# expect: MANUAL - open the three images and check: level and XP bar, today's
# score with its three points rows and caption, ten badge tiles (three earned),
# two archive rows, and the six settings rows, all inside the window in both
# themes and on the iPad spread. CupertinoIcons render as tofu on this machine
# (pre-existing baseline) - judge layout, not the chevron glyphs.
```

- [ ] **Step 4: Run the golden test to verify it passes**

```bash
# expect: PASS - 3 golden tests pass, plus the updated tab-scaffold file
flutter test test/features/progress/profile_screen_golden_test.dart test/app/tab_scaffold_test.dart
```

- [ ] **Step 5: Analyze, run the suite, commit**

```bash
# expect: PASS - analyzer clean; whole suite green
flutter analyze && flutter test
```

```bash
# expect: RUN
git add test/features/progress/profile_screen_golden_test.dart \
  test/features/progress/goldens/ test/app/tab_scaffold_test.dart
git commit -m "test: profile golden images and tab coverage

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

### Task 21: Polish — README, format, full suite

README stops calling the tabs placeholders, formatting is confirmed clean, and the whole suite runs one last time.

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update the README**

**Edit `README.md`** — two pairs

Replace:
```dart
It runs on iPhone (portrait) and iPad (all orientations). The dial planner, the week strip, the Now card, the event sheets, the session timer, repeating events, day templates, Copy yesterday and the Calendar are done; the Stats and Profile tabs are still placeholders.
```
With:
```dart
It runs on iPhone (portrait) and iPad (all orientations). The dial planner, the week strip, the Now card, the event sheets, the session timer, repeating events, day templates, Copy yesterday, the Calendar, Stats (week/month tone balance, planned-vs-actual, focus depth, heatmap) and Profile (level and streaks, energy score, badges, weekly roundups, settings, export) are done; notifications arrive in Step 5.
```

Replace:
```dart
  features/     clock, session, calendar (stats and profile are placeholders)
```
With:
```dart
  features/     clock, session, calendar, stats, progress (profile)
```

- [ ] **Step 2: Confirm formatting, analyze, run the full suite**

```bash
# expect: PASS - no output means every file is formatted
DART="$(dirname "$(which flutter)")/dart"
"$DART" format --output=none --set-exit-if-changed lib test
```

```bash
# expect: PASS - analyzer clean; the whole suite passes (roughly 1,510 tests: 1,361 baseline + ~150 new)
flutter analyze && flutter test
```

- [ ] **Step 3: Commit**

```bash
# expect: RUN
git add README.md
git commit -m "docs: stats and profile are done

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 4: Self-review the plan**

```bash
# expect: MANUAL - read the finished plan file end to end and check:
# - every task's test file, source file and provider/fake names match across tasks
#   (StatsSnapshot fields, FocusDepth fields, BadgeFacts fields, RoundupPayload
#   fields incl. the Task 18 tone-minutes amendment, Fake* APIs, harness fields);
# - every Edit block's Replace: text matches the file as the previous task left it;
# - no plan code imports a feature from another feature;
# - no new runtime package beyond share_plus, no path_provider import;
# - every # expect: block states the right outcome.
# Fix what you find before handing over.
```

