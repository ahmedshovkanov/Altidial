import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/app/theme/tone_colors.dart';
import 'package:altidial/core/flight/flight_details.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/features/clock/model/active_event.dart';
import 'package:altidial/features/clock/model/calendar_event.dart';
import 'package:altidial/features/clock/providers.dart';
import 'package:altidial/shared/widgets/app_card.dart';
import 'package:altidial/shared/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The selected day's events as a list, in start order. Shown in the right pane
/// of a wide window, where there is room for it. The running event's row is
/// tinted; tapping a row opens that event. Draws nothing on an empty day.
///
/// It scrolls inside its own pane, so it never competes with the dial's drag
/// gestures. It must sit where it gets a bounded height.
class TodaysPlanList extends ConsumerWidget {
  const TodaysPlanList({required this.onOpenEvent, super.key});

  final void Function(CalendarEvent event) onOpenEvent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDateProvider);
    final now = ref.watch(clockProvider);
    final events =
        ref.watch(dayEventsProvider).valueOrNull ?? const <CalendarEvent>[];
    if (events.isEmpty) return const SizedBox.shrink();

    final isToday = selected == startOfDay(now);
    final runningId = isToday
        ? activeEventsAt(events, minuteOfDay(now)).firstOrNull?.id
        : null;
    final title = isToday
        ? Strings.planTitleToday
        : Strings.planTitleFor(DateFormat('EEEE').format(selected));
    final toneColors = context.toneColors;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            itemCount: events.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final event = events[index];
              final palette = toneColors.paletteFor(event.tone);
              return Semantics(
                button: true,
                label: Strings.eventSemantics(
                  event.title,
                  event.tone.label,
                  formatMinuteOfDay(event.startMinute),
                  formatMinuteOfDay(event.endMinute),
                  spokenDurationMinutes(event.range.durationMinutes),
                ),
                excludeSemantics: true,
                onTap: () => onOpenEvent(event),
                child: AppCard(
                  key: ValueKey('plan-${event.id}'),
                  color: event.id == runningId ? palette.soft : null,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  onTap: () => onOpenEvent(event),
                  child: Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: palette.solid,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: const SizedBox(width: 6, height: 40),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              event.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                            if (event.isFlight)
                              Text(
                                flightSubtitle(
                                  flightNumber: event.flightNumber,
                                  fromCode: event.fromCode,
                                  toCode: event.toCode,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            Text(
                              '${formatMinuteRange(event.startMinute, event.endMinute)}'
                              ' · ${formatDurationMinutes(event.range.durationMinutes)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
