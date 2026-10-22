import 'package:drift/drift.dart';
import 'package:altidial/core/task_status.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/tables/tasks_table.dart';

part 'task_dao.g.dart';

/// Data access for the v12 `tasks` table: per-column ordering, status moves,
/// completion stamps, duplication and removal. Validation lives in
/// `TaskRepository`; this layer only enforces database invariants.
@DriftAccessor(tables: [Tasks])
class TaskDao extends DatabaseAccessor<AppDatabase> with _$TaskDaoMixin {
  TaskDao(super.attachedDatabase);

  /// A project's tasks in board order: column (backlog → done), then the
  /// manual [TaskRow.sortOrder], then id as a stable tiebreak.
  Stream<List<TaskRow>> watchForProject(int projectId) =>
      (select(tasks)
            ..where((r) => r.projectId.equals(projectId))
            ..orderBy([
              (r) => OrderingTerm(expression: r.boardStatus),
              (r) => OrderingTerm(expression: r.sortOrder),
              (r) => OrderingTerm(expression: r.id),
            ]))
          .watch();

  /// Every task across projects, for the cross-project Board and Today views.
  Stream<List<TaskRow>> watchAll() =>
      (select(tasks)
            ..orderBy([
              (r) => OrderingTerm(expression: r.projectId),
              (r) => OrderingTerm(expression: r.boardStatus),
              (r) => OrderingTerm(expression: r.sortOrder),
            ]))
          .watch();

  /// Inserts a task at the end of its column. `boardStatus`/`priority` keep
  /// their DDL defaults; `updatedAt` starts equal to [createdAt].
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

  /// The next sort order for a column: the current maximum plus one, so the
  /// first task in an empty column lands at 1.
  Future<int> _nextSortOrder(int projectId, TaskStatus status) async {
    final maxOrder = tasks.sortOrder.max();
    final row = await (selectOnly(tasks)
          ..addColumns([maxOrder])
          ..where(
            tasks.projectId.equals(projectId) &
                tasks.boardStatus.equals(status.dbIndex),
          ))
        .getSingleOrNull();
    return (row?.read(maxOrder) ?? 0) + 1;
  }

  /// Applies partial [changes], always bumping `updatedAt`.
  Future<void> updateTask(int id, TasksCompanion changes) =>
      (super.update(tasks)..where((r) => r.id.equals(id))).write(
        changes.copyWith(updatedAt: Value(DateTime.now())),
      );

  /// Moves a task into [status] at [sortOrder], bumping the row's updatedAt.
  /// `completedAt` is stamped exactly when the target is Done, cleared
  /// otherwise.
  Future<void> moveTo(int id, TaskStatus status, int sortOrder) =>
      updateTask(id, TasksCompanion(
        boardStatus: Value(status.dbIndex),
        sortOrder: Value(sortOrder),
        completedAt: Value(status == TaskStatus.done ? DateTime.now() : null),
      ));

  Future<void> setDone(int id, {DateTime? at}) => updateTask(id, TasksCompanion(
    boardStatus: const Value(4),
    completedAt: Value(at ?? DateTime.now()),
  ));

  Future<void> reopen(int id) => updateTask(id, TasksCompanion(
    boardStatus: const Value(1),
    completedAt: const Value(null),
  ));

  Future<void> remove(int id) =>
      (delete(tasks)..where((r) => r.id.equals(id))).go();

  /// Copies [id] into Backlog as "<title> (copy)", continuing the Backlog
  /// column's order.
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
