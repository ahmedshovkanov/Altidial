import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/session/session_outcome.dart';
import 'package:energy_clock/core/session/session_timing.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/daos/session_dao.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/features/reflections/model/reflection.dart';

/// A session as the rest of the app sees it, kept separate from the Drift row
/// so that widgets never depend on the persistence layer's generated types.
class SessionRecord {
  const SessionRecord({
    required this.id,
    required this.eventId,
    required this.startedAt,
    required this.endedAt,
    required this.plannedSeconds,
    required this.pausedSeconds,
    required this.pauseStartedAt,
    required this.activeSeconds,
    required this.overtimeSeconds,
    required this.outcome,
    this.energyRating,
    this.focusRating,
    this.tags = const [],
    this.note,
  });

  factory SessionRecord.fromRow(SessionRow row) => SessionRecord(
    id: row.id,
    eventId: row.eventId,
    startedAt: row.startedAt,
    endedAt: row.endedAt,
    plannedSeconds: row.plannedSeconds,
    pausedSeconds: row.pausedSeconds,
    pauseStartedAt: row.pauseStartedAt,
    activeSeconds: row.activeSeconds,
    overtimeSeconds: row.overtimeSeconds,
    outcome: SessionOutcome.fromDbIndex(row.outcome),
    energyRating: row.energyRating,
    focusRating: row.focusRating,
    // Sanitised on the way in: a corrupt or legacy csv must not put an unknown
    // id in front of a person as a tag.
    tags: ReflectionTags.decodeTags(row.tagsCsv),
    note: row.note,
  );

  final int id;
  final int eventId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int plannedSeconds;
  final int pausedSeconds;
  final DateTime? pauseStartedAt;
  final int activeSeconds;
  final int overtimeSeconds;
  final SessionOutcome outcome;
  final int? energyRating;
  final int? focusRating;
  final List<String> tags;
  final String? note;

  /// The wall-clock arithmetic for this session.
  SessionTiming get timing => SessionTiming(
    startedAt: startedAt,
    plannedSeconds: plannedSeconds,
    pausedSeconds: pausedSeconds,
    pauseStartedAt: pauseStartedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is SessionRecord &&
      other.id == id &&
      other.eventId == eventId &&
      other.startedAt == startedAt &&
      other.endedAt == endedAt &&
      other.plannedSeconds == plannedSeconds &&
      other.pausedSeconds == pausedSeconds &&
      other.pauseStartedAt == pauseStartedAt &&
      other.activeSeconds == activeSeconds &&
      other.overtimeSeconds == overtimeSeconds &&
      other.outcome == outcome &&
      other.energyRating == energyRating &&
      other.focusRating == focusRating &&
      other.note == note &&
      _tagsEqual(other.tags, tags);

  static bool _tagsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    eventId,
    startedAt,
    endedAt,
    plannedSeconds,
    pausedSeconds,
    pauseStartedAt,
    activeSeconds,
    overtimeSeconds,
    outcome,
    energyRating,
    focusRating,
    note,
    Object.hashAll(tags),
  );
}

/// The session that is running now, with the details of its event, which is
/// all the session screen needs.
class RunningSession {
  const RunningSession({
    required this.session,
    required this.eventTitle,
    required this.eventTone,
    required this.eventDate,
    required this.eventRange,
  });

  factory RunningSession.fromRow(RunningRow row) => RunningSession(
    session: SessionRecord.fromRow(row.session),
    eventTitle: row.event.title,
    eventTone: Tone.fromDbIndex(row.event.toneIndex),
    eventDate: row.event.date,
    eventRange: MinuteRange(row.event.startMinute, row.event.endMinute),
  );

  final SessionRecord session;
  final String eventTitle;
  final Tone eventTone;

  /// Local midnight of the event's day.
  final DateTime eventDate;

  /// The slot the event holds on the dial.
  final MinuteRange eventRange;

  int get id => session.id;
  int get eventId => session.eventId;
  SessionTiming get timing => session.timing;

  @override
  bool operator ==(Object other) =>
      other is RunningSession &&
      other.session == session &&
      other.eventTitle == eventTitle &&
      other.eventTone == eventTone &&
      other.eventDate == eventDate &&
      other.eventRange == eventRange;

  @override
  int get hashCode =>
      Object.hash(session, eventTitle, eventTone, eventDate, eventRange);
}
