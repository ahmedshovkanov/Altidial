import 'dart:async';

import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/repositories/reuse_repository.dart';

import 'fake_event_repository.dart';

/// In-memory [ReuseRepository] for widget tests. Templates live in memory;
/// applying one and copying a day create events in [FakeEventRepository], with
/// the same refusals as the real repository.
class FakeReuseRepository implements ReuseRepository {
  FakeReuseRepository(this._events);

  final FakeEventRepository _events;
  final List<DayTemplate> _templates = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();
  int _nextId = 1;

  void dispose() {
    unawaited(_changes.close());
  }

  /// The saved templates, oldest first.
  List<DayTemplate> get templates => List.unmodifiable(_templates);

  /// Adds a template directly and returns its id.
  int addTemplate(String name, List<TemplateItem> items) {
    final id = _nextId++;
    _templates.add(DayTemplate(id: id, name: name, items: items));
    _notify();
    return id;
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  List<DayTemplate> _newestFirst() => _templates.reversed.toList();

  @override
  Stream<List<DayTemplate>> watchTemplates() async* {
    yield _newestFirst();
    yield* _changes.stream.map((_) => _newestFirst());
  }

  @override
  Future<int> saveTemplate({
    required String name,
    required DateTime day,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'A template needs a name');
    }
    final events = await _events.eventsForDay(day);
    if (events.isEmpty) throw const EmptyDayException();
    return addTemplate(trimmed, [
      for (final event in events)
        TemplateItem(title: event.title, tone: event.tone, range: event.range),
    ]);
  }

  @override
  Future<void> deleteTemplate(int id) async {
    _templates.removeWhere((template) => template.id == id);
    _notify();
  }

  Future<void> _requireEmpty(DateTime day) async {
    if ((await _events.eventsForDay(day)).isNotEmpty) {
      throw const DayNotEmptyException();
    }
  }

  @override
  Future<int> applyTemplate({
    required int templateId,
    required DateTime day,
  }) async {
    await _requireEmpty(day);
    final matches = _templates.where((template) => template.id == templateId);
    if (matches.isEmpty) return 0;
    final items = matches.single.items;
    for (final item in items) {
      await _events.createEvent(
        day: startOfDay(day),
        title: item.title,
        tone: item.tone,
        range: item.range,
      );
    }
    return items.length;
  }

  @override
  Future<int> copyDay({required DateTime from, required DateTime to}) async {
    await _requireEmpty(to);
    final source = await _events.eventsForDay(from);
    for (final event in source) {
      await _events.createEvent(
        day: startOfDay(to),
        title: event.title,
        tone: event.tone,
        range: event.range,
      );
    }
    return source.length;
  }
}
