// lib/features/projects/widgets/project_row.dart
import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/tone_colors.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/features/projects/model/project_progress.dart';
import 'package:flutter/material.dart';

/// One project row: a progress ring, the title, an `actual of planned/target`
/// subtitle and the deadline chip.
///
/// Pure: the caller passes recomputed minutes and progress always comes from
/// `ProjectProgress.compute`, so the ring and the subtitle can never disagree.
/// Colours come from the theme only.
class ProjectRowTile extends StatelessWidget {
  const ProjectRowTile({
    required this.project,
    required this.plannedMinutes,
    required this.actualMinutes,
    this.sessionsCount = 0,
    this.lastWorkedAt,
    this.taskCounts,
    this.onTap,
    super.key,
  });

  final ProjectRow project;
  final int plannedMinutes;
  final int actualMinutes;

  /// Done sessions linked to the project; shown as the sessions meta line.
  final int sessionsCount;

  /// Newest done-session time; null when the project has no done sessions.
  final DateTime? lastWorkedAt;

  /// Done/total task progress for the project; the line is hidden while null
  /// or when the project has no tasks.
  final ({int done, int total})? taskCounts;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final progress = ProjectProgress.compute(
      plannedMinutes: plannedMinutes,
      actualMinutes: actualMinutes,
      targetMinutes: project.targetMinutes,
    );
    final denominator =
        project.targetMinutes != null && project.targetMinutes! > 0
        ? project.targetMinutes!
        : plannedMinutes;
    final now = DateTime.now();
    final deadline = deadlineLabel(project.deadline, now);
    final overdue = ProjectProgress.isOverdue(project.deadline, now);
    // Ring in the tone-affinity color; neutral ink when affinity is null.
    final ringColor = project.toneIndex == null
        ? colors.ink
        : context.toneColors.fillFor(Tone.fromDbIndex(project.toneIndex!));
    final meta = Strings.projectsMeta(
      sessionsCount,
      relativeDayLabel(lastWorkedAt, now),
    );
    final taskCounts = this.taskCounts;
    return ListTile(
      leading: SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(
          value: progress.clamp(0.0, 1.0).toDouble(),
          backgroundColor: colors.outline,
          valueColor: AlwaysStoppedAnimation<Color>(ringColor),
        ),
      ),
      title: Row(
        children: [
          Expanded(child: Text(project.title)),
          if (project.priority > 0)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: colors.danger,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            Strings.projectsProgress(
              formatDurationMinutes(actualMinutes),
              formatDurationMinutes(denominator),
            ),
          ),
          Text(meta),
          if (taskCounts != null && taskCounts.total > 0)
            Text(
              Strings.projectsTasksLine(taskCounts.done, taskCounts.total),
            ),
          if (project.status != 0 && project.completedAt != null)
            Text(
              Strings.projectsCompletedOn(
                Strings.friendlyDate(project.completedAt!),
              ),
            ),
          if (deadline.isNotEmpty)
            Chip(
              label: Text(
                deadline,
                style: overdue ? TextStyle(color: colors.danger) : null,
              ),
              side: overdue ? BorderSide(color: colors.danger) : null,
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}
