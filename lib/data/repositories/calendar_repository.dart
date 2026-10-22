import 'package:energy_clock/core/time/month_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/daos/event_dao.dart';
import 'package:energy_clock/data/repositories/series_materialiser.dart';

/// Planned minutes per tone for one day. A tone with no events is absent.
typedef ToneMinutes = Map<Tone, int>;

/// What the Calendar tab reads: how each day of a month is planned.
abstract interface class CalendarRepository {
  /// The planned minutes per tone for every day of [month]'s month that has
  /// events (days with none are absent), keyed by local midnight. Recurring
  /// series are expanded into the month first, so a repeating event shows on
  /// every day it covers. Emits again whenever an event changes.
  Stream<Map<DateTime, ToneMinutes>> watchMonth(DateTime month);
}

class DriftCalendarRepository implements CalendarRepository {
  DriftCalendarRepository(this._dao, {this._materialiser});

  final EventDao _dao;
  final SeriesMaterialiser? _materialiser;

  @override
  Stream<Map<DateTime, ToneMinutes>> watchMonth(DateTime month) async* {
    final first = startOfMonth(month);
    final end = addMonths(first, 1);

    final materialiser = _materialiser;
    if (materialiser != null) {
      try {
        await materialiser.materialise(first, end);
      } on Object {
        // Show the month as stored: a failed expansion must not blank the
        // Calendar.
      }
    }

    yield* _dao.watchToneMinutes(first, end).map((rows) {
      final byDay = <DateTime, ToneMinutes>{};
      for (final row in rows) {
        final minutes = byDay.putIfAbsent(row.date, () => <Tone, int>{});
        minutes[Tone.fromDbIndex(row.toneIndex)] = row.minutes;
      }
      return byDay;
    });
  }
}
