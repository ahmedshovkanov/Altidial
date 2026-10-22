import 'package:drift/drift.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/tables/progress_table.dart';
import 'package:altidial/data/tables/weekly_roundups_table.dart';

part 'roundup_dao.g.dart';

/// Stores and lists the frozen weekly roundups, plus the badge unlocks per
/// week the generator names.
@DriftAccessor(tables: [WeeklyRoundups, BadgeUnlocks])
class RoundupDao extends DatabaseAccessor<AppDatabase> with _$RoundupDaoMixin {
  RoundupDao(super.attachedDatabase);

  Future<WeeklyRoundupRow?> roundupFor(int isoYear, int isoWeek) =>
      (select(weeklyRoundups)..where(
            (row) => row.isoYear.equals(isoYear) & row.isoWeek.equals(isoWeek),
          ))
          .getSingleOrNull();

  Future<void> insertRoundup({
    required int isoYear,
    required int isoWeek,
    required String payloadJson,
    required DateTime generatedAt,
  }) => into(weeklyRoundups).insert(
    WeeklyRoundupsCompanion.insert(
      isoYear: isoYear,
      isoWeek: isoWeek,
      generatedAt: generatedAt,
      payloadJson: payloadJson,
    ),
  );

  /// Every stored roundup, newest first.
  Stream<List<WeeklyRoundupRow>> watchArchive() =>
      (select(weeklyRoundups)..orderBy([
            (row) => OrderingTerm.desc(row.isoYear),
            (row) => OrderingTerm.desc(row.isoWeek),
          ]))
          .watch();

  Future<List<WeeklyRoundupRow>> archive() =>
      (select(weeklyRoundups)..orderBy([
            (row) => OrderingTerm.desc(row.isoYear),
            (row) => OrderingTerm.desc(row.isoWeek),
          ]))
          .get();

  /// Stable badge ids unlocked in `[from, toExclusive)`, in unlock order.
  Future<List<String>> unlocksInWeek(DateTime from, DateTime toExclusive) =>
      (select(badgeUnlocks)
            ..where(
              (row) =>
                  row.unlockedAt.isBiggerOrEqualValue(from) &
                  row.unlockedAt.isSmallerThanValue(toExclusive),
            )
            ..orderBy([(row) => OrderingTerm.asc(row.unlockedAt)]))
          .map((row) => row.badgeId)
          .get();
}
