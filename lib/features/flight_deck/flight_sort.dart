// lib/features/flight_deck/flight_sort.dart
import 'package:energy_clock/features/clock/data/event_repository.dart'
    show CalendarEvent;

/// Flights divided at [now]: a flight whose end is after [now] is upcoming.
class FlightSplit {
  const FlightSplit({
    required this.upcoming,
    required this.past,
    required this.next,
  });

  final List<CalendarEvent> upcoming;
  final List<CalendarEvent> past;
  final CalendarEvent? next;
}

DateTime flightEndOf(CalendarEvent flight) => DateTime(
  flight.date.year,
  flight.date.month,
  flight.date.day,
).add(Duration(minutes: flight.endMinute));

int _compareFlights(CalendarEvent a, CalendarEvent b) {
  final byDate = a.date.compareTo(b.date);
  if (byDate != 0) return byDate;
  final byStart = a.startMinute.compareTo(b.startMinute);
  return byStart != 0 ? byStart : a.id.compareTo(b.id);
}

FlightSplit splitFlights(List<CalendarEvent> flights, DateTime now) {
  final upcoming = <CalendarEvent>[];
  final past = <CalendarEvent>[];
  for (final flight in flights) {
    if (flightEndOf(flight).isAfter(now)) {
      upcoming.add(flight);
    } else {
      past.add(flight);
    }
  }
  upcoming.sort(_compareFlights);
  past.sort(_compareFlights);
  return FlightSplit(
    upcoming: upcoming,
    past: past,
    next: upcoming.isEmpty ? null : upcoming.first,
  );
}
