import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/features/clock/providers.dart';
import 'package:altidial/features/projects/projects_screen.dart';
import 'package:altidial/features/projects/providers.dart';
import 'package:altidial/features/projects/widgets/project_detail.dart';
import 'package:altidial/features/projects/widgets/project_row.dart';
import 'package:altidial/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Profile entry point for Projects: the top-3 active projects with
/// progress rings. Tapping opens the hub. Hidden while loading or when the
/// list fails, so a Projects hiccup never breaks the Profile tab.
class ProjectsCard extends ConsumerWidget {
  const ProjectsCard({super.key});

  void _openHub(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectsScreen(
          onOpenDay: (day) {
            ref.read(selectedDateProvider.notifier).select(day);
            Navigator.popUntil(context, (route) => route.isFirst);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectListProvider);
    return projects.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      skipError: true,
      data: (rows) {
        final active = rows.where((p) => p.status == 0).take(3).toList();
        return AppCard(
          onTap: () => _openHub(context, ref),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                Strings.projectsTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (active.isEmpty) ...[
                Text(
                  Strings.projectsEmptyHint,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.appColors.muted,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  onPressed: () async {
                    final id = await showCreateProjectDialog(context, ref);
                    if (id != null && context.mounted) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProjectDetailView(
                            projectId: id,
                            onOpenDay: (day) {
                              ref
                                  .read(selectedDateProvider.notifier)
                                  .select(day);
                              Navigator.popUntil(
                                context,
                                (route) => route.isFirst,
                              );
                            },
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text(Strings.projectNew),
                ),
              ] else
                for (final project in active)
                  _CardRow(project: project),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}

class _CardRow extends ConsumerWidget {
  const _CardRow({required this.project});

  final ProjectRow project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(projectDetailProvider(project.id)).valueOrNull;
    return ProjectRowTile(
      project: project,
      plannedMinutes: detail?.plannedMinutes ?? 0,
      actualMinutes: detail?.actualMinutes ?? 0,
    );
  }
}
