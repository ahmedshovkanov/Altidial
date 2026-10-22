import 'package:drift/drift.dart';

/// A named day plan the person saved to reuse (spec §7, day templates). The
/// events of the plan are in [DayTemplateItems].
@DataClassName('DayTemplateRow')
class DayTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 60)();

  DateTimeColumn get createdAt => dateTime()();
}

/// One event of a template: the same fields as an event, minus the day and the
/// status, which a template does not have.
@DataClassName('DayTemplateItemRow')
class DayTemplateItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get templateId => integer().references(DayTemplates, #id)();

  TextColumn get title => text().withLength(min: 1, max: 120)();

  IntColumn get toneIndex => integer()();

  /// 0–1439.
  IntColumn get startMinute => integer()();

  /// 1–1440, exclusive.
  IntColumn get endMinute => integer()();
}
