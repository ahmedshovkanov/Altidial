import 'package:drift/drift.dart';
import 'package:energy_clock/core/event_status.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/tables/day_templates_table.dart';
import 'package:energy_clock/data/tables/events_table.dart';

part 'template_dao.g.dart';

/// A template and its events, for the template list.
typedef TemplateWithItems = ({
  DayTemplateRow template,
  List<DayTemplateItemRow> items,
});

/// Day templates, and the events of a day that a template is saved from or
/// applied to (spec §7).
@DriftAccessor(tables: [DayTemplates, DayTemplateItems, Events])
class TemplateDao extends DatabaseAccessor<AppDatabase>
    with _$TemplateDaoMixin {
  TemplateDao(super.attachedDatabase);

  static final int _skipped = EventStatus.skipped.dbIndex;

  /// Every template, newest first, each with its items in start order.
  Stream<List<TemplateWithItems>> watchTemplates() {
    final query =
        select(dayTemplates).join([
          leftOuterJoin(
            dayTemplateItems,
            dayTemplateItems.templateId.equalsExp(dayTemplates.id),
          ),
        ])..orderBy([
          OrderingTerm.desc(dayTemplates.createdAt),
          OrderingTerm.desc(dayTemplates.id),
          OrderingTerm.asc(dayTemplateItems.startMinute),
          OrderingTerm.asc(dayTemplateItems.id),
        ]);
    return query.watch().map((rows) {
      final byId = <int, TemplateWithItems>{};
      for (final row in rows) {
        final template = row.readTable(dayTemplates);
        final entry = byId.putIfAbsent(
          template.id,
          () => (template: template, items: <DayTemplateItemRow>[]),
        );
        final item = row.readTableOrNull(dayTemplateItems);
        if (item != null) entry.items.add(item);
      }
      return byId.values.toList();
    });
  }

  Future<int> insertTemplate(DayTemplatesCompanion entry) =>
      into(dayTemplates).insert(entry);

  Future<void> insertItem(DayTemplateItemsCompanion entry) =>
      into(dayTemplateItems).insert(entry);

  /// A template's items in start order.
  Future<List<DayTemplateItemRow>> itemsFor(int templateId) {
    return (select(dayTemplateItems)
          ..where((row) => row.templateId.equals(templateId))
          ..orderBy([
            (row) => OrderingTerm(expression: row.startMinute),
            (row) => OrderingTerm(expression: row.id),
          ]))
        .get();
  }

  Future<void> deleteTemplate(int id) async {
    await (delete(
      dayTemplateItems,
    )..where((row) => row.templateId.equals(id))).go();
    await (delete(dayTemplates)..where((row) => row.id.equals(id))).go();
  }

  /// The events really on [day] in start order; skipped rows are left out.
  Future<List<EventRow>> liveEventsOn(DateTime day) {
    return (select(events)
          ..where(
            (row) => row.date.equals(day) & row.status.isNotValue(_skipped),
          )
          ..orderBy([
            (row) => OrderingTerm(expression: row.startMinute),
            (row) => OrderingTerm(expression: row.id),
          ]))
        .get();
  }

  Future<int> insertEvent(EventsCompanion entry) => into(events).insert(entry);

  /// Runs [action] in one database transaction.
  Future<T> inTransaction<T>(Future<T> Function() action) =>
      transaction(action);
}
