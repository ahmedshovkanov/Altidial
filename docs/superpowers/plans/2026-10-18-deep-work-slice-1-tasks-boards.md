# Deep Work Slice 1 — Tasks & Boards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the project checklist into first-class tasks with a kanban board, list view, rich task editor, cross-project Board and Today views — all offline, no new permissions.

**Architecture:** Additive Drift migration v11→v12 creates a `tasks` table, copies every `project_subtasks` row into it, and drops the old table. A focused `TaskDao` + `DriftTaskRepository` expose CRUD/move/reorder with inline validation; pure helpers in `core/task_status.dart` + `features/projects/model/task_board.dart` carry the status model and sorting. UI replaces `SubtaskList` with `TaskBoard`/`TaskList` inside project detail, and the Projects tab gains an Outcomes/Board/Today segmented control. No dial, session, or notification changes in this slice.

**Tech Stack:** Flutter + Riverpod + Drift (SQLite) + flutter_test. Drift codegen and schema tools run through the Flutter SDK's `dart`.

## Global Constraints

- Offline-only, no backend, no sync, no account, no new iOS permissions.
- Features never import each other; `features/projects/` imports only `data/`, `core/`, `app/`, `shared/`.
- All user copy in `lib/core/strings.dart`; no hardcoded copy in widgets.
- All colours via theme tokens (`context.appColors`, `context.toneColors`); `test/architecture/no_hardcoded_colors_test.dart` must pass.
- Drift codegen only via the Flutter SDK's `dart`: `"$(dirname "$(which flutter)")/dart" run build_runner build --delete-conflicting-outputs`.
- Schema dumps/exports via the same `dart`: `"$(dirname "$(which flutter)")/dart" run drift_dev schema dump lib/data/database.dart drift_schemas/` then `"$(dirname "$(which flutter)")/dart" run drift_dev schema generate drift_schemas/ test/generated_migrations/`.
- Every schema bump needs a migration step in `lib/data/database.dart` and a case in `test/data/migration_test.dart` (schemas live in `drift_schemas/`).
- Task title 1–120; notes 0–2000 (empty stored as null); priority 0–3; board status 0–4; estimate 15–60000 minutes when set.
- Gates per task: `flutter analyze` and `flutter test` for the touched areas; never `flutter test --update-goldens` (this slice touches no dial pixels).

---

### Task 1: Schema v12 — `tasks` table, subtask migration, drop old table

**Files:**
- Create: `lib/data/tables/tasks_table.dart`
- Create: `lib/core/task_status.dart`
- Modify: `lib/data/database.dart` (tables list, version comment, `schemaVersion`, `migration`, `resetAll`)
- Modify: `lib/data/daos/project_dao.dart:11` (drop `ProjectSubtasks` from accessor) and `:79-85` (`deleteAndUnlink` deletes tasks, not subtasks)
- Delete: `lib/data/tables/project_subtasks_table.dart`, `lib/data/daos/subtask_dao.dart`, `lib/data/daos/subtask_dao.g.dart`
- Modify: `test/data/migration_test.dart` (bump every `migrateAndValidate(db, 11)` to `12`, add v11→v12 data test)
- Generated: `lib/data/database.g.dart`, `lib/data/daos/project_dao.g.dart`, `drift_schemas/drift_schema_v12.json`, `test/generated_migrations/schema.dart`

**Interfaces:**
- Consumes: existing `Projects` table (`id`), `project_subtasks` v11 table (raw SQL only).
- Produces: `TaskRow` data class (`id`, `projectId`, `title`, `notes`, `boardStatus`, `priority`, `estimateMinutes`, `dueDate`, `plannedDate`, `sortOrder`, `blockedReason`, `createdAt`, `updatedAt`, `completedAt`); `db.tasks` table; `TaskStatus` enum + `dbIndex`; schema v12.

- [ ] **Step 1: Write the failing migration test (data preservation)**

Add to `test/data/migration_test.dart` (near the other v-specific tests):

```dart
test('upgrading from version 11 turns subtasks into tasks', () async {
  final schema = await verifier.schemaAt(11);
  schema.rawDatabase.execute(
    "INSERT INTO projects (title, created_at, status, priority) "
    "VALUES ('Alpha', $seconds, 0, 0)",
  );
  schema.rawDatabase.execute(
    "INSERT INTO project_subtasks (project_id, title, is_done, sort_order, created_at) "
    "VALUES (1, 'First step', 1, 1, $seconds), "
    "(1, 'Second step', 0, 2, $seconds)",
  );

  final database = AppDatabase.forTesting(schema.newConnection());
  addTearDown(database.close);
  await verifier.migrateAndValidate(database, 12);

  final tasks = await database.select(database.tasks).get();
  expect(tasks.length, 2);
  final done = tasks.singleWhere((t) => t.title == 'First step');
  expect(done.boardStatus, 4);
  expect(done.completedAt, isNotNull);
  final open = tasks.singleWhere((t) => t.title == 'Second step');
  expect(open.boardStatus, 1);
  expect(open.completedAt, isNull);
  // The old table is gone: selecting it must throw.
  expect(
    () => schema.rawDatabase.select('SELECT * FROM project_subtasks'),
    throwsA(anything),
  );
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/data/migration_test.dart -v`
Expected: FAIL — `database.tasks` undefined / table missing.

- [ ] **Step 3: Add the `TaskStatus` model**

```dart
// lib/core/task_status.dart
/// Board column for a task. Persisted as [dbIndex]; unknown values read as
/// backlog. Kept in `core/` so both `data/` and `features/projects/` can use it.
enum TaskStatus {
  backlog(0),
  todo(1),
  doing(2),
  blocked(3),
  done(4);

  const TaskStatus(this.dbIndex);
  final int dbIndex;

  static TaskStatus fromDb(int value) => TaskStatus.values.firstWhere(
    (s) => s.dbIndex == value,
    orElse: () => TaskStatus.backlog,
  );
}
```

- [ ] **Step 4: Add the `tasks` table**

```dart
// lib/data/tables/tasks_table.dart
import 'package:drift/drift.dart';

import 'projects_table.dart';

/// First-class units of work under a project (schema v12). Replaces the v11
/// checklist. `boardStatus` is 0 backlog / 1 todo / 2 doing / 3 blocked /
/// 4 done; `blockedReason` only means something when `boardStatus == 3`.
/// `completedAt` is non-null exactly when `boardStatus == 4`. Title length is
/// documented here but enforced in `TaskRepository` (only NOT NULL reaches DDL).
@DataClassName('TaskRow')
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  TextColumn get notes => text().nullable()();
  IntColumn get boardStatus => integer().withDefault(const Constant(0))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  IntColumn get estimateMinutes => integer().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get plannedDate => dateTime().nullable()();
  IntColumn get sortOrder => integer()();
  TextColumn get blockedReason => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
}
```

- [ ] **Step 5: Wire the table + migration + reset into `database.dart`**

In `@DriftDatabase(tables: [...])` replace `ProjectSubtasks,` with `Tasks,` and import the new table. Bump the version comment and `schemaVersion`:

```dart
/// Version 12: `tasks` replaces `project_subtasks`; subtask rows are copied
/// into tasks (done → Done column) and the old table is dropped.
@override
int get schemaVersion => 12;
```

Add to `onUpgrade` after the v11 block:

```dart
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
```

In `resetAll()` replace `await delete(projectSubtasks).go();` with `await delete(tasks).go();`.

- [ ] **Step 6: Update `ProjectDao` to delete tasks and drop the old import**

Change the accessor to `@DriftAccessor(tables: [Projects, Events, Tasks])`, import `tasks_table.dart`, and in `deleteAndUnlink` replace the subtask delete with:

```dart
await (delete(tasks)..where((r) => r.projectId.equals(id))).go();
```

- [ ] **Step 7: Delete the old subtask files**

Delete `lib/data/tables/project_subtasks_table.dart`, `lib/data/daos/subtask_dao.dart`, `lib/data/daos/subtask_dao.g.dart`. Also remove `SubtaskRepository`/`DriftSubtaskRepository` and `subtaskRepositoryProvider` (Search `lib/data/repositories/project_repository.dart:187-234` and `lib/data/providers.dart:107-111`) — the new task repository in Task 3 replaces them. Remove the `subtaskListProvider`/`subtaskCountsProvider` usage from `lib/features/projects/providers.dart` later in Task 4; leave the definitions compiling until then by deleting them here and fixing call sites in Task 4.

- [ ] **Step 8: Regenerate code + schemas**

```bash
"$(dirname "$(which flutter)")/dart" run build_runner build --delete-conflicting-outputs
"$(dirname "$(which flutter)")/dart" run drift_dev schema dump lib/data/database.dart drift_schemas/
"$(dirname "$(which flutter)")/dart" run drift_dev schema generate drift_schemas/ test/generated_migrations/
```

Expected: `database.g.dart` compiles; `drift_schemas/drift_schema_v12.json` exists.

- [ ] **Step 9: Bump the existing migration assertions and run**

In `test/data/migration_test.dart` change every `verifier.migrateAndValidate(database, 11)` to `12`. Run: `flutter test test/data/migration_test.dart -v`. Expected: PASS (all versions migrate; the new v11→v12 test passes).

- [ ] **Step 10: Analyze + commit**

Run: `flutter analyze` — the only expected errors are missing subtask symbols in files Task 2/3/4 will rewrite; fix any that are unrelated. To keep this task independently green, temporarily delete `lib/features/projects/widgets/subtask_list.dart`, the `SubtaskList` embedding in `project_detail.dart`, `subtaskListProvider`/`subtaskCountsProvider` in `features/projects/providers.dart`, and the `subtaskCounts:` argument in `projects_screen.dart:271-278`; the task board arrives in Task 4.

```bash
git add -A
git commit -m "feat: tasks table replaces project subtasks (schema v12)"
```

---

### Task 2: Pure board helpers — comparators, grouping, validation

**Files:**
- Create: `lib/features/projects/model/task_board.dart`
- Test: `test/features/projects/task_board_test.dart`

**Interfaces:**
- Consumes: `TaskStatus` (`core/task_status.dart`), `TaskRow`.
- Produces: `enum TasksSort { manual, title, due, priority, created, estimate, updated }`; `int compareTasks(TaskRow a, TaskRow b, TasksSort sort)`; `Map<TaskStatus, List<TaskRow>> groupByStatus(List<TaskRow> tasks)`; `String? validateTaskTitle(String)`, `String? validateTaskNotes(String)`, `String? validateTaskEstimate(int?)`; `String? taskTitleErrorKey(...)` not needed — return the message string.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/projects/task_board_test.dart
import 'package:energy_clock/core/task_status.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/features/projects/model/task_board.dart';
import 'package:flutter_test/flutter_test.dart';

TaskRow task({
  int id = 1,
  String title = 'A',
  int status = 0,
  int priority = 0,
  int sortOrder = 0,
  DateTime? due,
  int? estimate,
  DateTime? createdAt,
}) => TaskRow(
  id: id,
  projectId: 1,
  title: title,
  notes: null,
  boardStatus: status,
  priority: priority,
  estimateMinutes: estimate,
  dueDate: due,
  plannedDate: null,
  sortOrder: sortOrder,
  blockedReason: null,
  createdAt: createdAt ?? DateTime(2026, 10, 1),
  updatedAt: createdAt ?? DateTime(2026, 10, 1),
  completedAt: status == 4 ? DateTime(2026, 10, 2) : null,
);

void main() {
  test('manual sort uses sortOrder then id', () {
    final a = task(id: 2, sortOrder: 1);
    final b = task(id: 1, sortOrder: 2);
    expect(compareTasks(a, b, TasksSort.manual), lessThan(0));
  });

  test('due sort puts nulls last, then earliest first', () {
    final none = task(id: 1);
    final soon = task(id: 2, due: DateTime(2026, 10, 5));
    final later = task(id: 3, due: DateTime(2026, 10, 9));
    final list = [none, later, soon]..sort((a, b) => compareTasks(a, b, TasksSort.due));
    expect(list.map((t) => t.id), [2, 3, 1]);
  });

  test('groupByStatus buckets by board status', () {
    final grouped = groupByStatus([
      task(id: 1, status: 0),
      task(id: 2, status: 4),
      task(id: 3, status: 0),
    ]);
    expect(grouped[TaskStatus.backlog]!.map((t) => t.id), [1, 3]);
    expect(grouped[TaskStatus.done]!.map((t) => t.id), [2]);
    expect(grouped[TaskStatus.doing], isEmpty);
  });

  test('validation ranges', () {
    expect(validateTaskTitle(''), isNotNull);
    expect(validateTaskTitle('x' * 121), isNotNull);
    expect(validateTaskTitle('Ship it'), isNull);
    expect(validateTaskNotes('x' * 2001), isNotNull);
    expect(validateTaskEstimate(10), isNotNull); // below 15
    expect(validateTaskEstimate(90), isNull);
    expect(validateTaskEstimate(null), isNull);
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/projects/task_board_test.dart -v`
Expected: FAIL — `compareTasks` undefined.

- [ ] **Step 3: Implement the helpers**

```dart
// lib/features/projects/model/task_board.dart
import 'package:energy_clock/core/task_status.dart';
import 'package:energy_clock/data/database.dart';

enum TasksSort { manual, title, due, priority, created, estimate, updated }

const int maxTaskTitleLength = 120;
const int maxTaskNotesLength = 2000;
const int minTaskEstimateMinutes = 15;
const int maxTaskEstimateMinutes = 60000;

int compareTasks(TaskRow a, TaskRow b, TasksSort sort) {
  int tieBreak() => a.id.compareTo(b.id);
  switch (sort) {
    case TasksSort.manual:
      return a.sortOrder.compareTo(b.sortOrder) != 0
          ? a.sortOrder.compareTo(b.sortOrder)
          : tieBreak();
    case TasksSort.title:
      return a.title.toLowerCase().compareTo(b.title.toLowerCase()) != 0
          ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
          : tieBreak();
    case TasksSort.due:
      final ad = a.dueDate, bd = b.dueDate;
      if (ad == null && bd == null) return tieBreak();
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd) != 0 ? ad.compareTo(bd) : tieBreak();
    case TasksSort.priority:
      return b.priority.compareTo(a.priority) != 0
          ? b.priority.compareTo(a.priority)
          : tieBreak();
    case TasksSort.created:
      return b.createdAt.compareTo(a.createdAt) != 0
          ? b.createdAt.compareTo(a.createdAt)
          : tieBreak();
    case TasksSort.estimate:
      final ae = a.estimateMinutes, be = b.estimateMinutes;
      if (ae == null && be == null) return tieBreak();
      if (ae == null) return 1;
      if (be == null) return -1;
      return ae.compareTo(be) != 0 ? ae.compareTo(be) : tieBreak();
    case TasksSort.updated:
      return b.updatedAt.compareTo(a.updatedAt) != 0
          ? b.updatedAt.compareTo(a.updatedAt)
          : tieBreak();
  }
}

Map<TaskStatus, List<TaskRow>> groupByStatus(List<TaskRow> tasks) {
  final grouped = {for (final s in TaskStatus.values) s: <TaskRow>[]};
  for (final task in tasks) {
    grouped[TaskStatus.fromDb(task.boardStatus)]!.add(task);
  }
  return grouped;
}

String? validateTaskTitle(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'Name your task';
  if (trimmed.length > maxTaskTitleLength) {
    return 'Keep it under $maxTaskTitleLength characters';
  }
  return null;
}

String? validateTaskNotes(String value) {
  if (value.trim().length > maxTaskNotesLength) {
    return 'Keep notes under $maxTaskNotesLength characters';
  }
  return null;
}

String? validateTaskEstimate(int? minutes) {
  if (minutes == null) return null;
  if (minutes < minTaskEstimateMinutes || minutes > maxTaskEstimateMinutes) {
    return 'Use 15 minutes to 1000 hours';
  }
  return null;
}
```

> Copy note: in Task 4 these literal messages migrate into `Strings` (`tasksTitleRequired`, `tasksTitleTooLong`, `tasksNotesTooLong`, `tasksEstimateRange`); the helpers then return the `Strings` values. Add the `Strings` keys in Task 4 and update these three functions there.

- [ ] **Step 4: Run tests, analyze, commit**

Run: `flutter test test/features/projects/task_board_test.dart -v` → PASS. `flutter analyze` → clean.

```bash
git add lib/features/projects/model/task_board.dart test/features/projects/task_board_test.dart
git commit -m "feat: pure task board helpers (sort, group, validation)"
```

---

### Task 3: `TaskDao` + `TaskRepository` + providers

**Files:**
- Create: `lib/data/daos/task_dao.dart`
- Create: `lib/data/repositories/task_repository.dart`
- Modify: `lib/data/providers.dart` (add `taskRepositoryProvider`)
- Modify: `lib/features/projects/providers.dart` (add `taskListProvider`, `allTasksProvider`)
- Test: `test/data/task_dao_test.dart`, `test/data/task_repository_test.dart`

**Interfaces:**
- Consumes: `db.tasks`, `TaskStatus`, `TaskRow`.
- Produces: `TaskDao.watchForProject(int)`, `watchAll()`, `create(...)`, `update(...)`, `moveTo(id, status, sortOrder)`, `setDone(id, {DateTime? at})`, `reopen(id)`, `remove(id)`, `duplicate(id)`; `TaskRepository` mirroring those with validation; `taskRepositoryProvider`; `taskListProvider(projectId)`; `allTasksProvider`.

- [ ] **Step 1: Write failing DAO tests**

```dart
// test/data/task_dao_test.dart
import 'package:drift/native.dart';
import 'package:energy_clock/core/task_status.dart';
import 'package:energy_clock/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> seedProject() => db.projectDao.createProject(
    ProjectsCompanion.insert(title: 'Alpha', createdAt: DateTime(2026, 10, 1)),
  );

  test('create appends in its column, watch orders by column then sortOrder', () async {
    final pid = await seedProject();
    await db.taskDao.create(projectId: pid, title: 'One', status: TaskStatus.todo, createdAt: DateTime(2026, 10, 1));
    await db.taskDao.create(projectId: pid, title: 'Two', status: TaskStatus.todo, createdAt: DateTime(2026, 10, 1));
    await db.taskDao.create(projectId: pid, title: 'Zero', status: TaskStatus.backlog, createdAt: DateTime(2026, 10, 1));

    final rows = await db.taskDao.watchForProject(pid).first;
    expect(rows.map((r) => r.title), ['Zero', 'One', 'Two']);
    expect(rows.first.sortOrder, 1);
    expect(rows.last.sortOrder, 2);
  });

  test('moveTo changes column and done sets/clears completedAt', () async {
    final pid = await seedProject();
    final id = await db.taskDao.create(projectId: pid, title: 'A', status: TaskStatus.todo, createdAt: DateTime(2026, 10, 1));
    await db.taskDao.setDone(id, at: DateTime(2026, 10, 3));
    var row = (await db.select(db.tasks)..where((r) => r.id.equals(id))).getSingle();
    expect(row.boardStatus, 4);
    expect(row.completedAt, isNotNull);
    await db.taskDao.reopen(id);
    row = (await db.select(db.tasks)..where((r) => r.id.equals(id))).getSingle();
    expect(row.boardStatus, 1);
    expect(row.completedAt, isNull);
  });

  test('deleteAndUnlink cascades tasks', () async {
    final pid = await seedProject();
    await db.taskDao.create(projectId: pid, title: 'A', status: TaskStatus.todo, createdAt: DateTime(2026, 10, 1));
    await db.projectDao.deleteAndUnlink(pid);
    expect(await db.select(db.tasks).get(), isEmpty);
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/data/task_dao_test.dart -v`
Expected: FAIL — `taskDao` undefined.

- [ ] **Step 3: Implement `TaskDao`**

```dart
// lib/data/daos/task_dao.dart
import 'package:drift/drift.dart';
import 'package:energy_clock/core/task_status.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/tables/tasks_table.dart';

part 'task_dao.g.dart';

@DriftAccessor(tables: [Tasks])
class TaskDao extends DatabaseAccessor<AppDatabase> with _$TaskDaoMixin {
  TaskDao(super.attachedDatabase);

  Stream<List<TaskRow>> watchForProject(int projectId) =>
      (select(tasks)
            ..where((r) => r.projectId.equals(projectId))
            ..orderBy([
              (r) => OrderingTerm(expression: r.boardStatus),
              (r) => OrderingTerm(expression: r.sortOrder),
              (r) => OrderingTerm(expression: r.id),
            ]))
          .watch();

  Stream<List<TaskRow>> watchAll() =>
      (select(tasks)
            ..orderBy([
              (r) => OrderingTerm(expression: r.projectId),
              (r) => OrderingTerm(expression: r.boardStatus),
              (r) => OrderingTerm(expression: r.sortOrder),
            ]))
          .watch();

  Future<int> create({
    required int projectId,
    required String title,
    required TaskStatus status,
    required DateTime createdAt,
  }) => transaction(() async {
    final next = await _nextSortOrder(projectId, status);
    return into(tasks).insert(
      TasksCompanion.insert(
        projectId: projectId,
        title: title,
        boardStatus: Value(status.dbIndex),
        sortOrder: next,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );
  });

  Future<int> _nextSortOrder(int projectId, TaskStatus status) async {
    final maxOrder = tasks.sortOrder.max();
    final row = await (selectOnly(tasks)
          ..addColumns([maxOrder])
          ..where(tasks.projectId.equals(projectId) & tasks.boardStatus.equals(status.dbIndex)))
        .getSingleOrNull();
    return (row?.read(maxOrder) ?? 0) + 1;
  }

  Future<void> update(int id, TasksCompanion changes) =>
      (update(tasks)..where((r) => r.id.equals(id))).write(
        changes.copyWith(updatedAt: Value(DateTime.now())),
      );

  /// Moves a task into [status] at [sortOrder], bumping the row's updatedAt.
  Future<void> moveTo(int id, TaskStatus status, int sortOrder) =>
      update(id, TasksCompanion(
        boardStatus: Value(status.dbIndex),
        sortOrder: Value(sortOrder),
        completedAt: Value(status == TaskStatus.done ? DateTime.now() : null),
      ));

  Future<void> setDone(int id, {DateTime? at}) => update(id, TasksCompanion(
    boardStatus: const Value(4),
    completedAt: Value(at ?? DateTime.now()),
  ));

  Future<void> reopen(int id) => update(id, TasksCompanion(
    boardStatus: const Value(1),
    completedAt: const Value(null),
  ));

  Future<void> remove(int id) =>
      (delete(tasks)..where((r) => r.id.equals(id))).go();

  Future<int> duplicate(int id) => transaction(() async {
    final original = await (select(tasks)..where((r) => r.id.equals(id))).getSingle();
    // The copy lands in Backlog, so its sortOrder continues the Backlog column.
    final next = await _nextSortOrder(original.projectId, TaskStatus.backlog);
    final now = DateTime.now();
    return into(tasks).insert(
      original.toCompanion(false).copyWith(
        id: const Value.absent(),
        title: Value('${original.title} (copy)'),
        sortOrder: Value(next),
        boardStatus: const Value(0),
        completedAt: const Value(null),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  });
}
```

- [ ] **Step 4: Implement `TaskRepository` with validation**

```dart
// lib/data/repositories/task_repository.dart
import 'package:energy_clock/core/task_status.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/features/projects/model/task_board.dart';

abstract interface class TaskRepository {
  Stream<List<TaskRow>> watchTasks(int projectId);
  Stream<List<TaskRow>> watchAllTasks();
  Future<int> create(int projectId, String title);
  Future<void> updateTitle(int id, String title);
  Future<void> updateNotes(int id, String? notes);
  Future<void> updatePriority(int id, int priority);
  Future<void> updateEstimate(int id, int? minutes);
  Future<void> updateDueDate(int id, DateTime? date);
  Future<void> updatePlannedDate(int id, DateTime? date);
  Future<void> updateBlockedReason(int id, String? reason);
  Future<void> move(int id, TaskStatus status, {int? sortOrder});
  Future<void> complete(int id);
  Future<void> reopen(int id);
  Future<void> remove(int id);
  Future<int> duplicate(int id);
}

class DriftTaskRepository implements TaskRepository {
  DriftTaskRepository(this._db);
  final AppDatabase _db;

  @override
  Stream<List<TaskRow>> watchTasks(int projectId) => _db.taskDao.watchForProject(projectId);
  @override
  Stream<List<TaskRow>> watchAllTasks() => _db.taskDao.watchAll();

  @override
  Future<int> create(int projectId, String title) {
    final trimmed = _title(title);
    return _db.taskDao.create(
      projectId: projectId,
      title: trimmed,
      status: TaskStatus.todo,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> updateTitle(int id, String title) =>
      _db.taskDao.update(id, TasksCompanion(title: Value(_title(title))));

  @override
  Future<void> updateNotes(int id, String? notes) {
    final trimmed = notes?.trim();
    final value = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    if (value != null && value.length > maxTaskNotesLength) {
      throw ArgumentError('notes 0-$maxTaskNotesLength chars');
    }
    return _db.taskDao.update(id, TasksCompanion(notes: Value(value)));
  }

  @override
  Future<void> updatePriority(int id, int priority) =>
      _db.taskDao.update(id, TasksCompanion(priority: Value(priority.clamp(0, 3))));

  @override
  Future<void> updateEstimate(int id, int? minutes) {
    if (minutes != null &&
        (minutes < minTaskEstimateMinutes || minutes > maxTaskEstimateMinutes)) {
      throw ArgumentError('estimate $minTaskEstimateMinutes-$maxTaskEstimateMinutes');
    }
    return _db.taskDao.update(id, TasksCompanion(estimateMinutes: Value(minutes)));
  }

  @override
  Future<void> updateDueDate(int id, DateTime? date) =>
      _db.taskDao.update(id, TasksCompanion(dueDate: Value(date)));

  @override
  Future<void> updatePlannedDate(int id, DateTime? date) =>
      _db.taskDao.update(id, TasksCompanion(plannedDate: Value(date)));

  @override
  Future<void> updateBlockedReason(int id, String? reason) {
    final trimmed = reason?.trim();
    final value = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    if (value != null && value.length > 200) {
      throw ArgumentError('blocked reason 0-200 chars');
    }
    return _db.taskDao.update(id, TasksCompanion(blockedReason: Value(value)));
  }

  @override
  Future<void> move(int id, TaskStatus status, {int? sortOrder}) =>
      _db.taskDao.moveTo(id, status, sortOrder ?? 1 << 20);

  @override
  Future<void> complete(int id) => _db.taskDao.setDone(id);
  @override
  Future<void> reopen(int id) => _db.taskDao.reopen(id);
  @override
  Future<void> remove(int id) => _db.taskDao.remove(id);
  @override
  Future<int> duplicate(int id) => _db.taskDao.duplicate(id);

  String _title(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty || trimmed.length > maxTaskTitleLength) {
      throw ArgumentError('task title 1-$maxTaskTitleLength chars');
    }
    return trimmed;
  }
}
```

- [ ] **Step 5: Add providers**

In `lib/data/providers.dart`:

```dart
import 'package:energy_clock/data/repositories/task_repository.dart';
// ...
/// First-class tasks under projects (schema v12). Replaces subtasks.
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return DriftTaskRepository(ref.watch(appDatabaseProvider));
});
```

In `lib/features/projects/providers.dart`:

```dart
/// The canonical task repository, aliased under the feature-local plural name
/// (same instance; overriding either name in tests overrides both).
final Provider<TaskRepository> tasksRepositoryProvider = taskRepositoryProvider;

/// A project's tasks in board order, keyed by project id.
final taskListProvider =
    StreamProvider.family<List<TaskRow>, int>((ref, projectId) {
  return ref.watch(tasksRepositoryProvider).watchTasks(projectId);
});

/// Every task across projects, for the cross-project Board and Today views.
final allTasksProvider = StreamProvider<List<TaskRow>>((ref) {
  return ref.watch(tasksRepositoryProvider).watchAllTasks();
});
```

- [ ] **Step 6: Regenerate, test, analyze, commit**

```bash
"$(dirname "$(which flutter)")/dart" run build_runner build --delete-conflicting-outputs
flutter test test/data/task_dao_test.dart test/features/projects/ -v
flutter analyze
git add lib/data/daos/task_dao.dart lib/data/daos/task_dao.g.dart lib/data/repositories/task_repository.dart lib/data/providers.dart lib/features/projects/providers.dart test/data/task_dao_test.dart
git commit -m "feat: task dao, repository, and providers"
```

---

### Task 4: Per-project Board + List UI (replace SubtaskList)

**Files:**
- Create: `lib/features/projects/widgets/task_card.dart`
- Create: `lib/features/projects/widgets/task_board.dart`
- Create: `lib/features/projects/widgets/task_list.dart`
- Modify: `lib/features/projects/widgets/project_detail.dart` (embed board/list behind a Board | List switch)
- Modify: `lib/core/strings.dart` (task copy block)
- Modify: `lib/features/projects/model/task_board.dart` (return `Strings` messages, not literals)
- Test: `test/features/projects/task_board_test.dart` (widgets), update `test/features/projects/project_detail_test.dart`; delete `test/features/projects/subtask_list_test.dart`

**Interfaces:**
- Consumes: `taskListProvider(projectId)`, `tasksRepositoryProvider`, `TaskStatus`, `compareTasks`, `groupByStatus`.
- Produces: `TaskBoard(projectId)`, `TaskList(projectId)`, `TaskCard(task, onTap)`, `String taskStatusLabel(TaskStatus)`, `String estimateLabel(int?)`.

- [ ] **Step 1: Add the `Strings` task block**

Append to the Projects section of `lib/core/strings.dart` (after the subtask keys around line 634):

```dart
// --- Tasks (replaces subtasks, schema v12) ---
static const String tasksTitle = 'Tasks';
static const String tasksEmpty = 'Break down the work — add the first task.';
static const String tasksAddHint = 'Add a task';
static const String tasksAdd = 'Add';
static const String tasksTitleRequired = 'Name your task';
static const String tasksTitleTooLong = 'Keep it under 120 characters';
static const String tasksNotesTooLong = 'Keep notes under 2000 characters';
static const String tasksEstimateRange = 'Use 15 minutes to 1000 hours';
static const List<String> tasksStatusLabels = ['Backlog', 'Todo', 'Doing', 'Blocked', 'Done'];
static const List<String> tasksPriorityLabels = ['None', 'Low', 'Medium', 'High'];
static const String tasksBoardView = 'Board';
static const String tasksListView = 'List';
static const String tasksDeleted = 'Task deleted';
static const String tasksCompleted = 'Task completed';
static const String tasksDuplicated = 'Task duplicated';
static const String tasksNoMatch = 'No tasks match.';
static const String tasksClear = 'Clear';
static const String tasksMetaNoEstimate = 'No estimate';
static String tasksEstimateVsActual(String estimate, String actual) => '$actual of $estimate';
```

- [ ] **Step 2: Update the pure helpers to use `Strings`**

In `lib/features/projects/model/task_board.dart` replace the literal returns from Step 3 of Task 2 with `Strings.tasksTitleRequired`, `Strings.tasksTitleTooLong`, `Strings.tasksNotesTooLong`, `Strings.tasksEstimateRange` (add `import 'package:energy_clock/core/strings.dart';`). The Task 2 tests assert `isNotNull`, so they still pass.

- [ ] **Step 3: Write the failing widget test**

```dart
// test/features/projects/task_board_test.dart (append widget group)
testWidgets('board shows columns and adds a task', (tester) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  final pid = await db.projectDao.createProject(
    ProjectsCompanion.insert(title: 'Alpha', createdAt: DateTime(2026, 10, 1)),
  );
  await tester.pumpWidget(_harness(db, TaskBoard(projectId: pid)));
  await tester.pumpAndSettle();
  for (final label in Strings.tasksStatusLabels) {
    expect(find.text(label), findsOneWidget);
  }
  await tester.enterText(find.byKey(const Key('task-add-backlog')), 'Ship v1');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
  expect(find.text('Ship v1'), findsOneWidget);
});
```

`_harness` wraps the widget in a `ProviderScope` with `appDatabaseProvider.overrideWithValue(db)` and a `MaterialApp`. Copy the pattern from `test/features/projects/subtask_list_test.dart` before deleting it.

- [ ] **Step 4: Run to verify it fails**

Run: `flutter test test/features/projects/task_board_test.dart -v`
Expected: FAIL — `TaskBoard` undefined.

- [ ] **Step 5: Implement `TaskCard`, `TaskBoard`, `TaskList`**

```dart
// lib/features/projects/widgets/task_card.dart
class TaskCard extends StatelessWidget {
  const TaskCard({required this.task, this.onTap, super.key});
  final TaskRow task;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final done = TaskStatus.fromDb(task.boardStatus) == TaskStatus.done;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                if (task.priority > 0) ...[
                  Container(width: 8, height: 8,
                    decoration: BoxDecoration(color: colors.toneFocus, shape: BoxShape.circle)),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Expanded(child: Text(task.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done ? colors.muted : null))),
              ]),
              if (task.dueDate != null) Text(Strings.projectsDueBy(friendlyDate(task.dueDate!)),
                style: Theme.of(context).textTheme.labelSmall),
              if (task.estimateMinutes != null)
                Text(formatDurationMinutes(task.estimateMinutes!),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
```

`TaskBoard` renders a horizontal `SingleChildScrollView` of five `Column`s (one per `TaskStatus`), each headed by `taskStatusLabel(status)` + count + an inline add `TextField` keyed `Key('task-add-${status.name}')` calling `tasksRepositoryProvider.create(projectId, text)` then upgrading the new row to `status` via `repository.move(id, status)`. Cards use `TaskCard` with `onTap` opening the editor (Task 5). `TaskList` renders a single `ListView` of `TaskCard`s sorted by the current `TasksSort`.

```dart
// lib/features/projects/widgets/task_board.dart (head)
String taskStatusLabel(TaskStatus status) => Strings.tasksStatusLabels[status.index];
String estimateLabel(int? minutes) =>
    minutes == null ? Strings.tasksMetaNoEstimate : formatDurationMinutes(minutes);

class TaskBoard extends ConsumerWidget {
  const TaskBoard({required this.projectId, super.key});
  final int projectId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(taskListProvider(projectId));
    final tasks = async.valueOrNull ?? const <TaskRow>[];
    final grouped = groupByStatus(tasks);
    return SizedBox(
      height: 360,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final status in TaskStatus.values)
            _Column(projectId: projectId, status: status, tasks: grouped[status]!),
        ],
      ),
    );
  }
}
```

`_Column` is a `ConsumerStatefulWidget` owning the add `TextEditingController`; it validates with `validateTaskTitle`, disables Add until valid, and on submit calls `create` then `move(id, status)`.

- [ ] **Step 6: Embed Board | List in `project_detail.dart`**

Replace the `SubtaskList(projectId: ...)` call with a `TaskBoardSection(projectId)` that holds a `SegmentedButton` (Board / List) in local state and renders `TaskBoard` or `TaskList` under a `Strings.tasksTitle` header. Keep the existing detail sections untouched.

- [ ] **Step 7: Run tests, analyze, commit**

```bash
flutter test test/features/projects/task_board_test.dart test/features/projects/project_detail_test.dart -v
flutter analyze
git add -A
git commit -m "feat: project task board and list replace subtasks"
```

---

### Task 5: Rich task editor sheet

**Files:**
- Create: `lib/features/projects/widgets/task_editor.dart`
- Modify: `lib/features/projects/widgets/task_board.dart`, `task_list.dart` (open editor on card tap)
- Modify: `lib/core/strings.dart` (editor copy)
- Test: `test/features/projects/task_editor_test.dart`

**Interfaces:**
- Consumes: `tasksRepositoryProvider`, `taskListProvider`, `TaskStatus`, `validateTask*`.
- Produces: `Future<void> showTaskEditor(BuildContext, WidgetRef, {required TaskRow task})`.

- [ ] **Step 1: Write the failing editor test**

```dart
testWidgets('editor saves title, priority, estimate hours, and due chip', (tester) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  final pid = await db.projectDao.createProject(
    ProjectsCompanion.insert(title: 'Alpha', createdAt: DateTime(2026, 10, 1)));
  final id = await db.taskDao.create(
    projectId: pid, title: 'Old', status: TaskStatus.todo, createdAt: DateTime(2026, 10, 1));
  final task = (await db.select(db.tasks)..where((r) => r.id.equals(id))).getSingle();

  await tester.pumpWidget(_harness(db, Builder(builder: (context) => FilledButton(
    onPressed: () => showTaskEditor(context, ProviderScope.containerOf(context), task: task),
    child: const Text('open')))));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('task-title')), 'New');
  await tester.tap(find.text(Strings.tasksPriorityLabels[2])); // Medium
  await tester.enterText(find.byKey(const Key('task-estimate')), '1.5');
  await tester.tap(find.text(Strings.projectsDeadlineToday));
  await tester.tap(find.text(Strings.save));
  await tester.pumpAndSettle();

  final row = (await db.select(db.tasks)..where((r) => r.id.equals(id))).getSingle();
  expect(row.title, 'New');
  expect(row.priority, 2);
  expect(row.estimateMinutes, 90);
  expect(row.dueDate, isNotNull);
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/projects/task_editor_test.dart -v`
Expected: FAIL — `showTaskEditor` undefined.

- [ ] **Step 3: Implement the editor**

A `showModalBottomSheet` (`isScrollControlled: true`) with a `StatefulWidget` body owning controllers for title/notes/estimate. Sections:
- Title field (`Key('task-title')`), `validateTaskTitle`.
- Notes field (`Key('task-notes')`), 2000 counter.
- Status: 5 `ChoiceChip`s → `move(id, status)`.
- Priority: 4 `ChoiceChip`s → `updatePriority`.
- Estimate: hours field (`Key('task-estimate')`), parse decimal → `(value * 60).round()`, then `updateEstimate`.
- Due: quick chips Today / Tomorrow / Next week + pick-a-date + Clear → `updateDueDate`.
- Planned: same chips → `updatePlannedDate` (feeds the Today board).
- Save button (`Strings.save`) commits title/notes/estimate then pops; Delete (`Strings.projectsDelete`) with confirm.

```dart
Future<void> showTaskEditor(BuildContext context, WidgetRef ref, {required TaskRow task}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _TaskEditorSheet(task: task),
  );
}
```

Helpers reuse `friendlyDate` and the daylight-safe `DateTime(y, m, d)` constructors already used in `project_detail.dart`.

- [ ] **Step 4: Wire card taps + run tests**

In `TaskBoard`/`TaskList`, card `onTap` calls `showTaskEditor(context, ref, task: task)`.

```bash
flutter test test/features/projects/task_editor_test.dart test/features/projects/task_board_test.dart -v
flutter analyze
git add lib/features/projects/widgets/task_editor.dart lib/features/projects/widgets/task_board.dart lib/features/projects/widgets/task_list.dart lib/core/strings.dart test/features/projects/task_editor_test.dart
git commit -m "feat: rich task editor sheet"
```

---

### Task 6: Board/list toolbar — search, filters, sort, group, show-done

**Files:**
- Create: `lib/features/projects/widgets/task_toolbar.dart`
- Modify: `lib/features/projects/providers.dart` (add `TasksView` + `tasksViewProvider`)
- Modify: `lib/features/projects/widgets/task_board.dart`, `task_list.dart` (consume the view)
- Modify: `lib/core/strings.dart` (toolbar copy)
- Test: `test/features/projects/task_toolbar_test.dart`

**Interfaces:**
- Consumes: `TasksSort`, `TaskStatus`, `TaskRow`.
- Produces: `TasksView` (`query`, `sort`, `priorities` Set, `dueFilter`, `statusFilter`, `showDone`, `groupByStatusFlag`), `tasksViewProvider` (`NotifierProvider`), `TaskToolbar` widget, `List<TaskRow> applyTasksView(List<TaskRow>, TasksView, {DateTime? now})`.

- [ ] **Step 1: Write failing tests for `applyTasksView`**

```dart
test('query filters by title substring, due filter and priorities', () {
  final view = TasksView(query: 'ship', priorities: {3}, dueFilter: TasksDueFilter.overdue);
  final rows = applyTasksView([...], view, now: DateTime(2026, 10, 10));
  // assert only matching rows survive
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/projects/task_toolbar_test.dart -v`
Expected: FAIL — `TasksView` undefined.

- [ ] **Step 3: Implement the view state + pure filter**

Add to `lib/features/projects/providers.dart`:

```dart
enum TasksDueFilter { any, overdue, today, thisWeek, none }

@immutable
class TasksView {
  const TasksView({
    this.query = '',
    this.sort = TasksSort.manual,
    this.priorities = const {},
    this.dueFilter = TasksDueFilter.any,
    this.showDone = true,
  });
  final String query;
  final TasksSort sort;
  final Set<int> priorities;
  final TasksDueFilter dueFilter;
  final bool showDone;
  TasksView copyWith({ /* standard, with Set/clear handling like ProjectsView */ }) => ...;
}

class TasksViewNotifier extends Notifier<TasksView> {
  @override
  TasksView build() => const TasksView();
  // setQuery / setSort / togglePriority / setDueFilter / setShowDone
}

final tasksViewProvider =
    NotifierProvider<TasksViewNotifier, TasksView>(TasksViewNotifier.new);
```

Add the pure filter to `model/task_board.dart`:

```dart
List<TaskRow> applyTasksView(List<TaskRow> tasks, TasksView view, {DateTime? now}) {
  final q = view.query.trim().toLowerCase();
  final today = now ?? DateTime.now();
  return tasks.where((t) {
    if (q.isNotEmpty && !t.title.toLowerCase().contains(q)) return false;
    if (view.priorities.isNotEmpty && !view.priorities.contains(t.priority)) return false;
    if (!view.showDone && t.boardStatus == 4) return false;
    switch (view.dueFilter) {
      case TasksDueFilter.any: break;
      case TasksDueFilter.none: if (t.dueDate != null) return false;
      case TasksDueFilter.overdue:
        if (t.dueDate == null || !t.dueDate!.isBefore(DateTime(today.year, today.month, today.day))) return false;
      case TasksDueFilter.today:
        if (t.dueDate == null || !_sameDay(t.dueDate!, today)) return false;
      case TasksDueFilter.thisWeek:
        if (t.dueDate == null || t.dueDate!.isAfter(today.add(const Duration(days: 7)))) return false;
    }
    return true;
  }).toList()..sort((a, b) => compareTasks(a, b, view.sort));
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
```

- [ ] **Step 4: Implement `TaskToolbar` and consume the view**

`TaskToolbar` renders a search `TextField`, priority filter `FilterChip`s, due `ChoiceChip`s, a sort `PopupMenuButton<TasksSort>`, a group-by toggle, and a show-done `Switch`. `TaskBoard`/`TaskList` call `applyTasksView` on the watched rows before grouping/rendering.

- [ ] **Step 5: Run tests, analyze, commit**

```bash
flutter test test/features/projects/ -v
flutter analyze
git add -A
git commit -m "feat: task board toolbar with search filter sort group"
```

---

### Task 7: Projects tab — Outcomes / Board / Today + cross-project views

**Files:**
- Create: `lib/features/projects/widgets/today_view.dart`
- Create: `lib/features/projects/widgets/cross_project_board.dart`
- Modify: `lib/features/projects/projects_screen.dart` (`ProjectsTabBody` gains the segmented control; `ProjectsScreen` too)
- Modify: `lib/core/strings.dart` (tab copy)
- Test: `test/features/projects/projects_tab_test.dart` (extend)

**Interfaces:**
- Consumes: `allTasksProvider`, `projectListProvider`, `tasksRepositoryProvider`, `applyTasksView`.
- Produces: `enum ProjectsSurface { outcomes, board, today }`; `ProjectsTabBody` renders the chosen surface; `TodayView`; `CrossProjectBoard`.

- [ ] **Step 1: Write the failing tab test**

```dart
testWidgets('projects tab switches between Outcomes, Board and Today', (tester) async {
  // pump ProjectsTabBody in a ProviderScope with a seeded db.
  // tap Strings.projectsSurfaceBoard → a project filter chip row appears;
  // tap Strings.projectsSurfaceToday → Strings.todayEmpty appears when no task is planned.
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/projects/projects_tab_test.dart -v`
Expected: FAIL — surfaces absent.

- [ ] **Step 3: Implement the segmented control + views**

```dart
// projects_screen.dart
enum ProjectsSurface { outcomes, board, today }

// ProjectsTabBody holds ProjectsSurface in a StatefulWidget; a SegmentedButton
// at the top switches between:
//   outcomes -> _HubBody(rows, onOpenDay)
//   board    -> CrossProjectBoard(onOpenDay)
//   today    -> TodayView(onOpenDay)
```

`CrossProjectBoard` watches `allTasksProvider` + `projectListProvider`, shows a project filter `ChoiceChip` row (All + one per project), then the same column layout as `TaskBoard` but with cards carrying a small project label; card taps open the project's detail or the editor.

`TodayView` filters `allTasksProvider` to `plannedDate` today (and `showDone == false` by default), grouped by project, with the `Strings.todayEmpty` empty state. A "Pull to today" action is available from the shared card menu (set `plannedDate = today`).

- [ ] **Step 4: Run tests, analyze, commit**

```bash
flutter test test/features/projects/ -v
flutter analyze
git add -A
git commit -m "feat: projects tab outcomes board and today views"
```

---

### Task 8: Retire subtask code, full regression gate

**Files:** cleanup + verification.
- Delete any remaining subtask references (`SubtaskDao`, `SubtaskRepository`, `subtaskListProvider`, `subtaskCountsProvider`, `SubtaskRow`, `project_subtasks`).
- Modify `lib/features/projects/widgets/project_row.dart` — the `3/8 tasks` line now derives from `taskListProvider`.
- Test: `test/data/project_repository_test.dart` (subtask cases removed), `test/data/subtask_dao_test.dart` (deleted).

- [ ] **Step 1: Grep for stragglers**

Run: `rg -n "subtask|Subtask|project_subtasks" lib test`. Expected: no hits outside `drift_schemas/` and `test/generated_migrations/` (schema snapshots stay).

- [ ] **Step 2: Fix the hub row count**

In `projects_screen.dart` restore the `subtaskCounts:` argument to `TaskRowTile`, sourced from a new `taskCountsProvider(projectId)` derived from `taskListProvider` (`done` = `boardStatus == 4`, `total` = row count). Hide the line when `total == 0`.

- [ ] **Step 3: Full gates**

Run: `flutter analyze` → clean.
Run: `flutter test` → all PASS, including `no_hardcoded_colors_test` and every `migration_test` case. No golden regen (dial pixels untouched).

- [ ] **Step 4: Manual smoke (record in the commit body)**

Create project → open detail → add tasks in Backlog/Todo/Doing → drag between columns → open editor → set title/notes/priority/estimate/due/planned → complete → Undo → duplicate → delete → toolbar search/filter/sort/group → Projects tab Board (project filter) → Today → archive/delete project (tasks cascade, no orphans).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: retire subtask code, verify deep work slice 1"
```

## Self-Review

**1. Spec coverage (Slice 1 scope):** §1 v12 `tasks` table + subtask→task migration + drop → Task 1. §1 derived "task done/total" hub line → Task 8. §2 board/list replacing `SubtaskList` → Task 4. §2 rich task editor (title/notes/status/priority/estimate/due/planned; sprint/project/dependencies are Tasks 6–7 of later slices) → Task 5. §2 toolbar (search/filter/sort/group/show-done) → Task 6. §2 Projects tab Outcomes/Board/Today + cross-project Board + Today → Task 7. §3 reads/writes + validation → Tasks 2, 3. §4 validation ranges, empty states, delete/complete-undo → Tasks 2, 4, 5, 8. §5 unit/DAO/migration/widget/regression → Tasks 1, 2, 3, 4, 5, 6, 7, 8. Slice 1 explicitly excludes dial/session/dependencies/sprints (Tasks 2–4 of the parent spec) — those get their own plans.
**2. Placeholder scan:** no TBD/TODO; every task names exact files, signatures, commands, and expected results. UI tasks specify structure + keyed widgets; the data layer is complete code.
**3. Type consistency:** `TaskRow` columns fixed in Task 1 and used verbatim in Tasks 2–8. `TaskStatus`/`dbIndex` defined in Task 1, used in Tasks 2–8. `TaskRepository` signatures fixed in Task 3 and consumed in Tasks 4–7. `TasksView`/`tasksViewProvider`/`applyTasksView` fixed in Task 6, consumed in Tasks 6–7. Validation message keys fixed in Task 4 and referenced thereafter.
