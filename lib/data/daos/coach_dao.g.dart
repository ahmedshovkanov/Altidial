// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coach_dao.dart';

// ignore_for_file: type=lint
mixin _$CoachDaoMixin on DatabaseAccessor<AppDatabase> {
  $CoachIntentsTable get coachIntents => attachedDatabase.coachIntents;
  $CoachReviewsTable get coachReviews => attachedDatabase.coachReviews;
  $CoachInsightsTable get coachInsights => attachedDatabase.coachInsights;
  CoachDaoManager get managers => CoachDaoManager(this);
}

class CoachDaoManager {
  final _$CoachDaoMixin _db;
  CoachDaoManager(this._db);
  $$CoachIntentsTableTableManager get coachIntents =>
      $$CoachIntentsTableTableManager(_db.attachedDatabase, _db.coachIntents);
  $$CoachReviewsTableTableManager get coachReviews =>
      $$CoachReviewsTableTableManager(_db.attachedDatabase, _db.coachReviews);
  $$CoachInsightsTableTableManager get coachInsights =>
      $$CoachInsightsTableTableManager(_db.attachedDatabase, _db.coachInsights);
}
