// lib/features/projects/widgets/today_view.dart
import 'package:energy_clock/app/navigation/tab_bar_inset.dart';
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/task_status.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/features/projects/providers.dart';
import 'package:energy_clock/features/projects/widgets/task_card.dart';
import 'package:energy_clock/features/projects/widgets/task_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Every task planned for today, grouped by project. Done tasks are hidden, and
/// a card tap opens the shared task editor (whose planned-date chips include
/// Today — the "pull to today" path). Shows [Strings.todayEmpty] when nothing
/// is planned.
class TodayView extends ConsumerWidget {
  const TodayView({required this.onOpenDay, super.key});

  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final today = startOfDay(DateTime.now());
    final projects =
        ref.watch(projectListProvider).valueOrNull ?? const <ProjectRow>[];
    final all = ref.watch(allTasksProvider).valueOrNull ?? const <TaskRow>[];
    final planned = all
        .where(
          (task) =>
              task.plannedDate != null && _sameDay(task.plannedDate!, today),
        )
        .where((task) => task.boardStatus != TaskStatus.done.dbIndex)
        .toList();
    if (planned.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            Strings.todayEmpty,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: colors.muted),
          ),
        ),
      );
    }
    final titles = {for (final project in projects) project.id: project.title};
    final ordered = <int?>[
      ...titles.keys.where(
        (id) => planned.any((task) => task.projectId == id),
      ),
      if (planned.any((task) => !titles.containsKey(task.projectId))) null,
    ];
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        TabBarInset.of(context) + AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final id in ordered) ...[
            Text(
              id == null ? Strings.projectNone : titles[id]!,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final task in planned.where(
              (task) => id == null
                  ? !titles.containsKey(task.projectId)
                  : task.projectId == id,
            ))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: TaskCard(
                  task: task,
                  onTap: () => showTaskEditor(context, ref, task: task),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
