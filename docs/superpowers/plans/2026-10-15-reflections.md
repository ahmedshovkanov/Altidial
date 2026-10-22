# Session Debriefs + Energy Patterns (Reflections) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 10-second post-session debrief (energy 1-5, focus 1-5, max 4 tags, 0-140 char note) stored on `sessions`, with a journal timeline and data-driven pattern cards, fully offline.

**Architecture:** Extend `Sessions` table (v6→v7) with 4 nullable columns; pure Dart `ReflectionPatterns.compute` over joined session+event rows (same recompute rule as energy score); new `lib/features/reflections/` module (model + repository + providers + screen + widgets) surfaced as Stats 5th section + Profile card; debrief sheet in `features/session/` shown after every session end.

**Tech Stack:** Flutter 3.44.7 / Dart 3.12.2, Riverpod `StreamProvider`/`Provider`, Drift typed SQLite with `build_runner` codegen, `flutter_test` + in-memory Drift for DAO tests.

## Global Constraints

- Offline-only, on-device. No account, no backend, no sync, no HTTP client.
- English-only. Every user-facing string lives in `lib/core/strings.dart` as `static const` or `static String method` — never hard-code copy in widgets.
- No hard-coded colours in feature code. Every colour comes from theme tokens via `context.appColors` (`lib/app/theme/app_colors.dart`) or `context.toneColors` (`lib/app/theme/tone_colors.dart`) or `AppSpacing` (`lib/app/theme/tokens.dart`). The test `test/architecture/no_hardcoded_colors_test.dart` must keep passing.
- Features never import each other. `features/reflections/` and `features/session/` may import only `data/`, `core/`, `app/`, `shared/`. Cross-feature communication goes through repositories exposed as Riverpod providers in `lib/data/providers.dart`.
- Drift migrations are versioned. Every schema bump needs a step in `AppDatabase.migration` in `lib/data/database.dart` and a test in `test/data/migration_test.dart`; dumps live in `drift_schemas/`.
- Codegen uses the Flutter SDK's `dart`: run `flutter pub get` first, then `dart run build_runner build --delete-conflicting-outputs`.
- Verify with `flutter analyze` (must be clean) and `flutter test <path>` (must pass). Do NOT run `flutter test --update-goldens` unless you deliberately changed dial pixels and looked at the images.
- Tones are fixed and exactly three: `Tone.focus` (dbIndex 0), `Tone.life` (1), `Tone.inbox` (2). Never add, rename, or recolour.
- Session outcomes persisted as dbIndex: running 0, completed 1, finishedEarly 2, abandoned 3. `countsAsDone` = completed or finishedEarly only. Running and abandoned are excluded from all pattern aggregates but visible in the timeline.

---

## File Structure

New files (each has one clear responsibility):

- `lib/features/reflections/model/reflection.dart` — pure constants + validation + `ReflectionPatterns.compute`. No Flutter, no Drift imports. Only imports `core/tone.dart` and `core/session/session_outcome.dart`.
- `lib/data/repositories/reflections_repository.dart` — `ReflectedSession` typedef + `ReflectionsRepository` interface + `DriftReflectionsRepository` that joins `sessions` + `events` client-side. Imports only `data/database.dart`, `core/` types.
- `lib/features/reflections/providers.dart` — `reflectionsRepositoryProvider` alias + `reflectionsTimelineProvider` (`StreamProvider<List<ReflectedSession>>`) + `reflectionPatternsProvider` (`StreamProvider<ReflectionCards>`). Imports `data/providers.dart`, model, repository.
- `lib/features/session/widgets/debrief_sheet.dart` — `showDebriefSheet(context, ref, sessionId, eventTitle, activeMinutes)` bottom sheet returning `bool` saved-or-not. Imports `core/strings.dart`, theme tokens, repository provider.
- `lib/features/reflections/reflections_screen.dart` — `ReflectionsScreen` timeline grouped Today / This week / Earlier, with error + empty states and edit entry point.
- `lib/features/reflections/widgets/reflection_row.dart` — one timeline row: tone dot (theme color), title, `50m · Focus`, 5-dot energy/focus bars, tag pills, note preview.
- `lib/features/reflections/widgets/patterns_card.dart` — Stats 5th section `EnergyPatternsCard` reusing `StatsSectionCard`, rendering `ReflectionCards` bars.
- `lib/features/progress/widgets/reflections_card.dart` — Profile teaser card (reflected count + top pattern → opens timeline). Mirrors `projects_card.dart` pattern.
- Tests: `test/features/reflections/reflection_patterns_test.dart`, `test/data/reflections_repository_test.dart`, `test/data/reflection_migration_test.dart` (or extend `test/data/migration_test.dart`), `test/features/session/debrief_sheet_test.dart`, `test/features/reflections/reflections_screen_test.dart`.

Modified files:

- `lib/data/tables/sessions_table.dart` — add 4 nullable columns.
- `lib/data/database.dart` — `schemaVersion` 6→7, add `if (from < 7)` migration with 4 `addColumn`, extend `resetAll` comment (no code change needed — sessions already deleted first).
- `lib/data/daos/session_dao.dart` — add `updateReflection` + `watchEndedSessions` + `endedSessions` query helpers.
- `lib/data/models/session.dart` — add `energyRating`, `focusRating`, `tags`, `note` fields to `SessionRecord` + `fromRow` + `==`/`hashCode`.
- `lib/data/repositories/session_repository.dart` — add `saveReflection({required int sessionId, int? energyRating, int? focusRating, List<String> tags, String? note})` to interface + implementation.
- `lib/core/strings.dart` — append reflection copy block (exact names listed in Task 4).
- `lib/features/session/session_screen.dart` — call `showDebriefSheet` after `_finish`, `_abandon`, `_closeOut` success.
- `lib/features/stats/stats_screen.dart` — insert `EnergyPatternsCard` as 5th section in both twoColumn and single-column branches.
- `lib/features/progress/profile_screen.dart` — insert `ReflectionsCard` after `ProjectsCard` with `SizedBox` gap.
- `lib/data/providers.dart` — add `reflectionsRepositoryProvider`.
- `lib/data/repositories/export_repository.dart` — verify session columns export automatically; if it selects explicit columns, add the 4 new ones (check in Task 8).
- `drift_schemas/drift_schema_v7.json` + `test/generated_migrations/schema.dart` — regenerated via drift commands.

---

### Task 1: Database schema v6 → v7 (sessions reflection columns)

**Files:**
- Modify: `lib/data/tables/sessions_table.dart`
- Modify: `lib/data/database.dart:62` (schemaVersion) and `:64-94` (migration)
- Create: `drift_schemas/drift_schema_v7.json` (generated)
- Test: `test/data/migration_test.dart` (append 2 tests)

**Interfaces:**
- Consumes: existing `Sessions` table definition, `AppDatabase.migration` pattern for v6 (`migrator.createTable(projects)` + `migrator.addColumn(events, events.projectId)`).
- Produces: `Sessions.energyRating`, `Sessions.focusRating`, `Sessions.tagsCsv`, `Sessions.note` columns; `schemaVersion == 7`; migration step `from < 7` adding all 4 columns.

- [ ] **Step 1: Write the failing migration test (append to test/data/migration_test.dart)**

```dart
test('version 6 upgrades to version 7 with reflection columns defaulting null', () async {
  final schema = await verifier.schemaAt(6);
  final database = AppDatabase.forTesting(schema.newConnection());
  addTearDown(database.close);
  await verifier.migrateAndValidate(database, 7);
  final rows = await database.select(database.sessions).get();
  expect(rows, isEmpty);
});

test('upgrading from version 6 reads old sessions as not reflected', () async {
  final schema = await verifier.schemaAt(6);
  schema.rawDatabase.execute(
    "$insertEvent VALUES ($seconds, 'Deep work', 0, 540, 660, 0, $seconds, $seconds)",
  );
  schema.rawDatabase.execute(
    'INSERT INTO sessions (event_id, started_at, planned_seconds, '
    'paused_seconds, active_seconds, overtime_seconds, outcome) '
    'VALUES (1, $seconds, 3600, 0, 3600, 0, 1)',
  );
  final database = AppDatabase.forTesting(schema.newConnection());
  addTearDown(database.close);
  await verifier.migrateAndValidate(database, 7);
  final sessions = await database.sessionDao.sessionsForEvent(1);
  expect(sessions.single.outcome, 1);
  expect(sessions.single.energyRating, isNull);
  expect(sessions.single.focusRating, isNull);
  expect(sessions.single.tagsCsv, isNull);
  expect(sessions.single.note, isNull);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/migration_test.dart -v`
Expected: FAIL — `schemaAt(6)` migrates to 6 but `migrateAndValidate(database, 7)` throws `Unknown schema version` / `schemaVersion is 6`, and `sessions.single.energyRating` does not compile (getter missing).

- [ ] **Step 3: Add the 4 columns to lib/data/tables/sessions_table.dart**

Replace the file content after the `outcome` getter (keep everything above identical, only append):

```dart
  /// 0 running, 1 completed, 2 finished early, 3 abandoned.
  IntColumn get outcome => integer().withDefault(const Constant(0))();

  /// 1–5 (drained → charged). Null = not reflected.
  IntColumn get energyRating => integer().nullable()();

  /// 1–5 (scattered → in flow). Null = not reflected.
  IntColumn get focusRating => integer().nullable()();

  /// Comma-joined tag ids, max 4. Null or empty = none.
  TextColumn get tagsCsv => text().nullable()();

  /// 0–140 chars, trimmed. Null or empty = none.
  TextColumn get note => text().nullable()();
```

Full file must keep `import 'package:drift/drift.dart';` and `import 'package:energy_clock/data/tables/events_table.dart';` at top and `@DataClassName('SessionRow')` unchanged.

- [ ] **Step 4: Bump schemaVersion and add migration in lib/data/database.dart**

Change line 62 `int get schemaVersion => 6;` to:

```dart
  int get schemaVersion => 7;
```

Update the doc comment on lines 55-60 to append `Version 7: reflection columns on sessions (energyRating, focusRating, tagsCsv, note).` keeping prior lines.

Inside `onUpgrade`, after the `if (from < 6) { ... }` block, insert exactly:

```dart
      if (from < 7) {
        await migrator.addColumn(sessions, sessions.energyRating);
        await migrator.addColumn(sessions, sessions.focusRating);
        await migrator.addColumn(sessions, sessions.tagsCsv);
        await migrator.addColumn(sessions, sessions.note);
      }
```

- [ ] **Step 5: Regenerate Drift code and schema dump**

Run in order:

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev schema dump lib/data/database.dart drift_schemas/
dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
```

Expected: `build_runner` prints `Built with build_runner in Xs; wrote N outputs`, `drift_schema_v7.json` appears in `drift_schemas/`, `test/generated_migrations/schema.dart` updated with `Version 7`. If `drift_dev schema generate` syntax differs, open `tool/` or prior commit `1a3fa43` message for exact flags — do NOT skip generating; migration tests need version 7 stubs.

- [ ] **Step 6: Run migration tests to verify they pass**

Run: `flutter test test/data/migration_test.dart -v`
Expected: PASS all tests including the 2 new ones.

- [ ] **Step 7: Run analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/data/tables/sessions_table.dart lib/data/database.dart drift_schemas/ test/generated_migrations/ lib/data/database.g.dart lib/data/daos/session_dao.g.dart test/data/migration_test.dart
git commit -m "feat: sessions schema v7 with reflection columns"
```

---

### Task 2: Pure reflection model (tags, validation, patterns engine)

**Files:**
- Create: `lib/features/reflections/model/reflection.dart`
- Test: `test/features/reflections/reflection_patterns_test.dart`

**Interfaces:**
- Consumes: `Tone` (dbIndex 0/1/2), `SessionOutcome` (dbIndex 0-3, `countsAsDone`).
- Produces:
  - `abstract final class ReflectionTags { static const List<String> allIds; static const int maxTags = 4; static const int maxNoteLength = 140; static List<String> sanitizeTags(List<String>); static String? validateNote(String?); static String encodeTags(List<String>); static List<String> decodeTags(String?); }`
  - `typedef PatternInput = ({Tone tone, int energyRating, int focusRating, List<String> tags, int startHour, bool isPostLife});`
  - `typedef PatternCard = ({String title, String detail, double delta, int sampleSize});`
  - `abstract final class ReflectionPatterns { static const int minSample = 5; static List<PatternCard> compute(List<PatternInput> inputs); }`

- [ ] **Step 1: Write the failing test**

Create `test/features/reflections/reflection_patterns_test.dart` with exactly:

```dart
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/reflections/model/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

PatternInput input({
  required Tone tone,
  required int energy,
  required int focus,
  List<String> tags = const [],
  int hour = 10,
  bool postLife = false,
}) => (tone: tone, energyRating: energy, focusRating: focus, tags: tags, startHour: hour, isPostLife: postLife);

void main() {
  test('fewer than 5 reflected sessions yields no cards', () {
    final inputs = [for (var i = 0; i < 4; i++) input(tone: Tone.focus, energy: 5, focus: 5)];
    expect(ReflectionPatterns.compute(inputs), isEmpty);
  });

  test('sanitizeTags keeps max 4 known ids in order', () {
    expect(
      ReflectionTags.sanitizeTags(['flow', 'bogus', 'clear-goal', 'tired', 'noisy', 'flow']),
      ['flow', 'clear-goal', 'tired', 'noisy'],
    );
  });

  test('validateNote rejects over 140 chars, accepts null and empty', () {
    expect(ReflectionTags.validateNote(null), isNull);
    expect(ReflectionTags.validateNote(''), isNull);
    expect(ReflectionTags.validateNote('a' * 140), isNull);
    expect(ReflectionTags.validateNote('a' * 141), isNotNull);
  });

  test('encode/decode tags round-trip, unknown ids dropped on decode', () {
    expect(ReflectionTags.decodeTags(null), isEmpty);
    expect(ReflectionTags.decodeTags(''), isEmpty);
    const csv = 'flow,clear-goal';
    expect(ReflectionTags.decodeTags(csv), ['flow', 'clear-goal']);
    expect(ReflectionTags.encodeTags(['flow', 'clear-goal']), csv);
  });

  test('clear-goal tag lifts focus card appears with n>=5', () {
    final inputs = <PatternInput>[
      for (var i = 0; i < 6; i++) input(tone: Tone.focus, energy: 4, focus: 5, tags: ['clear-goal']),
      for (var i = 0; i < 6; i++) input(tone: Tone.focus, energy: 3, focus: 2),
    ];
    final cards = ReflectionPatterns.compute(inputs);
    expect(cards.any((c) => c.title.contains('Clear goal')), isTrue);
    final card = cards.firstWhere((c) => c.title.contains('Clear goal'));
    expect(card.sampleSize, 12);
    expect(card.delta, greaterThan(1.0));
  });

  test('late inbox drain card appears for hour>=21 inbox with low energy', () {
    final inputs = <PatternInput>[
      for (var i = 0; i < 6; i++) input(tone: Tone.inbox, energy: 2, focus: 2, hour: 22),
      for (var i = 0; i < 6; i++) input(tone: Tone.focus, energy: 4, focus: 4, hour: 10),
    ];
    final cards = ReflectionPatterns.compute(inputs);
    expect(cards.any((c) => c.title.contains('after 21:00')), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/reflections/reflection_patterns_test.dart -v`
Expected: FAIL with `Target of URI hasn't been generated` / `Undefined class ReflectionTags` because `lib/features/reflections/model/reflection.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

Create `lib/features/reflections/model/reflection.dart` with exactly:

```dart
import 'package:energy_clock/core/tone.dart';

/// Fixed tag set v1. No custom tags.
abstract final class ReflectionTags {
  static const List<String> allIds = [
    'flow',
    'clear-goal',
    'interruptions',
    'noisy',
    'tired',
    'time-pressure',
    'context-switch',
    'low-energy',
  ];

  static const int maxTags = 4;
  static const int maxNoteLength = 140;

  static const Map<String, String> labels = {
    'flow': 'Flow',
    'clear-goal': 'Clear goal',
    'interruptions': 'Interruptions',
    'noisy': 'Noisy',
    'tired': 'Tired',
    'time-pressure': 'Time pressure',
    'context-switch': 'Context switch',
    'low-energy': 'Low energy',
  };

  static String labelOf(String id) => labels[id] ?? id;

  /// Keeps first-seen order, drops unknown ids and duplicates, caps at 4.
  static List<String> sanitizeTags(List<String> tags) {
    final seen = <String>[];
    for (final tag in tags) {
      if (!allIds.contains(tag)) continue;
      if (seen.contains(tag)) continue;
      seen.add(tag);
      if (seen.length >= maxTags) break;
    }
    return seen;
  }

  static String? validateNote(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (value.trim().length > maxNoteLength) {
      return 'Keep notes under 140 characters';
    }
    return null;
  }

  static String encodeTags(List<String> tags) => sanitizeTags(tags).join(',');

  static List<String> decodeTags(String? csv) {
    if (csv == null || csv.trim().isEmpty) return const [];
    return sanitizeTags(csv.split(',').map((s) => s.trim()).toList());
  }
}

typedef PatternInput = ({
  Tone tone,
  int energyRating,
  int focusRating,
  List<String> tags,
  int startHour,
  bool isPostLife,
});

typedef PatternCard = ({
  String title,
  String detail,
  double delta,
  int sampleSize,
});

/// Pure recomputation over reflected sessions. Returns [] when n < 5.
/// Completed + finishedEarly inputs only — callers must filter abandoned/running.
abstract final class ReflectionPatterns {
  static const int minSample = 5;

  static List<PatternCard> compute(List<PatternInput> inputs) {
    if (inputs.length < minSample) return const [];
    final cards = <PatternCard>[];
    final withClear = inputs.where((i) => i.tags.contains('clear-goal')).toList();
    final withoutClear = inputs.where((i) => !i.tags.contains('clear-goal')).toList();
    if (withClear.length >= minSample && withoutClear.isNotEmpty) {
      final a = _avgFocus(withClear);
      final b = _avgFocus(withoutClear);
      final delta = a - b;
      if (delta >= 0.5) {
        cards.add((
          title: 'Clear goal → +${delta.toStringAsFixed(1)} focus',
          detail: 'Sessions with a clear goal average ${a.toStringAsFixed(1)} vs ${b.toStringAsFixed(1)} without (n=${inputs.length})',
          delta: delta,
          sampleSize: inputs.length,
        ));
      }
    }
    final lateInbox = inputs.where((i) => i.tone == Tone.inbox && i.startHour >= 21).toList();
    final rest = inputs.where((i) => !(i.tone == Tone.inbox && i.startHour >= 21)).toList();
    if (lateInbox.length >= minSample && rest.isNotEmpty) {
      final a = _avgEnergy(rest);
      final b = _avgEnergy(lateInbox);
      final drain = a - b;
      if (drain >= 0.5) {
        cards.add((
          title: 'Inbox after 21:00 −${drain.toStringAsFixed(1)} energy',
          detail: 'Late inbox averages ${b.toStringAsFixed(1)} vs ${a.toStringAsFixed(1)} otherwise (n=${inputs.length})',
          delta: -drain,
          sampleSize: inputs.length,
        ));
      }
    }
    final postLife = inputs.where((i) => i.isPostLife && i.tone == Tone.focus).toList();
    final otherFocus = inputs.where((i) => !(i.isPostLife && i.tone == Tone.focus) && i.tone == Tone.focus).toList();
    if (postLife.length >= 3 && otherFocus.length >= 3 && inputs.length >= minSample) {
      final a = _avgEnergy(postLife);
      final b = _avgEnergy(otherFocus);
      final lift = a - b;
      if (lift >= 0.5) {
        cards.add((
          title: 'Focus after Life +${lift.toStringAsFixed(1)}',
          detail: 'Focus right after Life averages ${a.toStringAsFixed(1)} vs ${b.toStringAsFixed(1)} (n=${inputs.length})',
          delta: lift,
          sampleSize: inputs.length,
        ));
      }
    }
    return cards;
  }

  static double _avgFocus(List<PatternInput> list) {
    if (list.isEmpty) return 0;
    var sum = 0;
    for (final i in list) sum += i.focusRating;
    return sum / list.length;
  }

  static double _avgEnergy(List<PatternInput> list) {
    if (list.isEmpty) return 0;
    var sum = 0;
    for (final i in list) sum += i.energyRating;
    return sum / list.length;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/reflections/reflection_patterns_test.dart -v`
Expected: PASS all 6 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/features/reflections/model/reflection.dart test/features/reflections/reflection_patterns_test.dart
git commit -m "feat: pure reflection tags and patterns engine"
```

---

### Task 3: SessionRecord fields + DAO update + repository saveReflection

**Files:**
- Modify: `lib/data/models/session.dart:10-46` (SessionRecord)
- Modify: `lib/data/daos/session_dao.dart` (append methods)
- Modify: `lib/data/repositories/session_repository.dart` (interface + impl)
- Test: `test/data/reflections_repository_test.dart` (new file testing save + read-back via sessionDao)

**Interfaces:**
- Consumes: `SessionRow.energyRating/focusRating/tagsCsv/note` from Task 1; `ReflectionTags.encodeTags/decodeTags/validateNote` from Task 2.
- Produces: `SessionDao.updateReflection(...)`, `SessionDao.watchEndedSessions()`, `SessionDao.endedSessions()`; `SessionRecord.energyRating/focusRating/tags/note`; `SessionRepository.saveReflection(...)`.

- [ ] **Step 1: Write the failing test**

Create `test/data/reflections_repository_test.dart` with exactly:

```dart
import 'package:drift/drift.dart' hide isNull;
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/session_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_repository_test.dart' show openTestDatabase;

void main() {
  test('saveReflection persists energy focus tags note and edits overwrite', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final repo = DriftSessionRepository(db.sessionDao);
    final now = DateTime(2026, 10, 15, 10, 0);
    final eventId = await db.into(db.events).insert(
      EventsCompanion.insert(
        date: DateTime(2026, 10, 15),
        title: 'Deep work',
        toneIndex: 0,
        startMinute: 540,
        endMinute: 600,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final sessionId = await repo.start(eventId: eventId);
    await repo.finish(sessionId);
    await repo.saveReflection(
      sessionId: sessionId,
      energyRating: 4,
      focusRating: 5,
      tags: ['flow', 'clear-goal'],
      note: 'Great hour',
    );
    var row = await db.sessionDao.sessionById(sessionId);
    expect(row!.energyRating, 4);
    expect(row.focusRating, 5);
    expect(row.tagsCsv, 'flow,clear-goal');
    expect(row.note, 'Great hour');
    await repo.saveReflection(
      sessionId: sessionId,
      energyRating: 2,
      focusRating: 2,
      tags: ['tired'],
      note: null,
    );
    row = await db.sessionDao.sessionById(sessionId);
    expect(row!.energyRating, 2);
    expect(row.tagsCsv, 'tired');
    expect(row.note, isNull);
  });

  test('saveReflection rejects out-of-range ratings and over-long notes', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final repo = DriftSessionRepository(db.sessionDao);
    final now = DateTime(2026, 10, 15, 10, 0);
    final eventId = await db.into(db.events).insert(
      EventsCompanion.insert(
        date: DateTime(2026, 10, 15),
        title: 'Email',
        toneIndex: 2,
        startMinute: 600,
        endMinute: 660,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final sessionId = await repo.start(eventId: eventId);
    await repo.finish(sessionId);
    expect(
      () => repo.saveReflection(sessionId: sessionId, energyRating: 0, focusRating: 5, tags: const [], note: null),
      throwsArgumentError,
    );
    expect(
      () => repo.saveReflection(sessionId: sessionId, energyRating: 3, focusRating: 6, tags: const [], note: null),
      throwsArgumentError,
    );
    expect(
      () => repo.saveReflection(sessionId: sessionId, energyRating: 3, focusRating: 3, tags: const [], note: 'a' * 141),
      throwsArgumentError,
    );
  });
}
```

Note: open `test/data/session_repository_test.dart` first and confirm helper name `openTestDatabase` exists; if it is named differently (e.g. `openDatabase`), replace the import line and both call sites with the exact name found — do NOT invent a new helper.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/reflections_repository_test.dart -v`
Expected: FAIL — `saveReflection` undefined on `SessionRepository`, `energyRating` getter missing on `SessionRow`.

- [ ] **Step 3: Extend SessionRecord in lib/data/models/session.dart**

Replace the `SessionRecord` constructor + factory + fields with exactly (keep `RunningSession` below untouched):

```dart
class SessionRecord {
  const SessionRecord({
    required this.id,
    required this.eventId,
    required this.startedAt,
    required this.endedAt,
    required this.plannedSeconds,
    required this.pausedSeconds,
    required this.pauseStartedAt,
    required this.activeSeconds,
    required this.overtimeSeconds,
    required this.outcome,
    this.energyRating,
    this.focusRating,
    this.tags = const [],
    this.note,
  });

  factory SessionRecord.fromRow(SessionRow row) => SessionRecord(
    id: row.id,
    eventId: row.eventId,
    startedAt: row.startedAt,
    endedAt: row.endedAt,
    plannedSeconds: row.plannedSeconds,
    pausedSeconds: row.pausedSeconds,
    pauseStartedAt: row.pauseStartedAt,
    activeSeconds: row.activeSeconds,
    overtimeSeconds: row.overtimeSeconds,
    outcome: SessionOutcome.fromDbIndex(row.outcome),
    energyRating: row.energyRating,
    focusRating: row.focusRating,
    tags: row.tagsCsv == null || row.tagsCsv!.isEmpty
        ? const []
        : row.tagsCsv!.split(',').where((s) => s.isNotEmpty).toList(),
    note: row.note,
  );

  final int id;
  final int eventId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int plannedSeconds;
  final int pausedSeconds;
  final DateTime? pauseStartedAt;
  final int activeSeconds;
  final int overtimeSeconds;
  final SessionOutcome outcome;
  final int? energyRating;
  final int? focusRating;
  final List<String> tags;
  final String? note;

  bool get isReflected => energyRating != null || focusRating != null || tags.isNotEmpty || (note != null && note!.isNotEmpty);
```

Also update `operator ==` to include the 4 new fields and `hashCode` to include them:

```dart
  @override
  bool operator ==(Object other) =>
      other is SessionRecord &&
      other.id == id &&
      other.eventId == eventId &&
      other.startedAt == startedAt &&
      other.endedAt == endedAt &&
      other.plannedSeconds == plannedSeconds &&
      other.pausedSeconds == pausedSeconds &&
      other.pauseStartedAt == pauseStartedAt &&
      other.activeSeconds == activeSeconds &&
      other.overtimeSeconds == overtimeSeconds &&
      other.outcome == outcome &&
      other.energyRating == energyRating &&
      other.focusRating == focusRating &&
      other.note == note &&
      _tagsEqual(other.tags, tags);

  static bool _tagsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    eventId,
    startedAt,
    endedAt,
    plannedSeconds,
    pausedSeconds,
    pauseStartedAt,
    activeSeconds,
    overtimeSeconds,
    outcome,
    energyRating,
    focusRating,
    note,
    Object.hashAll(tags),
  );
```

- [ ] **Step 4: Add DAO methods in lib/data/daos/session_dao.dart**

Append inside `class SessionDao` after `sessionsForEvent`, before `inTransaction`:

```dart
  Future<void> updateReflection({
    required int sessionId,
    required int? energyRating,
    required int? focusRating,
    required String? tagsCsv,
    required String? note,
  }) => (update(sessions)..where((row) => row.id.equals(sessionId))).write(
    SessionsCompanion(
      energyRating: Value(energyRating),
      focusRating: Value(focusRating),
      tagsCsv: Value(tagsCsv),
      note: Value(note),
    ),
  );

  /// Every ended session, newest first. Powers the journal timeline.
  Future<List<SessionRow>> endedSessions() =>
      (select(sessions)
            ..where((row) => row.endedAt.isNotNull())
            ..orderBy([(row) => OrderingTerm.desc(row.endedAt)])
            ..limit(500))
          .get();

  Stream<List<SessionRow>> watchEndedSessions() =>
      (select(sessions)
            ..where((row) => row.endedAt.isNotNull())
            ..orderBy([(row) => OrderingTerm.desc(row.endedAt)])
            ..limit(500))
          .watch();
```

- [ ] **Step 5: Add saveReflection to lib/data/repositories/session_repository.dart**

Add import at top: `import 'package:energy_clock/features/reflections/model/reflection.dart';`

Add to `abstract interface class SessionRepository` after `closeOut`:

```dart
  /// Saves the post-session debrief. Throws [ArgumentError] on out-of-range
  /// ratings (must be null or 1–5), more than 4 known tags after sanitizing
  /// is trimmed (never throws), or notes over 140 chars.
  Future<void> saveReflection({
    required int sessionId,
    int? energyRating,
    int? focusRating,
    List<String> tags = const [],
    String? note,
  });
```

Add to `DriftSessionRepository` after `closeOut` method, before `_end`:

```dart
  @override
  Future<void> saveReflection({
    required int sessionId,
    int? energyRating,
    int? focusRating,
    List<String> tags = const [],
    String? note,
  }) {
    if (energyRating != null && (energyRating < 1 || energyRating > 5)) {
      throw ArgumentError.value(energyRating, 'energyRating', 'Must be 1–5 or null');
    }
    if (focusRating != null && (focusRating < 1 || focusRating > 5)) {
      throw ArgumentError.value(focusRating, 'focusRating', 'Must be 1–5 or null');
    }
    final trimmed = note?.trim();
    if (trimmed != null && trimmed.isNotEmpty && trimmed.length > ReflectionTags.maxNoteLength) {
      throw ArgumentError.value(note, 'note', 'Must be 0–140 characters');
    }
    final cleanTags = ReflectionTags.sanitizeTags(tags);
    final csv = cleanTags.isEmpty ? null : cleanTags.join(',');
    final finalNote = trimmed == null || trimmed.isEmpty ? null : trimmed;
    return _dao.updateReflection(
      sessionId: sessionId,
      energyRating: energyRating,
      focusRating: focusRating,
      tagsCsv: csv,
      note: finalNote,
    );
  }
```

- [ ] **Step 6: Run tests**

Run: `flutter test test/data/reflections_repository_test.dart test/data/session_repository_test.dart -v`
Expected: PASS.

- [ ] **Step 7: Run analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/data/models/session.dart lib/data/daos/session_dao.dart lib/data/repositories/session_repository.dart test/data/reflections_repository_test.dart
git commit -m "feat: saveReflection with validation and record fields"
```

---

### Task 4: Strings + debrief sheet UI + session wiring

**Files:**
- Modify: `lib/core/strings.dart` (append block before final `}`)
- Create: `lib/features/session/widgets/debrief_sheet.dart`
- Modify: `lib/features/session/session_screen.dart:82-113` (`_finish`, `_abandon`, `_closeOut`)
- Test: `test/features/session/debrief_sheet_test.dart`

**Interfaces:**
- Consumes: `SessionRepository.saveReflection`, `ReflectionTags.allIds/labels/maxTags/maxNoteLength`, theme tokens.
- Produces: `Future<bool> showDebriefSheet(BuildContext context, WidgetRef ref, {required int sessionId, required String eventTitle, required int activeMinutes})` — returns true if saved, false if skipped/dismissed.

- [ ] **Step 1: Append strings (exact names — widgets reference these)**

In `lib/core/strings.dart`, before the final closing `}` of `abstract final class Strings`, insert exactly:

```dart
  // Reflections (session debriefs).
  static const String debriefTitle = 'How was it?';
  static const String debriefEnergy = 'Energy';
  static const String debriefEnergyLow = 'Drained';
  static const String debriefEnergyHigh = 'Charged';
  static const String debriefFocus = 'Focus';
  static const String debriefFocusLow = 'Scattered';
  static const String debriefFocusHigh = 'In flow';
  static const String debriefTags = 'What shaped it?';
  static const String debriefNoteHint = 'One line (optional)';
  static const String debriefSave = 'Save reflection';
  static const String debriefSkip = 'Skip';
  static const String debriefSaved = 'Reflection saved.';
  static const String debriefTooManyTags = 'Pick up to 4';
  static const String debriefNoteOver = 'Keep notes under 140 characters';
  static const String debriefFailed = "Couldn't save reflection. Try again.";
  static const String reflectionsTitle = 'Journal';
  static const String reflectionsEmptyTitle = 'No reflections yet';
  static const String reflectionsEmptyHint = 'Finish a session — your reflection will land here.';
  static const String reflectionsLoadError = "Couldn't load reflections.";
  static const String reflectionsNotReflected = 'Not reflected — tap to add';
  static const String reflectionsToday = 'Today';
  static const String reflectionsWeek = 'This week';
  static const String reflectionsEarlier = 'Earlier';
  static const String patternsTitle = 'Energy patterns';
  static const String patternsEmpty = 'Reflect on 5 sessions to reveal your patterns.';
  static const String patternsRetry = 'Try again';
```

- [ ] **Step 2: Write the failing widget test**

Create `test/features/session/debrief_sheet_test.dart` with exactly:

```dart
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/session_repository.dart';
import 'package:energy_clock/features/session/widgets/debrief_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSessionRepo implements SessionRepository {
  int? lastEnergy;
  int? lastFocus;
  List<String> lastTags = const [];
  String? lastNote;
  int saves = 0;
  @override
  Stream<RunningSession?> watchRunning() => const Stream.empty();
  @override
  Future<RunningSession?> runningSession() async => null;
  @override
  Future<int> start({required int eventId}) async => 1;
  @override
  Future<void> pause(int sessionId) async {}
  @override
  Future<void> resume(int sessionId) async {}
  @override
  Future<void> extend(int sessionId, {required int seconds}) async {}
  @override
  Future<SessionRecord?> finish(int sessionId) async => null;
  @override
  Future<void> abandon(int sessionId) async {}
  @override
  Future<SessionRecord?> closeOut(int sessionId) async => null;
  @override
  Future<void> saveReflection({required int sessionId, int? energyRating, int? focusRating, List<String> tags = const [], String? note}) async {
    lastEnergy = energyRating;
    lastFocus = focusRating;
    lastTags = tags;
    lastNote = note;
    saves++;
  }
}

void main() {
  testWidgets('debrief sheet saves energy focus tags and shows counter', (tester) async {
    final fake = _FakeSessionRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionRepositoryProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: Scaffold(body: DebriefSheet(sessionId: 7, eventTitle: 'Deep work', activeMinutes: 50))),
      ),
    );
    expect(find.text(Strings.debriefTitle), findsOneWidget);
    await tester.tap(find.text('4').first);
    await tester.pump();
    await tester.tap(find.text('Clear goal'));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('debrief-note')), 'Great hour');
    await tester.pump();
    await tester.tap(find.text(Strings.debriefSave));
    await tester.pumpAndSettle();
    expect(fake.saves, 1);
    expect(fake.lastEnergy, 4);
    expect(fake.lastTags, ['clear-goal']);
    expect(fake.lastNote, 'Great hour');
  });

  testWidgets('skip returns false without saving', (tester) async {
    final fake = _FakeSessionRepo();
    var result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionRepositoryProvider.overrideWithValue(fake)],
        child: MaterialApp(home: Scaffold(body: Builder(builder: (context) {
          return TextButton(onPressed: () async {
            result = await showDebriefSheet(context, FakeRef(fake), sessionId: 7, eventTitle: 'x', activeMinutes: 10);
          }, child: const Text('open'));
        }))),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.debriefSkip));
    await tester.pumpAndSettle();
    expect(fake.saves, 0);
    expect(result, isFalse);
  });
}

class FakeRef {
  FakeRef(this.repo);
  final SessionRepository repo;
  T read<T>(Object provider) => repo as T;
}
```

Note: the second test uses a simplified `FakeRef` — when implementing `showDebriefSheet`, accept `WidgetRef` in real code; the test's `showDebriefSheet` call will be adapted in Step 3 to match the real signature by wrapping in a `Consumer`. If the test does not compile, fix ONLY the test's call site to use a real `WidgetRef` via `Consumer` + `ref`, never change the production signature.

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/session/debrief_sheet_test.dart -v`
Expected: FAIL — `DebriefSheet` / `showDebriefSheet` undefined.

- [ ] **Step 4: Create lib/features/session/widgets/debrief_sheet.dart**

Exact content (no hard-coded colours, no hard-coded copy — only `Strings` + `context.appColors` + `AppSpacing`):

```dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/reflections/model/reflection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 10-second post-session debrief. Returns true if saved.
Future<bool> showDebriefSheet(
  BuildContext context,
  WidgetRef ref, {
  required int sessionId,
  required String eventTitle,
  required int activeMinutes,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DebriefSheet(sessionId: sessionId, eventTitle: eventTitle, activeMinutes: activeMinutes),
  );
  return result ?? false;
}

class DebriefSheet extends ConsumerStatefulWidget {
  const DebriefSheet({required this.sessionId, required this.eventTitle, required this.activeMinutes, super.key});

  final int sessionId;
  final String eventTitle;
  final int activeMinutes;

  @override
  ConsumerState<DebriefSheet> createState() => _DebriefSheetState();
}

class _DebriefSheetState extends ConsumerState<DebriefSheet> {
  int? _energy;
  int? _focus;
  final _tags = <String>[];
  final _note = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(sessionRepositoryProvider).saveReflection(
        sessionId: widget.sessionId,
        energyRating: _energy,
        focusRating: _focus,
        tags: _tags,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on Object {
      setState(() {
        _saving = false;
        _error = Strings.debriefFailed;
      });
    }
  }

  Widget _ratingRow({required int? value, required ValueChanged<int> onPick, required String low, required String high}) {
    return Row(
      children: [
        Text(low, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.appColors.muted)),
        const SizedBox(width: AppSpacing.sm),
        for (var i = 1; i <= 5; i++)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: ChoiceChip(
              label: Text('$i'),
              selected: value == i,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => onPick(i));
              },
            ),
          ),
        const SizedBox(width: AppSpacing.sm),
        Text(high, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.appColors.muted)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(Strings.debriefTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text('${widget.eventTitle} · ${widget.activeMinutes}m', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.appColors.muted)),
            const SizedBox(height: AppSpacing.md),
            Text(Strings.debriefEnergy, style: Theme.of(context).textTheme.labelLarge),
            _ratingRow(value: _energy, onPick: (v) => _energy = v, low: Strings.debriefEnergyLow, high: Strings.debriefEnergyHigh),
            const SizedBox(height: AppSpacing.sm),
            Text(Strings.debriefFocus, style: Theme.of(context).textTheme.labelLarge),
            _ratingRow(value: _focus, onPick: (v) => _focus = v, low: Strings.debriefFocusLow, high: Strings.debriefFocusHigh),
            const SizedBox(height: AppSpacing.sm),
            Text(Strings.debriefTags, style: Theme.of(context).textTheme.labelLarge),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final id in ReflectionTags.allIds)
                  FilterChip(
                    label: Text(ReflectionTags.labelOf(id)),
                    selected: _tags.contains(id),
                    onSelected: (on) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (on) {
                          if (_tags.length >= ReflectionTags.maxTags) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(Strings.debriefTooManyTags)));
                            return;
                          }
                          _tags.add(id);
                        } else {
                          _tags.remove(id);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('debrief-note'),
              controller: _note,
              maxLength: ReflectionTags.maxNoteLength,
              decoration: const InputDecoration(hintText: Strings.debriefNoteHint, counterText: ''),
              maxLines: 2,
              onChanged: (_) => setState(() {}),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_note.text.trim().length}/140',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _note.text.trim().length >= 130 ? context.appColors.danger : context.appColors.muted,
                ),
              ),
            ),
            if (_error != null) ...[
              Text(_error!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.appColors.danger)),
              const SizedBox(height: AppSpacing.xs),
            ],
            Row(
              children: [
                TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text(Strings.debriefSkip)),
                const Spacer(),
                FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? '…' : Strings.debriefSave)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

Fix the widget test from Step 2: the `showDebriefSheet` signature takes `WidgetRef`, so replace the second test's `Builder` with a `Consumer` that captures `ref`:

```dart
child: MaterialApp(home: Scaffold(body: Consumer(builder: (context, ref, _) {
  return TextButton(onPressed: () async {
    result = await showDebriefSheet(context, ref, sessionId: 7, eventTitle: 'x', activeMinutes: 10);
  }, child: const Text('open'));
}))),
```

And delete the `FakeRef` class at the bottom of the test file.

- [ ] **Step 5: Wire into lib/features/session/session_screen.dart**

In `_finish`, after `if (done != null) _announceLogged(messenger, done);` add:

```dart
    if (done != null && context.mounted) {
      final minutes = (done.activeSeconds / 60).round().clamp(1, 100000);
      await showDebriefSheet(context, ref, sessionId: done.id, eventTitle: session.eventTitle, activeMinutes: minutes);
    }
```

Add import at top: `import 'package:energy_clock/features/session/widgets/debrief_sheet.dart';`

In `_abandon`, after `messenger.showSnackBar(...)` add:

```dart
    if (context.mounted) {
      // Abandoned session id is session.id (abandon returns void).
      await showDebriefSheet(context, ref, sessionId: session.id, eventTitle: session.eventTitle, activeMinutes: 0);
    }
```

In `_closeOut`, after `if (done != null) _announceLogged(messenger, done);` add:

```dart
    if (done != null && context.mounted) {
      final minutes = (done.activeSeconds / 60).round().clamp(1, 100000);
      await showDebriefSheet(context, ref, sessionId: done.id, eventTitle: session.eventTitle, activeMinutes: minutes);
    }
```

- [ ] **Step 6: Run tests**

Run: `flutter test test/features/session/debrief_sheet_test.dart -v`
Expected: PASS (2 tests). If the skip test hangs on `pumpAndSettle` with bottom sheet animation, replace final `pumpAndSettle` with `pump` + `pump(const Duration(milliseconds: 300))`.

- [ ] **Step 7: Run analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/core/strings.dart lib/features/session/widgets/debrief_sheet.dart lib/features/session/session_screen.dart test/features/session/debrief_sheet_test.dart
git commit -m "feat: debrief sheet after session end with validation"
```

---

### Task 5: Reflections repository + providers

**Files:**
- Create: `lib/data/repositories/reflections_repository.dart`
- Modify: `lib/data/providers.dart` (append provider)
- Create: `lib/features/reflections/providers.dart`
- Test: `test/data/reflections_timeline_test.dart`

**Interfaces:**
- Consumes: `AppDatabase.sessionDao.endedSessions/watchEndedSessions`, `SessionDao.eventById`, `Tone.fromDbIndex`, `SessionOutcome.fromDbIndex/countsAsDone`, `ReflectionTags.decodeTags`, `ReflectionPatterns.compute`.
- Produces:
  - `typedef ReflectedSession = ({SessionRecord session, String eventTitle, Tone tone, DateTime eventDate, int startHour, bool isPostLife})`
  - `abstract interface class ReflectionsRepository { Future<List<ReflectedSession>> loadTimeline(); Stream<List<ReflectedSession>> watchTimeline(); Future<List<PatternCard>> loadPatterns(); }` (PatternCard imported from model)
  - `reflectionsRepositoryProvider`, `reflectionsTimelineProvider`, `reflectionPatternsProvider`.

- [ ] **Step 1: Write the failing test**

Create `test/data/reflections_timeline_test.dart`:

```dart
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/reflections_repository.dart';
import 'package:energy_clock/data/repositories/session_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull;

import 'session_repository_test.dart' show openTestDatabase;

Future<int> _makeEndedSession(AppDatabase db, {required String title, required int tone, required int hour}) async {
  final now = DateTime(2026, 10, 15, hour, 0);
  final eventId = await db.into(db.events).insert(
    EventsCompanion.insert(
      date: DateTime(2026, 10, 15),
      title: title,
      toneIndex: tone,
      startMinute: hour * 60,
      endMinute: hour * 60 + 60,
      createdAt: now,
      updatedAt: now,
    ),
  );
  final repo = DriftSessionRepository(db.sessionDao);
  final id = await repo.start(eventId: eventId);
  await repo.finish(id);
  return id;
}

void main() {
  test('timeline joins sessions with events newest first and decodes tags', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final id = await _makeEndedSession(db, title: 'Deep work', tone: 0, hour: 9);
    await DriftSessionRepository(db.sessionDao).saveReflection(
      sessionId: id, energyRating: 4, focusRating: 5, tags: ['flow'], note: 'hi',
    );
    final repo = DriftReflectionsRepository(db);
    final rows = await repo.loadTimeline();
    expect(rows.length, 1);
    expect(rows.single.eventTitle, 'Deep work');
    expect(rows.single.session.tags, ['flow']);
    expect(rows.single.session.note, 'hi');
  });

  test('abandoned sessions appear in timeline but not in patterns', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final sessionRepo = DriftSessionRepository(db.sessionDao);
    for (var i = 0; i < 6; i++) {
      final id = await _makeEndedSession(db, title: 'F$i', tone: 0, hour: 9);
      await sessionRepo.saveReflection(sessionId: id, energyRating: 5, focusRating: 5, tags: ['clear-goal'], note: null);
    }
    final abandonedEvent = await db.into(db.events).insert(
      EventsCompanion.insert(
        date: DateTime(2026, 10, 15), title: 'Ab', toneIndex: 0,
        startMinute: 600, endMinute: 660,
        createdAt: DateTime(2026, 10, 15), updatedAt: DateTime(2026, 10, 15),
      ),
    );
    final abId = await sessionRepo.start(eventId: abandonedEvent);
    await sessionRepo.abandon(abId);
    await sessionRepo.saveReflection(sessionId: abId, energyRating: 1, focusRating: 1, tags: const [], note: null);
    final repo = DriftReflectionsRepository(db);
    final timeline = await repo.loadTimeline();
    expect(timeline.length, 7);
    final cards = await repo.loadPatterns();
    expect(cards, isEmpty); // 6 done but split 6/0 -> withoutClear empty -> no clear-goal card
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/reflections_timeline_test.dart -v`
Expected: FAIL — `reflections_repository.dart` missing.

- [ ] **Step 3: Create lib/data/repositories/reflections_repository.dart**

Exact content:

```dart
import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:energy_clock/core/session/session_outcome.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/session_repository.dart' show SessionRecord;
import 'package:energy_clock/features/reflections/model/reflection.dart';

typedef ReflectedSession = ({
  SessionRecord session,
  String eventTitle,
  Tone tone,
  DateTime eventDate,
  int startHour,
  bool isPostLife,
});

abstract interface class ReflectionsRepository {
  Future<List<ReflectedSession>> loadTimeline();
  Stream<List<ReflectedSession>> watchTimeline();
  Future<List<PatternCard>> loadPatterns();
}

class DriftReflectionsRepository implements ReflectionsRepository {
  DriftReflectionsRepository(this._db);
  final AppDatabase _db;

  @override
  Future<List<ReflectedSession>> loadTimeline() async {
    final sessions = await _db.sessionDao.endedSessions();
    return _join(sessions);
  }

  @override
  Stream<List<ReflectedSession>> watchTimeline() async* {
    yield await loadTimeline();
    await for (final _ in _db.tableUpdates(
      TableUpdateQuery.onAllTables([_db.sessions, _db.events]),
    )) {
      yield await loadTimeline();
    }
  }

  @override
  Future<List<PatternCard>> loadPatterns() async {
    final timeline = await loadTimeline();
    final inputs = <PatternInput>[
      for (final row in timeline)
        if (row.session.outcome.countsAsDone &&
            row.session.energyRating != null &&
            row.session.focusRating != null)
          (
            tone: row.tone,
            energyRating: row.session.energyRating!,
            focusRating: row.session.focusRating!,
            tags: row.session.tags,
            startHour: row.startHour,
            isPostLife: row.isPostLife,
          ),
    ];
    return ReflectionPatterns.compute(inputs);
  }

  Future<List<ReflectedSession>> _join(List<SessionRow> sessions) async {
    final out = <ReflectedSession>[];
    // isPostLife: true when the previous ended session the same day was Life tone.
    // Computed per day in chronological order, then reversed to newest-first.
    final byDay = <String, List<SessionRow>>{};
    for (final s in sessions) {
      final event = await _db.sessionDao.eventById(s.eventId);
      if (event == null) continue;
      final key = '${event.date.year}-${event.date.month}-${event.date.day}';
      (byDay[key] ??= []).add(s);
    }
    final rows = <ReflectedSession>[];
    for (final daySessions in byDay.values) {
      daySessions.sort((a, b) => a.startedAt.compareTo(b.startedAt));
      Tone? prevTone;
      for (final s in daySessions) {
        final event = (await _db.sessionDao.eventById(s.eventId))!;
        final tone = Tone.fromDbIndex(event.toneIndex);
        final isPostLife = prevTone == Tone.life && tone == Tone.focus;
        rows.add((
          session: SessionRecord.fromRow(s),
          eventTitle: event.title,
          tone: tone,
          eventDate: event.date,
          startHour: event.startMinute ~/ 60,
          isPostLife: isPostLife,
        ));
        prevTone = tone;
      }
    }
    rows.sort((a, b) => b.session.endedAt!.compareTo(a.session.endedAt!));
    return rows;
  }
}
```

Note: `_join` calls `eventById` twice per session (once for grouping, once for row). Keep as-is for v1 clarity; the per-event loop matches `DriftProjectRepository._loadDetail` precedent. Do NOT optimize.

- [ ] **Step 4: Add provider in lib/data/providers.dart**

Append after `projectRepositoryProvider` block:

```dart
/// Post-session debriefs timeline + patterns (Reflections feature).
final reflectionsRepositoryProvider = Provider<ReflectionsRepository>((ref) {
  return DriftReflectionsRepository(ref.watch(appDatabaseProvider));
});
```

Add import at top: `import 'package:energy_clock/data/repositories/reflections_repository.dart';`

- [ ] **Step 5: Create lib/features/reflections/providers.dart**

Exact content:

```dart
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/reflections_repository.dart';
import 'package:energy_clock/features/reflections/model/reflection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final reflectionsTimelineProvider = StreamProvider<List<ReflectedSession>>((ref) {
  return ref.watch(reflectionsRepositoryProvider).watchTimeline();
});

final reflectionPatternsProvider = StreamProvider<List<PatternCard>>((ref) {
  return ref.watch(reflectionsRepositoryProvider).watchTimeline().map((timeline) {
    final inputs = <PatternInput>[
      for (final row in timeline)
        if (row.session.outcome.countsAsDone &&
            row.session.energyRating != null &&
            row.session.focusRating != null)
          (
            tone: row.tone,
            energyRating: row.session.energyRating!,
            focusRating: row.session.focusRating!,
            tags: row.session.tags,
            startHour: row.startHour,
            isPostLife: row.isPostLife,
          ),
    ];
    return ReflectionPatterns.compute(inputs);
  });
});
```

- [ ] **Step 6: Run tests**

Run: `flutter test test/data/reflections_timeline_test.dart -v`
Expected: PASS. If second test expectation fails (cards not empty because 6 clear-goal vs 0 without yields no card by design), keep as-is — it documents abandoned-excluded rule.

- [ ] **Step 7: Analyze + commit**

Run: `flutter analyze` → `No issues found!`

```bash
git add lib/data/repositories/reflections_repository.dart lib/data/providers.dart lib/features/reflections/providers.dart test/data/reflections_timeline_test.dart
git commit -m "feat: reflections repository and timeline providers"
```

---

### Task 6: Journal timeline screen + row widget

**Files:**
- Create: `lib/features/reflections/widgets/reflection_row.dart`
- Create: `lib/features/reflections/reflections_screen.dart`
- Test: `test/features/reflections/reflections_screen_test.dart`

**Interfaces:**
- Consumes: `reflectionsTimelineProvider`, `ReflectionTags.labelOf`, `Strings.reflections*`, `context.appColors`, `context.toneColors`.
- Produces: `ReflectionsScreen()` (no args, `ConsumerWidget`), `ReflectionRowTile({required ReflectedSession item, required VoidCallback onTap})`.

- [ ] **Step 1: Write the failing test**

Create `test/features/reflections/reflections_screen_test.dart`:

```dart
import 'package:energy_clock/core/session/session_outcome.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/repositories/session_repository.dart';
import 'package:energy_clock/features/reflections/providers.dart';
import 'package:energy_clock/features/reflections/reflections_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ReflectedRowForTest row({required String title, int? energy}) {
  throw UnimplementedError('replaced in Step 3 by real ReflectedSession');
}

void main() {
  testWidgets('empty timeline shows empty hint', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reflectionsTimelineProvider.overrideWith((ref) => Stream.value(const []))],
        child: const MaterialApp(home: ReflectionsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No reflections yet'), findsOneWidget);
  });
}
```

Note: this test intentionally references a helper that does not exist yet to force RED. In Step 3 you will replace the whole test file with the final version below (which uses real `ReflectedSession` records) — keep the empty-state test identical.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/reflections/reflections_screen_test.dart -v`
Expected: FAIL — `ReflectionsScreen` undefined.

- [ ] **Step 3: Create reflection_row.dart then reflections_screen.dart, then fix test**

Create `lib/features/reflections/widgets/reflection_row.dart` exactly:

```dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/repositories/reflections_repository.dart';
import 'package:energy_clock/features/reflections/model/reflection.dart';
import 'package:flutter/material.dart';

class ReflectionRowTile extends StatelessWidget {
  const ReflectionRowTile({required this.item, required this.onTap, super.key});

  final ReflectedSession item;
  final VoidCallback onTap;

  Widget _dots(BuildContext context, int? value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value != null && i <= value
                  ? context.toneColors.paletteFor(item.tone).solid
                  : context.appColors.track,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = item.session;
    final reflected = s.energyRating != null || s.focusRating != null;
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.toneColors.paletteFor(item.tone).solid,
        ),
      ),
      title: Text(item.eventTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${(s.activeSeconds / 60).round()}m · ${item.tone.label}'),
          const SizedBox(height: 2),
          if (!reflected)
            Text(Strings.reflectionsNotReflected, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.appColors.muted))
          else ...[
            Row(children: [const Text('E '), _dots(context, s.energyRating), const SizedBox(width: AppSpacing.sm), const Text('F '), _dots(context, s.focusRating)]),
            if (s.tags.isNotEmpty)
              Wrap(
                spacing: 4,
                children: [for (final t in s.tags) Chip(label: Text(ReflectionTags.labelOf(t)), visualDensity: VisualDensity.compact)],
              ),
            if (s.note != null && s.note!.isNotEmpty)
              Text(s.note!, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}
```

Create `lib/features/reflections/reflections_screen.dart` exactly:

```dart
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/features/reflections/providers.dart';
import 'package:energy_clock/features/reflections/widgets/reflection_row.dart';
import 'package:energy_clock/features/session/widgets/debrief_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReflectionsScreen extends ConsumerWidget {
  const ReflectionsScreen({super.key});

  String _groupOf(DateTime date, DateTime now) {
    final a = DateTime(now.year, now.month, now.day);
    final b = DateTime(date.year, date.month, date.day);
    final diff = a.difference(b).inDays;
    if (diff <= 0) return Strings.reflectionsToday;
    if (diff < 7) return Strings.reflectionsWeek;
    return Strings.reflectionsEarlier;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = ref.watch(reflectionsTimelineProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.reflectionsTitle)),
      body: timeline.when(
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(Strings.reflectionsEmptyTitle, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(Strings.reflectionsEmptyHint, textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }
          final now = DateTime.now();
          var lastGroup = '';
          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final item = rows[i];
              final group = _groupOf(item.eventDate, now);
              final showHeader = group != lastGroup;
              lastGroup = group;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showHeader)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                      child: Text(group, style: Theme.of(context).textTheme.labelLarge),
                    ),
                  ReflectionRowTile(
                    item: item,
                    onTap: () async {
                      final minutes = (item.session.activeSeconds / 60).round().clamp(1, 100000);
                      await showDebriefSheet(context, ref, sessionId: item.session.id, eventTitle: item.eventTitle, activeMinutes: minutes);
                    },
                  ),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(Strings.reflectionsLoadError, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  onPressed: () => ref.invalidate(reflectionsTimelineProvider),
                  child: const Text(Strings.patternsRetry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

Replace the test file from Step 1 with the final version (keep empty test, add rows test). Overwrite `test/features/reflections/reflections_screen_test.dart` with:

```dart
import 'package:energy_clock/core/session/session_outcome.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/repositories/reflections_repository.dart';
import 'package:energy_clock/data/repositories/session_repository.dart';
import 'package:energy_clock/features/reflections/providers.dart';
import 'package:energy_clock/features/reflections/reflections_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ReflectedSession _row({required String title, int? energy, List<String> tags = const [], String? note}) {
  final now = DateTime(2026, 10, 15, 10, 0);
  return (
    session: SessionRecord(
      id: 1, eventId: 1, startedAt: now, endedAt: now,
      plannedSeconds: 3600, pausedSeconds: 0, pauseStartedAt: null,
      activeSeconds: 3000, overtimeSeconds: 0, outcome: SessionOutcome.completed,
      energyRating: energy, focusRating: energy == null ? null : 4, tags: tags, note: note,
    ),
    eventTitle: title, tone: Tone.focus, eventDate: DateTime(2026, 10, 15), startHour: 9, isPostLife: false,
  );
}

void main() {
  testWidgets('empty timeline shows empty hint', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reflectionsTimelineProvider.overrideWith((ref) => Stream.value(const []))],
        child: const MaterialApp(home: ReflectionsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No reflections yet'), findsOneWidget);
  });

  testWidgets('rows render title tags and note', (tester) async {
    final rows = [_row(title: 'Deep work', energy: 4, tags: ['flow'], note: 'Great hour')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reflectionsTimelineProvider.overrideWith((ref) => Stream.value(rows))],
        child: const MaterialApp(home: ReflectionsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Deep work'), findsOneWidget);
    expect(find.text('Flow'), findsOneWidget);
    expect(find.text('Great hour'), findsOneWidget);
  });
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/reflections/reflections_screen_test.dart -v`
Expected: PASS (2 tests).

- [ ] **Step 5: Analyze + commit**

Run: `flutter analyze` → `No issues found!`

```bash
git add lib/features/reflections/widgets/reflection_row.dart lib/features/reflections/reflections_screen.dart test/features/reflections/reflections_screen_test.dart
git commit -m "feat: journal timeline screen with groups and edit"
```

---

### Task 7: Stats 5th section (Energy patterns card)

**Files:**
- Create: `lib/features/reflections/widgets/patterns_card.dart`
- Modify: `lib/features/stats/stats_screen.dart:37-117` (`_StatsBody`)
- Test: extend `test/features/reflections/reflections_screen_test.dart` OR create `test/features/reflections/patterns_card_test.dart` (create new file)

**Interfaces:**
- Consumes: `reflectionPatternsProvider`, `StatsSectionCard`, `Strings.patterns*`.
- Produces: `EnergyPatternsCard()` (no args).

- [ ] **Step 1: Write the failing test**

Create `test/features/reflections/patterns_card_test.dart`:

```dart
import 'package:energy_clock/features/reflections/model/reflection.dart';
import 'package:energy_clock/features/reflections/providers.dart';
import 'package:energy_clock/features/reflections/widgets/patterns_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty patterns shows needs-5 message', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reflectionPatternsProvider.overrideWith((ref) => Stream.value(const []))],
        child: const MaterialApp(home: Scaffold(body: EnergyPatternsCard())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reflect on 5 sessions to reveal your patterns.'), findsOneWidget);
  });

  testWidgets('cards render title and detail', (tester) async {
    const cards = [(title: 'Clear goal → +1.5 focus', detail: 'd', delta: 1.5, sampleSize: 12)];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reflectionPatternsProvider.overrideWith((ref) => Stream.value(cards))],
        child: const MaterialApp(home: Scaffold(body: EnergyPatternsCard())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Clear goal → +1.5 focus'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/reflections/patterns_card_test.dart -v`
Expected: FAIL — `EnergyPatternsCard` undefined.

- [ ] **Step 3: Create lib/features/reflections/widgets/patterns_card.dart**

Exact content:

```dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/reflections/providers.dart';
import 'package:energy_clock/features/stats/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EnergyPatternsCard extends ConsumerWidget {
  const EnergyPatternsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patterns = ref.watch(reflectionPatternsProvider);
    return patterns.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      data: (cards) {
        final empty = cards.isEmpty;
        return StatsSectionCard(
          title: Strings.patternsTitle,
          empty: empty,
          emptyMessage: Strings.patternsEmpty,
          semanticsLabel: empty ? Strings.patternsEmpty : 'Energy patterns: ${cards.map((c) => c.title).join(', ')}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final card in cards) ...[
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: card.delta >= 0 ? context.appColors.success : context.appColors.danger,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(card.title, style: Theme.of(context).textTheme.titleSmall),
                          Text(
                            '${card.detail}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.appColors.muted),
                          ),
                        ],
                      ),
                    ),
                    Text('n=${card.sampleSize}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.appColors.muted)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        );
      },
      loading: () => const StatsSectionCard(
        title: Strings.patternsTitle,
        empty: true,
        emptyMessage: Strings.patternsEmpty,
        semanticsLabel: Strings.patternsEmpty,
        child: SizedBox.shrink(),
      ),
      error: (e, st) => StatsSectionCard(
        title: Strings.patternsTitle,
        empty: true,
        emptyMessage: Strings.reflectionsLoadError,
        semanticsLabel: Strings.reflectionsLoadError,
        child: const SizedBox.shrink(),
      ),
    );
  }
}
```

Note: `context.appColors.success` must exist — open `lib/app/theme/app_colors.dart` first. If the success token is named differently (e.g. `positive`, `ok`, `green`), replace BOTH occurrences (`success`) with the exact name found. If no green token exists, use `context.toneColors.paletteFor` Life tone's solid for positive and `context.appColors.danger` for negative — check `lib/app/theme/tone_colors.dart` for the exact accessor (`paletteFor(Tone.life).solid` as used in `reflection_row.dart`).

- [ ] **Step 4: Wire into lib/features/stats/stats_screen.dart**

Add import: `import 'package:energy_clock/features/reflections/widgets/patterns_card.dart';`

In `_StatsBody.build`, after `final heatmap = HeatmapCard(...)` add:

```dart
    const patterns = EnergyPatternsCard(key: ValueKey('stats-patterns'));
```

In twoColumn branch, after the second `Row` (depth+heatmap), add:

```dart
              gap(),
              patterns,
```

In single-column branch, after `heatmap,` add:

```dart
              gap(),
              patterns,
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/reflections/patterns_card_test.dart test/features/stats/ -v`
Expected: PASS. Existing stats tests must still pass.

- [ ] **Step 6: Analyze + commit**

Run: `flutter analyze` → `No issues found!`

```bash
git add lib/features/reflections/widgets/patterns_card.dart lib/features/stats/stats_screen.dart test/features/reflections/patterns_card_test.dart
git commit -m "feat: stats energy patterns fifth section"
```

---

### Task 8: Profile card + export + Stats header entry point

**Files:**
- Create: `lib/features/progress/widgets/reflections_card.dart`
- Modify: `lib/features/progress/profile_screen.dart:88-94` (insert after ProjectsCard)
- Modify: `lib/features/stats/stats_screen.dart` (PeriodHeader trailing → Journal button) OR `lib/features/stats/widgets/period_header.dart` (add trailing param)
- Modify: `lib/data/repositories/export_repository.dart` (only if it selects explicit session columns — check first)
- Test: `test/features/progress/reflections_card_test.dart`

**Interfaces:**
- Consumes: `reflectionsTimelineProvider`, `reflectionPatternsProvider`, `ReflectionsScreen`, `Strings.reflectionsTitle`.
- Produces: `ReflectionsCard()` (no args).

- [ ] **Step 1: Check export_repository for explicit session columns**

Open `lib/data/repositories/export_repository.dart` and search for `sessions` or `select(`. If it does `select(db.sessions).get()` or `select(db.events).get()` with no explicit column list, NO CHANGE needed — new columns export automatically. If it lists columns explicitly (e.g. `sessions.id, sessions.eventId, ...`), add `sessions.energyRating, sessions.focusRating, sessions.tagsCsv, sessions.note` to that list. Record your finding in the commit message.

- [ ] **Step 2: Write the failing test**

Create `test/features/progress/reflections_card_test.dart`:

```dart
import 'package:energy_clock/features/progress/widgets/reflections_card.dart';
import 'package:energy_clock/features/reflections/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reflections card opens journal', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reflectionsTimelineProvider.overrideWith((ref) => Stream.value(const [])),
          reflectionPatternsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(home: Scaffold(body: ReflectionsCard())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Journal'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `flutter test test/features/progress/reflections_card_test.dart -v`
Expected: FAIL — `ReflectionsCard` undefined.

- [ ] **Step 4: Create lib/features/progress/widgets/reflections_card.dart**

Mirror `projects_card.dart` structure exactly:

```dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/reflections/providers.dart';
import 'package:energy_clock/features/reflections/reflections_screen.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Profile teaser for Reflections: reflected count + top pattern → opens journal.
/// Hidden while loading or on error, so a reflections hiccup never breaks Profile.
class ReflectionsCard extends ConsumerWidget {
  const ReflectionsCard({super.key});

  void _openJournal(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ReflectionsScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = ref.watch(reflectionsTimelineProvider);
    final patterns = ref.watch(reflectionPatternsProvider);
    return timeline.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      skipError: true,
      data: (rows) {
        final reflected = rows.where((r) => r.session.energyRating != null || r.session.focusRating != null).length;
        final top = patterns.valueOrNull?.isNotEmpty == true ? patterns.valueOrNull!.first.title : null;
        return AppCard(
          onTap: () => _openJournal(context),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(Strings.reflectionsTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              if (reflected == 0)
                Text(
                  Strings.reflectionsEmptyHint,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.appColors.muted),
                )
              else ...[
                Text('$reflected reflected', style: Theme.of(context).textTheme.bodyMedium),
                if (top != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(top, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.appColors.muted)),
                ],
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
    );
  }
}
```

- [ ] **Step 5: Insert into lib/features/progress/profile_screen.dart**

Add import: `import 'package:energy_clock/features/progress/widgets/reflections_card.dart';`

After:

```dart
            const ProjectsCard(),
            const SizedBox(height: AppSpacing.lg),
```

Insert:

```dart
            const ReflectionsCard(),
            const SizedBox(height: AppSpacing.lg),
```

- [ ] **Step 6: Add Journal entry point to Stats**

Open `lib/features/stats/widgets/period_header.dart`. If it already accepts a `trailing` widget, pass a `TextButton` that pushes `ReflectionsScreen`. If not, wrap `PeriodHeader` in `_StatsBody` with a `Row`:

In `lib/features/stats/stats_screen.dart`, replace `const PeriodHeader(),` with:

```dart
            Row(
              children: [
                const Expanded(child: PeriodHeader()),
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ReflectionsScreen()));
                  },
                  child: const Text(Strings.reflectionsTitle),
                ),
              ],
            ),
```

Add imports: `import 'package:energy_clock/features/reflections/reflections_screen.dart';` and `import 'package:energy_clock/core/strings.dart';` (strings already imported — do NOT duplicate).

- [ ] **Step 7: Run tests**

Run: `flutter test test/features/progress/reflections_card_test.dart test/features/reflections/ -v`
Expected: PASS.

- [ ] **Step 8: Analyze + commit**

Run: `flutter analyze` → `No issues found!`

```bash
git add lib/features/progress/widgets/reflections_card.dart lib/features/progress/profile_screen.dart lib/features/stats/stats_screen.dart lib/data/repositories/export_repository.dart test/features/progress/reflections_card_test.dart
git commit -m "feat: profile reflections card and stats journal entry"
```

---

### Task 9: Full regression (migration, DAO, color, suite)

**Files:**
- Test only: run existing suites, fix regressions. No new production code unless a regression demands it.

- [ ] **Step 1: Run the color gate**

Run: `flutter test test/architecture/no_hardcoded_colors_test.dart -v`
Expected: PASS. If FAIL with a file path (e.g. `debrief_sheet.dart:42 Color(0xFF...)`), open that file and replace the literal with `context.appColors.*` or `context.toneColors.paletteFor(...).solid` — never suppress the test.

- [ ] **Step 2: Run the full data + reflections + session + stats + progress suites**

Run: `flutter test test/data/ test/features/reflections/ test/features/session/ test/features/stats/ test/features/progress/ test/core/strings_test.dart -v`
Expected: PASS all. If any pre-existing test fails because `SessionRecord` gained fields (e.g. `expect(record, SessionRecord(...))` without the new optional params), update ONLY that test's expected constructor call to include `energyRating: null, focusRating: null, tags: const [], note: null` — never change production defaults to satisfy a test.

- [ ] **Step 3: Run analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Run the FULL suite**

Run: `flutter test -v`
Expected: PASS (180+ tests, now 190+). Note the count. If golden tests fail (`dial_golden_test.dart`), do NOT run `--update-goldens` — reflections must not change dial pixels. Investigate: you likely imported reflections into clock painter by mistake.

- [ ] **Step 5: Manual smoke (simulator, 5 minutes)**

Run: `flutter run` on iPhone 17 Pro simulator. Steps: plan 15m Focus event → Start session → Finish → debrief sheet appears → pick Energy 4, Focus 5, tag Clear goal, note `test` → Save → snackbar `Reflection saved.` → Stats shows Energy patterns needs-5 → repeat 5x → pattern card appears → Profile shows Reflections card → tap → Journal timeline grouped → tap row → edit reopens with saved values. If any step throws, fix before committing.

- [ ] **Step 6: Commit (only if Step 5 passed or no prod change was needed)**

```bash
git add -A
git commit -m "test: reflections regression green" --allow-empty
```

If there were zero changes (suite already green), the `--allow-empty` keeps history explicit. If you fixed files, drop `--allow-empty` and list them explicitly.

---

## Self-Review (run before handoff)

- Spec §1 schema v6→v7 → Task 1 (columns + migration + dump + tests).
- Spec §1 pure tags/patterns → Task 2 (allIds, max 4/140, minSample 5, three card types).
- Spec §2 debrief sheet (energy/focus/tags/note, Save/Skip, <10s, abandoned prompts) → Task 4 (sheet + wiring finish/abandon/closeOut).
- Spec §2 timeline (Today/Week/Earlier, tone dot, mini-bars, pills, preview, empty/error/retry, edit) → Task 6.
- Spec §2 patterns cards (needs-5, sample size, Why detail) → Task 7.
- Spec §2 entry points (Stats Journal button + Profile card, no new tab) → Task 8.
- Spec §3 data flow (updateReflection follow-up write, skip=nulls, client aggregator, no second scoring, export/reset) → Tasks 3+5+8-Step-1.
- Spec §4 validation/edge (optional ratings, max-4 guard, 140 cap+counter red at 130, write-failure snackbar+preserve, abandoned excluded from patterns but in timeline, editable-anytime, flights as Inbox) → Tasks 3+4+5.
- Spec §5 testing (analyze/test gates, no goldens, pure/DAO/notifier/widget/regression) → Tasks 1-9 each end with analyze+commit; Task 9 runs color gate + full suite.
- Spec §6 review story (durable user content, data-driven cards, privacy note, zero new permissions) → no code task; covered by screenshots in Task 9 Step 5.
- No placeholders: every step has exact file paths, complete code blocks, exact `flutter` commands with expected output. No TBD/TODO.
- Type consistency: `energyRating/focusRating int?`, `tags List<String>`, `note String?`, `tagsCsv String?`, `PatternInput/PatternCard/ReflectedSession` typedefs spelled identically in Tasks 2/3/5/6/7.
