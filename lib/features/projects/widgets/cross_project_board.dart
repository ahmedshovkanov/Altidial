// lib/features/projects/widgets/cross_project_board.dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/task_status.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/features/projects/model/task_board.dart';
import 'package:energy_clock/features/projects/providers.dart';
import 'package:energy_clock/features/projects/widgets/task_drag.dart';
import 'package:energy_clock/features/projects/widgets/task_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Every project's tasks on one status board. A project filter chip row (All +
/// one per project) narrows the cards; each card carries a small project label
/// and opens the shared task editor on tap. The column layout mirrors
/// TaskBoard, but there is no inline add (a card has no single project here).
class CrossProjectBoard extends ConsumerStatefulWidget {
  const CrossProjectBoard({required this.onOpenDay, super.key});

  final ValueChanged<DateTime> onOpenDay;

  @override
  ConsumerState<CrossProjectBoard> createState() => _CrossProjectBoardState();
}

class _CrossProjectBoardState extends ConsumerState<CrossProjectBoard> {
  /// The selected project id, or null for every project.
  int? _projectFilter;

  @override
  Widget build(BuildContext context) {
    final projects =
        ref.watch(projectListProvider).valueOrNull ?? const <ProjectRow>[];
    final view = ref.watch(crossProjectTasksViewProvider);
    final all = ref.watch(allTasksProvider).valueOrNull ?? const <TaskRow>[];
    final titles = {for (final project in projects) project.id: project.title};
    final scoped = _projectFilter == null
        ? all
        : all.where((task) => task.projectId == _projectFilter).toList();
    final grouped = groupByStatus(applyTasksView(scoped, view));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              ChoiceChip(
                label: const Text(Strings.projectsFilterAll),
                selected: _projectFilter == null,
                onSelected: (_) => setState(() => _projectFilter = null),
              ),
              for (final project in projects)
                ChoiceChip(
                  label: Text(project.title),
                  selected: _projectFilter == project.id,
                  onSelected: (_) =>
                      setState(() => _projectFilter = project.id),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final status in TaskStatus.values)
                  _BoardColumn(
                    status: status,
                    tasks: grouped[status]!,
                    projectTitle: (task) => titles[task.projectId],
                    onTapTask: (task) =>
                        showTaskEditor(context, ref, task: task),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One cross-project board column: a status header with the live count and a
/// scrolling list of cards, each tagged with its project name.
class _BoardColumn extends ConsumerWidget {
  const _BoardColumn({
    required this.status,
    required this.tasks,
    required this.projectTitle,
    required this.onTapTask,
  });

  final TaskStatus status;
  final List<TaskRow> tasks;
  final String? Function(TaskRow) projectTitle;
  final ValueChanged<TaskRow> onTapTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return SizedBox(
      width: 240,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      taskStatusLabel(status),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    '${tasks.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TaskDropZone(
                dropKey: Key('cross-task-drop-${status.name}'),
                onAccept: (id) =>
                    ref.read(tasksRepositoryProvider).move(id, status),
                child: ListView(
                  children: [
                    for (final task in tasks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (projectTitle(task) != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: AppSpacing.xs,
                                  bottom: 2,
                                ),
                                child: Text(
                                  Strings.projectsTaskProject(
                                    projectTitle(task)!,
                                  ),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colors.muted,
                                  ),
                                ),
                              ),
                            DraggableTaskCard(
                              task: task,
                              cardWidth: 220,
                              onTap: () => onTapTask(task),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
