# Altidial — Rename and Hidden Demo Mode — Design

**Date:** 2026-10-22
**Scope:** Rename the app from Energy Clock to Altidial everywhere, and add a hidden debug mode that replaces app data with a deterministic three-month demo dataset. The demo mode is available in every build and is triggered by holding the Profile tab for six seconds.
**Approach:** Full internal and external rename, then a destructive-but-confirmed demo seed built from a deterministic on-device generator. All user-facing data is produced locally; there is no backend, account, sync or new permission.
**User decisions:** Full rename including bundle id `com.selfloop.altidial`; hold the Profile tab bar button for six seconds; confirmation before wiping; debug mode persists across launches; Exit debug mode wipes demo data and returns to onboarding; every feature should be exercised; deterministic generator relative to today; available in all builds.

## 1. Rename to Altidial

### Visible identity

| Surface | New value |
|---|---|
| iOS home screen | `Altidial` (`CFBundleDisplayName`) |
| Bundle name | `Altidial` (`CFBundleName`) |
| Flutter `MaterialApp.title` | `Strings.appTitle` = `Altidial` |
| Export/share subject | `Altidial export` |
| Onboarding, session alert and notification copy | Replace every user-facing `Energy Clock` mention with `Altidial` |
| README | New title and product copy |
| iOS bundle identifier | `com.selfloop.altidial` (tests: `com.selfloop.altidial.RunnerTests`) |

### Internal identity

- `pubspec.yaml` package name: `energy_clock` → `altidial`.
- Every Dart import `package:energy_clock/...` → `package:altidial/...`, including tests and `tool/brand/`.
- Drift database filename: `energy_clock` → `altidial`.
- `energy_clock.iml` → `altidial.iml`.
- The `debugPrint` prefix `EnergyClock:` → `Altidial:`.
- README and the new spec use the new name. Historical design specs and plans keep their original titles as an accurate record.

The bundle id and database filename change create a fresh app identity, so existing on-device data does not carry over. This is accepted.

## 2. Debug activation and lifecycle

### Trigger

- `AppTabBar` gains an optional `onProfileHold` callback. Only tab index 3 (Profile) wires it.
- A raw pointer listener starts a six-second timer on pointer down and cancels it on pointer up/cancel. Cancelling means the hold never fires. If the timer fires while the finger is still down, it fires once and does not repeat until the next pointer down.
- There is no visual hint during the hold. At six seconds a destructive confirmation dialog appears.
- The trigger is compiled into all builds. No `kDebugMode` guard.

### Confirmation and seeding

1. Dialog title: `Load demo data?`
2. Body explains that all events, sessions, projects, tasks, reflections, templates, badges, settings and local notifications data will be erased, and three months of demo data will replace them.
3. Confirm label: `Load demo data`; cancel leaves everything untouched.
4. On confirm, show a non-dismissible progress dialog while the seed runs.
5. On success: `onboarding_done=1` and `debug_mode=1` are stored, screens refresh, and a snackbar confirms `Demo data loaded.`
6. On failure: the raw seed transaction rolls back, the progress dialog closes, and an inline snackbar says `Couldn't load demo data.` Existing data is unchanged.

### Persistence and Profile section

- `debug_mode` lives in the existing settings key/value table and is read through a Riverpod provider.
- When active, Profile shows a **Debug** section after Settings with:
  - A `Demo data` status line.
  - **Regenerate demo data** — same confirmation, wipe and seed, keeps debug mode on.
  - **Exit debug mode** — confirmation explains that demo data will be erased and the app returns to onboarding. On confirm: wipe every table, clear settings, set `debug_mode=0`, invalidate onboarding, and show onboarding.
- Holding Profile again while debug mode is already on is a no-op apart from a short `Demo mode is already on.` snackbar.

## 3. Demo dataset

### Shape

- A deterministic generator (`Random(0xA17D1A1)`) produces exactly 90 local days ending today. The same day offset always gets the same plan, so regenerating on the same day produces the same dataset and the demo always looks current.
- Weekdays carry a realistic sequence of non-overlapping blocks: deep work, email/admin, lunch or walk, meetings, a second focus block. Weekends are lighter. Roughly one day in ten is an empty rest day.
- Events never overlap, so the three-ring rule cannot be violated.
- Plans use a fixed content pool of realistic titles, project names and reflection notes. That pool lives in `lib/debug/demo_data.dart`: it is demo content rather than UI chrome, so it stays out of `Strings` while every label and message the debug UI itself shows still comes from `Strings`.

### What is generated

| Area | Demo content |
|---|---|
| Events | 90 days of planned events across all three tones, plus three flight events (one past, two upcoming) with flight number and IATA route |
| Sessions | Linked to past events only. Outcomes: completed ~75%, finished early ~10%, abandoned ~7%, no session ~8%. `plannedSeconds`, `activeSeconds`, `pausedSeconds` and `overtimeSeconds` are internally consistent |
| Reflections | ~70% of ended sessions get energy/focus ratings, 1–4 tags and occasional short notes |
| Projects | Five projects with notes, priority, tone affinity, deadlines and targets; a representative set of events is linked to them |
| Tasks | Four to six tasks per project spread across Backlog, Todo, Doing, Blocked and Done, with estimates, due dates, planned dates and completed timestamps |
| Templates | Two named day templates ("Workday", "Reset day") with realistic items |
| Coach | Intents and reviews for most days in the last 30 days, including today's intent and yesterday's review |
| Badges | Unlocks inserted with plausible historical dates so the archive's badge lines are realistic |
| Derived caches | Day scores, XP, level, streaks, badge completion and weekly roundups are rebuilt by the existing progress and roundup pipelines |

### Today

Today is partially lived. Events that ended before the current time have sessions and completed status; later events remain planned. No running session is seeded, so the recovery flow does not appear.

### Derived data pipeline

1. Raw rows are inserted in one transaction through the database, with explicit deterministic ids assigned by the generator (projects, events, sessions, tasks, templates, coach rows, badge unlocks). The database has just been wiped, so explicit ids are safe.
2. After the raw transaction commits, `ProgressRepository.recalculateAll()` rebuilds day scores, XP, level, streaks and any still-missing badges.
3. `RoundupRepository.ensureCurrent()` generates every finished week from the first demo date through last week.
4. Coach insights are not pre-written; the existing `ensureWeek` path generates them when Coach is opened. Templates and flights are read directly from the seeded rows.

## 4. Architecture and components

```
lib/debug/
  debug_constants.dart        # hold duration, settings keys, seed
  debug_providers.dart        # debug mode state + demo seeder provider
  demo_data.dart              # fixed titles, notes, project/task pools
  demo_generator.dart         # pure deterministic dataset builder
  demo_seeder.dart            # transactional wipe + insert + recompute
  debug_actions.dart          # confirm/progress/snackbar flows
  widgets/debug_section.dart  # Profile debug card
```

- `DemoDataset` is a plain in-memory record of companions and metadata, so the generator can be tested without a database.
- `DemoSeeder` is an interface with a Drift implementation; widget tests override it with a fake.
- `DebugActions` centralises the three flows (activate, regenerate, exit) so `TabScaffold` and `DebugSection` behave identically.
- `AppTabBar` only reports the six-second hold; `TabScaffold` calls `DebugActions.activate`.
- `ProfileScreen` adds `DebugSection` only when `debugModeProvider` is true. Normal-mode layout is unchanged.
- All copy is added to `lib/core/strings.dart`. All colours and spacing use existing theme tokens. Features still never import each other; `lib/debug/` is an app-level layer that imports data/core.

## 5. Error handling and edge cases

- **Wipe is atomic with the seed.** The seeder opens one transaction, deletes in foreign-key-safe order (the same order as `resetAll`), inserts raw rows, writes `onboarding_done` and `debug_mode`, and commits. A failure leaves the previous database untouched.
- **Derived rebuild is best-effort.** If `recalculateAll()` or `ensureCurrent()` throws after the raw commit, debug mode still activates with source data intact; scores and roundups can be rebuilt from the Debug section or the existing Settings "Recalculate" action. The failure is logged, never shown as a crash.
- **Hold timer lifecycle.** The timer is cancelled on pointer up, pointer cancel and widget dispose. Tests never leave pending timers.
- **Double activation.** A guard prevents a second seed while one is running. The confirmation and progress dialogs are dismissed safely if the screen goes away.
- **Exit while a session is running.** The wipe deletes the session with everything else; no recovery banner survives.
- **Notifications.** The existing foreground reconciler sees the table updates and reschedules/cancels notifications from the new dataset. No new notification code.
- **Date boundaries.** Days are local midnights, and day stepping uses calendar construction such as `DateTime(year, month, day + 1)` rather than `Duration(days: 1)`, so DST transitions cannot shift a date. Sessions never extend past their event's day except for a running session, which is never seeded.
- **All builds.** Because the trigger exists in release, the confirmation is mandatory and worded as destructive. There is no silent wipe path.

## 6. Testing

- **Rename:** tests assert `CFBundleDisplayName`/`CFBundleName` are Altidial, bundle id is `com.selfloop.altidial`, `Strings.appTitle` and export subject use Altidial, and no Dart import references `package:energy_clock/`.
- **Generator unit tests:** exactly 90 days ending today; deterministic across two runs with a fixed clock; no day has more than three overlapping events; all past events with sessions have valid instants and durations; future events have no sessions; every area (events, tones, sessions, reflections, projects, tasks, templates, flights, coach, badge unlocks) is non-empty; today contains both completed and planned events.
- **Seeder tests:** an in-memory database is wiped and seeded; row counts match the dataset; scores, progress and roundups are rebuilt; a forced insert failure leaves the prior data intact.
- **Widget tests:** 5.9-second hold does nothing; 6-second hold shows the confirmation; cancel preserves data; confirm calls the seeder and shows the debug section; regenerate runs again; exit wipes and returns to onboarding; the timer is cancelled when the pointer lifts early.
- **Existing tests:** update imports and expected strings for the rename. Goldens should be unchanged in normal mode because the debug section is conditional and the tab bar has no visual change. `no_hardcoded_colors_test` must keep passing.
- **Gates:** `flutter analyze`, `flutter test`, and a manual simulator pass covering hold, seed, navigate every tab, regenerate and exit.

## 7. Build order

1. **Rename** — mechanical package/import/bundle/name changes, update strings and tests; gates green before feature work.
2. **Debug state and trigger** — settings key, provider, six-second hold, confirmation shell, Debug section with empty actions.
3. **Generator** — pure deterministic dataset and unit tests.
4. **Seeder and derived pipeline** — transactional wipe/insert, recalculate, roundups, seeder tests.
5. **Wire actions** — activate, regenerate and exit flows, progress/error UI, widget tests.
6. **Full verification** — `flutter analyze`, `flutter test`, simulator walkthrough, golden check.

## 8. Out of scope

- Real cloud sync, accounts or analytics.
- A general-purpose debug console, feature flags or data inspector.
- Preserving real user data across debug activation; the design is intentionally destructive and confirmed.
- A new app icon or visual rebrand beyond the name and copy.
- Updating historical design specs and implementation plans to the new name.

## 9. Open items

None. Every decision needed for implementation was resolved during brainstorming.
