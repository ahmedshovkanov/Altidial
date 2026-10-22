import 'package:drift/drift.dart';

/// One day's cached score, always recomputable from `events` and `sessions`
/// (spec §9.1). Days with no plan and no sessions have no row.
@DataClassName('DayScoreRow')
class DayScores extends Table {
  /// Local midnight of the scored day.
  DateTimeColumn get date => dateTime()();

  /// 0–100, the sum of the three points columns.
  IntColumn get energyScore => integer()();

  /// 0–50.
  IntColumn get adherencePoints => integer()();

  /// 0–30.
  IntColumn get focusPoints => integer()();

  /// 0–20.
  IntColumn get balancePoints => integer()();

  /// The minute pool (countsAsDone), by tone.
  IntColumn get focusMinutes => integer().withDefault(const Constant(0))();
  IntColumn get lifeMinutes => integer().withDefault(const Constant(0))();
  IntColumn get inboxMinutes => integer().withDefault(const Constant(0))();

  IntColumn get plannedMinutes => integer().withDefault(const Constant(0))();
  IntColumn get completedMinutes => integer().withDefault(const Constant(0))();

  DateTimeColumn get computedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {date};
}
