import 'package:altidial/app/theme/app_theme.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/task_status.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/features/projects/model/task_board.dart';
import 'package:altidial/features/projects/providers.dart';
import 'package:altidial/features/projects/widgets/task_board.dart';
import 'package:altidial/features/projects/widgets/task_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_task_repository.dart';

TaskRow task({
  int id = 1,
  String title = 'A',
  int status = 0,
  int priority = 0,
  int sortOrder = 0,
  DateTime? due,
  int? estimate,
  DateTime? createdAt,
  DateTime? updatedAt,
}) => TaskRow(
  id: id,
  projectId: 1,
  title: title,
  notes: null,
  boardStatus: status,
  priority: priority,
  estimateMinutes: estimate,
  dueDate: due,
  plannedDate: null,
  sortOrder: sortOrder,
  blockedReason: null,
  createdAt: createdAt ?? DateTime(2026, 10, 1),
  updatedAt: updatedAt ?? createdAt ?? DateTime(2026, 10, 1),
  completedAt: status == 4 ? DateTime(2026, 10, 2) : null,
);

void main() {
  test('manual sort uses sortOrder then id', () {
    final a = task(id: 2, sortOrder: 1);
    final b = task(id: 1, sortOrder: 2);
    expect(compareTasks(a, b, TasksSort.manual), lessThan(0));
  });

  test('due sort puts nulls last, then earliest first', () {
    final none = task(id: 1);
    final soon = task(id: 2, due: DateTime(2026, 10, 5));
    final later = task(id: 3, due: DateTime(2026, 10, 9));
    final list = [none, later, soon]..sort((a, b) => compareTasks(a, b, TasksSort.due));
    expect(list.map((t) => t.id), [2, 3, 1]);
  });

  test('title sort is case-insensitive then id', () {
    final a = task(id: 2, title: 'beta');
    final b = task(id: 1, title: 'Alpha');
    expect(compareTasks(a, b, TasksSort.title), greaterThan(0));
    expect(compareTasks(b, a, TasksSort.title), lessThan(0));
    final tie = task(id: 2, title: 'alpha');
    expect(compareTasks(b, tie, TasksSort.title), lessThan(0));
  });

  test('priority sort puts higher priority first then id', () {
    final low = task(id: 1, priority: 1);
    final high = task(id: 2, priority: 5);
    final list = [low, high]..sort((a, b) => compareTasks(a, b, TasksSort.priority));
    expect(list.map((t) => t.id), [2, 1]);
    final tie = task(id: 0, priority: 5);
    expect(compareTasks(high, tie, TasksSort.priority), greaterThan(0));
  });

  test('created sort puts newest first then id', () {
    final old = task(id: 1, createdAt: DateTime(2026, 10, 1));
    final recent = task(id: 2, createdAt: DateTime(2026, 10, 5));
    final list = [old, recent]..sort((a, b) => compareTasks(a, b, TasksSort.created));
    expect(list.map((t) => t.id), [2, 1]);
  });

  test('estimate sort puts nulls last, then smallest first', () {
    final none = task(id: 1, estimate: null);
    final small = task(id: 2, estimate: 15);
    final big = task(id: 3, estimate: 60000);
    final list = [none, big, small]
      ..sort((a, b) => compareTasks(a, b, TasksSort.estimate));
    expect(list.map((t) => t.id), [2, 3, 1]);
    expect(compareTasks(none, small, TasksSort.estimate), greaterThan(0));
    expect(compareTasks(small, none, TasksSort.estimate), lessThan(0));
  });

  test('updated sort puts newest first then id', () {
    final old = task(id: 1, updatedAt: DateTime(2026, 10, 1));
    final recent = task(id: 2, updatedAt: DateTime(2026, 10, 8));
    final list = [old, recent]..sort((a, b) => compareTasks(a, b, TasksSort.updated));
    expect(list.map((t) => t.id), [2, 1]);
  });

  test('groupByStatus buckets by board status', () {
    final grouped = groupByStatus([
      task(id: 1, status: 0),
      task(id: 2, status: 4),
      task(id: 3, status: 0),
    ]);
    expect(grouped[TaskStatus.backlog]!.map((t) => t.id), [1, 3]);
    expect(grouped[TaskStatus.done]!.map((t) => t.id), [2]);
    expect(grouped[TaskStatus.doing], isEmpty);
  });

  test('validation ranges', () {
    expect(validateTaskTitle(''), isNotNull);
    expect(validateTaskTitle('x' * 121), isNotNull);
    expect(validateTaskTitle('Ship it'), isNull);
    expect(validateTaskNotes('x' * 2001), isNotNull);
    expect(validateTaskEstimate(10), isNotNull); // below 15
    expect(validateTaskEstimate(90), isNull);
    expect(validateTaskEstimate(null), isNull);
  });

  test('validation boundaries', () {
    expect(validateTaskTitle('x' * 120), isNull);
    expect(validateTaskTitle('x' * 121), isNotNull);
    expect(validateTaskTitle('   '), isNotNull);
    expect(validateTaskNotes('x' * 2000), isNull);
    expect(validateTaskEstimate(15), isNull);
    expect(validateTaskEstimate(60000), isNull);
  });

  group('TaskBoard widgets', () {
    testWidgets('board shows columns and adds a task', (tester) async {
      final repo = FakeTaskRepository();
      addTearDown(repo.dispose);
      await tester.pumpWidget(_harness(repo, const TaskBoard(projectId: 1)));
      await tester.pumpAndSettle();
      for (final label in Strings.tasksStatusLabels) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.enterText(
        find.byKey(const Key('task-add-backlog')),
        'Ship v1',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Ship v1'), findsOneWidget);
      expect(repo.rows.single.boardStatus, TaskStatus.backlog.dbIndex);
    });

    testWidgets('adding in a column lands the task in that column', (
      tester,
    ) async {
      final repo = FakeTaskRepository();
      addTearDown(repo.dispose);
      await tester.pumpWidget(_harness(repo, const TaskBoard(projectId: 1)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('task-add-doing')), 'Ship v1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(repo.rows.single.boardStatus, TaskStatus.doing.dbIndex);
    });

    testWidgets('dragging a card moves it to another column', (tester) async {
      final repo = FakeTaskRepository([
        task(id: 1, title: 'Ship v1', status: TaskStatus.todo.dbIndex),
      ]);
      addTearDown(repo.dispose);
      await tester.pumpWidget(_harness(repo, const TaskBoard(projectId: 1)));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Ship v1')),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.moveTo(
        tester.getCenter(find.byKey(const Key('task-drop-doing'))),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(repo.rows.single.boardStatus, TaskStatus.doing.dbIndex);
    });

    testWidgets('list renders tasks and the empty state', (tester) async {
      final repo = FakeTaskRepository();
      addTearDown(repo.dispose);
      await tester.pumpWidget(_harness(repo, const TaskList(projectId: 1)));
      await tester.pumpAndSettle();
      expect(find.text(Strings.tasksEmpty), findsOneWidget);

      await repo.create(1, 'Ship v1');
      await tester.pumpAndSettle();
      expect(find.text('Ship v1'), findsOneWidget);
      expect(find.text(Strings.tasksEmpty), findsNothing);
    });

    testWidgets('tapping a card opens the task editor', (tester) async {
      final repo = FakeTaskRepository([
        task(id: 1, title: 'Ship v1', status: TaskStatus.todo.dbIndex),
      ]);
      addTearDown(repo.dispose);
      await tester.pumpWidget(_harness(repo, const TaskBoard(projectId: 1)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ship v1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('task-title')), findsOneWidget);
    });
  });
}

Widget _harness(FakeTaskRepository repo, Widget child) => ProviderScope(
  overrides: [tasksRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  ),
);
