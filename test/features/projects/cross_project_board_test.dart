import 'package:altidial/app/theme/app_theme.dart';
import 'package:altidial/core/task_status.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/repositories/project_repository.dart';
import 'package:altidial/features/projects/providers.dart';
import 'package:altidial/features/projects/widgets/cross_project_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_task_repository.dart';

class _FakeProjects implements ProjectRepository {
  _FakeProjects(this.rows);
  final List<ProjectRow> rows;

  @override
  Stream<List<ProjectRow>> watchProjects() => Stream.value(rows);

  @override
  Stream<ProjectDetail> watchDetail(int id) => throw UnimplementedError();

  @override
  Future<int> create(String title) => throw UnimplementedError();
  @override
  Future<void> updateTitle(int id, String title) => throw UnimplementedError();
  @override
  Future<void> updateNotes(int id, String? notes) => throw UnimplementedError();
  @override
  Future<void> updatePriority(int id, int priority) =>
      throw UnimplementedError();
  @override
  Future<void> updateDeadline(int id, DateTime? deadline) =>
      throw UnimplementedError();
  @override
  Future<void> updateTarget(int id, int? targetMinutes) =>
      throw UnimplementedError();
  @override
  Future<void> updateAffinity(int id, int? toneIndex) =>
      throw UnimplementedError();
  @override
  Future<void> complete(int id) => throw UnimplementedError();
  @override
  Future<void> reopen(int id) => throw UnimplementedError();
  @override
  Future<void> archive(int id) => throw UnimplementedError();
  @override
  Future<void> unarchive(int id) => throw UnimplementedError();
  @override
  Future<void> deleteAndUnlink(int id) => throw UnimplementedError();
}

ProjectRow _project() => ProjectRow(
  id: 1,
  title: 'Alpha',
  createdAt: DateTime(2026, 10, 14),
  targetMinutes: 60,
  status: 0,
  priority: 0,
);

TaskRow _task() => TaskRow(
  id: 1,
  projectId: 1,
  title: 'Ship v1',
  notes: null,
  boardStatus: TaskStatus.todo.dbIndex,
  priority: 0,
  estimateMinutes: null,
  dueDate: null,
  plannedDate: null,
  sortOrder: 0,
  blockedReason: null,
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
  completedAt: null,
);

void main() {
  testWidgets('dragging a card moves it to another column', (tester) async {
    final projects = _FakeProjects([_project()]);
    final tasks = FakeTaskRepository([_task()]);
    addTearDown(tasks.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsRepositoryProvider.overrideWithValue(projects),
          tasksRepositoryProvider.overrideWithValue(tasks),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: CrossProjectBoard(onOpenDay: (_) {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Ship v1')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.moveTo(
      tester.getCenter(find.byKey(const Key('cross-task-drop-doing'))),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tasks.rows.single.boardStatus, TaskStatus.doing.dbIndex);
  });
}
