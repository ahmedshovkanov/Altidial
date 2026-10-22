// lib/features/flight_deck/widgets/next_flight_hero.dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart'
    show CalendarEvent;
import 'package:energy_clock/features/flight_deck/flight_sort.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

String deckCountdownLabel(DateTime now, CalendarEvent flight) {
  final end = flightEndOf(flight);
  final days = end.difference(now).inDays;
  final today = DateTime(now.year, now.month, now.day);
  final flightDay = DateTime(
    flight.date.year, flight.date.month, flight.date.day);
  final time = formatMinuteOfDay(flight.startMinute);
  if (flightDay == today) return Strings.deckCountdownToday(time);
  if (flightDay == today.add(const Duration(days: 1))) {
    return Strings.deckCountdownTomorrow(time);
  }
  return Strings.deckCountdownDays(days);
}

/// The nearest upcoming flight with its countdown. Tapping opens the day.
class NextFlightHero extends StatelessWidget {
  const NextFlightHero({
    required this.flight,
    required this.now,
    required this.onOpen,
    super.key,
  });

  final CalendarEvent flight;
  final DateTime now;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final route = Strings.flightRoute(
      flight.fromCode ?? '?',
      flight.toCode ?? '?',
    );
    return Card(
      color: colors.surface,
      child: InkWell(
        key: const ValueKey('deck-hero-open'),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(CupertinoIcons.airplane, size: 32, color: colors.ink),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Strings.deckNextFlight,
                        style: Theme.of(context).textTheme.labelMedium!
                            .copyWith(color: colors.muted)),
                    Text(
                      '${flight.flightNumber ?? flight.title} · $route',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(deckCountdownLabel(now, flight),
                        style: Theme.of(context).textTheme.bodyMedium!
                            .copyWith(color: colors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
