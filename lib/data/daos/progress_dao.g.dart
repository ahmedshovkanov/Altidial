// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress_dao.dart';

// ignore_for_file: type=lint
mixin _$ProgressDaoMixin on DatabaseAccessor<AppDatabase> {
  $DayScoresTable get dayScores => attachedDatabase.dayScores;
  $ProgressTable get progress => attachedDatabase.progress;
  $BadgeUnlocksTable get badgeUnlocks => attachedDatabase.badgeUnlocks;
  $WeeklyRoundupsTable get weeklyRoundups => attachedDatabase.weeklyRoundups;
  $EventsTable get events => attachedDatabase.events;
  $SessionsTable get sessions => attachedDatabase.sessions;
  ProgressDaoManager get managers => ProgressDaoManager(this);
}

class ProgressDaoManager {
  final _$ProgressDaoMixin _db;
  ProgressDaoManager(this._db);
  $$DayScoresTableTableManager get dayScores =>
      $$DayScoresTableTableManager(_db.attachedDatabase, _db.dayScores);
  $$ProgressTableTableManager get progress =>
      $$ProgressTableTableManager(_db.attachedDatabase, _db.progress);
  $$BadgeUnlocksTableTableManager get badgeUnlocks =>
      $$BadgeUnlocksTableTableManager(_db.attachedDatabase, _db.badgeUnlocks);
  $$WeeklyRoundupsTableTableManager get weeklyRoundups =>
      $$WeeklyRoundupsTableTableManager(
        _db.attachedDatabase,
        _db.weeklyRoundups,
      );
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db.attachedDatabase, _db.events);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db.attachedDatabase, _db.sessions);
}
