# Projects Visual Polish & Draggable Tasks

Date: 2026-10-19

## Goal

Make the Projects experience feel more considered and make tasks directly
manipulable. Two surfaces are in scope:

- The **project Detail screen** — richer hierarchy and depth.
- The **cross-project Board** — visual depth plus drag between columns.

The per-project **Task board** gains the same drag feel.

## Constraints

- Colour comes only from the theme. On-screen colour still only ever means a
  *tone*; drop highlights, columns and stat chips stay neutral
  (`ink` / `outline` / `surface`). The existing no-hard-coded-colour test must
  keep passing.
- Features never import each other. All work stays inside
  `lib/features/projects/`.
- No new data model, DAO or repository methods. Drag reuses the existing
  `tasksRepository.move(taskId, status)`.
- Reduced motion is honoured: animations collapse when
  `MediaQuery.disableAnimationsOf(context)` is true.

## Non-goals

- Reordering cards within a column.
- Drag across projects (the cross-project Board already spans projects; a card
  keeps its project when moved).
- New task/project fields.
- Regenerating dial/calendar goldens (no project goldens exist).

## 1. Drag interaction (shared behaviour)

Both boards use the same treatment, factored into a small shared widget group
so the two boards cannot drift.

- **Gesture:** `LongPressDraggable<int>(delay: Duration(milliseconds: 150))`,
  so the lift is near-immediate while column and board scrolling keep working.
- **Lifted card (feedback):** rendered on a `Material` with elevation
  (`AppColors.cardShadow`), a slight scale (~1.03) and rotation (~1deg); width
  matches the column card width so it does not jump.
- **Source slot (`childWhenDragging`):** a dashed-outline ghost box at the card
  height, at reduced opacity.
- **Drop target:** a `DragTarget<int>` per column. When
  `candidate.isNotEmpty` the column shows an ink border, a faint ink-tinted
  fill and a centred "Drop here" hint; otherwise the neutral outline border.
- **On accept:** call `tasksRepositoryProvider.move(taskId, status)`.

## 2. Cross-project Board

- `_BoardColumn` becomes a `ConsumerWidget` wrapped in `DragTarget<int>`.
- Each card is wrapped in the shared draggable, carrying `task.id` as data.
- On accept, move via the repository; the existing stream updates the column.
- The per-card project label stays above each card.
- A shared `Key('cross-task-drop-<status>')` names each drop target for tests,
  mirroring the per-project `task-drop-<status>` keys.

## 3. Per-project Task board

- Replace the current bare `LongPressDraggable` with the shared draggable
  (150ms delay + feedback).
- Wrap each `_Column` in the shared drop target (keeps the existing
  `task-drop-<status>` key).
- Tap-to-open-editor and inline add stay unchanged.

## 4. Project Detail — hero header

- The tappable title stays in the `AppBar` (it owns rename); the hero must not
  repeat it, so `find.text(title)` keeps matching one widget.
- Header becomes a hero row: a larger progress ring (72px) coloured by the
  project's tone affinity (neutral ink when none), the existing progress line
  and event count, and a row of neutral **stat chips**:
  - `done/total tasks` (from `taskCountsProvider`), hidden while `total == 0`.
  - `sessions` count, hidden while `count == 0`.
  - `deadline` via `deadlineLabel` (`Due in 3d` / `Overdue 2d`), danger-tinted
    when overdue. Distinct text from the Deadline card's `friendlyDate`, so no
    widget renders the same string twice.
- No target chip (the Target card already shows the duration; avoid duplication).
- The completed-on line stays beneath the hero when the project is complete.

## 5. Project Detail — card-based sections

- Priority, Deadline, Target, Tone and Notes each become a distinct `Card`
  with a leading icon and the existing edit affordances (tap-to-edit, quick
  deadline chips, priority/tone choice chips).
- Linked events and Velocity remain sections, wrapped consistently with the
  rest.

## 6. Project Detail — progress visuals

- Tone-split bar becomes thicker (~10px) with the same tone colours and a
  rounding radius.
- Velocity bars: a soft baseline tick under each day, a minimum bar height for
  zero days, and a gentle scale-in animation (collapsed under reduced motion).

## Files touched

- `lib/features/projects/widgets/task_card.dart` (or a new
  `task_drag.dart`): shared draggable + drop-target widgets.
- `lib/features/projects/widgets/task_board.dart`: use shared widgets.
- `lib/features/projects/widgets/cross_project_board.dart`: add drag.
- `lib/features/projects/widgets/project_detail.dart`: hero, cards, visuals.
- `lib/core/strings.dart`: any new labels (e.g. a drop hint).
- Tests: `task_board_test.dart`, `cross_project_board` coverage,
  `project_detail_test.dart`.

## Testing

- `task_board_test.dart`: drag test uses the 150ms delay; tap/add/validation
  tests unchanged.
- New test: dragging a card on the cross-project Board moves it to the target
  column (assert `repo.rows.single.boardStatus`).
- `project_detail_test.dart`: assertions for the hero stat chips where they are
  stable; keep existing rename/notes/target/velocity/drag-agnostic tests green.
- `flutter analyze` and `flutter test` must pass.
