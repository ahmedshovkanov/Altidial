# Energy Clock — Projects Pro Expansion (Fixes + Depth) — Design

**Date:** 2026-10-17
**Scope:** Expand the Projects tab (now 2nd tab) from primitive rings + deadline chips into a rich linked-outcomes hub. Offline-only, no backend, no sync, no account, no new iOS permissions. Reuses the existing notification channel for deadline reminders.
**Approach:** Phased Pro (approved). Slice 1: fixes + hub/detail depth (no new tables beyond project columns). Slice 2: subtasks table + deadline reminders. Two migrations, two implementation slices.
**User decisions:** all thin spots hurt → fix all; subtasks in scope; deadline reminders + velocity both in.

## 1. Architecture & data model

Existing pattern stays: `lib/data/tables/` → Drift DAOs → repositories in `lib/data/repositories/` → Riverpod providers in `lib/data/providers.dart` → feature UI. Features never import each other; Projects imports only `data/`, `core/`, `app/`, `shared/`. All copy in `lib/core/strings.dart`. All colors via theme tokens — the no-hardcoded-colour test must keep passing.

Schema change — version 9 → 10 (Slice 1) and 10 → 11 (Slice 2), one migration step each, `build_runner` codegen with the Flutter SDK's `dart`:

- v10 `projects.notes` — text nullable, 0–500 chars, default null. Empty string never stored (cleared to null).
- v10 `projects.priority` — int with default 0: 0 none / 1 low / 2 medium / 3 high. Unknown values read as 0.
- v10 adds `updateTitle(id, title)` repository path (title 1–80 chars, trimmed). Previously rename was impossible.
- v11 `project_subtasks` — `id` int PK, `projectId` int FK references `projects(id)` on delete cascade, `title` text 1–80, `isDone` bool default false, `sortOrder` int (creation order, no drag-reorder in v1), `createdAt` datetime. Index on `projectId`.
- `events.projectId` semantics unchanged (one event → max one project). Deleting a project sets `events.projectId = null` and (v11) deletes its subtasks; events and sessions are never deleted.
- Existing rows migrate with `notes = null`, `priority = 0`; no backfill. `resetAll()` in `database.dart` also clears `project_subtasks`.
- Every bump needs a step in `migration` and a test in `test/data/migration_test.dart`; see `drift_schemas/`.

Performance fix (Slice 1, no migration): replace the per-event `sessionsForEvent` loop in `DriftProjectRepository._loadDetail` with one grouped query (`sessionsForProject(projectId)` on the session DAO, joined via linked event ids). Same math: `plannedMinutes` = sum of linked events' (`endMinute - startMinute`); `actualMinutes` = `activeSeconds ~/ 60` summed over done outcomes (completed + finishedEarly) only. `ProjectDetail` gains `sessionsCount` and `lastWorkedAt` (max done-session end time, nullable) so the hub renders without extra watches.

Velocity (pure, never stored — same rule as energy score): `velocityLast7Days(sessions)` in `features/projects/model/` maps the last 7 calendar days to done-minutes per day. Zero days render as empty bars, never fake averages.

Navigation: unchanged. Projects stays tab index 1 (`ProjectsTabBody`), `ProjectDetailView` stays a pushed route. `onOpenDay` in tab mode does `selectedDateProvider.select(day)` + tab select(0).

## 2. Components (UI)

All inside `features/projects/` (+ theme tokens, core strings). Tab keeps state when switching via existing scaffold behavior.

- **Hub list (`projects_screen.dart` + `widgets/project_row.dart`):** header row (title + New button reusing `showCreateProjectDialog`, still title-only to keep the dialog light) + new search field (filters by title substring, case-insensitive) + sort menu (Deadline / Progress / Recently worked / Title; null deadlines sort last, null `lastWorkedAt` sorts last) + filter chips (All tones / Focus / Life / Inbox affinity + Overdue only). Sections become Active / Ready to complete / Completed (own section) / Archived (collapsed). Row upgrades: title, progress ring in tone-affinity color (neutral when null), `actual of target/planned` subtitle, deadline chip (`Due Fri` / `Due in 3d` / `Overdue 3d` red — moved into `Strings`, no longer hardcoded English in `project_progress.dart`), plus `N sessions · worked 2d ago` line and `3/8 tasks` subtask count (Slice 2) and priority dot (Slice 1). Empty state ("Name your first outcome") and load-failure + retry kept, search-no-match gets its own empty ("No projects match …" + Clear button).
- **Project detail (`widgets/project_detail.dart`):** header ring + `planned vs actual` + sessions count + tone-split mini-bar (unchanged math) + `Completed Oct 12` line when completed. Title tappable → rename dialog (same 1–80 validation). Notes card: multiline display + Edit sheet, 500-char counter, empty hint ("Add context — why does this matter?"). Priority picker: 4 chips (None/Low/Medium/High). Deadline row: quick chips Today / Tomorrow / Next week + pick-a-date + Clear; overdue red; friendly dates everywhere (`Fri, Oct 17`, never `YYYY-MM-DD` — `_dayLabel` removed). Target editor in hours (`20h`, stepper 1h + manual entry in hours with one decimal, still stores integer minutes). 7-day velocity mini-bars (7 vertical bars, done-minutes per day, empty week shows quiet "No sessions in the last 7 days" instead of zeroed chart). Linked events grouped Upcoming / Past: each row shows tone dot + title + `Fri, Oct 17 · 9:00–10:30` + per-event `45m of 1h` actuals (done sessions only) instead of bare titles. `Mark complete` / `Reopen` / `Archive` menu + delete with unlink confirmation ("Events stay on your dial, only the link is removed"); complete/archive surface an Undo snackbar (5s; undo of complete → reopen to active, undo of archive → restore prior status 0/1 preserving `completedAt`); delete stays confirm-only (no resurrection). Metadata stays editable even for past-linked events (existing spec §4 overlap rule).
- **Subtasks (Slice 2, `widgets/subtask_list.dart`):** checklist under detail header: unchecked first (creation order), checked collapsed greyed with strikethrough. Add row (inline text field + Add, 1–80 chars), tap checkbox toggles, swipe or menu renames/deletes. Counts feed hub (`3/8 tasks`) and `readyToComplete` hint stays progress-based only — subtasks never auto-complete a project.
- **Stats/Profile/Coach hooks:** read-only, no fork. Stats' 4 sections unchanged. No changes to energy score, streak, XP, badges — project minutes and subtasks are views, never a second scoring system.

Visual companion was not needed; user proceeded text-only.

## 3. Data flow

Create / edit / delete reuse the existing write path; two additive writes.

- **Slice 1 reads:** `projectListProvider` + `projectDetailProvider(id)` as today, plus client-side search/sort/filter state in a new `projectsViewProvider` (Notifier holding `query`, `sort`, `toneFilter`, `overdueOnly`). Hub watches list + per-visible-project details for `sessionsCount`/`lastWorkedAt` (bounded to visible rows; grouped query keeps it O(1) per project, fixing the current N+1). Countdown/deadline text stays a pure function of date; UI ticks locally, no DB polling.
- **Slice 1 writes:** `updateTitle`, `updateNotes`, `updatePriority` via `ProjectDao` + `projectsRepository` with inline validation; write failure surfaces inline snackbar, never crash. Target writes convert hours → minutes at the sheet boundary.
- **Slice 2 subtasks:** new `subtaskRepository` + `watchSubtasks(projectId)` stream + `create/toggle/rename/delete` (toggle flips `isDone`, no timestamps beyond `createdAt`). No optimistic updates — DAO transactions then stream re-emit.
- **Slice 2 reminders:** `NotificationScheduler.scheduleProjectDeadline(project)` reuses the existing "event starting soon" channel (no new permission): one local notification at 09:00 the day before `deadline` in the device timezone via the existing scheduler's timezone handling (only when `deadline != null`, status active, not complete/archived). Rescheduled on deadline change, cancelled on complete/archive/delete/deadline-clear. Past deadlines never schedule. Disabled when system notifications are denied (same guard as events).
- **Notifications:** no other fork — linked events schedule like any event via the existing scheduler.

## 4. Error handling & edge cases

Tight by design; all failures inline, never throws to the user.

- **Validation (inline, save disabled until valid):** title 1–80 chars; notes 0–500; priority 0–3 (unknown → 0); `targetMinutes` optional, 15–600000 (entered as hours, converted); deadline optional, not before creation day at creation time (overdue afterward is a state, not an error); subtask title 1–80. Copy lives in `lib/core/strings.dart` — including `deadlineLabel` strings currently hardcoded in `project_progress.dart` and the `YYYY-MM-DD` fallback, both moved to `Strings`.
- **Empty states:** no projects; search-no-match; project with no linked events ("Link events from any event sheet to start tracking"); no sessions yet → planned-only dashed ring ("Run a session to fill this in"); no subtasks ("Break it down — add the first step"); velocity week with no sessions → quiet line, never zeroed averages. No section renders zeroed charts.
- **Overlap with existing rules:** flight-forces-Inbox wins over affinity; past-day read-only disables picker + project edits for past-linked events (project metadata itself stays editable); 3-ring overlap refusal unchanged; same-day-flight guard unchanged.
- **Timer lifecycle:** no timers in hub/tab except local deadline countdown text and Undo snackbar timers; no runaway state on tab switch (kept-alive tab restores idle, same as Deck).
- **Delete/undo:** delete unlinks events (`projectId = null`) + deletes subtasks (Slice 2), deletes the project row; no undo (hard delete). Complete/archive/reopen are reversible + Undo snackbar.
- **Out of scope (explicit non-goals):** per-task estimates, sharing/collaboration, iCloud sync, widgets/Live Activity for projects, auto-complete (progress or subtasks never auto-complete), second XP/score system, new tones, recurrence of projects, iPad-specific layout beyond existing adaptive shell, subtask drag-reorder (v1 creation-order only).

## 5. Testing

Follows repo gates: `flutter analyze`, `flutter test`, golden rule (`flutter test --update-goldens` only after deliberate visual change + image review). Hub row/detail changes are deliberate, so expect row/detail widget-test updates; dial pixels untouched (no dial golden regen).

- **Pure unit tests:** progress math (unchanged cases), `deadlineLabel` incl. new `Strings` keys, title/notes/priority/target validation, sort comparators (deadline/progress/recent/title), `velocityLast7Days` (empty, single, multi-day, abandoned excluded), subtask counting `done/total`.
- **DAO/repository tests:** create → rename/notes/priority round-trip; delete unlinks without deleting events; subtask CRUD + cascade on project delete; pre-migration rows read as `notes = null`, `priority = 0`; migrations v9 → v10 and v10 → v11 with `drift_schemas/`.
- **Notifier tests:** search/sort/filter state transitions; complete/reopen/archive + undo paths; reminder schedule/cancel on deadline change/complete/delete (mocked scheduler clock).
- **Widget tests:** hub search + sort + filters + empty/no-match states; row badges (sessions, last-worked, subtask count, priority); detail rename/notes/priority/deadline-quick-chips/target-hours/velocity/per-event actuals; subtask add/toggle/rename/delete; delete confirmation unlinks.
- **Regression:** no-hardcoded-colour test passes; existing flight overlay/sheet, Deck, Coach, tab-switch preservation tests untouched except new tab indices if sections shift.

## 6. Apple review story (4.2)

Reviewer sees durable user-created outcomes with weeks-long lifecycle (deadlines with reminders, targets in hours, notes, priorities, subtasks, per-event actuals, 7-day velocity) plus data-driven rings that cannot be faked with static content, and screenshots showing search/sort, velocity bars, subtasks, and deadline chips — clearly a tool with lasting value, not content. App Store notes can state "100% on-device, no account" as a privacy feature. Flight Deck calm kit stays as-is; Projects becomes the depth anchor alongside Stats and Coach.
