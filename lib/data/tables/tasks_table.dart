import 'package:drift/drift.dart';

import 'projects_table.dart';

/// First-class units of work under a project (schema v12). Replaces the v11
/// checklist. `boardStatus` is 0 backlog / 1 todo / 2 doing / 3 blocked /
/// 4 done; `blockedReason` only means something when `boardStatus == 3`.
/// `completedAt` is non-null exactly when `boardStatus == 4`. Title length is
/// documented here but enforced in `TaskRepository` (only NOT NULL reaches DDL).
@DataClassName('TaskRow')
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  TextColumn get notes => text().nullable()();
  IntColumn get boardStatus => integer().withDefault(const Constant(0))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  IntColumn get estimateMinutes => integer().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get plannedDate => dateTime().nullable()();
  IntColumn get sortOrder => integer()();
  TextColumn get blockedReason => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
}
