# Energy Clock — Deep Work (Tasks, Boards, Sprints, Dependencies) — Design

**Date:** 2026-10-18
**Scope:** Grow Projects from a checklist-based outcome list into a full on-device deep-work system. Tasks become first-class and schedulable onto the dial; sessions complete them. Adds a kanban board, cross-project Today board, sprints, and dependencies. Offline-only: no backend, no account, no sync, no new iOS permissions. Reuses the existing notification channel for task due reminders.
**Approach:** Phased (4 slices, 4 migrations v12 → v15), approved direction "Extend Projects". Task model: tasks replace subtasks.
**User decisions:** "Extend Projects"; "tasks replace subtasks"; a big, dense, power-tool feature with lots of controls.

## 1. Architecture & data model

Same layering as the rest of the app: `lib/data/tables/` → Drift DAOs → repositories in `lib/data/repositories/` → Riverpod providers in `lib/data/providers.dart` → feature UI in `lib/features/projects/`. Projects imports only `data/`, `core/`, `app/`, `shared/`. All user copy lives in `lib/core/strings.dart`. All colour comes from theme tokens; the `no_hardcoded_colors_test` must keep passing. Features never import each other.

Schema changes, one migration step and one `migration_test.dart` case each (`drift_schemas/` regenerated). Codegen via the Flutter SDK's `dart`: `"$(dirname "$(which flutter)")/dart" run build_runner build --delete-conflicting-outputs`.

### v12 — `tasks` (replaces `project_subtasks`)

| Column | Type | Notes |
|---|---|---|
| `id` | int PK | |
| `projectId` | int FK `projects(id)` | `onDelete: cascade` |
| `title` | text | 1–120, enforced in repo (documented here; only NOT NULL reaches DDL) |
| `notes` | text? | 0–2000, empty never stored (cleared to null) |
| `boardStatus` | int default 0 | 0 Backlog / 1 Todo / 2 Doing / 3 Blocked (manual) / 4 Done; unknown reads as 0. The Blocked column is `3`; there is no separate flag |
| `priority` | int default 0 | 0 none / 1 low / 2 medium / 3 high |
| `estimateMinutes` | int? | optional, 15–60000 (entered in hours at the sheet boundary) |
| `dueDate` | datetime? | date-only semantics |
| `plannedDate` | datetime? | day the task is pulled onto; feeds the Today board |
| `sortOrder` | int | per project per column, max+1 so new tasks append |
| `blockedReason` | text? | 0–200, only meaningful when `boardStatus == 3` (manual block); cleared when leaving Blocked |
| `createdAt` | datetime | |
| `updatedAt` | datetime | |
| `completedAt` | datetime? | non-null iff `boardStatus == 4` |

Index on `(projectId)` and `(projectId, boardStatus)`.

Migration v11 → v12: create `tasks`; copy every `project_subtasks` row (`projectId`, `title`, `sortOrder`, `createdAt`; `boardStatus` = `isDone ? 4 : 1` → done tasks land in Done, the rest in Todo; `completedAt = isDone ? createdAt : null`; `updatedAt = createdAt`; all other columns at defaults); then `migrator.deleteTable('project_subtasks')`. `resetAll()` swaps `projectSubtasks` for `tasks`.

### v13 — task ↔ event link

`events.taskId` int nullable + index. Null = unlinked (current behaviour). A task may have many linked events (many sessions of the same work). Deleting a task sets `events.taskId = null`; events and sessions are never deleted. Same precedent as `events.projectId`.

### v14 — `task_dependencies`

| Column | Type | Notes |
|---|---|---|
| `id` | int PK | |
| `taskId` | int FK `tasks(id)` | `onDelete: cascade` — the dependent |
| `dependsOnTaskId` | int FK `tasks(id)` | `onDelete: cascade` — the prerequisite |
| `createdAt` | datetime | |

Unique `(taskId, dependsOnTaskId)`. Self-links and cycles are rejected in the repository (DFS over the edge set), never only in the UI.

Migration v13 → v14 creates the table. Also in v14: task due reminders reuse the existing notification channel (no schema change).

### v15 — `sprints`

| Column | Type | Notes |
|---|---|---|
| `id` | int PK | |
| `projectId` | int FK `projects(id)` | `onDelete: cascade` (sprints are project-level) |
| `name` | text | 1–60, enforced in repo |
| `startDate` | datetime | date-only |
| `endDate` | datetime | date-only, `>= startDate` |
| `status` | int default 0 | 0 planned / 1 active / 2 closed |
| `createdAt` | datetime | |
| `closedAt` | datetime? | set on close |

`tasks.sprintId` int? FK `sprints(id)` with `onDelete: setNull` — closing/deleting a sprint never deletes work.

Migration v14 → v15 creates `sprints` and adds `tasks.sprintId`.

### Derived, never stored

Following the energy-score rule, these are computed on read and cached only in memory:

- **Task actual minutes** = sum of `activeSeconds ~/ 60` over done sessions (completed + finishedEarly) of the task's linked events. Reuses the existing grouped session query; no per-event loops.
- **Dependency-blocked** = the task has ≥1 dependency whose `boardStatus != 4`. Shown as a lock badge; never written to the row.
- **Sprint progress** = committed vs done task counts and estimate/actual minutes for the sprint's tasks.
- **Subtask count on the hub** (`3/8 tasks`) becomes task done/total for the project.

## 2. Components (UI)

All inside `features/projects/` plus `shared/` widgets and core strings/tokens. Nothing else changes.

### Projects tab becomes three surfaces

The tab (still index 1, one tab, no new tab-bar slot) gains a top segmented control:

- **Outcomes** — the existing hub (`projects_screen.dart`), unchanged except the row's `3/8 tasks` line now reads tasks.
- **Board** — a cross-project kanban: columns Backlog / Todo / Doing / Blocked / Done; a project filter chip row (All + one chip per project); same toolbar as the per-project board. This is the "deep work management" home.
- **Today** — a cross-project board of tasks whose `plannedDate` is today (or flagged), with a "Pull to today" affordance available from any board/list card.

### Project detail gains a Board/List section

`widgets/subtask_list.dart` is deleted; `widgets/task_board.dart` (columns) and `widgets/task_list.dart` (flat list) replace it, behind a Board | List switch.

- **Board:** horizontal columns with header (name, count, `+` add). Drag a card between columns to change `boardStatus` and reorder; long-press a card for the action menu (Edit, Schedule, Start session, Mark done, Duplicate, Add dependency, Delete). Cards show: title, tone dot, priority dot, due chip, `estimate vs actual`, dependency lock badge + `blocked by N`, sprint chip, and a session-progress mini-ring.
- **List:** one sortable list with the same fields as rows, grouped headers, bulk select (set status, add to sprint, delete).

### Toolbar (many controls, per board/list)

Search field; filter chips (priority, due: overdue / today / this week / none, tone affinity, blocked-only, has-sessions, unplanned); sort menu (Manual / Title / Due / Priority / Created / Estimate / Recently updated); group-by toggle; sprint selector (All / Backlog / each sprint); show/hide Done; `Add task`.

### Rich task editor sheet (`widgets/task_editor.dart`)

Title; notes (multiline, 2000-char counter); status picker (5 chips); priority (4 chips); estimate (hours stepper + manual entry, one decimal); due date (quick chips Today / Tomorrow / Next week + pick + clear); planned date (feeds Today board); sprint picker (with "New sprint"); project picker (move the task); tone affinity inherits the project (read-only); **Dependencies** section (Blocked by list + Blocks reverse list, add via task picker with cycle guard); **Linked events** list (each row: friendly date + range + per-event actual, with Schedule / Unschedule); actual-vs-estimate readout; Save / Delete / Duplicate.

### Sprints (`widgets/sprint_bar.dart`, `widgets/sprint_manager_dialog.dart`)

Sprint selector sits in the toolbar. Manager dialog lists sprints (name, dates, status), create/edit (name 1–60, start/end), activate (only one active per project at a time), and close. A progress strip on the board shows committed vs done counts and estimate/actual minutes with a mini burn-down. Closing a sprint prompts: move incomplete tasks to Backlog or to another sprint (never silently dropped).

### Stats / Coach hooks (read-only)

Stats gains one task section: throughput (done per week), median cycle time (created → completed), and estimate accuracy (actual ÷ estimate). Coach gains read-only signals: overdue count, at-risk = due soon and still in Backlog/Todo. Neither introduces a second XP/score system; project and task minutes remain views over sessions.

## 3. Data flow

- **Reads:** `taskListProvider(projectId)` and `taskDetailProvider(id)` wrap DAO watch streams. The board watches the project's tasks plus the done-session rollup (one grouped query, O(1) per task) so card actuals render without N+1. Cross-project Board and Today watch a global task stream with client-side grouping. Search/filter/sort/group/sprint state lives in a `tasksViewProvider` (Notifier holding the query and toggles), not in the DB.
- **Writes:** create / update / move / reorder / duplicate / delete via `TaskDao` + `tasksRepository`, with inline validation; a write failure surfaces an inline snackbar, never a crash. Status changes are DAO transactions; the watch stream re-emits. No optimistic UI.
- **Dependency writes:** add edge → cycle check → insert; on cycle, the sheet shows an inline "That would create a dependency loop" and does not write. Remove edge deletes the row.
- **Sprint writes:** create/activate/close via `sprintsRepository`; activation demotes any other active sprint for the project in one transaction; close sets `closedAt` and prompts for the move.
- **Scheduling:** `Schedule` opens the existing event sheet prefilled with the task title, tone, and estimate duration, and writes `events.taskId` on save. `Start session` creates an ad-hoc event at "now" linked to the task and launches the Session flow. Session completion marks the linked event done and prompts "Mark task done?" — v1 never auto-completes a task silently.
- **Notifications:** task due reminders reuse the existing "event starting soon" channel (no new permission): one notification at 09:00 on `dueDate` when the task is not done. Rescheduled on due-date change; cancelled on complete/delete/due-clear. Disabled when notifications are denied (same guard as events and project deadlines).

## 4. Error handling & edge cases

All failures inline; never throws to the user.

- **Validation (save disabled until valid):** title 1–120; notes 0–2000; estimate 15–60000 minutes (entered in hours); priority 0–3; block reason 0–200 when `isBlocked`; sprint name 1–60 and `endDate >= startDate`; dependency edges reject self-links and cycles.
- **Drag rules:** a dependency-blocked task cannot be dragged into Doing — the drag is refused with "Finish the tasks it depends on first". The manual Blocked column is `boardStatus = 3`; leaving Blocked clears `blockedReason`.
- **Delete:** task delete unlinks events (`taskId = null`) and cascades its dependency edges, then deletes the row; confirm dialog, no undo (mirrors project delete). Project delete cascades tasks and their edges; events/sessions survive.
- **Complete/undo:** completing sets `boardStatus = 4` + `completedAt` and shows a 5s Undo snackbar (reopen clears `completedAt`); complete/reopen/duplicate are reversible, delete is confirm-only.
- **Empty states:** no tasks ("Break down the work — add the first task"); all-done board; search-no-match ("No tasks match …" + Clear); Today with nothing pulled ("Pull a task to plan your day"); sprint with no tasks; task with no linked events ("Schedule it to track time").
- **Overlap with existing rules:** 3-ring overlap refusal, same-day flight guard, and past-day read-only all stand; task metadata stays editable even when its linked events are in the past.
- **Timer lifecycle:** no timers except the Undo snackbar and the local due-countdown text; boards have no runaway state on tab switch (kept-alive tab restores idle, same as Deck).
- **Explicit non-goals:** assignees/teams, sync/iCloud, recurring tasks, attachments, custom fields, cross-project sprints, dependency types beyond blocks/blocked-by, Gantt timeline, subtask nesting, widgets/Live Activity, new tones, a second XP/score system, cross-tab drag-and-drop.

## 5. Testing

Follows the repo gates: `flutter analyze`, `flutter test`, and the golden rule (`flutter test --update-goldens` only after a deliberate visual change, then review the images). Board/list/editor are deliberate, so expect project widget tests to change; dial pixels are untouched (no dial golden regen).

- **Pure unit tests:** `boardStatus` transitions; sort comparators (manual/title/due/priority/created/estimate/updated); dependency cycle detection and blocked computation; estimate/duration formatting; sprint progress and burn-down math; Today-board filtering by `plannedDate`.
- **DAO/repository tests:** task CRUD + reorder round-trip; unique dependency constraint + cascade; sprint CRUD, single-active invariant, and `tasks.sprintId` set-null on sprint delete; project delete cascades tasks; delete unlinks events.
- **Migration tests:** v11 → v12 (subtasks become tasks; `project_subtasks` dropped; mapping preserved), v12 → v13, v13 → v14, v14 → v15, with `drift_schemas/`.
- **Notifier tests:** `tasksViewProvider` search/filter/sort/group/sprint transitions; complete/reopen/duplicate/undo; due-reminder schedule/cancel on due change/complete/delete (mocked scheduler clock).
- **Widget tests:** board drag changes status; blocked drag refusal; toolbar filters/sort/search; task editor fields + dependency cycle error; sprint manager create/activate/close + move prompt; Today board pull; session-completes-task prompt; hub `done/total tasks` line.
- **Regression:** `no_hardcoded_colors_test` passes; existing project/subtask tests are migrated (subtask tests become task tests); flight overlay, Deck, Coach, and tab-switch preservation tests stay green.

## 6. Build slices

Each slice ends runnable with passing gates.

- **Slice 1 (v12) — Tasks & boards.** `tasks` table + subtask→task migration; `TaskDao`/`tasksRepository`; per-project Board + List replacing `SubtaskList`; rich task editor; toolbar (search/filter/sort/group); complete/reopen/duplicate/delete. *Runnable: projects have real boards.*
- **Slice 2 (v13) — Dial & session integration.** `events.taskId`; Schedule/Unschedule; Start session from a task; session-completes-task prompt; task progress actuals on cards. *Runnable: tasks live on the dial and sessions complete them.*
- **Slice 3 (v14) — Dependencies & reminders.** `task_dependencies`, cycle guard, lock badge + blocked drag refusal, dependency UI in the editor; task due reminders on the existing channel. *Runnable: tasks can depend on each other and remind you.*
- **Slice 4 (v15) — Sprints & cross-project boards.** `sprints` + UI + burn-down; cross-project Board view; Today board; Stats/Coach read-only hooks. *Runnable: the full deep-work suite.*
