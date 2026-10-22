import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/project_repository.dart';
import 'package:energy_clock/features/clock/widgets/event_sheet.dart';
import 'package:energy_clock/features/projects/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_event_repository.dart';
import '../../support/fake_series_repository.dart';

class _SheetHarness {
  _SheetHarness();

  final FakeEventRepository repository = FakeEventRepository();
  late final FakeSeriesRepository series = FakeSeriesRepository(repository);

  void dispose() => repository.dispose();

  Future<void> open(
    WidgetTester tester, {
    required DateTime day,
    int? editing,
  }) async {
    tester.view.physicalSize = const Size(402, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final existing = editing == null
        ? null
        : repository.eventById(editing);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventRepositoryProvider.overrideWithValue(repository),
          seriesRepositoryProvider.overrideWithValue(series),
          projectListProvider.overrideWith((ref) => Stream.value(const [])),
          projectsRepositoryProvider.overrideWithValue(_FakeProjects()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => EventSheet.show(
                  context,
                  day: day,
                  initialRange: existing?.range ?? const MinuteRange(540, 600),
                  existing: existing,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }
}

// Minimal ProjectRepository stub for EventSheet's project list only.
class _FakeProjects implements ProjectRepository {
  @override
  Stream<List<ProjectRow>> watchProjects() => Stream.value(const []);

  @override
  Stream<ProjectDetail> watchDetail(int id) =>
      Stream.error(StateError('no detail'));

  @override
  Future<int> create(String title) async => 999;

  @override
  Future<void> updateTitle(int id, String title) async {}

  @override
  Future<void> updateNotes(int id, String? notes) async {}

  @override
  Future<void> updatePriority(int id, int priority) async {}

  @override
  Future<void> updateDeadline(int id, DateTime? deadline) async {}

  @override
  Future<void> updateTarget(int id, int? targetMinutes) async {}

  @override
  Future<void> updateAffinity(int id, int? toneIndex) async {}

  @override
  Future<void> complete(int id) async {}

  @override
  Future<void> reopen(int id) async {}

  @override
  Future<void> archive(int id) async {}

  @override
  Future<void> unarchive(int id) async {}

  @override
  Future<void> deleteAndUnlink(int id) async {}
}

Future<void> _save(WidgetTester tester) async {
  final finder = find.text(Strings.save);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _unlinkViaPicker(WidgetTester tester) async {
  final row = find.widgetWithText(ListTile, Strings.projectPickerTitle);
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
  // Picker always offers No project, even with an empty list.
  await tester.tap(find.text(Strings.projectNone).last);
  await tester.pumpAndSettle();
}

void main() {
  group('recurring create', () {
    testWidgets('repeat disables the picker and links nothing', (
      tester,
    ) async {
      final harness = _SheetHarness();
      addTearDown(harness.dispose);
      final day = DateTime(2026, 10, 20);

      await harness.open(tester, day: day);
      await tester.enterText(find.byType(TextField), 'Standup');

      await tester.tap(find.text(Strings.repeatDaily));
      await tester.pumpAndSettle();

      // Picker row explains why it is disabled.
      expect(find.text(Strings.projectRepeatingHint), findsOneWidget);

      await _save(tester);

      expect(find.byType(EventSheet), findsNothing);
      expect(harness.series.created, hasLength(1));
      // No single-row link attempt for the recurring create.
      expect(harness.repository.updateProjectCalls, isEmpty);
      final events = await harness.repository.eventsForDay(day);
      expect(events.single.projectId, isNull);
    });
  });

  group('edit scope', () {
    testWidgets('this-event updates one row', (tester) async {
      final harness = _SheetHarness();
      addTearDown(harness.dispose);
      final day = DateTime(2026, 10, 20);
      final seriesId = harness.series.addSeries(RecurrenceRule.daily());
      final id = harness.repository.addOccurrence(
        seriesId: seriesId,
        day: day,
        title: 'Standup',
      );
      // Pre-link, then clear the log so only save-time calls count.
      await harness.repository.updateProject(id: id, projectId: 7);
      harness.repository.updateProjectCalls.clear();
      harness.repository.updateProjectForSeriesCalls.clear();

      await harness.open(tester, day: day, editing: id);
      await _unlinkViaPicker(tester);
      await _save(tester);

      // Edit-scope question: choose this event only.
      expect(find.text(Strings.editScopeTitle), findsOneWidget);
      await tester.tap(find.text(Strings.scopeThisEvent));
      await tester.pumpAndSettle();

      expect(harness.repository.updateProjectCalls, hasLength(1));
      expect(harness.repository.updateProjectCalls.single.projectId, isNull);
      expect(harness.repository.updateProjectForSeriesCalls, isEmpty);
      expect(harness.repository.eventById(id)!.projectId, isNull);
    });

    testWidgets('all-future updates the series range', (tester) async {
      final harness = _SheetHarness();
      addTearDown(harness.dispose);
      final day = DateTime(2026, 10, 20);
      final seriesId = harness.series.addSeries(RecurrenceRule.daily());
      final id = harness.repository.addOccurrence(
        seriesId: seriesId,
        day: day,
        title: 'Standup',
      );
      // A later occurrence of the same series, also pre-linked.
      final later = harness.repository.addOccurrence(
        seriesId: seriesId,
        day: day.add(const Duration(days: 1)),
        title: 'Standup',
      );
      await harness.repository.updateProject(id: id, projectId: 7);
      await harness.repository.updateProject(id: later, projectId: 7);
      harness.repository.updateProjectCalls.clear();
      harness.repository.updateProjectForSeriesCalls.clear();

      await harness.open(tester, day: day, editing: id);
      await _unlinkViaPicker(tester);
      await _save(tester);

      await tester.tap(find.text(Strings.scopeThisAndFuture));
      await tester.pumpAndSettle();

      expect(harness.repository.updateProjectForSeriesCalls, hasLength(1));
      final call = harness.repository.updateProjectForSeriesCalls.single;
      expect(call.seriesId, seriesId);
      expect(call.projectId, isNull);
      // The split deletes later occurrences; the bulk call covers any that
      // remain (none here) and the edited row is unlinked.
      expect(harness.repository.eventById(later), isNull);
      expect(harness.repository.eventById(id)!.projectId, isNull);
    });
  });

  group('read-only and flights', () {
    testWidgets('past-day picker is disabled', (tester) async {
      final harness = _SheetHarness();
      addTearDown(harness.dispose);
      final past = DateTime.now().subtract(const Duration(days: 2));
      final start = DateTime(past.year, past.month, past.day);

      await harness.open(tester, day: start);

      final tile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, Strings.projectPickerTitle),
      );
      expect(tile.enabled, isFalse);
    });

    testWidgets('flight event with project stores both', (tester) async {
      final harness = _SheetHarness();
      addTearDown(harness.dispose);
      final day = DateTime(2026, 10, 20);

      // Storage level: flight-forces-Inbox coexists with a project link.
      final id = await harness.repository.createEvent(
        day: day,
        title: 'Trip',
        tone: Tone.focus,
        range: const MinuteRange(540, 600),
        isFlight: true,
        flightNumber: 'LH715',
        fromCode: 'SOF',
        toCode: 'BER',
        projectId: 7,
      );
      final stored = harness.repository.eventById(id)!;
      expect(stored.isFlight, isTrue);
      expect(stored.tone, Tone.inbox);
      expect(stored.projectId, 7);

      // Sheet level: the picker row stays enabled for flights.
      await harness.open(tester, day: day);
      await tester.tap(find.byKey(const Key('flight-toggle')));
      await tester.pump();
      final tile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, Strings.projectPickerTitle),
      );
      expect(tile.enabled, isTrue);
    });
  });
}
