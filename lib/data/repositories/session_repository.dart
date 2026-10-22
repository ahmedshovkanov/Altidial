import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:energy_clock/core/event_status.dart';
import 'package:energy_clock/core/session/session_outcome.dart';
import 'package:energy_clock/data/daos/session_dao.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/models/session.dart';
import 'package:energy_clock/features/reflections/model/reflection.dart';

export 'package:energy_clock/data/models/session.dart';

/// Thrown by [SessionRepository.start] while another session is running. Only
/// one session runs at a time.
class SessionAlreadyRunningException implements Exception {
  const SessionAlreadyRunningException();
}

/// Thrown by [SessionRepository.start] when the event no longer exists.
class SessionEventMissingException implements Exception {
  const SessionEventMissingException();
}

/// Starts, steers and ends timed sessions (spec §6). Every method that changes
/// a session ignores a session that has already ended, so a double tap or a
/// late callback can never write twice.
abstract interface class SessionRepository {
  /// The running session, or null; emits again on every change.
  Stream<RunningSession?> watchRunning();

  Future<RunningSession?> runningSession();

  /// Starts a session on the event, planned for the event's length. Throws
  /// [SessionAlreadyRunningException] or [SessionEventMissingException].
  Future<int> start({required int eventId});

  Future<void> pause(int sessionId);

  Future<void> resume(int sessionId);

  /// Adds [seconds] to the planned length.
  Future<void> extend(int sessionId, {required int seconds});

  /// Ends the session now. Completed if it reached its planned end, finished
  /// early if not; either way the event becomes completed. Returns the
  /// finished session, or null if it was not running.
  Future<SessionRecord?> finish(int sessionId);

  /// Ends the session now as abandoned. The event stays planned. Returns the
  /// ended session, or null if it was not running.
  Future<SessionRecord?> abandon(int sessionId);

  /// Ends a session found after the app was killed. Like [finish], except that
  /// the recorded time is capped at the planned length: nobody can say how long
  /// the person really worked while the app was closed, and overtime nobody
  /// watched would spoil planned-versus-actual statistics.
  Future<SessionRecord?> closeOut(int sessionId);

  /// Saves the post-session debrief. Throws [ArgumentError] on out-of-range
  /// ratings (must be null or 1–5), more than 4 known tags after sanitizing
  /// is trimmed (never throws), or notes over 140 chars.
  Future<void> saveReflection({
    required int sessionId,
    int? energyRating,
    int? focusRating,
    List<String> tags = const [],
    String? note,
  });
}

class DriftSessionRepository implements SessionRepository {
  DriftSessionRepository(this._dao, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SessionDao _dao;
  final DateTime Function() _clock;

  static final int _running = SessionOutcome.running.dbIndex;

  @override
  Stream<RunningSession?> watchRunning() => _dao.watchRunning().map(
    (row) => row == null ? null : RunningSession.fromRow(row),
  );

  @override
  Future<RunningSession?> runningSession() async {
    final row = await _dao.running();
    return row == null ? null : RunningSession.fromRow(row);
  }

  @override
  Future<int> start({required int eventId}) {
    return _dao.inTransaction(() async {
      if (await _dao.running() != null) {
        throw const SessionAlreadyRunningException();
      }
      final event = await _dao.eventById(eventId);
      if (event == null) throw const SessionEventMissingException();
      return _dao.insertSession(
        SessionsCompanion.insert(
          eventId: eventId,
          startedAt: _clock(),
          plannedSeconds: (event.endMinute - event.startMinute) * 60,
        ),
      );
    });
  }

  @override
  Future<void> pause(int sessionId) {
    return _dao.inTransaction(() async {
      final row = await _dao.sessionById(sessionId);
      if (row == null || row.outcome != _running) return;
      if (row.pauseStartedAt != null) return;
      await _dao.updateSession(
        sessionId,
        SessionsCompanion(pauseStartedAt: Value(_clock())),
      );
    });
  }

  @override
  Future<void> resume(int sessionId) {
    return _dao.inTransaction(() async {
      final row = await _dao.sessionById(sessionId);
      if (row == null || row.outcome != _running) return;
      if (row.pauseStartedAt == null) return;
      final timing = SessionRecord.fromRow(row).timing;
      await _dao.updateSession(
        sessionId,
        SessionsCompanion(
          pausedSeconds: Value(timing.pausedSecondsTotalAt(_clock())),
          pauseStartedAt: const Value(null),
        ),
      );
    });
  }

  @override
  Future<void> extend(int sessionId, {required int seconds}) {
    assert(seconds > 0, 'An extension must add time');
    return _dao.inTransaction(() async {
      final row = await _dao.sessionById(sessionId);
      if (row == null || row.outcome != _running) return;
      await _dao.updateSession(
        sessionId,
        SessionsCompanion(plannedSeconds: Value(row.plannedSeconds + seconds)),
      );
    });
  }

  @override
  Future<SessionRecord?> finish(int sessionId) =>
      _end(sessionId, abandoned: false, capAtPlanned: false);

  @override
  Future<SessionRecord?> abandon(int sessionId) =>
      _end(sessionId, abandoned: true, capAtPlanned: false);

  @override
  Future<SessionRecord?> closeOut(int sessionId) =>
      _end(sessionId, abandoned: false, capAtPlanned: true);

  @override
  Future<void> saveReflection({
    required int sessionId,
    int? energyRating,
    int? focusRating,
    List<String> tags = const [],
    String? note,
  }) {
    if (energyRating != null && (energyRating < 1 || energyRating > 5)) {
      throw ArgumentError.value(energyRating, 'energyRating', 'Must be 1–5 or null');
    }
    if (focusRating != null && (focusRating < 1 || focusRating > 5)) {
      throw ArgumentError.value(focusRating, 'focusRating', 'Must be 1–5 or null');
    }
    final trimmed = note?.trim();
    if (trimmed != null && trimmed.isNotEmpty && trimmed.length > ReflectionTags.maxNoteLength) {
      throw ArgumentError.value(note, 'note', 'Must be 0–140 characters');
    }
    final csv = ReflectionTags.encodeTags(tags);
    final finalNote = trimmed == null || trimmed.isEmpty ? null : trimmed;
    return _dao.updateReflection(
      sessionId: sessionId,
      energyRating: energyRating,
      focusRating: focusRating,
      tagsCsv: csv.isEmpty ? null : csv,
      note: finalNote,
    );
  }

  Future<SessionRecord?> _end(
    int sessionId, {
    required bool abandoned,
    required bool capAtPlanned,
  }) {
    return _dao.inTransaction(() async {
      final row = await _dao.sessionById(sessionId);
      if (row == null || row.outcome != _running) return null;

      final now = _clock();
      final timing = SessionRecord.fromRow(row).timing;
      var active = timing.elapsedSecondsAt(now);
      if (capAtPlanned) active = math.min(active, row.plannedSeconds);
      final overtime = math.max(0, active - row.plannedSeconds);
      final outcome = abandoned
          ? SessionOutcome.abandoned
          : active >= row.plannedSeconds
          ? SessionOutcome.completed
          : SessionOutcome.finishedEarly;

      await _dao.updateSession(
        sessionId,
        SessionsCompanion(
          endedAt: Value(now),
          pausedSeconds: Value(timing.pausedSecondsTotalAt(now)),
          pauseStartedAt: const Value(null),
          activeSeconds: Value(active),
          overtimeSeconds: Value(overtime),
          outcome: Value(outcome.dbIndex),
        ),
      );
      if (outcome.countsAsDone) {
        await _dao.setEventStatus(
          eventId: row.eventId,
          status: EventStatus.completed.dbIndex,
          updatedAt: now,
        );
      }
      return SessionRecord.fromRow((await _dao.sessionById(sessionId))!);
    });
  }
}
