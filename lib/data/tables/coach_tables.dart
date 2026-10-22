import 'package:drift/drift.dart';

/// One morning intent per local day.
@DataClassName('CoachIntentRow')
class CoachIntents extends Table {
  DateTimeColumn get date => dateTime()();
  TextColumn get focusGoal => text().withLength(min: 1, max: 120)();
  TextColumn get topEventIds => text().nullable()();
  IntColumn get predictedEnergy => integer().nullable().check(predictedEnergy.isBetweenValues(1, 5))();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {date};
}

/// One evening review per local day. Adherence is read live from day_scores.
@DataClassName('CoachReviewRow')
class CoachReviews extends Table {
  DateTimeColumn get date => dateTime()();
  IntColumn get energy => integer().check(energy.isBetweenValues(1, 5))();
  TextColumn get winText => text().withLength(max: 140).nullable()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {date};
}

/// Frozen weekly insight cards, one row per rule per ISO week.
@DataClassName('CoachInsightRow')
class CoachInsights extends Table {
  IntColumn get isoYear => integer()();
  IntColumn get isoWeek => integer()();
  TextColumn get kind => text().withLength(min: 1, max: 32)();
  TextColumn get payloadJson => text()();
  DateTimeColumn get generatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {isoYear, isoWeek, kind};
}
