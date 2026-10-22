// lib/features/projects/widgets/task_card.dart
import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/task_status.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/features/projects/model/project_progress.dart';
import 'package:flutter/material.dart';

/// One task on the board or list: a priority dot, the title (struck through
/// when Done), and optional due-date / estimate meta lines. Colours come from
/// the theme only.
class TaskCard extends StatelessWidget {
  const TaskCard({required this.task, this.onTap, super.key});

  final TaskRow task;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final done = TaskStatus.fromDb(task.boardStatus) == TaskStatus.done;
    final dueDate = task.dueDate;
    final estimateMinutes = task.estimateMinutes;
    final due = dueDate == null ? '' : deadlineLabel(dueDate, DateTime.now());
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (task.priority > 0) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Expanded(
                    child: Text(
                      task.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done ? colors.muted : null,
                      ),
                    ),
                  ),
                ],
              ),
              if (due.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(due, style: theme.textTheme.labelSmall),
              ],
              if (estimateMinutes != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  formatDurationMinutes(estimateMinutes),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
