// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'template_dao.dart';

// ignore_for_file: type=lint
mixin _$TemplateDaoMixin on DatabaseAccessor<AppDatabase> {
  $DayTemplatesTable get dayTemplates => attachedDatabase.dayTemplates;
  $DayTemplateItemsTable get dayTemplateItems =>
      attachedDatabase.dayTemplateItems;
  $EventsTable get events => attachedDatabase.events;
  TemplateDaoManager get managers => TemplateDaoManager(this);
}

class TemplateDaoManager {
  final _$TemplateDaoMixin _db;
  TemplateDaoManager(this._db);
  $$DayTemplatesTableTableManager get dayTemplates =>
      $$DayTemplatesTableTableManager(_db.attachedDatabase, _db.dayTemplates);
  $$DayTemplateItemsTableTableManager get dayTemplateItems =>
      $$DayTemplateItemsTableTableManager(
        _db.attachedDatabase,
        _db.dayTemplateItems,
      );
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db.attachedDatabase, _db.events);
}
