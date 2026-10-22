// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'roundup_dao.dart';

// ignore_for_file: type=lint
mixin _$RoundupDaoMixin on DatabaseAccessor<AppDatabase> {
  $WeeklyRoundupsTable get weeklyRoundups => attachedDatabase.weeklyRoundups;
  $BadgeUnlocksTable get badgeUnlocks => attachedDatabase.badgeUnlocks;
  RoundupDaoManager get managers => RoundupDaoManager(this);
}

class RoundupDaoManager {
  final _$RoundupDaoMixin _db;
  RoundupDaoManager(this._db);
  $$WeeklyRoundupsTableTableManager get weeklyRoundups =>
      $$WeeklyRoundupsTableTableManager(
        _db.attachedDatabase,
        _db.weeklyRoundups,
      );
  $$BadgeUnlocksTableTableManager get badgeUnlocks =>
      $$BadgeUnlocksTableTableManager(_db.attachedDatabase, _db.badgeUnlocks);
}
