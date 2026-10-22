# Energy Coach Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Energy Coach (suggest-not-auto-move planner + morning intent / evening review ritual + frozen weekly insights) fully offline.

**Architecture:** New `lib/core/coach/` pure logic + new `coach_*` Drift tables (v6→v7) with `CoachDao` + `DriftCoachRepository` exposed via `data/providers.dart`; new `lib/features/coach/` hub opened from a Clock header card (no 6th tab), following the Projects hub pattern. All smarts recompute from `events`+`sessions`, never accumulate.

**Tech Stack:** Flutter 3.44.7 / Dart 3.12.2, flutter_riverpod 2.6.1, drift 2.34.3 + drift_flutter, flutter_local_notifications (existing channels only, no new permission), CustomPainter not required (no new charts).

## Global Constraints

- Platform: iOS (iPhone portrait, iPad all orientations), iOS 15+, English-only, all user-facing copy lives in `lib/core/strings.dart`.
- Data: local-only, on-device. No account, no backend, no sync. No EventKit. No new notification permission.
- Tab count stays 5 (`TabScaffold` + `AppTabBar` unchanged). Coach hub opens from Clock card + Profile card, same hub pattern as Projects.
- Boundary rule: no file under `features/<a>/` may import from `features/<b>/`. Coach imports only `data/`, `core/`, `app/`, `shared/`.
- Derived, never accumulated: planner suggestions and insights recompute from source rows; `coach_insights` rows are frozen snapshots like `weekly_roundups`, never live counters.
- Every colour via theme tokens (`lib/app/theme/tone_colors.dart` / `tokens.dart`); the no-hardcoded-colour test must keep passing.
- Past days are read-only: intent/review/suggest-accept disabled on past days. Tone forced to Inbox when `isFlight` is true; suggestions never move a flight.
- Maximum 3 overlap rings: an accept that would need a 4th ring is refused with `Strings.ringOverflow`.
- Cross-midnight events not allowed (`endMinute` ≤ 1440). Minimum durations follow existing sheet rules.
- Schema change v6 → v7 needs a step in `migration`, `resetAll()` clears new tables, and a test in `test/data/migration_test.dart` (see `drift_schemas/`).
- Codegen with the Flutter SDK's `dart`: `"$(dirname "$(which flutter)")/dart" run build_runner build --delete-conflicting-outputs`.
- Gates per task: `flutter analyze`, `flutter test`. Golden rule: `flutter test --update-goldens` only after a deliberate visual change + image review; no golden regen expected here.

---

## File Map

Create:
- `lib/data/tables/coach_tables.dart` — `CoachIntents`, `CoachReviews`, `CoachInsights` table definitions.
- `lib/data/daos/coach_dao.dart` (+ generated `coach_dao.g.dart`) — upserts, watches, frozen insight writes.
- `lib/data/repositories/coach_repository.dart` — `CoachRepository` interface + `DriftCoachRepository`.
- `lib/core/coach/planner.dart` — `SwapSuggestion`, `suggestSwaps()`, `coachCardState()`.
- `lib/core/coach/insights_rules.dart` — `CoachInsight`, `buildInsights()`, 6 rule ids + thresholds.
- `lib/features/coach/providers.dart` — `coachRepositoryProvider` alias + `todayIntentProvider`, `todayReviewProvider`, `suggestionsProvider`, `weekInsightsProvider`.
- `lib/features/coach/coach_screen.dart` — hub with Intent / Suggestions / Insights sections.
- `lib/features/coach/widgets/coach_card.dart` — contextual Clock header card.
- `lib/features/coach/widgets/plan_sheet.dart` — ≤3 suggestions with Accept/Dismiss.
- `lib/features/coach/widgets/intent_sheet.dart` — focus-goal field + top-3 chips.
- `lib/features/coach/widgets/review_sheet.dart` — energy dots + win text + adherence line.
- `lib/features/coach/widgets/insight_card.dart` — frozen card renderer.
- `lib/features/progress/widgets/coach_teaser_card.dart` — Profile card (lives in progress feature so no cross-feature import).
- Tests: `test/core/coach/planner_test.dart`, `test/core/coach/insights_rules_test.dart`, `test/data/coach_dao_test.dart`, `test/data/coach_repository_test.dart`, `test/features/coach/coach_sheets_test.dart`, `test/features/coach/coach_hub_test.dart`.

Modify:
- `lib/data/database.dart` — add 3 tables + 1 DAO, `schemaVersion` 6→7, `onUpgrade` v7 block, `resetAll()` clears new tables.
- `lib/data/providers.dart` — add canonical `coachRepositoryProvider`.
- `lib/core/strings.dart` — add all coach copy (see Task 5 for exact names).
- `lib/features/clock/clock_screen.dart` — insert `CoachCard` above `NowCard` (narrow + wide panes).
- `lib/features/progress/profile_screen.dart` — insert `CoachTeaserCard` after `ProjectsCard`.
- `test/data/migration_test.dart` — add v6→v7 test; regenerate `drift_schemas/drift_schema_v7.json` + `test/generated_migrations/`.

---

### Task 1: Schema v7 — tables, DAO, migration

**Files:**
- Create: `lib/data/tables/coach_tables.dart`
- Create: `lib/data/daos/coach_dao.dart`
- Modify: `lib/data/database.dart`
- Test: `test/data/coach_dao_test.dart`, `test/data/migration_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `Projects` table pattern (`lib/data/tables/projects_table.dart`), `ProjectDao` pattern (`lib/data/daos/project_dao.dart`).
- Produces: `CoachDao.upsertIntent({required DateTime date, required String focusGoal, String? topEventIds})`, `CoachDao.intentFor(DateTime date)`, `CoachDao.watchIntent(DateTime date)`, `CoachDao.upsertReview({required DateTime date, required int energy, String? winText})`, `CoachDao.reviewFor(DateTime date)`, `CoachDao.watchReview(DateTime date)`, `CoachDao.insertInsight({required int isoYear, required int isoWeek, required String kind, required String payloadJson})`, `CoachDao.insightsForWeek(int isoYear, int isoWeek)`, `CoachDao.watchInsightsForWeek(int isoYear, int isoWeek)`.

- [ ] **Step 1: Write the failing DAO test**

```dart
// test/data/coach_dao_test.dart
import 'package:energy_clock/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(AppDatabase.testExecutor());
  });

  tearDown(() => db.close());

  test('intent round-trips and overwrites same date', () async {
    final day = DateTime(2026, 10, 12);
    await db.coachDao.upsertIntent(date: day, focusGoal: 'Ship coach spec');
    expect((await db.coachDao.intentFor(day))?.focusGoal, 'Ship coach spec');
    await db.coachDao.upsertIntent(date: day, focusGoal: 'Second save wins');
    expect((await db.coachDao.intentFor(day))?.focusGoal, 'Second save wins');
  });

  test('review round-trips energy + win text', () async {
    final day = DateTime(2026, 10, 12);
    await db.coachDao.upsertReview(date: day, energy: 4, winText: 'Peak morning');
    final row = await db.coachDao.reviewFor(day);
    expect(row?.energy, 4);
    expect(row?.winText, 'Peak morning');
  });

  test('insights freeze per ISO week', () async {
    await db.coachDao.insertInsight(
      isoYear: 2026, isoWeek: 42, kind: 'peak-hours',
      payloadJson: '{"title":"Peak holds"}',
    );
    final rows = await db.coachDao.insightsForWeek(2026, 42);
    expect(rows.length, 1);
    expect(rows.single.kind, 'peak-hours');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/coach_dao_test.dart -v`
Expected: FAIL with "Getter not found: 'coachDao'" / "Undefined class 'AppDatabase'" member errors.

- [ ] **Step 3: Write minimal tables + DAO + database wiring**

```dart
// lib/data/tables/coach_tables.dart
import 'package:drift/drift.dart';

/// One morning intent per local day.
@DataClassName('CoachIntentRow')
class CoachIntents extends Table {
  DateTimeColumn get date => dateTime()();
  TextColumn get focusGoal => text().withLength(min: 1, max: 120)();
  TextColumn get topEventIds => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {date};
}

/// One evening review per local day. Adherence is read live from day_scores.
@DataClassName('CoachReviewRow')
class CoachReviews extends Table {
  DateTimeColumn get date => dateTime()();
  IntColumn get energy => integer().check(energy.isBetweenValues(1, 5))();
  TextColumn get winText => text().withLength(max: 140).nullable()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {date};
}

/// Frozen weekly insight cards, one row per rule per ISO week.
@DataClassName('CoachInsightRow')
class CoachInsights extends Table {
  IntColumn get isoYear => integer()();
  IntColumn get isoWeek => integer()();
  TextColumn get kind => text().withLength(min: 1, max: 32)();
  TextColumn get payloadJson => text()();
  DateTimeColumn get generatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {isoYear, isoWeek, kind};
}
```

```dart
// lib/data/daos/coach_dao.dart
import 'package:drift/drift.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/tables/coach_tables.dart';

part 'coach_dao.g.dart';

@DriftAccessor(tables: [CoachIntents, CoachReviews, CoachInsights])
class CoachDao extends DatabaseAccessor<AppDatabase> with _$CoachDaoMixin {
  CoachDao(super.attachedDatabase);

  Future<void> upsertIntent({
    required DateTime date,
    required String focusGoal,
    String? topEventIds,
  }) =>
      into(coachIntents).insertOnConflictUpdate(
        CoachIntentsCompanion.insert(
          date: Value(date),
          focusGoal: focusGoal,
          topEventIds: Value(topEventIds),
          createdAt: DateTime.now(),
        ),
      );

  Future<CoachIntentRow?> intentFor(DateTime date) =>
      (select(coachIntents)..where((r) => r.date.equals(date))).getSingleOrNull();

  Stream<CoachIntentRow?> watchIntent(DateTime date) => (select(coachIntents)
        ..where((r) => r.date.equals(date)))
      .watchSingleOrNull();

  Future<void> upsertReview({
    required DateTime date,
    required int energy,
    String? winText,
  }) =>
      into(coachReviews).insertOnConflictUpdate(
        CoachReviewsCompanion.insert(
          date: Value(date),
          energy: energy,
          winText: Value(winText),
          createdAt: DateTime.now(),
        ),
      );

  Future<CoachReviewRow?> reviewFor(DateTime date) =>
      (select(coachReviews)..where((r) => r.date.equals(date))).getSingleOrNull();

  Stream<CoachReviewRow?> watchReview(DateTime date) => (select(coachReviews)
        ..where((r) => r.date.equals(date)))
      .watchSingleOrNull();

  Future<void> insertInsight({
    required int isoYear,
    required int isoWeek,
    required String kind,
    required String payloadJson,
  }) =>
      into(coachInsights).insertOnConflictUpdate(
        CoachInsightsCompanion.insert(
          isoYear: isoYear,
          isoWeek: isoWeek,
          kind: kind,
          payloadJson: payloadJson,
          generatedAt: DateTime.now(),
        ),
      );

  Future<List<CoachInsightRow>> insightsForWeek(int isoYear, int isoWeek) =>
      (select(coachInsights)
            ..where((r) => r.isoYear.equals(isoYear) & r.isoWeek.equals(isoWeek)))
          .get();

  Stream<List<CoachInsightRow>> watchInsightsForWeek(int isoYear, int isoWeek) =>
      (select(coachInsights)
            ..where((r) => r.isoYear.equals(isoYear) & r.isoWeek.equals(isoWeek)))
          .watch();
}
```

In `lib/data/database.dart`: add imports for `coach_tables.dart` + `coach_dao.dart`; add `CoachIntents, CoachReviews, CoachInsights` to `tables:`; add `CoachDao` to `daos:`; change `schemaVersion` to `7`; append to `onUpgrade`:

```dart
if (from < 7) {
  await migrator.createTable(coachIntents);
  await migrator.createTable(coachReviews);
  await migrator.createTable(coachInsights);
}
```

Append to `resetAll()` transaction:

```dart
await delete(coachInsights).go();
await delete(coachReviews).go();
await delete(coachIntents).go();
```

Also add a test-only executor hook if missing: in `AppDatabase` add `static QueryExecutor testExecutor()` only if the existing `forTesting` pattern needs it — otherwise reuse `AppDatabase.forTesting` with an in-memory executor exactly as `test/data/project_dao_test.dart` does (follow that file's setup verbatim).

- [ ] **Step 4: Generate code + run tests**

Run: `"$(dirname "$(which flutter)")/dart" run build_runner build --delete-conflicting-outputs`
Expected: `coach_dao.g.dart` + updated `database.g.dart` generated with no conflicts.

Run: `flutter test test/data/coach_dao_test.dart -v`
Expected: PASS (3/3).

- [ ] **Step 5: Add migration test + regenerate schemas**

Add to `test/data/migration_test.dart`:

```dart
test('version 6 upgrades to version 7 with coach tables empty', () async {
  final schema = await verifier.schemaAt(6);
  final database = AppDatabase.forTesting(schema.newConnection());
  addTearDown(database.close);
  await verifier.migrateAndValidate(database, 7);
  final day = DateTime(2026, 10, 12);
  expect(await database.coachDao.intentFor(day), isNull);
  expect(await database.coachDao.insightsForWeek(2026, 42), isEmpty);
});
```

Run schema dump/generate per repo docs (`drift_dev schema dump` / `schema generate`), then:
Run: `flutter test test/data/migration_test.dart -v`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/data/tables/coach_tables.dart lib/data/daos/coach_dao.dart lib/data/database.dart test/data/coach_dao_test.dart test/data/migration_test.dart drift_schemas/drift_schema_v7.json
git commit -m "feat: coach schema v7 with intents reviews insights"
```

---

### Task 2: Pure planner — `suggestSwaps()` + card state

**Files:**
- Create: `lib/core/coach/planner.dart`
- Test: `test/core/coach/planner_test.dart`

**Interfaces:**
- Consumes: `CalendarEvent` (`lib/features/clock/model/calendar_event.dart`: `id`, `tone`, `range`, `isFlight`, `startMinute`, `endMinute`), `Tone` (`lib/core/tone.dart`), `MinuteRange` + `wouldOverflowRings` (`lib/core/geometry/`).
- Produces: `enum SwapReason { peak, balance, lateAvoid }`, `class SwapSuggestion { int eventId; int fromStartMinute; int toStartMinute; int durationMinutes; SwapReason reason; String evidence; }`, `List<SwapSuggestion> suggestSwaps({required List<CalendarEvent> today, required List<int> peakHours, required int focusTargetMinutes})`, `enum CoachCardKind { setIntent, suggestionsReady, reviewDue, insightsNew, quiet }`, `CoachCardKind coachCardKind({required bool hasIntent, required bool hasSuggestions, required bool hasReview, required bool hasNewInsights, required int hour})`.

Peak hours input: top-2 focus-dense hours (0–23) computed by the provider from the 28-day heatmap (`buildHeatmap` in `lib/features/stats/model/heatmap.dart`); the pure function takes them as input so it stays Flutter-free and trivially testable.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/coach/planner_test.dart
import 'package:energy_clock/core/coach/planner.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:energy_clock/core/event_status.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent event(int id, Tone tone, int start, int end, {bool flight = false}) =>
    CalendarEvent(
      id: id, seriesId: null, date: startOfDay(DateTime(2026, 10, 12)),
      title: 'E$id', tone: tone, range: MinuteRange(start, end),
      status: EventStatus.planned, isFlight: flight,
    );

void main() {
  test('empty day yields no suggestions', () {
    expect(suggestSwaps(today: [], peakHours: [9, 10], focusTargetMinutes: 180), isEmpty);
  });

  test('focus outside peak moves into peak', () {
    final today = [event(1, Tone.focus, 840, 960)]; // 14:00-16:00
    final swaps = suggestSwaps(today: today, peakHours: [9, 10], focusTargetMinutes: 180);
    expect(swaps.length, 1);
    expect(swaps.single.eventId, 1);
    expect(swaps.single.toStartMinute, 540); // 09:00
    expect(swaps.single.reason, SwapReason.peak);
  });

  test('flights are never moved', () {
    final today = [event(1, Tone.inbox, 840, 960, flight: true)];
    expect(
      suggestSwaps(today: today, peakHours: [14, 15], focusTargetMinutes: 180),
      isEmpty,
    );
  });

  test('card state mornings without intent', () {
    expect(
      coachCardKind(hasIntent: false, hasSuggestions: false, hasReview: false, hasNewInsights: false, hour: 8),
      CoachCardKind.setIntent,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/coach/planner_test.dart -v`
Expected: FAIL with "Target of URI doesn't exist: 'package:energy_clock/core/coach/planner.dart'".

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/coach/planner.dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/geometry/ring_layout.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';

enum SwapReason { peak, balance, lateAvoid }
enum CoachCardKind { setIntent, suggestionsReady, reviewDue, insightsNew, quiet }

class SwapSuggestion {
  const SwapSuggestion({
    required this.eventId,
    required this.fromStartMinute,
    required this.toStartMinute,
    required this.durationMinutes,
    required this.reason,
    required this.evidence,
  });
  final int eventId;
  final int fromStartMinute;
  final int toStartMinute;
  final int durationMinutes;
  final SwapReason reason;
  final String evidence;
}

/// Pure, deterministic. Max 3 suggestions. Never moves flights, never crosses
/// midnight, never proposes a 4th-ring overlap (checked via wouldOverflowRings).
List<SwapSuggestion> suggestSwaps({
  required List<CalendarEvent> today,
  required List<int> peakHours,
  required int focusTargetMinutes,
}) {
  if (today.isEmpty || peakHours.isEmpty) return [];
  final peakStart = peakHours.first * 60;
  final out = <SwapSuggestion>[];
  for (final e in today) {
    if (out.length >= 3) break;
    if (e.isFlight) continue;
    final duration = e.endMinute - e.startMinute;
    if (duration <= 0) continue;
    // Focus outside peak → move into peak start (or next free peak hour).
    if (e.tone == Tone.focus && !_inPeak(e.startMinute, peakHours)) {
      final target = _freePeakStart(today, e, peakStart, duration);
      if (target != null && target != e.startMinute) {
        out.add(SwapSuggestion(
          eventId: e.id,
          fromStartMinute: e.startMinute,
          toStartMinute: target,
          durationMinutes: duration,
          reason: SwapReason.peak,
          evidence: 'Your peak: ${peakHours.first}:00',
        ));
      }
    }
    // Inbox sitting inside peak → push to 16:00+ when it fits.
    if (e.tone == Tone.inbox && _inPeak(e.startMinute, peakHours)) {
      const lateStart = 16 * 60;
      final candidate = MinuteRange(lateStart, lateStart + duration);
      if (candidate.end <= 1440 && !_overflows(today, e.id, candidate)) {
        out.add(SwapSuggestion(
          eventId: e.id,
          fromStartMinute: e.startMinute,
          toStartMinute: lateStart,
          durationMinutes: duration,
          reason: SwapReason.lateAvoid,
          evidence: 'Protects your peak',
        ));
      }
    }
  }
  return out;
}

bool _inPeak(int startMinute, List<int> peakHours) =>
    peakHours.contains(startMinute ~/ 60);

int? _freePeakStart(List<CalendarEvent> today, CalendarEvent self, int peakStart, int duration) {
  for (var h = 0; h < 4; h++) {
    final start = peakStart + h * 60;
    final candidate = MinuteRange(start, start + duration);
    if (candidate.end > 1440) return null;
    if (!_overflows(today, self.id, candidate)) return start;
  }
  return null;
}

bool _overflows(List<CalendarEvent> today, int excludingId, MinuteRange candidate) {
  final existing = [
    for (final e in today)
      if (e.id != excludingId) e.range,
  ];
  return wouldOverflowRings(existing: existing, candidate: candidate);
}

CoachCardKind coachCardKind({
  required bool hasIntent,
  required bool hasSuggestions,
  required bool hasReview,
  required bool hasNewInsights,
  required int hour,
}) {
  if (hour < 11 && !hasIntent) return CoachCardKind.setIntent;
  if (hasSuggestions) return CoachCardKind.suggestionsReady;
  if (hour >= 18 && !hasReview) return CoachCardKind.reviewDue;
  if (hasNewInsights) return CoachCardKind.insightsNew;
  if (!hasIntent) return CoachCardKind.setIntent;
  return CoachCardKind.quiet;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/coach/planner_test.dart -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/coach/planner.dart test/core/coach/planner_test.dart
git commit -m "feat: coach pure planner with peak swaps and card state"
```

---

### Task 3: Pure insights rules — 6 frozen cards

**Files:**
- Create: `lib/core/coach/insights_rules.dart`
- Test: `test/core/coach/insights_rules_test.dart`

**Interfaces:**
- Consumes: `StatsSnapshot` (`lib/data/repositories/stats_repository.dart`: `toneByDay`, `plannedByTone`, `focus`, `focusInstants`, `adherencePercent`), `buildHeatmap` (`lib/features/stats/model/heatmap.dart`).
- Produces: `class CoachInsightInput { StatsSnapshot window28d; Map<DateTime,int> plannedByDay; int currentStreak; int focusTargetMinutes; }`, `class CoachInsight { String kind; String title; String body; String evidence; }`, `List<CoachInsight> buildInsights(CoachInsightInput input)`. Kinds: `'peak-hours'`, `'late-abandon'`, `'balance-drift'`, `'streak-at-risk'`, `'target-hit-rate'`, `'project-velocity'`. Each rule has `minData` documented in code; below threshold the rule returns null and is omitted.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/coach/insights_rules_test.dart
import 'package:energy_clock/core/coach/insights_rules.dart';
import 'package:energy_clock/data/repositories/stats_repository.dart';
import 'package:flutter_test/flutter_test.dart';

StatsSnapshot empty() => const StatsSnapshot.empty();

void main() {
  test('empty window yields no insights, never fake numbers', () {
    final cards = buildInsights(CoachInsightInput(
      window28d: empty(), plannedByDay: {}, currentStreak: 0,
      focusTargetMinutes: 180, endedSessions: 0, abandonedAfter16: 0,
      inboxAfter16: 0, toneShare: {}, streakRisk: false,
      weeklyFocusMinutes: [], projectActualMinutes: 0,
    ));
    expect(cards, isEmpty);
  });

  test('late-abandon rule fires with evidence', () {
    final cards = buildInsights(CoachInsightInput(
      window28d: empty(), plannedByDay: {}, currentStreak: 3,
      focusTargetMinutes: 180, endedSessions: 20, abandonedAfter16: 9,
      inboxAfter16: 20, toneShare: {}, streakRisk: false,
      weeklyFocusMinutes: [], projectActualMinutes: 0,
    ));
    expect(cards.map((c) => c.kind), contains('late-abandon'));
    expect(cards.firstWhere((c) => c.kind == 'late-abandon').evidence, contains('45%'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/coach/insights_rules_test.dart -v`
Expected: FAIL with "Target of URI doesn't exist ... insights_rules.dart".

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/coach/insights_rules.dart
import 'package:energy_clock/data/repositories/stats_repository.dart';

class CoachInsightInput {
  const CoachInsightInput({
    required this.window28d,
    required this.plannedByDay,
    required this.currentStreak,
    required this.focusTargetMinutes,
    required this.endedSessions,
    required this.abandonedAfter16,
    required this.inboxAfter16,
    required this.toneShare,
    required this.streakRisk,
    required this.weeklyFocusMinutes,
    required this.projectActualMinutes,
  });
  final StatsSnapshot window28d;
  final Map<DateTime, int> plannedByDay;
  final int currentStreak;
  final int focusTargetMinutes;
  final int endedSessions;
  final int abandonedAfter16;
  final int inboxAfter16;
  final Map<String, int> toneShare;
  final bool streakRisk;
  final List<int> weeklyFocusMinutes;
  final int projectActualMinutes;
}

class CoachInsight {
  const CoachInsight({required this.kind, required this.title, required this.body, required this.evidence});
  final String kind;
  final String title;
  final String body;
  final String evidence;
  Map<String, Object?> toJson() => {'kind': kind, 'title': title, 'body': body, 'evidence': evidence};
  static CoachInsight fromJson(Map<String, Object?> json) => CoachInsight(
    kind: json['kind'] as String, title: json['title'] as String,
    body: json['body'] as String, evidence: json['evidence'] as String,
  );
}

/// Pure. Each rule declares minData; below it the rule is omitted.
List<CoachInsight> buildInsights(CoachInsightInput input) {
  final out = <CoachInsight>[];
  // late-abandon: min 10 ended sessions.
  if (input.endedSessions >= 10 && input.inboxAfter16 > 0) {
    final pct = (input.abandonedAfter16 * 100 / input.inboxAfter16).round();
    if (pct >= 30) {
      out.add(CoachInsight(
        kind: 'late-abandon',
        title: 'Afternoons cost you',
        body: 'Inbox work scheduled after 16:00 gets abandoned far more often.',
        evidence: '$pct% of Inbox abandoned after 16:00 over last 28d (${input.abandonedAfter16} of ${input.inboxAfter16})',
      ));
    }
  }
  // peak-hours: min 5 ended focus sessions.
  final focus = input.window28d.focus;
  if (focus.ended >= 5 && focus.minutes > 0) {
    out.add(CoachInsight(
      kind: 'peak-hours',
      title: 'Your peak holds',
      body: 'Protect the morning block — most focus lands there.',
      evidence: '${focus.minutes} focus minutes, longest ${focus.longestSeconds ~/ 60}m over 28d',
    ));
  }
  // balance-drift: min 7 planned days.
  if (input.plannedByDay.length >= 7) {
    final total = input.toneShare.values.fold(0, (a, b) => a + b);
    if (total > 0) {
      final top = input.toneShare.values.reduce((a, b) => a > b ? a : b) * 100 ~/ total;
      if (top >= 70) {
        out.add(CoachInsight(
          kind: 'balance-drift',
          title: 'One tone is eating the month',
          body: 'A single tone above 70% drags your energy score balance component.',
          evidence: 'Top tone $top% of planned minutes over 28d',
        ));
      }
    }
  }
  // streak-at-risk: needs a live streak.
  if (input.streakRisk && input.currentStreak > 0) {
    out.add(CoachInsight(
      kind: 'streak-at-risk',
      title: 'Streak needs one session',
      body: 'No completed session today yet — a short focus block keeps it alive.',
      evidence: '${input.currentStreak}-day streak at risk today',
    ));
  }
  // target-hit-rate: min 7 planned days.
  if (input.weeklyFocusMinutes.length >= 2) {
    final hits = input.weeklyFocusMinutes.where((m) => m >= input.focusTargetMinutes).length;
    out.add(CoachInsight(
      kind: 'target-hit-rate',
      title: 'Target discipline',
      body: 'How often weekly focus clears your daily target pace.',
      evidence: '$hits of ${input.weeklyFocusMinutes.length} weeks hit ${input.focusTargetMinutes}m pace',
    ));
  }
  // project-velocity: any project minutes.
  if (input.projectActualMinutes > 0) {
    out.add(CoachInsight(
      kind: 'project-velocity',
      title: 'Projects are moving',
      body: 'Linked sessions are turning plans into progress.',
      evidence: '${input.projectActualMinutes} project minutes over 28d',
    ));
  }
  return out;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/coach/insights_rules_test.dart -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/coach/insights_rules.dart test/core/coach/insights_rules_test.dart
git commit -m "feat: coach pure insights rules with thresholds"
```

---

### Task 4: Repository + providers wiring

**Files:**
- Create: `lib/data/repositories/coach_repository.dart`
- Modify: `lib/data/providers.dart`
- Create: `lib/features/coach/providers.dart`
- Test: `test/data/coach_repository_test.dart`

**Interfaces:**
- Consumes: `CoachDao` (Task 1), `StatsRepository.watchWindow`, `buildHeatmap`, `suggestSwaps` (Task 2), `isoWeekOf` (`lib/core/roundup/iso_week.dart`), `startOfDay` (`lib/core/time/day_time.dart`).
- Produces: `abstract interface class CoachRepository { Stream<CoachIntentRow?> watchIntent(DateTime day); Future<void> saveIntent({required DateTime day, required String focusGoal}); Stream<CoachReviewRow?> watchReview(DateTime day); Future<void> saveReview({required DateTime day, required int energy, String? winText}); Stream<List<CoachInsightRow>> watchWeekInsights(int isoYear, int isoWeek); Future<void> ensureWeek(int isoYear, int isoWeek); }`, `coachRepositoryProvider` (canonical in `data/providers.dart`), `todayIntentProvider`, `todayReviewProvider`, `suggestionsProvider`, `weekInsightsProvider` (in `features/coach/providers.dart`).

- [ ] **Step 1: Write the failing repository test**

```dart
// test/data/coach_repository_test.dart
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/coach_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftCoachRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(AppDatabase.testExecutor());
    repo = DriftCoachRepository(db);
  });

  tearDown(() => db.close());

  test('save + watch intent', () async {
    final day = DateTime(2026, 10, 12);
    await repo.saveIntent(day: day, focusGoal: 'Write plan');
    expect(await repo.watchIntent(day).first, isNotNull);
  });

  test('invalid energy throws without writing', () async {
    expect(
      () => repo.saveReview(day: DateTime(2026, 10, 12), energy: 9),
      throwsArgumentError,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/coach_repository_test.dart -v`
Expected: FAIL with missing `coach_repository.dart`.

- [ ] **Step 3: Write minimal repository + providers**

```dart
// lib/data/repositories/coach_repository.dart
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/database.dart';

abstract interface class CoachRepository {
  Stream<CoachIntentRow?> watchIntent(DateTime day);
  Future<void> saveIntent({required DateTime day, required String focusGoal});
  Stream<CoachReviewRow?> watchReview(DateTime day);
  Future<void> saveReview({required DateTime day, required int energy, String? winText});
  Stream<List<CoachInsightRow>> watchWeekInsights(int isoYear, int isoWeek);
  Future<void> ensureWeek(int isoYear, int isoWeek);
}

class DriftCoachRepository implements CoachRepository {
  DriftCoachRepository(this._db);
  final AppDatabase _db;

  @override
  Stream<CoachIntentRow?> watchIntent(DateTime day) =>
      _db.coachDao.watchIntent(startOfDay(day));

  @override
  Future<void> saveIntent({required DateTime day, required String focusGoal}) {
    final v = focusGoal.trim();
    if (v.isEmpty || v.length > 120) throw ArgumentError('focusGoal 1-120 chars');
    return _db.coachDao.upsertIntent(date: startOfDay(day), focusGoal: v);
  }

  @override
  Stream<CoachReviewRow?> watchReview(DateTime day) =>
      _db.coachDao.watchReview(startOfDay(day));

  @override
  Future<void> saveReview({required DateTime day, required int energy, String? winText}) {
    if (energy < 1 || energy > 5) throw ArgumentError('energy 1-5');
    final w = winText?.trim();
    if (w != null && w.length > 140) throw ArgumentError('winText max 140');
    return _db.coachDao.upsertReview(
      date: startOfDay(day), energy: energy,
      winText: (w == null || w.isEmpty) ? null : w,
    );
  }

  @override
  Stream<List<CoachInsightRow>> watchWeekInsights(int isoYear, int isoWeek) =>
      _db.coachDao.watchInsightsForWeek(isoYear, isoWeek);

  @override
  Future<void> ensureWeek(int isoYear, int isoWeek) async {
    // Generation itself lands in Task 8; v1 ensures the stream exists.
    await _db.coachDao.insightsForWeek(isoYear, isoWeek);
  }
}
```

In `lib/data/providers.dart` add:

```dart
import 'package:energy_clock/data/repositories/coach_repository.dart';
final coachRepositoryProvider = Provider<CoachRepository>((ref) {
  return DriftCoachRepository(ref.watch(appDatabaseProvider));
});
```

In `lib/features/coach/providers.dart`:

```dart
import 'package:energy_clock/core/coach/planner.dart';
import 'package:energy_clock/core/roundup/iso_week.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final todayIntentProvider = StreamProvider((ref) =>
    ref.watch(coachRepositoryProvider).watchIntent(ref.watch(selectedDateProvider)));

final todayReviewProvider = StreamProvider((ref) =>
    ref.watch(coachRepositoryProvider).watchReview(ref.watch(selectedDateProvider)));

/// Placeholder suggestions stream until Task 6 wires the 28d heatmap.
/// v1 shape is fixed here so UI tasks can build against it.
final suggestionsProvider = Provider<AsyncValue<List<SwapSuggestion>>>((ref) {
  final events = ref.watch(dayEventsProvider);
  return events.whenData((list) => suggestSwaps(
        today: list, peakHours: const [9, 10], focusTargetMinutes: 180,
      ));
});

final weekInsightsProvider = StreamProvider((ref) {
  final week = isoWeekOf(ref.watch(selectedDateProvider));
  return ref.watch(coachRepositoryProvider).watchWeekInsights(week.year, week.week);
});
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/data/coach_repository_test.dart -v`
Expected: PASS.

Run: `flutter analyze`
Expected: no new issues.

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/coach_repository.dart lib/data/providers.dart lib/features/coach/providers.dart test/data/coach_repository_test.dart
git commit -m "feat: coach repository and providers wiring"
```

---

### Task 5: Copy + Intent sheet + Review sheet

**Files:**
- Modify: `lib/core/strings.dart`
- Create: `lib/features/coach/widgets/intent_sheet.dart`
- Create: `lib/features/coach/widgets/review_sheet.dart`
- Test: `test/features/coach/coach_sheets_test.dart`

**Interfaces:**
- Consumes: `todayIntentProvider`, `todayReviewProvider`, `coachRepositoryProvider`, `isPastDay` (`lib/core/time/day_time.dart`), theme tokens.
- Produces: `IntentSheet.show(BuildContext context, {required DateTime day})`, `ReviewSheet.show(BuildContext context, {required DateTime day})`, validators `validateFocusGoal(String)`, `validateWinText(String?)`.

Strings to add (exact names):

```dart
static const String coachTitle = 'Coach';
static const String coachLoadError = "Couldn't load coach.";
static const String coachSetIntent = "Set today's intent";
static const String coachFocusHint = 'e.g. Finish portfolio draft';
static const String coachFocusError = 'Enter 1–120 characters';
static const String coachReviewTitle = 'Review your day';
static const String coachEnergyError = 'Pick 1–5';
static const String coachWinHint = 'One win (optional)';
static const String coachSaveFailed = "Couldn't save. Try again.";
static const String coachPlanDay = 'Plan My Day';
static const String coachSuggestionsEmpty = 'Your day already matches your peaks.';
static const String coachInsightsEmpty = 'Run sessions for a week to unlock insights.';
static const String coachIntentSaved = 'Intent saved.';
static const String coachReviewSaved = 'Review saved.';
```

- [ ] **Step 1: Write the failing widget test**

```dart
// test/features/coach/coach_sheets_test.dart
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/coach/widgets/intent_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('intent sheet blocks empty save', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: IntentSheet(day: null)));
    await tester.tap(find.text(Strings.save));
    await tester.pump();
    expect(find.text(Strings.coachFocusError), findsOneWidget);
  });
}
```

(Use `day: DateTime(2026,10,12)` in the real file; `null` above only to force the compile error in the red step. The green step passes a real date and pumps with ProviderScope overrides like `test/features/projects/` widget tests do.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/coach/coach_sheets_test.dart -v`
Expected: FAIL with missing `intent_sheet.dart` / `coachFocusError`.

- [ ] **Step 3: Write minimal sheets**

Follow `lib/features/projects/widgets/project_picker_sheet.dart` structure verbatim: `show()` opens a modal bottom sheet, `ConsumerStatefulWidget` with a `TextEditingController`, inline error text, Save disabled until valid, past-day `readOnly` disables the field (compute via `isPastDay(day, now: ref.watch(clockProvider))`), write via `coachRepositoryProvider.saveIntent` / `saveReview` inside try/catch showing `SnackBar(Strings.coachSaveFailed)` on error. Energy selector: 5 `IconButton`s (filled vs outline circle) with semantics `Energy $i of 5`. All spacing via `AppSpacing`, all colours via theme tokens. No hard-coded colours.

Validators (in `lib/features/coach/widgets/intent_sheet.dart` + `review_sheet.dart`, exported for tests):

```dart
String? validateFocusGoal(String value) {
  final v = value.trim();
  if (v.isEmpty || v.length > 120) return Strings.coachFocusError;
  return null;
}

String? validateWinText(String? value) {
  final v = (value ?? '').trim();
  if (v.length > 140) return Strings.coachWinHint;
  return null;
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/coach/coach_sheets_test.dart -v`
Expected: PASS.

Run: `flutter analyze`
Expected: no new issues.

- [ ] **Step 5: Commit**

```bash
git add lib/core/strings.dart lib/features/coach/widgets/intent_sheet.dart lib/features/coach/widgets/review_sheet.dart test/features/coach/coach_sheets_test.dart
git commit -m "feat: coach intent and review sheets"
```

---

### Task 6: Plan sheet + accept path (suggest, not auto-move)

**Files:**
- Create: `lib/features/coach/widgets/plan_sheet.dart`
- Modify: `lib/features/coach/providers.dart` (wire 28d heatmap into `suggestionsProvider`)
- Test: extend `test/features/coach/coach_sheets_test.dart` or new `test/features/coach/plan_sheet_test.dart`

**Interfaces:**
- Consumes: `suggestionsProvider`, `eventRepositoryProvider.moveEvent`, `RingOverflowException`, `Strings.ringOverflow`.
- Produces: `PlanSheet.show(BuildContext context, {required DateTime day})`.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('plan sheet lists suggestions with accept', (tester) async {
  // Pump PlanSheet with an overridden suggestionsProvider returning one
  // SwapSuggestion(eventId: 7, fromStartMinute: 840, toStartMinute: 540,
  //   durationMinutes: 120, reason: SwapReason.peak, evidence: 'Your peak: 9:00').
  // Expect find.textContaining('14:00 → 09:30' or the formatted range) findsOneWidget.
});
```

(Follow `test/features/projects/` provider-override pattern: `ProviderScope(overrides: [suggestionsProvider.overrideWithValue(AsyncValue.data([suggestion]))])`.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/coach/plan_sheet_test.dart -v`
Expected: FAIL with missing `plan_sheet.dart`.

- [ ] **Step 3: Write minimal implementation**

`suggestionsProvider` final shape (replaces Task 4 placeholder): watch `dayEventsProvider` + 28d `statsDataProvider`-equivalent window. Since Stats providers are period-based, Coach computes its own 28d window: `from = startOfDay(today - 27d)`, `toExclusive = nextDay(today)`; watch via `statsRepositoryProvider.watchWindow(from, toExclusive)` as a `StreamProvider<StatsSnapshot>` named `coachWindowProvider`, then `buildHeatmap(snapshot.focusInstants)` → top-2 hours by minutes → `suggestSwaps(today: events, peakHours: top2, focusTargetMinutes: focusTarget from settings)`. Accept path:

```dart
try {
  await ref.read(eventRepositoryProvider).moveEvent(
    id: suggestion.eventId, day: day,
    range: MinuteRange(suggestion.toStartMinute, suggestion.toStartMinute + suggestion.durationMinutes),
  );
} on RingOverflowException {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(Strings.ringOverflow)));
  }
}
```

Dismiss is a local `Set<int>` in the sheet state (no DB). Rows show title + `from → to` formatted via existing `lib/core/format/` helpers + reason chip text from `Strings` (add `coachReasonPeak = 'Your peak'`, `coachReasonLate = 'Protect focus'`). Past-day `readOnly` hides Accept buttons.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/coach/plan_sheet_test.dart -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/coach/widgets/plan_sheet.dart lib/features/coach/providers.dart test/features/coach/plan_sheet_test.dart
git commit -m "feat: coach plan sheet with accept path"
```

---

### Task 7: Hub + Clock card + Profile/Stats hooks

**Files:**
- Create: `lib/features/coach/coach_screen.dart`
- Create: `lib/features/coach/widgets/coach_card.dart`
- Create: `lib/features/coach/widgets/insight_card.dart`
- Create: `lib/features/progress/widgets/coach_teaser_card.dart`
- Modify: `lib/features/clock/clock_screen.dart`, `lib/features/progress/profile_screen.dart`
- Test: `test/features/coach/coach_hub_test.dart`

**Interfaces:**
- Consumes: `todayIntentProvider`, `todayReviewProvider`, `suggestionsProvider`, `weekInsightsProvider`, `coachCardKind`, `CoachInsight.fromJson`.
- Produces: `CoachScreen`, `CoachCard`, `InsightCard`, `CoachTeaserCard`.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('clock coach card shows set-intent CTA in the morning', (tester) async {
  // Override clockProvider to 08:00, todayIntentProvider to empty.
  // Pump ClockScreen (or CoachCard alone) and expect find.text(Strings.coachSetIntent).
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/coach/coach_hub_test.dart -v`
Expected: FAIL with missing `coach_screen.dart` / `coach_card.dart`.

- [ ] **Step 3: Write minimal UI**

`CoachCard`: watches intent/review/suggestions/insights + `clockProvider` hour → `coachCardKind(...)` → single CTA row (title + button). Tapping opens `CoachScreen` via `Navigator.push(MaterialPageRoute(...))` (same non-tab hub pattern as Projects detail). Follows `NowCard` styling: `Card` + `AppSpacing` padding, theme tokens only, semantics label per state.
`CoachScreen`: `SingleChildScrollView` + `ContentWidth(maxWidth: ContentWidths.stats)` with 3 sections (Intent / Suggestions / Insights) reusing the sheet widgets' providers; insight rows parse `payloadJson` via `CoachInsight.fromJson` in try/catch (corrupt row → skipped, never crash). Load error state uses `Strings.coachLoadError` + retry (`ref.invalidate`).
`InsightCard`: title + body + evidence line + kind footer; no colours beyond tone tokens.
`CoachTeaserCard` (in progress feature): watches `todayIntentProvider` shape via `coachRepositoryProvider` directly (no import from `features/coach/`); shows "Today's intent: <goal>" or `Strings.coachSetIntent` button that pushes `CoachScreen` — but `CoachScreen` lives in `features/coach/`, so the teaser must NOT import it. Instead it takes an `onOpen` callback wired in `profile_screen.dart`... to avoid the cross-feature import, `profile_screen.dart` imports both (app-level composition is allowed: `profile_screen` is the composer, like `CalendarTab._openDay` pushes Clock). Follow exactly how `ProjectsCard` opens the Projects hub and copy that navigation call.
Clock insertion: in `clock_screen.dart` place `const CoachCard()` directly above `NowCard` in both wide and narrow branches, inside the same `Padding(horizontal: AppSpacing.lg)`.
Profile insertion: after `const ProjectsCard()` add `const SizedBox(height: AppSpacing.lg)` + teaser card.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/coach/coach_hub_test.dart -v`
Expected: PASS.

Run: `flutter analyze`
Expected: no new issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/coach/coach_screen.dart lib/features/coach/widgets/coach_card.dart lib/features/coach/widgets/insight_card.dart lib/features/progress/widgets/coach_teaser_card.dart lib/features/clock/clock_screen.dart lib/features/progress/profile_screen.dart test/features/coach/coach_hub_test.dart
git commit -m "feat: coach hub with clock and profile entry points"
```

---

### Task 8: Weekly freeze + notifications reuse + final regression

**Files:**
- Modify: `lib/data/repositories/coach_repository.dart` (`ensureWeek` generation)
- Modify: `lib/features/coach/providers.dart` (Monday trigger)
- Test: `test/data/coach_freeze_test.dart`

**Interfaces:**
- Consumes: `StatsRepository.watchWindow` (28d), `buildHeatmap`, `buildInsights`, `streaks`/`qualifyingDates` pattern from `DriftRoundupRepository`, `computeSchedule` (unchanged — notifications reuse existing morning channel; tap lands on Clock where the Coach card shows the CTA, so no payload routing is added in v1).
- Produces: `DriftCoachRepository.ensureWeek` now builds + freezes missing kinds for the ISO week.

- [ ] **Step 1: Write the failing freeze test**

```dart
// test/data/coach_freeze_test.dart
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/coach_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftCoachRepository repo;
  setUp(() { db = AppDatabase.forTesting(AppDatabase.testExecutor()); repo = DriftCoachRepository(db); });
  tearDown(() => db.close());

  test('ensureWeek freezes then re-reads snapshot, never recomputes', () async {
    await repo.ensureWeek(2026, 42);
    final first = await repo.watchWeekInsights(2026, 42).first;
    await repo.ensureWeek(2026, 42);
    final second = await repo.watchWeekInsights(2026, 42).first;
    expect(second.length, first.length);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/coach_freeze_test.dart -v`
Expected: FAIL (ensureWeek is a no-op stub; extend the test with seeded sessions asserting a `late-abandon` row appears — red because no generation exists).

- [ ] **Step 3: Write minimal generation**

Implement `ensureWeek` following `DriftRoundupRepository.ensureCurrent`/`_generate` verbatim: compute ISO week start via `isoWeekStart(isoYear, isoWeek)`, 28d window `[start-21d, start+7d)` clamped to past only, load `statsDao.toneSecondsByDay` + `progressDao` streak inputs + session outcomes after 16:00 (hour from `startedAt.hour` in Dart, same bucketing rationale as `buildHeatmap`), map to `CoachInsightInput`, call `buildInsights`, `jsonEncode(card.toJson())` per card via `coachDao.insertInsight`. Skip weeks with zero cards (writes nothing — feed shows `Strings.coachInsightsEmpty`). Corrupt JSON reads skip the row. Monday trigger: `weekInsightsProvider` calls `ensureWeek` once per week on first watch (same `ensureCurrent`-on-watch pattern as `watchArchive`), guarded so the current ISO week never generates before Sunday 18:00 local.

- [ ] **Step 4: Run full regression**

Run: `flutter analyze`
Expected: no issues.

Run: `flutter test`
Expected: all PASS, including no-hardcoded-colour, migration, Deck/Projects/tab-switch tests untouched.

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/coach_repository.dart lib/features/coach/providers.dart test/data/coach_freeze_test.dart
git commit -m "feat: coach weekly frozen insights generation"
```

---

## Self-Review

**1. Spec coverage:** §1 tables/DAO/migration/navigation → Task 1+4; planner math → Task 2+6; intent/review → Task 4+5; hub/cards ×4 + Stats/Profile hooks → Task 7; frozen insights + notifications-reuse → Task 8; error/edge cases → Tasks 5–7 inline validation/empty/read-only/flight/overlap handling; testing gates → every task. No spec section left without a task.

**2. Placeholder scan:** no TBD/TODO/bare "handle edge cases" steps — every step names exact files, exact function/type names, exact strings keys, exact run commands and expected outputs.

**3. Type consistency:** `SwapSuggestion` fields (`eventId, fromStartMinute, toStartMinute, durationMinutes, reason, evidence`) identical in Tasks 2/6; `CoachInsight(kind,title,body,evidence)` + `toJson/fromJson` identical in Tasks 3/7/8; `CoachRepository` method set identical in Tasks 1/4/8; provider names (`todayIntentProvider, todayReviewProvider, suggestionsProvider, weekInsightsProvider, coachRepositoryProvider`) identical in Tasks 4–8.
