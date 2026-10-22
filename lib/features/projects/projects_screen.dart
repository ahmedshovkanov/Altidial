// lib/features/projects/projects_screen.dart
import 'package:altidial/app/navigation/tab_bar_inset.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/repositories/project_repository.dart';
import 'package:altidial/features/projects/model/project_progress.dart';
import 'package:altidial/features/projects/providers.dart';
import 'package:altidial/features/projects/widgets/cross_project_board.dart';
import 'package:altidial/features/projects/widgets/project_detail.dart';
import 'package:altidial/features/projects/widgets/project_row.dart';
import 'package:altidial/features/projects/widgets/today_view.dart';
import 'package:altidial/shared/layout/content_width.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The three ways to look at Projects: the Outcomes hub, the cross-project
/// Board and what is planned Today.
enum ProjectsSurface { outcomes, board, today }

/// Tab-safe body for the Projects tab (no Scaffold/AppBar). A segmented control
/// switches between the Outcomes hub, the cross-project [CrossProjectBoard] and
/// [TodayView].
class ProjectsTabBody extends ConsumerStatefulWidget {
  const ProjectsTabBody({required this.onOpenDay, super.key});

  final ValueChanged<DateTime> onOpenDay;

  @override
  ConsumerState<ProjectsTabBody> createState() => _ProjectsTabBodyState();
}

class _ProjectsTabBodyState extends ConsumerState<ProjectsTabBody> {
  ProjectsSurface _surface = ProjectsSurface.outcomes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: SegmentedButton<ProjectsSurface>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ProjectsSurface.outcomes,
                label: Text(Strings.projectsSurfaceOutcomes),
              ),
              ButtonSegment(
                value: ProjectsSurface.board,
                label: Text(Strings.projectsSurfaceBoard),
              ),
              ButtonSegment(
                value: ProjectsSurface.today,
                label: Text(Strings.projectsSurfaceToday),
              ),
            ],
            selected: {_surface},
            onSelectionChanged: (selection) =>
                setState(() => _surface = selection.first),
          ),
        ),
        Expanded(
          child: switch (_surface) {
            ProjectsSurface.outcomes => _OutcomesSurface(
              onOpenDay: widget.onOpenDay,
            ),
            ProjectsSurface.board => CrossProjectBoard(
              onOpenDay: widget.onOpenDay,
            ),
            ProjectsSurface.today => TodayView(onOpenDay: widget.onOpenDay),
          },
        ),
      ],
    );
  }
}

/// The Outcomes surface: the hub body behind the project-list stream's
/// loading/error states.
class _OutcomesSurface extends ConsumerWidget {
  const _OutcomesSurface({required this.onOpenDay});

  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectListProvider);
    return projects.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      skipError: true,
      data: (rows) => _HubBody(rows: rows, onOpenDay: onOpenDay),
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(Strings.projectsLoadError, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => ref.invalidate(projectListProvider),
                child: const Text(Strings.deckRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Projects hub: active projects, those ready to complete, and completed
/// & archived behind a collapsed section. Opened from the Profile card (the
/// tab count stays five). [onOpenDay] jumps to a linked event's day and is
/// passed through to the detail screen.
class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({required this.onOpenDay, super.key});

  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.projectsTitle)),
      body: ProjectsTabBody(onOpenDay: onOpenDay),
    );
  }
}

/// Shows a validated title dialog, creates the project, and returns its id.
/// Null on dismiss or failure (failure shows a SnackBar). Shared by the hub
/// empty state and the Profile card empty state.
Future<int?> showCreateProjectDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final title = await showDialog<String?>(
    context: context,
    builder: (dialogContext) => const _CreateProjectDialog(),
  );
  if (title == null) return null;
  try {
    return await ref.read(projectsRepositoryProvider).create(title);
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(Strings.projectsSaveFailed)),
      );
    }
    return null;
  }
}

/// Title dialog owning its controller so dispose happens with the route
/// (disposing a controller while the pop animation still builds throws).
class _CreateProjectDialog extends StatefulWidget {
  const _CreateProjectDialog();

  @override
  State<_CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<_CreateProjectDialog> {
  late final TextEditingController _controller = TextEditingController();
  String? _error;
  bool _valid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(Strings.projectCreateTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: Strings.projectCreateLabel,
          hintText: Strings.projectNameHint,
          errorText: _error,
        ),
        onChanged: (value) {
          final message = validateProjectTitle(value);
          setState(() {
            _error = _controller.text.isEmpty ? null : message;
            _valid = message == null;
          });
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(Strings.cancel),
        ),
        FilledButton(
          onPressed: _valid
              ? () => Navigator.pop(context, _controller.text.trim())
              : null,
          child: const Text(Strings.save),
        ),
      ],
    );
  }
}

class _HubBody extends ConsumerWidget {
  const _HubBody({required this.rows, required this.onOpenDay});

  final List<ProjectRow> rows;
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(projectsViewProvider);
    final viewControls = ref.read(projectsViewProvider.notifier);
    final now = DateTime.now();
    final query = view.query.trim().toLowerCase();
    final filtered = rows.where((p) {
      if (query.isNotEmpty && !p.title.toLowerCase().contains(query)) {
        return false;
      }
      if (view.toneFilter != null && p.toneIndex != view.toneFilter) {
        return false;
      }
      if (view.overdueOnly && !ProjectProgress.isOverdue(p.deadline, now)) {
        return false;
      }
      return true;
    }).toList();
    // Watch details in filter (repository) order so subscriptions stay stable,
    // then sort copies for display.
    final details = <int, AsyncValue<ProjectDetail>>{
      for (final p in filtered) p.id: ref.watch(projectDetailProvider(p.id)),
    };
    final taskCounts = <int, ({int done, int total})?>{
      for (final p in filtered) p.id: ref.watch(taskCountsProvider(p.id)),
    };
    // Loading details are unknown: keep them in Active until loaded so the
    // Ready section never flickers in and out on first paint.
    double? progressOrNull(ProjectRow p) {
      final async = details[p.id];
      if (async == null || async.isLoading) return null;
      final detail = async.valueOrNull;
      if (detail == null) return null;
      return ProjectProgress.compute(
        plannedMinutes: detail.plannedMinutes,
        actualMinutes: detail.actualMinutes,
        targetMinutes: p.targetMinutes,
      );
    }

    // Progress/recent sorts need the detail fields, so the hub passes them
    // via closures over its details map (see the comparator doc comments).
    int sortRows(ProjectRow a, ProjectRow b) {
      switch (view.sort) {
        case ProjectsSort.deadline:
          return compareByDeadline(a, b);
        case ProjectsSort.progress:
          return compareByProgress(
            a,
            b,
            progressOrNull(a) ?? 0.0,
            progressOrNull(b) ?? 0.0,
          );
        case ProjectsSort.recent:
          return compareByRecent(
            a,
            b,
            details[a.id]?.valueOrNull?.lastWorkedAt,
            details[b.id]?.valueOrNull?.lastWorkedAt,
          );
        case ProjectsSort.title:
          return compareByTitle(a, b);
      }
    }

    final ready = filtered
        .where((p) => p.status == 0)
        .where((p) {
          final progress = progressOrNull(p);
          return progress != null &&
              ProjectProgress.isReadyToComplete(progress);
        })
        .toList()
      ..sort(sortRows);
    final open = filtered
        .where((p) => p.status == 0)
        .where((p) {
          final progress = progressOrNull(p);
          return progress == null ||
              !ProjectProgress.isReadyToComplete(progress);
        })
        .toList()
      ..sort(sortRows);
    final completed = filtered.where((p) => p.status == 1).toList()
      ..sort(sortRows);
    final archived = filtered.where((p) => p.status == 2).toList()
      ..sort(sortRows);
    final visible = [...open, ...ready, ...completed, ...archived];

    Widget tile(ProjectRow p) {
      final detail = details[p.id]?.valueOrNull;
      return ProjectRowTile(
        project: p,
        plannedMinutes: detail?.plannedMinutes ?? 0,
        actualMinutes: detail?.actualMinutes ?? 0,
        sessionsCount: detail?.sessionsCount ?? 0,
        lastWorkedAt: detail?.lastWorkedAt,
        taskCounts: taskCounts[p.id],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ProjectDetailView(projectId: p.id, onOpenDay: onOpenDay),
          ),
        ),
      );
    }

    Widget section(String title, List<ProjectRow> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        for (final p in items) tile(p),
      ],
    );

    Widget filterChip(String label, int? toneIndex) => ChoiceChip(
      label: Text(label),
      selected: view.toneFilter == toneIndex,
      onSelected: (_) => viewControls.setToneFilter(toneIndex),
    );

    return SingleChildScrollView(
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
                Expanded(
                  child: Text(
                    Strings.projectsTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () => showCreateProjectDialog(context, ref),
                  child: const Text(Strings.projectNew),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (rows.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        Strings.projectsEmptyTitle,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        Strings.projectsEmptyHint,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton(
                        onPressed: () async {
                          final id = await showCreateProjectDialog(context, ref);
                          if (id != null && context.mounted) {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProjectDetailView(
                                  projectId: id,
                                  onOpenDay: onOpenDay,
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text(Strings.projectNew),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              TextField(
                decoration: const InputDecoration(
                  hintText: Strings.projectsSearchHint,
                  prefixIcon: Icon(Icons.search),
                ),
                textInputAction: TextInputAction.search,
                onChanged: viewControls.setQuery,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        filterChip(Strings.projectsFilterAll, null),
                        filterChip(
                          Strings.projectsFilterFocus,
                          Tone.focus.dbIndex,
                        ),
                        filterChip(
                          Strings.projectsFilterLife,
                          Tone.life.dbIndex,
                        ),
                        filterChip(
                          Strings.projectsFilterInbox,
                          Tone.inbox.dbIndex,
                        ),
                        FilterChip(
                          label: const Text(Strings.projectsFilterOverdue),
                          selected: view.overdueOnly,
                          onSelected: (_) => viewControls.setOverdueOnly(
                            !view.overdueOnly,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<ProjectsSort>(
                    icon: const Icon(Icons.sort),
                    tooltip: Strings.projectsSortBy,
                    onSelected: viewControls.setSort,
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: ProjectsSort.deadline,
                        child: Text(Strings.projectsSortDeadline),
                      ),
                      PopupMenuItem(
                        value: ProjectsSort.progress,
                        child: Text(Strings.projectsSortProgress),
                      ),
                      PopupMenuItem(
                        value: ProjectsSort.recent,
                        child: Text(Strings.projectsSortRecent),
                      ),
                      PopupMenuItem(
                        value: ProjectsSort.title,
                        child: Text(Strings.projectsSortTitle),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (visible.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      Strings.projectsNoMatch,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else ...[
                if (open.isNotEmpty) section(Strings.projectsActive, open),
                if (open.isNotEmpty && ready.isNotEmpty)
                  const SizedBox(height: AppSpacing.lg),
                if (ready.isNotEmpty) section(Strings.projectsReady, ready),
                if ((open.isNotEmpty || ready.isNotEmpty) &&
                    completed.isNotEmpty)
                  const SizedBox(height: AppSpacing.lg),
                if (completed.isNotEmpty)
                  section(Strings.projectsCompleted, completed),
                if (completed.isNotEmpty && archived.isNotEmpty)
                  const SizedBox(height: AppSpacing.lg),
                if (archived.isNotEmpty)
                  ExpansionTile(
                    title: Text(
                      Strings.projectsArchived,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    children: [for (final p in archived) tile(p)],
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
