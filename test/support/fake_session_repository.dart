import 'dart:async';
import 'dart:math' as math;

import 'package:energy_clock/core/event_status.dart';
import 'package:energy_clock/core/session/session_outcome.dart';
import 'package:energy_clock/data/repositories/session_repository.dart';
import 'package:energy_clock/features/reflections/model/reflection.dart';

import 'fake_event_repository.dart';

/// In-memory [SessionRepository] for widget tests, for the same reason
/// [FakeEventRepository] exists: a real Drift database cannot deliver its
/// streams inside `testWidgets`. The behaviour against Drift is covered by
/// `test/data/session_repository_test.dart`.
///
/// It works on the events held by [events] and reads the time from [clock], so
/// a test that moves the clock moves the session with it.
class FakeSessionRepository implements SessionRepository {
  FakeSessionRepository({required this.events, required this._clock});

  final FakeEventRepository events;
  final DateTime Function() _clock;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Every repository call, by name, in order: `start`, `pause`, ...
  final List<String> calls = <String>[];

  /// The sessions that have ended, oldest first.
  final List<SessionRecord> ended = <SessionRecord>[];

  SessionRecord? _record;
  int _nextId = 1;

  void dispose() {
    unawaited(_changes.close());
  }

  /// The session that is running now, or null.
  RunningSession? get running {
    final record = _record;
    if (record == null) return null;
    final event = events.eventById(record.eventId)!;
    return RunningSession(
      session: record,
      eventTitle: event.title,
      eventTone: event.tone,
      eventDate: event.date,
      eventRange: event.range,
    );
  }

  /// Puts a session into the running state without going through [start], as
  /// if a previous launch of the app had left it there.
  void seedRunning({
    required int eventId,
    required DateTime startedAt,
    int plannedSeconds = 3600,
    int pausedSeconds = 0,
    DateTime? pauseStartedAt,
  }) {
    _record = SessionRecord(
      id: _nextId++,
      eventId: eventId,
      startedAt: startedAt,
      endedAt: null,
      plannedSeconds: plannedSeconds,
      pausedSeconds: pausedSeconds,
      pauseStartedAt: pauseStartedAt,
      activeSeconds: 0,
      overtimeSeconds: 0,
      outcome: SessionOutcome.running,
    );
    _notify();
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Stream<RunningSession?> watchRunning() async* {
    yield running;
    yield* _changes.stream.map((_) => running);
  }

  @override
  Future<RunningSession?> runningSession() async => running;

  @override
  Future<int> start({required int eventId}) async {
    calls.add('start');
    if (_record != null) throw const SessionAlreadyRunningException();
    final event = events.eventById(eventId);
    if (event == null) throw const SessionEventMissingException();
    final id = _nextId++;
    _record = SessionRecord(
      id: id,
      eventId: eventId,
      startedAt: _clock(),
      endedAt: null,
      plannedSeconds: event.range.durationMinutes * 60,
      pausedSeconds: 0,
      pauseStartedAt: null,
      activeSeconds: 0,
      overtimeSeconds: 0,
      outcome: SessionOutcome.running,
    );
    _notify();
    return id;
  }

  SessionRecord? _live(int sessionId) {
    final record = _record;
    return record != null && record.id == sessionId ? record : null;
  }

  void _replace(
    SessionRecord record, {
    int? plannedSeconds,
    int? pausedSeconds,
    DateTime? pauseStartedAt,
    bool clearPause = false,
  }) {
    _record = SessionRecord(
      id: record.id,
      eventId: record.eventId,
      startedAt: record.startedAt,
      endedAt: record.endedAt,
      plannedSeconds: plannedSeconds ?? record.plannedSeconds,
      pausedSeconds: pausedSeconds ?? record.pausedSeconds,
      pauseStartedAt: clearPause
          ? null
          : pauseStartedAt ?? record.pauseStartedAt,
      activeSeconds: record.activeSeconds,
      overtimeSeconds: record.overtimeSeconds,
      outcome: record.outcome,
    );
    _notify();
  }

  @override
  Future<void> pause(int sessionId) async {
    calls.add('pause');
    final record = _live(sessionId);
    if (record == null || record.pauseStartedAt != null) return;
    _replace(record, pauseStartedAt: _clock());
  }

  @override
  Future<void> resume(int sessionId) async {
    calls.add('resume');
    final record = _live(sessionId);
    if (record == null || record.pauseStartedAt == null) return;
    _replace(
      record,
      pausedSeconds: record.timing.pausedSecondsTotalAt(_clock()),
      clearPause: true,
    );
  }

  @override
  Future<void> extend(int sessionId, {required int seconds}) async {
    calls.add('extend $seconds');
    final record = _live(sessionId);
    if (record == null) return;
    _replace(record, plannedSeconds: record.plannedSeconds + seconds);
  }

  @override
  Future<SessionRecord?> finish(int sessionId) {
    calls.add('finish');
    return _end(sessionId, abandoned: false, capAtPlanned: false);
  }

  @override
  Future<SessionRecord?> abandon(int sessionId) {
    calls.add('abandon');
    return _end(sessionId, abandoned: true, capAtPlanned: false);
  }

  @override
  Future<SessionRecord?> closeOut(int sessionId) {
    calls.add('closeOut');
    return _end(sessionId, abandoned: false, capAtPlanned: true);
  }

  @override
  Future<void> saveReflection({
    required int sessionId,
    int? energyRating,
    int? focusRating,
    List<String> tags = const [],
    String? note,
  }) async {
    calls.add('saveReflection');
    if (energyRating != null && (energyRating < 1 || energyRating > 5)) {
      throw ArgumentError.value(
        energyRating,
        'energyRating',
        'Must be 1–5 or null',
      );
    }
    if (focusRating != null && (focusRating < 1 || focusRating > 5)) {
      throw ArgumentError.value(
        focusRating,
        'focusRating',
        'Must be 1–5 or null',
      );
    }
    final trimmed = note?.trim();
    if (trimmed != null &&
        trimmed.isNotEmpty &&
        trimmed.length > ReflectionTags.maxNoteLength) {
      throw ArgumentError.value(note, 'note', 'Must be 0–140 characters');
    }
    final cleanTags = ReflectionTags.sanitizeTags(tags);
    final finalNote = trimmed == null || trimmed.isEmpty ? null : trimmed;
    SessionRecord withReflection(SessionRecord s) => SessionRecord(
      id: s.id,
      eventId: s.eventId,
      startedAt: s.startedAt,
      endedAt: s.endedAt,
      plannedSeconds: s.plannedSeconds,
      pausedSeconds: s.pausedSeconds,
      pauseStartedAt: s.pauseStartedAt,
      activeSeconds: s.activeSeconds,
      overtimeSeconds: s.overtimeSeconds,
      outcome: s.outcome,
      energyRating: energyRating,
      focusRating: focusRating,
      tags: cleanTags,
      note: finalNote,
    );
    final index = ended.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      ended[index] = withReflection(ended[index]);
      _notify();
      return;
    }
    final live = _live(sessionId);
    if (live != null) {
      _record = withReflection(live);
      _notify();
    }
  }

  Future<SessionRecord?> _end(
    int sessionId, {
    required bool abandoned,
    required bool capAtPlanned,
  }) async {
    final record = _live(sessionId);
    if (record == null) return null;
    final now = _clock();
    final timing = record.timing;
    var active = timing.elapsedSecondsAt(now);
    if (capAtPlanned) active = math.min(active, record.plannedSeconds);
    final outcome = abandoned
        ? SessionOutcome.abandoned
        : active >= record.plannedSeconds
        ? SessionOutcome.completed
        : SessionOutcome.finishedEarly;
    final done = SessionRecord(
      id: record.id,
      eventId: record.eventId,
      startedAt: record.startedAt,
      endedAt: now,
      plannedSeconds: record.plannedSeconds,
      pausedSeconds: timing.pausedSecondsTotalAt(now),
      pauseStartedAt: null,
      activeSeconds: active,
      overtimeSeconds: math.max(0, active - record.plannedSeconds),
      outcome: outcome,
    );
    ended.add(done);
    _record = null;
    if (outcome.countsAsDone) {
      events.setStatus(record.eventId, EventStatus.completed);
    }
    _notify();
    return done;
  }
}
