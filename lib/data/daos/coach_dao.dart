import 'package:drift/drift.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/tables/coach_tables.dart';

part 'coach_dao.g.dart';

@DriftAccessor(tables: [CoachIntents, CoachReviews, CoachInsights])
class CoachDao extends DatabaseAccessor<AppDatabase> with _$CoachDaoMixin {
  CoachDao(super.attachedDatabase);

  Future<void> upsertIntent({
    required DateTime date,
    required String focusGoal,
    String? topEventIds,
    int? predictedEnergy,
  }) =>
      into(coachIntents).insertOnConflictUpdate(
        CoachIntentsCompanion.insert(
          date: date,
          focusGoal: focusGoal,
          topEventIds: Value(topEventIds),
          predictedEnergy: Value(predictedEnergy),
          createdAt: DateTime.now(),
        ),
      );

  Future<CoachIntentRow?> intentFor(DateTime date) =>
      (select(coachIntents)..where((r) => r.date.equals(date))).getSingleOrNull();

  Stream<CoachIntentRow?> watchIntent(DateTime date) => (select(coachIntents)
        ..where((r) => r.date.equals(date)))
      .watchSingleOrNull();

  Future<void> upsertReview({
    required DateTime date,
    required int energy,
    String? winText,
  }) =>
      into(coachReviews).insertOnConflictUpdate(
        CoachReviewsCompanion.insert(
          date: date,
          energy: energy,
          winText: Value(winText),
          createdAt: DateTime.now(),
        ),
      );

  Future<CoachReviewRow?> reviewFor(DateTime date) =>
      (select(coachReviews)..where((r) => r.date.equals(date))).getSingleOrNull();

  Stream<CoachReviewRow?> watchReview(DateTime date) => (select(coachReviews)
        ..where((r) => r.date.equals(date)))
      .watchSingleOrNull();

  Future<void> insertInsight({
    required int isoYear,
    required int isoWeek,
    required String kind,
    required String payloadJson,
  }) =>
      into(coachInsights).insertOnConflictUpdate(
        CoachInsightsCompanion.insert(
          isoYear: isoYear,
          isoWeek: isoWeek,
          kind: kind,
          payloadJson: payloadJson,
          generatedAt: DateTime.now(),
        ),
      );

  Future<List<CoachInsightRow>> insightsForWeek(int isoYear, int isoWeek) =>
      (select(coachInsights)
            ..where((r) => r.isoYear.equals(isoYear) & r.isoWeek.equals(isoWeek)))
          .get();

  Stream<List<CoachInsightRow>> watchInsightsForWeek(int isoYear, int isoWeek) =>
      (select(coachInsights)
            ..where((r) => r.isoYear.equals(isoYear) & r.isoWeek.equals(isoWeek)))
          .watch();
}
