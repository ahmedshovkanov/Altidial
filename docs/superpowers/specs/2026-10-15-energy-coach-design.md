# Energy Clock — Energy Coach (Smart Day + Review Ritual) — Design

**Date:** 2026-10-15
**Scope:** New major feature: on-device coach that suggests better placement, runs a morning/evening ritual, and generates a weekly insights feed. Offline-only, no backend, no sync, no account, no new iOS permissions.
**Approach:** A — Energy Coach (approved). Suggest-not-auto-move planner + intent/review ritual + frozen weekly insights. Hub reachable without a 6th tab; all smarts as pure recomputation over existing events + sessions.
**User decisions:** keep offline-only → large effort (3+ weeks) → Approach A.

## 1. Architecture & data model

Existing pattern stays: `lib/data/tables/` → Drift DAOs → repositories in `lib/data/repositories/` → Riverpod providers in `lib/data/providers.dart` → feature UI. Features never import each other (amendment from Projects spec holds: features may depend one-way toward shared providers/sheets only, no cycles); Coach imports only `data/`, `core/`, `app/`, `shared/`. All copy in `lib/core/strings.dart`. All colors via theme tokens — the no-hardcoded-colour test must keep passing.

New module `lib/features/coach/` (screen + widgets + providers) plus pure logic in `lib/core/coach/` (`planner.dart`, `insights_rules.dart` — no Flutter imports, fully unit-testable).

Schema change — version 6 → 7 (one migration, `build_runner` codegen with the Flutter SDK's `dart`):

- `coach_intents` — `date` date PK, `focusGoal` text (1–120 chars), `topEventIds` text (comma-joined event ids snapshot, nullable), `createdAt` datetime.
- `coach_reviews` — `date` date PK, `energy` int (1–5), `winText` text nullable (0–140 chars), `createdAt` datetime. Adherence is never stored here — it is read live from `day_scores`.
- `coach_insights` — `isoYear` + `isoWeek` composite PK, `kind` text (one of 6 rule ids), `payloadJson` text (frozen snapshot), `generatedAt` datetime. Frozen like `weekly_roundups` — reopening shows what was true at generation time.
- Existing rows: nothing to backfill. `resetAll()` in `database.dart` also clears all three tables.
- Every bump needs a step in `migration` and a test in `test/data/migration_test.dart`; see `drift_schemas/`.

Navigation: tab count stays 5 (`TabScaffold` + `AppTabBar` unchanged). Coach hub is `lib/features/coach/coach_screen.dart` surfaced as a contextual card at the top of Clock (morning / midday / evening / Monday states) and as a card on Profile; deep-link from Stats insights teaser is read-only. No `features/<a>` → `features/<b>` imports.

Planner + insights math (pure classes in `core/coach/`, recomputable — same rule as energy score, never incrementally accumulated):

- `suggestSwaps(todayEvents, heatmap28d, focusTargetMinutes)` → ranked `List<SwapSuggestion>` (max 3): each has `eventId`, `fromStartMinute`, `toStartMinute`, `reasonKind` (peak | balance | late-avoid), `evidenceText`. Peak window = top-2 focus-dense hours from 28-day heatmap; Focus events outside peak are candidates to move in; Inbox events inside peak are candidates to move out; Life events bias toward 11:00–14:00 / after 17:00. Never proposes a move that creates a 4th overlap ring or crosses midnight.
- `buildInsights(statsWindow28d, dayScores, sessionsSummary, projectsSummary)` → 0–6 cards, one per rule: `peak-hours`, `late-abandon`, `balance-drift`, `streak-at-risk`, `target-hit-rate`, `project-velocity`. Each card: `title`, `body` (1 line), `evidence` (numbers, e.g. "42% of Inbox abandoned after 16:00 over last 14d"), `ruleVersion`. Generation threshold: each rule declares `minData` (e.g. ≥5 ended sessions in window); below threshold the card is omitted and the feed shows a per-feed "Not enough data yet — run sessions for a week" state, never fake numbers.

## 2. Components (UI)

All inside `features/coach/` (+ theme tokens, core strings). Tabs keep state when switching via existing scaffold behavior.

- **Coach card on Clock (`widgets/coach_card.dart`):** contextual CTA driven by time-of-day + data state. Morning (before 11:00, no intent yet): `Set today's intent` + `Plan My Day`. Midday (intent set, swaps available): `2 suggestions ready — review`. Evening (≥1 ended session today, no review yet): `Review your day (1 min)`. Monday (new insights row this week): `3 new insights`. Tapping opens the Coach hub scrolled to the right section. Empty-data state collapses to a single quiet line, never a wall of CTAs.
- **Plan My Day sheet (`widgets/plan_sheet.dart`):** list of ≤3 `SwapSuggestion` rows: event title + `14:00 → 09:30` + reason chip (`Your peak`, `Protect focus`, `Avoid late slump`). Per-row Accept / Dismiss. Accept reuses the existing event-edit write path (same validation: same-day, 3-ring refusal, flight pinned). Dismiss records a `dismissedSuggestionIds` in-memory set only (no DB). "No suggestions — your day already matches your peaks" empty state.
- **Morning Intent sheet (`widgets/intent_sheet.dart`):** focus-goal text field (1–120 chars, inline validation, save disabled until valid) + auto-picked top-3 from today's Focus events (read-only chips, tap jumps to Clock like the Projects detail pattern). One save per date (re-save overwrites). Disabled on past read-only days.
- **Evening Review sheet (`widgets/review_sheet.dart`):** energy 1–5 dot selector + optional win text (0–140) + adherence line auto-pulled from `day_scores` ("Today: 68% kept"). Save writes `coach_reviews`. Shows existing review for re-read; past days read-only.
- **Coach hub (`coach_screen.dart` + `widgets/insight_card.dart`):** sections Intent (today) / Suggestions (today) / Insights (this week + archive). Insight cards: title, body, evidence line, rule-version footer. Archive collapsed by default. Load failure: "Couldn't load coach." + retry (provider invalidate).
- **Stats/Profile hooks (read-only, no fork):** Stats' 4 sections unchanged; a small "Coach insight" teaser under Focus depth links to the hub. Profile gets a `Coach` card (today's intent status + streak of reviewed days). No changes to energy score, streak, XP, badges — coach data is a view over existing sessions, not a second scoring system.

Visual companion was not needed; user proceeded text-only.

## 3. Data flow

Create / edit reuse existing write paths; two new writes + one frozen read.

- **Intent:** sheet → validate → `coachDao.upsertIntent(date, focusGoal, topEventIds)` → providers invalidate → Clock card flips to midday state.
- **Review:** sheet → validate → `coachDao.upsertReview(date, energy, winText)` → invalidate. Review count feeds the Profile Coach card only.
- **Suggestions:** providers watch today's `events` stream + 28d `StatsSnapshot` (existing `statsRepository.watchWindow`) → pure `suggestSwaps()` client-side (same light-aggregator pattern as `deckFlightsProvider`). Accept = existing `calendar_repository.updateEvent` with moved minutes. No DB polling; recompute on events/window change.
- **Insights:** Monday foreground (or first open of the ISO week) → `buildInsights()` over 28d window → freeze one row per card into `coach_insights`. Reopening an old week reads the frozen JSON, never recomputes. History still counts like roundups.
- **Notifications:** no fork — morning reminder deep-links to intent sheet when today is empty of intent; evening reminder (existing planning-reminder channel variant) deep-links to review when sessions exist but no review. Both reuse the existing `NotificationScheduler` channels; no new permission.

## 4. Error handling & edge cases

Tight by design; all failures inline, never throws to the user.

- **Validation (inline, save disabled until valid):** focus goal 1–120 chars; win text 0–140; energy required 1–5. Copy lives in `lib/core/strings.dart`.
- **Empty states:** no events today → planner empty ("Add 2+ events to get suggestions"); <minData → insights empty ("Run sessions for a week to unlock insights"); no intent yet → intent section CTA; no review yet → review CTA. No section renders zeroed charts.
- **Overlap with existing rules:** flight-forces-Inbox wins (flights are pinnable — suggestions never move a flight unless user drags it manually); past-day read-only disables intent/review/suggest-accept; 3-ring overlap refusal applies to accepts unchanged; same-day-flight guard unchanged.
- **Timer lifecycle:** no timers in hub except local time-of-day CTA text; no runaway state on tab switch (kept-alive tab restores idle, same as Deck).
- **Out of scope (explicit non-goals):** auto-apply without tap, AI/cloud-generated text, new tones, recurrence of intents, iCloud sync, widgets/Live Activity (deferred to a follow-up), sharing/collaboration, second XP/score system, checklists/subtasks (Projects Pro is a separate spec).

## 5. Testing

Follows repo gates: `flutter analyze`, `flutter test`, golden rule (`flutter test --update-goldens` only after deliberate visual change + image review). No golden regen expected (new screens only; default dial pixels unchanged).

- **Pure unit tests:** `suggestSwaps` (empty, already-optimal, peak move-in, inbox move-out, pinned-flight respect, 4th-ring refusal, midnight clamp); all 6 insight rules (fires, below-threshold omitted, evidence numbers exact); frozen-vs-recompute (old week reads snapshot).
- **DAO/repository tests:** upsert intent/review round-trip; overwrite same date; pre-migration DB reads without coach tables; migration v6 → v7 with `drift_schemas/`.
- **Notifier tests:** accept applies move via existing edit path; dismiss is memory-only; invalid saves rejected.
- **Widget tests:** Clock card shows correct CTA per time/state; sheets validate + save/disable; hub groups + cards + empty states render; Profile card shows intent status and opens hub.
- **Regression:** no-hardcoded-colour test passes; existing flight overlay/sheet, Deck, Projects, tab-switch preservation tests untouched.

## 6. Apple review story (4.2)

Reviewer sees a ritual loop with weeks-long personal data (intents, reviews, frozen insights), data-driven suggestions that cannot be faked with static content, and screenshots showing peak-based swaps + insight evidence + review streak — clearly an intelligent tool with lasting value, not a planner skin over a timer. The Flight Deck calm facts stay as-is; Coach becomes the depth anchor alongside Stats and Projects. App Store notes can state "100% on-device intelligence, no account" as a privacy feature.
