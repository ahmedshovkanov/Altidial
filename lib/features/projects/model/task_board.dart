import 'package:altidial/core/strings.dart';
import 'package:altidial/core/task_status.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/features/projects/providers.dart';

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

/// The display name for one board column, indexed by [TaskStatus.index].
String taskStatusLabel(TaskStatus status) =>
    Strings.tasksStatusLabels[status.index];

String? validateTaskTitle(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return Strings.tasksTitleRequired;
  if (trimmed.length > maxTaskTitleLength) {
    return Strings.tasksTitleTooLong;
  }
  return null;
}

String? validateTaskNotes(String value) {
  if (value.trim().length > maxTaskNotesLength) {
    return Strings.tasksNotesTooLong;
  }
  return null;
}

String? validateTaskEstimate(int? minutes) {
  if (minutes == null) return null;
  if (minutes < minTaskEstimateMinutes || minutes > maxTaskEstimateMinutes) {
    return Strings.tasksEstimateRange;
  }
  return null;
}

/// Applies a board/list [view] to [tasks], returning a fresh, sorted list.
/// Pure: no repository or provider access (though [TasksView] lives beside the
/// provider, the filter itself is deterministic). [now] is injectable so the
/// overdue/today/thisWeek windows are testable.
List<TaskRow> applyTasksView(
  List<TaskRow> tasks,
  TasksView view, {
  DateTime? now,
}) {
  final q = view.query.trim().toLowerCase();
  final today = now ?? DateTime.now();
  final startOfToday = DateTime(today.year, today.month, today.day);
  final weekEnd = today.add(const Duration(days: 7));
  return tasks.where((t) {
    if (q.isNotEmpty && !t.title.toLowerCase().contains(q)) return false;
    if (view.priorities.isNotEmpty && !view.priorities.contains(t.priority)) {
      return false;
    }
    if (view.statusFilter.isNotEmpty &&
        !view.statusFilter.contains(TaskStatus.fromDb(t.boardStatus))) {
      return false;
    }
    if (!view.showDone && t.boardStatus == TaskStatus.done.dbIndex) return false;
    switch (view.dueFilter) {
      case TasksDueFilter.any:
        break;
      case TasksDueFilter.none:
        if (t.dueDate != null) return false;
      case TasksDueFilter.overdue:
        if (t.dueDate == null || !t.dueDate!.isBefore(startOfToday)) {
          return false;
        }
      case TasksDueFilter.today:
        if (t.dueDate == null || !_sameDay(t.dueDate!, today)) return false;
      case TasksDueFilter.thisWeek:
        if (t.dueDate == null || t.dueDate!.isAfter(weekEnd)) return false;
    }
    return true;
  }).toList()..sort((a, b) => compareTasks(a, b, view.sort));
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
