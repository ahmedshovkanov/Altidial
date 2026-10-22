import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/task_status.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/features/projects/model/task_board.dart';
import 'package:energy_clock/features/projects/providers.dart';
import 'package:energy_clock/features/projects/widgets/task_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

TaskRow task({
  int id = 1,
  String title = 'A',
  int status = 0,
  int priority = 0,
  int sortOrder = 0,
  DateTime? due,
  DateTime? createdAt,
}) => TaskRow(
  id: id,
  projectId: 1,
  title: title,
  notes: null,
  boardStatus: status,
  priority: priority,
  estimateMinutes: null,
  dueDate: due,
  plannedDate: null,
  sortOrder: sortOrder,
  blockedReason: null,
  createdAt: createdAt ?? DateTime(2026, 10, 1),
  updatedAt: createdAt ?? DateTime(2026, 10, 1),
  completedAt: status == TaskStatus.done.dbIndex ? DateTime(2026, 10, 2) : null,
);

void main() {
  group('applyTasksView', () {
    test('query filters by title substring, due filter and priorities', () {
      final view = TasksView(
        query: 'ship',
        priorities: {3},
        dueFilter: TasksDueFilter.overdue,
      );
      final rows = [
        task(
          id: 1,
          title: 'Ship v1',
          priority: 3,
          due: DateTime(2026, 10, 5),
        ),
        task(
          id: 2,
          title: 'Ship v2',
          priority: 1,
          due: DateTime(2026, 10, 5),
        ),
        task(
          id: 3,
          title: 'Ship v3',
          priority: 3,
          due: DateTime(2026, 10, 20),
        ),
        task(id: 4, title: 'Polish', priority: 3, due: DateTime(2026, 10, 5)),
        task(id: 5, title: 'Ship v4', priority: 3),
      ];
      final result = applyTasksView(
        rows,
        view,
        now: DateTime(2026, 10, 10),
      );
      expect(result.map((t) => t.id), [1]);
    });

    test('query is trimmed and case-insensitive', () {
      final rows = [
        task(id: 1, title: 'Ship the thing'),
        task(id: 2, title: 'Other'),
      ];
      final result = applyTasksView(rows, const TasksView(query: '  SHIP '));
      expect(result.map((t) => t.id), [1]);
    });

    test('overdue keeps only dates strictly before today', () {
      final rows = [
        task(id: 1, due: DateTime(2026, 10, 9, 23)),
        task(id: 2, due: DateTime(2026, 10, 10)),
        task(id: 3, due: DateTime(2026, 10, 11)),
        task(id: 4),
      ];
      final result = applyTasksView(
        rows,
        const TasksView(dueFilter: TasksDueFilter.overdue),
        now: DateTime(2026, 10, 10, 9),
      );
      expect(result.map((t) => t.id), [1]);
    });

    test('today keeps only the same calendar day', () {
      final rows = [
        task(id: 1, due: DateTime(2026, 10, 10, 8)),
        task(id: 2, due: DateTime(2026, 10, 10, 20)),
        task(id: 3, due: DateTime(2026, 10, 11)),
        task(id: 4),
      ];
      final result = applyTasksView(
        rows,
        const TasksView(dueFilter: TasksDueFilter.today),
        now: DateTime(2026, 10, 10, 9),
      );
      expect(result.map((t) => t.id), [1, 2]);
    });

    test('none keeps only tasks without a due date', () {
      final rows = [
        task(id: 1, due: DateTime(2026, 10, 10)),
        task(id: 2),
      ];
      final result = applyTasksView(
        rows,
        const TasksView(dueFilter: TasksDueFilter.none),
      );
      expect(result.map((t) => t.id), [2]);
    });

    test('thisWeek drops dates more than seven days out', () {
      final rows = [
        task(id: 1, due: DateTime(2026, 10, 10)),
        task(id: 2, due: DateTime(2026, 10, 17)),
        task(id: 3, due: DateTime(2026, 10, 18)),
        task(id: 4),
      ];
      final result = applyTasksView(
        rows,
        const TasksView(dueFilter: TasksDueFilter.thisWeek),
        now: DateTime(2026, 10, 10, 9),
      );
      expect(result.map((t) => t.id), [1, 2]);
    });

    test('showDone false removes done tasks', () {
      final rows = [
        task(id: 1, status: TaskStatus.todo.dbIndex),
        task(id: 2, status: TaskStatus.done.dbIndex),
      ];
      final result = applyTasksView(rows, const TasksView(showDone: false));
      expect(result.map((t) => t.id), [1]);
    });

    test('statusFilter keeps only the chosen statuses', () {
      final rows = [
        task(id: 1, status: TaskStatus.todo.dbIndex),
        task(id: 2, status: TaskStatus.doing.dbIndex),
      ];
      final result = applyTasksView(
        rows,
        const TasksView(statusFilter: {TaskStatus.doing}),
      );
      expect(result.map((t) => t.id), [2]);
    });

    test('applies the view sort', () {
      final rows = [
        task(id: 1, title: 'Beta'),
        task(id: 2, title: 'Alpha'),
      ];
      final result = applyTasksView(rows, const TasksView(sort: TasksSort.title));
      expect(result.map((t) => t.id), [2, 1]);
    });
  });

  group('TasksViewNotifier', () {
    test('starts with the default view', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(tasksViewProvider), const TasksView());
    });

    test('setQuery / setSort / setShowDone / setGroupBy / setDueFilter', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(tasksViewProvider.notifier);

      notifier.setQuery('ship');
      expect(container.read(tasksViewProvider).query, 'ship');

      notifier.setSort(TasksSort.due);
      expect(container.read(tasksViewProvider).sort, TasksSort.due);

      notifier.setDueFilter(TasksDueFilter.overdue);
      expect(
        container.read(tasksViewProvider).dueFilter,
        TasksDueFilter.overdue,
      );

      notifier.setShowDone(false);
      expect(container.read(tasksViewProvider).showDone, isFalse);

      notifier.setGroupByStatus(false);
      expect(container.read(tasksViewProvider).groupByStatusFlag, isFalse);
    });

    test('togglePriority adds then removes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(tasksViewProvider.notifier);

      notifier.togglePriority(2);
      expect(container.read(tasksViewProvider).priorities, {2});

      notifier.togglePriority(2);
      expect(container.read(tasksViewProvider).priorities, isEmpty);
    });

    test('toggleStatusFilter adds then removes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(tasksViewProvider.notifier);

      notifier.toggleStatus(TaskStatus.doing);
      expect(container.read(tasksViewProvider).statusFilter, {TaskStatus.doing});

      notifier.toggleStatus(TaskStatus.doing);
      expect(container.read(tasksViewProvider).statusFilter, isEmpty);
    });
  });

  group('TasksView.copyWith', () {
    test('replaces and clears the priority set', () {
      const view = TasksView(priorities: {1, 2});
      expect(view.copyWith(priorities: {3}).priorities, {3});
      expect(view.copyWith(priorities: {}).priorities, isEmpty);
      expect(view.copyWith().priorities, {1, 2});
    });
  });

  group('TaskToolbar widgets', () {
    testWidgets('typing in the search box updates the view', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(_harness(container));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('task-search')), 'ship');
      await tester.pump();

      expect(container.read(tasksViewProvider).query, 'ship');
    });

    testWidgets('seeds the search field from the persisted query', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(tasksViewProvider.notifier).setQuery('ship');

      await tester.pumpWidget(_harness(container));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const Key('task-search')),
      );
      expect(field.controller?.text, 'ship');
      expect(find.text('ship'), findsOneWidget);
    });

    testWidgets(
      'keeps the typed query visible after the toolbar is rebuilt',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await tester.pumpWidget(_harness(container));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('task-search')), 'ship');
        await tester.pump();
        expect(container.read(tasksViewProvider).query, 'ship');

        // Simulate leaving and returning to the project: the toolbar is
        // disposed and rebuilt against the same (non-autoDispose) provider.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.pumpWidget(_harness(container));
        await tester.pumpAndSettle();

        expect(find.text('ship'), findsOneWidget);
      },
    );

    testWidgets('clears the field when the query is cleared externally', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(_harness(container));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('task-search')), 'ship');
      await tester.pump();
      expect(find.text('ship'), findsOneWidget);

      container.read(tasksViewProvider.notifier).setQuery('');
      await tester.pump();

      final field = tester.widget<TextField>(
        find.byKey(const Key('task-search')),
      );
      expect(field.controller?.text, isEmpty);
      expect(find.text('ship'), findsNothing);
    });

    testWidgets('tapping a priority chip toggles it', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(_harness(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('task-priority-filter-3')));
      await tester.pumpAndSettle();

      expect(container.read(tasksViewProvider).priorities, {3});
    });

    testWidgets('tapping a due chip sets the due filter', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(_harness(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('task-due-overdue')));
      await tester.pumpAndSettle();

      expect(
        container.read(tasksViewProvider).dueFilter,
        TasksDueFilter.overdue,
      );
    });

    testWidgets('show-done switch updates the view', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(_harness(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('task-show-done')));
      await tester.pumpAndSettle();

      expect(container.read(tasksViewProvider).showDone, isFalse);
    });

    testWidgets('sort menu shows every TasksSort option', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(_harness(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('task-sort')));
      await tester.pumpAndSettle();

      expect(find.text(Strings.tasksSortManual), findsOneWidget);
      expect(find.text(Strings.tasksSortUpdated), findsOneWidget);
    });
  });
}

Widget _harness(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: TaskToolbar()),
  ),
);
