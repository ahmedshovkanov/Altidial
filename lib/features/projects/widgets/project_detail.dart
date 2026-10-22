// lib/features/projects/widgets/project_detail.dart
import 'package:altidial/app/navigation/tab_bar_inset.dart';
import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/app/theme/tone_colors.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/repositories/project_repository.dart';
import 'package:altidial/features/projects/model/project_progress.dart';
import 'package:altidial/features/projects/providers.dart';
import 'package:altidial/features/projects/widgets/task_board.dart';
import 'package:altidial/features/projects/widgets/task_list.dart';
import 'package:altidial/features/projects/widgets/task_toolbar.dart';
import 'package:altidial/shared/layout/content_width.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One project's detail: header ring + planned/actual, a tone-split bar,
/// rename/notes/priority editors, deadline/target/tone editors, a 7-day
/// velocity strip, linked events with per-event actuals (tap opens the day
/// via [onOpenDay]) and the complete/reopen/archive/delete menu.
class ProjectDetailView extends ConsumerWidget {
  const ProjectDetailView({
    required this.projectId,
    required this.onOpenDay,
    super.key,
  });

  final int projectId;
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(projectDetailProvider(projectId));
    return detail.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      skipError: true,
      data: (loaded) => _DetailBody(detail: loaded, onOpenDay: onOpenDay),
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (error, stack) {
        // Deleted projects surface as StateError (getSingle on a gone row):
        // close the detail. Other failures stay with a retry.
        if (error is StateError) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.pop(context);
          });
        }
        return Scaffold(
          appBar: AppBar(),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    Strings.projectsLoadError,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: () =>
                        ref.invalidate(projectDetailProvider(projectId)),
                    child: const Text(Strings.deckRetry),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail, required this.onOpenDay});

  final ProjectDetail detail;
  final ValueChanged<DateTime> onOpenDay;

  ProjectRow get project => detail.project;

  Future<void> _fail(BuildContext context, Object error) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(Strings.projectsSaveFailed)));
  }

  void _showUndo(
    BuildContext context, {
    required String message,
    required Future<void> Function() undo,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: Strings.projectsUndo,
          onPressed: () async {
            try {
              await undo();
            } on Object {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(Strings.projectsSaveFailed),
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _RenameDialog(initial: project.title),
    );
    if (result == null || result == project.title) return;
    try {
      await ref.read(projectsRepositoryProvider).updateTitle(project.id, result);
    } on Object {
      if (!context.mounted) return;
      await _fail(context, 'rename');
    }
  }

  Future<void> _editNotes(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _NotesDialog(initial: project.notes),
    );
    if (result == null) return;
    try {
      await ref
          .read(projectsRepositoryProvider)
          .updateNotes(project.id, result.isEmpty ? null : result);
    } on Object {
      if (!context.mounted) return;
      await _fail(context, 'notes');
    }
  }

  Future<void> _setPriority(
    BuildContext context,
    WidgetRef ref,
    int priority,
  ) async {
    try {
      await ref
          .read(projectsRepositoryProvider)
          .updatePriority(project.id, priority);
    } on Object {
      if (!context.mounted) return;
      await _fail(context, 'priority');
    }
  }

  Future<void> _editDeadline(BuildContext context, WidgetRef ref) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: project.deadline ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    try {
      await ref
          .read(projectsRepositoryProvider)
          .updateDeadline(project.id, picked);
    } on Object {
      if (!context.mounted) return;
      await _fail(context, 'deadline');
    }
  }

  Future<void> _setDeadline(
    BuildContext context,
    WidgetRef ref,
    DateTime? deadline,
  ) async {
    try {
      await ref
          .read(projectsRepositoryProvider)
          .updateDeadline(project.id, deadline);
    } on Object {
      if (!context.mounted) return;
      await _fail(context, 'deadline-chip');
    }
  }

  Future<void> _clearDeadline(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(projectsRepositoryProvider).updateDeadline(project.id, null);
    } on Object {
      if (!context.mounted) return;
      await _fail(context, 'deadline-clear');
    }
  }

  Future<void> _editTarget(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) =>
          _TargetDialog(initialMinutes: project.targetMinutes),
    );
    if (result == null) return;
    try {
      await ref
          .read(projectsRepositoryProvider)
          .updateTarget(project.id, result.isEmpty ? null : int.parse(result));
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(Strings.projectsSaveFailed)),
        );
      }
    }
  }

  Future<void> _setAffinity(
    BuildContext context,
    WidgetRef ref,
    int? toneIndex,
  ) async {
    try {
      await ref
          .read(projectsRepositoryProvider)
          .updateAffinity(project.id, toneIndex);
    } on Object {
      if (!context.mounted) return;
      await _fail(context, 'affinity');
    }
  }

  Future<void> _menuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final repository = ref.read(projectsRepositoryProvider);
    try {
      switch (action) {
        case 'complete':
          await repository.complete(project.id);
          if (!context.mounted) return;
          _showUndo(
            context,
            message: Strings.projectsCompletedMessage,
            undo: () => repository.reopen(project.id),
          );
        case 'reopen':
          await repository.reopen(project.id);
        case 'archive':
          await repository.archive(project.id);
          if (!context.mounted) return;
          _showUndo(
            context,
            message: Strings.projectsArchivedMessage,
            undo: () => repository.unarchive(project.id),
          );
        case 'delete':
          await _delete(context, ref);
      }
    } on Object {
      if (!context.mounted) return;
      await _fail(context, action);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(Strings.projectsDeleteTitle),
        content: const Text(Strings.projectsDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(Strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(Strings.projectsDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(projectsRepositoryProvider).deleteAndUnlink(project.id);
    } on Object {
      if (!context.mounted) return;
      await _fail(context, 'delete');
      return;
    }
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final progress = ProjectProgress.compute(
      plannedMinutes: detail.plannedMinutes,
      actualMinutes: detail.actualMinutes,
      targetMinutes: project.targetMinutes,
    );
    final counts = ref.watch(taskCountsProvider(project.id));
    final now = DateTime.now();
    final overdue = ProjectProgress.isOverdue(project.deadline, now);
    final today = startOfDay(now);
    final upcoming = detail.events
        .where((e) => !startOfDay(e.date).isBefore(today))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final past = detail.events
        .where((e) => startOfDay(e.date).isBefore(today))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final perTone = <Tone, int>{};
    for (final event in detail.events) {
      final tone = Tone.fromDbIndex(event.toneIndex);
      perTone[tone] =
          (perTone[tone] ?? 0) + (event.endMinute - event.startMinute);
    }
    final toneTotal = perTone.values.fold(0, (sum, minutes) => sum + minutes);

    // Derived from the detail's grouped done-only sessions (never fresh DAO
    // rows): the 7-day velocity and per-event actuals, both O(n).
    final velocity = velocityLast7Days(
      doneSessions: detail.doneSessions,
      now: now,
    );
    final perEventSeconds = <int, int>{};
    for (final session in detail.doneSessions) {
      perEventSeconds[session.eventId] =
          (perEventSeconds[session.eventId] ?? 0) + session.activeSeconds;
    }

    Widget eventRow(EventRow event) {
      final planned = event.endMinute - event.startMinute;
      final actual = (perEventSeconds[event.id] ?? 0) ~/ 60;
      return ListTile(
        leading: Container(
          key: Key('project-event-tone-${event.id}'),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.toneColors.fillFor(
              Tone.fromDbIndex(event.toneIndex),
            ),
          ),
        ),
        title: Text(event.title),
        subtitle: Text(
          Strings.projectsEventActuals(
            Strings.friendlyDate(event.date),
            formatMinuteRange(event.startMinute, event.endMinute),
            formatDurationMinutes(actual),
            formatDurationMinutes(planned),
          ),
        ),
        onTap: () => onOpenDay(event.date),
      );
    }

    Widget eventSection(String title, List<EventRow> events) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        for (final event in events) eventRow(event),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () => _rename(context, ref),
          child: Text(project.title),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (action) => _menuAction(context, ref, action),
            itemBuilder: (context) => [
              if (project.status == 0)
                const PopupMenuItem(
                  value: 'complete',
                  child: Text(Strings.projectsMarkComplete),
                ),
              if (project.status != 0)
                const PopupMenuItem(
                  value: 'reopen',
                  child: Text(Strings.projectsReopen),
                ),
              if (project.status != 2)
                const PopupMenuItem(
                  value: 'archive',
                  child: Text(Strings.projectsArchive),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Text(Strings.projectsDelete),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          TabBarInset.of(context) + AppSpacing.xl,
        ),
        child: ContentWidth(
          maxWidth: ContentWidths.stats,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      strokeWidth: 6,
                      value: progress.clamp(0.0, 1.0).toDouble(),
                      backgroundColor: colors.outline,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        project.toneIndex == null
                            ? colors.ink
                            : context.toneColors.fillFor(
                                Tone.fromDbIndex(project.toneIndex!),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Strings.projectsProgress(
                            formatDurationMinutes(detail.actualMinutes),
                            formatDurationMinutes(
                              project.targetMinutes != null &&
                                      project.targetMinutes! > 0
                                  ? project.targetMinutes!
                                  : detail.plannedMinutes,
                            ),
                          ),
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          Strings.eventCount(detail.events.length),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if ((counts != null && counts.total > 0) ||
                  detail.doneSessions.isNotEmpty ||
                  project.deadline != null) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    if (counts != null && counts.total > 0)
                      _StatChip(
                        icon: Icons.checklist,
                        label: Strings.projectsTasksLine(
                          counts.done,
                          counts.total,
                        ),
                      ),
                    if (detail.doneSessions.isNotEmpty)
                      _StatChip(
                        icon: Icons.timer_outlined,
                        label: Strings.projectsSessions(
                          detail.doneSessions.length,
                        ),
                      ),
                    if (project.deadline != null)
                      _StatChip(
                        icon: Icons.event,
                        label: deadlineLabel(project.deadline, now),
                        danger: overdue,
                      ),
                  ],
                ),
              ],
              if (project.status == 1 && project.completedAt != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  Strings.projectsCompletedOn(
                    Strings.friendlyDate(project.completedAt!),
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.muted,
                  ),
                ),
              ],
              if (toneTotal > 0) ...[
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 10,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    child: Row(
                      children: [
                        for (final entry in perTone.entries)
                          Expanded(
                            flex: entry.value,
                            child: Container(
                              color: context.toneColors.fillFor(entry.key),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.flag),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            Strings.projectsPriorityTitle,
                            style: theme.textTheme.titleSmall,
                          ),
                          // Same danger dot as the hub row: AppColors stays
                          // neutral by design, so priority reuses danger.
                          if (project.priority > 0) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: colors.danger,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          for (var i = 0; i < 4; i++)
                            ChoiceChip(
                              label: Text(Strings.projectsPriorityLabels[i]),
                              selected: project.priority == i,
                              onSelected: (_) => _setPriority(context, ref, i),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.notes),
                  title: const Text(Strings.projectsNotesTitle),
                  subtitle: Text(
                    project.notes ?? Strings.projectsNotesHint,
                    style: project.notes == null
                        ? TextStyle(color: colors.muted)
                        : null,
                  ),
                  trailing: const Icon(Icons.edit),
                  onTap: () => _editNotes(context, ref),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TaskBoardSection(projectId: project.id),
              const SizedBox(height: AppSpacing.lg),
              // Metadata (deadline/target/affinity) stays editable even for
              // past-linked events: past read-only gates event links in the
              // event sheet, not project metadata (spec §4 overlap).
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.event),
                      title: const Text(Strings.projectsDeadline),
                      subtitle: Text(
                        project.deadline == null
                            ? Strings.projectsNoDeadline
                            : Strings.friendlyDate(project.deadline!),
                        style: overdue ? TextStyle(color: colors.danger) : null,
                      ),
                      trailing: const Icon(Icons.edit),
                      onTap: () => _editDeadline(context, ref),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          ActionChip(
                            label: const Text(Strings.projectsDeadlineToday),
                            onPressed: () => _setDeadline(context, ref, today),
                          ),
                          ActionChip(
                            label: const Text(Strings.projectsDeadlineTomorrow),
                            onPressed: () => _setDeadline(
                              context,
                              ref,
                              DateTime(today.year, today.month, today.day + 1),
                            ),
                          ),
                          ActionChip(
                            label: const Text(Strings.projectsDeadlineNextWeek),
                            onPressed: () => _setDeadline(
                              context,
                              ref,
                              DateTime(today.year, today.month, today.day + 7),
                            ),
                          ),
                          if (project.deadline != null)
                            ActionChip(
                              label: const Text(Strings.projectsDeadlineClear),
                              onPressed: () => _clearDeadline(context, ref),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text(Strings.projectsTarget),
                  subtitle: Text(
                    project.targetMinutes == null
                        ? Strings.projectsNoTarget
                        : formatDurationMinutes(project.targetMinutes!),
                  ),
                  trailing: const Icon(Icons.edit),
                  onTap: () => _editTarget(context, ref),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.palette_outlined),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            Strings.projectsAffinity,
                            style: theme.textTheme.titleSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          ChoiceChip(
                            label: const Text(Strings.projectsNoAffinity),
                            selected: project.toneIndex == null,
                            onSelected: (_) => _setAffinity(context, ref, null),
                          ),
                          for (final tone in Tone.values)
                            ChoiceChip(
                              label: Text(tone.label),
                              selected: project.toneIndex == tone.dbIndex,
                              onSelected: (_) =>
                                  _setAffinity(context, ref, tone.dbIndex),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                Strings.projectsVelocityTitle,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (velocity.every((minutes) => minutes == 0))
                Text(
                  Strings.projectsVelocityEmpty,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.muted,
                  ),
                )
              else
                _VelocityBars(velocity: velocity),
              const SizedBox(height: AppSpacing.lg),
              Text(
                Strings.projectsLinkedEvents,
                style: theme.textTheme.titleSmall,
              ),
              if (detail.events.isEmpty)
                Text(
                  Strings.projectsDetailEmpty,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.muted,
                  ),
                )
              else ...[
                if (upcoming.isNotEmpty) ...[
                  eventSection(Strings.projectsUpcoming, upcoming),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (past.isNotEmpty) eventSection(Strings.projectsPast, past),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The tasks section of a project detail: a Board | List switch held in local
/// state over the project's shared task stream. Card taps are a placeholder
/// until the task editor lands (Task 5).
class TaskBoardSection extends ConsumerStatefulWidget {
  const TaskBoardSection({required this.projectId, super.key});

  final int projectId;

  @override
  ConsumerState<TaskBoardSection> createState() => _TaskBoardSectionState();
}

class _TaskBoardSectionState extends ConsumerState<TaskBoardSection> {
  bool _board = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                Strings.tasksTitle,
                style: theme.textTheme.titleSmall,
              ),
            ),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: true, label: Text(Strings.tasksBoardView)),
                ButtonSegment(value: false, label: Text(Strings.tasksListView)),
              ],
              selected: {_board},
              onSelectionChanged: (selection) =>
                  setState(() => _board = selection.first),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        const TaskToolbar(),
        const SizedBox(height: AppSpacing.md),
        if (_board)
          TaskBoard(projectId: widget.projectId)
        else
          TaskList(projectId: widget.projectId),
      ],
    );
  }
}

/// Seven rounded bars, oldest first, heights scaled to the week's max and
/// grown in on first paint. Each day carries a faint baseline tick; zero days
/// render as faint ticks. Animation collapses under reduced motion.
class _VelocityBars extends StatelessWidget {
  const _VelocityBars({required this.velocity});

  final List<int> velocity;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    const maxBarHeight = 64.0;
    const minBarHeight = 4.0;
    final maxMinutes = velocity.fold(0, (a, b) => a > b ? a : b);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduceMotion ? Duration.zero : AppMotion.slow,
      curve: AppMotion.standard,
      builder: (context, t, _) => Row(
        key: const Key('projects-velocity-bars'),
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final minutes in velocity)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height:
                          velocityBarHeight(
                            minutes: minutes,
                            maxMinutes: maxMinutes,
                            minHeight: minBarHeight,
                            maxHeight: maxBarHeight,
                          ) *
                          t,
                      decoration: BoxDecoration(
                        color: minutes == 0 ? colors.outline : colors.ink,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(height: 2, color: colors.outline),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Rename dialog owning its controller so dispose happens with the route.
/// Save stays disabled until the title validates (1–80 chars).
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(Strings.projectsRenameTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: Strings.projectsRenameHint,
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) {
          if (validateProjectTitle(_controller.text) == null) {
            Navigator.pop(context, _controller.text.trim());
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(Strings.cancel),
        ),
        FilledButton(
          onPressed: validateProjectTitle(_controller.text) == null
              ? () => Navigator.pop(context, _controller.text.trim())
              : null,
          child: const Text(Strings.save),
        ),
      ],
    );
  }
}

/// Notes dialog owning its controller. The counter mirrors the debrief
/// pattern (`length/max`); save stays disabled past 500 chars. Popping an
/// empty string means "cleared" — the caller maps it to null.
class _NotesDialog extends StatefulWidget {
  const _NotesDialog({required this.initial});

  final String? initial;

  @override
  State<_NotesDialog> createState() => _NotesDialogState();
}

class _NotesDialogState extends State<_NotesDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = validateNotes(_controller.text) == null;
    return AlertDialog(
      title: const Text(Strings.projectsNotesTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: Strings.projectsNotesHint,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              Strings.projectsNotesCounter(_controller.text.length, 500),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(Strings.cancel),
        ),
        FilledButton(
          onPressed: valid
              ? () => Navigator.pop(context, _controller.text.trim())
              : null,
          child: const Text(Strings.save),
        ),
      ],
    );
  }
}

/// Hours text for a stored minute value: whole hours without decimals
/// (`120` → `2`), fractions trimmed (`90` → `1.5`, `45` → `0.75`).
String _hoursText(int minutes) {
  final hours = minutes / 60;
  if (hours == hours.roundToDouble()) return hours.toInt().toString();
  var text = hours.toStringAsFixed(2);
  while (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  if (text.endsWith('.')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}

/// Target dialog owning its controller so dispose happens with the route
/// (disposing a controller while the pop animation still builds throws).
/// Input is in hours (decimals allowed); submit converts `hours * 60` and
/// rounds to whole minutes before the shared minute validator runs. Popping
/// an empty string means "cleared" — the caller maps it to null.
class _TargetDialog extends StatefulWidget {
  const _TargetDialog({required this.initialMinutes});

  final int? initialMinutes;

  @override
  State<_TargetDialog> createState() => _TargetDialogState();
}

class _TargetDialogState extends State<_TargetDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialMinutes == null
        ? ''
        : _hoursText(widget.initialMinutes!),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      Navigator.pop(context, '');
      return;
    }
    final hours = double.tryParse(text);
    if (hours == null || !hours.isFinite) {
      setState(() => _error = Strings.projectsTargetHoursHint);
      return;
    }
    final minutes = (hours * 60).round();
    final message = validateTargetMinutes(minutes);
    if (message != null) {
      setState(() => _error = message);
      return;
    }
    Navigator.pop(context, minutes.toString());
  }

  void _bumpHours(double delta) {
    final current = double.tryParse(_controller.text.trim()) ?? 0;
    final next = (current + delta).clamp(0, double.infinity);
    _controller
      ..text = _hoursText((next * 60).round())
      ..selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    if (_error != null) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(Strings.projectsTarget),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            autofocus: true,
            decoration: InputDecoration(
              hintText: Strings.projectsTargetHoursHint,
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                tooltip: Strings.stepperDecrease(Strings.projectsTarget),
                onPressed: () => _bumpHours(-1),
              ),
              const SizedBox(width: AppSpacing.md),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: Strings.stepperIncrease(Strings.projectsTarget),
                onPressed: () => _bumpHours(1),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(Strings.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text(Strings.save),
        ),
      ],
    );
  }
}

/// One neutral hero chip. Colour on screen only ever means a tone, so chips
/// stay ink/muted (with danger reserved for overdue).
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Chip(
      avatar: Icon(
        icon,
        size: 16,
        color: danger ? colors.danger : colors.muted,
      ),
      label: Text(
        label,
        style: danger ? TextStyle(color: colors.danger) : null,
      ),
    );
  }
}
