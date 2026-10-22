// lib/features/projects/widgets/task_board.dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/task_status.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/features/projects/model/task_board.dart';
import 'package:energy_clock/features/projects/providers.dart';
import 'package:energy_clock/features/projects/widgets/task_drag.dart';
import 'package:energy_clock/features/projects/widgets/task_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// An estimate as human text: `No estimate` for null, else `2h 30m`.
String estimateLabel(int? minutes) => minutes == null
    ? Strings.tasksMetaNoEstimate
    : formatDurationMinutes(minutes);

/// A project's tasks as five status columns (Backlog → Done) that scroll
/// horizontally. Each column has an inline add field and accepts cards dragged
/// from other columns.
class TaskBoard extends ConsumerWidget {
  const TaskBoard({required this.projectId, super.key});

  final int projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(taskListProvider(projectId));
    final view = ref.watch(tasksViewProvider);
    final tasks = applyTasksView(async.valueOrNull ?? const <TaskRow>[], view);
    final grouped = groupByStatus(tasks);
    return SizedBox(
      height: 360,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final status in TaskStatus.values)
              _Column(
                projectId: projectId,
                status: status,
                tasks: grouped[status]!,
              ),
          ],
        ),
      ),
    );
  }
}

/// One board column: a header with the live count, the dragged-into drop area,
/// an inline add field and an Add button. Owns the add controller so dispose
/// happens with the column.
class _Column extends ConsumerStatefulWidget {
  const _Column({
    required this.projectId,
    required this.status,
    required this.tasks,
  });

  final int projectId;
  final TaskStatus status;
  final List<TaskRow> tasks;

  @override
  ConsumerState<_Column> createState() => _ColumnState();
}

class _ColumnState extends ConsumerState<_Column> {
  final TextEditingController _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid => validateTaskTitle(_controller.text) == null;

  Future<void> _add() async {
    if (!_valid || _saving) return;
    final title = _controller.text.trim();
    setState(() => _saving = true);
    try {
      final repository = ref.read(tasksRepositoryProvider);
      final id = await repository.create(widget.projectId, title);
      // `create` starts tasks in Todo; upgrade to this column when different.
      if (widget.status != TaskStatus.todo) {
        await repository.move(id, widget.status);
      }
      _controller.clear();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _move(int taskId) =>
      ref.read(tasksRepositoryProvider).move(taskId, widget.status);

  @override
  Widget build(BuildContext context) {
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
                      taskStatusLabel(widget.status),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    '${widget.tasks.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TaskDropZone(
                dropKey: Key('task-drop-${widget.status.name}'),
                onAccept: _move,
                child: ListView(
                  children: [
                    for (final task in widget.tasks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: DraggableTaskCard(
                          task: task,
                          cardWidth: 220,
                          onTap: () =>
                              showTaskEditor(context, ref, task: task),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: Key('task-add-${widget.status.name}'),
              controller: _controller,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: Strings.tasksAddHint,
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _add(),
            ),
            const SizedBox(height: AppSpacing.xs),
            FilledButton.tonal(
              onPressed: _valid && !_saving ? _add : null,
              child: const Text(Strings.tasksAdd),
            ),
          ],
        ),
      ),
    );
  }
}
