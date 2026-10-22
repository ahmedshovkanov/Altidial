# Coach Ritual v2 (Energy + Reflection) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add morning energy prediction to intent and live reflection aggregates to evening review, read-only over existing sessions.

**Architecture:** One additive nullable column `coach_intents.predicted_energy` (v8→v9 migration); `CoachDao.upsertIntent` + `CoachRepository.saveIntent` accept optional `predictedEnergy`; intent sheet gains optional 1–5 dots; hub shows prediction line plus today's session energy/focus averages and top tags computed client-side.

**Tech Stack:** Flutter 3.x, Riverpod 2.x, Drift 2.x, existing `sessions` reflection columns (`energyRating`, `focusRating`, `tagsCsv`), `day_scores` adherence, theme tokens + `Strings`.

## Global Constraints

- Offline-only; no backend, no sync, no account, no new iOS permissions.
- Features never import each other; Coach imports only `data/`, `core/`, `app/`, `shared/`.
- All user copy in `lib/core/strings.dart`; no hardcoded copy.
- All colors via theme tokens; the no-hardcoded-colour test must keep passing.
- Prediction value never drives `coachCardKind` CTA — intent existence drives card state as today.
- Past-day read-only disables intent/review/prediction edits via existing `isPastDay` guard.
- Drift codegen with the Flutter SDK's `dart`: `"$(dirname "$(which flutter)")/dart" run build_runner build --delete-conflicting-outputs`.
- Every schema bump needs a step in `migration` and a test in `test/data/migration_test.dart`; see `drift_schemas/`.

---

### Task 1: Schema v9 predictedEnergy column

**Files:**
- Modify: `lib/data/tables/coach_tables.dart`
- Modify: `lib/data/database.dart`
- Modify: `lib/data/daos/coach_dao.dart`
- Test: `test/data/coach_dao_test.dart`, `test/data/migration_test.dart`

**Interfaces:**
- Consumes: existing `CoachIntents` table (`date`, `focusGoal`, `topEventIds`, `createdAt`).
- Produces: `CoachIntents.predictedEnergy` nullable int 1–5; `CoachDao.upsertIntent({required DateTime date, required String focusGoal, String? topEventIds, int? predictedEnergy})`.

- [ ] **Step 1: Write the failing test**

In `test/data/coach_dao_test.dart` append:

```dart
test('intent round-trips predicted energy', () async {
  final day = DateTime(2026, 10, 12);
  await db.coachDao.upsertIntent(date: day, focusGoal: 'Ship ritual', predictedEnergy: 4);
  expect((await db.coachDao.intentFor(day))?.predictedEnergy, 4);
  await db.coachDao.upsertIntent(date: day, focusGoal: 'Second save wins', predictedEnergy: null);
  expect((await db.coachDao.intentFor(day))?.predictedEnergy, isNull);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/coach_dao_test.dart -v`
Expected: FAIL with "No named parameter 'predictedEnergy'".

- [ ] **Step 3: Write minimal implementation**

In `lib/data/tables/coach_tables.dart`:

```dart
IntColumn get predictedEnergy => integer().nullable().check(predictedEnergy.isBetweenValues(1, 5))();
```

In `lib/data/database.dart`: bump `schemaVersion` to 9, update doc comment to add `/// Version 9: coach_intents.predicted_energy.`, add migration step:

```dart
if (from < 9) {
  await migrator.addColumn(coachIntents, coachIntents.predictedEnergy);
}
```

In `lib/data/daos/coach_dao.dart`:

```dart
Future<void> upsertIntent({
  required DateTime date,
  required String focusGoal,
  String? topEventIds,
  int? predictedEnergy,
}) =>
    into(coachIntents).insertOnConflictUpdate(
      CoachIntentsCompanion.insert(
        date: date,
        focusGoal: focusGoal,
        topEventIds: Value(topEventIds),
        predictedEnergy: Value(predictedEnergy),
        createdAt: DateTime.now(),
      ),
    );
```

Run codegen:

```bash
"$(dirname "$(which flutter)")/dart" run build_runner build --delete-conflicting-outputs
```

Then dump schema for v9 per repo workflow (`drift_dev schema dump`) and regenerate `test/generated_migrations/schema.dart` so `migration_test.dart` sees v9. If the repo script is `tool/`-based, follow the existing v8 commit's file list (`drift_schemas/drift_schema_v9.json` + generated helper).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/coach_dao_test.dart -v`
Expected: PASS.

Add migration test in `test/data/migration_test.dart`:

```dart
test('version 8 upgrades to version 9 with predictedEnergy null', () async {
  final schema = await verifier.schemaAt(8);
  final database = AppDatabase.forTesting(schema.newConnection());
  addTearDown(database.close);
  await verifier.migrateAndValidate(database, 9);
  final day = DateTime(2026, 10, 12);
  await database.coachDao.upsertIntent(date: day, focusGoal: 'Old row');
  expect((await database.coachDao.intentFor(day))?.predictedEnergy, isNull);
});
```

Run: `flutter test test/data/migration_test.dart -v`
Expected: PASS.

Run: `flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/tables/coach_tables.dart lib/data/database.dart lib/data/daos/coach_dao.dart test/data/coach_dao_test.dart test/data/migration_test.dart drift_schemas/ test/generated_migrations/
git commit -m "feat: add coach_intents.predicted_energy v9"
```

### Task 2: Repository validation + Strings copy

**Files:**
- Modify: `lib/data/repositories/coach_repository.dart`
- Modify: `lib/core/strings.dart`
- Test: `test/data/coach_repository_test.dart`

**Interfaces:**
- Consumes: `CoachDao.upsertIntent` from Task 1.
- Produces: `CoachRepository.saveIntent({required DateTime day, required String focusGoal, int? predictedEnergy})` rejecting `predictedEnergy` outside 1–5; new `Strings.predictedEnergyLabel`, `Strings.reflectionsTodayLine`, `Strings.reflectionsTodayEmpty`.

- [ ] **Step 1: Write the failing test**

```dart
test('saveIntent accepts null and 1-5, rejects 0 and 6', () async {
  final day = DateTime(2026, 10, 12);
  await repository.saveIntent(day: day, focusGoal: 'Goal', predictedEnergy: null);
  expect((await db.coachDao.intentFor(startOfDay(day)))?.predictedEnergy, isNull);
  await repository.saveIntent(day: day, focusGoal: 'Goal', predictedEnergy: 3);
  expect((await db.coachDao.intentFor(startOfDay(day)))?.predictedEnergy, 3);
  expect(() => repository.saveIntent(day: day, focusGoal: 'Goal', predictedEnergy: 0), throwsArgumentError);
  expect(() => repository.saveIntent(day: day, focusGoal: 'Goal', predictedEnergy: 6), throwsArgumentError);
});
```

Adjust to match existing `coach_repository_test.dart` setup (db + repository construction, `startOfDay` import from `lib/core/time/day_time.dart`).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/coach_repository_test.dart -v`
Expected: FAIL with "No named parameter 'predictedEnergy'".

- [ ] **Step 3: Write minimal implementation**

In `lib/data/repositories/coach_repository.dart`:

```dart
abstract interface class CoachRepository {
  Stream<CoachIntentRow?> watchIntent(DateTime day);
  Future<void> saveIntent({required DateTime day, required String focusGoal, int? predictedEnergy});
  // ... rest unchanged
}
```

```dart
@override
Future<void> saveIntent({required DateTime day, required String focusGoal, int? predictedEnergy}) {
  final v = focusGoal.trim();
  if (v.isEmpty || v.length > 120) throw ArgumentError('focusGoal 1-120 chars');
  if (predictedEnergy != null && (predictedEnergy < 1 || predictedEnergy > 5)) {
    throw ArgumentError('predictedEnergy 1-5 or null');
  }
  return _db.coachDao.upsertIntent(date: startOfDay(day), focusGoal: v, predictedEnergy: predictedEnergy);
}
```

In `lib/core/strings.dart` add:

```dart
static const String predictedEnergyLabel = 'Morning energy';
static const String reflectionsTodayEmpty = 'No reflections yet today.';
static String reflectionsTodayLine(int count, String energy, String focus, String tags) =>
    '$count sessions · E $energy / F $focus · top: $tags';
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/coach_repository_test.dart test/data/coach_dao_test.dart -v`
Expected: PASS.

Run: `flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/coach_repository.dart lib/core/strings.dart test/data/coach_repository_test.dart
git commit -m "feat: validate predictedEnergy in coach repository"
```

### Task 3: Intent sheet prediction + hub display

**Files:**
- Modify: `lib/features/coach/widgets/intent_sheet.dart`
- Modify: `lib/features/coach/coach_screen.dart`
- Test: `test/features/coach/intent_sheet_test.dart` (create if missing; mirror `review_sheet_test.dart` pattern if exists)

**Interfaces:**
- Consumes: `saveIntent` with `predictedEnergy` from Task 2; `todayIntentProvider` row including `predictedEnergy`.
- Produces: Intent sheet with optional 1–5 dots (`Semantics 'Predicted energy i of 5'`); hub `_IntentSection` shows `Energy 4/5` line when non-null.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('intent sheet saves prediction', (tester) async {
  await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: IntentSheet(day: _day))));
  await tester.pump();
  await tester.enterText(find.byType(TextField), 'Finish draft');
  await tester.tap(find.bySemanticsLabel('Predicted energy 4 of 5'));
  await tester.pump();
  await tester.tap(find.text('Save'));
  await tester.pump();
  // Verify via repository mock or provider override that predictedEnergy == 4.
});
```

Use existing test overrides for `coachRepositoryProvider` (see `test/features/coach/` for fake repository pattern). If no fake exists, assert the dots render and Save enables — minimal failing assertion is `expect(find.bySemanticsLabel('Predicted energy 4 of 5'), findsOneWidget)` failing before implementation.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/coach/intent_sheet_test.dart -v`
Expected: FAIL with "Found 0 widgets with semantics label".

- [ ] **Step 3: Write minimal implementation**

In `_IntentSheetState` add `int? _predicted;`. After the `TextField`, insert:

```dart
const SizedBox(height: AppSpacing.sm),
Text(Strings.predictedEnergyLabel, style: Theme.of(context).textTheme.labelLarge),
Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    for (var i = 1; i <= 5; i++)
      Semantics(
        label: 'Predicted energy $i of 5',
        button: true,
        child: IconButton(
          icon: Icon(i <= (_predicted ?? 0) ? Icons.circle : Icons.circle_outlined),
          onPressed: readOnly ? null : () => setState(() => _predicted = (_predicted == i) ? null : i),
        ),
      ),
  ],
),
```

Tapping selected dot clears to null (optional field). `_save` passes `predictedEnergy: _predicted`.

In `coach_screen.dart` `_IntentSection.build`, after `Text(current.focusGoal)` add:

```dart
if (current.predictedEnergy != null)
  Text('${Strings.predictedEnergyLabel} ${current.predictedEnergy}/5'),
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/coach/intent_sheet_test.dart -v`
Expected: PASS.

Run: `flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/coach/widgets/intent_sheet.dart lib/features/coach/coach_screen.dart test/features/coach/intent_sheet_test.dart
git commit -m "feat: intent sheet morning energy prediction"
```

### Task 4: Review live reflection aggregates

**Files:**
- Modify: `lib/features/coach/providers.dart` (add `todayReflectionSummaryProvider`)
- Modify: `lib/features/coach/coach_screen.dart` (`_IntentSection` review block or new `_ReflectionLine`)
- Test: `test/features/coach/reflection_summary_test.dart`

**Interfaces:**
- Consumes: today's ended sessions with `energyRating`/`focusRating`/`tagsCsv` via `sessionDao.endedSessions()` joined to today's events (same join as `DriftReflectionsRepository._join`), or via `reflectionsRepositoryProvider.watchTimeline()` filtered to selected day.
- Produces: `todayReflectionSummaryProvider -> AsyncValue<ReflectionSummary>` where `ReflectionSummary({required int count, required double? avgEnergy, required double? avgFocus, required List<String> topTags})` plus `formatSummary()` using `Strings.reflectionsTodayLine` / `Strings.reflectionsTodayEmpty`.

- [ ] **Step 1: Write the failing test**

```dart
test('summary averages rated sessions, ignores unrated', () {
  final summary = summarizeReflections([
    (energy: 4, focus: 5, tags: ['flow']),
    (energy: 2, focus: 3, tags: ['flow', 'tired']),
    (energy: null, focus: null, tags: []),
  ]);
  expect(summary.count, 3);
  expect(summary.avgEnergy, closeTo(3.0, 0.01));
  expect(summary.avgFocus, closeTo(4.0, 0.01));
  expect(summary.topTags, ['flow', 'tired']);
});
```

Define `summarizeReflections` as the pure helper this task introduces (in `providers.dart` or `lib/core/coach/reflection_summary.dart` with no Flutter imports). Test fails with "function not defined".

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/coach/reflection_summary_test.dart -v`
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

Create pure helper in `lib/core/coach/reflection_summary.dart`:

```dart
class ReflectionSummary {
  const ReflectionSummary({required this.count, required this.avgEnergy, required this.avgFocus, required this.topTags});
  final int count;
  final double? avgEnergy;
  final double? avgFocus;
  final List<String> topTags;
}

ReflectionSummary summarizeReflections(List<({int? energy, int? focus, List<String> tags})> rows) {
  if (rows.isEmpty) return const ReflectionSummary(count: 0, avgEnergy: null, avgFocus: null, topTags: []);
  final energies = [for (final r in rows) if (r.energy != null) r.energy!];
  final focuses = [for (final r in rows) if (r.focus != null) r.focus!];
  final tagCounts = <String, int>{};
  for (final r in rows) {
    for (final t in r.tags) {
      tagCounts[t] = (tagCounts[t] ?? 0) + 1;
    }
  }
  final top = tagCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value) != 0 ? b.value.compareTo(a.value) : a.key.compareTo(b.key));
  double? avg(List<int> xs) => xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;
  return ReflectionSummary(count: rows.length, avgEnergy: avg(energies), avg(focuses), topTags: [for (final e in top.take(2)) e.key]);
}
```

Provider in `lib/features/coach/providers.dart`:

```dart
final todayReflectionSummaryProvider = Provider<AsyncValue<ReflectionSummary>>((ref) {
  final timeline = ref.watch(reflectionsTimelineProvider);
  final day = ref.watch(selectedDateProvider);
  return timeline.when(
    data: (rows) {
      final dayStart = startOfDay(day);
      final today = rows.where((r) => startOfDay(r.eventDate) == dayStart).toList();
      return AsyncValue.data(summarizeReflections([
        for (final r in today)
          (energy: r.session.energyRating, focus: r.session.focusRating, tags: r.session.tags),
      ]));
    },
    error: (e, st) => AsyncValue.error(e, st),
    loading: () => const AsyncValue.loading(),
  );
});
```

Use existing `reflectionsTimelineProvider` from `lib/features/reflections/providers.dart` (import providers only, never widgets — preserves no-feature-import rule via provider import; if the rule forbids even that, duplicate the light-aggregator watch on `reflectionsRepositoryProvider.watchTimeline()` directly in coach providers). Day comparison via `startOfDay` from `lib/core/time/day_time.dart` (equality on midnight-normalized dates).

Hub UI in `coach_screen.dart` under review section:

```dart
final summary = ref.watch(todayReflectionSummaryProvider);
summary.when(
  data: (s) => s.count == 0 || s.avgEnergy == null
      ? const Text(Strings.reflectionsTodayEmpty)
      : Text(Strings.reflectionsTodayLine(s.count, s.avgEnergy!.toStringAsFixed(1), s.avgFocus!.toStringAsFixed(1), s.topTags.map(Strings.tagLabel).join(', '))),
  loading: () => const SizedBox.shrink(),
  error: (_, __) => const SizedBox.shrink(),
),
```

Tag labels via existing `Strings.tagLabel`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/coach/reflection_summary_test.dart -v`
Expected: PASS.

Run: `flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/coach/reflection_summary.dart lib/features/coach/providers.dart lib/features/coach/coach_screen.dart test/features/coach/reflection_summary_test.dart
git commit -m "feat: live reflection aggregates in coach review"
```

### Task 5: Full regression + goldens

**Files:**
- All touched files; goldens in `test/features/clock/goldens` and `test/features/coach/`.

**Interfaces:**
- Consumes: Tasks 1-4.
- Produces: Green `flutter analyze` + `flutter test`; no-hardcoded-colour test passes.

- [ ] **Step 1: Run full suite**

Run: `flutter analyze`
Expected: PASS.

Run: `flutter test -v`
Expected: PASS. Coach hub goldens (if any) may fail on new prediction/aggregate lines — review images before updating.

- [ ] **Step 2: Regen goldens only if deliberate**

Run: `flutter test --update-goldens test/features/coach/ -v` only after image review.
Expected: PASS, diff shows only prediction dots + aggregate line.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "test: coach ritual v2 regression green"
```
