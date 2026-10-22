import 'package:energy_clock/app/settings/settings_providers.dart';
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/repositories/stats_repository.dart';
import 'package:energy_clock/features/stats/model/stats_period.dart';
import 'package:energy_clock/features/stats/widgets/section_card.dart';
import 'package:energy_clock/shared/charts/donut_painter.dart';
import 'package:energy_clock/shared/charts/stacked_bars_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Completed minutes per day, tones stacked, heights relative to the fullest
/// day. Month windows show one thin bar per day without labels.
class ToneBalanceCard extends ConsumerWidget {
  const ToneBalanceCard({
    required this.snapshot,
    required this.window,
    super.key,
  });

  final StatsSnapshot snapshot;
  final StatsWindow window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstWeekday =
        ref.watch(firstDayOfWeekProvider).valueOrNull ?? DateTime.monday;
    final toneColors = context.toneColors;
    final theme = Theme.of(context);

    final stacks = <DateTime, ToneStack>{};
    for (final cell in snapshot.toneByDay) {
      (stacks[cell.date] ??= <Tone, int>{})[cell.tone] = cell.minutes;
    }
    final bars = <ToneStack>[
      for (var i = 0; i < window.dayCount; i++)
        stacks[DateTime(
              window.from.year,
              window.from.month,
              window.from.day + i,
            )] ??
            const <Tone, int>{},
    ];

    final totals = <Tone, int>{for (final tone in Tone.values) tone: 0};
    for (final cell in snapshot.toneByDay) {
      totals[cell.tone] = totals[cell.tone]! + cell.minutes;
    }
    final grandTotal = totals.values.fold(0, (sum, m) => sum + m);
    int share(Tone tone) =>
        grandTotal == 0 ? 0 : ((totals[tone]! * 100) / grandTotal).round();
    final summary = Strings.joinWords([
      for (final tone in Tone.values)
        Strings.statsToneLegend(
          tone.label,
          formatDurationMinutes(totals[tone]!),
          share(tone),
        ),
    ]);
    final empty = snapshot.completedTotal == 0;

    final card = StatsSectionCard(
      title: Strings.statsToneBalance,
      empty: empty,
      emptyMessage: Strings.statsEmptyToneBalance,
      semanticsLabel: summary,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 140,
            width: double.infinity,
            child: CustomPaint(
              painter: StackedBarsPainter(
                days: bars,
                colors: {
                  for (final tone in Tone.values)
                    tone: toneColors.fillFor(tone),
                },
                trackColor: context.appColors.outline,
              ),
            ),
          ),
          if (window.dayCount == 7) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                for (final name in Strings.weekdayShortStarting(firstWeekday))
                  Expanded(
                    child: Center(
                      child: Text(name[0], style: theme.textTheme.bodySmall),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox.square(
                dimension: 110,
                child: CustomPaint(
                  painter: DonutPainter(
                    segments: [
                      for (final tone in Tone.values)
                        (tone: tone, minutes: totals[tone]!),
                    ],
                    colors: {
                      for (final tone in Tone.values)
                        tone: toneColors.fillFor(tone),
                    },
                    trackColor: context.appColors.outline,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final tone in Tone.values)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Row(
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: toneColors.fillFor(tone),
                                shape: BoxShape.circle,
                              ),
                              child: const SizedBox.square(dimension: 10),
                            ),
                            const SizedBox(width: AppSpacing.xs + 2),
                            Expanded(
                              child: Text(
                                Strings.statsToneLegend(
                                  tone.label,
                                  formatDurationMinutes(totals[tone]!),
                                  share(tone),
                                ),
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
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
