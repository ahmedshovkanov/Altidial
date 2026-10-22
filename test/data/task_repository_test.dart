import 'package:drift/native.dart';
import 'package:altidial/core/task_status.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/repositories/task_repository.dart';
import 'package:altidial/features/projects/model/task_board.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late TaskRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftTaskRepository(db);
  });
  tearDown(() => db.close());

  Future<int> seedProject([String title = 'Alpha']) =>
      db.projectDao.createProject(
        ProjectsCompanion.insert(title: title, createdAt: DateTime(2026, 10, 1)),
      );

  Future<TaskRow> read(int id) =>
      (db.select(db.tasks)..where((r) => r.id.equals(id))).getSingle();

  test('create trims the title and starts in Todo', () async {
    final pid = await seedProject();
    final id = await repository.create(pid, '  Ship it  ');
    final row = await read(id);
    expect(row.title, 'Ship it');
    expect(row.boardStatus, TaskStatus.todo.dbIndex);
    expect(row.sortOrder, 1);
  });

  test('create rejects blank and overlong titles', () async {
    final pid = await seedProject();
    expect(() => repository.create(pid, '   '), throwsArgumentError);
    expect(
      () => repository.create(pid, 'x' * (maxTaskTitleLength + 1)),
      throwsArgumentError,
    );
  });

  test('updateTitle trims and validates', () async {
    final pid = await seedProject();
    final id = await repository.create(pid, 'A');
    await repository.updateTitle(id, '  B  ');
    expect((await read(id)).title, 'B');
    expect(() => repository.updateTitle(id, ''), throwsArgumentError);
  });

  test('updateNotes trims, clears blank, and caps length', () async {
    final pid = await seedProject();
    final id = await repository.create(pid, 'A');
    await repository.updateNotes(id, '  why  ');
    expect((await read(id)).notes, 'why');
    await repository.updateNotes(id, '   ');
    expect((await read(id)).notes, isNull);
    expect(
      () => repository.updateNotes(id, 'x' * (maxTaskNotesLength + 1)),
      throwsArgumentError,
    );
  });

  test('updatePriority clamps to 0..3', () async {
    final pid = await seedProject();
    final id = await repository.create(pid, 'A');
    await repository.updatePriority(id, 9);
    expect((await read(id)).priority, 3);
    await repository.updatePriority(id, -4);
    expect((await read(id)).priority, 0);
  });

  test('updateEstimate validates the allowed range', () async {
    final pid = await seedProject();
    final id = await repository.create(pid, 'A');
    await repository.updateEstimate(id, 90);
    expect((await read(id)).estimateMinutes, 90);
    await repository.updateEstimate(id, null);
    expect((await read(id)).estimateMinutes, isNull);
    expect(
      () => repository.updateEstimate(id, minTaskEstimateMinutes - 1),
      throwsArgumentError,
    );
    expect(
      () => repository.updateEstimate(id, maxTaskEstimateMinutes + 1),
      throwsArgumentError,
    );
  });

  test('due and planned dates persist and clear', () async {
    final pid = await seedProject();
    final id = await repository.create(pid, 'A');
    final due = DateTime(2026, 11, 1);
    final planned = DateTime(2026, 10, 20);
    await repository.updateDueDate(id, due);
    await repository.updatePlannedDate(id, planned);
    var row = await read(id);
    expect(row.dueDate, due);
    expect(row.plannedDate, planned);
    await repository.updateDueDate(id, null);
    await repository.updatePlannedDate(id, null);
    row = await read(id);
    expect(row.dueDate, isNull);
    expect(row.plannedDate, isNull);
  });

  test('updateBlockedReason trims, clears blank, and caps at 200', () async {
    final pid = await seedProject();
    final id = await repository.create(pid, 'A');
    await repository.updateBlockedReason(id, '  waiting  ');
    expect((await read(id)).blockedReason, 'waiting');
    await repository.updateBlockedReason(id, '  ');
    expect((await read(id)).blockedReason, isNull);
    expect(
      () => repository.updateBlockedReason(id, 'x' * 201),
      throwsArgumentError,
    );
  });

  test('move changes the column with or without an explicit order', () async {
    final pid = await seedProject();
    final id = await repository.create(pid, 'A');
    await repository.move(id, TaskStatus.doing);
    var row = await read(id);
    expect(row.boardStatus, TaskStatus.doing.dbIndex);
    expect(row.sortOrder, 1 << 20);
    await repository.move(id, TaskStatus.blocked, sortOrder: 5);
    row = await read(id);
    expect(row.boardStatus, TaskStatus.blocked.dbIndex);
    expect(row.sortOrder, 5);
    expect(row.completedAt, isNull);
  });

  test('complete stamps Done and reopen clears it back to Todo', () async {
    final pid = await seedProject();
    final id = await repository.create(pid, 'A');
    await repository.complete(id);
    var row = await read(id);
    expect(row.boardStatus, TaskStatus.done.dbIndex);
    expect(row.completedAt, isNotNull);
    await repository.reopen(id);
    row = await read(id);
    expect(row.boardStatus, TaskStatus.todo.dbIndex);
    expect(row.completedAt, isNull);
  });

  test('remove deletes the task', () async {
    final pid = await seedProject();
    final id = await repository.create(pid, 'A');
    await repository.remove(id);
    expect(await db.select(db.tasks).get(), isEmpty);
  });

  test('duplicate copies the task into Backlog', () async {
    final pid = await seedProject();
    final id = await repository.create(pid, 'Ship');
    final copyId = await repository.duplicate(id);
    final copy = await read(copyId);
    expect(copy.title, 'Ship (copy)');
    expect(copy.boardStatus, TaskStatus.backlog.dbIndex);
  });

  test('watchTasks streams one board and watchAllTasks every task', () async {
    final first = await seedProject();
    final second = await seedProject('Beta');
    await repository.create(first, 'A');
    await repository.create(second, 'B');

    expect(
      (await repository.watchTasks(first).first).map((r) => r.title),
      ['A'],
    );
    expect(
      (await repository.watchAllTasks().first).map((r) => r.title).toSet(),
      {'A', 'B'},
    );
  });
}
