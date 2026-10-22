// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'series_dao.dart';

// ignore_for_file: type=lint
mixin _$SeriesDaoMixin on DatabaseAccessor<AppDatabase> {
  $EventSeriesTable get eventSeries => attachedDatabase.eventSeries;
  $EventsTable get events => attachedDatabase.events;
  $SessionsTable get sessions => attachedDatabase.sessions;
  SeriesDaoManager get managers => SeriesDaoManager(this);
}

class SeriesDaoManager {
  final _$SeriesDaoMixin _db;
  SeriesDaoManager(this._db);
  $$EventSeriesTableTableManager get eventSeries =>
      $$EventSeriesTableTableManager(_db.attachedDatabase, _db.eventSeries);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db.attachedDatabase, _db.events);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db.attachedDatabase, _db.sessions);
}
