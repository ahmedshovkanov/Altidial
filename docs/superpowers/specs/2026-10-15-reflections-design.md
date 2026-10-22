# Energy Clock — Session Debriefs + Energy Patterns (Reflections) — Design

**Date:** 2026-10-15
**Scope:** New major feature: 10-second post-session debrief (energy + focus + tags + note) feeding an on-device patterns engine and journal timeline. Offline-only, no backend, no sync, no account, no new permissions.
**Approach:** A — Session debriefs + Energy Patterns (approved). Columns on existing `sessions`; new `features/reflections/` module surfaced as Stats 5th section + timeline screen + Profile card; no new tab.
**User decisions:** keep offline-only → reflection-journal direction → Approach A (over evening day-review and project retros).

## 1. Architecture & data model

Existing pattern stays: `lib/data/tables/` → Drift DAOs → repositories in `lib/data/repositories/` → Riverpod providers in `lib/data/providers.dart` → feature UI. Features never import each other; Reflections imports only `data/`, `core/`, `app/`, `shared/`. All copy in `lib/core/strings.dart`. All colors via theme tokens — the no-hardcoded-colour test must keep passing.

Schema change — version 6 → 7 (one migration, `build_runner` codegen with the Flutter SDK's `dart`):

- `sessions.energyRating` — int nullable, 1–5 (drained → charged), default null.
- `sessions.focusRating` — int nullable, 1–5 (scattered → in flow), default null.
- `sessions.tagsCsv` — text nullable (comma-joined tag ids, max 4).
- `sessions.note` — text nullable (0–140 chars, trimmed).
- Existing rows migrate to nulls = "not reflected"; no backfill. `resetAll()` in `database.dart` already clears `sessions`, nothing extra.
- Every bump needs a step in `migration` and a test in `test/data/migration_test.dart`; see `drift_schemas/`.

Navigation: tab count stays 5 (`TabScaffold` + `AppTabBar` unchanged). Reflections is a new module `lib/features/reflections/` (screen + widgets + providers + pure pattern model, possibly `core/reflection/` for pure math) surfaced as Stats 5th section + timeline screen pushed from Stats header and Profile card. Debrief sheet lives in `features/session/widgets/debrief_sheet.dart`. No `features/<a>` → `features/<b>` imports.

Pure logic (`ReflectionTags` consts + `ReflectionPatterns.compute`, testable, recomputable — same rule as energy score, never incrementally accumulated):

- Fixed tag set v1 (8 ids): `flow, clear-goal, interruptions, noisy, tired, time-pressure, context-switch, low-energy`. No custom tags.
- Patterns require `n >= 5` reflected sessions (completed + finishedEarly only), else empty. Examples: tone-energy delta, hour-of-day focus split, tag lift (`clear-goal +0.9 focus`), post-Life boost (`focus right after Life +0.8`), late-Inbox drain. All pure functions over (session + event tone + hour).

## 2. Components (UI)

All inside `features/session/` (sheet) + `features/reflections/`. Tab keeps state when switching via existing scaffold behavior.

- **Debrief sheet (`session/widgets/debrief_sheet.dart`):** appears right after Finish / Finish early / Abandon / recovery close-out, with session summary on top (`Logged 50m on Deep work`). Energy 1–5 (`Drained → Charged`), Focus 1–5 (`Scattered → In flow`), tag chips multi-select max 4, optional note field 140 chars with counter. Big `Save`, subtle `Skip`. <10s. Editable later from journal. Abandoned sessions also prompt.
- **Journal timeline (`reflections/reflections_screen.dart` + widgets):** grouped Today / This week / Earlier. Row: tone dot + title + `50m · Focus`, energy/focus as 5-dot mini-bars, up to 4 tag pills, note preview 1 line. Tap → edit debrief bottom-sheet (same form). Empty state: "Finish a session — your reflection will land here." Load failure: "Couldn't load reflections." + retry (provider invalidate).
- **Patterns cards (Stats 5th section `Energy patterns`, reuses `section_card.dart`):** only when `n >= 5`, else "Reflect on 5 sessions to reveal your patterns." Cards e.g. `Clear goal → +0.9 focus (n=12)`, `Inbox after 21:00 −1.2 energy (n=7)`. Simple tone-colored bars, no new chart lib. Each card shows sample size + `Why?` subtitle.
- **Entry points:** Stats header `Journal` button + Profile `Reflections` card (reflected-session streak + top pattern teaser → opens timeline). No tab change.

Visual companion was not needed; user proceeded text-only.

## 3. Data flow

Reuses existing session write path; one new read aggregator. No polling, no timers.

- **Save:** debrief sheet → validate → `sessionDao.updateReflection(sessionId, energy, focus, tagsCsv, note)` as a follow-up write immediately after the session-end transaction that writes `endedAt / activeSeconds / outcome`. Skipping leaves nulls — session still counts for streak/XP/score exactly as today. Editing updates same row, never a second row.
- **Read timeline:** new `reflectionsRepository` + `reflectionsTimelineProvider` watches `sessions` table stream joined to `events` (tone/title/date) client-side, newest-first, filtered to `endedAt != null`. Same light-aggregator pattern as `deckFlightsProvider`.
- **Read patterns:** `reflectionPatternsProvider` watches same joined list → pure `ReflectionPatterns.compute(list)` in Dart. No caching table, no `day_scores` fork.
- **Complete/archive/delete:** n/a. Deleting an event/session deletes its reflection with it (FK cascade as today).
- **Notifications:** no fork — debrief is inline on session end, never via push. No journal reminder channel in v1.
- **Export/reset:** `export_repository` includes reflection columns automatically; `resetAll()` clears with sessions.

Stats' 4 existing sections unchanged; energy score, streak, XP, badges unchanged — reflections are a view over sessions, not a second scoring system (same rule as Projects).

## 4. Error handling & edge cases

Tight by design; all failures inline, never throws to the user.

- **Validation (inline):** energy/focus optional 1–5 (both empty = valid Skip-equivalent); tags max 4 (5th tap shows "Pick up to 4" inline); note 0–140 chars with live counter, hard-capped at 140 (paste truncates, counter red at 130+). Copy lives in `lib/core/strings.dart`.
- **Empty states:** no reflected sessions → timeline empty + patterns needs-5 message; session with no debrief shows dashed mini-bars + "Not reflected — tap to add"; no tags/note omits pills/preview.
- **Write failure:** DAO update fails → snackbar "Couldn't save reflection. Try again." + sheet stays open with values preserved; session end itself already persisted so streak/XP never lost.
- **Overlap with existing rules:** debrief editable anytime (experience, not plan — unlike event times which are past-day read-only); patterns use completed + finishedEarly only, abandoned + running excluded from aggregates but visible in timeline (same precedent as streak/XP); flight-forces-Inbox sessions reflect like any Inbox event; recovery close-out prompts debrief once.
- **Timer lifecycle:** no timers in reflections; kept-alive tabs restore idle, same as Deck.
- **Out of scope (explicit non-goals):** custom tags, photo/voice notes, mood-over-time graphs beyond pattern cards, daily journal reminder notifications, sharing to social, iCloud sync, widgets/Live Activity for reflections, second XP/score system, recurrence of reflections, iPad-specific layout beyond existing adaptive shell.

## 5. Testing

Follows repo gates: `flutter analyze`, `flutter test`, golden rule (`flutter test --update-goldens` only after deliberate visual change + image review). No golden regen expected (new screens only; default dial pixels unchanged).

- **Pure unit tests:** `ReflectionPatterns.compute` (empty <5 → no cards, tone-energy delta, hour split, tag lift, post-Life boost, abandoned/running excluded), note trim/cap, tagsCsv round-trip (max 4, unknown ids ignored).
- **DAO/repository tests:** update reflection persists + edit overwrites; pre-migration rows read as nulls; migration v6 → v7 with `drift_schemas/`.
- **Notifier tests:** timeline groups Today/Week/Earlier; patterns empty until 5; write failure → retry state.
- **Widget tests:** sheet renders energy/focus/tags/note + Save/Skip; 5th-tag guard; note counter 130+/140; timeline rows + empty + error + retry; edit reopens with saved values; Stats 5th section empty vs cards; Profile card teaser opens timeline.
- **Regression:** no-hardcoded-colour test passes; existing session end/close-out, Deck, tab-switch preservation tests untouched.

## 6. Apple review story (4.2)

Reviewer on Day 1 sees empty dial (risk). Reviewer on Day 3 with sample data sees durable user-created objects with weeks-long value (140-char notes + ratings + tags on every session, journal grouped by week), data-driven patterns that cannot be faked with static content (`Clear goal → +0.9 focus n=12`, tone/hour/tag breakdowns from their own sessions), and screenshots showing debrief sheet + timeline + pattern cards — clearly a tool with lasting personal value, not a timer skin. App Store notes can state "100% on-device journal, no account — reflections never leave the phone" as a privacy feature. Flight Deck calm kit stays as-is; Reflections becomes the depth anchor alongside Stats + Projects.

No new permission, no backend, no EventKit — zero new review surface. All content is user-entered, so no content-moderation risk.
