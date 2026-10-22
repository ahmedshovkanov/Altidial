import 'package:drift/drift.dart';

/// The single cached progress row (spec §4.2): one row, id always 1.
@DataClassName('ProgressRow')
class Progress extends Table {
  IntColumn get id => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  IntColumn get xp => integer().withDefault(const Constant(0))();
  IntColumn get level => integer().withDefault(const Constant(1))();
  IntColumn get currentStreak => integer().withDefault(const Constant(0))();
  IntColumn get longestStreak => integer().withDefault(const Constant(0))();

  /// The last local day this row was computed for; drives `ensureFresh()`.
  DateTimeColumn get lastStreakDate => dateTime().nullable()();
}

/// Badge unlocks, keyed by the stable id of a code-side definition (spec §9.4).
@DataClassName('BadgeUnlockRow')
class BadgeUnlocks extends Table {
  TextColumn get badgeId => text()();

  DateTimeColumn get unlockedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {badgeId};
}
