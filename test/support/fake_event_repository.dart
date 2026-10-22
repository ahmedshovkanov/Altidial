import 'dart:async';

import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/geometry/ring_layout.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/features/clock/data/event_repository.dart';

/// In-memory [EventRepository] for widget tests.
///
/// `testWidgets` runs inside a fake-async zone. A real Drift database completes
/// its I/O on real timers the fake clock never advances, so its stream never
/// delivers and the test isolate is torn down mid-stream. Repository behaviour
/// against Drift is covered by the plain `test()` suites; widget tests only
/// need something that satisfies the interface.
class FakeEventRepository implements EventRepository {
  final List<CalendarEvent> _events = <CalendarEvent>[];
  final StreamController<void> _changes = StreamController<void>.broadcast();
  int _nextId = 1;

  void dispose() {
    unawaited(_changes.close());
  }

  List<CalendarEvent> _forDay(DateTime day) {
    final normalised = startOfDay(day);
    final result = _events.where((event) => event.date == normalised).toList();
    result.sort((a, b) {
      final byStart = a.startMinute.compareTo(b.startMinute);
      return byStart != 0 ? byStart : a.id.compareTo(b.id);
    });
    return result;
  }

  void _guard(DateTime day, MinuteRange range, int? excludingId) {
    final existing = [
      for (final event in _forDay(day))
        if (event.id != excludingId) event.range,
    ];
    if (wouldOverflowRings(existing: existing, candidate: range)) {
      throw const RingOverflowException();
    }
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Stream<List<CalendarEvent>> watchDay(DateTime day) async* {
    yield _forDay(day);
    yield* _changes.stream.map((_) => _forDay(day));
  }

  @override
  Future<List<CalendarEvent>> eventsForDay(DateTime day) async => _forDay(day);

  Map<DateTime, Set<Tone>> _tonesBetween(DateTime from, DateTime toExclusive) {
    final start = startOfDay(from);
    final end = startOfDay(toExclusive);
    final byDay = <DateTime, Set<Tone>>{};
    for (final event in _events) {
      if (event.date.isBefore(start) || !event.date.isBefore(end)) continue;
      byDay.putIfAbsent(event.date, () => <Tone>{}).add(event.tone);
    }
    return byDay;
  }

  @override
  Stream<Map<DateTime, Set<Tone>>> watchTonesByDay(
    DateTime from,
    DateTime toExclusive,
  ) async* {
    yield _tonesBetween(from, toExclusive);
    yield* _changes.stream.map((_) => _tonesBetween(from, toExclusive));
  }

  List<CalendarEvent> _flightsBetween(DateTime from, DateTime toExclusive) {
    final start = startOfDay(from);
    final end = startOfDay(toExclusive);
    final result = _events
        .where(
          (event) =>
              event.isFlight &&
              !event.date.isBefore(start) &&
              event.date.isBefore(end),
        )
        .toList();
    result.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0
          ? byDate
          : (a.startMinute != b.startMinute
                ? a.startMinute.compareTo(b.startMinute)
                : a.id.compareTo(b.id));
    });
    return result;
  }

  @override
  Stream<List<CalendarEvent>> watchFlights(
    DateTime from,
    DateTime toExclusive,
  ) async* {
    yield _flightsBetween(from, toExclusive);
    yield* _changes.stream.map((_) => _flightsBetween(from, toExclusive));
  }

  @override
  Future<int> createEvent({
    required DateTime day,
    required String title,
    required Tone tone,
    required MinuteRange range,
    bool isFlight = false,
    String? flightNumber,
    String? fromCode,
    String? toCode,
    int? projectId,
  }) async {
    final normalised = startOfDay(day);
    _guard(normalised, range, null);
    final id = _nextId++;
    _events.add(
      CalendarEvent(
        id: id,
        seriesId: null,
        date: normalised,
        title: title,
        tone: isFlight ? Tone.inbox : tone,
        range: range,
        status: EventStatus.planned,
        isFlight: isFlight,
        flightNumber: isFlight ? flightNumber : null,
        fromCode: isFlight ? fromCode : null,
        toCode: isFlight ? toCode : null,
        projectId: projectId,
      ),
    );
    _notify();
    return id;
  }

  @override
  Future<void> updateFlight({
    required int id,
    required bool isFlight,
    required String? flightNumber,
    required String? fromCode,
    required String? toCode,
  }) async {
    final index = _events.indexWhere((event) => event.id == id);
    if (index == -1) return;
    final existing = _events[index];
    _events[index] = CalendarEvent(
      id: existing.id,
      seriesId: existing.seriesId,
      date: existing.date,
      title: existing.title,
      tone: existing.tone,
      range: existing.range,
      status: existing.status,
      isFlight: isFlight,
      flightNumber: isFlight ? flightNumber : null,
      fromCode: isFlight ? fromCode : null,
      toCode: isFlight ? toCode : null,
      projectId: existing.projectId,
    );
    _notify();
  }

  @override
  Future<void> moveEvent({
    required int id,
    required DateTime day,
    required MinuteRange range,
  }) async {
    final normalised = startOfDay(day);
    _guard(normalised, range, id);
    final index = _events.indexWhere((event) => event.id == id);
    if (index == -1) return;
    final existing = _events[index];
    _events[index] = CalendarEvent(
      id: existing.id,
      seriesId: existing.seriesId,
      date: existing.date,
      title: existing.title,
      tone: existing.tone,
      range: range,
      status: existing.status,
      isFlight: existing.isFlight,
      flightNumber: existing.flightNumber,
      fromCode: existing.fromCode,
      toCode: existing.toCode,
      projectId: existing.projectId,
    );
    _notify();
  }

  @override
  Future<void> updateDetails({
    required int id,
    required String title,
    required Tone tone,
  }) async {
    final index = _events.indexWhere((event) => event.id == id);
    if (index == -1) return;
    final existing = _events[index];
    _events[index] = CalendarEvent(
      id: existing.id,
      seriesId: existing.seriesId,
      date: existing.date,
      title: title,
      tone: tone,
      range: existing.range,
      status: existing.status,
      isFlight: existing.isFlight,
      flightNumber: existing.flightNumber,
      fromCode: existing.fromCode,
      toCode: existing.toCode,
      projectId: existing.projectId,
    );
    _notify();
  }

  @override
  Future<void> updateProject({required int id, required int? projectId}) async {
    updateProjectCalls.add((id: id, projectId: projectId));
    final index = _events.indexWhere((event) => event.id == id);
    if (index == -1) return;
    final existing = _events[index];
    _events[index] = CalendarEvent(
      id: existing.id,
      seriesId: existing.seriesId,
      date: existing.date,
      title: existing.title,
      tone: existing.tone,
      range: existing.range,
      status: existing.status,
      isFlight: existing.isFlight,
      flightNumber: existing.flightNumber,
      fromCode: existing.fromCode,
      toCode: existing.toCode,
      projectId: projectId,
    );
    _notify();
  }

  /// Test-only call log for the edit-scope tests: every single-row link.
  final List<({int id, int? projectId})> updateProjectCalls = [];

  /// Test-only call log for the edit-all-future path.
  final List<({int seriesId, DateTime fromDate, int? projectId})>
  updateProjectForSeriesCalls = [];

  @override
  Future<void> updateProjectForSeries({
    required int seriesId,
    required DateTime fromDate,
    required int? projectId,
  }) async {
    final start = startOfDay(fromDate);
    updateProjectForSeriesCalls.add((
      seriesId: seriesId,
      fromDate: start,
      projectId: projectId,
    ));
    for (var i = 0; i < _events.length; i++) {
      final existing = _events[i];
      if (existing.seriesId != seriesId || existing.date.isBefore(start)) {
        continue;
      }
      _events[i] = CalendarEvent(
        id: existing.id,
        seriesId: existing.seriesId,
        date: existing.date,
        title: existing.title,
        tone: existing.tone,
        range: existing.range,
        status: existing.status,
        isFlight: existing.isFlight,
        flightNumber: existing.flightNumber,
        fromCode: existing.fromCode,
        toCode: existing.toCode,
        projectId: projectId,
      );
    }
    _notify();
  }

  @override
  Future<void> deleteEvent(int id) async {
    _events.removeWhere((event) => event.id == id);
    _notify();
  }

  /// Every event, in creation order. For fakes that look across days.
  List<CalendarEvent> get all => List.unmodifiable(_events);

  /// Emits whenever an event is added, changed or removed.
  Stream<void> get changes => _changes.stream;

  /// Adds an event that belongs to a series, as the real materialiser would.
  /// Does not check rings.
  int addOccurrence({
    required int seriesId,
    required DateTime day,
    String title = 'Standup',
    Tone tone = Tone.inbox,
    MinuteRange range = const MinuteRange(540, 570),
    EventStatus status = EventStatus.planned,
  }) {
    final id = _nextId++;
    _events.add(
      CalendarEvent(
        id: id,
        seriesId: seriesId,
        date: startOfDay(day),
        title: title,
        tone: tone,
        range: range,
        status: status,
      ),
    );
    _notify();
    return id;
  }

  /// Puts an event in a series, or (null) makes it a one-off.
  void setSeriesId(int id, int? seriesId) {
    final index = _events.indexWhere((event) => event.id == id);
    if (index == -1) return;
    final existing = _events[index];
    _events[index] = CalendarEvent(
      id: existing.id,
      seriesId: seriesId,
      date: existing.date,
      title: existing.title,
      tone: existing.tone,
      range: existing.range,
      status: existing.status,
      isFlight: existing.isFlight,
      flightNumber: existing.flightNumber,
      fromCode: existing.fromCode,
      toCode: existing.toCode,
      projectId: existing.projectId,
    );
    _notify();
  }

  /// Removes every event of the series dated [from] or later.
  void removeSeriesFrom(int seriesId, DateTime from) {
    final start = startOfDay(from);
    _events.removeWhere(
      (event) => event.seriesId == seriesId && !event.date.isBefore(start),
    );
    _notify();
  }

  /// The event with [id], or null.
  CalendarEvent? eventById(int id) {
    for (final event in _events) {
      if (event.id == id) return event;
    }
    return null;
  }

  /// Changes an event's status, as finishing a session does.
  void setStatus(int id, EventStatus status) {
    final index = _events.indexWhere((event) => event.id == id);
    if (index == -1) return;
    final existing = _events[index];
    _events[index] = CalendarEvent(
      id: existing.id,
      seriesId: existing.seriesId,
      date: existing.date,
      title: existing.title,
      tone: existing.tone,
      range: existing.range,
      status: status,
      isFlight: existing.isFlight,
      flightNumber: existing.flightNumber,
      fromCode: existing.fromCode,
      toCode: existing.toCode,
      projectId: existing.projectId,
    );
    _notify();
  }
}
