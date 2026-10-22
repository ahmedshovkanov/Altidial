import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/task_status.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/features/projects/providers.dart';
import 'package:energy_clock/features/projects/widgets/task_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_task_repository.dart';

TaskRow task({
  int id = 1,
  String title = 'Old',
  int status = 1,
  int priority = 0,
  int? estimate,
  DateTime? due,
  DateTime? planned,
  String? notes,
}) => TaskRow(
  id: id,
  projectId: 1,
  title: title,
  notes: notes,
  boardStatus: status,
  priority: priority,
  estimateMinutes: estimate,
  dueDate: due,
  plannedDate: planned,
  sortOrder: 0,
  blockedReason: null,
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
  completedAt: null,
);

Widget _harness(FakeTaskRepository repo, Widget child) => ProviderScope(
  overrides: [tasksRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  ),
);

/// Pumps a screen with an "open" button that launches the editor for task [id],
/// then taps it. Grows the test surface so every section is on screen.
Future<void> _openEditor(WidgetTester tester, FakeTaskRepository repo) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    _harness(
      repo,
      Consumer(
        builder: (context, ref, _) => FilledButton(
          onPressed: () => showTaskEditor(
            context,
            ref,
            task: repo.rows.first,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('editor saves title, priority, estimate hours, and due chip', (
    tester,
  ) async {
    final repo = FakeTaskRepository([task()]);
    addTearDown(repo.dispose);
    await _openEditor(tester, repo);

    await tester.enterText(find.byKey(const Key('task-title')), 'New');
    await tester.tap(find.text(Strings.tasksPriorityLabels[2]));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('task-estimate')), '1.5');
    await tester.tap(find.byKey(const Key('task-due-today')));
    await tester.pump();
    await tester.tap(find.text(Strings.save));
    await tester.pumpAndSettle();

    final row = repo.rows.single;
    expect(row.title, 'New');
    expect(row.priority, 2);
    expect(row.estimateMinutes, 90);
    expect(row.dueDate, isNotNull);
  });

  testWidgets('editor saves notes', (tester) async {
    final repo = FakeTaskRepository([task()]);
    addTearDown(repo.dispose);
    await _openEditor(tester, repo);

    await tester.enterText(find.byKey(const Key('task-notes')), 'Next steps');
    await tester.tap(find.text(Strings.save));
    await tester.pumpAndSettle();

    expect(repo.rows.single.notes, 'Next steps');
  });

  testWidgets('blank notes become null', (tester) async {
    final repo = FakeTaskRepository([task(notes: 'Old notes')]);
    addTearDown(repo.dispose);
    await _openEditor(tester, repo);

    await tester.enterText(find.byKey(const Key('task-notes')), '   ');
    await tester.tap(find.text(Strings.save));
    await tester.pumpAndSettle();

    expect(repo.rows.single.notes, isNull);
  });

  testWidgets('controller seeds the estimate field from stored minutes', (
    tester,
  ) async {
    final repo = FakeTaskRepository([task(estimate: 90)]);
    addTearDown(repo.dispose);
    await _openEditor(tester, repo);

    expect(find.text('1.5'), findsOneWidget);
  });

  testWidgets('status chips move the task immediately', (tester) async {
    final repo = FakeTaskRepository([task()]);
    addTearDown(repo.dispose);
    await _openEditor(tester, repo);

    await tester.tap(find.byKey(const Key('task-status-doing')));
    await tester.pumpAndSettle();

    expect(repo.rows.single.boardStatus, TaskStatus.doing.dbIndex);
  });

  testWidgets('planned chip sets the planned date', (tester) async {
    final repo = FakeTaskRepository([task()]);
    addTearDown(repo.dispose);
    await _openEditor(tester, repo);

    await tester.tap(find.byKey(const Key('task-planned-tomorrow')));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    expect(
      repo.rows.single.plannedDate,
      DateTime(now.year, now.month, now.day + 1),
    );
  });

  testWidgets('an out-of-range estimate blocks the save', (tester) async {
    final repo = FakeTaskRepository([task()]);
    addTearDown(repo.dispose);
    await _openEditor(tester, repo);

    await tester.enterText(find.byKey(const Key('task-estimate')), '0.1');
    await tester.tap(find.text(Strings.save));
    await tester.pumpAndSettle();

    expect(find.text(Strings.tasksEstimateRange), findsOneWidget);
    expect(repo.rows.single.title, 'Old');
  });

  testWidgets('delete confirms then removes the task', (tester) async {
    final repo = FakeTaskRepository([task()]);
    addTearDown(repo.dispose);
    await _openEditor(tester, repo);

    await tester.tap(find.text(Strings.projectsDelete));
    await tester.pumpAndSettle();
    expect(find.text(Strings.tasksDeleteTitle), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(Strings.projectsDelete),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.rows, isEmpty);
  });
}
