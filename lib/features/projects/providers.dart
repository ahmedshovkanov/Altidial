// lib/features/projects/providers.dart
import 'package:altidial/core/task_status.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/data/repositories/project_repository.dart';
import 'package:altidial/data/repositories/task_repository.dart';
import 'package:altidial/features/projects/model/task_board.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Re-export of the canonical [projectRepositoryProvider] (defined in
/// `data/providers.dart`) under the feature-local plural name.
///
/// This is the same provider instance, not a second definition, so overriding
/// either name in tests overrides both. Feature code imports this file and
/// uses the plural; the data layer owns the singular definition.
final Provider<ProjectRepository> projectsRepositoryProvider =
    projectRepositoryProvider;

/// The canonical task repository, aliased under the feature-local plural name
/// (same instance; overriding either name in tests overrides both).
final Provider<TaskRepository> tasksRepositoryProvider = taskRepositoryProvider;

/// A project's tasks in board order, keyed by project id.
final taskListProvider =
    StreamProvider.family<List<TaskRow>, int>((ref, projectId) {
      return ref.watch(tasksRepositoryProvider).watchTasks(projectId);
    });

/// Done/total task counts for a project, derived from [taskListProvider].
///
/// `done` counts tasks in the Done column (`boardStatus == 4`); `total` is the
/// row count. Null while the task stream is still loading, so the hub row can
/// hide the tasks line until the counts are known.
final taskCountsProvider =
    Provider.family<({int done, int total})?, int>((ref, projectId) {
      final tasks = ref.watch(taskListProvider(projectId)).valueOrNull;
      if (tasks == null) return null;
      final done = tasks
          .where((t) => t.boardStatus == TaskStatus.done.dbIndex)
          .length;
      return (done: done, total: tasks.length);
    });

/// Every task across projects, for the cross-project Board and Today views.
final allTasksProvider = StreamProvider<List<TaskRow>>((ref) {
  return ref.watch(tasksRepositoryProvider).watchAllTasks();
});

final projectListProvider = StreamProvider<List<ProjectRow>>((ref) {
  return ref.watch(projectsRepositoryProvider).watchProjects();
});

/// One project's live detail (row + linked events + planned/actual minutes),
/// keyed by project id. Same family shape as the Clock/Calendar providers.
final projectDetailProvider =
    StreamProvider.family<ProjectDetail, int>((ref, projectId) {
      return ref.watch(projectsRepositoryProvider).watchDetail(projectId);
    });

/// Hub sort order. Null-bearing rows sort last in every mode (see the
/// comparators in `model/project_progress.dart`).
enum ProjectsSort { deadline, progress, recent, title }

/// Hub view state: the search query, the sort order, the tone filter
/// (`Tone.dbIndex`, null for All) and the overdue-only flag.
@immutable
class ProjectsView {
  const ProjectsView({
    this.query = '',
    this.sort = ProjectsSort.deadline,
    this.toneFilter,
    this.overdueOnly = false,
  });

  final String query;
  final ProjectsSort sort;
  final int? toneFilter;
  final bool overdueOnly;

  ProjectsView copyWith({
    String? query,
    ProjectsSort? sort,
    int? Function()? toneFilter,
    bool? overdueOnly,
  }) {
    return ProjectsView(
      query: query ?? this.query,
      sort: sort ?? this.sort,
      toneFilter: toneFilter != null ? toneFilter() : this.toneFilter,
      overdueOnly: overdueOnly ?? this.overdueOnly,
    );
  }
}

/// Owns the hub's [ProjectsView]. Plain `Notifier` (not auto-dispose) so the
/// search text survives tab switches.
class ProjectsViewNotifier extends Notifier<ProjectsView> {
  @override
  ProjectsView build() => const ProjectsView();

  void setQuery(String query) {
    if (query == state.query) return;
    state = state.copyWith(query: query);
  }

  void setSort(ProjectsSort sort) {
    if (sort == state.sort) return;
    state = state.copyWith(sort: sort);
  }

  void setToneFilter(int? toneIndex) {
    if (toneIndex == state.toneFilter) return;
    state = state.copyWith(toneFilter: () => toneIndex);
  }

  void setOverdueOnly(bool value) {
    if (value == state.overdueOnly) return;
    state = state.copyWith(overdueOnly: value);
  }
}

final projectsViewProvider =
    NotifierProvider<ProjectsViewNotifier, ProjectsView>(
      ProjectsViewNotifier.new,
    );

/// The due-date window a task board/list is filtered to. [any] shows every
/// task; [none] shows only tasks with no due date.
enum TasksDueFilter { any, overdue, today, thisWeek, none }

/// Task board/list view state: the search query, the sort order, the set of
/// priorities to keep (empty means every priority), the due-date window, the
/// statuses to keep (empty means every status), whether Done tasks show, and
/// whether the list groups by status.
@immutable
class TasksView {
  const TasksView({
    this.query = '',
    this.sort = TasksSort.manual,
    this.priorities = const {},
    this.dueFilter = TasksDueFilter.any,
    this.statusFilter = const {},
    this.showDone = true,
    this.groupByStatusFlag = true,
  });

  final String query;
  final TasksSort sort;
  final Set<int> priorities;
  final TasksDueFilter dueFilter;
  final Set<TaskStatus> statusFilter;
  final bool showDone;
  final bool groupByStatusFlag;

  TasksView copyWith({
    String? query,
    TasksSort? sort,
    Set<int>? priorities,
    TasksDueFilter? dueFilter,
    Set<TaskStatus>? statusFilter,
    bool? showDone,
    bool? groupByStatusFlag,
  }) {
    return TasksView(
      query: query ?? this.query,
      sort: sort ?? this.sort,
      priorities: priorities ?? this.priorities,
      dueFilter: dueFilter ?? this.dueFilter,
      statusFilter: statusFilter ?? this.statusFilter,
      showDone: showDone ?? this.showDone,
      groupByStatusFlag: groupByStatusFlag ?? this.groupByStatusFlag,
    );
  }
}

/// Owns the project board/list's [TasksView]. Plain `Notifier` (not
/// auto-dispose) so the search text survives board/list switches.
class TasksViewNotifier extends Notifier<TasksView> {
  @override
  TasksView build() => const TasksView();

  void setQuery(String query) {
    if (query == state.query) return;
    state = state.copyWith(query: query);
  }

  void setSort(TasksSort sort) {
    if (sort == state.sort) return;
    state = state.copyWith(sort: sort);
  }

  void togglePriority(int priority) {
    state = state.copyWith(
      priorities: _toggled(state.priorities, priority),
    );
  }

  void toggleStatus(TaskStatus status) {
    state = state.copyWith(
      statusFilter: _toggled(state.statusFilter, status),
    );
  }

  void setDueFilter(TasksDueFilter dueFilter) {
    if (dueFilter == state.dueFilter) return;
    state = state.copyWith(dueFilter: dueFilter);
  }

  void setShowDone(bool value) {
    if (value == state.showDone) return;
    state = state.copyWith(showDone: value);
  }

  void setGroupByStatus(bool value) {
    if (value == state.groupByStatusFlag) return;
    state = state.copyWith(groupByStatusFlag: value);
  }

  Set<T> _toggled<T>(Set<T> current, T value) {
    final next = {...current};
    if (!next.add(value)) next.remove(value);
    return next;
  }
}

final tasksViewProvider =
    NotifierProvider<TasksViewNotifier, TasksView>(TasksViewNotifier.new);

/// Owns the cross-project Board's [TasksView]. A separate instance from
/// [tasksViewProvider] so the board cannot inherit the per-project toolbar's
/// filters (search/sort/showDone); same notifier shape. Plain `Notifier` so its
/// state survives surface switches.
final crossProjectTasksViewProvider =
    NotifierProvider<TasksViewNotifier, TasksView>(TasksViewNotifier.new);
