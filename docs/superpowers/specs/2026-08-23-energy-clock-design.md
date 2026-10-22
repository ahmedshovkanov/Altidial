# Energy Clock — Design Spec

**Date:** 2026-08-23
**Status:** Approved for planning
**Platform:** iOS (iPhone, portrait, iOS 15+), Flutter 3.44.7 / Dart 3.12.2

---

## 1. Product summary

Energy Clock is a task and time manager that organises a day by **cognitive
load** rather than by clock time. The user places events on orbits around a
24-hour dial and assigns each one a **tone**. Reading the orbit tells the user
what kind of day they have committed to before they read a single word.

Tapping an event starts a **session**: the dial is replaced by a countdown timer
for that event. Completed sessions feed statistics, a daily energy score, a
streak, badges, XP, and a Weekly Roundup.

### The three tones

Tones are fixed. There are exactly three, they cannot be added to, removed,
renamed, or recoloured.

| Tone | Colour | Meaning | Examples |
|---|---|---|---|
| Focus | Purple | Demanding intellectual work | Deep work, writing, design |
| Life | Green | Body and rest | Sport, walking, lunch |
| Inbox | Orange | Routine and reactive work | Calls, email, admin |

The fixed set is a product decision, not a limitation. Three tones is what makes
a day's load legible at a glance, and it keeps statistics, scoring, and badges
comparable across all users and all time.

### Language

The app is **English-only**. All user-facing copy is in English. No localisation
framework in this version; strings live in a central constants file so
localisation stays possible later.

---

## 2. Decisions taken

These were settled during brainstorming and are not open in planning.

| Area | Decision |
|---|---|
| App name | Energy Clock |
| Data | Local-only, on-device. No account, no backend, no sync. |
| Calendar integration | None. Self-contained; no EventKit, no permission prompt. |
| Dial | 24-hour, midnight at top, clockwise. Whole day visible at once. |
| Visual language | Follows `image.png` in the repo root: light airy face, thin ticks, large numerals, thick rounded arc "pills" orbiting outside the dial, label text curved along each arc. |
| Colour meaning | Colour always encodes tone. Never per-event colour. |
| Overlaps | Allowed. Overlapping events render on nested rings, up to 3 rings. |
| Event creation | Press-and-drag a sector on the orbit, then a details sheet. A `+` button opens the same sheet. |
| Cross-midnight events | Not allowed. Drag clamps at end of day (`endMinute` 1440). |
| Session timer | Counts down from planned duration, then counts up in overtime. |
| Session controls | Pause/resume, finish early, abandon, extend +5/+15. |
| Backgrounding | Wall-clock arithmetic plus a scheduled local notification. No background execution, no Live Activity. |
| Reuse tools | All three: recurring events, day templates, copy-yesterday. |
| Calendar screen | Month grid with per-day tone rings. |
| Tabs | Clock · Calendar · Stats · Profile |
| Theme | Light and dark, following the iOS setting, with a manual override. |
| Notifications | Session ended, event starting soon, Weekly Roundup ready, daily planning reminder. |
| Stack | Riverpod (state) + Drift (typed SQLite) + CustomPainter (dial and charts). |

### Explicitly out of scope

- Any backend, account system, or cross-device sync
- Apple Calendar / EventKit integration in either direction
- Live Activities, Dynamic Island, home-screen widgets, Apple Watch
- Android, iPad, macOS, and web targets
- Localisation beyond English
- Sharing or exporting to social platforms

---

## 3. Architecture

### 3.1 Directory structure

```
lib/
  main.dart
  app/
    app.dart               root widget, theme mode wiring
    theme/                 light and dark ThemeData, tone palette
    navigation/            tab scaffold, routes
  core/
    time/                  day boundaries, minute-of-day helpers, DST-safe math
    geometry/              DialGeometry: polar math, hit testing, ring layout
    format/                duration and date formatting
    result.dart            typed success/failure wrapper
  data/
    database.dart          Drift database definition
    tables/                table definitions
    daos/                  one DAO per aggregate
  features/
    clock/                 dial screen, painter, drag-to-create, event sheet
    session/               session screen, timer controller, notifications
    calendar/              month grid, day rings, reuse tools
    stats/                 period selector, four stat sections, chart painters
    progress/              streak, energy score, badges, XP, Weekly Roundup, profile
  shared/
    widgets/               buttons, sheets, empty states, tone chips
```

**Boundary rule:** no file under `features/<a>/` may import from
`features/<b>/`. Cross-feature communication goes through repositories exposed
as Riverpod providers. This keeps each feature independently readable and
testable, and keeps individual files small enough to reason about whole.

### 3.2 State management

Riverpod. The three pieces of shared derived state — the current day's events,
the running session, and the progress totals — are exactly the dependency graph
Riverpod is built for. Controllers are `AsyncNotifier` subclasses; repositories
are plain classes provided by `Provider`.

### 3.3 Persistence

Drift over SQLite. Chosen because every statistic in Section 7 is an aggregation
over potentially months of rows. In SQL each is one grouped query; in a document
store each becomes a Dart loop over the full table that degrades as the app is
used. Drift additionally gives compile-time-checked queries and a first-class
migration path, which matters once real user data exists on device.

Migrations are versioned from schema v1 onward. Every schema change ships with a
migration step and a migration test.

---

## 4. Data model

### 4.1 `Tone` — code, not data

```dart
enum Tone { focus, life, inbox }
```

Each carries a label, a light-mode colour, a dark-mode colour, and a stable
integer index persisted in the database. No tones table exists.

### 4.2 Tables

**`event_series`** — the recurrence *rule*.

| Column | Type | Notes |
|---|---|---|
| `id` | int PK | |
| `title` | text | |
| `toneIndex` | int | |
| `startMinute` | int | 0–1439, minute of day |
| `endMinute` | int | 1–1440, exclusive; must exceed `startMinute` |
| `recurrenceKind` | int | none / daily / weekdays / customMask |
| `weekdayMask` | int | 7-bit mask, Monday = bit 0 |
| `validFrom` | date | |
| `validUntil` | date? | null = open-ended |
| `createdAt` | datetime | |

**`events`** — concrete occurrences. One row per event per date.

| Column | Type | Notes |
|---|---|---|
| `id` | int PK | |
| `seriesId` | int? FK | null for one-off events |
| `date` | date | local calendar date |
| `title` | text | |
| `toneIndex` | int | |
| `startMinute` | int | 0–1439 |
| `endMinute` | int | ≤ 1440, clamped at midnight |
| `status` | int | planned / completed / skipped |
| `createdAt` | datetime | |
| `updatedAt` | datetime | |

Indexed on `(date)` and `(seriesId, date)`.

**`sessions`**

| Column | Type | Notes |
|---|---|---|
| `id` | int PK | |
| `eventId` | int FK | |
| `startedAt` | datetime | absolute UTC instant |
| `endedAt` | datetime? | null while running |
| `plannedSeconds` | int | duration at session start, updated by extends |
| `pausedSeconds` | int | accumulated |
| `pauseStartedAt` | datetime? | non-null while paused |
| `activeSeconds` | int | final recorded active time |
| `overtimeSeconds` | int | time past planned end |
| `outcome` | int | running / completed / finishedEarly / abandoned |

**`day_templates`** — `id`, `name`, `createdAt`.

**`day_template_items`** — `id`, `templateId` FK, `title`, `toneIndex`,
`startMinute`, `endMinute`.

**`day_scores`** — cached, always recomputable.
`date` PK, `energyScore`, `adherencePoints`, `focusPoints`, `balancePoints`,
`focusMinutes`, `lifeMinutes`, `inboxMinutes`, `plannedMinutes`,
`completedMinutes`, `computedAt`.

**`badge_unlocks`** — `badgeId` (text, matches a code-side definition) PK,
`unlockedAt`.

**`progress`** — single row.
`xp`, `level`, `currentStreak`, `longestStreak`, `lastStreakDate`.

**`weekly_roundups`** — `isoYear` + `isoWeek` composite PK, `generatedAt`,
`payloadJson`. The payload is a **frozen snapshot**: reopening an old week shows
what the roundup said when generated, not a recomputation.

**`settings`** — `key` text PK, `value` text.

### 4.3 Recurrence by materialisation

The single most important simplification in the design.

When a day is opened — or when notifications are scheduled for an upcoming
window — any `event_series` covering that date that has not yet produced a row
in `events` is expanded into one. From that point on, every downstream consumer
reads plain `events` rows and contains **no recurrence logic at all**.

- Editing one occurrence edits its `events` row. `seriesId` is retained so the
  origin stays traceable.
- "Edit all future" rewrites the `event_series` row and deletes
  not-yet-past materialised rows from tomorrow onward, which re-expand on next
  view with the new values.
- Deleting one occurrence deletes its row; the series still exists, so the
  deletion must be recorded to prevent re-expansion. A deleted occurrence is
  kept as a row with `status = skipped` rather than removed.

Materialisation is idempotent and confined to one function,
`SeriesMaterialiser.materialiseDay(date)`.

### 4.4 Overlap rings are computed, never stored

Ring assignment happens at render time: sweep the day's events sorted by
`startMinute`, assigning each the innermost ring not occupied at that moment.
Storing the ring index would let the database drift out of sync with what is
actually drawable.

Maximum 3 rings. A drag that would require a fourth is refused with the message
"Up to three overlapping events."

---

## 5. Clock screen

### 5.1 Dial geometry

- One full rotation is 1440 minutes. Midnight at the top, running clockwise.
- `angle = minute / 1440 * 360°`, and the inverse maps a touch point to a minute.
- The dial face carries hour ticks, numerals every three hours (0, 3, 6 … 21),
  and a single "now" hand. The centre shows the current time and the tone
  currently in effect.
- Event arcs occupy a band outside the face. Ring 0 hugs the dial; each overlap
  pushes one ring outward.

All polar math lives in `DialGeometry`, a pure Dart class with no Flutter
dependency beyond `Offset`/`Size`. This is the primary unit-test target —
testing math is trivial where testing a painter is not.

`DialPainter` draws face, ticks, numerals, now-hand, arcs, and curved arc
labels. Label text follows the arc; when an arc is too short to fit its title,
the label is omitted from the arc and the event is identified by tap instead.

### 5.2 Creating an event

1. Press and drag within the orbit band outside the face.
2. A ghost arc follows the finger, snapping to 5-minute increments with a light
   haptic tick per snap. The dial centre live-displays the swept range.
3. Minimum duration is 15 minutes. A shorter drag snaps up to 15.
4. A drag crossing midnight clamps at the end of the day, `endMinute` 1440.
5. On release, a modal sheet opens: title field, three large tone buttons,
   start/end steppers for precise adjustment, and a repeat option.

A `+` button in the nav bar opens the same sheet pre-filled with the next free
slot, for when dragging is impractical.

### 5.3 Editing

- Tap an arc to open a detail sheet: **Start session**, Edit, Delete.
- Drag an arc's middle to move it; drag either end to resize it.
- All changes persist immediately. No save button and no dirty state.
- Past days are read-only. Today and future days are editable.

### 5.4 Empty day affordances

An empty, editable day shows **Copy yesterday** and **Apply template** buttons
beneath the dial, alongside the invitation to drag out a first event.

---

## 6. Session

### 6.1 Presentation

Starting a session replaces the dial with a session view: a large countdown ring
in the event's tone colour, the event title above it, remaining time inside.
Controls: pause/resume, +5, +15, Finish early, Abandon.

### 6.2 Timing model

Timing is **pure wall-clock arithmetic**. The session row stores `startedAt`
(absolute instant), accumulated `pausedSeconds`, and `pauseStartedAt` while
paused. Remaining time is recomputed from the system clock on every tick and on
every return to the foreground.

Consequences: the timer cannot drift, cannot be broken by iOS suspending the
app, and requires no background execution entitlement.

A local notification is scheduled for the planned end instant, and rescheduled
whenever the session is paused, resumed, or extended.

### 6.3 Overtime

At zero the ring switches to an overtime style and counts up in red until the
user finishes. Overtime is recorded in `overtimeSeconds` so planned-versus-actual
statistics reflect reality rather than intention.

### 6.4 Outcomes

| Outcome | Recorded | Counts toward streak | Earns XP |
|---|---|---|---|
| Completed (ran to planned end or beyond) | yes | yes | yes |
| Finished early | yes, with actual duration | yes | yes, for actual minutes |
| Abandoned | yes, marked abandoned | no | no |

Finishing writes the `sessions` row, sets the event's `status`, and triggers
recalculation of that day's score, the streak, XP, and badge evaluation.

### 6.5 Failure handling

- **Notification permission denied.** Sessions work correctly; only the end
  alert is lost. A one-time banner explains this and links to Settings.
- **App killed mid-session.** On next launch the running session is detected in
  the database and the user is offered resume or close-out, with elapsed time
  computed from `startedAt`.
- **Device clock changed backwards.** Elapsed time is floored at zero rather
  than going negative, and the session is closed out at its recorded values.

---

## 7. Calendar

- Month grid. Each day cell renders a miniature ring showing that day's tone
  balance, so a month's character is visible without reading numbers.
- Horizontal swipe between months.
- Tapping a day opens the Clock tab focused on that date.
- Today is highlighted. Future days are editable; past days are read-only.

### Reuse tools

**Recurring events.** Configured in the event sheet: daily, weekdays, or a
custom weekday picker, with an optional end date. Editing an occurrence prompts
"This event" or "This and all future".

**Day templates.** Saved from a day's overflow menu as a named template.
Applied to an empty day from a picker. Applying a template to a non-empty day is
not offered.

**Copy yesterday.** A single button, shown only on an empty editable day, that
duplicates the previous day's events.

---

## 8. Statistics

One scrollable screen with a week/month period selector at the top. Each section
is backed by a single grouped SQL aggregate over `events` joined to `sessions`.

1. **Tone balance** — a stacked bar per day, plus a donut for the whole period,
   with hours and percentages per tone.
2. **Planned vs actual** — adherence percentage (planned minutes that became
   completed sessions) and paired bars per tone comparing planned to actual.
3. **Focus depth** — total focus hours, longest unbroken focus session, average
   focus session length, and abandonment rate.
4. **Hour-of-day heatmap** — weekday rows against 24 hour columns, cell
   intensity from accumulated focus minutes. Reveals the user's real peak hours.

### Charts

Hand-rolled `CustomPainter` implementations, reusing the painter infrastructure
built for the dial. This avoids a charting dependency whose default styling
would fight the tone palette, in an app whose whole identity is a bespoke
visualisation. Cost: roughly a day of extra work versus adopting `fl_chart`.

### Empty states

Each section renders a specific invitation when it has no data — for example
"Run your first session to see where your focus goes" — rather than a zeroed
axis. A new user sees nothing meaningful here for several days, and that first
impression matters.

---

## 9. Progress and gamification

### 9.1 Core rule: derived, never accumulated

Streak, energy score, XP, and badges are computed **from** `events` and
`sessions`, then cached in `day_scores` and `progress` for speed. A full
`recalculateAll()` path can rebuild every number from source rows.

Incrementing counters on each session would mean one bug — or one edited past
day — silently and permanently corrupting a user's history. This rule is not
negotiable during implementation.

### 9.2 Daily streak

Consecutive days with at least one session whose outcome is `completed` **or**
`finishedEarly`. Abandoned sessions do not count, and a running session does not
count until it ends. A day that passes with no such session ends the streak;
`currentStreak` resets to 0 and `longestStreak` retains the previous maximum.
Evaluated at the local-time day boundary. No freezes or grace days.

### 9.3 Energy score (0–100 per day)

Three explicit components, so the score is tunable and explainable:

| Component | Range | Definition |
|---|---|---|
| Adherence | 0–50 | `completedMinutes / plannedMinutes`, capped at 1.0, × 50. When `plannedMinutes` is 0 this component is 0. |
| Focus | 0–30 | `focusMinutes / dailyFocusTarget`, capped at 1.0, × 30. Target defaults to 180 minutes and is settable. |
| Balance | 0–20 | 20 when all three tones are present and no single tone exceeds 70% of the day's minutes; scaled down proportionally otherwise. |

A day with no planned events scores 0 on every component. Scores for days
already in the past are never silently recomputed; only an explicit
`recalculateAll()` rebuilds them.

The Profile screen shows the component breakdown, not just the total. A score
that cannot be interrogated is a score users stop trusting.

### 9.4 Badges

Static definitions in code, each with a stable string id. Evaluated after every
session completion and at day rollover.

Initial set: first session; 10, 50, and 100 sessions; a four-hour focus day; a
week touching all three tones; 7-day streak; 30-day streak; a week with no
abandoned sessions; a focus session started before 08:00.

Unlocks are timestamped in `badge_unlocks`. The Profile badge grid shows locked
slots so the set is discoverable.

### 9.5 XP and levels

1 XP per completed session minute, × 1.5 for Focus sessions, plus bonuses for
streak days and badge unlocks. Levels sit on a widening threshold curve.

**Noted risk:** XP overlaps substantially with the energy score, and is the
element most likely to make a calm utility app feel gamey. It is specified here
as requested and is the first candidate for removal if the app feels
over-gamified in use.

### 9.6 Weekly Roundup

Generated Sunday evening, announced by a local notification, covering the seven
days ending that Sunday. The reported week is always Monday–Sunday, independent
of the "first day of week" setting, which affects only how the calendar month
grid is laid out. Presented as a vertical card stack:

- The week's tone donut
- Adherence percentage
- Best focus day
- Streak status
- Badges earned this week
- XP gained
- Comparison against the previous week

The generated result is **frozen as a JSON snapshot** in `weekly_roundups`.
Reopening week 34 next March shows what it said at the time, not a recomputation
against a changed database. Past roundups live in an archive list on Profile.

### 9.7 Profile tab

Level and XP progress, current and longest streak, the badge grid, the roundup
archive, and settings:

- Theme: system / light / dark
- Notification toggles, and lead time for "event starting soon"
- Daily focus target
- First day of week
- Data export (JSON) and full reset

---

## 10. Notifications

All local, via `flutter_local_notifications`. Permission is requested at first
meaningful use, not at launch.

| Notification | Trigger |
|---|---|
| Session ended | Scheduled at the running session's planned end instant |
| Event starting soon | Configurable lead time before a planned event's start |
| Weekly Roundup ready | Sunday evening |
| Daily planning reminder | Configurable morning time, only if today's orbit is empty |

Scheduling for upcoming events requires materialising recurring series a short
window ahead; the materialiser is invoked for the next 7 days whenever the app
foregrounds.

---

## 11. Theming

Light and dark themes following the iOS system setting, with a manual override
in settings. The light theme follows the reference image: near-white face, thin
grey ticks, dark numerals, saturated tone arcs. The dark theme keeps the same
tone hues, adjusted for contrast, on a near-black face.

Every colour is defined once in the theme's tone palette. No hard-coded colours
in feature code.

---

## 12. Testing and verification

**Unit tests** carry the weight, aimed at pure logic:

- `DialGeometry`: angle↔minute conversion, hit testing, orbit band detection,
  midnight clamping, minimum-duration snapping
- Ring assignment for overlapping events, including the 3-ring refusal
- `SeriesMaterialiser`: expansion, idempotency, skip handling, edit-all-future
- Session timing: pause, resume, extend, overtime, foreground recovery,
  backwards clock change, DST transition days
- Energy score components, streak evaluation, XP calculation, every badge rule

**DAO tests** run against an in-memory Drift database, including migration tests
from each shipped schema version.

**Widget tests** cover the event sheet's validation and the session controls.

**Golden tests** pin the dial painter's rendering for a small set of
representative days.

**Manual verification** on the iPhone 17 Pro simulator at the end of every
phase, with screenshots shared for review. The dial is a visual artifact; no
automated test establishes whether it looks right.

---

## 13. Edge cases

| Case | Handling |
|---|---|
| Event crossing midnight | Prevented; drag clamps at `endMinute` 1440 |
| Four overlapping events | Refused with an explanatory message |
| Arc too short for its label | Label omitted from the arc; identified by tap |
| Notification permission denied | Sessions still work; one-time explanatory banner |
| App killed mid-session | Session recovered from database on launch |
| Device clock moved backwards | Elapsed floored at zero; session closed out |
| DST transition | Events store minute-of-day; sessions store absolute instants; neither breaks |
| Editing a past day | Prevented; past days are read-only |
| Empty database on first launch | Every screen has a defined empty state |
| Applying a template to a non-empty day | Not offered |

---

## 14. Build phases

Each phase ends with something runnable on the simulator and a screenshot
review. Each phase gets its own implementation plan; this spec is deliberately
larger than one plan's worth of work.

**Phase 1 — Core.** Project scaffold, theme, tab shell, Drift schema, dial
geometry and painter, drag-to-create, event sheet, event editing, day switching.
*Runnable result: a working visual day planner.*

**Phase 2 — Session.** Session screen, timing model, controls, notifications,
outcome recording, crash recovery.
*Runnable result: the app's core loop is complete.*

**Phase 3 — Calendar and reuse.** Month grid with day rings, recurrence
(rules, materialisation, edit scopes), day templates, copy-yesterday.
*Runnable result: usable beyond the first week.*

**Phase 4 — Statistics.** Period selector, four stat sections, chart painters,
empty states.

**Phase 5 — Progress.** Energy score, streak, badges, XP, Profile tab, Weekly
Roundup, settings, data export.

---

## 15. Dependencies

| Package | Purpose |
|---|---|
| `flutter_riverpod` | State management |
| `drift` + `sqlite3_flutter_libs` | Typed SQLite persistence |
| `drift_dev` + `build_runner` | Code generation (dev) |
| `path_provider` | Database file location |
| `flutter_local_notifications` | All four notification types |
| `timezone` | Correct scheduling across DST |
| `intl` | Date and duration formatting |
| `share_plus` | Handing the exported JSON file to the iOS share sheet |

No charting library. No HTTP client. No analytics or crash-reporting SDK.
