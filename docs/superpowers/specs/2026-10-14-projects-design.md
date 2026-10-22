# Energy Clock — Projects (Linked Outcomes) — Design

**Date:** 2026-10-14
**Scope:** New major feature: full projects with deadline, target hours, linked events, progress ring, completion state. Offline-only, no backend, no sync, no account.
**Approach:** A — Linked Projects hub (approved). Nullable `projectId` on existing `events`; new `projects` table; hub reachable without a 6th tab; progress as pure recomputation over existing events + sessions.
**User decisions:** keep offline-only → goals-and-projects direction → full projects (not labels-only) → Approach A.

## 1. Architecture & data model

Existing pattern stays: `lib/data/tables/` → Drift DAOs → repositories in `lib/data/repositories/` → Riverpod providers in `lib/data/providers.dart` → feature UI. Features never import each other (amendment: features may depend one-way toward projects via providers/sheets only, no cycles); Projects imports only `data/`, `core/`, `app/`, `shared/`. All copy in `lib/core/strings.dart`. All colors via theme tokens — the no-hardcoded-colour test must keep passing.

Schema change — version 5 → 6 (one migration, `build_runner` codegen with the Flutter SDK's `dart`):

- `projects` — `id` int PK, `title` text (1–80 chars), `createdAt` datetime, `deadline` date nullable, `targetMinutes` int nullable (15–600000), `toneIndex` int nullable (null = all tones, display-only affinity), `status` int (0 active / 1 completed / 2 archived, default 0), `completedAt` datetime nullable.
- `events.projectId` — int nullable FK, default null. One event → max one project (same precedent as `seriesId`). Deleting a project sets `projectId = null` on its events; events and sessions are never deleted by project deletion.
- Existing rows migrate to `projectId = null`; no backfill. `resetAll()` in `database.dart` also clears `projects`.
- Every bump needs a step in `migration` and a test in `test/data/migration_test.dart`; see `drift_schemas/`.

Navigation: tab count stays 5 (`TabScaffold` + `AppTabBar` unchanged). Projects hub is a new module `lib/features/projects/` (screen + widgets + providers) surfaced as a card on Profile (top-3 active with rings → opens hub) and reachable from the Clock overflow; deep-link from Stats is read-only. No `features/<a>` → `features/<b>` imports.

Progress math (pure `ProjectProgress` class in `core/` or feature model, testable, recomputable — same rule as energy score, never incrementally accumulated):

- `plannedMinutes` = sum of linked events' (`endMinute - startMinute`).
- `actualMinutes` = sum of linked sessions' `activeSeconds / 60` for outcomes completed + finishedEarly only (abandoned excluded, running excluded).
- `progress` = `targetMinutes != null ? actual / target : planned > 0 ? actual / planned : 0`, capped for display at >100% as overflow ring.
- Status hint: `readyToComplete` when `progress >= 1.0`; completion is always manual. `overdue` when `deadline` past and status active and not complete. `dueSoon` within 7 days.

## 2. Components (UI)

All inside `features/projects/` (+ theme tokens, core strings). Tab keeps state when switching via existing scaffold behavior.

- **Event sheet — project picker row (`features/clock/widgets/event_sheet.dart`):** single row below tone buttons: `No project ▾` → bottom-sheet list of active projects + `+ New project` inline creation (title only; deadline/target set in detail). Works when `isFlight == true` (flights count as Inbox like any event). Disabled on past read-only days. Toggling off sets `projectId = null`.
- **Projects hub list (`projects_screen.dart` + `widgets/project_row.dart`):** sections Active / Ready to complete / Completed & Archived (collapsed by default). Row: title, progress ring in tone-affinity color (neutral when affinity null), `12.5 / 20h` subtitle, deadline chip (`Due Fri` / `Due in 3d` / `Overdue 3d` red). Empty state: "Name your first outcome — e.g. Launch portfolio, Run 10k" + Create button. Load failure: "Couldn't load projects." + retry (provider invalidate).
- **Project detail (`widgets/project_detail.dart`):** header ring + `planned vs actual` + sessions count + tone-split mini-bar; editable deadline + target (stepper + manual entry); tone-affinity picker (display-only, never rewrites event tones; flight-forces-Inbox still wins); linked events grouped Upcoming / Past (tap → `selectedDateProvider.select(date)` + jump to Clock, reusing `CalendarTab._openDay` / Flight Deck hero pattern); `Mark complete` / `Reopen` / `Archive` menu; delete with unlink confirmation ("Events stay on your dial, only the link is removed").
- **Stats/Profile hooks (read-only, no fork):** Stats' 4 sections unchanged; project detail reuses the same grouped queries filtered by `projectId`. Profile gets a `Projects` card (top-3 active). No changes to energy score, streak, XP, badges — project minutes are a view over existing sessions, not a second scoring system.

Visual companion was not needed; user proceeded text-only.

## 3. Data flow

Create / edit / delete reuse the existing write path; one new read aggregator.

- **Create:** event sheet → validate → `eventDao.create` / `calendar_repository` with `projectId`, tone/flight rules unchanged. New-project inline creation creates the `projects` row first, then links.
- **Edit:** same sheet; recurrence occurrences inherit `projectId` at materialisation time (`SeriesMaterialiser.materialiseDay`); edit-one vs edit-all-future follows existing series rules. Template apply / copy-yesterday copies `projectId` with the events.
- **Read hub:** new `projectsRepository` + Riverpod providers watch `projects` table + calendar day-range streams filtered client-side on `projectId` (same light-aggregator pattern as `deckFlightsProvider`). Countdown/deadline text is a pure function of date; UI ticks locally, no DB polling.
- **Complete/archive/delete:** explicit user actions only. Completing sets `status = 1` + `completedAt`; history still counts (frozen like roundups — reopening shows what was true). Archiving sets `status = 2`. Deleting unlinks events (`projectId = null`) and deletes the project row.
- **Notifications:** no fork — linked events schedule like any event via the existing `NotificationScheduler`. Optional v1.1: deadline-approaching reminder reusing the "event starting soon" channel (not in v1 scope).

## 4. Error handling & edge cases

Tight by design; all failures inline, never throws to the user.

- **Validation (inline, save disabled until valid):** title 1–80 chars; `targetMinutes` optional, 15–600000; deadline optional, not before creation day at creation time (overdue afterward is a state, not an error). Copy lives in `lib/core/strings.dart`.
- **Empty states:** no projects; project with no linked events ("Link events from any event sheet to start tracking"); no sessions yet → planned-only dashed ring ("Run a session to fill this in"); no saved/completed section when empty (collapsed).
- **Favorites-style optimistic updates not needed** — writes go through DAO transactions; write failure surfaces inline snackbar, never crash.
- **Overlap with existing rules:** flight-forces-Inbox wins over affinity; past-day read-only disables picker + project edits for past-linked events; 3-ring overlap refusal unchanged; same-day-flight guard unchanged.
- **Timer lifecycle:** no timers in hub except local deadline countdown text; no runaway state on tab switch (kept-alive tab restores idle, same as Deck).
- **Out of scope (explicit non-goals):** subtasks/checklists, per-task estimates, sharing/collaboration, iCloud sync, widgets/Live Activity for projects, auto-complete, second XP/score system, new Travel tone, recurrence of projects themselves, iPad-specific layout beyond existing adaptive shell.

## 5. Testing

Follows repo gates: `flutter analyze`, `flutter test`, golden rule (`flutter test --update-goldens` only after deliberate visual change + image review). No golden regen expected (new screens only; default dial pixels unchanged).

- **Pure unit tests:** progress math (empty, planned-only, partial, over-100%, target vs planned modes), overdue/due-soon text, ready-to-complete hint, tone-affinity display mapping.
- **DAO/repository tests:** create project → link events → read back; delete unlinks without deleting events; pre-migration rows read as `projectId = null`; migration v5 → v6 with `drift_schemas/`.
- **Notifier tests:** complete/reopen/archive transitions persist; invalid edits rejected.
- **Widget tests:** picker shows/creates/selects/clears; hub groups + rings + empty states render; detail edits deadline/target; delete confirmation unlinks; Profile card shows top-3 and opens hub.
- **Regression:** no-hardcoded-colour test passes; existing flight overlay/sheet, Deck, tab-switch preservation tests untouched.

## 6. Apple review story (4.2)

Reviewer sees durable user-created objects with weeks-long lifecycle (deadlines, targets, progress over sessions), data-driven rings that cannot be faked with static content, and screenshots showing rings + deadlines + linked plans — clearly a tool with lasting value, not content. App Store notes can state "100% on-device, no account" as a privacy feature. Flight Deck calm kit stays as-is; Projects becomes the depth anchor alongside Stats.
