import 'package:drift/drift.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/tables/events_table.dart';
import 'package:altidial/data/tables/projects_table.dart';
import 'package:altidial/data/tables/tasks_table.dart';

part 'project_dao.g.dart';

/// Data access for durable user outcomes (schema v6 foundation).
/// Expanded with link helpers and status transitions in Task 3.
@DriftAccessor(tables: [Projects, Events, Tasks])
class ProjectDao extends DatabaseAccessor<AppDatabase>
    with _$ProjectDaoMixin {
  ProjectDao(super.attachedDatabase);

  Future<int> createProject(ProjectsCompanion entry) =>
      into(projects).insert(entry);
  Future<List<ProjectRow>> allProjects() =>
      (select(projects)
            ..orderBy([
              (r) => OrderingTerm(
                expression: r.createdAt,
                mode: OrderingMode.desc,
              ),
            ])
            ..limit(200))
          .get();
  Stream<List<ProjectRow>> watchProjects() =>
      (select(projects)
            ..orderBy([
              (r) => OrderingTerm(
                expression: r.createdAt,
                mode: OrderingMode.desc,
              ),
            ])
            ..limit(200))
          .watch();
  /// Active (status 0) projects carrying a deadline, for the notification
  /// reconcile pass. Completed and archived projects never remind.
  Future<List<ProjectRow>> activeProjectsWithDeadline() =>
      (select(projects)
            ..where((r) => r.status.equals(0) & r.deadline.isNotNull()))
          .get();
  Future<void> updateTitle(int id, String title) =>
      (update(projects)..where((r) => r.id.equals(id))).write(
        ProjectsCompanion(title: Value(title.trim())),
      );
  Future<void> updateNotes(int id, String? notes) =>
      (update(projects)..where((r) => r.id.equals(id))).write(
        ProjectsCompanion(notes: Value(notes?.trim().isEmpty == true ? null : notes?.trim())),
      );
  Future<void> updatePriority(int id, int priority) =>
      (update(projects)..where((r) => r.id.equals(id))).write(
        ProjectsCompanion(priority: Value(priority.clamp(0, 3))),
      );
  Future<void> updateDeadline(int id, DateTime? deadline) =>
      (update(projects)..where((r) => r.id.equals(id))).write(
        ProjectsCompanion(deadline: Value(deadline)),
      );
  Future<void> updateTarget(int id, int? targetMinutes) =>
      (update(projects)..where((r) => r.id.equals(id))).write(
        ProjectsCompanion(targetMinutes: Value(targetMinutes)),
      );
  Future<void> updateAffinity(int id, int? toneIndex) =>
      (update(projects)..where((r) => r.id.equals(id))).write(
        ProjectsCompanion(toneIndex: Value(toneIndex)),
      );
  Future<void> setStatus(int id, int status, DateTime? completedAt) =>
      (update(projects)..where((r) => r.id.equals(id))).write(
        ProjectsCompanion(
          status: Value(status),
          completedAt: Value(completedAt),
        ),
      );
  /// Deletes the project row only; linked events keep their rows with projectId cleared.
  /// Tasks are deleted in the same transaction: the v12 foreign key cascades
  /// too, but that only fires when `PRAGMA foreign_keys` is on (off by default
  /// in tests), so the explicit delete is the contract.
  Future<void> deleteAndUnlink(int id) => transaction(() async {
    await (delete(tasks)..where((r) => r.projectId.equals(id))).go();
    await (update(events)..where((r) => r.projectId.equals(id))).write(
      const EventsCompanion(projectId: Value(null)),
    );
    await (delete(projects)..where((r) => r.id.equals(id))).go();
  });
}
