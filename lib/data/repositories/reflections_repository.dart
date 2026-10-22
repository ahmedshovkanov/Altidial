import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/repositories/session_repository.dart' show SessionRecord;
import 'package:altidial/features/reflections/model/reflection.dart';

typedef ReflectedSession = ({
  SessionRecord session,
  String eventTitle,
  Tone tone,
  DateTime eventDate,
  int startHour,
  bool isPostLife,
});

abstract interface class ReflectionsRepository {
  Future<List<ReflectedSession>> loadTimeline();
  Stream<List<ReflectedSession>> watchTimeline();
  Future<List<PatternCard>> loadPatterns();
}

class DriftReflectionsRepository implements ReflectionsRepository {
  DriftReflectionsRepository(this._db);
  final AppDatabase _db;

  @override
  Future<List<ReflectedSession>> loadTimeline() async {
    final sessions = await _db.sessionDao.endedSessions();
    return _join(sessions);
  }

  @override
  Stream<List<ReflectedSession>> watchTimeline() async* {
    yield await loadTimeline();
    await for (final _ in _db.tableUpdates(
      TableUpdateQuery.onAllTables([_db.sessions, _db.events]),
    )) {
      yield await loadTimeline();
    }
  }

  @override
  Future<List<PatternCard>> loadPatterns() async {
    final timeline = await loadTimeline();
    final inputs = <PatternInput>[
      for (final row in timeline)
        if (row.session.outcome.countsAsDone &&
            row.session.energyRating != null &&
            row.session.focusRating != null)
          (
            tone: row.tone,
            energyRating: row.session.energyRating!,
            focusRating: row.session.focusRating!,
            tags: row.session.tags,
            startHour: row.startHour,
            isPostLife: row.isPostLife,
          ),
    ];
    return ReflectionPatterns.compute(inputs);
  }

  Future<List<ReflectedSession>> _join(List<SessionRow> sessions) async {
    if (sessions.isEmpty) return const [];
    // One query for every event the sessions touch. Point-querying per session
    // meant two queries per row, and the timeline provider is not autoDispose,
    // so every pause or resume paid for it again while Stats was open.
    final events = await (_db.select(_db.events)
          ..where((t) => t.id.isIn({for (final s in sessions) s.eventId})))
        .get();
    final eventById = {for (final event in events) event.id: event};

    // isPostLife: true when the previous ended session the same day was Life tone.
    // Computed per day in chronological order, then reversed to newest-first.
    final byDay = <String, List<({SessionRow session, EventRow event})>>{};
    for (final s in sessions) {
      final event = eventById[s.eventId];
      if (event == null) continue;
      final key = '${event.date.year}-${event.date.month}-${event.date.day}';
      (byDay[key] ??= []).add((session: s, event: event));
    }
    final rows = <ReflectedSession>[];
    for (final daySessions in byDay.values) {
      daySessions.sort((a, b) => a.session.startedAt.compareTo(b.session.startedAt));
      Tone? prevTone;
      for (final s in daySessions) {
        final event = s.event;
        final tone = Tone.fromDbIndex(event.toneIndex);
        final isPostLife = prevTone == Tone.life && tone == Tone.focus;
        rows.add((
          session: SessionRecord.fromRow(s.session),
          eventTitle: event.title,
          tone: tone,
          eventDate: event.date,
          startHour: event.startMinute ~/ 60,
          isPostLife: isPostLife,
        ));
        prevTone = tone;
      }
    }
    rows.sort((a, b) => b.session.endedAt!.compareTo(a.session.endedAt!));
    return rows;
  }
}