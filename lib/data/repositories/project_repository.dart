import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:altidial/core/session/session_outcome.dart';
import 'package:altidial/data/database.dart';

/// One project's live detail: its row, linked events, and recomputed minutes.
///
/// `plannedMinutes` sums the linked events' (`endMinute - startMinute`);
/// `actualMinutes` truncates (`~/ 60`) the summed `activeSeconds` of linked
/// sessions whose outcome counts as done — abandoned and running excluded.
/// Same truncation rule as Stats; feed both into `ProjectProgress.compute`.
class ProjectDetail {
  const ProjectDetail({
    required this.project,
    required this.events,
    required this.plannedMinutes,
    required this.actualMinutes,
    this.sessionsCount = 0,
    this.lastWorkedAt,
    this.doneSessions = const [],
  });

  final ProjectRow project;
  final List<EventRow> events;
  final int plannedMinutes;
  final int actualMinutes;

  /// Done sessions linked to this project (completed + finished early).
  final int sessionsCount;

  /// Max done-session end time (`endedAt ?? startedAt`), null when the
  /// project has no done sessions yet. Powers hub "worked Nd ago" lines.
  final DateTime? lastWorkedAt;

  /// The done-outcome sessions behind [actualMinutes], from the same single
  /// grouped query (never per-event calls). The detail view derives the
  /// 7-day velocity (`velocityLast7Days`) and per-event actuals from this
  /// list client-side in O(n); it is already filtered to done outcomes, so
  /// callers must not re-filter or mix in raw DAO rows.
  final List<SessionRow> doneSessions;
}

abstract interface class ProjectRepository {
  Stream<List<ProjectRow>> watchProjects();

  /// The detail of [id], re-emitted on every database change (same reload
  /// loop as `StatsRepository.watchWindow`). Errors when the project row
  /// is gone — callers close the detail when the project is deleted.
  Stream<ProjectDetail> watchDetail(int id);
  Future<int> create(String title);
  Future<void> updateTitle(int id, String title);
  Future<void> updateNotes(int id, String? notes);
  Future<void> updatePriority(int id, int priority);
  Future<void> updateDeadline(int id, DateTime? deadline);
  Future<void> updateTarget(int id, int? targetMinutes);
  Future<void> updateAffinity(int id, int? toneIndex);
  Future<void> complete(int id);
  Future<void> reopen(int id);
  Future<void> archive(int id);
  Future<void> unarchive(int id);
  Future<void> deleteAndUnlink(int id);
}

class DriftProjectRepository implements ProjectRepository {
  DriftProjectRepository(this._db);
  final AppDatabase _db;

  @override
  Stream<List<ProjectRow>> watchProjects() => _db.projectDao.watchProjects();

  @override
  Stream<ProjectDetail> watchDetail(int id) async* {
    yield await _loadDetail(id);
    // Only project/event/session writes can change a detail. Filtered (not
    // broadcast) so unrelated tables don't reload.
    await for (final _ in _db.tableUpdates(
      TableUpdateQuery.onAllTables([_db.projects, _db.events, _db.sessions]),
    )) {
      yield await _loadDetail(id);
    }
  }

  /// Planned from event ranges, actuals from one grouped session query over
  /// all linked events (done outcomes only).
  Future<ProjectDetail> _loadDetail(int id) => _db.transaction(() async {
    final project =
        await (_db.select(_db.projects)..where((row) => row.id.equals(id)))
            .getSingle();
    final events = await _db.eventDao.eventsForProject(id);
    final doneOutcomes = <int>{
      SessionOutcome.completed.dbIndex,
      SessionOutcome.finishedEarly.dbIndex,
    };
    final sessions = events.isEmpty
        ? <SessionRow>[]
        : await _db.sessionDao.sessionsForProject(
            events.map((e) => e.id).toList(),
          );
    final done =
        sessions.where((s) => doneOutcomes.contains(s.outcome)).toList();
    final plannedMinutes = events.fold<int>(
      0,
      (sum, event) => sum + (event.endMinute - event.startMinute),
    );
    final actualMinutes =
        done.fold<int>(0, (sum, s) => sum + s.activeSeconds) ~/ 60;
    final lastWorkedAt = done.isEmpty
        ? null
        : done
              .map((s) => s.endedAt ?? s.startedAt)
              .reduce((a, b) => a.isAfter(b) ? a : b);
    return ProjectDetail(
      project: project,
      events: events,
      plannedMinutes: plannedMinutes,
      actualMinutes: actualMinutes,
      sessionsCount: done.length,
      lastWorkedAt: lastWorkedAt,
      doneSessions: done,
    );
  });

  @override
  Future<int> create(String title) => _db.projectDao.createProject(
    ProjectsCompanion.insert(title: title.trim(), createdAt: DateTime.now()),
  );

  @override
  Future<void> updateTitle(int id, String title) =>
      _db.projectDao.updateTitle(id, title);

  @override
  Future<void> updateNotes(int id, String? notes) =>
      _db.projectDao.updateNotes(id, notes);

  @override
  Future<void> updatePriority(int id, int priority) =>
      _db.projectDao.updatePriority(id, priority);

  @override
  Future<void> updateDeadline(int id, DateTime? deadline) =>
      _db.projectDao.updateDeadline(id, deadline);

  @override
  Future<void> updateTarget(int id, int? targetMinutes) =>
      _db.projectDao.updateTarget(id, targetMinutes);

  @override
  Future<void> updateAffinity(int id, int? toneIndex) =>
      _db.projectDao.updateAffinity(id, toneIndex);

  @override
  Future<void> complete(int id) =>
      _db.projectDao.setStatus(id, 1, DateTime.now());

  @override
  Future<void> reopen(int id) => _db.projectDao.setStatus(id, 0, null);

  @override
  Future<void> archive(int id) async {
    // Preserve a prior completion time: archiving hides, it doesn't unfinish.
    final row =
        await (_db.select(_db.projects)..where((r) => r.id.equals(id)))
            .getSingleOrNull();
    await _db.projectDao.setStatus(id, 2, row?.completedAt);
  }

  @override
  Future<void> unarchive(int id) async {
    // The archived row encodes its own past: archiving preserves
    // completedAt, so a non-null stamp means the project was completed and
    // a null stamp means it was active. Restores both exactly.
    final row =
        await (_db.select(_db.projects)..where((r) => r.id.equals(id)))
            .getSingleOrNull();
    final completedAt = row?.completedAt;
    await _db.projectDao.setStatus(
      id,
      completedAt == null ? 0 : 1,
      completedAt,
    );
  }

  @override
  Future<void> deleteAndUnlink(int id) => _db.projectDao.deleteAndUnlink(id);
}
