# Energy Clock — Projects Tab + Coach Ritual v2 (Energy + Reflection) — Design

**Date:** 2026-10-15
**Scope:** Two independent pieces shipping separately: (A) Navigation — Projects becomes the 2nd tab, Stats moves into Profile as a pushed hub; (B) Coach ritual expansion — morning energy prediction + live reflection aggregates in evening review. Offline-only, no backend, no sync, no account, no new iOS permissions.
**Approach:** 1 — Tab swap + light ritual (approved). Suggest-not-auto-move planner unchanged; Journal/debriefs unchanged; review aggregates are read-only views, never a second scoring system.
**User decisions:** new tab for Projects (2nd place), keep Coach in current place → richer ritual → energy + reflection → Projects 2nd, Stats into Profile with Stats button → Approach 1.

## 1. Architecture & data model

Existing pattern stays: `lib/data/tables/` → Drift DAOs → repositories in `lib/data/repositories/` → Riverpod providers in `lib/data/providers.dart` → feature UI. Features never import each other; Coach/Projects import only `data/`, `core/`, `app/`, `shared/`. All copy in `lib/core/strings.dart`. All colors via theme tokens — the no-hardcoded-colour test must keep passing.

Tabs stay at 5, order becomes Clock (0), Projects (1), Calendar (2), Profile (3), Deck (4). `AppTabBar` labels/icons/`tabCount` mapping updated (`Projects` icon `CupertinoIcons.folder` / `folder_fill` following the existing selected-fill pattern; `Stats` label/icon removed); `TabScaffold._screen` maps 1 → Projects tab root, 2 → Calendar, 3 → Profile, 4 → Deck. Projects tab root is the existing hub body without its `Scaffold`/`AppBar` (tabs are bodies inside `TabScaffold`'s Scaffold — Stats/Profile today return scroll views, not nested Scaffolds). `ProjectDetailView` stays a pushed route on top of the tab. `onOpenDay` in tab mode does `selectedDateProvider.select(day)` + tab select(0), replacing the current `popUntil(first)` used from the pushed hub. New `Strings` keys: `statsCardTitle`/`statsCardHint`, `predictedEnergyLabel`, `reflectionsTodayLine`/`reflectionsTodayEmpty` — no hardcoded copy in widgets.

Stats leaves the tab bar: `StatsScreen` body stays as-is, wrapped in a thin pushed `StatsHub` Scaffold + AppBar when opened from Profile. Profile drops `ProjectsCard`, adds a `StatsCard` button (title + chevron, pushes StatsHub). No changes to tab-switch keep-alive behavior (`IndexedStack` + `_visited`).

Coach schema change — version 8 → 9 (one migration, `build_runner` codegen with the Flutter SDK's `dart`):

- `coach_intents.predictedEnergy` — int nullable, check 1-5, default null. Existing rows read as null = "no prediction".
- `coach_reviews` unchanged. Review aggregates (avg energy/focus, tag counts, adherence) are live recomputations over existing `sessions` + `day_scores`, same rule as energy score — never stored.
- `resetAll()` in `database.dart` behavior unchanged (clears coach tables as today).
- Every bump needs a step in `migration` and a test in `test/data/migration_test.dart`; see `drift_schemas/`.

Navigation: Coach hub stays pushed (`Navigator.push`) from Clock card + Profile teaser; tab count unchanged by Coach.

Planner + insights math unchanged (`suggestSwaps`, `buildInsights`, `coachCardKind`). Prediction value never drives CTA — intent existence drives card state as today.

## 2. Components (UI)

All inside `features/projects/`, `features/stats/`, `features/progress/`, `features/coach/` (+ theme tokens, core strings). Tabs keep state when switching via existing scaffold behavior.

- **Projects tab root:** header row (title + New button reusing `showCreateProjectDialog`), then existing Active / Ready to complete / Completed & Archived sections unchanged (`ProjectRowTile`, rings, deadline chips). Empty state ("Name your first outcome") and load-failure + retry kept verbatim, minus the pushed-hub AppBar.
- **Profile Stats entry (`StatsCard`):** `AppCard` with title + "Week/month tone balance, planned-vs-actual…" subtitle + chevron, `onTap` pushes StatsHub. Placed where `ProjectsCard` was to keep scroll order stable.
- **StatsHub (pushed):** `Scaffold(appBar: AppBar(title: Stats))` + existing `StatsScreen` body (period header, tone balance, planned-vs-actual, focus depth, heatmap, patterns, Journal link). `TabBarInset` padding resolves to 0 on pushed routes (no tab shell above) — no special-casing.
- **Intent sheet v2:** focus-goal field unchanged + new optional "Morning energy" 1–5 dot row (same control as review sheet, `Semantics 'Predicted energy i of 5'`). Save enabled when goal valid; prediction optional. Existing intents show prediction as `Energy 4/5` line under the goal in the hub.
- **Coach hub Review section v2:** under the saved/todo review, a live "Today's reflections" line: `3 sessions · E 3.7 / F 4.0 · top: Flow, Clear goal` + existing adherence line. Pulled from today's ended sessions with ratings; when zero rated sessions, quiet `No reflections yet today.` No editing here — tapping opens Journal (existing `ReflectionsScreen` route).
- **Stats/Profile hooks:** Stats' 4 sections + patterns unchanged. No changes to energy score, streak, XP, badges.

Visual companion was not needed; user proceeded text-only.

## 3. Data flow

Create / edit reuse existing write paths; one additive write + live reads.

- **Projects as tab:** `projectListProvider` + `projectDetailProvider(id)` watched from tab root exactly as today. Create/link/complete/archive/delete reuse `projectsRepository` + `eventDao.updateProject` paths; validation unchanged. Tab switches recompute via existing watchers, no DB polling.
- **Stats as hub:** `statsDataProvider` + `statsWindowProvider` watched from pushed StatsHub; first open loads current week/month window, back-pop returns to Profile with tab state preserved via existing `IndexedStack` keep-alive.
- **Intent prediction:** sheet → validate → `coachRepository.saveIntent(day, focusGoal, predictedEnergy?)` → `coachDao.upsertIntent` writes nullable col → `todayIntentProvider` invalidates → Clock `CoachCard` + Profile teaser flip exactly as today (intent existence drives `coachCardKind`, prediction value never drives CTA).
- **Review aggregates:** hub watches today's ended sessions (existing session/event join via reflections providers filtered to selected day) + `day_scores` adherence. Pure client-side averages/tag counts, recomputed on sessions change — same light-aggregator pattern as `suggestionsProvider`. No new writes, dismiss/set flows untouched.
- **Notifications:** no fork.

## 4. Error handling & edge cases

Tight by design; all failures inline, never throws to the user.

- **Validation (inline, save disabled until valid):** goal 1–120 chars; win 0–140; energy/prediction 1–5 when set (prediction null allowed). Copy lives in `lib/core/strings.dart`.
- **Empty states:** Projects tab empty → same create CTA; Stats hub load failure → existing copy; intent with no prediction → goal only; review with no rated sessions → quiet line, never zeroed averages. No section renders zeroed charts.
- **Overlap with existing rules:** flight-forces-Inbox wins; past-day read-only disables intent/review/prediction edits; 3-ring overlap refusal unchanged; same-day-flight guard unchanged. `isPastDay` guard covers prediction dots.
- **Timer lifecycle:** no timers in hub/tab except local time-of-day CTA text; no runaway state on tab switch (kept-alive tab restores idle, same as Deck).
- **Out of scope (explicit non-goals):** merging debrief edit into review, auto-apply without tap, new tones, recurrence of intents, iCloud sync, widgets/Live Activity, sharing/collaboration, second XP/score system, checklists/subtasks, iPad-specific layout beyond existing adaptive shell.

## 5. Testing

Follows repo gates: `flutter analyze`, `flutter test`, golden rule (`flutter test --update-goldens` only after deliberate visual change + image review). Tab icons/order change is deliberate, so expect one tab-bar golden regen + image review; dial pixels untouched.

- **Pure unit tests:** prediction validation (null/1–5/invalid rejected); reflection aggregate formatting (empty, single, multi-tag, unrated excluded).
- **DAO/repository tests:** upsert intent with/without prediction round-trip; overwrite same date; pre-migration DB reads prediction null; migration v7 → v8 with `drift_schemas/`.
- **Notifier tests:** `onOpenDay` from Projects tab selects date + switches to Clock tab; StatsHub push/pop preserves Profile state.
- **Widget tests:** Projects tab groups + rings + empty states render without AppBar; Profile shows StatsCard (no ProjectsCard) and opens StatsHub; intent sheet saves with/without prediction; hub shows prediction line + live aggregates; Clock card CTA logic unchanged.
- **Regression:** no-hardcoded-colour test passes; existing flight overlay/sheet, Deck, tab-switch preservation tests updated only for new indices.

## 6. Apple review story (4.2)

Reviewer sees durable user-created outcomes promoted to a first-class tab (weeks-long lifecycle with deadlines/targets/rings) plus a ritual loop with weeks-long personal data (predicted vs actual energy, reflection aggregates, frozen insights) — data-driven views that cannot be faked with static content. App Store notes can state "100% on-device intelligence, no account" as a privacy feature.
