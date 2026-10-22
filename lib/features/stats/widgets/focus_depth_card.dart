import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/data/repositories/stats_repository.dart';
import 'package:altidial/features/stats/model/stats_period.dart';
import 'package:altidial/features/stats/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Four tiles: total, longest and average focus plus the abandoned count.
class FocusDepthCard extends ConsumerWidget {
  const FocusDepthCard({
    required this.snapshot,
    required this.window,
    super.key,
  });

  final StatsSnapshot snapshot;
  final StatsWindow window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = snapshot.focus;
    final rate = focus.abandonmentRate;
    final summary = Strings.statsFocusSummary(
      formatDurationMinutes(focus.minutes),
      formatDurationMinutes(focus.longestSeconds ~/ 60),
      formatDurationMinutes(focus.averageSeconds ~/ 60),
      Strings.statsAbandonedCount(focus.abandoned, focus.ended),
    );
    final empty = focus.ended == 0;

    final card = StatsSectionCard(
      title: Strings.statsFocusDepth,
      empty: empty,
      emptyMessage: Strings.statsEmptyFocus,
      semanticsLabel: summary,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _Metric(
                  value: formatDurationMinutes(focus.minutes),
                  label: Strings.statsTotalFocus,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Metric(
                  value: formatDurationMinutes(focus.longestSeconds ~/ 60),
                  label: Strings.statsLongestSession,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  value: formatDurationMinutes(focus.averageSeconds ~/ 60),
                  label: Strings.statsAverageSession,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Metric(
                  value: Strings.statsAbandonedCount(
                    focus.abandoned,
                    focus.ended,
                  ),
                  label: rate == null
                      ? Strings.statsAbandoned
                      : Strings.statsAbandonedLabel((rate * 100).round()),
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

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: theme.textTheme.titleLarge),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
