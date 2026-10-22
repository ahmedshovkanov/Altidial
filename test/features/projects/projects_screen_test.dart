import 'dart:async';

import 'package:altidial/app/theme/app_theme.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/repositories/project_repository.dart';
import 'package:altidial/features/projects/projects_screen.dart';
import 'package:altidial/features/projects/providers.dart';
import 'package:altidial/features/projects/widgets/project_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProjectRow _project(
  int id,
  String title, {
  int status = 0,
  int? targetMinutes,
  DateTime? deadline,
  int? toneIndex,
  int priority = 0,
  DateTime? completedAt,
}) => ProjectRow(
  id: id,
  title: title,
  createdAt: DateTime(2026, 10, 14),
  deadline: deadline,
  targetMinutes: targetMinutes,
  toneIndex: toneIndex,
  status: status,
  completedAt: completedAt,
  priority: priority,
);

EventRow _event(int id, int projectId, DateTime date) => EventRow(
  id: id,
  seriesId: null,
  date: date,
  title: 'Session work $id',
  toneIndex: 0,
  startMinute: 600,
  endMinute: 660,
  status: 0,
  isFlight: false,
  flightNumber: null,
  fromCode: null,
  toCode: null,
  projectId: projectId,
  createdAt: DateTime(2026, 10, 14),
  updatedAt: DateTime(2026, 10, 14),
);

ProjectDetail _detail(
  ProjectRow project, {
  List<EventRow> events = const [],
  int plannedMinutes = 0,
  int actualMinutes = 0,
  int sessionsCount = 0,
  DateTime? lastWorkedAt,
}) => ProjectDetail(
  project: project,
  events: events,
  plannedMinutes: plannedMinutes,
  actualMinutes: actualMinutes,
  sessionsCount: sessionsCount,
  lastWorkedAt: lastWorkedAt,
);

class _RecordingProjectRepository implements ProjectRepository {
  _RecordingProjectRepository({
    List<ProjectRow>? rows,
    Map<int, ProjectDetail>? details,
  }) : rows = rows ?? [],
       details = details ?? {};

  final List<ProjectRow> rows;
  final Map<int, ProjectDetail> details;
  final List<int> completed = [];
  final List<int> reopened = [];
  final List<int> archived = [];
  final List<int> unarchived = [];
  final List<int> deleted = [];
  final List<int> clearedDeadlines = [];

  @override
  Stream<List<ProjectRow>> watchProjects() => Stream.value(rows);

  @override
  Stream<ProjectDetail> watchDetail(int id) {
    final detail = details[id];
    if (detail == null) return Stream.error(StateError('no project $id'));
    return Stream.value(detail);
  }

  @override
  Future<int> create(String title) async {
    const id = 999;
    final row = _project(id, title);
    rows.add(row);
    details[id] = _detail(row);
    return id;
  }

  @override
  Future<void> updateTitle(int id, String title) async {}

  @override
  Future<void> updateNotes(int id, String? notes) async {}

  @override
  Future<void> updatePriority(int id, int priority) async {}

  @override
  Future<void> updateDeadline(int id, DateTime? deadline) async {
    if (deadline == null) clearedDeadlines.add(id);
  }

  @override
  Future<void> updateTarget(int id, int? targetMinutes) async {}

  @override
  Future<void> updateAffinity(int id, int? toneIndex) async {}

  @override
  Future<void> complete(int id) async {
    completed.add(id);
  }

  @override
  Future<void> reopen(int id) async {
    reopened.add(id);
  }

  @override
  Future<void> archive(int id) async {
    archived.add(id);
  }

  @override
  Future<void> unarchive(int id) async {
    unarchived.add(id);
  }

  @override
  Future<void> deleteAndUnlink(int id) async {
    deleted.add(id);
  }
}

Widget _hubHost(
  _RecordingProjectRepository fake, {
  ValueChanged<DateTime>? onOpenDay,
}) {
  final detailOverrides = [
    for (final row in fake.rows)
      if (fake.details.containsKey(row.id))
        projectDetailProvider(
          row.id,
        ).overrideWith((ref) => Stream.value(fake.details[row.id]!)),
  ];
  return ProviderScope(
    overrides: [
      projectsRepositoryProvider.overrideWithValue(fake),
      projectListProvider.overrideWith((ref) => fake.watchProjects()),
      ...detailOverrides,
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: ProjectsScreen(onOpenDay: onOpenDay ?? (_) {})),
    ),
  );
}

Widget _detailHost(_RecordingProjectRepository fake, int projectId) =>
    ProviderScope(
      overrides: [
        projectsRepositoryProvider.overrideWithValue(fake),
        projectDetailProvider(
          projectId,
        ).overrideWith((ref) => fake.watchDetail(projectId)),
        taskListProvider(
          projectId,
        ).overrideWith((ref) => Stream.value(const <TaskRow>[])),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ProjectDetailView(
            projectId: projectId,
            onOpenDay: (_) {},
          ),
        ),
      ),
    );

void main() {
  testWidgets('hub groups active and completed and shows empty state', (
    tester,
  ) async {
    final active = _project(1, 'Alpha', targetMinutes: 120);
    final ready = _project(2, 'Beta', targetMinutes: 60);
    final done = _project(3, 'Done', status: 1);
    final fake = _RecordingProjectRepository(
      rows: [active, ready, done],
      details: {
        1: _detail(active, plannedMinutes: 120, actualMinutes: 30),
        2: _detail(ready, plannedMinutes: 60, actualMinutes: 90),
        3: _detail(done, plannedMinutes: 60, actualMinutes: 60),
      },
    );
    await tester.pumpWidget(_hubHost(fake));
    await tester.pumpAndSettle();

    // Active vs ready-to-complete sections.
    expect(find.text(Strings.projectsActive), findsOneWidget);
    expect(find.text(Strings.projectsReady), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    // Completed projects show in their own expanded section.
    expect(find.text(Strings.projectsCompleted), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('hub search filters and sort menu orders by deadline', (
    tester,
  ) async {
    final now = DateTime.now();
    final late = _project(
      1,
      'Alpha',
      targetMinutes: 120,
      deadline: now.add(const Duration(days: 9)),
    );
    final early = _project(
      2,
      'Beta',
      targetMinutes: 120,
      deadline: now.add(const Duration(days: 1)),
    );
    final other = _project(3, 'Gamma', targetMinutes: 120);
    final fake = _RecordingProjectRepository(
      rows: [late, early, other],
      details: {
        1: _detail(late, plannedMinutes: 60, actualMinutes: 10),
        2: _detail(early, plannedMinutes: 60, actualMinutes: 10),
        3: _detail(other, plannedMinutes: 60, actualMinutes: 10),
      },
    );
    await tester.pumpWidget(_hubHost(fake));
    await tester.pumpAndSettle();

    // Search narrows to the matching project.
    await tester.enterText(find.byType(TextField), 'beta');
    await tester.pumpAndSettle();
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
    expect(find.text('Gamma'), findsNothing);

    // Clear search, sort by Deadline → earliest deadline first.
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.projectsSortDeadline));
    await tester.pumpAndSettle();
    final betaY = tester.getTopLeft(find.text('Beta')).dy;
    final alphaY = tester.getTopLeft(find.text('Alpha')).dy;
    expect(betaY, lessThan(alphaY));
  });

  testWidgets('hub overdue chip shows only overdue projects', (tester) async {
    final now = DateTime.now();
    final overdue = _project(
      1,
      'Late',
      targetMinutes: 60,
      deadline: now.subtract(const Duration(days: 2)),
    );
    final upcoming = _project(
      2,
      'Soon',
      targetMinutes: 60,
      deadline: now.add(const Duration(days: 2)),
    );
    final fake = _RecordingProjectRepository(
      rows: [overdue, upcoming],
      details: {
        1: _detail(overdue, plannedMinutes: 60, actualMinutes: 10),
        2: _detail(upcoming, plannedMinutes: 60, actualMinutes: 10),
      },
    );
    await tester.pumpWidget(_hubHost(fake));
    await tester.pumpAndSettle();

    expect(find.text('Late'), findsOneWidget);
    expect(find.text('Soon'), findsOneWidget);
    await tester.tap(find.text(Strings.projectsFilterOverdue));
    await tester.pumpAndSettle();
    expect(find.text('Late'), findsOneWidget);
    expect(find.text('Soon'), findsNothing);
  });

  testWidgets('hub splits completed and archived sections', (tester) async {
    final now = DateTime.now();
    final done = _project(1, 'Shipped', status: 1, completedAt: now);
    final filed = _project(2, 'Filed', status: 2, completedAt: now);
    final fake = _RecordingProjectRepository(
      rows: [done, filed],
      details: {1: _detail(done), 2: _detail(filed)},
    );
    await tester.pumpWidget(_hubHost(fake));
    await tester.pumpAndSettle();

    // Completed is expanded; archived hides behind a collapsed section.
    expect(find.text(Strings.projectsCompleted), findsOneWidget);
    expect(find.text('Shipped'), findsOneWidget);
    expect(find.text(Strings.projectsArchived), findsOneWidget);
    expect(find.text('Filed'), findsNothing);
    await tester.tap(find.text(Strings.projectsArchived));
    await tester.pumpAndSettle();
    expect(find.text('Filed'), findsOneWidget);
  });

  testWidgets('hub shows no-match when filters exclude everything', (
    tester,
  ) async {
    final project = _project(1, 'Alpha', targetMinutes: 60);
    final fake = _RecordingProjectRepository(
      rows: [project],
      details: {1: _detail(project)},
    );
    await tester.pumpWidget(_hubHost(fake));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text(Strings.projectsNoMatch), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
  });

  testWidgets('hub shows empty state when there are no projects', (
    tester,
  ) async {
    final fake = _RecordingProjectRepository();
    await tester.pumpWidget(_hubHost(fake));
    await tester.pumpAndSettle();

    expect(find.text(Strings.projectsEmptyTitle), findsOneWidget);
    expect(find.text(Strings.projectsEmptyHint), findsOneWidget);
  });

  testWidgets('hub shows error state with retry', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectListProvider.overrideWith(
            (ref) => Stream.error(Exception('boom')),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: ProjectsScreen(onOpenDay: (_) {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(Strings.projectsLoadError), findsOneWidget);
    expect(find.text(Strings.deckRetry), findsOneWidget);
  });

  testWidgets('detail shows progress and linked events open their day', (
    tester,
  ) async {
    final project = _project(1, 'Alpha', targetMinutes: 120);
    final day = DateTime(2026, 10, 20);
    final fake = _RecordingProjectRepository(
      rows: [project],
      details: {
        1: _detail(
          project,
          events: [_event(7, 1, day)],
          plannedMinutes: 60,
          actualMinutes: 30,
        ),
      },
    );
    DateTime? opened;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsRepositoryProvider.overrideWithValue(fake),
          projectDetailProvider(1).overrideWith((ref) => fake.watchDetail(1)),
          taskListProvider(1).overrideWith((ref) => Stream.value(const <TaskRow>[])),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ProjectDetailView(
              projectId: 1,
              onOpenDay: (d) => opened = d,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Session work 7'), findsOneWidget);

    // The richer detail scrolls; bring the event row on screen first.
    await tester.scrollUntilVisible(
      find.text('Session work 7'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Session work 7'));
    await tester.pumpAndSettle();
    expect(opened, DateTime(2026, 10, 20));
  });

  testWidgets('detail mark complete calls the repository', (tester) async {
    final project = _project(1, 'Alpha');
    final fake = _RecordingProjectRepository(
      rows: [project],
      details: {1: _detail(project)},
    );
    await tester.pumpWidget(_detailHost(fake, 1));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.projectsMarkComplete));
    await tester.pumpAndSettle();

    expect(fake.completed, [1]);
  });

  testWidgets('hub empty state creates a project and opens its detail', (
    tester,
  ) async {
    final fake = _RecordingProjectRepository();
    await tester.pumpWidget(_hubHost(fake));
    await tester.pumpAndSettle();

    expect(find.text(Strings.projectsEmptyTitle), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, Strings.projectNew));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Portfolio');
    await tester.pump();
    await tester.tap(find.text(Strings.save));
    await tester.pumpAndSettle();

    // Detail for the new project (id 999 from the fake) is pushed.
    expect(find.text('Portfolio'), findsWidgets);
  });

  testWidgets('detail write failure shows a snackbar', (tester) async {
    final project = _project(1, 'Alpha');
    final fake = _ThrowingProjectRepository(
      rows: [project],
      details: {1: _detail(project)},
    );
    await tester.pumpWidget(_detailHost(fake, 1));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.projectsMarkComplete));
    await tester.pumpAndSettle();

    expect(find.text(Strings.projectsSaveFailed), findsOneWidget);
  });

  testWidgets('deadline clear calls updateDeadline with null', (tester) async {
    final project = _project(
      1,
      'Alpha',
      deadline: DateTime(2026, 11, 1),
    );
    final fake = _RecordingProjectRepository(
      rows: [project],
      details: {1: _detail(project)},
    );
    await tester.pumpWidget(_detailHost(fake, 1));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(Strings.projectsDeadlineClear));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.projectsDeadlineClear));
    await tester.pumpAndSettle();

    expect(fake.clearedDeadlines, [1]);
  });

  testWidgets('detail error state offers retry', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectDetailProvider(
            1,
          ).overrideWith((ref) => Stream.error(Exception('boom'))),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ProjectDetailView(projectId: 1, onOpenDay: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(Strings.projectsLoadError), findsOneWidget);
    expect(find.text(Strings.deckRetry), findsOneWidget);
  });
}

class _ThrowingProjectRepository extends _RecordingProjectRepository {
  _ThrowingProjectRepository({
    super.rows,
    super.details,
  });

  @override
  Future<void> complete(int id) async {
    throw Exception('boom');
  }
}
