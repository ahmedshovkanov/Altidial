import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:energy_clock/features/clock/model/day_load.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One rounded bar split into tone segments in proportion to the day's planned
/// minutes, with a legend and the total. Overlapping events count twice,
/// because overlap is extra load. Draws nothing when the day has no events.
class DayLoadBar extends ConsumerWidget {
  const DayLoadBar({super.key});

  /// Height at normal text size.
  static const double height = 68;

  static const double _gap = 2;
  static const double _barHeight = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events =
        ref.watch(dayEventsProvider).valueOrNull ?? const <CalendarEvent>[];
    final load = computeDayLoad(events);
    if (load.isEmpty) return const SizedBox.shrink();

    final toneColors = context.toneColors;
    final theme = Theme.of(context);
    final tones = load.tones;

    final spoken = [
      for (final tone in tones)
        '${tone.label} ${spokenDurationMinutes(load.minutesFor(tone))}',
    ];

    return Semantics(
      label: Strings.dayLoadSemantics(spoken.join(', ')),
      excludeSemantics: true,
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final widths = segmentWidths([
                  for (final tone in Tone.values) load.minutesFor(tone),
                ], constraints.maxWidth - _gap * (tones.length - 1));
                final children = <Widget>[];
                for (final tone in Tone.values) {
                  final width = widths[tone.index];
                  if (width <= 0) continue;
                  if (children.isNotEmpty) {
                    children.add(const SizedBox(width: _gap));
                  }
                  children.add(
                    SizedBox(
                      key: ValueKey('load-${tone.name}'),
                      width: width,
                      height: _barHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: toneColors.fillFor(tone),
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                      ),
                    ),
                  );
                }
                return Row(children: children);
              },
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: AppSpacing.md,
                    children: [
                      for (final tone in tones)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: toneColors.fillFor(tone),
                                shape: BoxShape.circle,
                              ),
                              child: const SizedBox.square(dimension: 8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${tone.label} '
                              '${formatDurationMinutes(load.minutesFor(tone))}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Text(
                  Strings.plannedDuration(
                    formatDurationMinutes(load.totalMinutes),
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
