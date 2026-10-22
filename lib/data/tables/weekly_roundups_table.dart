import 'package:drift/drift.dart';

/// A generated Weekly Roundup, frozen as JSON (spec §9.6). One row per ISO
/// week; rows are never rewritten.
@DataClassName('WeeklyRoundupRow')
class WeeklyRoundups extends Table {
  IntColumn get isoYear => integer()();

  IntColumn get isoWeek => integer()();

  DateTimeColumn get generatedAt => dateTime()();

  TextColumn get payloadJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {isoYear, isoWeek};
}
