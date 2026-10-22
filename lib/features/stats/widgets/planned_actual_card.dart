import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/repositories/stats_repository.dart';
import 'package:energy_clock/features/stats/model/stats_period.dart';
import 'package:energy_clock/features/stats/widgets/section_card.dart';
import 'package:energy_clock/shared/charts/paired_bars_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Planned (muted) against completed (tone) minutes per tone, with the
/// adherence percent as a large figure above the chart.
class PlannedActualCard extends ConsumerWidget {
  const PlannedActualCard({
    required this.snapshot,
    required this.window,
    super.key,
  });

  final StatsSnapshot snapshot;
  final StatsWindow window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toneColors = context.toneColors;
    final theme = Theme.of(context);
    final adherence = snapshot.adherencePercent;

    final summary = Strings.joinWords([
      if (adherence != null) Strings.statsAdherence(adherence),
      for (final row in snapshot.plannedByTone)
        Strings.statsToneShare(
          row.tone.label,
          Strings.statsPlannedDone(
            formatDurationMinutes(row.plannedMinutes),
            formatDurationMinutes(row.completedMinutes),
          ),
        ),
    ]);
    final empty = snapshot.plannedTotal == 0;

    final card = StatsSectionCard(
      title: Strings.statsPlannedActual,
      empty: empty,
      emptyMessage: Strings.statsEmptyPlanned,
      semanticsLabel: summary,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (adherence != null) ...[
            Text(
              Strings.statsAdherence(adherence),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          SizedBox(
            height: 140,
            width: double.infinity,
            child: CustomPaint(
              painter: PairedBarsPainter(
                rows: [
                  for (final row in snapshot.plannedByTone)
                    (
                      tone: row.tone,
                      planned: row.plannedMinutes,
                      completed: row.completedMinutes,
                    ),
                ],
                colors: {
                  for (final tone in Tone.values)
                    tone: toneColors.fillFor(tone),
                },
                plannedColor: context.appColors.outline,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final row in snapshot.plannedByTone)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: toneColors.fillFor(row.tone),
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox.square(dimension: 10),
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Expanded(
                    child: Text(
                      '${row.tone.label}: ${Strings.statsPlannedDone(formatDurationMinutes(row.plannedMinutes), formatDurationMinutes(row.completedMinutes))}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    if (empty) return card;
    return Semantics(label: summary, excludeSemantics: true, child: card);
  }
}
