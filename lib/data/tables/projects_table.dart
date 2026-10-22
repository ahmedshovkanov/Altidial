import 'package:drift/drift.dart';

/// Durable user outcomes. Events link via `events.project_id`.
/// Status: 0 active, 1 completed, 2 archived.
@DataClassName('ProjectRow')
class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 80)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get deadline => dateTime().nullable()();
  IntColumn get targetMinutes => integer().nullable()();
  IntColumn get toneIndex => integer().nullable()();
  IntColumn get status => integer().withDefault(const Constant(0))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
}
