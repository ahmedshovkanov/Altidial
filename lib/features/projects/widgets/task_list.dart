// lib/features/projects/widgets/task_list.dart
import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/task_status.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/features/projects/model/task_board.dart';
import 'package:altidial/features/projects/providers.dart';
import 'package:altidial/features/projects/widgets/task_card.dart';
import 'package:altidial/features/projects/widgets/task_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A project's tasks as a single list, flat or grouped by status. Renders
/// inside the detail's scroll view, so it wraps its content and never scrolls
/// itself.
class TaskList extends ConsumerWidget {
  const TaskList({required this.projectId, super.key});

  final int projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final async = ref.watch(taskListProvider(projectId));
    final view = ref.watch(tasksViewProvider);
    final raw = async.valueOrNull ?? const <TaskRow>[];
    if (raw.isEmpty) {
      return Text(
        Strings.tasksEmpty,
        style: theme.textTheme.bodyMedium?.copyWith(color: colors.muted),
      );
    }
    final tasks = applyTasksView(raw, view);
    if (tasks.isEmpty) {
      return Text(
        Strings.tasksNoMatch,
        style: theme.textTheme.bodyMedium?.copyWith(color: colors.muted),
      );
    }
    Widget card(TaskRow task) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TaskCard(
        task: task,
        onTap: () => showTaskEditor(context, ref, task: task),
      ),
    );
    if (view.groupByStatusFlag) {
      final grouped = groupByStatus(tasks);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final status in TaskStatus.values)
            if (grouped[status]!.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Text(
                  Strings.tasksStatusLabels[status.index],
                  style: theme.textTheme.titleSmall,
                ),
              ),
              for (final task in grouped[status]!) card(task),
            ],
        ],
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tasks.length,
      itemBuilder: (context, index) => card(tasks[index]),
    );
  }
}
