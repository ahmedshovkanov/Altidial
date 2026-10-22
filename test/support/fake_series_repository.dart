import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/repositories/series_repository.dart';

import 'fake_event_repository.dart';

/// In-memory [SeriesRepository] for widget tests. It records every call and
/// applies the same effects as the real one to [FakeEventRepository]'s events:
/// a new repeating event, an edit that splits the series, a delete from here.
/// It does not create the later days of a series; tests that need them add
/// occurrences with [FakeEventRepository.addOccurrence].
class FakeSeriesRepository implements SeriesRepository {
  FakeSeriesRepository(this._events);

  final FakeEventRepository _events;

  /// The rule of each series by id. Tests may seed it with [addSeries].
  final Map<int, RecurrenceRule> rules = {};

  /// Every `createRecurring` call.
  final List<
    ({
      DateTime day,
      String title,
      Tone tone,
      MinuteRange range,
      RecurrenceRule rule,
    })
  >
  created = [];

  /// Every `updateFromHere` call.
  final List<
    ({
      int eventId,
      String title,
      Tone tone,
      MinuteRange range,
      RecurrenceRule rule,
    })
  >
  updated = [];

  /// The event id of every `deleteFromHere` call.
  final List<int> deletedFrom = [];

  int _nextSeriesId = 100;

  /// Starts a series with [rule] and returns its id.
  int addSeries(RecurrenceRule rule) {
    final id = _nextSeriesId++;
    rules[id] = rule;
    return id;
  }

  @override
  Future<RecurrenceRule?> ruleFor(int seriesId) async => rules[seriesId];

  @override
  Future<int> createRecurring({
    required DateTime day,
    required String title,
    required Tone tone,
    required MinuteRange range,
    required RecurrenceRule rule,
  }) async {
    final id = await _events.createEvent(
      day: day,
      title: title,
      tone: tone,
      range: range,
    );
    _events.setSeriesId(id, addSeries(rule));
    created.add((
      day: startOfDay(day),
      title: title,
      tone: tone,
      range: range,
      rule: rule,
    ));
    return id;
  }

  @override
  Future<void> updateFromHere({
    required int eventId,
    required String title,
    required Tone tone,
    required MinuteRange range,
    required RecurrenceRule rule,
  }) async {
    final event = _events.eventById(eventId);
    if (event == null) return;
    await _events.moveEvent(id: eventId, day: event.date, range: range);
    await _events.updateDetails(id: eventId, title: title, tone: tone);

    final oldSeries = event.seriesId;
    if (oldSeries != null) {
      _events.removeSeriesFrom(oldSeries, nextDay(event.date));
    }
    _events.setSeriesId(eventId, rule.repeats ? addSeries(rule) : null);
    updated.add((
      eventId: eventId,
      title: title,
      tone: tone,
      range: range,
      rule: rule,
    ));
  }

  @override
  Future<void> deleteFromHere(int eventId) async {
    final event = _events.eventById(eventId);
    if (event == null) return;
    deletedFrom.add(eventId);

    final seriesId = event.seriesId;
    if (seriesId == null) {
      await _events.deleteEvent(eventId);
    } else {
      _events.removeSeriesFrom(seriesId, event.date);
    }
  }
}
