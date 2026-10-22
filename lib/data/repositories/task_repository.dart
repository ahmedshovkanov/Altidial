import 'package:drift/drift.dart' show Value;
import 'package:altidial/core/task_status.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/features/projects/model/task_board.dart';

/// Task reads and writes for the Board/List/Today views. Every write is
/// validated here; the DAO enforces only database invariants.
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
  Stream<List<TaskRow>> watchTasks(int projectId) =>
      _db.taskDao.watchForProject(projectId);

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
      _db.taskDao.updateTask(id, TasksCompanion(title: Value(_title(title))));

  @override
  Future<void> updateNotes(int id, String? notes) {
    final value = _optionalText(notes, maxTaskNotesLength, 'notes');
    return _db.taskDao.updateTask(id, TasksCompanion(notes: Value(value)));
  }

  @override
  Future<void> updatePriority(int id, int priority) => _db.taskDao.updateTask(
    id,
    TasksCompanion(priority: Value(priority.clamp(0, 3))),
  );

  @override
  Future<void> updateEstimate(int id, int? minutes) {
    if (minutes != null &&
        (minutes < minTaskEstimateMinutes ||
            minutes > maxTaskEstimateMinutes)) {
      throw ArgumentError(
        'estimate $minTaskEstimateMinutes-$maxTaskEstimateMinutes',
      );
    }
    return _db.taskDao.updateTask(
      id,
      TasksCompanion(estimateMinutes: Value(minutes)),
    );
  }

  @override
  Future<void> updateDueDate(int id, DateTime? date) =>
      _db.taskDao.updateTask(id, TasksCompanion(dueDate: Value(date)));

  @override
  Future<void> updatePlannedDate(int id, DateTime? date) =>
      _db.taskDao.updateTask(id, TasksCompanion(plannedDate: Value(date)));

  @override
  Future<void> updateBlockedReason(int id, String? reason) {
    final value = _optionalText(reason, 200, 'blocked reason');
    return _db.taskDao.updateTask(
      id,
      TasksCompanion(blockedReason: Value(value)),
    );
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

  /// Trimmed, non-empty, length-checked title.
  String _title(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty || trimmed.length > maxTaskTitleLength) {
      throw ArgumentError('task title 1-$maxTaskTitleLength chars');
    }
    return trimmed;
  }

  /// Trimmed text; blank collapses to null. [max] caps the stored length.
  String? _optionalText(String? text, int max, String label) {
    final trimmed = text?.trim();
    final value = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    if (value != null && value.length > max) {
      throw ArgumentError('$label 0-$max chars');
    }
    return value;
  }
}
