# Energy Clock — Step 4: Statistics, Progress and Profile — Design

## Summary

Step 4 replaces the two remaining "coming soon" tabs with the finished product:
the **Stats** tab (spec §8) and the **Profile** tab (spec §9), plus the derived
progress engine underneath them. One spec, one plan, roughly 30 tasks.

**What ships:**

- **Stats tab** — week/month period selector; four sections (tone balance,
  planned vs actual, focus depth, hour-of-day heatmap); hand-rolled
  `CustomPainter` charts; a specific empty state per section.
- **Progress engine** — daily streak, 0–100 energy score, XP and levels, ten
  badges; all *derived* from `events` and `sessions`, cached in `day_scores`,
  `progress` and `badge_unlocks`, rebuilt by `recalculateAll()` (spec §9.1).
- **Profile tab** — level and XP, current/longest streak, badge grid (locked
  slots visible), Weekly Roundup archive, and settings: theme, daily focus
  target, first day of week, recalculate-all, data export (JSON via
  `share_plus`), full reset.
- **Weekly Roundup** — generated for finished weeks when Profile is read,
  frozen as a JSON snapshot in `weekly_roundups` (spec §9.6). The
  local-notification announcement arrives in Step 5 on top of the same
  generator.
- **Schema v4** — four new tables, migration step, migration tests, regenerated
  schema dumps.

**What does not ship:** anything `flutter_local_notifications` (roundup
announcement, notification toggles, permission prompts) and the foreground
"next 7 days" scheduling job — all Step 5.

**Citation convention:** two-part numbers (`§4.2`, `§9.6`, `§15`) cite the
master spec (2026-08-23). This document's own sections are single-part
(`§1`…`§14`) or named by heading.

## 1. Context and roadmap

The master spec (2026-08-23) splits the remaining work into Phase 4
(Statistics) and Phase 5 (Progress, Profile, Roundup, settings, export). The
user has chosen to deliver both phases as Step 4 minus notifications:

| | Step 4 (this spec) | Step 5 (deferred) |
|---|---|---|
| Stats tab | ✅ | |
| Score, streak, badges, XP | ✅ | |
| Profile tab, badge grid, roundup archive | ✅ | |
| Weekly Roundup generation | ✅ (on read) | announcement notification |
| Theme, focus target, first day of week | ✅ | |
| Export (JSON) and full reset | ✅ | |
| Notification toggles | | ✅ |
| Roundup/event notification permission + delivery | | ✅ |
| Foreground "next 7 days" event job | | ✅ |

This is deliberately one large plan; the user accepted the review cost. The
plan will stage the work so every stage ends green (analyze clean, suite
passing) even if a later stage stalls.

## 2. Decisions taken

1. **Data access: SQL aggregates + cached progress (approach A).** Stats reads
   each section from grouped SQL over `events ⋈ sessions` for the selected
   window — spec §8's own words. Progress numbers are computed by a pure
   calculator and cached in the progress tables, per §9.1. Rejected: computing
   everything in Dart from streamed rows (memory per paint, aggregation logic
   where SQL already belongs), and a pre-aggregated stats cache (invalidation
   on past-day edits — exactly the cache-drift §9.1 forbids).
2. **One spec, one big plan** covering §8 Statistics + §9 Progress (user's
   choice over splitting into 4a/4b).
3. **Settings shipped on Profile in Step 4:** theme, daily focus target, first
   day of week, export + reset. Notification toggles wait for Step 5.
4. **Roundups generate when read** (Profile/archive build, plus app
   foreground), not on a new scheduler; Step 5 adds the announcement on top.
5. **`share_plus` is the one new runtime package**, already listed in spec
   §15, used only for handing the export JSON to the iOS share sheet.
6. **XP and levels ship** despite the §9.5 gameiness caveat; the caveat is
   recorded as a review note for after Step 5 ships, not a code TODO.

## 3. Amendments to the 2026-08-23 spec

| # | Spec says | Step 4 does | Why |
|---|---|---|---|
| 1 | §9.6 roundup is "generated Sunday evening, announced by a local notification" | Generated lazily when Profile or the archive is read (and on app foreground); notification deferred to Step 5 | Notifications are Step 5; the payload and freeze semantics are unchanged |
| 2 | §9.7 first day of week is a Profile setting; Step 3's plan promised it to Step 5 | Ships in Step 4 | The user's Step 4 scope includes settings |
| 3 | §8/§9 silent on which session minutes count | One pool, below | Must be identical in stats, score and roundups or the numbers disagree |
| 4 | §9.7 Profile settings include notification toggles | Deferred to Step 5 | No notifications yet |

**The minute pool (amendment 3).** Every aggregate — tone minutes (stats
section 1, heatmap, `day_scores.focusMinutes/lifeMinutes/inboxMinutes`), the
score's focus component, the roundup's donut — uses the same pool:
**`activeSeconds` of sessions whose outcome is `completed` or `finishedEarly`**
(the `countsAsDone` set), attributed to `events.date` of the joined event.
Abandoned sessions contribute nothing except the abandonment rate in stats
section 3. Rationale: one explainable rule ("stats count finished work"),
consistent with §9.2's "abandoned sessions do not count", and it stops the
focus-target component being fed by abandoned time. *Planned* minutes are the
sum of event durations (`endMinute - startMinute`) for events whose date is in
the window, regardless of status — a skipped event still counts against
adherence, a deleted one does not exist.

**Period membership.** All four stats queries filter `events.date ∈ [from, to)`
after `SeriesMaterialiser.materialise(from, to)` fills recurring events into
the window (Step 3's requirement). The only exception is the heatmap, which
*filters* by that window but *buckets* by the local hour and weekday of
`sessions.startedAt` — spec §8.4 wants "your real peak hours", i.e. when work
actually happened, not when it was planned.

## 4. Data layer

### 4.1 Schema v4

Four new tables in `lib/data/tables/`, column-for-column with spec §4.2:

**`day_scores`** — `date` (DateTime, PK), `energyScore` int, `adherencePoints`
int, `focusPoints` int, `balancePoints` int, `focusMinutes` int,
`lifeMinutes` int, `inboxMinutes` int, `plannedMinutes` int,
`completedMinutes` int, `computedAt` DateTime.

**`badge_unlocks`** — `badgeId` text PK, `unlockedAt` DateTime.

**`progress`** — single row (`id` int PK with a constant 1): `xp` int, `level`
int, `currentStreak` int, `longestStreak` int, `lastStreakDate` DateTime.

**`weekly_roundups`** — `isoYear` int, `isoWeek` int (composite PK),
`generatedAt` DateTime, `payloadJson` text.

`schemaVersion` → 4 with an `onUpgrade` branch (`if (from < 4)`) creating all
four tables, mirroring v3's style in `lib/data/database.dart:40`. Generated
artifacts (`*.g.dart`, `drift_schemas/drift_schema_v4.json`,
`test/generated_migrations/schema_v4.dart` + `schema.dart`) come from the
standard trio — `build_runner build`, `drift_dev schema dump`,
`drift_dev schema generate` — run with the Flutter SDK's bundled `dart`, never
the PATH `dart` (Step 3's tooling note). `test/data/migration_test.dart` grows
`version 1/2/3 upgrades to version 4` and data-preservation cases; the
existing v3 tests retarget to v4.

### 4.2 Settings storage

`SettingsDao` already stores arbitrary strings; extend
`SettingsRepository` (`lib/data/repositories/settings_repository.dart`) with
`getString/setString(key, {defaultValue})` and `getInt/setInt(key,
{defaultValue})` (ints stored as decimal text). `getBool/setBool` unchanged.
`FakeSettingsRepository` gains the same methods. New keys:

| Key | Type | Default | Values |
|---|---|---|---|
| `theme_mode` | string | `system` | `system` / `light` / `dark` |
| `daily_focus_target` | int | `180` | minutes, 30–480 in steps of 30 |
| `first_day_of_week` | int | `1` | `1` (Monday) or `7` (Sunday) |

### 4.3 Stats queries — `StatsDao`

One DAO (`lib/data/daos/stats_dao.dart`), four queries, each taking
`(DateTime from, DateTime to)` and assuming the window has been materialised.
Following `CalendarRepository.watchMonth`, the repository that wraps it
materialises first and tolerates a failed expansion the same way — a broken
series expansion shows the period as stored rather than blanking the screen:

1. **`toneMinutesByDay`** → `(date, toneIndex, minutes)`: `SUM(activeSeconds)/60`
   grouped by day-of-`events.date` and `toneIndex`, `countsAsDone` outcomes
   only. Feeds the stacked bars and the period donut.
2. **`plannedByTone`** → `(toneIndex, plannedMinutes, completedMinutes)`:
   event minutes vs `countsAsDone` session minutes per tone for the window.
   Feeds the paired bars and the adherence headline (window-wide
   `completed / planned`, capped at 1.0 for display, division by zero → null).
3. **`focusDepth`** → one row over ended Focus-tone sessions joined to
   windowed events: `SUM/MAX/AVG` of `activeSeconds` over `countsAsDone`
   outcomes (total minutes, longest, average), plus
   `SUM(outcome = abandoned) / COUNT(*)` for the abandonment rate. The
   headline numbers obey the minute-pool rule; abandoned time appears only as
   the rate, which is this section's whole view of failure.
4. **`heatmapFocus`** → `(startedAt, activeSeconds)` for `countsAsDone`
   Focus sessions joined to windowed events. **Bucketing into the 7×24
   (weekday, hour) matrix happens in Dart, not SQL**: Drift stores `DateTime`
   as epoch seconds, and the buckets must be local wall-clock time — a SQLite
   `strftime` on epoch values would bucket in UTC and misplace every session
   across timezones and DST.

The DAO returns plain model rows (`lib/features/stats/model/*.dart`), no
widgets. Tests: `test/data/stats_dao_test.dart` against
`AppDatabase.forTesting` with hand-inserted events/sessions, including a
recurring series that must appear after materialisation.

### 4.4 ProgressCalculator — `lib/features/progress/`

A pure Dart engine, no Drift imports: given plain rows (day aggregates,
qualifying-day list, session rows, unlocked badge ids) it returns
`DayScore`, `ProgressSnapshot`, and badge evaluations. Functions:

- `scoreFor(day)` → spec §9.3: adherence 0–50
  (`completed/planned` capped 1.0, 0 when planned is 0), focus 0–30
  (`focusMinutes / target` capped 1.0), balance 0–20 (20 when all three tones
  present and max tone share ≤ 70%, otherwise scaled proportionally), total
  rounded to 0–100. No planned events → all components 0.
- `streaks(qualifyingDates)` → §9.2: consecutive local days with ≥1
  `countsAsDone` session. `currentStreak` is the run ending today, or the run
  ending yesterday when today has no qualifying session yet (the day hasn't
  passed); a missed day zeroes it. `longestStreak` keeps the historical max.
- `xp(sessions, unlockedBadges, qualifyingDates)` → §9.5: 1 XP per
  `countsAsDone` session minute ×1.5 for Focus (rounded at the end), +50 per
  badge unlock, +5 for each qualifying day beyond the first seven of each
  streak run.
- `levelFor(xp)` → widening curve: `xpToReachLevel(L) = 100·(L−1)·L / 2`
  (level 1 at 0, 2 at 100, 3 at 300, 4 at 600 — each step costs 100 more).
- `badgesToUnlock(history, now)` → §9.4's ten static definitions:

| id | Criterion |
|---|---|
| `first_session` | ≥1 ended session |
| `sessions_10` / `sessions_50` / `sessions_100` | ≥10 / 50 / 100 ended sessions |
| `focus_day_4h` | one day with ≥240 `countsAsDone` Focus minutes |
| `week_all_tones` | one Monday–Sunday week with `countsAsDone` minutes in all three tones |
| `streak_7` / `streak_30` | a streak run of ≥7 / ≥30 days |
| `week_no_abandoned` | one Monday–Sunday week with ≥1 `countsAsDone` session and 0 abandoned |
| `early_bird` | a Focus session that started before 08:00 local |

Definitions are `const` records in
`lib/features/progress/badges.dart` (id, title, description, predicate) —
stable ids because `badge_unlocks` persists them. Evaluation never unlocks
twice; locked slots still render on Profile (§9.4).

### 4.5 ProgressRepository and when recalculation runs

`lib/data/repositories/progress_repository.dart` wraps a small
`ProgressDao` and owns the read-modify-write:

- **After a session ends** (any outcome): recompute the *event's date's*
  `day_scores` row, re-evaluate badge candidates, recompute streaks/XP/level.
  The provider layer invokes this after `SessionRepository` completes its
  write (repositories stay persistence-only, per Step 2's layering).
- **On day rollover** (app foregrounded on a new local day, or a screen read
  after midnight): finalise yesterday's `day_scores`, then streaks/badges.
- **On Profile read and on app foreground**: `ensureFresh()` — finalise
  yesterday's row if the local day has rolled over (streams alone never emit
  at midnight), then recompute today's row if it predates today. The Stats tab
  does not call it: its numbers come from the live queries, not
  `day_scores`.
- **Past-day edits are never silently recomputed** (§9.3). Editing a March
  event in March updates nothing in `day_scores` until
  **`recalculateAll()`**, which rebuilds every `day_scores` row, then
  streaks, badges, XP and level from source rows. It is exposed as a
  Profile row, not called automatically.

## 5. Stats screen

### 5.1 Period model

`StatsPeriod` — `week` or `month` plus a **week start** or **month anchor**:

- **Week**: 7 days starting on `first_day_of_week` (setting, default Monday),
  anchored to the current week by default. Prev/next chevrons step ±7 days;
  tapping the label ("5–11 October 2026") returns to the current week.
- **Month**: the calendar month; chevrons step ±1 month; label
  ("October 2026"); tapping it returns to the current month.

State lives in `statsPeriodProvider` (plain `Notifier`), so tab switches keep
the period (TabScaffold keeps tabs alive).

### 5.2 The four sections

Section order and content follow spec §8, one `AppCard` each, title via
`SectionHeader`:

1. **Tone balance** — a stacked bar per day (7 or 28–31 thin columns, one
   stack per day, segments by tone using `TonePalette.solid`) plus a donut for
   the whole period, and a legend of hours + percentage per tone
   (`12h 30m · 45%`). Painters: `stacked_bars_painter.dart`,
   `donut_painter.dart`.
2. **Planned vs actual** — the adherence percentage as a large figure
   ("86% adherence"), then paired bars per tone (planned vs completed
   minutes, planned drawn in the tone's `soft`/outline style, completed in
   `solid`). Painter: `paired_bars_painter.dart`.
3. **Focus depth** — four metric tiles: total focus hours, longest unbroken
   focus session, average focus session, abandonment rate (percentage, shown
   as `—` when the denominator is 0). Text tiles, no painter.
4. **Hour-of-day heatmap** — 7 weekday rows × 24 hour columns, cell alpha
   scaled to focus minutes in the period (0 = hairline `outline`, 1 = `solid`
   Focus tone), weekday initials as row labels, hour ticks at 0/6/12/18/24.
   Painter: `heatmap_painter.dart`.

Charts are `CustomPainter`s reusing the dial's painter conventions
(`shouldRepaint` on data change, colours from theme/tone extensions, no
animation on first paint). No charting package (spec §15).

**Empty states** — each section gets its own invitation when its query returns
no rows, rendered in place of the chart (exact copy in the plan):
tone balance → "Run your first session to see where your focus goes";
planned vs actual → "Plan a day and come back to see how it went"; focus
depth → "Your longest session will show up here"; heatmap → "A week of focus
sessions reveals your peak hours". A period with zero materialised events
shows all four empty states, never a zeroed axis (§8 "Empty states").

### 5.3 Layout

- **Narrow**: single scrollable column — period header, then the four cards.
- **Medium/wide**: `ContentWidth(maxWidth: 800)`; tone balance and
  planned-vs-actual side by side in the top row, focus depth and heatmap full
  width below. Heatmap always gets the full content width.

Layout mirrors Calendar/Clock: computed in `lib/features/stats/stats_layout.dart`
from the window class, unit-tested by a layout-matrix test at the same widths
Step 3 used (375, 390, 430, 600, 768, 1024, 1366).

### 5.4 Loading, errors, semantics

`statsDataProvider` is a `StreamProvider.family` keyed by the resolved
`(from, to)` window — the repository materialises the window inside the stream
(like `CalendarRepository.watchMonth`) and the four queries emit whenever an
event or session changes, so a session ending repaints Stats without any
provider plumbing. Loading shows card-shaped placeholders; an error replaces
the screen body with the existing failure pattern
(`Strings.loadFailed` style) plus a retry button. Each card exposes a
`Semantics` summary ("Tone balance: 12 hours focused, 4 hours body, 2 hours
inbox") so the charts are never the only way to get the numbers; painters are
`SemanticsTraversal`-excluded.

## 6. Progress screen (Profile)

`ProfileScreen` becomes a scrollable stack of `AppCard`s (narrow and wide
alike, `ContentWidth(maxWidth: 600)`):

1. **Header card** — level as the headline ("Level 4"), an XP progress bar to
   the next level with `320 / 600 XP` beneath, then current and longest
   streak as text ("12-day streak · best 30", using the existing ring mark as
   the streak glyph — no emoji). Empty state (no sessions): "Finish a
   session to start your streak."
2. **Energy score card** — today's score 0–100 with the three component rows
   (adherence / focus / balance as `50 / 50` style figures) per §9.3's
   "breakdown, not just the total". Tapping expands the component definitions.
3. **Badge grid** — `Wrap` of ten slots, unlocked badges in tone colour with
   title + unlock date, locked slots as dimmed outlines with the title hidden
   ("?" slot) so the set stays discoverable (§9.4).
4. **Roundup archive** — newest first: "Week 40 · 29 Sep – 5 Oct" rows; each
   opens the frozen snapshot view (§7 above). Empty: "Your first roundup
   appears on Monday."
5. **Settings card** — rows built from the shared adaptive controls:
   - **Theme** → `chooseOne` (System / Light / Dark), writes `theme_mode`;
     `app.dart` watches the provider instead of the hardcoded
     `ThemeMode.system` (app.dart:20).
   - **Daily focus target** → `chooseOne` of 30…480 step 30 (default 180),
     writes `daily_focus_target`; the score's focus component reads it.
   - **First day of week** → `chooseOne` Monday / Sunday, writes
     `first_day_of_week`; see Settings behaviour below.
   - **Recalculate all** → confirm, run `recalculateAll()`, show completion.
   - **Export data** → Export below.
   - **Erase everything** → destructive `confirmDestructive` (existing
     adaptive helper): wipes every table *including* `settings`, so
     `onboarding_done` clears and the app returns to onboarding like a fresh
     install. No partial resets.

Wording for all rows lives in `lib/core/strings.dart`.

## 7. Weekly Roundup

### 7.1 Generation on read

`roundupArchiveProvider` runs `ensureCurrent()` (Profile/archive read, and app
foreground):

1. Determine the last **fully finished** Monday–Sunday week (independent of
   the first-day setting, §9.6).
2. For each finished week since the earliest session date that has no
   `weekly_roundups` row: generate one. Weeks before any data are skipped.
3. Generated rows are never rewritten — reopening week 34 next March reads
   `payloadJson` as frozen (§9.6). A row is only skipped, never refreshed.

Step 5 will call the same generator from its notification job.

### 7.2 Payload (frozen JSON)

```json
{
  "isoYear": 2026, "isoWeek": 40,
  "rangeStart": "2026-09-29", "rangeEnd": "2026-10-05",
  "toneMinutes": {"focus": 720, "life": 180, "inbox": 240},
  "adherence": 0.86,
  "bestFocusDay": {"date": "2026-10-01", "minutes": 210},
  "streak": {"current": 12, "longest": 20},
  "badges": [{"id": "streak_7", "unlockedAt": "2026-10-03T18:04:00Z"}],
  "xpGained": 815,
  "previousWeek": {"focusMinutes": 640, "adherence": 0.78}
}
```

`xpGained` sums the week's session XP + that week's badge unlocks + streak
bonuses accrued that week (all derivable per-week). `previousWeek` is the
prior week's focus minutes and adherence for the comparison card; absent for
the first week. Times in UTC ISO-8601, dates as local `yyyy-MM-dd`.

### 7.3 Presentation

The snapshot view renders the §9.6 card stack top to bottom: tone donut
(reusing the Stats donut painter), adherence, best focus day, streak status,
badges earned this week, XP gained, previous-week comparison (deltas in
tone-neutral wording: "25% more focus than last week"). Generated presentation
is read-only; no pull-to-refresh.

## 8. Settings behaviour

- **Theme** — `themeModeProvider` (AsyncNotifier over `theme_mode`), watched
  by `EnergyClockApp`; switching is instant and survives restart.
- **Daily focus target** — read synchronously by the score calculator via a
  provider; changing it does *not* silently rescore past days (§9.3); today's
  row refreshes on next `ensureFresh()`.
- **First day of week** — the cross-cutting one. The stored weekday threads
  through `daysOfWeek()` (`day_time.dart:79`), the month grid's leading-day
  calculation (`month_time.dart:22`), the WeekStrip anchor, and the Stats
  week period. Concretely: these helpers take a `firstWeekday` parameter
  (default `DateTime.monday`) fed by a `firstDayOfWeekProvider`; call sites
  are updated. Calendar month grids re-layout when the setting changes.
  **The Roundup's Monday–Sunday week does not change** (§9.6). Tests for the
  Sunday variant are added alongside the existing `month_time` /
  `week_strip` tests.
- **Export** — see Export below.
- **Recalculate all** — the `recalculateAll()` path described under
  ProgressRepository above.

## 9. Export

`ExportRepository.build()` serialises every table plus metadata:

```json
{
  "app": "energy_clock", "schemaVersion": 4,
  "exportedAt": "2026-10-07T09:12:00Z",
  "events": [...], "eventSeries": [...], "sessions": [...],
  "dayTemplates": [...], "dayTemplateItems": [...],
  "dayScores": [...], "badgeUnlocks": [...], "progress": {...},
  "weeklyRoundups": [...], "settings": {...}
}
```

Column names are the Drift row names serialised through a hand-written mapper
(no `dart:convert` surprises: dates as ISO-8601 strings, booleans as ints
matching the DB). The file is written to
`path_provider`'s temporary directory as `energy-clock-export.json` and handed
to `SharePlus.instance.share(ShareParams(files: [XFile(path)]))` — the exact
`share_plus` API is pinned in the plan after checking the installed version.
Sharing is behind a thin `ShareService` interface so widget tests inject a
fake and assert on the generated JSON, not the platform channel.

## 10. State and providers

| Provider | Feature | Kind | Feeds |
|---|---|---|---|
| `statsPeriodProvider` | stats | `Notifier<StatsPeriod>` | header, cards |
| `statsWindowProvider` | stats | derived `(from, to)` | materialise + queries |
| `statsDataProvider` | stats | `StreamProvider.family` (materialises, then watches) | the four sections |
| `progressProvider` | progress | `StreamProvider` over `progress` + today's `day_scores` | Profile header, score card |
| `badgesProvider` | progress | derived | badge grid |
| `roundupArchiveProvider` | progress | `StreamProvider` (ensures current, then watches) | archive list |
| `themeModeProvider` / `focusTargetProvider` / `firstDayOfWeekProvider` | progress (settings) | `AsyncNotifier`s | app theme, score, week layout |

Existing providers gain nothing; the session-end hook is a
`ref.listen`-style side effect in `session/providers.dart` after the outcome
write succeeds. Stream over the tables (Drift `watch`) rather than explicit
invalidation, so every screen stays consistent without provider plumbing.

## 11. Accessibility and theming

Every figure is text, not just painted pixels; charts carry `Semantics`
summaries (see Loading, errors, semantics above). Tone colours come from the existing `TonePalette`
(`solid`/`soft`/`deep`, `onSolid` pairs) so light/dark contrast is inherited
rather than re-derived; heatmap cells sit on `outline`-to-`solid` alpha
interpolation, never below the hairline contrast of existing chart chrome.
All copy is in `lib/core/strings.dart` with format helpers following the
`Strings.nowTimeLeft` pattern (`Strings.streakDays(int)`,
`Strings.xpProgress(int, int)`, …), covered by `strings_test.dart`.
Focus order: period header → sections in visual order → Profile rows; no
trapped focus; every icon button has a semantic label
(`Strings.stepperDecrease` pattern).

## 12. Error handling and edge cases

- **No data at all** (fresh install): every stats section shows its empty
  state; Profile shows the empty header ("Finish a session to start your
  streak"), zero-level badge grid, empty archive, working settings. Nothing
  crashes, nothing shows a zeroed axis.
- **Query failure** (locked DB, migration miss): stats body becomes the retry
  card; Profile renders what loaded and a per-card retry for the rest.
- **Division by zero**: adherence null when planned = 0; abandonment `—` when
  no ended focus sessions; heatmap cells absent, not zero-height.
- **Running/paused sessions** are excluded from every pool (`countsAsDone`
  never includes `running`), so a session in flight changes no numbers until
  it ends.
- **Timezones/DST**: day buckets and streaks use local calendar dates
  (`events.date`, `DateTime(y, m, d)` arithmetic) like the rest of the app;
  heatmap hours use the local hour of `startedAt`. A DST day still has one
  row; a 25-hour day's sessions land in their wall-clock hour.
- **Cross-midnight sessions** belong to their event's date for period
  membership; the heatmap uses their start hour (23:50 counts as hour 23).
- **Badge stability**: ids are `const`; a rename would orphan unlocks, so the
  plan's badge table is treated as append-mostly and covered by a test that
  asserts the id set.
- **`recalculateAll()` cost**: full rebuild over all rows; run behind a
  confirm dialog with a progress indicator; at realistic data sizes (< 5
  years of sessions) this is a single-digit-seconds operation worst case.
- **Export failures**: share sheet dismissed or temp file unwritable →
  inline error snackbar, no partial file left behind (temp file deleted in a
  `finally`).

## 13. Testing and verification

Mirror Steps 1–3 exactly: unit tests first, `flutter analyze` clean,
`dart format --output=none --set-exit-if-changed lib test` clean, full
`flutter test` green, goldens generated on this machine and reviewed by
reading the PNGs (they render CupertinoIcons as tofu here — pre-existing
baseline, see Step 3's note).

| Area | Test files |
|---|---|
| Schema v4 migration | `test/data/migration_test.dart` (v1/2/3 → v4, data kept) |
| Stats SQL | `test/data/stats_dao_test.dart` (four queries, materialised recurrence, empty window) |
| Settings storage | `test/data/settings_test.dart` (+ int/string round-trips, fakes) |
| Progress engine | `test/features/progress/progress_calculator_test.dart` (score caps, no-plan day, balance scaling, streak run/grace/break, XP rates + bonuses, level curve, each badge criterion, id set) |
| Repository hooks | `test/data/progress_repository_test.dart` (session-end recalc, ensureFresh, past-day immutability, recalculateAll) |
| Roundups | `test/features/progress/roundup_generator_test.dart` (payload shape, first week, freeze: later data doesn't rewrite a stored week) |
| Export | `test/features/progress/export_test.dart` (JSON shape, fake share service, failure path) |
| Stats UI | `test/features/stats/stats_screen_test.dart`, `stats_layout_matrix_test.dart`, `stats_screen_golden_test.dart` (week populated / month / empty) |
| Profile UI | `test/features/profile/profile_screen_test.dart`, `profile_screen_golden_test.dart` (levels, badge locked/unlocked, settings rows, empty state) |
| First-day-of-week | extensions of `month_time_test.dart`, `week_strip_test.dart`, new `first_day_of_week_test.dart` |
| Strings | `test/core/strings_test.dart` additions |

Layout-matrix widths: 375, 390, 430, 600, 768, 1024, 1366 (Step 3's set).
Manual iOS walkthrough (simulator) is again deferred: this Windows machine has
no iOS simulator; the plan ends with the same hand-off note as Step 3 Task 21.

## 14. Build order, risks, scope

### Build order (for the plan to cut into ~30 tasks)

1. **Schema** — four tables, v4 migration, generated dumps, migration tests.
2. **Settings storage** — `getString/getInt` + fakes + tests.
3. **Stats data** — materialise window, `StatsDao` queries, model rows, DAO
   tests.
4. **Stats UI** — period header, four painters, four sections, empty states,
   layout matrix, widget + golden tests.
5. **Progress engine** — score, streak, XP/level, badges as pure functions +
   tests.
6. **Progress data** — `ProgressDao`/repository, session-end hook,
   rollover/ensureFresh, recalculateAll + tests.
7. **Roundups** — generator, dao, generate-on-read, freeze tests.
8. **Profile UI** — header, score card, badge grid, archive, snapshot view,
   widget + golden tests.
9. **Settings wiring** — theme, focus target, first-day threading (week strip,
   month grid, week helpers) + tests.
10. **Export and reset** — `share_plus`, JSON mapper, fake share service,
    destructive reset + tests.
11. **Polish** — semantics, strings, README feature line update, format,
    analyze, full suite, goldens reviewed, staged commits per stage.

### Risks

- **Plan size.** ~30 tasks is the largest yet; mitigated by stage gates where
  every stage ends green and commits are staged (Steps 1–3's pattern).
- **First-day-of-week is cross-cutting.** Touching `daysOfWeek`, the month
  grid and WeekStrip can regress existing tests; the setting is threaded with
  default-preserving parameters and Sunday-specific tests added early (stage 9
  lands before polish).
- **`share_plus` API drift.** The API has renamed across majors; the plan
  pins the version from `pubspec.lock` at execution time behind `ShareService`.
- **Golden noise.** New goldens inherit the tofu-icon baseline; review by
  reading PNGs, never by blindly accepting diffs.
- **Numbers must agree.** Stats, score and roundups share one minute pool
  (amendment 3) and one window rule; the calculator and DAO tests cross-check the same
  fixture.

### Out of scope (Step 5 and later)

- All notifications: roundup announcement, event lead-time, permission
  prompts, and the notification toggles on Profile.
- The foreground "next 7 days" materialisation job — already deferred by
  Step 3's plan, and named for Step 5 there.
- Chart interactivity (tooltips, tap-to-inspect), trends beyond the selected
  period, per-event stats, widget/watch targets, iPad-specific Stats/Profile
  experiments beyond the layout matrix.

### Dependencies

- **New runtime package:** `share_plus` (spec §15). Nothing else; still no
  charting library, no HTTP, no analytics.
- **Dev tooling:** unchanged — Flutter SDK's `dart` for `build_runner` /
  `drift_dev`; `rg` unavailable on this machine (use the grep tool).

### Open items for the plan

- Exact copy for empty states, settings rows, badge titles/descriptions and
  the score-component explainer.
- Exact golden names and which of the three stats goldens vs two profile
  goldens are worth the maintenance.
- `share_plus` version pin and the current API call shape.
- Whether the Profile score card expands inline or opens an adaptive dialog.
