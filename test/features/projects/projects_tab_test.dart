import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/task_status.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/project_repository.dart';
import 'package:energy_clock/features/projects/projects_screen.dart';
import 'package:energy_clock/features/projects/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_task_repository.dart';

class _FakeProjectRepository implements ProjectRepository {
  _FakeProjectRepository({this.rows = const []});

  final List<ProjectRow> rows;

  @override
  Stream<List<ProjectRow>> watchProjects() => Stream.value(rows);

  @override
  Stream<ProjectDetail> watchDetail(int id) {
    final row = rows.singleWhere((r) => r.id == id);
    return Stream.value(
      ProjectDetail(
        project: row,
        events: const [],
        plannedMinutes: 0,
        actualMinutes: 0,
      ),
    );
  }

  @override
  Future<int> create(String title) => throw UnimplementedError();

  @override
  Future<void> updateTitle(int id, String title) => throw UnimplementedError();

  @override
  Future<void> updateNotes(int id, String? notes) => throw UnimplementedError();

  @override
  Future<void> updatePriority(int id, int priority) => throw UnimplementedError();

  @override
  Future<void> updateDeadline(int id, DateTime? deadline) => throw UnimplementedError();

  @override
  Future<void> updateTarget(int id, int? targetMinutes) => throw UnimplementedError();

  @override
  Future<void> updateAffinity(int id, int? toneIndex) => throw UnimplementedError();

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

void main() {
  testWidgets('projects tab renders without nested AppBar', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsRepositoryProvider.overrideWithValue(_FakeProjectRepository()),
          projectListProvider.overrideWith((ref) => _FakeProjectRepository().watchProjects()),
        ],
        child: const MaterialApp(home: ProjectsTabBody(onOpenDay: _noop)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(Strings.projectsTitle), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('projects tab hub shows search and filters', (tester) async {
    final row = ProjectRow(
      id: 1,
      title: 'Alpha',
      createdAt: DateTime(2026, 10, 14),
      targetMinutes: 60,
      status: 0,
      priority: 0,
    );
    final fake = _FakeProjectRepository(rows: [row]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsRepositoryProvider.overrideWithValue(fake),
          projectListProvider.overrideWith((ref) => fake.watchProjects()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: ProjectsTabBody(onOpenDay: _noop)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(Strings.projectsSearchHint), findsOneWidget);
    expect(find.text(Strings.projectsFilterAll), findsOneWidget);
    expect(find.text(Strings.projectsFilterOverdue), findsOneWidget);
  });

  testWidgets('projects tab switches between Outcomes, Board and Today', (
    tester,
  ) async {
    final projects = _FakeProjectRepository(rows: [_project(1, 'Alpha')]);
    final tasks = FakeTaskRepository();
    addTearDown(tasks.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsRepositoryProvider.overrideWithValue(projects),
          projectListProvider.overrideWith((ref) => projects.watchProjects()),
          tasksRepositoryProvider.overrideWithValue(tasks),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: ProjectsTabBody(onOpenDay: _noop)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Outcomes is the default surface: the hub search field is visible.
    expect(find.text(Strings.projectsSearchHint), findsOneWidget);

    // Board: the project filter chip row appears (All + one per project).
    await tester.tap(find.text(Strings.projectsSurfaceBoard));
    await tester.pumpAndSettle();
    expect(find.text(Strings.projectsFilterAll), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);

    // Today: empty state when nothing is planned.
    await tester.tap(find.text(Strings.projectsSurfaceToday));
    await tester.pumpAndSettle();
    expect(find.text(Strings.todayEmpty), findsOneWidget);
  });

  testWidgets('cross-project board labels cards with their project', (
    tester,
  ) async {
    final projects = _FakeProjectRepository(rows: [_project(1, 'Alpha')]);
    final tasks = FakeTaskRepository([
      _task(id: 1, title: 'Ship v1', status: TaskStatus.todo.dbIndex),
    ]);
    addTearDown(tasks.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsRepositoryProvider.overrideWithValue(projects),
          projectListProvider.overrideWith((ref) => projects.watchProjects()),
          tasksRepositoryProvider.overrideWithValue(tasks),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: ProjectsTabBody(onOpenDay: _noop)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(Strings.projectsSurfaceBoard));
    await tester.pumpAndSettle();

    expect(find.text('Ship v1'), findsOneWidget);
    expect(find.text(Strings.projectsTaskProject('Alpha')), findsOneWidget);

    // Tapping a card opens the shared task editor.
    await tester.tap(find.text('Ship v1'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task-title')), findsOneWidget);
  });

  testWidgets('today view shows planned tasks and hides done by default', (
    tester,
  ) async {
    final projects = _FakeProjectRepository(rows: [_project(1, 'Alpha')]);
    final tasks = FakeTaskRepository([
      _task(
        id: 1,
        title: 'Planned now',
        status: TaskStatus.todo.dbIndex,
        plannedDate: DateTime.now(),
      ),
      _task(
        id: 2,
        title: 'Planned done',
        status: TaskStatus.done.dbIndex,
        plannedDate: DateTime.now(),
      ),
      // Unknown project: grouped under the "No project" header, not dropped.
      _task(
        id: 3,
        title: 'Orphan task',
        status: TaskStatus.todo.dbIndex,
        projectId: 99,
        plannedDate: DateTime.now(),
      ),
    ]);
    addTearDown(tasks.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsRepositoryProvider.overrideWithValue(projects),
          projectListProvider.overrideWith((ref) => projects.watchProjects()),
          tasksRepositoryProvider.overrideWithValue(tasks),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: ProjectsTabBody(onOpenDay: _noop)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(Strings.projectsSurfaceToday));
    await tester.pumpAndSettle();

    expect(find.text('Planned now'), findsOneWidget);
    expect(find.text('Planned done'), findsNothing);
    expect(find.text('Orphan task'), findsOneWidget);
    expect(find.text(Strings.projectNone), findsOneWidget);
  });

  testWidgets('cross-project board filter works and ignores per-project query', (
    tester,
  ) async {
    final projects = _FakeProjectRepository(
      rows: [_project(1, 'Alpha'), _project(2, 'Beta')],
    );
    final tasks = FakeTaskRepository([
      _task(id: 1, title: 'Alpha task', status: TaskStatus.todo.dbIndex),
      _task(
        id: 2,
        title: 'Beta task',
        status: TaskStatus.todo.dbIndex,
        projectId: 2,
      ),
    ]);
    addTearDown(tasks.dispose);
    final container = ProviderContainer(
      overrides: [
        projectsRepositoryProvider.overrideWithValue(projects),
        projectListProvider.overrideWith((ref) => projects.watchProjects()),
        tasksRepositoryProvider.overrideWithValue(tasks),
      ],
    );
    addTearDown(container.dispose);
    // A per-project toolbar query must not leak into the cross-project board.
    container.read(tasksViewProvider.notifier).setQuery('no-match-query');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: ProjectsTabBody(onOpenDay: _noop)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(Strings.projectsSurfaceBoard));
    await tester.pumpAndSettle();

    // Independent of the per-project query: both tasks still show.
    expect(find.text('Alpha task'), findsOneWidget);
    expect(find.text('Beta task'), findsOneWidget);

    // The board's own project filter narrows to the chosen project.
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    expect(find.text('Alpha task'), findsOneWidget);
    expect(find.text('Beta task'), findsNothing);
  });
}

ProjectRow _project(int id, String title) => ProjectRow(
  id: id,
  title: title,
  createdAt: DateTime(2026, 10, 14),
  targetMinutes: 60,
  status: 0,
  priority: 0,
);

TaskRow _task({
  required int id,
  required String title,
  required int status,
  int projectId = 1,
  DateTime? plannedDate,
}) => TaskRow(
  id: id,
  projectId: projectId,
  title: title,
  notes: null,
  boardStatus: status,
  priority: 0,
  estimateMinutes: null,
  dueDate: null,
  plannedDate: plannedDate,
  sortOrder: 0,
  blockedReason: null,
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
  completedAt: null,
);

void _noop(DateTime _) {}