# Energy Clock — Step 5: Notifications — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The app schedules its four local notifications (session end, event starting soon, morning reminder, roundup ready) through one foreground reconciler, asks permission at first meaningful use, and exposes four toggles plus a morning-time row on Profile.

**Architecture:** Pure `computeSchedule` in `lib/core/notifications/` decides the full pending set from plain data; thin `DriftNotificationScheduler` in the data layer materialises the next 7 days, reads events/toggles, diffs against the last desired set with stable ids, and applies cancels/schedules per-id with failures swallowed. Triggers are app foreground (via `AppLifecycleListener`, the established pattern) and any events-table write (via drift `tableUpdates`). No background modes, no new packages.

**Tech Stack:** Flutter 3.44.7, Dart 3.12.2, `flutter_riverpod` 2.6, `drift` + `drift_flutter`, `flutter_local_notifications` (already wired behind `NotificationService`), `intl`. No new runtime packages. No schema change (settings keys only).

**Specs:** `docs/superpowers/specs/2026-10-09-step-5-notifications-design.md` (this step) over `docs/superpowers/specs/2026-08-23-energy-clock-design.md` (§10 Notifications). **Step 4 is not implemented yet** — this plan depends on nothing from it except the future Profile screen, and says exactly where the merge happens (Task 4).

## Global Constraints

- **Platform:** iOS 15+. iPhone portrait; iPad all orientations.
- **Language:** English-only. All user-facing copy lives in `lib/core/strings.dart`.
- **Boundary rule:** no file under `lib/features/<a>/` imports from `lib/features/<b>/`. The scheduler lives in `lib/data/` so every feature drives it through providers.
- **No hard-coded colours in feature code** (`Color(0x`, `Colors.` banned under `lib/features/`; enforced by test). The new UI reuses existing theme colors only.
- **Local dates:** local midnights via the `DateTime(y, m, d ± n)` constructor, never 24-hour `Duration`s. Notification instants are absolute (`DateTime` instants; the service sends UTC).
- **Tap targets** ≥ 44 pt. New rows reuse existing shared widgets (`chooseOne`, `confirmDestructive` is not needed here; `CupertinoSwitch`, `CupertinoIcons`).
- **Tooling:** `DART="$(dirname "$(which flutter)")/dart"` for Dart commands; `rg` unavailable (use grep tool / `Select-String`).
- **Style:** `flutter analyze` clean; `dart format` output committed; lints in `analysis_options.yaml`.
- **Commit messages** end with a blank line and `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Plan checkboxes stay unticked.

## Decisions and amendments

| # | Area | Decision |
|---|---|---|
| 1 | Scheduler placement | `DriftNotificationScheduler` in `lib/data/repositories/` + `notificationSchedulerProvider` in `lib/data/providers.dart`; pure `computeSchedule` in `lib/core/notifications/schedule.dart`. |
| 2 | Event-reminder ids | `10000 + eventId` (stable database ids; reschedule replaces; deleted events vanish from the desired set and are cancelled). |
| 3 | Morning ids | `20000 + yyyymmdd` (e.g. 20261009 → 20281009). Roundup id `30001`. Session end keeps `1001`. |
| 4 | Cap | Nearest 32 event reminders; iOS allows 64 pending per app and the other three types need headroom. |
| 5 | Lead time | Fixed 10 minutes (`eventLeadMinutes = 10` const in the pure module; a test-only parameter is YAGNI). |
| 6 | Toggle-off cancellation | Stateless: diff `computeSchedule` with the toggle forced on versus off; no persisted id set (restart-safe). The in-memory last-desired set starts empty per launch. |
| 7 | Coalescing | The scheduler serializes passes through a `_tail` future chain (the `SessionAlertsNotifier` precedent); bursts queue instead of overlapping. |
| 8 | Session-end toggle | Gates the existing `SessionAlertsNotifier._sync` (check the bool first, default true). No other session-alert behavior changes. |
| 9 | Permission reuse | New shared `ensureNotificationPermission()` helper owns the prompted-key flow; `SessionAlertsNotifier._permitted` is refactored onto it with behavior preserved by existing tests. |
| 10 | Profile surface | Step 4's screen doesn't exist, so this plan gives `ProfileScreen` its first real section (`NotificationSettingsSection` in its own file). Step 4's shell task must render that widget rather than replacing the file — flagged in Task 4. |
| 11 | Roundup week number | Minimal `isoWeekNumber()` Thursday-rule helper lives in the pure module with verified values; Step 4's richer ISO helpers may subsume it later. |
| 12 | Morning time storage | Minutes since midnight (`morning_reminder_minutes`, default 480), formatted at the call site with `DateFormat`. |

## Out of scope

Notification sounds/badges customization beyond the existing configuration, notification actions/snooze, per-event lead times, watch complications, push, analytics. The XP/level gameiness review note. Anything in Step 4's plans.

## How to read the steps

- **Create / Replace / Edit** blocks give exact changes; **Edit** shows `Replace:` (appears exactly once) and `With:`.
- `# expect: PASS` must succeed; `# expect: FAIL` must fail for the stated reason; `# expect: RUN` are setup commands; `# expect: MANUAL` is done by a person.
- If a snippet doesn't compile against the installed `flutter_local_notifications`, fix minimally, keep behavior and test intent, and report it.
- `testWidgets` runs in fake time; `FakeNotificationService.pending` records scheduled items.
- New-test counts are in each `# expect: PASS`; the full suite must stay green (no baseline number is claimed — Step 4 is unexecuted).

## File Structure

**Created:**

| File | Responsibility |
|---|---|
| `lib/core/notifications/schedule.dart` | Pure `computeSchedule`, id consts, `isoWeekNumber`, `DesiredNotification`/`ScheduledEvent` typedefs |
| `lib/data/repositories/notification_scheduler.dart` | `NotificationScheduler` interface + `DriftNotificationScheduler` + `foregroundRefreshProvider` + `notificationSchedulerProvider` (provider lives in `lib/data/providers.dart`, see Task 2) |
| `lib/data/notifications/notification_permission.dart` | Shared `ensureNotificationPermission()` + key consts for the four toggles and morning minutes |
| `lib/features/progress/widgets/notification_settings.dart` | `NotificationSettingsSection` (four toggles, morning row, OS-off row) |
| `test/core/notifications/schedule_test.dart` | Pure computation tests |
| `test/data/notification_scheduler_test.dart` | Fake-service reconcile tests (memory Drift db) |
| `test/features/progress/notification_settings_test.dart` | Toggle/row/permission widget tests |

**Modified:** `lib/core/strings.dart`, `lib/data/daos/event_dao.dart` (`eventsBetween`), `lib/data/providers.dart`, `lib/features/session/session_alerts.dart` (toggle gate + permission-helper refactor), `lib/features/clock/widgets/../clock_tab.dart` (`lib/app/navigation/clock_tab.dart`: watch the refresh provider), `lib/features/progress/profile_screen.dart` (first real section), `test/support/clock_harness.dart` (nothing needed — fakes already wired; confirm in Task 4), `test/features/session/session_alerts_test.dart`, `README.md`.

---

## Stage 1 — Pure computation

### Task 1: `computeSchedule` and notification copy

The whole schedule as a pure function of plain data, plus the four notifications' copy. No clock, no database, no plugin.

**Files:**
- Create: `lib/core/notifications/schedule.dart`
- Modify: `lib/core/strings.dart`
- Test: `test/core/notifications/schedule_test.dart` (new)

**Interfaces:**
- `ScheduledEvent = ({int id, DateTime startsAt, String title, Tone tone})` (`startsAt` is an absolute instant).
- `DesiredNotification = ({int id, DateTime at, String title, String body})`.
- `eventLeadMinutes = 10`, `maxEventReminders = 32`, `roundupNotificationId = 30001`.
- `eventReminderId(int eventId) = 10000 + eventId`; `morningReminderId(DateTime day) = 20000 + (day.year * 10000 + day.month * 100 + day.day)`.
- `computeSchedule({required List<ScheduledEvent> events, required DateTime now, required bool eventSoon, required bool roundup, required bool morning, required int morningMinutes, int horizonDays = 7}) → List<DesiredNotification>`:
  - Event reminders for events with `startsAt − 10 min > now`, nearest 32 by `startsAt`.
  - Morning reminders for each of the next `horizonDays` dates (starting today) with zero events, at `date + morningMinutes`, only when that instant is after `now`.
  - Roundup for the upcoming Sunday 20:00 (today if Sunday and `now < 20:00`, else next Sunday).
  - "Empty" counts non-deleted input events only (callers exclude status-2 rows).
- `isoWeekNumber(DateTime date) → int` (Thursday rule; verified: 2026-10-11 → 41, 2026-01-01 → 1, 2025-12-29 → 1).

- [ ] **Step 1: Write the failing tests**

**Create `test/core/notifications/schedule_test.dart`**

```dart
import 'package:energy_clock/core/notifications/schedule.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Wednesday 7 October 2026, 10:30.
  final now = DateTime(2026, 10, 7, 10, 30);

  ScheduledEvent event(int id, DateTime startsAt) => (
    id: id,
    startsAt: startsAt,
    title: 'Deep work',
    tone: Tone.focus,
  );

  test('an upcoming event gets a reminder ten minutes before', () {
    final desired = computeSchedule(
      events: [event(1, DateTime(2026, 10, 7, 12))],
      now: now,
      eventSoon: true,
      roundup: false,
      morning: false,
      morningMinutes: 480,
    );
    expect(desired, hasLength(1));
    expect(desired.single.id, 10001);
    expect(desired.single.at, DateTime(2026, 10, 7, 11, 50));
    expect(desired.single.title, 'Deep work');
  });

  test('a passed lead instant is never scheduled', () {
    final desired = computeSchedule(
      events: [event(1, DateTime(2026, 10, 7, 10, 35))],
      now: now,
      eventSoon: true,
      roundup: false,
      morning: false,
      morningMinutes: 480,
    );
    expect(desired, isEmpty);
  });

  test('a switched-off type schedules nothing', () {
    final desired = computeSchedule(
      events: [event(1, DateTime(2026, 10, 7, 12))],
      now: now,
      eventSoon: false,
      roundup: true,
      morning: false,
      morningMinutes: 480,
    );
    // Only the roundup (Sunday) — no event reminder, no mornings.
    expect(desired.map((item) => item.id), [roundupNotificationId]);
  });

  test('empty mornings get reminders, full mornings do not', () {
    final desired = computeSchedule(
      events: [event(1, DateTime(2026, 10, 9, 12))],
      now: now,
      eventSoon: false,
      roundup: false,
      morning: true,
      morningMinutes: 480,
    );
    final ids = desired.map((item) => item.id).toSet();
    // Today is empty but its 08:00 passed; the 8th is empty; the 9th is full.
    expect(ids, contains(morningReminderId(DateTime(2026, 10, 8))));
    expect(ids, isNot(contains(morningReminderId(DateTime(2026, 10, 7)))));
    expect(ids, isNot(contains(morningReminderId(DateTime(2026, 10, 9)))));
    final eighth = desired.firstWhere(
      (item) => item.id == morningReminderId(DateTime(2026, 10, 8)),
    );
    expect(eighth.at, DateTime(2026, 10, 8, 8));
  });

  test('the roundup lands on Sunday at eight in the evening', () {
    final desired = computeSchedule(
      events: const [],
      now: now, // Wednesday
      eventSoon: false,
      roundup: true,
      morning: false,
      morningMinutes: 480,
    );
    expect(desired.single.at, DateTime(2026, 10, 11, 20));
    expect(desired.single.body, contains('41'));
  });

  test('on Sunday morning the roundup is today, on Sunday night it is next week', () {
    final morning = computeSchedule(
      events: const [],
      now: DateTime(2026, 10, 11, 9),
      eventSoon: false,
      roundup: true,
      morning: false,
      morningMinutes: 480,
    );
    expect(morning.single.at, DateTime(2026, 10, 11, 20));

    final night = computeSchedule(
      events: const [],
      now: DateTime(2026, 10, 11, 21),
      eventSoon: false,
      roundup: true,
      morning: false,
      morningMinutes: 480,
    );
    expect(night.single.at, DateTime(2026, 10, 18, 20));
  });

  test('event reminders cap at the nearest 32', () {
    final desired = computeSchedule(
      events: [
        for (var i = 0; i < 100; i++)
          event(i, DateTime(2026, 10, 7, 11).add(Duration(minutes: i))),
      ],
      now: now,
      eventSoon: true,
      roundup: false,
      morning: false,
      morningMinutes: 480,
    );
    expect(desired, hasLength(32));
    expect(desired.last.id, 10000 + 31);
  });

  test('ids are stable per event and per date', () {
    expect(eventReminderId(7), 10007);
    expect(morningReminderId(DateTime(2026, 10, 9)), 20281009);
  });

  test('ISO week numbers match the calendar', () {
    expect(isoWeekNumber(DateTime(2026, 10, 11)), 41);
    expect(isoWeekNumber(DateTime(2026, 1, 1)), 1);
    expect(isoWeekNumber(DateTime(2025, 12, 29)), 1);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL - compile error: lib/core/notifications/schedule.dart does not exist yet.
flutter test test/core/notifications/schedule_test.dart
```

- [ ] **Step 3: Add the strings**

**Edit `lib/core/strings.dart`** — insert after the last existing notification-related block (confirm the anchor at implementation time; the session strings live near `sessionEndedTitle`). Append a notifications block:

```dart
  // Notifications (spec §10).
  static String eventReminderBody(String tone) =>
      'Starts in 10 minutes · $tone';
  static const String morningReminderTitle = 'Plan your day';
  static const String morningReminderBody =
      'Today is wide open — put something on the dial.';
  static const String roundupReadyTitle = 'Your Weekly Roundup is ready';
  static String roundupReadyBody(int week) =>
      'Week $week in review: scores, streaks and badges.';
```

- [ ] **Step 4: Create the pure module**

**Create `lib/core/notifications/schedule.dart`**

```dart
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';

/// One planned event the scheduler knows about. `startsAt` is an absolute
/// instant; callers exclude deleted occurrences.
typedef ScheduledEvent = ({
  int id,
  DateTime startsAt,
  String title,
  Tone tone,
});

/// One pending notification the app wants: a stable id so rescheduling
/// replaces, and an absolute instant.
typedef DesiredNotification = ({int id, DateTime at, String title, String body});

/// Minutes before an event's start its reminder fires. Fixed (Step 5
/// decision); a parameter would be YAGNI.
const int eventLeadMinutes = 10;

/// At most this many event reminders stay pending: iOS allows 64 per app and
/// the other three types need headroom.
const int maxEventReminders = 32;

/// The one roundup id. There is only ever one upcoming Sunday.
const int roundupNotificationId = 30001;

/// `10000 + eventId`. Stable while the event exists.
int eventReminderId(int eventId) => 10000 + eventId;

/// `20000 + yyyymmdd` of the morning it wakes. Fits an int with room.
int morningReminderId(DateTime day) =>
    20000 + day.year * 10000 + day.month * 100 + day.day;

/// The ISO week number of [date]'s week (Thursday rule). Calendar arithmetic —
/// a DST change inside the week cannot move the result.
int isoWeekNumber(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  final thursday = DateTime(
    day.year,
    day.month,
    day.day + (DateTime.thursday - day.weekday),
  );
  final jan4 = DateTime(thursday.year, 1, 4);
  final week1Monday = DateTime(
    jan4.year,
    jan4.month,
    jan4.day - (jan4.weekday - DateTime.monday),
  );
  return DateTime.utc(
        day.year,
        day.month,
        day.day,
      ).difference(DateTime.utc(
        week1Monday.year,
        week1Monday.month,
        week1Monday.day,
      )).inDays ~/
      7 +
      1;
}

/// The full pending set: event reminders, empty mornings, and the Sunday
/// roundup — each only when its toggle is on. Past instants are never
/// returned.
List<DesiredNotification> computeSchedule({
  required List<ScheduledEvent> events,
  required DateTime now,
  required bool eventSoon,
  required bool roundup,
  required bool morning,
  required int morningMinutes,
  int horizonDays = 7,
}) {
  final desired = <DesiredNotification>[];

  if (eventSoon) {
    final upcoming =
        events
            .where(
              (event) => event.startsAt
                  .subtract(const Duration(minutes: eventLeadMinutes))
                  .isAfter(now),
            )
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    for (final event in upcoming.take(maxEventReminders)) {
      desired.add((
        id: eventReminderId(event.id),
        at: event.startsAt.subtract(
          const Duration(minutes: eventLeadMinutes),
        ),
        title: event.title,
        body: Strings.eventReminderBody(event.tone.label),
      ));
    }
  }

  if (morning) {
    final busy = {
      for (final event in events)
        DateTime(
          event.startsAt.year,
          event.startsAt.month,
          event.startsAt.day,
        ),
    };
    final today = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < horizonDays; i++) {
      final day = DateTime(today.year, today.month, today.day + i);
      if (busy.contains(day)) continue;
      final at = day.add(Duration(minutes: morningMinutes));
      if (!at.isAfter(now)) continue;
      desired.add((
        id: morningReminderId(day),
        at: at,
        title: Strings.morningReminderTitle,
        body: Strings.morningReminderBody,
      ));
    }
  }

  if (roundup) {
    var sunday = DateTime(now.year, now.month, now.day);
    while (sunday.weekday != DateTime.sunday) {
      sunday = DateTime(sunday.year, sunday.month, sunday.day + 1);
    }
    var at = DateTime(sunday.year, sunday.month, sunday.day, 20);
    if (!at.isAfter(now)) {
      at = DateTime(at.year, at.month, at.day + 7, 20);
    }
    desired.add((
      id: roundupNotificationId,
      at: at,
      title: Strings.roundupReadyTitle,
      body: Strings.roundupReadyBody(isoWeekNumber(at)),
    ));
  }

  return desired;
}
```

> Note for the implementer: `busy` derives local days from absolute `startsAt` instants — an event's local day is what "empty morning" means, and the repository (Task 2) passes event-local days explicitly, so this fold is belt-and-braces. `Tone.label` already exists (week strip uses it).

- [ ] **Step 5: Run the tests to verify they pass**

```bash
# expect: PASS - 9 tests
flutter test test/core/notifications/schedule_test.dart
```

- [ ] **Step 6: Analyze, run the suite, commit**

```bash
# expect: PASS - analyzer clean; whole suite green
flutter analyze && flutter test
```

```bash
# expect: RUN
git add lib/core/notifications/schedule.dart lib/core/strings.dart test/core/notifications/schedule_test.dart
git commit -m "feat: pure notification schedule computation

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

## Stage 2 — Scheduler and permission

### Task 2: Scheduler, providers, foreground wiring

The thin reconciler, its providers, the events-range query, integer settings access (Step 4's version of this doesn't exist yet — see the merge note), and fake-service tests on a memory database.

**Files:**
- Create: `lib/data/repositories/notification_scheduler.dart`, `lib/data/notifications/notification_permission.dart` (keys only — the helper itself is Task 3)
- Modify: `lib/data/daos/event_dao.dart` (`eventsBetween`), `lib/data/repositories/settings_repository.dart` (+ `getInt`/`setInt`), `test/support/fake_settings_repository.dart` (same), `lib/data/providers.dart` (two providers), `lib/app/navigation/clock_tab.dart` (watch the refresh provider)
- Test: `test/data/notification_scheduler_test.dart` (new), `test/data/settings_test.dart` (append int tests)

**Interfaces:**
- `NotificationScheduler` interface: `Future<void> reconcile()`.
- `DriftNotificationScheduler(db, service, {now, materialiser})`; passes serialize through a `_tail` chain; never throws.
- `notificationSchedulerProvider: Provider<NotificationScheduler>`; `foregroundRefreshProvider: Provider<void>` (initial refresh + `tableUpdates` on `events` + `AppLifecycleListener.onResume`).
- `EventDao.eventsBetween(from, toExclusive) → Future<List<EventRow>>` (date range, skips status 2, ordered by date then start).
- `SettingsRepository` gains `Future<int?> getInt(String key)` / `Future<void> setInt(String key, int value)` (decimal strings in the text column; unparseable reads as null). Fake mirrors with a `Map<String, Object>` store... 

> Merge note (read carefully): Step 4's plan also extends this repository (its Task 2). That task is unexecuted. When it executes, it must merge with — not overwrite — the `getInt`/`setInt` added here; the signatures here are the canonical ones.

- [ ] **Step 1: Write the failing tests**

**Create `test/data/notification_scheduler_test.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/notifications/notification_permission.dart';
import 'package:energy_clock/data/repositories/notification_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_notification_service.dart';

void main() {
  late AppDatabase db;
  late FakeNotificationService service;
  late DriftNotificationScheduler scheduler;

  // Wednesday 7 October 2026, 10:30.
  final now = DateTime(2026, 10, 7, 10, 30);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = FakeNotificationService();
    scheduler = DriftNotificationScheduler(
      db,
      service,
      now: () => now,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> seedEvent(DateTime date, {int start = 720}) =>
      db.eventDao.insertEvent(
        EventsCompanion.insert(
          date: date,
          title: 'Deep work',
          toneIndex: Tone.focus.dbIndex,
          startMinute: start,
          endMinute: start + 60,
          createdAt: now,
          updatedAt: now,
        ),
      );

  test('a morning reconcile schedules the event, the mornings and the roundup', () async {
    await seedEvent(DateTime(2026, 10, 7));

    await scheduler.reconcile();

    expect(service.pending[10001]?.at, DateTime(2026, 10, 7, 11, 50));
    // Today is full; tomorrow empty at the default 08:00.
    expect(service.pending[20281008]?.at, DateTime(2026, 10, 8, 8));
    expect(service.pending[30001]?.at, DateTime(2026, 10, 11, 20));
  });

  test('a second pass schedules nothing new', () async {
    await seedEvent(DateTime(2026, 10, 7));
    await scheduler.reconcile();
    final calls = service.log.where((line) => line.startsWith('schedule')).length;

    await scheduler.reconcile();

    expect(
      service.log.where((line) => line.startsWith('schedule')).length,
      calls,
    );
  });

  test('a deleted event loses its reminder', () async {
    final id = await seedEvent(DateTime(2026, 10, 7));
    await scheduler.reconcile();
    expect(service.pending, contains(10000 + id));

    await db.eventDao.deleteById(id, now: now);
    await scheduler.reconcile();

    expect(service.pending, isNot(contains(10000 + id)));
  });

  test('a switched-off type cancels even with no memory of it', () async {
    // A previous launch scheduled this; this scheduler never saw it.
    service.pending[10001] = (
      at: DateTime(2026, 10, 7, 11, 50),
      title: 'Deep work',
      body: 'x',
    );
    await seedEvent(DateTime(2026, 10, 7));
    await db.settingsDao.setValue(notifyEventSoonKey, '0');

    await DriftNotificationScheduler(db, service, now: () => now).reconcile();

    expect(service.pending, isNot(contains(10001)));
    // The roundup (a type still on) is scheduled by the same pass.
    expect(service.pending, contains(30001));
  });

  test('a failing plugin is swallowed and retried next pass', () async {
    await seedEvent(DateTime(2026, 10, 7));
    service.failSchedule = true;

    await scheduler.reconcile();
    expect(service.pending, isEmpty);

    service.failSchedule = false;
    await scheduler.reconcile();
    expect(service.pending, contains(10001));
  });

  test('materialising first pulls series occurrences into range', () async {
    // A daily series starting today: no occurrence rows exist until the
    // materialiser runs inside reconcile.
    final rule = RecurrenceRule.daily();
    await db.seriesDao.insertSeries(
      EventSeriesCompanion.insert(
        title: 'Standup',
        toneIndex: Tone.life.dbIndex,
        startMinute: 540,
        endMinute: 555,
        recurrenceKind: rule.kind.dbIndex,
        weekdayMask: Value(rule.weekdayMask),
        validFrom: DateTime(2026, 10, 7),
        validUntil: const Value(null),
        createdAt: now,
      ),
    );
    scheduler = DriftNotificationScheduler(
      db,
      service,
      now: () => now,
      materialiser: SeriesMaterialiser(db.seriesDao, clock: () => now),
    );

    await scheduler.reconcile();

    // Seven occurrences (7–13 Oct); today's 08:50 reminder already passed, so
    // six stay pending — including tomorrow's 08:50.
    final reminders = service.pending.keys.where(
      (id) => id >= 10000 && id < 20000,
    );
    expect(reminders, hasLength(6));
    final tomorrow = await db.eventDao.eventsForDay(DateTime(2026, 10, 8));
    expect(
      service.pending[10000 + tomorrow.single.id]?.at,
      DateTime(2026, 10, 8, 8, 50),
    );
  });
}
```

> Note for the implementer: this test needs `import 'package:energy_clock/core/recurrence/recurrence_rule.dart';` and `import 'package:energy_clock/data/repositories/series_materialiser.dart';` — add both to the test file.

**Append to `test/data/settings_test.dart`** (inside `DriftSettingsRepository` group):

```dart
    test('an integer round-trips through its stored string form', () async {
      expect(await repository.getInt('missing'), isNull);
      await repository.setInt('morning', 480);
      expect(await repository.getInt('morning'), 480);
      await db.settingsDao.setValue('morning', 'nope');
      expect(await repository.getInt('morning'), isNull);
    });
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL - compile error: NotificationScheduler, the permission keys and getInt do not exist yet.
flutter test test/data/notification_scheduler_test.dart test/data/settings_test.dart
```

- [ ] **Step 3: Extend the DAO and settings**

**Edit `lib/data/daos/event_dao.dart`** — insert after `eventsForDay`:

Replace:
```dart
  Future<List<EventRow>> eventsForDay(DateTime day) => _dayQuery(day).get();
```
With:
```dart
  Future<List<EventRow>> eventsForDay(DateTime day) => _dayQuery(day).get();

  /// Every non-deleted event in `[from, toExclusive)`, oldest first. Feeds the
  /// notification scheduler's 7-day horizon.
  Future<List<EventRow>> eventsBetween(DateTime from, DateTime toExclusive) =>
      (select(events)
            ..where(
              (row) =>
                  row.date.isBiggerOrEqualValue(from) &
                  row.date.isSmallerThanValue(toExclusive) &
                  row.status.isNotValue(_skipped),
            )
            ..orderBy([
              (row) => OrderingTerm(expression: row.date),
              (row) => OrderingTerm(expression: row.startMinute),
            ]))
          .get();
```

**Edit `lib/data/repositories/settings_repository.dart`** — add to the interface and the implementation:

Replace:
```dart
abstract interface class SettingsRepository {
  Future<bool> getBool(String key, {bool defaultValue = false});
  Future<void> setBool(String key, bool value);
}
```
With:
```dart
abstract interface class SettingsRepository {
  Future<bool> getBool(String key, {bool defaultValue = false});
  Future<void> setBool(String key, bool value);

  /// The stored string, or null when the key was never set.
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);

  /// The stored integer, or null when the key was never set or does not parse.
  /// Stored as its decimal string; the table holds only text.
  Future<int?> getInt(String key);
  Future<void> setInt(String key, int value);
}
```

Replace:
```dart
  @override
  Future<void> setBool(String key, bool value) =>
      _dao.setValue(key, value ? '1' : '0');
}
```
With:
```dart
  @override
  Future<void> setBool(String key, bool value) =>
      _dao.setValue(key, value ? '1' : '0');

  @override
  Future<String?> getString(String key) => _dao.valueFor(key);

  @override
  Future<void> setString(String key, String value) =>
      _dao.setValue(key, value);

  @override
  Future<int?> getInt(String key) async =>
      int.tryParse(await getString(key) ?? '');

  @override
  Future<void> setInt(String key, int value) =>
      setString(key, value.toString());
}
```

**Replace `test/support/fake_settings_repository.dart`** (the whole file — 34 lines today):

```dart
import 'dart:async';

import 'package:energy_clock/data/repositories/settings_repository.dart';

/// In-memory [SettingsRepository] for widget tests. Booleans are stored
/// as-is, integers as decimal strings — the same shapes the Drift repository
/// writes.
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({Map<String, Object>? values})
    : values = {...?values};

  /// The stored settings; tests read and seed it directly.
  final Map<String, Object> values;

  /// Makes every read throw, as an unreadable database would.
  bool failReads = false;

  /// Makes every write throw.
  bool failWrites = false;

  /// While non-null, reads wait for it to complete.
  Completer<bool>? gate;

  Future<void> _read() async {
    if (failReads) throw StateError('settings are unreadable');
    final held = gate;
    if (held != null) await held.future;
  }

  @override
  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    await _read();
    return values[key] == true ? true : values[key] is bool ? values[key] as bool : defaultValue;
  }

  @override
  Future<void> setBool(String key, bool value) async {
    if (failWrites) throw StateError('settings are unwritable');
    values[key] = value;
  }

  @override
  Future<String?> getString(String key) async {
    await _read();
    final stored = values[key];
    return stored is String ? stored : null;
  }

  @override
  Future<void> setString(String key, String value) async {
    if (failWrites) throw StateError('settings are unwritable');
    values[key] = value;
  }

  @override
  Future<int?> getInt(String key) async {
    final stored = await getString(key);
    return stored == null ? null : int.tryParse(stored);
  }

  @override
  Future<void> setInt(String key, int value) => setString(key, '$value');
}
```

> Note for the implementer: this also adds the `getString`/`setString` pair from Step 4's (unexecuted) Task 2 so the fake implements the full interface once — `getInt` is specified in terms of it, exactly like the Drift implementation. When Step 4 executes, its Task 2 must merge with this file, not overwrite it. `getBool`'s odd-looking ternary preserves the old semantics exactly (a stored `false` beats a `true` default; anything non-bool falls back to the default).

- [ ] **Step 4: Create the keys file and the scheduler**

**Create `lib/data/notifications/notification_permission.dart`**

```dart
/// Settings keys owned by notifications. Toggles default to true at the call
/// site (`getBool(key, defaultValue: true)`); they do nothing until the OS
/// permission exists.
const String notifySessionEndKey = 'notify_session_end';
const String notifyEventSoonKey = 'notify_event_soon';
const String notifyRoundupKey = 'notify_roundup';
const String notifyMorningKey = 'notify_morning';

/// Minutes since midnight for the daily reminder. Default 480 (08:00).
const String morningReminderMinutesKey = 'morning_reminder_minutes';
const int defaultMorningMinutes = 480;
```

**Create `lib/data/repositories/notification_scheduler.dart`**

```dart
import 'package:energy_clock/core/notifications/schedule.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/notifications/notification_permission.dart';
import 'package:energy_clock/data/notifications/notification_service.dart';
import 'package:energy_clock/data/repositories/series_materialiser.dart';

/// Recomputes the full pending set and applies the difference (spec §10).
/// Passes serialize through a future chain; a pass never throws.
abstract interface class NotificationScheduler {
  Future<void> reconcile();
}

class DriftNotificationScheduler implements NotificationScheduler {
  DriftNotificationScheduler(
    this._db,
    this._service, {
    DateTime Function()? now,
    SeriesMaterialiser? materialiser,
  }) : _now = now ?? DateTime.now,
       _materialiser = materialiser;

  final AppDatabase _db;
  final NotificationService _service;
  final DateTime Function() _now;
  final SeriesMaterialiser? _materialiser;

  Future<void> _tail = Future<void>.value();
  List<DesiredNotification> _last = [];

  @override
  Future<void> reconcile() {
    final run = _tail.then((_) => _reconcile());
    _tail = run;
    return run;
  }

  Future<void> _reconcile() async {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final horizon = DateTime(today.year, today.month, today.day + 7);

    final materialiser = _materialiser;
    if (materialiser != null) {
      try {
        await materialiser.materialise(today, horizon);
      } on Object {
        // Schedule from stored events: a failed expansion must not silence
        // everything (the Calendar's rule).
      }
    }

    final settings = _db.settingsDao;
    final toggles = (
      eventSoon:
          (await settings.valueFor(notifyEventSoonKey)) != '0',
      roundup: (await settings.valueFor(notifyRoundupKey)) != '0',
      morning: (await settings.valueFor(notifyMorningKey)) != '0',
    );
    final morningMinutes =
        int.tryParse(
          await settings.valueFor(morningReminderMinutesKey) ?? '',
        ) ??
        defaultMorningMinutes;

    final rows = await _db.eventDao.eventsBetween(today, horizon);
    final events = <ScheduledEvent>[
      for (final row in rows)
        (
          id: row.id,
          startsAt: DateTime(
            row.date.year,
            row.date.month,
            row.date.day,
            row.startMinute ~/ 60,
            row.startMinute % 60,
          ),
          title: row.title,
          tone: Tone.fromDbIndex(row.toneIndex),
        ),
    ];

    final desired = computeSchedule(
      events: events,
      now: now,
      eventSoon: toggles.eventSoon,
      roundup: toggles.roundup,
      morning: toggles.morning,
      morningMinutes: morningMinutes,
    );
    // Forced-all-on twin: anything it wants that the real set does not is an
    // orphan (toggled off, possibly before a restart) — cancel it.
    final allOn = computeSchedule(
      events: events,
      now: now,
      eventSoon: true,
      roundup: true,
      morning: true,
      morningMinutes: morningMinutes,
    );

    final wanted = {for (final item in desired) item.id};
    final before = {for (final item in _last) item.id: item};
    final failedSchedules = <int>{};
    final failedCancels = <DesiredNotification>[];
    for (final item in _last) {
      if (wanted.contains(item.id)) continue;
      try {
        await _service.cancel(item.id);
      } on Object {
        // A dead plugin entry must not block the rest of the pass.
        failedCancels.add(item);
      }
    }
    for (final item in allOn) {
      if (wanted.contains(item.id) || before.containsKey(item.id)) continue;
      try {
        await _service.cancel(item.id);
      } on Object {
        // Same rule.
        failedCancels.add(item);
      }
    }
    for (final item in desired) {
      final old = before[item.id];
      if (old != null &&
          old.at == item.at &&
          old.title == item.title &&
          old.body == item.body) {
        continue;
      }
      try {
        await _service.schedule(
          id: item.id,
          at: item.at,
          title: item.title,
          body: item.body,
        );
      } on Object {
        // One bad item never blocks the rest.
        failedSchedules.add(item.id);
      }
    }
    // Failed schedules stay out of `_last` so the next pass retries them;
    // failed cancels stay in so they are attempted again.
    _last = [
      for (final item in desired)
        if (!failedSchedules.contains(item.id)) item,
      ...failedCancels,
    ];
  }
}
```

> Notes for the implementer:
>
> - Toggle reads use `valueFor(key) != '0'` (missing or anything-but-`'0'` means on) instead of `SettingsRepository.getBool(..., defaultValue: true)` so the scheduler needs only the DAO. Either is fine — keep this form.
> - `row.date` is already a local midnight; the `startsAt` construction is calendar arithmetic, DST-safe for ordinary days.

- [ ] **Step 5: Add the providers and watch them**

**Edit `lib/data/providers.dart`** — add after `notificationServiceProvider`:

Replace:
```dart
/// Local notifications. Tests replace it with a fake, so nothing in a test run
/// reaches the plugin.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return LocalNotificationService();
});
```
With:
```dart
/// Local notifications. Tests replace it with a fake, so nothing in a test run
/// reaches the plugin.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return LocalNotificationService();
});

/// The foreground notification reconciler (spec §10).
final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  return DriftNotificationScheduler(
    ref.watch(appDatabaseProvider),
    ref.watch(notificationServiceProvider),
    materialiser: ref.watch(seriesMaterialiserProvider),
  );
});

/// Materialises the next 7 days, then reconciles notifications: once on first
/// watch, on every foreground, and on every events-table write. Watch it from
/// a widget that lives as long as the app (ClockTab). Passes serialize inside
/// the scheduler; a failing plugin never surfaces here.
final foregroundRefreshProvider = Provider<void>((ref) {
  final scheduler = ref.watch(notificationSchedulerProvider);
  final db = ref.watch(appDatabaseProvider);

  void refresh() {
    unawaited(scheduler.reconcile());
  }

  final tables = db
      .tableUpdates(TableUpdate.onTable(db.events))
      .listen((_) => refresh());
  ref.onDispose(tables.cancel);
  final lifecycle = AppLifecycleListener(onResume: refresh);
  ref.onDispose(lifecycle.dispose);
  refresh();
});
```

> Note for the implementer: this needs `dart:async` (`unawaited`), `package:drift/drift.dart` (`TableUpdate`), `package:flutter/widgets.dart` (`AppLifecycleListener`), and imports of the scheduler and providers already in the file. `tableUpdates` with a filter is the same API the (unexecuted) Step 4 plan verified against drift 2.34.3 — if the signature differs, use the broadcast `tableUpdates()` and ignore the payload.

**Edit `lib/app/navigation/clock_tab.dart`** — one pair (confirm the anchor; the session sync watch is at line 20):

Replace:
```dart
    ref.watch(sessionAlertsSyncProvider);
```
With:
```dart
    ref.watch(sessionAlertsSyncProvider);
    ref.watch(foregroundRefreshProvider);
```

- [ ] **Step 6: Run the tests to verify they pass**

```bash
# expect: PASS - 6 scheduler tests and settings (incl. 1 new int test)
flutter test test/data/notification_scheduler_test.dart test/data/settings_test.dart
```

- [ ] **Step 7: Analyze, run the suite, commit**

```bash
# expect: PASS - analyzer clean; whole suite green
flutter analyze && flutter test
```

```bash
# expect: RUN
git add lib/data/repositories/notification_scheduler.dart lib/data/notifications/notification_permission.dart \
  lib/data/daos/event_dao.dart lib/data/repositories/settings_repository.dart \
  test/support/fake_settings_repository.dart lib/data/providers.dart lib/app/navigation/clock_tab.dart \
  test/data/notification_scheduler_test.dart test/data/settings_test.dart
git commit -m "feat: foreground notification reconciler

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

### Task 3: Shared permission flow and the session-end toggle

The first-use permission flow moves into the data layer for reuse, and the existing session alert obeys its new toggle. Behavior is preserved pin-for-pin by the existing tests.

**Files:**
- Modify: `lib/data/notifications/notification_permission.dart` (add the helper), `lib/features/session/session_alerts.dart` (move the key, gate `_sync`, refactor `_permitted`)
- Test: `test/data/notification_permission_test.dart` (new), `test/features/session/session_alerts_test.dart` (append 2 tests)

**Interfaces:**
- Consumes: toggle keys + `defaultMorningMinutes` from Task 2; `SettingsRepository.getBool` (existing).
- Produces: `ensureNotificationPermission({required NotificationService service, required SettingsRepository settings}) → Future<bool>` (true when alerts may fire; never throws).

- [ ] **Step 1: Write the failing tests**

**Create `test/data/notification_permission_test.dart`**

```dart
import 'package:energy_clock/data/notifications/notification_permission.dart';
import 'package:energy_clock/data/notifications/notification_service.dart';
import 'package:energy_clock/data/repositories/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_notification_service.dart';
import '../support/fake_settings_repository.dart';

void main() {
  late FakeNotificationService service;
  late FakeSettingsRepository settings;

  setUp(() {
    service = FakeNotificationService();
    settings = FakeSettingsRepository();
  });

  Future<bool> ensure() => ensureNotificationPermission(
    service: service,
    settings: settings,
  );

  test('an enabled system passes through without prompting', () async {
    expect(await ensure(), isTrue);
    expect(service.requests, 0);
    expect(settings.values, isEmpty);
  });

  test('the prompt fires once and a grant sticks', () async {
    service.enabled = false;

    expect(await ensure(), isTrue);
    expect(service.requests, 1);
    expect(settings.values['notifications_prompted'], isTrue);

    // Already prompted and granted: no second prompt.
    service.enabled = true;
    expect(await ensure(), isTrue);
    expect(service.requests, 1);
  });

  test('a refusal never prompts again and reads as denied', () async {
    service
      ..enabled = false
      ..grantsRequest = false;

    expect(await ensure(), isFalse);
    expect(await ensure(), isFalse);
    expect(service.requests, 1);
  });

  test('a failing plugin reads as refused', () async {
    service.enabled = false;
    settings.failReads = true;

    expect(await ensure(), isFalse);
  });
}
```

**Edit `test/features/session/session_alerts_test.dart`** — two pairs. First the import (the key moved out of `session_alerts.dart`, which this file already imports for other names):

Replace:
```dart
import 'package:energy_clock/features/session/providers.dart';
```
With:
```dart
import 'package:energy_clock/data/notifications/notification_permission.dart';
import 'package:energy_clock/features/session/providers.dart';
```

Then append inside the `scheduling` group:

```dart
    test('a switched-off session toggle cancels instead of scheduling', () async {
      harness.settings.values[notifySessionEndKey] = false;
      final session = await startSession();

      await alerts().sync(session);

      expect(harness.notifications.pending, isEmpty);
      expect(harness.notifications.requests, 0);
    });

    test('an unset session toggle schedules as before', () async {
      final session = await startSession();

      await alerts().sync(session);

      expect(
        harness.notifications.pending[sessionEndNotificationId],
        isNotNull,
      );
    });
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL - compile error: ensureNotificationPermission and the toggle keys do not exist yet.
flutter test test/data/notification_permission_test.dart test/features/session/session_alerts_test.dart
```

- [ ] **Step 3: Add the helper and move the key**

**Edit `lib/data/notifications/notification_permission.dart`** — append:

```dart
import 'package:energy_clock/data/notifications/notification_service.dart';
import 'package:energy_clock/data/repositories/settings_repository.dart';

/// Set once the system permission prompt has been shown, so the app never asks
/// twice. iOS cannot tell "never asked" from "refused", so the app remembers.
/// (Moved here from `session_alerts.dart`: the toggle flow needs the same key
/// and the data layer cannot import a feature.)
const String notificationsPromptedKey = 'notifications_prompted';

/// The shared first-use permission flow: an enabled system passes through, the
/// system prompt fires once and its answer sticks, and a refusal after
/// prompting returns false at once. Never throws — a failing plugin reads as
/// refused so callers degrade instead of crashing.
Future<bool> ensureNotificationPermission({
  required NotificationService service,
  required SettingsRepository settings,
}) async {
  try {
    if (await service.areEnabled()) return true;
    if (!await settings.getBool(notificationsPromptedKey)) {
      await settings.setBool(notificationsPromptedKey, true);
      return await service.requestPermission();
    }
    return false;
  } on Object {
    return false;
  }
}
```

- [ ] **Step 4: Rewire the session alerts**

**Edit `lib/features/session/session_alerts.dart`** — three pairs

Replace:
```dart
import 'package:energy_clock/data/notifications/notification_service.dart';
```
With:
```dart
import 'package:energy_clock/data/notifications/notification_permission.dart';
import 'package:energy_clock/data/notifications/notification_service.dart';
```

Replace:
```dart
/// Set once the system permission prompt has been shown, so the app never asks
/// twice. iOS cannot tell "never asked" from "refused", so the app remembers.
const String notificationsPromptedKey = 'notifications_prompted';

```
With:
```dart
```
(That is: delete the const and its doc comment — it now lives in `notification_permission.dart`, which this file imports, so `session_alerts_test.dart` keeps resolving the name through its existing `session_alerts.dart` import. Confirm no other file defines it.)

Replace:
```dart
  Future<void> _sync(RunningSession? session) async {
    try {
      final service = ref.read(notificationServiceProvider);
      final now = ref.read(sessionNowSourceProvider)();
```
With:
```dart
  Future<void> _sync(RunningSession? session) async {
    try {
      final service = ref.read(notificationServiceProvider);
      if (!await ref
          .read(settingsRepositoryProvider)
          .getBool(notifySessionEndKey, defaultValue: true)) {
        await service.cancel(sessionEndNotificationId);
        return;
      }
      final now = ref.read(sessionNowSourceProvider)();
```

Replace:
```dart
  Future<bool> _permitted(NotificationService service) async {
    if (await service.areEnabled()) {
      state = AlertsStatus.granted;
      return true;
    }
    final settings = ref.read(settingsRepositoryProvider);
    if (!await settings.getBool(notificationsPromptedKey)) {
      await settings.setBool(notificationsPromptedKey, true);
      if (await service.requestPermission()) {
        state = AlertsStatus.granted;
        return true;
      }
    }
    state = AlertsStatus.denied;
    return false;
  }
```
With:
```dart
  Future<bool> _permitted(NotificationService service) async {
    final granted = await ensureNotificationPermission(
      service: service,
      settings: ref.read(settingsRepositoryProvider),
    );
    state = granted ? AlertsStatus.granted : AlertsStatus.denied;
    return granted;
  }
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
# expect: PASS - permission (4 new) plus the whole alerts file incl. 2 new toggle tests
flutter test test/data/notification_permission_test.dart test/features/session/session_alerts_test.dart
```

- [ ] **Step 6: Analyze, run the suite, commit**

```bash
# expect: PASS - analyzer clean; whole suite green
flutter analyze && flutter test
```

```bash
# expect: RUN
git add lib/data/notifications/notification_permission.dart lib/features/session/session_alerts.dart \
  test/data/notification_permission_test.dart test/features/session/session_alerts_test.dart
git commit -m "feat: shared permission flow and session alert toggle

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Stage 3 — Profile settings UI

### Task 4: Notification toggles, morning row, off-state

Profile's first real section. `ProfileScreen` is still the placeholder, so this task gives it a single Notifications group — structured so Step 4's shell task keeps this widget and adds its own sections around it.

**Files:**
- Create: `lib/features/progress/widgets/notification_settings.dart`
- Modify: `lib/features/progress/profile_screen.dart` (render the section), `lib/core/strings.dart` (settings copy)
- Test: `test/features/progress/notification_settings_test.dart` (new)

**Interfaces:**
- Consumes: toggle keys + `defaultMorningMinutes` (Task 2), `ensureNotificationPermission` (Task 3), `chooseOne` + `CupertinoSwitch` patterns (existing shared widgets), `morningReminderMinutesKey` int access (Task 2).
- Produces: `NotificationSettingsSection` (`ConsumerWidget`); row keys `settings-notify-session`, `settings-notify-event`, `settings-notify-roundup`, `settings-notify-morning`, `settings-morning-time`, `settings-notifications-off`.

> Step 4 merge note: Step 4's plan replaces `profile_screen.dart` wholesale (its Tasks 17–19). That replacement must render `NotificationSettingsSection` (imported from this file) instead of dropping it — the section, its keys and its tests are canonical as written here.

- [ ] **Step 1: Write the failing tests**

**Create `test/features/progress/notification_settings_test.dart`**

```dart
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/notifications/notification_permission.dart';
import 'package:energy_clock/features/progress/profile_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(harness.app(const ProfileScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('the four toggles default to on', (tester) async {
    await mount(tester);

    for (final key in [
      'settings-notify-session',
      'settings-notify-event',
      'settings-notify-roundup',
      'settings-notify-morning',
    ]) {
      final switches = find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(CupertinoSwitch),
      );
      expect(switches, findsOneWidget);
      expect(tester.widget<CupertinoSwitch>(switches).value, isTrue);
    }
    expect(find.text(formatDurationMinutes(480)), findsOneWidget);
  });

  testWidgets('flipping a toggle persists it', (tester) async {
    await mount(tester);

    await tester.tap(find.byKey(const ValueKey('settings-notify-event')));
    await tester.pumpAndSettle();

    expect(harness.settings.values[notifyEventSoonKey], isFalse);
  });

  testWidgets('a refused permission snaps the toggle back with guidance', (tester) async {
    harness.notifications
      ..enabled = false
      ..grantsRequest = false;
    await mount(tester);

    await tester.tap(find.byKey(const ValueKey('settings-notify-roundup')));
    await tester.pumpAndSettle();

    expect(harness.settings.values[notifyRoundupKey], isNot(isTrue));
    expect(find.text(Strings.notificationsDenied), findsOneWidget);
    await tester.tap(find.text(Strings.notificationsOpenSettings));
    expect(harness.notifications.settingsOpened, 1);
  });

  testWidgets('the morning row picks a time from the sheet', (tester) async {
    await mount(tester);

    await tester.tap(find.byKey(const ValueKey('settings-morning-time')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('6:00 AM'));
    await tester.pumpAndSettle();

    expect(harness.settings.values[morningReminderMinutesKey], '360');
  });

  testWidgets('the morning row disables with its toggle off', (tester) async {
    harness.settings.values[notifyMorningKey] = false;
    await mount(tester);

    await tester.tap(find.byKey(const ValueKey('settings-morning-time')));
    await tester.pumpAndSettle();

    // No sheet opens for a disabled row.
    expect(find.text('6:00 AM'), findsNothing);
  });

  testWidgets('an OS-level refusal shows the off-state row instead', (tester) async {
    harness.notifications.enabled = false;
    harness.settings.values['notifications_prompted'] = true;
    await mount(tester);

    expect(find.byKey(const ValueKey('settings-notifications-off')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-notify-session')), findsNothing);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL - compile error: NotificationSettingsSection, the row keys and the settings strings do not exist yet.
flutter test test/features/progress/notification_settings_test.dart
```

- [ ] **Step 3: Add the strings**

**Edit `lib/core/strings.dart`** — append a settings-notifications block (place it with the other settings copy if any exists yet, otherwise after the session strings):

```dart
  // Notification settings (spec §10).
  static const String settingsNotifications = 'Notifications';
  static const String notifySessionEndLabel = 'Session end';
  static const String notifyEventSoonLabel = 'Event starting soon';
  static const String notifyRoundupLabel = 'Weekly roundup';
  static const String notifyMorningLabel = 'Morning reminder';
  static const String morningTimeLabel = 'Reminder time';
  static const String notificationsDenied =
      'Notifications are off. Turn them on to use alerts.';
  static const String notificationsOpenSettings = 'Open Settings';
  static const String notificationsOffTitle = 'Notifications are off';
  static const String notificationsOffBody =
      'The app cannot send alerts until they are allowed in Settings.';
```

- [ ] **Step 4: Create the section widget**

**Create `lib/features/progress/widgets/notification_settings.dart`**

```dart
import 'dart:async';

import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/notifications/notification_permission.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/notification_scheduler.dart';
import 'package:energy_clock/shared/widgets/adaptive_choice.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:energy_clock/shared/widgets/section_header.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The Notifications group of Profile's settings: four per-type toggles, the
/// morning-time row, and the OS-off state (spec §10). Step 4's Profile shell
/// keeps this widget and adds its own sections around it.
class NotificationSettingsSection extends ConsumerWidget {
  const NotificationSettingsSection({super.key});

  /// Morning choices, minutes since midnight: 06:00–10:00 in 30-minute steps.
  static const List<int> morningChoices = [
    360, 390, 420, 450, 480, 510, 540, 570, 600,
  ];

  static String _morningLabel(int minutes) => DateFormat('h:mm a').format(
    DateTime(2026, 1, 1).add(Duration(minutes: minutes)),
  );

  Future<void> _flip({
    required BuildContext context,
    required WidgetRef ref,
    required String key,
    required bool value,
  }) async {
    final settings = ref.read(settingsRepositoryProvider);
    if (!value) {
      await settings.setBool(key, false);
      ref.invalidate(_togglesProvider);
      unawaited(ref.read(notificationSchedulerProvider).reconcile());
      return;
    }
    final granted = await ensureNotificationPermission(
      service: ref.read(notificationServiceProvider),
      settings: settings,
    );
    if (!context.mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Strings.notificationsDenied),
          action: SnackBarAction(
            label: Strings.notificationsOpenSettings,
            onPressed:
                () => unawaited(
                  ref.read(notificationServiceProvider).openSettings(),
                ),
          ),
        ),
      );
      return;
    }
    await settings.setBool(key, true);
    ref.invalidate(_togglesProvider);
    unawaited(ref.read(notificationSchedulerProvider).reconcile());
  }

  Future<void> _pickMorning(BuildContext context, WidgetRef ref) async {
    final picked = await chooseOne<int>(
      context,
      title: Strings.morningTimeLabel,
      cancelLabel: Strings.cancel,
      options: [
        for (final minutes in morningChoices)
          ChoiceOption(label: _morningLabel(minutes), value: minutes),
      ],
    );
    if (picked == null || !context.mounted) return;
    await ref
        .read(settingsRepositoryProvider)
        .setInt(morningReminderMinutesKey, picked);
    ref.invalidate(_togglesProvider);
    unawaited(ref.read(notificationSchedulerProvider).reconcile());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final system = ref.watch(_systemEnabledProvider);
    return system.when(
      data:
          (enabled) =>
              enabled
                  ? _Toggles(
                    onFlip:
                        (key, value) => _flip(
                          context: context,
                          ref: ref,
                          key: key,
                          value: value,
                        ),
                    onMorning: () => _pickMorning(context, ref),
                  )
                  : const _OffState(),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _Toggles extends ConsumerWidget {
  const _Toggles({required this.onFlip, required this.onMorning});

  final Future<void> Function(String key, bool value) onFlip;
  final VoidCallback onMorning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toggles = ref.watch(_togglesProvider);
    return toggles.when(
      data: (state) {
        final colors = context.appColors;
        final theme = Theme.of(context);
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(title: Strings.settingsNotifications),
              const SizedBox(height: AppSpacing.sm),
              _ToggleRow(
                rowKey: 'settings-notify-session',
                label: Strings.notifySessionEndLabel,
                value: state.session,
                onChanged:
                    (value) => onFlip(notifySessionEndKey, value),
              ),
              _ToggleRow(
                rowKey: 'settings-notify-event',
                label: Strings.notifyEventSoonLabel,
                value: state.event,
                onChanged: (value) => onFlip(notifyEventSoonKey, value),
              ),
              _ToggleRow(
                rowKey: 'settings-notify-roundup',
                label: Strings.notifyRoundupLabel,
                value: state.roundup,
                onChanged: (value) => onFlip(notifyRoundupKey, value),
              ),
              _ToggleRow(
                rowKey: 'settings-notify-morning',
                label: Strings.notifyMorningLabel,
                value: state.morning,
                onChanged: (value) => onFlip(notifyMorningKey, value),
              ),
              InkWell(
                key: const ValueKey('settings-morning-time'),
                onTap: state.morning ? onMorning : null,
                borderRadius: BorderRadius.circular(AppRadii.control),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          Strings.morningTimeLabel,
                          style: theme.textTheme.bodyLarge!.copyWith(
                            color:
                                state.morning ? null : colors.muted,
                          ),
                        ),
                      ),
                      Text(
                        NotificationSettingsSection._morningLabel(
                          state.minutes,
                        ),
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: state.morning ? null : colors.muted,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 18,
                        color: colors.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.rowKey,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String rowKey;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    // The whole row toggles: a bigger target than the switch alone.
    return MergeSemantics(
      child: InkWell(
        key: ValueKey(rowKey),
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              CupertinoSwitch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _OffState extends ConsumerWidget {
  const _OffState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: InkWell(
        key: const ValueKey('settings-notifications-off'),
        onTap:
            () => unawaited(
              ref.read(notificationServiceProvider).openSettings(),
            ),
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                Strings.notificationsOffTitle,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                Strings.notificationsOffBody,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The four toggle states plus the morning minutes, read together so the
/// section builds once.
final _togglesProvider = FutureProvider<
  ({bool session, bool event, bool roundup, bool morning, int minutes})
>((ref) async {
  final settings = ref.watch(settingsRepositoryProvider);
  return (
    session: await settings.getBool(notifySessionEndKey, defaultValue: true),
    event: await settings.getBool(notifyEventSoonKey, defaultValue: true),
    roundup: await settings.getBool(notifyRoundupKey, defaultValue: true),
    morning: await settings.getBool(notifyMorningKey, defaultValue: true),
    minutes:
        await settings.getInt(morningReminderMinutesKey) ??
        defaultMorningMinutes,
  );
});

final _systemEnabledProvider = FutureProvider<bool>((ref) {
  return ref.watch(notificationServiceProvider).areEnabled();
});
```

- [ ] **Step 5: Render the section on Profile**

**Replace `lib/features/progress/profile_screen.dart`**

```dart
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/features/progress/widgets/notification_settings.dart';
import 'package:energy_clock/shared/layout/content_width.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Profile tab. Today it holds the Notifications group (Step 5); Step 4's
/// shell task adds level, score, badges, roundups and the rest of settings
/// around `NotificationSettingsSection` — it must keep this widget.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ContentWidth(
        // `ContentWidths.stats` (800) arrives with Step 4; until then 560.
        maxWidth: ContentWidths.column,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [NotificationSettingsSection()],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Run the tests to verify they pass**

```bash
# expect: PASS - 6 tests
flutter test test/features/progress/notification_settings_test.dart
```

- [ ] **Step 7: Analyze, run the suite, commit**

```bash
# expect: PASS - analyzer clean; whole suite green
flutter analyze && flutter test
```

```bash
# expect: RUN
git add lib/features/progress/widgets/notification_settings.dart lib/features/progress/profile_screen.dart \
  lib/core/strings.dart test/features/progress/notification_settings_test.dart
git commit -m "feat: notification toggles and morning row on Profile

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Stage 4 — Docs and device verification

### Task 5: README, manual verification, full suite

- [ ] **Step 1: Update the README**

**Edit `README.md`** — one pair:

Replace:
```dart
It runs on iPhone (portrait) and iPad (all orientations). The dial planner, the week strip, the Now card, the event sheets, the session timer, repeating events, day templates, Copy yesterday and the Calendar are done; the Stats and Profile tabs are still placeholders.
```
With:
```dart
It runs on iPhone (portrait) and iPad (all orientations). The dial planner, the week strip, the Now card, the event sheets, the session timer, repeating events, day templates, Copy yesterday and the Calendar are done; the Stats and Profile tabs are still placeholders; local notifications (session end, event reminders, morning nudge, roundup announcement) with per-type Profile toggles are done.
```

- [ ] **Step 2: Manual device verification**

```bash
# expect: MANUAL - on the iPhone simulator (this needs macOS; cannot run on this Windows machine):
# 1. Fresh install: start a session -> system prompt appears once; allow.
#    Foreground the app -> event reminders for the next 7 days appear in
#    Settings > Notifications > Energy Clock as scheduled (verify via logging:
#    temporarily add a debug print of desired ids, then remove it).
# 2. Lock the device with a session running -> "time is up" fires at the planned end.
# 3. Create a morning event tomorrow, leave today empty -> morning reminder fires
#    only for the empty day; fill today -> reminder cancelled after foreground.
# 4. Sunday 20:00 (override the clock on a dev build) -> roundup notification fires.
# 5. Deny permission -> toggles snap back with the guidance snackbar; the
#    OS-off row appears and opens Settings.
# Record the results in the task report; screenshots of the Profile group.
```

- [ ] **Step 3: Confirm formatting, analyze, run the full suite**

```bash
# expect: PASS - no output means every file is formatted
DART="$(dirname "$(which flutter)")/dart"
"$DART" format --output=none --set-exit-if-changed lib test
```

```bash
# expect: PASS - analyzer clean; whole suite green
flutter analyze && flutter test
```

- [ ] **Step 4: Commit**

```bash
# expect: RUN
git add README.md
git commit -m "docs: notifications are done

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 5: Self-review the plan**

```bash
# expect: MANUAL - read the finished plan end to end and check:
# - every spec section (§1-§11) has a task: §1 ids/copy -> Tasks 1-2, §2 scheduler
#   -> Task 2, §3 permission -> Tasks 3-4, §4 materialisation -> Task 2,
#   §5 UI -> Task 4, §6 copy -> Tasks 1/4, §7 errors -> Tasks 2-4, §8 testing
#   -> all tasks, §9 order -> task order, §10 scope respected;
# - names match across tasks (keys, ids, provider names, fake APIs, row keys);
# - no feature-to-feature imports; no new packages; no schema change;
# - no dangling references to Step 4 artifacts except the flagged merge points.
# Fix what you find before handing over.
```


