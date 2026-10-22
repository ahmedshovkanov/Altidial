import 'package:altidial/core/event_status.dart';
import 'package:altidial/core/time/month_time.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/repositories/calendar_repository.dart';

import 'fake_event_repository.dart';

/// In-memory [CalendarRepository] for widget tests: the planned minutes per
/// tone of each day of a month, worked out from [FakeEventRepository]'s events
/// and sent again when they change.
class FakeCalendarRepository implements CalendarRepository {
  FakeCalendarRepository(this._events);

  final FakeEventRepository _events;

  Map<DateTime, ToneMinutes> _month(DateTime month) {
    final first = startOfMonth(month);
    final end = addMonths(first, 1);
    final byDay = <DateTime, ToneMinutes>{};
    for (final event in _events.all) {
      if (event.date.isBefore(first) || !event.date.isBefore(end)) continue;
      if (event.status == EventStatus.skipped) continue;
      final minutes = byDay.putIfAbsent(event.date, () => <Tone, int>{});
      minutes[event.tone] =
          (minutes[event.tone] ?? 0) + event.range.durationMinutes;
    }
    return byDay;
  }

  @override
  Stream<Map<DateTime, ToneMinutes>> watchMonth(DateTime month) async* {
    yield _month(month);
    yield* _events.changes.map((_) => _month(month));
  }
}
