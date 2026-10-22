// lib/features/flight_deck/widgets/flights_list.dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart'
    show CalendarEvent;
import 'package:energy_clock/features/flight_deck/flight_sort.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

String _dayLabel(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Upcoming + past flight rows. Read-only: tapping a row opens its day via
/// the existing Clock sheet, so there is no edit form here.
class FlightsList extends StatelessWidget {
  const FlightsList({
    required this.split,
    required this.onOpenDay,
    super.key,
  });

  final FlightSplit split;
  final ValueChanged<DateTime> onOpenDay;

  Widget _row(BuildContext context, CalendarEvent flight) {
    final route = Strings.flightRoute(
      flight.fromCode ?? '?',
      flight.toCode ?? '?',
    );
    return ListTile(
      leading: Icon(
        CupertinoIcons.airplane,
        color: context.appColors.muted,
      ),
      title: Text(flight.flightNumber ?? flight.title),
      subtitle: Text('$route · ${_dayLabel(flight.date)}'),
      onTap: () => onOpenDay(flight.date),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (split.upcoming.isEmpty && split.past.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(Strings.deckEmptyTitle,
              style: Theme.of(context).textTheme.titleSmall),
          Text(Strings.deckEmptyHint,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: context.appColors.muted,
              )),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (split.upcoming.isNotEmpty) ...[
          Text(Strings.deckUpcoming,
              style: Theme.of(context).textTheme.titleSmall),
          for (final flight in split.upcoming) _row(context, flight),
        ],
        if (split.past.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(Strings.deckPast,
              style: Theme.of(context).textTheme.titleSmall),
          for (final flight in split.past) _row(context, flight),
        ],
      ],
    );
  }
}
