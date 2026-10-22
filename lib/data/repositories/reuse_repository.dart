import 'package:drift/drift.dart' show Value;
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/daos/template_dao.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/models/day_template.dart';

export 'package:altidial/data/models/day_template.dart';

/// The longest template name; matches the column.
const int maxTemplateNameLength = 60;

/// Thrown by [ReuseRepository.saveTemplate] when the day has no events.
class EmptyDayException implements Exception {
  const EmptyDayException();
}

/// Thrown when a template or a copy would land on a day that already has
/// events. Templates and copy-yesterday only fill an empty day (spec §7).
class DayNotEmptyException implements Exception {
  const DayNotEmptyException();
}

/// Fills a day from another day's plan: day templates and copy-yesterday.
abstract interface class ReuseRepository {
  /// Every template, newest first.
  Stream<List<DayTemplate>> watchTemplates();

  /// Saves the events of [day] as a template named [name] (trimmed, and cut to
  /// [maxTemplateNameLength]). Throws [EmptyDayException] if the day has no
  /// events, and [ArgumentError] if the name is empty. Returns the new id.
  Future<int> saveTemplate({required String name, required DateTime day});

  Future<void> deleteTemplate(int id);

  /// Creates the template's events on [day], as planned one-off events.
  /// Returns how many it created (0 if the template no longer exists). Throws
  /// [DayNotEmptyException] if [day] already has events.
  Future<int> applyTemplate({required int templateId, required DateTime day});

  /// Copies the events of [from] onto [to], as planned one-off events. Returns
  /// how many it created. Throws [DayNotEmptyException] if [to] already has
  /// events.
  Future<int> copyDay({required DateTime from, required DateTime to});
}

class DriftReuseRepository implements ReuseRepository {
  DriftReuseRepository(this._dao, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final TemplateDao _dao;
  final DateTime Function() _clock;

  @override
  Stream<List<DayTemplate>> watchTemplates() => _dao.watchTemplates().map(
    (groups) => [
      for (final group in groups)
        DayTemplate(
          id: group.template.id,
          name: group.template.name,
          items: [
            for (final item in group.items)
              TemplateItem(
                title: item.title,
                tone: Tone.fromDbIndex(item.toneIndex),
                range: MinuteRange(item.startMinute, item.endMinute),
              ),
          ],
        ),
    ],
  );

  @override
  Future<int> saveTemplate({required String name, required DateTime day}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'A template needs a name');
    }
    final clipped = trimmed.length > maxTemplateNameLength
        ? trimmed.substring(0, maxTemplateNameLength)
        : trimmed;

    return _dao.inTransaction(() async {
      final events = await _dao.liveEventsOn(startOfDay(day));
      if (events.isEmpty) throw const EmptyDayException();

      final id = await _dao.insertTemplate(
        DayTemplatesCompanion.insert(name: clipped, createdAt: _clock()),
      );
      for (final event in events) {
        await _dao.insertItem(
          DayTemplateItemsCompanion.insert(
            templateId: id,
            title: event.title,
            toneIndex: event.toneIndex,
            startMinute: event.startMinute,
            endMinute: event.endMinute,
          ),
        );
      }
      return id;
    });
  }

  @override
  Future<void> deleteTemplate(int id) =>
      _dao.inTransaction(() => _dao.deleteTemplate(id));

  @override
  Future<int> applyTemplate({required int templateId, required DateTime day}) {
    final target = startOfDay(day);
    return _dao.inTransaction(() async {
      await _requireEmpty(target);
      final items = await _dao.itemsFor(templateId);
      final now = _clock();
      for (final item in items) {
        await _dao.insertEvent(
          EventsCompanion.insert(
            date: target,
            title: item.title,
            toneIndex: item.toneIndex,
            startMinute: item.startMinute,
            endMinute: item.endMinute,
            // Template items carry no project: applied events start unlinked.
            projectId: const Value(null),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      return items.length;
    });
  }

  @override
  Future<int> copyDay({required DateTime from, required DateTime to}) {
    final target = startOfDay(to);
    return _dao.inTransaction(() async {
      await _requireEmpty(target);
      final source = await _dao.liveEventsOn(startOfDay(from));
      final now = _clock();
      for (final event in source) {
        await _dao.insertEvent(
          EventsCompanion.insert(
            date: target,
            title: event.title,
            toneIndex: event.toneIndex,
            startMinute: event.startMinute,
            endMinute: event.endMinute,
            projectId: Value(event.projectId),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      return source.length;
    });
  }

  Future<void> _requireEmpty(DateTime day) async {
    if ((await _dao.liveEventsOn(day)).isNotEmpty) {
      throw const DayNotEmptyException();
    }
  }
}
