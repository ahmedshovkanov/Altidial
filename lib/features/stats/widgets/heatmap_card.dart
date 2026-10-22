import 'package:altidial/app/settings/settings_providers.dart';
import 'package:altidial/app/theme/tone_colors.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/repositories/stats_repository.dart';
import 'package:altidial/features/stats/model/heatmap.dart';
import 'package:altidial/features/stats/model/stats_period.dart';
import 'package:altidial/features/stats/widgets/section_card.dart';
import 'package:altidial/shared/charts/heatmap_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// When focus happens: a 7×24 grid, weekday rows starting on the first day of
/// the week, hours across, with hour ticks at 0/6/12/18/24 below.
class HeatmapCard extends ConsumerWidget {
  const HeatmapCard({required this.snapshot, required this.window, super.key});

  final StatsSnapshot snapshot;
  final StatsWindow window;

  static const double _cellHeight = 16;
  static const double _gap = 2;
  static const double _chartHeight = _cellHeight * 7 + _gap * 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstWeekday =
        ref.watch(firstDayOfWeekProvider).valueOrNull ?? DateTime.monday;
    final theme = Theme.of(context);
    final toneColors = context.toneColors;

    final matrix = buildHeatmap(
      snapshot.focusInstants,
      firstWeekday: firstWeekday,
    );
    var bestRow = 0;
    var bestCol = 0;
    for (var row = 0; row < 7; row++) {
      for (var col = 0; col < 24; col++) {
        if (matrix[row][col] > matrix[bestRow][bestCol]) {
          bestRow = row;
          bestCol = col;
        }
      }
    }
    final bestWeekday =
        Strings.weekdayLong[(firstWeekday - DateTime.monday + bestRow) % 7];
    final summary = Strings.statsHeatmapBusiest(
      bestWeekday,
      DateFormat('ha').format(DateTime(2026, 1, 1, bestCol)),
      formatDurationMinutes(matrix[bestRow][bestCol]),
    );
    final empty = snapshot.focusInstants.isEmpty;

    final card = StatsSectionCard(
      title: Strings.statsHeatmap,
      empty: empty,
      emptyMessage: Strings.statsEmptyHeatmap,
      semanticsLabel: summary,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                height: _chartHeight,
                child: Column(
                  children: [
                    for (var row = 0; row < 7; row++) ...[
                      SizedBox(
                        height: _cellHeight,
                        child: Center(
                          child: Text(
                            Strings.weekdayShortStarting(firstWeekday)[row][0],
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ),
                      if (row < 6) const SizedBox(height: _gap),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SizedBox(
                  height: _chartHeight,
                  child: CustomPaint(
                    painter: HeatmapPainter(
                      matrix: matrix,
                      base: toneColors
                          .fillFor(Tone.focus)
                          .withValues(alpha: 0.12),
                      peak: toneColors.fillFor(Tone.focus),
                      gap: _gap,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const SizedBox(width: 26),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final tick in const ['0', '6', '12', '18', '24'])
                      Text(tick, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (empty) return card;
    return Semantics(label: summary, excludeSemantics: true, child: card);
  }
}
