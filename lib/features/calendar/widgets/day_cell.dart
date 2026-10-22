import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/repositories/calendar_repository.dart';
import 'package:energy_clock/features/calendar/model/ring_segments.dart';
import 'package:energy_clock/features/calendar/widgets/day_ring_painter.dart';
import 'package:energy_clock/shared/widgets/press_scale.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// One day of the month grid: a ring showing the day's tone balance with the
/// day number inside (spec §7). Today is a filled ink disc, past days have a
/// muted number, and the whole cell is one button.
class DayCell extends StatelessWidget {
  const DayCell({
    required this.day,
    required this.size,
    required this.minutes,
    required this.isToday,
    required this.isPast,
    required this.onTap,
    super.key,
  });

  final DateTime day;

  /// The cell is a square of this side.
  final double size;

  /// The day's planned minutes per tone; empty for a day with no events.
  final ToneMinutes minutes;

  final bool isToday;
  final bool isPast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final toneColors = context.toneColors;
    final theme = Theme.of(context);

    final stroke = (size * 0.1).clamp(3.0, 6.0);
    final radius = (size - stroke) / 2;
    // The gap must be wider than the two rounded ends that meet in it.
    final gap = stroke / radius + 0.14;
    final inner = size - 2 * (stroke + 3);

    final ordered = [
      for (final tone in Tone.values)
        if ((minutes[tone] ?? 0) > 0) tone,
    ];
    final label = Strings.weekDaySemantics(
      DateFormat('EEEE d MMMM').format(day),
      tones: Strings.joinWords([
        for (final tone in ordered)
          '${tone.label} ${spokenDurationMinutes(minutes[tone]!)}',
      ]),
      isToday: isToday,
    );

    final numberColor = isToday
        ? colors.onInk
        : (isPast ? colors.muted : colors.ink);

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        onTap: onTap,
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(size),
                painter: DayRingPainter(
                  segments: ringSegments(minutes, gap: gap),
                  colors: {
                    for (final tone in Tone.values)
                      tone: toneColors.fillFor(tone),
                  },
                  emptyColor: colors.outline,
                  strokeWidth: stroke,
                ),
              ),
              if (isToday)
                DecoratedBox(
                  key: const ValueKey('day-cell-today-disc'),
                  decoration: BoxDecoration(
                    color: colors.ink,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(dimension: inner),
                ),
              SizedBox.square(
                dimension: inner,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${day.day}',
                      style: theme.textTheme.labelLarge!.copyWith(
                        fontSize: (size * 0.3).clamp(13.0, 20.0),
                        color: numberColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
