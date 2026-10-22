# Projects Pro Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand Projects from primitive rings into a rich offline outcomes hub (Slice 1 fixes+depth, Slice 2 subtasks+reminders).

**Architecture:** Additive Drift migrations v9→v10 (project columns) and v10→v11 (subtasks table); grouped detail query replacing the N+1 loop; client-side search/sort/filter + pure velocity math; deadline reminders on the existing notification channel.

**Tech Stack:** Flutter + Riverpod + Drift (SQLite) + flutter_local_notifications (existing channel) + flutter_test.

## Global Constraints

- Offline-only, no backend, no sync, no account.
- No new iOS permissions; deadline reminders reuse the existing event-starting-soon channel.
- Features never import each other; `features/projects/` imports only `data/`, `core/`, `app/`, `shared/`.
- All user copy in `lib/core/strings.dart`; no hardcoded copy in widgets.
- All colors via theme tokens (`context.appColors`, `context.toneColors`); the no-hardcoded-colour test must pass.
- Drift codegen only via the Flutter SDK's `dart`: `"$(dirname "$(which flutter)")/dart" run build_runner build --delete-conflicting-outputs`.
- Every schema bump needs a migration step in `lib/data/database.dart` + a test in `test/data/migration_test.dart` (see `drift_schemas/`).
- Gates per task: `flutter analyze` and `flutter test` for touched areas; no `flutter test --update-goldens` unless a deliberate visual change was reviewed.

---

### Task 1: Schema v10 — notes/priority/rename + migration

**Files:**
- Modify: `lib/data/tables/projects_table.dart`
- Modify: `lib/data/database.dart:61-151` (version comment, `schemaVersion`, `migration`, `resetAll` stays)
- Modify: `lib/data/daos/project_dao.dart:37-62` (add `updateTitle`, `updateNotes`, `updatePriority`)
- Modify: `lib/data/repositories/project_repository.dart:25-40` (interface + impl)
- Test: `test/data/project_dao_test.dart`, `test/data/migration_test.dart`
- Generated: `lib/data/database.g.dart`, `lib/data/daos/project_dao.g.dart` (via build_runner, never hand-edited)

**Interfaces:**
- Consumes: existing `Projects` table (`title`, `createdAt`, `deadline`, `targetMinutes`, `toneIndex`, `status`, `completedAt`).
- Produces: `ProjectDao.updateTitle(id, title)`, `updateNotes(id, notes?)`, `updatePriority(id, priority)`; `ProjectRepository.updateTitle/updateNotes/updatePriority` with same signatures; schema v10.

- [ ] **Step 1: Write failing DAO test for title/notes/priority round-trip**

```dart
test('rename/notes/priority round-trip', () async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  final id = await db.projectDao.createProject(
    ProjectsCompanion.insert(title: 'Alpha', createdAt: DateTime(2026, 10, 1)),
  );
  await db.projectDao.updateTitle(id, 'Beta');
  await db.projectDao.updateNotes(id, 'Why it matters');
  await db.projectDao.updatePriority(id, 2);
  final row = await (db.select(db.projects)..where((r) => r.id.equals(id))).getSingle();
  expect(row.title, 'Beta');
  expect(row.notes, 'Why it matters');
  expect(row.priority, 2);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/project_dao_test.dart -v`
Expected: FAIL — `updateTitle` / `notes` / `priority` undefined.

- [ ] **Step 3: Implement v10 schema + DAO + repository**

```dart
// lib/data/tables/projects_table.dart — add:
TextColumn get notes => text().nullable()();
IntColumn get priority => integer().withDefault(const Constant(0))();
```

```dart
// lib/data/database.dart:
int get schemaVersion => 10;
// in migration onUpgrade, after the v9 block:
if (from < 10 && to >= 10) {
  await migrator.addColumn(projects, projects.notes);
  await migrator.addColumn(projects, projects.priority);
}
```

```dart
// lib/data/daos/project_dao.dart — add:
Future<void> updateTitle(int id, String title) =>
    (update(projects)..where((r) => r.id.equals(id))).write(
      ProjectsCompanion(title: Value(title.trim())),
    );
Future<void> updateNotes(int id, String? notes) =>
    (update(projects)..where((r) => r.id.equals(id))).write(
      ProjectsCompanion(notes: Value(notes?.trim().isEmpty == true ? null : notes?.trim())),
    );
Future<void> updatePriority(int id, int priority) =>
    (update(projects)..where((r) => r.id.equals(id))).write(
      ProjectsCompanion(priority: Value(priority.clamp(0, 3))),
    );
```

Then codegen: `"$(dirname "$(which flutter)")/dart" run build_runner build --delete-conflicting-outputs`. Add matching `updateTitle/updateNotes/updatePriority` to `ProjectRepository` interface + `DriftProjectRepository` delegating to the DAO. Unknown `priority` values read as 0 at display time (clamp in UI mapper, not stored).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/project_dao_test.dart test/data/project_repository_test.dart -v`
Expected: PASS.

- [ ] **Step 5: Add v9→v10 migration test + run**

Follow the existing `test/data/migration_test.dart` v5→v6 pattern: create a v9 db with a project row, upgrade, assert `notes == null` and `priority == 0`, assert `resetAll()` clears projects. Run: `flutter test test/data/migration_test.dart -v`. Expected: PASS.

- [ ] **Step 6: Analyze + commit**

Run: `flutter analyze`
Expected: clean.

```bash
git add lib/data/tables/projects_table.dart lib/data/database.dart lib/data/daos/project_dao.dart lib/data/repositories/project_repository.dart test/data/project_dao_test.dart test/data/migration_test.dart lib/data/database.g.dart lib/data/daos/project_dao.g.dart
git commit -m "feat: projects v10 notes priority rename"
```

---

### Task 2: Grouped detail query + pure velocity/sort/validation

**Files:**
- Modify: `lib/data/repositories/project_repository.dart:11-23` (`ProjectDetail` gains `sessionsCount`, `lastWorkedAt`)
- Modify: `lib/data/daos/session_dao.dart` (add `sessionsForProject(List<int> eventIds)` grouped query — one round-trip)
- Modify: `lib/features/projects/model/project_progress.dart` (add `velocityLast7Days`, sort comparators, `validateNotes`, `validatePriority`; keep `compute`, `isReadyToComplete`, `isOverdue` signatures unchanged)
- Test: `test/features/projects/project_progress_test.dart`, `test/data/project_repository_test.dart`

**Interfaces:**
- Consumes: `ProjectDao.eventsForProject`, new `SessionDao.sessionsForProject`.
- Produces: `ProjectDetail(project, events, plannedMinutes, actualMinutes, sessionsCount, lastWorkedAt)`; `List<int> velocityLast7Days({required List<SessionRow> doneSessions, required DateTime now})`; `int compareByDeadline/ProjectRow`, `compareByProgress`, `compareByRecent`, `compareByTitle`; `String? validateNotes(String)`, `validatePriority(int?)`.

- [ ] **Step 1: Write failing pure tests**

```dart
test('velocity maps done minutes to last 7 days, abandoned excluded', () {
  // doneSessions: 45m two days ago, 30m today, 60m abandoned yesterday (ignored).
  final v = velocityLast7Days(doneSessions: sessions, now: DateTime(2026, 10, 17));
  expect(v.length, 7);
  expect(v.last, 30); // today
  expect(v[5], 45);
  expect(v[6 - 1], isNot(60));
});
test('sort: null deadlines last, null lastWorked last', () {
  expect(compareByDeadline(aNoDeadline, bWithDeadline), greaterThan(0));
});
test('validateNotes rejects over 500', () {
  expect(validateNotes('x' * 501), isNotNull);
  expect(validateNotes('ok'), isNull);
});
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/projects/project_progress_test.dart -v`
Expected: FAIL — functions undefined.

- [ ] **Step 3: Implement grouped query + pure functions**

```dart
// session_dao.dart — add (one query, no per-event loop):
Future<List<SessionRow>> sessionsForProject(List<int> eventIds) =>
    (select(sessions)..where((s) => s.eventId.isIn(eventIds))).get();
```

```dart
// project_repository.dart — rewrite _loadDetail core:
final events = await _db.eventDao.eventsForProject(id);
final sessions = events.isEmpty
    ? <SessionRow>[]
    : await _db.sessionDao.sessionsForProject(events.map((e) => e.id).toList());
final done = sessions.where((s) => doneOutcomes.contains(s.outcome)).toList();
final plannedMinutes = events.fold<int>(0, (sum, e) => sum + (e.endMinute - e.startMinute));
final actualMinutes = done.fold<int>(0, (sum, s) => sum + s.activeSeconds) ~/ 60;
final lastWorkedAt = done.isEmpty ? null : done.map((s) => s.endedAt ?? s.startedAt).reduce((a, b) => a.isAfter(b) ? a : b);
return ProjectDetail(project: project, events: events, plannedMinutes: plannedMinutes, actualMinutes: actualMinutes, sessionsCount: done.length, lastWorkedAt: lastWorkedAt);
```

```dart
// project_progress.dart — add:
List<int> velocityLast7Days({required List<dynamic> doneSessions, required DateTime now, required int Function(dynamic) minutesOf, required DateTime Function(dynamic) dayOf}) { /* group by startOfDay, 7 buckets ending today */ }
int compareByDeadline(ProjectRow a, ProjectRow b) => /* nulls last, then date, then title */;
```

Keep the math identical to today (truncation `~/ 60`, done outcomes only). `lastWorkedAt` nullable.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/projects/project_progress_test.dart test/data/project_repository_test.dart -v`
Expected: PASS (repository test asserts one grouped call path still yields same minutes as before + exposes `sessionsCount`/`lastWorkedAt`).

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/project_repository.dart lib/data/daos/session_dao.dart lib/features/projects/model/project_progress.dart test/features/projects/project_progress_test.dart test/data/project_repository_test.dart
git commit -m "feat: grouped project detail query plus velocity and sort helpers"
```

---

### Task 3: Hub — search/sort/filter + row badges + Completed/Archived split

**Files:**
- Modify: `lib/core/strings.dart:528-567` (add keys: search hint, no-match, sort labels, sessions/worked/tasks lines, completed/archived titles, completed-on line)
- Modify: `lib/features/projects/providers.dart` (add `projectsViewProvider` Notifier holding `query`, `sort`, `toneFilter`, `overdueOnly`)
- Modify: `lib/features/projects/projects_screen.dart:176-329` (`_HubBody` gains search field + sort menu + filter chips; `done` splits into `completed` (status 1) and `archived` (status 2))
- Modify: `lib/features/projects/widgets/project_row.dart:1-84` (adds sessions/last-worked line, subtask-count slot defaulting to null in Slice 1, priority dot)
- Test: `test/features/projects/projects_screen_test.dart`, `test/features/projects/projects_tab_test.dart`, `test/features/projects/project_row_test.dart`

**Interfaces:**
- Consumes: `projectListProvider`, `projectDetailProvider(id)` (`sessionsCount`, `lastWorkedAt`), `projectsViewProvider` state.
- Produces: filtered/sorted `List<ProjectRow>` for `_HubBody`; no new public providers beyond `projectsViewProvider`.

- [ ] **Step 1: Write failing widget test**

```dart
testWidgets('hub search filters and sort menu orders by deadline', (tester) async {
  // Seed 3 projects (overrides projectsRepositoryProvider with fake).
  // Enter 'beta' in search → only Beta visible.
  // Clear, sort by Deadline → earliest deadline first.
  // Overdue chip → only overdue visible.
});
testWidgets('row shows sessions and last-worked', (tester) async {
  // project with sessionsCount 4, lastWorkedAt 2 days ago → finds '4 sessions · worked 2d ago'.
});
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/projects/projects_screen_test.dart -v`
Expected: FAIL — search/sort widgets absent.

- [ ] **Step 3: Implement hub + row (Slice 1 scope: subtask count hidden when null)**

Search `TextField` with `Strings.projectsSearchHint`; sort `PopupMenuButton` (Deadline/Progress/Recently worked/Title, nulls last); filter chips (All/Focus/Life/Inbox + Overdue). Row: keep ring + title + `actual of target/planned` + deadline chip (chip text now from `Strings.deadline*` keys, not hardcoded English — move `deadlineLabel` copy into `Strings` and have `project_progress.dart` call it), plus second line `Strings.projectsMeta(sessionsCount, lastWorkedLabel)` and priority dot (`Container` 8px in priority color token when priority > 0). Split sections: `Strings.projectsCompleted` (status 1, expanded) and `Strings.projectsArchived` (status 2, collapsed `ExpansionTile`). `relativeDayLabel(DateTime?, now)` helper in `project_progress.dart` returns `''`/`'today'`/`'yesterday'`/`'Nd ago'` via `Strings` keys.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/projects/ -v`
Expected: PASS. Then `flutter analyze`. Expected: clean.

- [ ] **Step 5: Commit**

```bash
git add lib/core/strings.dart lib/features/projects/providers.dart lib/features/projects/projects_screen.dart lib/features/projects/widgets/project_row.dart lib/features/projects/model/project_progress.dart test/features/projects/
git commit -m "feat: projects hub search sort filters and richer rows"
```

---

### Task 4: Detail — rename/notes/priority/deadline-chips/target-hours/velocity/per-event actuals/undo

**Files:**
- Modify: `lib/core/strings.dart` (add: rename title/hint, notes title/hint/counter, priority labels, deadline quick chips, target-hours hint, velocity title/empty, per-event actuals line, completed-on line, undo labels)
- Modify: `lib/features/projects/widgets/project_detail.dart:82-451` (`_DetailBody` + dialogs)
- Test: extend `test/features/projects/` detail tests (rename dialog, notes save, priority pick, deadline quick chip, target-hours conversion, per-event actuals line, undo snackbar)

**Interfaces:**
- Consumes: Task 1 writes (`updateTitle/Notes/Priority/Deadline/Target`), Task 2 detail fields + `velocityLast7Days`, existing `onOpenDay`.
- Produces: same `ProjectDetailView(projectId, onOpenDay)` signature — no caller changes.

- [ ] **Step 1: Write failing detail widget tests**

```dart
testWidgets('title tap renames', (t) async { /* tap title → dialog → save 'Beta' → verify repo.updateTitle called */ });
testWidgets('target entered in hours stores minutes', (t) async { /* enter '20' hours → expect updateTarget(id, 1200) */ });
testWidgets('per-event row shows actuals', (t) async { /* finds '45m of 1h' */ });
testWidgets('complete shows undo', (t) async { /* tap complete → snackbar Undo → tap → status back to 0 */ });
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/projects/project_detail_test.dart -v` (create if missing, following `projects_screen_test.dart` harness)
Expected: FAIL.

- [ ] **Step 3: Implement detail changes**

Title `InkWell` → `_RenameDialog` (1–80, save disabled until valid → `updateTitle`). Notes card (`maxLines: null`, counter `note.length/500` via `Strings.debriefNoteCounter` pattern → new `Strings.projectsNotesCounter`). Priority 4 `ChoiceChip`s → `updatePriority`. Deadline row keeps date picker but adds quick chips Today/Tomorrow/Next week + Clear (all via `Strings`); dates render via `friendlyDate(DateTime)` (`Fri, Oct 17`) — delete `_dayLabel` `YYYY-MM-DD`. Target dialog: input in hours (decimal allowed, e.g. `1.5` → 90 min), converts `hours * 60 → round()` then `validateTargetMinutes`; displays `formatDurationMinutes` as today. Velocity: 7 bars (`Row` of 7 `Expanded` rounded bars, height scaled to max, empty week → `Strings.projectsVelocityEmpty`). Per-event rows: `ListTile(title, subtitle: 'Fri, Oct 17 · 9:00–10:30 · 45m of 1h')` — per-event actuals from the grouped sessions map (pass `Map<eventId, minutes>` down from repository detail or recompute client-side from watched sessions; keep O(n)). `completedAt` line when status 1. Complete/archive → `ScaffoldMessenger` Undo (undo complete → `reopen`, undo archive → restore prior status preserving `completedAt`); delete stays confirm-only.

- [ ] **Step 4: Run tests + analyze**

Run: `flutter test test/features/projects/ -v`
Expected: PASS. Run: `flutter analyze`. Expected: clean.

- [ ] **Step 5: Commit**

```bash
git add lib/core/strings.dart lib/features/projects/widgets/project_detail.dart test/features/projects/
git commit -m "feat: rich project detail with rename notes velocity and undo"
```

---

### Task 5: Slice 1 regression gate

**Files:** none (verification only).

- [ ] **Step 1: Run full gates**

Run: `flutter analyze`
Expected: clean.
Run: `flutter test`
Expected: all PASS (dial goldens unchanged — no `--update-goldens`).

- [ ] **Step 2: Commit (empty if clean — otherwise fix first, no empty commits)**

Only commit if fixes were needed during this task.

---

### Task 6: Schema v11 — subtasks table + cascade + migration

**Files:**
- Create: `lib/data/tables/project_subtasks_table.dart`
- Modify: `lib/data/database.dart` (`tables: [..., ProjectSubtasks]`, `schemaVersion => 11`, migration `if (from < 11) await migrator.createTable(projectSubtasks)`, `resetAll` clears it)
- Create or extend: `lib/data/daos/subtask_dao.dart` (`watchForProject`, `create`, `toggle`, `rename`, `remove`) — or extend `ProjectDao` if fewer than ~80 lines; prefer a focused `SubtaskDao`.
- Modify: `lib/data/repositories/project_repository.dart` (add `SubtaskRepository` interface + `DriftSubtaskRepository`) and `lib/data/providers.dart` (expose `subtaskRepositoryProvider`)
- Modify: `lib/data/daos/project_dao.dart:57-62` (`deleteAndUnlink` also deletes subtasks in the same transaction)
- Test: `test/data/subtask_dao_test.dart` (new), `test/data/migration_test.dart` (v10→v11)

**Interfaces:**
- Consumes: `projects.id`.
- Produces: `watchSubtasks(projectId) → Stream<List<SubtaskRow>>`; `create(projectId, title) → Future<int>`; `toggle(id, isDone)`; `rename(id, title)`; `remove(id)`; `subtaskCountsProvider(projectId) → {done, total}` derived client-side.

- [ ] **Step 1: Write failing subtask tests**

```dart
test('subtask crud + cascade', () async {
  final projectId = await createProject('Alpha');
  final sid = await subtasks.create(projectId, 'First step');
  await subtasks.toggle(sid, true);
  expect((await watchOnce()).single.isDone, true);
  await projects.deleteAndUnlink(projectId);
  expect(await watchOnce(), isEmpty); // cascade
});
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/data/subtask_dao_test.dart -v`
Expected: FAIL — table/DAO missing.

- [ ] **Step 3: Implement table + DAO + repo + migration + codegen**

```dart
// lib/data/tables/project_subtasks_table.dart:
@DataClassName('SubtaskRow')
class ProjectSubtasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withLength(min: 1, max: 80)();
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer()();
  DateTimeColumn get createdAt => dateTime()();
}
```

Codegen after wiring into `@DriftDatabase(tables: [...])`. `create` sets `sortOrder = max+1` (or `createdAt.millisecondsSinceEpoch` fallback — pick one and document). Validation (1–80) enforced in repository, not just UI.

- [ ] **Step 4: Run tests**

Run: `flutter test test/data/subtask_dao_test.dart test/data/migration_test.dart -v`
Expected: PASS. Run: `flutter analyze`. Expected: clean.

- [ ] **Step 5: Commit**

```bash
git add lib/data/tables/project_subtasks_table.dart lib/data/database.dart lib/data/daos/subtask_dao.dart lib/data/repositories/project_repository.dart lib/data/providers.dart lib/data/daos/project_dao.dart test/data/subtask_dao_test.dart test/data/migration_test.dart lib/data/database.g.dart
git commit -m "feat: project subtasks table with cascade"
```

---

### Task 7: Subtasks UI + hub counts + deadline reminders

**Files:**
- Create: `lib/features/projects/widgets/subtask_list.dart`
- Modify: `lib/features/projects/widgets/project_detail.dart` (embed `SubtaskList` section)
- Modify: `lib/features/projects/widgets/project_row.dart` (show `done/total tasks` when non-null)
- Modify: `lib/core/strings.dart` (subtask add/hint/empty/delete/undo-copy)
- Modify: notification wiring — find `NotificationScheduler` (see `2026-10-09-step-5-notifications-design.md`): add `scheduleProjectDeadline(ProjectRow)` + `cancelProjectDeadline(id)`; call from repository writes (`updateDeadline`, `complete`, `reopen`, `archive`, `deleteAndUnlink`) or a provider-side listener — pick one, document in code.
- Test: `test/features/projects/subtask_list_test.dart` (new), `test/features/projects/project_row_test.dart` (counts), reminder unit test with fake clock (schedule day-before 09:00 device-local, no schedule when past/complete/deadline-null, cancel on clear/complete/delete)

**Interfaces:**
- Consumes: `watchSubtasks(projectId)`, `NotificationScheduler` existing channel.
- Produces: `SubtaskList(projectId)` widget; reminder side-effects only (no new permissions, no new provider state).

- [ ] **Step 1: Write failing UI + reminder tests**

```dart
testWidgets('add/check/rename/delete subtask', (t) async { /* inline add 'Step' → checkbox tap → done/total updates → delete removes */ });
test('deadline reminder schedules day-before 09:00', () async {
  // deadline Oct 20 → expect scheduled Oct 19 09:00; past deadline → no schedule; complete → cancel called.
});
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/projects/subtask_list_test.dart -v`
Expected: FAIL — widget missing.

- [ ] **Step 3: Implement subtask list + counts + reminders**

Unchecked (creation order) then checked (greyed + strikethrough); inline add field + Add button (save disabled until 1–80 valid); tap checkbox → `toggle`; trailing menu → Rename/Delete. Hub counts via watching subtasks per visible project (bounded, same pattern as Task 3) or a `subtaskCountsProvider` family — pick one. Reminders: exactly one pending notification per active project with a deadline (`id` namespaced e.g. `project_<id>`), 09:00 day-before device-local; reschedule on deadline change; cancel on clear/complete/archive/delete; never for past deadlines; no-op when notifications denied.

- [ ] **Step 4: Run tests + analyze**

Run: `flutter test test/features/projects/ test/data/ -v`
Expected: PASS. Run: `flutter analyze`. Expected: clean.

- [ ] **Step 5: Commit**

```bash
git add lib/features/projects/widgets/subtask_list.dart lib/features/projects/widgets/project_detail.dart lib/features/projects/widgets/project_row.dart lib/core/strings.dart test/features/projects/subtask_list_test.dart
git commit -m "feat: subtasks checklist plus deadline reminders"
```

---

### Task 8: Final regression (both slices)

**Files:** none (verification only; fix-forward if red).

- [ ] **Step 1: Full gates**

Run: `flutter analyze`
Expected: clean.
Run: `flutter test`
Expected: all PASS, including the no-hardcoded-colour test and migration tests. No golden regen (dial pixels untouched; hub/detail are new/changed screens covered by widget tests, not goldens).

- [ ] **Step 2: Manual smoke (document result in commit message or PR description)**

Create project → rename → notes → priority → deadline quick chip → target hours → link 2 events → run a session → detail shows per-event actuals + velocity bar → subtasks add/check → hub search/sort/filter → complete → Undo → archive → delete (unlinks, events stay). Deadline reminder fires day-before 09:00 (verify via scheduled-list debug or fake clock in test).

## Self-Review

**1. Spec coverage:** §1 schema v10/v11 + grouped query + velocity → Tasks 1, 2, 6. §2 hub (search/sort/filter, badges, Completed/Archived split) → Task 3. §2 detail (rename, notes, priority, quick chips, friendly dates, target-hours, velocity bars, per-event actuals, completedAt, undo) → Task 4. §2 subtasks → Tasks 6–7. §3 data flow (view provider, writes, reminders) → Tasks 3, 4, 7. §4 validation/empty states/overlap/delete-undo rules → Tasks 3, 4, 7 (tests assert each empty state + validation). §5 testing gates → Tasks 5, 8. §6 review story → covered by Tasks 3–4 screenshots-able UI.

**2. Placeholder scan:** no TBD/TODO; every step names exact files, signatures, test commands, and expected outcomes; no "similar to Task N" — code repeated per task.

**3. Type consistency:** `ProjectDetail` extension (`sessionsCount: int`, `lastWorkedAt: DateTime?`) defined in Task 2 and consumed in Tasks 3–4 with the same names. `velocityLast7Days` signature fixed in Task 2, reused in Task 4. `SubtaskRow` (`id`, `projectId`, `title`, `isDone`, `sortOrder`, `createdAt`) fixed in Task 6, consumed in Task 7. `updateTitle/Notes/Priority` signatures fixed in Task 1, used in Task 4. Reminder API (`scheduleProjectDeadline(ProjectRow)`, `cancelProjectDeadline(id)`) fixed in Task 7 only.
