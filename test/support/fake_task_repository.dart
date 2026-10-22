import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:energy_clock/core/task_status.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/task_repository.dart';
import 'package:energy_clock/features/projects/model/task_board.dart';

/// An in-memory [TaskRepository] for widget tests. Mirrors the Drift
/// repository's column ordering (boardStatus → sortOrder → id), title/notes
/// validation and completion stamps, so tests exercise the same rules without
/// a database (and without drift's stream-disposal timers).
class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository([List<TaskRow>? initial]) : _rows = [...?initial] {
    for (final row in _rows) {
      if (row.id >= _nextId) _nextId = row.id + 1;
    }
  }

  final List<TaskRow> _rows;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  int _nextId = 1;
  static final DateTime _now = DateTime(2026, 10, 17);

  /// A read-only snapshot in board order, for test assertions.
  List<TaskRow> get rows => List.unmodifiable(_snapshot());

  List<TaskRow> _snapshot({int? projectId}) {
    return _rows
        .where((r) => projectId == null || r.projectId == projectId)
        .toList()
      ..sort((a, b) {
        final byStatus = a.boardStatus.compareTo(b.boardStatus);
        if (byStatus != 0) return byStatus;
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
  }

  int _nextSortOrder(int projectId, TaskStatus status) =>
      _rows
          .where(
            (r) => r.projectId == projectId && r.boardStatus == status.dbIndex,
          )
          .fold<int>(0, (max, r) => r.sortOrder > max ? r.sortOrder : max) +
      1;

  @override
  Stream<List<TaskRow>> watchTasks(int projectId) async* {
    yield _snapshot(projectId: projectId);
    yield* _changes.stream.map((_) => _snapshot(projectId: projectId));
  }

  @override
  Stream<List<TaskRow>> watchAllTasks() async* {
    yield _snapshot();
    yield* _changes.stream.map((_) => _snapshot());
  }

  @override
  Future<int> create(int projectId, String title) async {
    final trimmed = title.trim();
    if (validateTaskTitle(trimmed) != null) {
      throw ArgumentError('task title 1-$maxTaskTitleLength chars');
    }
    final row = TaskRow(
      id: _nextId++,
      projectId: projectId,
      title: trimmed,
      notes: null,
      boardStatus: TaskStatus.todo.dbIndex,
      priority: 0,
      estimateMinutes: null,
      dueDate: null,
      plannedDate: null,
      sortOrder: _nextSortOrder(projectId, TaskStatus.todo),
      blockedReason: null,
      createdAt: _now,
      updatedAt: _now,
      completedAt: null,
    );
    _rows.add(row);
    _changes.add(null);
    return row.id;
  }

  @override
  Future<void> updateTitle(int id, String title) async {
    final trimmed = title.trim();
    if (validateTaskTitle(trimmed) != null) {
      throw ArgumentError('task title 1-$maxTaskTitleLength chars');
    }
    _update(id, (r) => r.copyWith(title: trimmed, updatedAt: _now));
  }

  @override
  Future<void> updateNotes(int id, String? notes) async {
    if (validateTaskNotes(notes ?? '') != null) {
      throw ArgumentError('0-$maxTaskNotesLength chars');
    }
    final trimmed = notes?.trim();
    final value = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    _update(id, (r) => r.copyWith(notes: Value(value), updatedAt: _now));
  }

  @override
  Future<void> updatePriority(int id, int priority) async {
    _update(
      id,
      (r) => r.copyWith(priority: priority.clamp(0, 3), updatedAt: _now),
    );
  }

  @override
  Future<void> updateEstimate(int id, int? minutes) async {
    if (validateTaskEstimate(minutes) != null) {
      throw ArgumentError(
        'estimate $minTaskEstimateMinutes-$maxTaskEstimateMinutes',
      );
    }
    _update(
      id,
      (r) => r.copyWith(estimateMinutes: Value(minutes), updatedAt: _now),
    );
  }

  @override
  Future<void> updateDueDate(int id, DateTime? date) async {
    _update(id, (r) => r.copyWith(dueDate: Value(date), updatedAt: _now));
  }

  @override
  Future<void> updatePlannedDate(int id, DateTime? date) async {
    _update(id, (r) => r.copyWith(plannedDate: Value(date), updatedAt: _now));
  }

  @override
  Future<void> updateBlockedReason(int id, String? reason) async {
    final value = _optionalText(reason, 200);
    _update(
      id,
      (r) => r.copyWith(blockedReason: Value(value), updatedAt: _now),
    );
  }

  @override
  Future<void> move(int id, TaskStatus status, {int? sortOrder}) async {
    _update(
      id,
      (r) => r.copyWith(
        boardStatus: status.dbIndex,
        sortOrder: sortOrder ?? (1 << 20),
        completedAt: Value(status == TaskStatus.done ? _now : null),
        updatedAt: _now,
      ),
    );
  }

  @override
  Future<void> complete(int id) async {
    _update(
      id,
      (r) => r.copyWith(
        boardStatus: TaskStatus.done.dbIndex,
        completedAt: Value(_now),
        updatedAt: _now,
      ),
    );
  }

  @override
  Future<void> reopen(int id) async {
    _update(
      id,
      (r) => r.copyWith(
        boardStatus: TaskStatus.todo.dbIndex,
        completedAt: const Value(null),
        updatedAt: _now,
      ),
    );
  }

  @override
  Future<void> remove(int id) async {
    _rows.removeWhere((r) => r.id == id);
    _changes.add(null);
  }

  @override
  Future<int> duplicate(int id) async {
    final original = _rows.firstWhere((r) => r.id == id);
    final row = original.copyWith(
      id: _nextId++,
      title: '${original.title} (copy)',
      boardStatus: TaskStatus.backlog.dbIndex,
      sortOrder: _nextSortOrder(original.projectId, TaskStatus.backlog),
      completedAt: const Value(null),
      createdAt: _now,
      updatedAt: _now,
    );
    _rows.add(row);
    _changes.add(null);
    return row.id;
  }

  TaskRow _update(int id, TaskRow Function(TaskRow) change) {
    final index = _rows.indexWhere((r) => r.id == id);
    if (index < 0) throw StateError('no task $id');
    final updated = change(_rows[index]);
    _rows[index] = updated;
    _changes.add(null);
    return updated;
  }

  /// Trimmed text; blank collapses to null. [max] caps the stored length.
  String? _optionalText(String? text, int max) {
    final trimmed = text?.trim();
    final value = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    if (value != null && value.length > max) {
      throw ArgumentError('0-$max chars');
    }
    return value;
  }

  void dispose() => _changes.close();
}
