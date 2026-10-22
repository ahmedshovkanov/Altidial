// lib/features/projects/widgets/task_toolbar.dart
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/projects/model/task_board.dart';
import 'package:energy_clock/features/projects/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The display name for one sort option.
String taskSortLabel(TasksSort sort) => switch (sort) {
  TasksSort.manual => Strings.tasksSortManual,
  TasksSort.title => Strings.tasksSortTitle,
  TasksSort.due => Strings.tasksSortDue,
  TasksSort.priority => Strings.tasksSortPriority,
  TasksSort.created => Strings.tasksSortCreated,
  TasksSort.estimate => Strings.tasksSortEstimate,
  TasksSort.updated => Strings.tasksSortUpdated,
};

/// The display name for one due-date window.
String taskDueFilterLabel(TasksDueFilter filter) => switch (filter) {
  TasksDueFilter.any => Strings.tasksDueAny,
  TasksDueFilter.overdue => Strings.tasksDueOverdue,
  TasksDueFilter.today => Strings.tasksDueToday,
  TasksDueFilter.thisWeek => Strings.tasksDueThisWeek,
  TasksDueFilter.none => Strings.tasksDueNone,
};

/// The search / filter / sort controls above a project's task board or list.
/// Reads and writes the shared [tasksViewProvider]; all colour comes from the
/// theme, all copy from [Strings].
class TaskToolbar extends ConsumerStatefulWidget {
  const TaskToolbar({super.key});

  @override
  ConsumerState<TaskToolbar> createState() => _TaskToolbarState();
}

class _TaskToolbarState extends ConsumerState<TaskToolbar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(tasksViewProvider).query,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(tasksViewProvider);
    final controls = ref.read(tasksViewProvider.notifier);
    ref.listen(tasksViewProvider, (previous, next) {
      if (next.query != _searchController.text) {
        _searchController.text = next.query;
      }
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('task-search'),
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: Strings.tasksSearchHint,
            prefixIcon: Icon(Icons.search),
            isDense: true,
          ),
          textInputAction: TextInputAction.search,
          onChanged: controls.setQuery,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (var i = 0; i < Strings.tasksPriorityLabels.length; i++)
              FilterChip(
                key: Key('task-priority-filter-$i'),
                label: Text(Strings.tasksPriorityLabels[i]),
                selected: view.priorities.contains(i),
                onSelected: (_) => controls.togglePriority(i),
              ),
            for (final filter in TasksDueFilter.values)
              ChoiceChip(
                key: Key('task-due-${filter.name}'),
                label: Text(taskDueFilterLabel(filter)),
                selected: view.dueFilter == filter,
                onSelected: (_) => controls.setDueFilter(filter),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            FilterChip(
              key: const Key('task-group'),
              avatar: const Icon(Icons.view_column_outlined, size: 18),
              label: const Text(Strings.tasksGroupBy),
              selected: view.groupByStatusFlag,
              onSelected: controls.setGroupByStatus,
            ),
            const Spacer(),
            PopupMenuButton<TasksSort>(
              key: const Key('task-sort'),
              icon: const Icon(Icons.sort),
              tooltip: Strings.tasksSortBy,
              onSelected: controls.setSort,
              itemBuilder: (context) => [
                for (final sort in TasksSort.values)
                  PopupMenuItem(
                    value: sort,
                    child: Text(taskSortLabel(sort)),
                  ),
              ],
            ),
            Text(
              Strings.tasksShowDone,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Switch(
              key: const Key('task-show-done'),
              value: view.showDone,
              onChanged: controls.setShowDone,
            ),
          ],
        ),
      ],
    );
  }
}
