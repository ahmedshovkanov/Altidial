import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:altidial/core/task_status.dart';
import 'package:altidial/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> seedProject([String title = 'Alpha']) =>
      db.projectDao.createProject(
        ProjectsCompanion.insert(title: title, createdAt: DateTime(2026, 10, 1)),
      );

  Future<TaskRow> read(int id) =>
      (db.select(db.tasks)..where((r) => r.id.equals(id))).getSingle();

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
    var row = await (db.select(db.tasks)..where((r) => r.id.equals(id))).getSingle();
    expect(row.boardStatus, 4);
    expect(row.completedAt, isNotNull);
    await db.taskDao.reopen(id);
    row = await (db.select(db.tasks)..where((r) => r.id.equals(id))).getSingle();
    expect(row.boardStatus, 1);
    expect(row.completedAt, isNull);
  });

  test('deleteAndUnlink cascades tasks', () async {
    final pid = await seedProject();
    await db.taskDao.create(projectId: pid, title: 'A', status: TaskStatus.todo, createdAt: DateTime(2026, 10, 1));
    await db.projectDao.deleteAndUnlink(pid);
    expect(await db.select(db.tasks).get(), isEmpty);
  });

  test('create starts each column at sortOrder 1 independently', () async {
    final pid = await seedProject();
    await db.taskDao.create(projectId: pid, title: 'B', status: TaskStatus.backlog, createdAt: DateTime(2026, 10, 1));
    final done = await db.taskDao.create(projectId: pid, title: 'D', status: TaskStatus.done, createdAt: DateTime(2026, 10, 1));
    final backlog =
        (await db.taskDao.watchForProject(pid).first).firstWhere((r) => r.boardStatus == 0);
    expect(backlog.sortOrder, 1);
    expect((await read(done)).sortOrder, 1);
  });

  test('watchAll spans projects, ordered by project then column then order', () async {
    final first = await seedProject('Alpha');
    final second = await seedProject('Beta');
    await db.taskDao.create(projectId: first, title: 'A-todo', status: TaskStatus.todo, createdAt: DateTime(2026, 10, 1));
    await db.taskDao.create(projectId: second, title: 'B-backlog', status: TaskStatus.backlog, createdAt: DateTime(2026, 10, 1));
    await db.taskDao.create(projectId: first, title: 'A-backlog', status: TaskStatus.backlog, createdAt: DateTime(2026, 10, 1));

    final rows = await db.taskDao.watchAll().first;
    expect(rows.map((r) => r.title), ['A-backlog', 'A-todo', 'B-backlog']);
  });

  test('moveTo sets an explicit sortOrder and clears completedAt', () async {
    final pid = await seedProject();
    final id = await db.taskDao.create(projectId: pid, title: 'A', status: TaskStatus.todo, createdAt: DateTime(2026, 10, 1));
    await db.taskDao.setDone(id, at: DateTime(2026, 10, 3));
    await db.taskDao.moveTo(id, TaskStatus.doing, 7);
    final row = await read(id);
    expect(row.boardStatus, 2);
    expect(row.sortOrder, 7);
    expect(row.completedAt, isNull);
  });

  test('update writes partial changes and bumps updatedAt', () async {
    final pid = await seedProject();
    final created = DateTime(2026, 10, 1);
    final id = await db.taskDao.create(projectId: pid, title: 'A', status: TaskStatus.todo, createdAt: created);
    await db.taskDao.updateTask(id, const TasksCompanion(title: Value('Renamed'), notes: Value('note')));
    final row = await read(id);
    expect(row.title, 'Renamed');
    expect(row.notes, 'note');
    expect(row.updatedAt.isAfter(created), isTrue);
  });

  test('duplicate copies into backlog with (copy) title at next backlog order', () async {
    final pid = await seedProject();
    final createdAt = DateTime(2026, 10, 1);
    final id = await db.taskDao.create(projectId: pid, title: 'Ship', status: TaskStatus.todo, createdAt: createdAt);
    await db.taskDao.setDone(id, at: DateTime(2026, 10, 3));

    final copyId = await db.taskDao.duplicate(id);

    expect(copyId, isNot(id));
    final copy = await read(copyId);
    expect(copy.title, 'Ship (copy)');
    expect(copy.boardStatus, 0);
    expect(copy.sortOrder, 1);
    expect(copy.completedAt, isNull);
    final original = await read(id);
    expect(original.title, 'Ship');
    expect(original.boardStatus, 4);
  });

  test('remove deletes only the given task', () async {
    final pid = await seedProject();
    final keep = await db.taskDao.create(projectId: pid, title: 'Keep', status: TaskStatus.todo, createdAt: DateTime(2026, 10, 1));
    final drop = await db.taskDao.create(projectId: pid, title: 'Drop', status: TaskStatus.todo, createdAt: DateTime(2026, 10, 1));
    await db.taskDao.remove(drop);
    final rows = await db.taskDao.watchForProject(pid).first;
    expect(rows.map((r) => r.id), [keep]);
  });
}
