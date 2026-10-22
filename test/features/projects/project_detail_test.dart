import 'dart:async';

import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/task_status.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/project_repository.dart';
import 'package:energy_clock/features/projects/providers.dart';
import 'package:energy_clock/features/projects/widgets/project_detail.dart';
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
  String? notes,
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
  notes: notes,
);

EventRow _event(int id, int projectId, DateTime date) => EventRow(
  id: id,
  seriesId: null,
  date: date,
  title: 'Session work $id',
  toneIndex: 0,
  startMinute: 540,
  endMinute: 600,
  status: 0,
  isFlight: false,
  flightNumber: null,
  fromCode: null,
  toCode: null,
  projectId: projectId,
  createdAt: DateTime(2026, 10, 14),
  updatedAt: DateTime(2026, 10, 14),
);

SessionRow _doneSession(
  int id, {
  required int eventId,
  required DateTime day,
  required int minutes,
  int outcome = 1,
}) {
  final start = DateTime(day.year, day.month, day.day, 10);
  return SessionRow(
    id: id,
    eventId: eventId,
    startedAt: start,
    endedAt: start.add(Duration(minutes: minutes)),
    plannedSeconds: minutes * 60,
    pausedSeconds: 0,
    activeSeconds: minutes * 60,
    overtimeSeconds: 0,
    outcome: outcome,
  );
}

ProjectDetail _detail(
  ProjectRow project, {
  List<EventRow> events = const [],
  List<SessionRow> doneSessions = const [],
  int plannedMinutes = 0,
  int actualMinutes = 0,
}) => ProjectDetail(
  project: project,
  events: events,
  plannedMinutes: plannedMinutes,
  actualMinutes: actualMinutes,
  doneSessions: doneSessions,
);

TaskRow _task(int id, int status) => TaskRow(
  id: id,
  projectId: 1,
  title: 'Task $id',
  notes: null,
  boardStatus: status,
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

class _FakeProjects implements ProjectRepository {
  _FakeProjects({Map<int, ProjectDetail>? details}) : details = details ?? {};

  final Map<int, ProjectDetail> details;
  final Map<int, String> titles = {};
  final Map<int, String?> notesUpdates = {};
  final Map<int, int> priorities = {};
  final Map<int, DateTime?> deadlineUpdates = {};
  final Map<int, int?> targets = {};
  final List<int> completed = [];
  final List<int> reopened = [];
  final List<int> archived = [];
  final List<int> unarchived = [];
  final List<int> deleted = [];

  @override
  Stream<List<ProjectRow>> watchProjects() => Stream.value(
    details.values.map((detail) => detail.project).toList(),
  );

  @override
  Stream<ProjectDetail> watchDetail(int id) {
    final detail = details[id];
    if (detail == null) return Stream.error(StateError('no project $id'));
    return Stream.value(detail);
  }

  @override
  Future<int> create(String title) async => 999;

  @override
  Future<void> updateTitle(int id, String title) async {
    titles[id] = title;
  }

  @override
  Future<void> updateNotes(int id, String? notes) async {
    notesUpdates[id] = notes;
  }

  @override
  Future<void> updatePriority(int id, int priority) async {
    priorities[id] = priority;
  }

  @override
  Future<void> updateDeadline(int id, DateTime? deadline) async {
    deadlineUpdates[id] = deadline;
  }

  @override
  Future<void> updateTarget(int id, int? targetMinutes) async {
    targets[id] = targetMinutes;
  }

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

Widget _detailHost(
  _FakeProjects fake,
  int projectId, {
  List<TaskRow> tasks = const [],
}) => ProviderScope(
  overrides: [
    projectsRepositoryProvider.overrideWithValue(fake),
    projectDetailProvider(
      projectId,
    ).overrideWith((ref) => fake.watchDetail(projectId)),
    taskListProvider(
      projectId,
    ).overrideWith((ref) => Stream.value(tasks)),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: ProjectDetailView(projectId: projectId, onOpenDay: (_) {}),
    ),
  ),
);

DateTime _day(DateTime dateTime) =>
    DateTime(dateTime.year, dateTime.month, dateTime.day);

void main() {
  testWidgets('title tap renames via the rename dialog', (tester) async {
    final project = _project(1, 'Alpha');
    final fake = _FakeProjects(details: {1: _detail(project)});
    await tester.pumpWidget(_detailHost(fake, 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    expect(find.text(Strings.projectsRenameTitle), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Beta',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, Strings.save));
    await tester.pumpAndSettle();

    expect(fake.titles[1], 'Beta');
  });

  testWidgets('rename save stays disabled until the title is valid', (
    tester,
  ) async {
    final project = _project(1, 'Alpha');
    final fake = _FakeProjects(details: {1: _detail(project)});
    await tester.pumpWidget(_detailHost(fake, 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();

    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogField, '');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, Strings.save)).onPressed,
      isNull,
    );

    await tester.enterText(dialogField, 'Beta');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, Strings.save)).onPressed,
      isNotNull,
    );
  });

  testWidgets('notes save records the note with a live counter', (tester) async {
    final project = _project(1, 'Alpha');
    final fake = _FakeProjects(details: {1: _detail(project)});
    await tester.pumpWidget(_detailHost(fake, 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text(Strings.projectsNotesTitle));
    await tester.pumpAndSettle();
    expect(find.text(Strings.projectsNotesCounter(0, 500)), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Plan shaping',
    );
    await tester.pump();
    expect(find.text(Strings.projectsNotesCounter(12, 500)), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, Strings.save));
    await tester.pumpAndSettle();

    expect(fake.notesUpdates[1], 'Plan shaping');
  });

  testWidgets('priority pick calls updatePriority', (tester) async {
    final project = _project(1, 'Alpha');
    final fake = _FakeProjects(details: {1: _detail(project)});
    await tester.pumpWidget(_detailHost(fake, 1));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(ChoiceChip, Strings.projectsPriorityLabels[3]),
    );
    await tester.pumpAndSettle();

    expect(fake.priorities[1], 3);
  });

  testWidgets('deadline tomorrow chip calls updateDeadline', (tester) async {
    final project = _project(1, 'Alpha');
    final fake = _FakeProjects(details: {1: _detail(project)});
    await tester.pumpWidget(_detailHost(fake, 1));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(Strings.projectsDeadlineTomorrow));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.projectsDeadlineTomorrow));
    await tester.pumpAndSettle();

    final expected = _day(DateTime.now().add(const Duration(days: 1)));
    expect(_day(fake.deadlineUpdates[1]!), expected);
  });

  testWidgets('target entered in hours stores minutes', (tester) async {
    final project = _project(1, 'Alpha');
    final fake = _FakeProjects(details: {1: _detail(project)});
    await tester.pumpWidget(_detailHost(fake, 1));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(Strings.projectsTarget));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.projectsTarget));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '20',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, Strings.save));
    await tester.pumpAndSettle();

    expect(fake.targets[1], 1200);
  });

  testWidgets('target accepts decimal hours', (tester) async {
    final project = _project(1, 'Alpha');
    final fake = _FakeProjects(details: {1: _detail(project)});
    await tester.pumpWidget(_detailHost(fake, 1));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(Strings.projectsTarget));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.projectsTarget));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '1.5',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, Strings.save));
    await tester.pumpAndSettle();

    expect(fake.targets[1], 90);
  });

  testWidgets('target stepper adds and subtracts one hour', (tester) async {
    final project = _project(1, 'Alpha', targetMinutes: 120);
    final fake = _FakeProjects(details: {1: _detail(project)});
    await tester.pumpWidget(_detailHost(fake, 1));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(Strings.projectsTarget));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.projectsTarget));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byTooltip(Strings.stepperIncrease(Strings.projectsTarget)),
    );
    await tester.pump();
    await tester.tap(
      find.byTooltip(Strings.stepperDecrease(Strings.projectsTarget)),
    );
    await tester.pump();
    await tester.tap(
      find.byTooltip(Strings.stepperIncrease(Strings.projectsTarget)),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, Strings.save));
    await tester.pumpAndSettle();

    // 2h + 1h - 1h + 1h = 3h → 180 minutes.
    expect(fake.targets[1], 180);
  });

  testWidgets('per-event row shows actuals', (tester) async {
    final project = _project(1, 'Alpha');
    final day = DateTime(2026, 10, 17);
    final fake = _FakeProjects(
      details: {
        1: _detail(
          project,
          events: [_event(7, 1, day)],
          doneSessions: [
            _doneSession(1, eventId: 7, day: day, minutes: 45),
          ],
          // Header total differs from the single event so the per-event
          // line ('45m of 1h') matches exactly one widget.
          plannedMinutes: 120,
          actualMinutes: 45,
        ),
      },
    );
    await tester.pumpWidget(_detailHost(fake, 1));
    await tester.pumpAndSettle();

    expect(find.textContaining('45m of 1h'), findsOneWidget);
    expect(find.textContaining('Sat, Oct 17'), findsOneWidget);
  });

  testWidgets('linked event row shows a tone dot in its tone color', (
    tester,
  ) async {
    final project = _project(1, 'Alpha');
    final day = DateTime(2026, 10, 17);
    final fake = _FakeProjects(
      details: {
        1: _detail(project, events: [_event(7, 1, day)]),
      },
    );
    await tester.pumpWidget(_detailHost(fake, 1));
    await tester.pumpAndSettle();

    final dot = tester.widget<Container>(
      find.byKey(const Key('project-event-tone-7')),
    );
    final decoration = dot.decoration as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    // _event stores toneIndex 0, i.e. Tone.focus.
    final expected = AppTheme.light
        .extension<ToneColors>()!
        .fillFor(Tone.focus);
    expect(decoration.color, expected);
  });

  testWidgets('velocity empty week shows the empty copy', (tester) async {
    final project = _project(1, 'Alpha');
    final fake = _FakeProjects(details: {1: _detail(project)});
    await tester.pumpWidget(_detailHost(fake, 1));
    await tester.pumpAndSettle();

    expect(find.text(Strings.projectsVelocityTitle), findsOneWidget);
    expect(find.text(Strings.projectsVelocityEmpty), findsOneWidget);
  });

  testWidgets('velocity bars render when a session ran today', (tester) async {
    final project = _project(1, 'Alpha');
    final now = DateTime.now();
    final fake = _FakeProjects(
      details: {
        1: _detail(
          project,
          events: [_event(7, 1, _day(now))],
          doneSessions: [
            _doneSession(1, eventId: 7, day: now, minutes: 30),
          ],
          plannedMinutes: 60,
          actualMinutes: 30,
        ),
      },
    );
    await tester.pumpWidget(_detailHost(fake, 1));
    await tester.pumpAndSettle();

    expect(find.text(Strings.projectsVelocityEmpty), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('projects-velocity-bars')),
        matching: find.byType(Expanded),
      ),
      findsNWidgets(7),
    );
  });

  testWidgets('complete shows undo and undo reopens', (tester) async {
    final project = _project(1, 'Alpha');
    final fake = _FakeProjects(details: {1: _detail(project)});
    await tester.pumpWidget(_detailHost(fake, 1));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.projectsMarkComplete));
    await tester.pumpAndSettle();

    expect(fake.completed, [1]);
    expect(find.text(Strings.projectsCompletedMessage), findsOneWidget);

    await tester.tap(find.text(Strings.projectsUndo));
    await tester.pumpAndSettle();

    expect(fake.reopened, [1]);
  });

  testWidgets('archive undo restores via unarchive', (tester) async {
    final completedAt = DateTime(2026, 10, 16, 9);
    final project = _project(1, 'Alpha', status: 1, completedAt: completedAt);
    final fake = _FakeProjects(details: {1: _detail(project)});
    await tester.pumpWidget(_detailHost(fake, 1));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.projectsArchive));
    await tester.pumpAndSettle();

    expect(fake.archived, [1]);
    expect(find.text(Strings.projectsArchivedMessage), findsOneWidget);

    await tester.tap(find.text(Strings.projectsUndo));
    await tester.pumpAndSettle();

    expect(fake.unarchived, [1]);
  });

  testWidgets('completed-on line uses the friendly date', (tester) async {
    final completedAt = DateTime(2026, 10, 16, 9);
    final project = _project(1, 'Alpha', status: 1, completedAt: completedAt);
    final fake = _FakeProjects(details: {1: _detail(project)});
    await tester.pumpWidget(_detailHost(fake, 1));
    await tester.pumpAndSettle();

    expect(find.text('Completed Fri, Oct 16'), findsOneWidget);
  });

  testWidgets('deadline renders the friendly date', (tester) async {
    final deadline = DateTime(2026, 10, 24);
    final project = _project(1, 'Alpha', deadline: deadline);
    final fake = _FakeProjects(details: {1: _detail(project)});
    await tester.pumpWidget(_detailHost(fake, 1));
    await tester.pumpAndSettle();

    expect(find.text('Sat, Oct 24'), findsOneWidget);
  });

  testWidgets('notes show stored text once saved', (tester) async {
    final project = _project(1, 'Alpha', notes: 'Shape the deck');
    final fake = _FakeProjects(details: {1: _detail(project)});
    await tester.pumpWidget(_detailHost(fake, 1));
    await tester.pumpAndSettle();

    expect(find.text('Shape the deck'), findsOneWidget);
  });

  testWidgets('tasks section switches between board and list', (tester) async {
    final project = _project(1, 'Alpha');
    final fake = _FakeProjects(details: {1: _detail(project)});
    await tester.pumpWidget(_detailHost(fake, 1));
    await tester.pumpAndSettle();

    expect(find.text(Strings.tasksTitle), findsOneWidget);
    expect(find.text(Strings.tasksStatusLabels.first), findsOneWidget);

    await tester.ensureVisible(find.text(Strings.tasksListView));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.tasksListView));
    await tester.pumpAndSettle();

    expect(find.text(Strings.tasksEmpty), findsOneWidget);
  });

  testWidgets('hero shows a tasks chip when the project has tasks', (
    tester,
  ) async {
    final project = _project(1, 'Alpha');
    final fake = _FakeProjects(details: {1: _detail(project)});
    await tester.pumpWidget(
      _detailHost(
        fake,
        1,
        tasks: [
          _task(1, TaskStatus.done.dbIndex),
          _task(2, TaskStatus.todo.dbIndex),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(Strings.projectsTasksLine(1, 2)), findsOneWidget);
  });

  testWidgets('hero shows the sessions chip when sessions exist', (
    tester,
  ) async {
    final project = _project(1, 'Alpha');
    final day = DateTime(2026, 10, 17);
    final fake = _FakeProjects(
      details: {
        1: _detail(
          project,
          events: [_event(7, 1, day)],
          doneSessions: [_doneSession(1, eventId: 7, day: day, minutes: 30)],
          plannedMinutes: 60,
          actualMinutes: 30,
        ),
      },
    );
    await tester.pumpWidget(_detailHost(fake, 1));
    await tester.pumpAndSettle();

    expect(find.text(Strings.projectsSessions(1)), findsOneWidget);
  });

  testWidgets('metadata sections render inside cards with leading icons', (
    tester,
  ) async {
    final project = _project(1, 'Alpha');
    final fake = _FakeProjects(details: {1: _detail(project)});
    await tester.pumpWidget(_detailHost(fake, 1));
    await tester.pumpAndSettle();

    // Priority, Deadline, Target, Tone and Notes each sit in a Card and lead
    // with their icon. Icon finders are scoped to the title's Card because
    // some icons (event, timer_outlined) are reused by the hero stat chips.
    final icons = <String, IconData>{
      Strings.projectsPriorityTitle: Icons.flag,
      Strings.projectsDeadline: Icons.event,
      Strings.projectsTarget: Icons.timer_outlined,
      Strings.projectsAffinity: Icons.palette_outlined,
      Strings.projectsNotesTitle: Icons.notes,
    };
    for (final entry in icons.entries) {
      final card = find.ancestor(
        of: find.text(entry.key),
        matching: find.byType(Card),
      );
      expect(card, findsOneWidget, reason: '${entry.key} should sit in a Card');
      expect(
        find.descendant(of: card, matching: find.byIcon(entry.value)),
        findsOneWidget,
        reason: '${entry.key} card should lead with ${entry.value}',
      );
    }
  });
}
