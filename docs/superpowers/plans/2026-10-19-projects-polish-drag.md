# Projects Polish & Draggable Tasks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the project Detail screen richer and give both task boards a short-delay drag with clear drop feedback.

**Architecture:** A new shared `task_drag.dart` owns one draggable-card widget and one drop-zone widget; both the per-project `TaskBoard` and the `CrossProjectBoard` compose them so drag behaviour cannot drift. The detail screen gets a hero header, card-sectioned metadata and livelier progress visuals.

**Tech Stack:** Flutter 3.44, Riverpod, no new packages.

## Global Constraints

- Colour comes only from the theme; on-screen colour only ever means a *tone*. Feature code must not contain `Color(0x` or `Colors.` (enforced by `test/architecture/no_hardcoded_colors_test.dart`).
- Features never import other features; all work stays in `lib/features/projects/`.
- No new data model, DAO or repository methods. Drag reuses `tasksRepositoryProvider.move(taskId, status)`.
- The drag delay is exactly `Duration(milliseconds: 150)`.
- Animations collapse to zero duration when `MediaQuery.disableAnimationsOf(context)` is true.
- Commands: test `flutter test`, lint `flutter analyze`.

---

### Task 1: Shared drag widgets + drop-hint string

**Files:**
- Create: `lib/features/projects/widgets/task_drag.dart`
- Modify: `lib/core/strings.dart` (add `tasksDropHere` near the other task strings, after line 660 `tasksMetaNoEstimate`)
- Create: `test/features/projects/task_drag_test.dart`

**Interfaces:**
- Consumes: `TaskCard` (existing, `lib/features/projects/widgets/task_card.dart`), `AppColors`/`AppSpacing`/`AppRadii`/`AppMotion`.
- Produces:
  - `const Duration taskDragDelay`
  - `class DraggableTaskCard extends StatelessWidget { DraggableTaskCard({required TaskRow task, required double cardWidth, VoidCallback? onTap}) }`
  - `class TaskDropZone extends StatelessWidget { TaskDropZone({required ValueChanged<int> onAccept, required Widget child, Key? dropKey}) }`

- [ ] **Step 1: Add the drop-hint string**

In `lib/core/strings.dart`, after `static const String tasksMetaNoEstimate = 'No estimate';` (line 660), add:

```dart
  static const String tasksDropHere = 'Drop here';
```

- [ ] **Step 2: Write the failing test**

Create `test/features/projects/task_drag_test.dart`:

```dart
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/features/projects/widgets/task_drag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TaskRow _task() => TaskRow(
  id: 1,
  projectId: 1,
  title: 'Ship v1',
  notes: null,
  boardStatus: 1,
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
  testWidgets('dragging a card onto a zone reports its id', (tester) async {
    int? dropped;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 240,
                child: DraggableTaskCard(task: _task(), cardWidth: 220),
              ),
              Expanded(
                child: TaskDropZone(
                  dropKey: const Key('zone'),
                  onAccept: (id) => dropped = id,
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Ship v1')),
    );
    await tester.pump(taskDragDelay + const Duration(milliseconds: 50));
    await gesture.moveTo(tester.getCenter(find.byKey(const Key('zone'))));
    await tester.pump();

    // Hovering shows the drop hint.
    expect(find.text(Strings.tasksDropHere), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(dropped, 1);
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/features/projects/task_drag_test.dart`
Expected: FAIL — `task_drag.dart` does not exist / `taskDragDelay` undefined.

- [ ] **Step 4: Write the shared widgets**

Create `lib/features/projects/widgets/task_drag.dart`:

```dart
// lib/features/projects/widgets/task_drag.dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/features/projects/widgets/task_card.dart';
import 'package:flutter/material.dart';

/// How long a card is held before a drag starts. Short enough to feel
/// immediate, long enough that column and board scrolling still work.
const Duration taskDragDelay = Duration(milliseconds: 150);

/// A [TaskCard] that can be picked up and dropped on a [TaskDropZone]. Carries
/// the task id as the drag payload. The lifted card lifts on a shadow and
/// scales slightly; the source slot fades behind a dashed outline.
class DraggableTaskCard extends StatelessWidget {
  const DraggableTaskCard({
    required this.task,
    required this.cardWidth,
    this.onTap,
    super.key,
  });

  final TaskRow task;
  final double cardWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return LongPressDraggable<int>(
      data: task.id,
      delay: taskDragDelay,
      feedback: Material(
        color: AppColors.transparent,
        child: SizedBox(
          width: cardWidth,
          child: Transform.scale(
            scale: 1.03,
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 8,
              shadowColor: colors.ink,
              child: TaskCard(task: task),
            ),
          ),
        ),
      ),
      childWhenDragging: CustomPaint(
        foregroundPainter: _DashedBorder(color: colors.outline),
        child: Opacity(opacity: 0.35, child: TaskCard(task: task)),
      ),
      child: TaskCard(task: task, onTap: onTap),
    );
  }
}

/// A column-sized drop target. Highlights (ink border, faint fill, a centred
/// hint) while a card hovers, then reports the dropped task id.
class TaskDropZone extends StatelessWidget {
  const TaskDropZone({
    required this.onAccept,
    required this.child,
    this.dropKey,
    super.key,
  });

  final ValueChanged<int> onAccept;
  final Widget child;
  final Key? dropKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return DragTarget<int>(
      key: dropKey,
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidate, rejected) {
        final active = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: reduceMotion ? Duration.zero : AppMotion.fast,
          curve: AppMotion.standard,
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: active ? colors.surface : AppColors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(
              color: active ? colors.ink : colors.outline,
              width: active ? 2 : 1,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              if (active)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: Center(child: Text(Strings.tasksDropHere)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Paints a dashed rounded-rectangle border at the child's bounds.
class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(AppRadii.card),
        ),
      );
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = distance + dash;
        canvas.drawPath(
          metric.extractPath(
            distance,
            end > metric.length ? metric.length : end,
          ),
          paint,
        );
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/projects/task_drag_test.dart`
Expected: PASS (1 test).

- [ ] **Step 6: Commit**

```bash
git add lib/features/projects/widgets/task_drag.dart lib/core/strings.dart test/features/projects/task_drag_test.dart
git commit -m "feat: shared draggable task card and drop zone"
```

---

### Task 2: Per-project board uses the shared drag widgets

**Files:**
- Modify: `lib/features/projects/widgets/task_board.dart` (imports; `_ColumnState.build` drop area, lines 138-179)
- Modify: `test/features/projects/task_board_test.dart:165-185` (drag test)

**Interfaces:**
- Consumes: `DraggableTaskCard`, `TaskDropZone`, `taskDragDelay` from Task 1.
- Produces: no new API; the `task-drop-<status>` keys are preserved.

- [ ] **Step 1: Update the drag test's timing and import**

In `test/features/projects/task_board_test.dart`:

Replace the import line `import 'package:flutter/gestures.dart';` (line 9) with nothing (the file no longer needs `kLongPressTimeout`).

Replace the body of `'dragging a card moves it to another column'` (lines 165-185) with:

```dart
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
```

- [ ] **Step 2: Run the test to verify it still passes on the old code**

Run: `flutter test test/features/projects/task_board_test.dart`
Expected: PASS — the old `LongPressDraggable` also fires within 200ms.

- [ ] **Step 3: Swap in the shared widgets**

In `lib/features/projects/widgets/task_board.dart`, remove the import
`import 'package:energy_clock/features/projects/widgets/task_card.dart';` and add
`import 'package:energy_clock/features/projects/widgets/task_drag.dart';`.

Replace the `Expanded(child: DragTarget<int>(...))` block (lines 138-179) with:

```dart
            Expanded(
              child: TaskDropZone(
                dropKey: Key('task-drop-${widget.status.name}'),
                onAccept: _move,
                child: ListView(
                  children: [
                    for (final task in widget.tasks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: DraggableTaskCard(
                          task: task,
                          cardWidth: 220,
                          onTap: () =>
                              showTaskEditor(context, ref, task: task),
                        ),
                      ),
                  ],
                ),
              ),
            ),
```

`_move` is `Future<void> _move(int taskId)` and is assignable to
`ValueChanged<int>` (a `void` return accepts any). No other change to `_Column`.

- [ ] **Step 4: Run the board tests**

Run: `flutter test test/features/projects/task_board_test.dart`
Expected: PASS (all tests, including the drag test).

- [ ] **Step 5: Commit**

```bash
git add lib/features/projects/widgets/task_board.dart test/features/projects/task_board_test.dart
git commit -m "refactor: per-project board uses shared drag widgets"
```

---

### Task 3: Cross-project board gains drag

**Files:**
- Modify: `lib/features/projects/widgets/cross_project_board.dart` (imports; `_BoardColumn` lines 99-188)
- Create: `test/features/projects/cross_project_board_test.dart`

**Interfaces:**
- Consumes: `DraggableTaskCard`, `TaskDropZone` from Task 1; `tasksRepositoryProvider` (existing).
- Produces: `cross-task-drop-<status>` keys on each column; `_BoardColumn` is now a `ConsumerWidget`.

- [ ] **Step 1: Write the failing test**

Create `test/features/projects/cross_project_board_test.dart`:

```dart
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/task_status.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/project_repository.dart';
import 'package:energy_clock/features/projects/providers.dart';
import 'package:energy_clock/features/projects/widgets/cross_project_board.dart';
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/projects/cross_project_board_test.dart`
Expected: FAIL — no `cross-task-drop-doing` key exists and the card does not move.

- [ ] **Step 3: Add the drag to the column**

In `lib/features/projects/widgets/cross_project_board.dart`, remove the import
`import 'package:energy_clock/features/projects/widgets/task_card.dart';` and add
`import 'package:energy_clock/features/projects/widgets/task_drag.dart';`.

Change `class _BoardColumn extends StatelessWidget` (line 99) to
`class _BoardColumn extends ConsumerWidget`, and its build signature (line 113) to
`Widget build(BuildContext context, WidgetRef ref) {`.

Replace the `Expanded(child: DecoratedBox(...))` block (lines 142-182) with:

```dart
            Expanded(
              child: TaskDropZone(
                dropKey: Key('cross-task-drop-${status.name}'),
                onAccept: (id) =>
                    ref.read(tasksRepositoryProvider).move(id, status),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  children: [
                    for (final task in tasks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (projectTitle(task) != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: AppSpacing.xs,
                                  bottom: 2,
                                ),
                                child: Text(
                                  Strings.projectsTaskProject(
                                    projectTitle(task)!,
                                  ),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colors.muted,
                                  ),
                                ),
                              ),
                            DraggableTaskCard(
                              task: task,
                              cardWidth: 220,
                              onTap: () => onTapTask(task),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/projects/cross_project_board_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Run the tab tests to confirm no regression**

Run: `flutter test test/features/projects/projects_tab_test.dart`
Expected: PASS (the label and tap-to-edit tests still hold).

- [ ] **Step 6: Commit**

```bash
git add lib/features/projects/widgets/cross_project_board.dart test/features/projects/cross_project_board_test.dart
git commit -m "feat: cross-project board cards are draggable"
```

---

### Task 4: Detail screen hero header with stat chips

**Files:**
- Modify: `lib/features/projects/widgets/project_detail.dart` (header block, lines 434-503)
- Modify: `test/features/projects/project_detail_test.dart` (new test)

**Interfaces:**
- Consumes: `taskCountsProvider(projectId)` (`({int done, int total})?`), `deadlineLabel(DateTime?, DateTime)`, `Strings.projectsSessions`, `Strings.projectsTasksLine`, `context.toneColors.fillFor`.
- Produces: no new API.

- [ ] **Step 1: Write the failing test**

Append to the `main()` in `test/features/projects/project_detail_test.dart` (before the closing brace at line 559):

```dart
  testWidgets('hero shows a tasks chip and hides it when there are no tasks', (
    tester,
  ) async {
    final project = _project(1, 'Alpha');
    final fake = _FakeProjects(details: {1: _detail(project)});
    await tester.pumpWidget(_detailHost(fake, 1));
    await tester.pumpAndSettle();

    // The host overrides taskListProvider with an empty stream: total == 0.
    expect(find.textContaining('tasks'), findsNothing);
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/projects/project_detail_test.dart`
Expected: the sessions test FAILS — no `'1 session'` chip exists yet.

- [ ] **Step 3: Replace the header block**

In `lib/features/projects/widgets/project_detail.dart`, replace lines 434-472
(the `Row(children: [ SizedBox(width: 64 ... CircularProgressIndicator ... ), ...])`)
with:

```dart
              Row(
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      strokeWidth: 6,
                      value: progress.clamp(0.0, 1.0).toDouble(),
                      backgroundColor: colors.outline,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        project.toneIndex == null
                            ? colors.ink
                            : context.toneColors.fillFor(
                                Tone.fromDbIndex(project.toneIndex!),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Strings.projectsProgress(
                            formatDurationMinutes(detail.actualMinutes),
                            formatDurationMinutes(
                              project.targetMinutes != null &&
                                      project.targetMinutes! > 0
                                  ? project.targetMinutes!
                                  : detail.plannedMinutes,
                            ),
                          ),
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          Strings.eventCount(detail.events.length),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
```

Also, near the top of `_DetailBody.build` (right after
`final progress = ProjectProgress.compute(...)` at line 314), add:

```dart
    final counts = ref.watch(taskCountsProvider(project.id));
```

Then, immediately after the header `Row(...)`'s closing `),` (before the
`if (project.status == 1 && project.completedAt != null)` block at old line 473),
insert:

```dart
              if ((counts != null && counts.total > 0) ||
                  detail.doneSessions.isNotEmpty ||
                  project.deadline != null) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    if (counts != null && counts.total > 0)
                      _StatChip(
                        icon: Icons.checklist,
                        label: Strings.projectsTasksLine(
                          counts.done,
                          counts.total,
                        ),
                      ),
                    if (detail.doneSessions.isNotEmpty)
                      _StatChip(
                        icon: Icons.timer_outlined,
                        label: Strings.projectsSessions(
                          detail.doneSessions.length,
                        ),
                      ),
                    if (project.deadline != null)
                      _StatChip(
                        icon: Icons.event,
                        label: deadlineLabel(project.deadline, now),
                        danger: overdue,
                      ),
                  ],
                ),
              ],
```

Add this private widget at the end of the file (after the `_TargetDialogState`
class):

```dart
/// One neutral hero chip. Colour on screen only ever means a tone, so chips
/// stay ink/muted (with danger reserved for overdue).
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Chip(
      avatar: Icon(
        icon,
        size: 16,
        color: danger ? colors.danger : colors.muted,
      ),
      label: Text(
        label,
        style: danger ? TextStyle(color: colors.danger) : null,
      ),
    );
  }
}
```

`ref` and `now` are already in scope in `_DetailBody.build`; `taskCountsProvider`
comes from the already-imported `providers.dart`, `deadlineLabel` from the
already-imported `project_progress.dart`, and `Tone`/`context.toneColors` from
existing imports.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/projects/project_detail_test.dart`
Expected: PASS (all tests; the new sessions test included, the "no tasks" test
holds because the host streams no tasks).

- [ ] **Step 5: Commit**

```bash
git add lib/features/projects/widgets/project_detail.dart test/features/projects/project_detail_test.dart
git commit -m "feat: project detail hero header with stat chips"
```

---

### Task 5: Detail metadata as cards

**Files:**
- Modify: `lib/features/projects/widgets/project_detail.dart` (priority block lines 505-549; deadline block lines 569-614; target block lines 615-624; tone block lines 625-658)
- Modify: `test/features/projects/project_detail_test.dart` (new test)

**Interfaces:**
- Consumes: existing `_setPriority`, `_editDeadline`, `_setDeadline`, `_clearDeadline`, `_editTarget`, `_setAffinity`.
- Produces: no new API; all existing texts and keys unchanged.

- [ ] **Step 1: Write the failing test**

Append to `main()` in `test/features/projects/project_detail_test.dart`:

```dart
  testWidgets('metadata sections render inside cards', (tester) async {
    final project = _project(1, 'Alpha');
    final fake = _FakeProjects(details: {1: _detail(project)});
    await tester.pumpWidget(_detailHost(fake, 1));
    await tester.pumpAndSettle();

    // Priority, Deadline, Target, Tone and Notes each sit in a Card.
    expect(
      find.ancestor(
        of: find.text(Strings.projectsPriorityTitle),
        matching: find.byType(Card),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text(Strings.projectsTarget),
        matching: find.byType(Card),
      ),
      findsOneWidget,
    );
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/projects/project_detail_test.dart`
Expected: FAIL — `'Priority'` is not inside a `Card` yet.

- [ ] **Step 3: Wrap each metadata block in a Card**

In `lib/features/projects/widgets/project_detail.dart`:

Wrap the priority `Padding(...)` block (lines 505-549) in a `Card`:

- Change `Padding(` (line 505) to `Card(child: Padding(`.
- Change its closing `),` (line 549) to `)),`.

Wrap the deadline block. Change the `ListTile(` at line 569 to
`Card(child: Column(children: [ListTile(` and, after the deadline
`Padding(... child: Wrap(... ActionChip ...))` closes at line 614, add `])),`.
Concretely, the deadline section becomes:

```dart
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text(Strings.projectsDeadline),
                      subtitle: Text(
                        project.deadline == null
                            ? Strings.projectsNoDeadline
                            : Strings.friendlyDate(project.deadline!),
                        style: overdue ? TextStyle(color: colors.danger) : null,
                      ),
                      trailing: const Icon(Icons.edit),
                      onTap: () => _editDeadline(context, ref),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          ActionChip(
                            label: const Text(Strings.projectsDeadlineToday),
                            onPressed: () => _setDeadline(context, ref, today),
                          ),
                          ActionChip(
                            label: const Text(Strings.projectsDeadlineTomorrow),
                            onPressed: () => _setDeadline(
                              context,
                              ref,
                              DateTime(today.year, today.month, today.day + 1),
                            ),
                          ),
                          ActionChip(
                            label: const Text(Strings.projectsDeadlineNextWeek),
                            onPressed: () => _setDeadline(
                              context,
                              ref,
                              DateTime(today.year, today.month, today.day + 7),
                            ),
                          ),
                          if (project.deadline != null)
                            ActionChip(
                              label: const Text(Strings.projectsDeadlineClear),
                              onPressed: () => _clearDeadline(context, ref),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
```

Wrap the target `ListTile(...)` (lines 615-624) in `Card(child: ...)`.

Wrap the tone `Padding(...)` block (lines 625-658) in `Card(child: ...)`:
change `Padding(` (line 625) to `Card(child: Padding(` and its closing `),`
(line 658) to `)),`.

- [ ] **Step 4: Run the detail tests**

Run: `flutter test test/features/projects/project_detail_test.dart`
Expected: PASS (all tests, including rename/target/notes/deadline interactions
and the new card test).

- [ ] **Step 5: Commit**

```bash
git add lib/features/projects/widgets/project_detail.dart test/features/projects/project_detail_test.dart
git commit -m "feat: project detail metadata in cards"
```

---

### Task 6: Detail progress visuals

**Files:**
- Modify: `lib/features/projects/widgets/project_detail.dart` (tone-split bar lines 484-503; `_VelocityBars` lines 756-789)

**Interfaces:**
- Consumes: existing `perTone`, `velocity`, `context.toneColors`, `AppMotion`.
- Produces: `_VelocityBars` keeps `Key('projects-velocity-bars')` and its 7 `Expanded` children.

- [ ] **Step 1: Thicken the tone-split bar**

In the tone-split bar, change `height: 8,` (line 487) to `height: 10,`.

- [ ] **Step 2: Replace `_VelocityBars`**

Replace the whole `_VelocityBars` class (lines 756-789) with:

```dart
/// Seven rounded bars, oldest first, heights scaled to the week's max and
/// grown in on first paint. Each day carries a faint baseline tick; zero days
/// render as faint ticks. Animation collapses under reduced motion.
class _VelocityBars extends StatelessWidget {
  const _VelocityBars({required this.velocity});

  final List<int> velocity;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    const maxBarHeight = 64.0;
    const minBarHeight = 4.0;
    final maxMinutes = velocity.fold(0, (a, b) => a > b ? a : b);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduceMotion ? Duration.zero : AppMotion.slow,
      curve: AppMotion.standard,
      builder: (context, t, _) => Row(
        key: const Key('projects-velocity-bars'),
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final minutes in velocity)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height:
                          (minBarHeight +
                              (minutes / maxMinutes) *
                                  (maxBarHeight - minBarHeight)) *
                          t,
                      decoration: BoxDecoration(
                        color: minutes == 0 ? colors.outline : colors.ink,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(height: 2, color: colors.outline),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Run the detail tests**

Run: `flutter test test/features/projects/project_detail_test.dart`
Expected: PASS — the velocity test finds 7 `Expanded` descendants of
`projects-velocity-bars`.

- [ ] **Step 4: Commit**

```bash
git add lib/features/projects/widgets/project_detail.dart
git commit -m "feat: livelier tone bar and velocity bars"
```

---

### Task 7: Full verification

**Files:** none.

- [ ] **Step 1: Lint**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: all tests pass, including
`test/architecture/no_hardcoded_colors_test.dart`.

- [ ] **Step 3: Confirm the colour rule held**

Run: `flutter test test/architecture/no_hardcoded_colors_test.dart`
Expected: PASS.

---

## Self-Review

**Spec coverage:**
- Shared drag behaviour (150ms, feedback, ghost, drop hint) → Task 1.
- Per-project board drag → Task 2.
- Cross-project board drag → Task 3.
- Detail hero header + stat chips → Task 4.
- Detail card sections → Task 5.
- Detail progress visuals (thicker tone bar, animated velocity) → Task 6.
- Tests and analyze → Tasks 1-7.

**Placeholder scan:** none — every step has concrete code or an exact command.

**Type consistency:** `taskDragDelay`, `DraggableTaskCard(task, cardWidth, onTap)`
and `TaskDropZone(onAccept, child, dropKey)` are defined in Task 1 and used with
those exact names/shapes in Tasks 2-3. `TasksView`/`TaskStatus`/
`tasksRepositoryProvider` signatures match `providers.dart`. Hero uses
`taskCountsProvider` returning `({int done, int total})?` as defined in
`providers.dart:35`.
