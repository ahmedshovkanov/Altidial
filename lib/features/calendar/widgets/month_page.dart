import 'package:altidial/app/settings/settings_providers.dart';
import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/app/theme/tone_colors.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/core/time/month_time.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/repositories/calendar_repository.dart';
import 'package:altidial/features/calendar/calendar_layout.dart';
import 'package:altidial/features/calendar/providers.dart';
import 'package:altidial/features/calendar/widgets/day_cell.dart';
import 'package:altidial/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One month: the weekday labels and the weeks of day cells in a card, the
/// legend, and, for a month with nothing planned, a short invitation.
///
/// Weeks start on the first day of the week (Monday by default); days outside
/// the month are blank. The page scrolls
/// if a very short window or a huge text size cannot fit it.
class MonthPage extends ConsumerWidget {
  const MonthPage({
    required this.month,
    required this.today,
    required this.onOpenDay,
    super.key,
  });

  /// The first of the month shown.
  final DateTime month;

  /// Today, at local midnight.
  final DateTime today;

  final ValueChanged<DateTime> onOpenDay;

  static String _keyFor(DateTime day) =>
      'day-${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final load = ref.watch(monthLoadProvider(startOfMonth(month)));
    final planned = load.valueOrNull ?? const <DateTime, ToneMinutes>{};
    final firstWeekday =
        ref.watch(firstDayOfWeekProvider).valueOrNull ?? DateTime.monday;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final theme = Theme.of(context);
    final toneColors = context.toneColors;
    final ink = context.appColors.ink;

    // How much of each tone the month holds.
    final totals = <Tone, int>{};
    for (final day in planned.values) {
      day.forEach((tone, minutes) {
        totals[tone] = (totals[tone] ?? 0) + minutes;
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = CalendarLayout.forArea(
          Size(constraints.maxWidth, constraints.maxHeight),
          textScale: textScale,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            CalendarLayout.pageMargin,
            AppSpacing.sm,
            CalendarLayout.pageMargin,
            AppSpacing.lg,
          ),
          child: Center(
            child: SizedBox(
              width: layout.cardWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppCard(
                    padding: EdgeInsets.all(layout.cardPadding),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MediaQuery.withClampedTextScaling(
                          maxScaleFactor: 1.3,
                          child: SizedBox(
                            height: CalendarLayout.weekdayRowHeight * 1.3,
                            child: Row(
                              children: [
                                for (final name in Strings.weekdayShortStarting(
                                  firstWeekday,
                                ))
                                  SizedBox(
                                    width: layout.cellSize,
                                    child: Center(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          name,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        for (final week in monthWeeks(
                          month,
                          firstWeekday: firstWeekday,
                        )) ...[
                          const SizedBox(height: CalendarLayout.rowGap),
                          Row(
                            children: [
                              for (final day in week)
                                SizedBox.square(
                                  dimension: layout.cellSize,
                                  child: day == null
                                      ? null
                                      : DayCell(
                                          key: ValueKey(_keyFor(day)),
                                          day: day,
                                          size: layout.cellSize,
                                          minutes:
                                              planned[day] ??
                                              const <Tone, int>{},
                                          isToday: day == today,
                                          isPast: day.isBefore(today),
                                          onTap: () => onOpenDay(day),
                                        ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final tone in Tone.values)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: toneColors.fillFor(tone),
                                shape: BoxShape.circle,
                              ),
                              child: const SizedBox.square(dimension: 10),
                            ),
                            const SizedBox(width: AppSpacing.xs + 2),
                            Text(tone.label, style: theme.textTheme.bodySmall),
                            if ((totals[tone] ?? 0) > 0) ...[
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                formatDurationMinutes(totals[tone]!),
                                style: theme.textTheme.bodySmall!.copyWith(
                                  color: ink,
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                  if (load.hasValue && planned.isEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      Strings.calendarEmptyMonth,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
