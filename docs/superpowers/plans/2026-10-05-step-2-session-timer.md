# Energy Clock — Step 2: Session Timer — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tapping an event starts a timed session. A countdown ring takes the Clock tab's place, with pause and resume, add 5 or 15 minutes, finish early or finish, and abandon. When time runs out the ring turns red and counts up; a local notification tells the person if the app is closed; a session left running by a killed app is offered for resume or close-out. A finished session is recorded and completes its event.

**Architecture:** Timing is pure wall-clock arithmetic (`SessionTiming`): a session stores its start, its total paused seconds and the start of the current pause, and every number on screen is worked out from the clock, so nothing drifts and iOS suspending the app changes nothing. Sessions live in a new Drift table (schema v2, with the project's first migration and migration test). A `SessionRepository` in the shared data layer starts, steers and ends sessions, so the Clock feature can start one without importing the session feature. The session feature owns the screen, the ticking clock, the notification logic and recovery; the app layer (`ClockTab`) composes the two features. The "time is up" notification is a pure function of the running session, kept in step by one listener, so pause, resume, extend and a relaunch all reschedule it in one place.

**Tech Stack:** Flutter 3.44.7, Dart 3.12.2, `flutter_riverpod` 2.6, `drift` + `drift_flutter` (+ `drift_dev schema` for migration tests), `intl`, and two new packages already approved in the Aug 23 spec §15: `flutter_local_notifications` ^22.3.1 and `timezone` ^0.11.1.

**Spec:** `docs/superpowers/specs/2026-08-23-energy-clock-design.md`. This plan implements §6 (session), the "session ended" row of §10, the `sessions` table of §4.2, and the session parts of §12–§13. The Step 1 spec (`docs/superpowers/specs/2026-10-03-step-1-foundation-design.md`) promised the Start button on the Now card and the detail sheet "in Step 2"; this plan adds it. Where this plan departs from the Aug 23 spec, the "Decisions and amendments" table below records it. **It must run after Step 1 is merged** (the design system, the Clock screen, the harness and the layout matrix it builds on).

## Global Constraints

These apply to every task. Copied from the specs and the Step 1 plans, with the schema and package lines updated for this step.

- **Platform:** iOS 15+. iPhone in portrait; iPad in all four orientations with resizable windows. Flutter 3.44.7 / Dart 3.12.2.
- **Language:** English-only. All user-facing copy lives in `lib/core/strings.dart`. No localisation framework.
- **Tones are fixed:** exactly three — Focus (purple), Life (green), Inbox (orange). Not addable, removable, renameable, or recolourable.
- **Colour only ever encodes a tone.** UI accent (buttons, selected tab) is near-black in light mode and near-white in dark mode, never purple. The one other colour on the session screen is the `danger` colour, for overtime.
- **No hard-coded colours in feature code.** Nothing under `lib/features/` may contain `Color(0x` or `Colors.`. Every colour comes from `context.appColors`, `context.toneColors`, `AppColors.transparent`, or `Theme.of(context).colorScheme`. Enforced by `test/architecture/no_hardcoded_colors_test.dart`.
- **Boundary rule:** no file under `lib/features/<a>/` may import from `lib/features/<b>/`. `lib/app/` composes features and may import them. Cross-feature communication goes through repositories exposed as Riverpod providers (here: `sessionRepositoryProvider` in `lib/data/providers.dart`).
- **Minute domain:** `startMinute` is 0–1439, `endMinute` is 1–1440 and exclusive, and never exceeds 1440. Session times are whole seconds.
- **Derived, never accumulated:** nothing about a session is counted up as it runs. Remaining time, overtime and elapsed time are recomputed from the clock on every tick and on every return to the foreground. Streak, score, XP and badges (Steps 4–5) will be derived from the `sessions` and `events` rows, so this step writes rows and calls nothing else.
- **Window classes:** narrow under 600 pt, medium 600–899 pt, wide 900 pt and up. Layout follows the app window width, not the device name. Every new screen is checked at the eight sizes of the layout matrix.
- **Tap targets** are at least 44 pt. **Contrast:** text pairs at least 4.5:1, arcs against the face at least 3:1. The session screen uses only token pairs the existing contrast tests already cover (`ink`, `muted` and `danger` on `page` and `surface`; each tone's `solid` on `surface`; `onSolid` on `solid`).
- **Reduce Motion:** the session screen has no animation of its own (the ring and the digits simply redraw each second); the buttons' press-scale already honours Reduce Motion. Keep it that way.
- **New runtime packages:** only `flutter_local_notifications` and `timezone`. `flutter pub add` also pulls in the plugin's web, Linux and Windows halves and their pure-Dart helpers (`http`, `xml`, `dbus` and others); the app never imports them and the iOS build does not link them. No charting library, no HTTP client of our own, no analytics SDK.
- **Schema:** version 2. Every schema change ships with a migration step and a migration test (`test/data/migration_test.dart`), built on `drift_schemas/` and `test/generated_migrations/`.
- **Tooling:** run Dart commands, including `build_runner` and `drift_dev`, with the Flutter SDK's `dart` (`"$(dirname "$(which flutter)")/dart"`). The first `dart` on this machine's PATH is 3.10 and fails on this project.
- **Style:** `flutter analyze` must stay clean; the repo follows `dart format` and the lints in `analysis_options.yaml` (single quotes, `unawaited_futures`, `prefer_final_locals`, `always_declare_return_types`). The code in this plan is already formatted; Task 15 only confirms it.
- **Commit messages** use the repo's conventional prefixes (`feat:`, `fix:`, `test:`, `refactor:`, `docs:`, `chore:`) and end with a blank line and the trailer `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## Decisions and amendments

These were settled while writing the plan from the Aug 23 spec. They are the places where the spec was silent, ambiguous, or has since been overtaken by Step 1. **Items 1, 2 and 4 are the ones most worth a second look.**

| # | Area | Decision | Why |
|---|---|---|---|
| 1 | Where the session appears | The session screen takes the **whole Clock tab's place** (header, week strip, dial, cards) while a session runs; the tab bar and the other three tabs stay. The Aug 23 spec says it "replaces the dial". | After Step 1 the dial is one of five things on the Clock page. Replacing only the dial would leave a Now card and day-load bar beside a countdown that say something else. |
| 2 | Notifications in this step | **Only "session ended".** "Event starting soon", "Weekly Roundup ready" and "Daily planning reminder" move to Step 5. | The other three need the settings (on/off, lead time, reminder time) that arrive in Step 5. A notification the person cannot switch off should not ship, and "starting soon" also needs the recurring-event window from Step 3. |
| 3 | Permission | Asked **once, when the first session starts**, never at launch. iOS cannot tell "never asked" from "refused", so the app records in `settings` that it has asked. A refusal never stops a session; a **one-time banner** on the session screen says alerts are off and offers Open Settings (via the plugin; no native code). | Spec §10 and §6.5. |
| 4 | Recovery after a killed app | A session already running when the app **launches** is a leftover. The session screen shows a card in place of the buttons: **Resume** (carry on; the clock kept running, so overtime may already show) or **Close out**. Close-out records **at most the planned time**. | The spec says "resume or close-out" but not what close-out records. Time the app was closed is unverifiable, and overtime nobody watched would spoil the planned-versus-actual statistics. |
| 5 | One session at a time | Starting while another runs is refused. A session can only be started on an event that is **planned and on today**. Finished and abandoned sessions stay as rows; an abandoned session leaves the event planned. Finishing (early or late) completes the event. | Spec §6.4. Starting on a future or past day is not in the spec; a past day is read-only and a session is for what you are doing now. |
| 6 | Deleting an event | Also deletes its sessions, in one transaction. | A session row must never point at an event that no longer exists. |
| 7 | Start button | On the Now card (running or next event, full-size card only) and the detail sheet. A finished event shows **Done** on the card and **Completed** in the sheet instead. VoiceOver gets a "Start session" custom action on the card. | Step 1 spec §2 and §9. |
| 8 | Finish wording | "Finish early" before the planned end; "Finish" (and the primary button) once in overtime. Abandon asks for confirmation; finishing does not. | The spec lists the controls but not the wording. |
| 9 | No streak / score / XP / badge call | `finish` writes the session and the event status and nothing else. | Spec §9.1: those numbers are derived from the rows. Spec §6.4's "triggers recalculation" is satisfied when Steps 4–5 read the rows. |
| 10 | Notification delivery | Scheduled as an **absolute instant in UTC** (`tz.UTC`, no time-zone database and no `flutter_timezone`). The app does not set the plugin's foreground-presentation delegate. | A session end is an instant, so daylight-saving rules cannot move it. A banner while the session screen is open adds nothing. |
| 11 | Privacy manifest | Not handled here. Step 6 must check the plugin's required-reason API use before submission. | Step 6 owns the submission kit. |

## Out of scope (later steps)

- "Event starting soon", Weekly Roundup and daily-planning notifications, and every notification setting (Step 5).
- Recurring events, templates, copy-yesterday, the Calendar tab (Step 3). Stats, streak, score, XP and badges (Steps 4–5).
- Live Activities, widgets and Dynamic Island (out of scope for the whole app).
- Starting a session from the Today's plan list on iPad: tapping a row opens the detail sheet, which has Start.

## How to read the steps

- **Create / Replace / Edit / Delete** blocks give the exact file change. A **Replace** block is the whole new file. An **Edit** block shows the exact text to find (`Replace:`) and what to put there (`With:`); the find text appears exactly once.
- A bash block whose first line is `# expect: PASS` must succeed; `# expect: FAIL` must fail for the stated reason; `# expect: RUN` and `# expect: UPDATE` are setup commands that must succeed; `# expect: MANUAL` is done by a person or the controller.
- Generated files (`*.g.dart`, `drift_schemas/*.json`, `test/generated_migrations/*`, golden images) are produced by the bash steps, not by file blocks. Commit them with the task.
- If a snippet does not compile against Flutter 3.44.7, fix the API usage minimally, keep the behaviour and the tests' intent, and say so in your report.
- `testWidgets` runs in fake time. Session tests never use `pumpAndSettle` on a screen that ticks; they use `pumpDial` (a bounded run of frames) or a plain `pump()` after moving the fake clock.

## File Structure

**Created:**

| File | Responsibility |
|---|---|
| `lib/core/event_status.dart` | `EventStatus` (moved out of the Clock feature so the data layer can use it) |
| `lib/core/session/session_outcome.dart` | `SessionOutcome` and its stable database indices |
| `lib/core/session/session_timing.dart` | `SessionTiming`: the wall-clock arithmetic, pure Dart |
| `lib/data/tables/sessions_table.dart` | The `sessions` Drift table |
| `lib/data/daos/session_dao.dart` | Queries and writes over `sessions` joined to `events` |
| `lib/data/models/session.dart` | `SessionRecord` and `RunningSession` domain objects |
| `lib/data/repositories/session_repository.dart` | `SessionRepository` and its Drift implementation |
| `lib/data/notifications/notification_service.dart` | The `NotificationService` interface |
| `lib/data/notifications/local_notification_service.dart` | The `flutter_local_notifications` implementation |
| `lib/features/session/providers.dart` | The session clock, the running-session stream, recovery |
| `lib/features/session/session_alerts.dart` | Permission, the end-of-session notification, the banner state |
| `lib/features/session/model/session_display.dart` | What the screen shows at one moment |
| `lib/features/session/session_layout.dart` | Ring size and button layout for a window |
| `lib/features/session/session_screen.dart` | The session screen |
| `lib/features/session/widgets/countdown_ring.dart` | The ring painter and the raised face |
| `lib/features/session/widgets/session_controls.dart` | Pause, add time, finish, abandon |
| `lib/features/session/widgets/alerts_banner.dart` | The one-time "alerts are off" card |
| `lib/features/session/widgets/recovery_card.dart` | The resume / close-out card |
| `lib/app/navigation/clock_tab.dart` | The Clock tab: the day, or the session when one runs |
| `lib/features/clock/widgets/start_session.dart` | `canStartSession` and `startSessionForEvent` |
| `drift_schemas/drift_schema_v1.json`, `…_v2.json` | Schema snapshots for migration tests |
| `test/generated_migrations/*` | Generated by `drift_dev schema generate` |
| `test/support/fake_session_repository.dart`, `fake_notification_service.dart` | In-memory fakes |

**Modified:** `pubspec.yaml`, `pubspec.lock`, `ios/Podfile.lock`, `ios/Runner.xcodeproj/project.pbxproj` (CocoaPods wiring for the plugin), `lib/core/strings.dart`, `lib/core/time/day_time.dart`, `lib/app/theme/app_typography.dart`, `lib/shared/widgets/app_button.dart`, `lib/data/database.dart`, `lib/data/daos/event_dao.dart`, `lib/data/providers.dart`, `lib/features/clock/model/calendar_event.dart`, `lib/features/clock/clock_screen.dart`, `lib/features/clock/widgets/now_card.dart`, `lib/features/clock/widgets/event_detail_sheet.dart`, `lib/app/navigation/tab_scaffold.dart`, the generated `*.g.dart` files, the four Clock screen goldens, `test/support/clock_harness.dart`, `test/support/fake_clock.dart`, `test/support/fake_event_repository.dart`, `test/app/tab_scaffold_test.dart`.

---

## Stage 1 — Data and logic

### Task 1: Packages and the schema v1 snapshot

Add the two notification packages, wire the plugin into the iOS project, and take a snapshot of the **current** (version 1) database schema. The snapshot has to be taken now, before Task 3 changes the schema: it is what the migration test upgrades from. Nothing else changes, so this task has no new test; the existing suite must stay green.

**Files:**
- Modify: `pubspec.yaml`, `pubspec.lock`, `ios/Podfile.lock`, `ios/Runner.xcodeproj/project.pbxproj`
- Create: `drift_schemas/drift_schema_v1.json` (generated)

**Interfaces:**
- Produces: the `flutter_local_notifications` and `timezone` packages, importable from `lib/`; `drift_schemas/drift_schema_v1.json`.

- [ ] **Step 1: Add the packages**

**Edit `pubspec.yaml`**

Replace:

```yaml
  intl: ^0.20.3
```

With:

```yaml
  intl: ^0.20.3
  flutter_local_notifications: ^22.3.1
  timezone: ^0.11.1
```

- [ ] **Step 2: Resolve the packages**

```bash
# expect: RUN
flutter pub get
```

Expected: it resolves `flutter_local_notifications 22.3.1` and `timezone 0.11.1` (plus the plugin's own platform packages) and changes `pubspec.lock`.

- [ ] **Step 3: Snapshot schema v1**

The database is still at version 1 here, so this records the shipped schema.

```bash
# expect: RUN — prints "Wrote to drift_schemas/drift_schema_v1.json"
DART="$(dirname "$(which flutter)")/dart"
mkdir -p drift_schemas
"$DART" run drift_dev schema dump lib/data/database.dart drift_schemas/
ls drift_schemas
```

- [ ] **Step 4: Check the plugin links into the iOS app**

CocoaPods adds the plugin to the Runner project, which changes `ios/Podfile.lock` and `ios/Runner.xcodeproj/project.pbxproj`. Building for the simulator proves it links.

```bash
# expect: RUN — ends with "Built build/ios/iphonesimulator/Runner.app"
flutter build ios --simulator --debug --no-codesign
```

- [ ] **Step 5: Run the existing suite**

```bash
# expect: PASS — analyzer clean, 587 tests pass
flutter analyze && flutter test
```

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock drift_schemas ios/Podfile.lock ios/Runner.xcodeproj/project.pbxproj
git commit -m "chore: add the notification packages and snapshot schema v1

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Session outcome, the timing model and countdown formats

The pure logic first. `SessionTiming` is the heart of spec §6.2: given when a session started, how long it has been paused and when the current pause began, it answers "how much time has been worked, how much is left, how far into overtime" for any instant. It works in whole seconds and floors everything at zero, so a device clock moved backwards can never give a negative time. `SessionOutcome` names how a session ended, with stable database numbers. `formatCountdown` and `spokenDurationSeconds` turn seconds into "04:05" and "4 minutes 5 seconds".

`EventStatus` moves out of the Clock feature into `lib/core/`, because the data layer (a later task) must set an event to completed and the data layer may not import a feature. `calendar_event.dart` re-exports it, so no existing import changes.

**Files:**
- Create: `lib/core/event_status.dart`, `lib/core/session/session_outcome.dart`, `lib/core/session/session_timing.dart`
- Replace: `lib/features/clock/model/calendar_event.dart`
- Modify: `lib/core/time/day_time.dart`
- Test: `test/core/session/session_timing_test.dart`, `test/core/time/countdown_format_test.dart`

**Interfaces:**
- Produces: `EventStatus { planned, completed, skipped }` with `dbIndex` and `fromDbIndex`; `SessionOutcome { running, completed, finishedEarly, abandoned }` with `dbIndex`, `fromDbIndex`, `countsAsDone`; `SessionTiming({startedAt, plannedSeconds, pausedSeconds, pauseStartedAt})` with `isPaused`, `elapsedSecondsAt(now)`, `remainingSecondsAt(now)`, `overtimeSecondsAt(now)`, `isOvertimeAt(now)`, `plannedEnd`, `currentPauseSecondsAt(now)`, `pausedSecondsTotalAt(now)`; `formatCountdown(int seconds)`; `spokenDurationSeconds(int seconds)`.

- [ ] **Step 1: Write the failing tests**

**Create `test/core/session/session_timing_test.dart`**

```dart
import 'package:energy_clock/core/session/session_outcome.dart';
import 'package:energy_clock/core/session/session_timing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 10, 7, 10, 0, 0);

  SessionTiming timing({
    int planned = 1500,
    int paused = 0,
    DateTime? pauseStartedAt,
  }) => SessionTiming(
    startedAt: start,
    plannedSeconds: planned,
    pausedSeconds: paused,
    pauseStartedAt: pauseStartedAt,
  );

  DateTime at(int seconds) => start.add(Duration(seconds: seconds));

  group('while running', () {
    test('counts down from the planned length', () {
      final t = timing();
      expect(t.elapsedSecondsAt(at(0)), 0);
      expect(t.remainingSecondsAt(at(0)), 1500);
      expect(t.elapsedSecondsAt(at(90)), 90);
      expect(t.remainingSecondsAt(at(90)), 1410);
      expect(t.isOvertimeAt(at(90)), isFalse);
      expect(t.overtimeSecondsAt(at(90)), 0);
    });

    test('ignores the part of a second that has not finished', () {
      final t = timing();
      final almost = at(90).add(const Duration(milliseconds: 999));
      expect(t.elapsedSecondsAt(almost), 90);
    });

    test('goes into overtime exactly when the planned time is used up', () {
      final t = timing();
      expect(t.isOvertimeAt(at(1499)), isFalse);
      expect(t.isOvertimeAt(at(1500)), isTrue);
      expect(t.overtimeSecondsAt(at(1500)), 0);
      expect(t.remainingSecondsAt(at(1500)), 0);
    });

    test('keeps counting up in overtime', () {
      final t = timing();
      expect(t.overtimeSecondsAt(at(1500 + 205)), 205);
      expect(t.remainingSecondsAt(at(1500 + 205)), -205);
    });
  });

  group('pauses', () {
    test('time spent paused is not counted', () {
      final t = timing(paused: 120);
      expect(t.elapsedSecondsAt(at(600)), 480);
    });

    test('a pause in progress freezes the elapsed time', () {
      final t = timing(paused: 60, pauseStartedAt: at(300));
      expect(t.isPaused, isTrue);
      expect(t.elapsedSecondsAt(at(300)), 240);
      expect(t.elapsedSecondsAt(at(900)), 240);
    });

    test('the pause in progress is added to the paused total', () {
      final t = timing(paused: 60, pauseStartedAt: at(300));
      expect(t.currentPauseSecondsAt(at(450)), 150);
      expect(t.pausedSecondsTotalAt(at(450)), 210);
    });

    test('a running session has no pause in progress', () {
      final t = timing(paused: 60);
      expect(t.isPaused, isFalse);
      expect(t.currentPauseSecondsAt(at(450)), 0);
      expect(t.pausedSecondsTotalAt(at(450)), 60);
    });
  });

  group('the planned end', () {
    test('is the start plus the planned length', () {
      expect(timing().plannedEnd, at(1500));
    });

    test('moves later by the time spent paused', () {
      expect(timing(paused: 120).plannedEnd, at(1620));
    });

    test('moves later when the session is extended', () {
      expect(timing(planned: 1500 + 300).plannedEnd, at(1800));
    });
  });

  group('a clock moved backwards', () {
    test('never gives a negative elapsed time', () {
      final t = timing();
      expect(t.elapsedSecondsAt(at(-3600)), 0);
      expect(t.remainingSecondsAt(at(-3600)), 1500);
      expect(t.overtimeSecondsAt(at(-3600)), 0);
    });

    test('never gives a negative pause length', () {
      final t = timing(pauseStartedAt: at(300));
      expect(t.currentPauseSecondsAt(at(100)), 0);
    });

    test('paused time larger than the span still floors at zero', () {
      final t = timing(paused: 5000);
      expect(t.elapsedSecondsAt(at(100)), 0);
    });
  });

  group('across a daylight-saving change', () {
    test('uses absolute instants, so a 25-hour day adds no hour', () {
      // 2026-10-25 is the European fall-back day; the arithmetic works on
      // epoch seconds, so two instants 90 s apart are 90 s apart.
      final fallBack = DateTime.utc(2026, 10, 25, 0, 59, 30);
      final t = SessionTiming(
        startedAt: fallBack,
        plannedSeconds: 600,
        pausedSeconds: 0,
        pauseStartedAt: null,
      );
      expect(t.elapsedSecondsAt(fallBack.add(const Duration(seconds: 90))), 90);
    });
  });

  group('SessionOutcome', () {
    test('database indices are stable', () {
      expect(SessionOutcome.running.dbIndex, 0);
      expect(SessionOutcome.completed.dbIndex, 1);
      expect(SessionOutcome.finishedEarly.dbIndex, 2);
      expect(SessionOutcome.abandoned.dbIndex, 3);
    });

    test('fromDbIndex round-trips and rejects unknown values', () {
      for (final outcome in SessionOutcome.values) {
        expect(SessionOutcome.fromDbIndex(outcome.dbIndex), outcome);
      }
      expect(() => SessionOutcome.fromDbIndex(9), throwsArgumentError);
    });

    test('only completed and finished-early count as done', () {
      expect(SessionOutcome.completed.countsAsDone, isTrue);
      expect(SessionOutcome.finishedEarly.countsAsDone, isTrue);
      expect(SessionOutcome.abandoned.countsAsDone, isFalse);
      expect(SessionOutcome.running.countsAsDone, isFalse);
    });
  });
}
```

**Create `test/core/time/countdown_format_test.dart`**

```dart
import 'package:energy_clock/core/time/day_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatCountdown', () {
    test('shows minutes and seconds under an hour', () {
      expect(formatCountdown(0), '00:00');
      expect(formatCountdown(5), '00:05');
      expect(formatCountdown(65), '01:05');
      expect(formatCountdown(25 * 60), '25:00');
      expect(formatCountdown(3599), '59:59');
    });

    test('adds hours from one hour up', () {
      expect(formatCountdown(3600), '1:00:00');
      expect(formatCountdown(3723), '1:02:03');
      expect(formatCountdown(10 * 3600 + 59), '10:00:59');
    });

    test('shows a negative value as zero', () {
      expect(formatCountdown(-30), '00:00');
    });
  });

  group('spokenDurationSeconds', () {
    test('says every non-zero part in words', () {
      expect(spokenDurationSeconds(3723), '1 hour 2 minutes 3 seconds');
      expect(spokenDurationSeconds(7200), '2 hours');
      expect(spokenDurationSeconds(61), '1 minute 1 second');
      expect(spokenDurationSeconds(600), '10 minutes');
      expect(spokenDurationSeconds(45), '45 seconds');
    });

    test('zero is "0 seconds", never empty', () {
      expect(spokenDurationSeconds(0), '0 seconds');
      expect(spokenDurationSeconds(-5), '0 seconds');
    });
  });
}
```

- [ ] **Step 2: Run them to see them fail**

```bash
# expect: FAIL — 'package:energy_clock/core/session/session_outcome.dart' and '…/session_timing.dart' do not exist, and `formatCountdown` is not defined
flutter test test/core/session/session_timing_test.dart test/core/time/countdown_format_test.dart
```

- [ ] **Step 3: Implement**

**Create `lib/core/event_status.dart`**

```dart
/// Where an event stands. Persisted as [dbIndex] in `events.status`; never
/// reorder or reuse these numbers.
enum EventStatus {
  planned(0),
  completed(1),
  skipped(2);

  const EventStatus(this.dbIndex);

  final int dbIndex;

  static EventStatus fromDbIndex(int index) {
    for (final status in EventStatus.values) {
      if (status.dbIndex == index) return status;
    }
    throw ArgumentError.value(index, 'index', 'Unknown event status');
  }
}
```

**Create `lib/core/session/session_outcome.dart`**

```dart
/// How a session ended. Persisted as [dbIndex] in `sessions.outcome`; never
/// reorder or reuse these numbers.
enum SessionOutcome {
  /// Still going. At most one session is in this state.
  running(0),

  /// Ran to its planned end or beyond.
  completed(1),

  /// Finished before the planned end.
  finishedEarly(2),

  /// Given up. Recorded, but not a completion.
  abandoned(3);

  const SessionOutcome(this.dbIndex);

  final int dbIndex;

  /// True for the two outcomes that count as having done the work.
  bool get countsAsDone =>
      this == SessionOutcome.completed || this == SessionOutcome.finishedEarly;

  static SessionOutcome fromDbIndex(int index) {
    for (final outcome in SessionOutcome.values) {
      if (outcome.dbIndex == index) return outcome;
    }
    throw ArgumentError.value(index, 'index', 'Unknown session outcome');
  }
}
```

**Create `lib/core/session/session_timing.dart`**

```dart
import 'dart:math' as math;

/// The wall-clock arithmetic behind a session (spec §6.2).
///
/// A session stores when it started, how long it has been paused in total, and
/// when the current pause began (null while running). Everything else is worked
/// out from the system clock each time it is asked for, so the timer cannot
/// drift and does not care that iOS suspends the app.
///
/// All values are whole seconds, and the instants are treated as whole seconds
/// too (the database stores them that way), so a tick on a wall-clock second
/// boundary shows exactly the right number.
class SessionTiming {
  const SessionTiming({
    required this.startedAt,
    required this.plannedSeconds,
    required this.pausedSeconds,
    required this.pauseStartedAt,
  });

  final DateTime startedAt;

  /// The planned length, including any extensions.
  final int plannedSeconds;

  /// Completed pauses, in total. Does not include a pause in progress.
  final int pausedSeconds;

  /// When the current pause began; null while the session is running.
  final DateTime? pauseStartedAt;

  bool get isPaused => pauseStartedAt != null;

  static int _seconds(DateTime instant) =>
      instant.millisecondsSinceEpoch ~/ 1000;

  /// Time spent actually working at [now]: the time since the start, less every
  /// pause. A pause in progress counts only up to its start, so the figure
  /// freezes while paused. Never negative, even if the device clock was moved
  /// back.
  int elapsedSecondsAt(DateTime now) {
    final reference = pauseStartedAt ?? now;
    final gross = _seconds(reference) - _seconds(startedAt);
    return math.max(0, gross - pausedSeconds);
  }

  /// Seconds until the planned end. Zero or negative once the session is in
  /// overtime.
  int remainingSecondsAt(DateTime now) =>
      plannedSeconds - elapsedSecondsAt(now);

  /// Seconds past the planned end; zero before it.
  int overtimeSecondsAt(DateTime now) =>
      math.max(0, elapsedSecondsAt(now) - plannedSeconds);

  /// True from the instant the planned time is used up.
  bool isOvertimeAt(DateTime now) => remainingSecondsAt(now) <= 0;

  /// The instant the planned time runs out, if the session keeps running
  /// without another pause. Only meaningful while running; a pause moves it
  /// later by the pause's length.
  DateTime get plannedEnd =>
      startedAt.add(Duration(seconds: plannedSeconds + pausedSeconds));

  /// How long the pause in progress has lasted at [now], in seconds; zero when
  /// running or when the clock moved back.
  int currentPauseSecondsAt(DateTime now) {
    final start = pauseStartedAt;
    if (start == null) return 0;
    return math.max(0, _seconds(now) - _seconds(start));
  }

  /// The paused total once any pause in progress is closed at [now].
  int pausedSecondsTotalAt(DateTime now) =>
      pausedSeconds + currentPauseSecondsAt(now);
}
```

**Replace `lib/features/clock/model/calendar_event.dart`**

```dart
import 'package:energy_clock/core/event_status.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';

export 'package:energy_clock/core/event_status.dart';

/// An event as the rest of the app sees it. Kept separate from the Drift row
/// so that widgets never depend on the persistence layer's generated types.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.seriesId,
    required this.date,
    required this.title,
    required this.tone,
    required this.range,
    required this.status,
  });

  final int id;
  final int? seriesId;
  final DateTime date;
  final String title;
  final Tone tone;
  final MinuteRange range;
  final EventStatus status;

  int get startMinute => range.start;
  int get endMinute => range.end;

  static CalendarEvent fromRow(EventRow row) => CalendarEvent(
    id: row.id,
    seriesId: row.seriesId,
    date: row.date,
    title: row.title,
    tone: Tone.fromDbIndex(row.toneIndex),
    range: MinuteRange(row.startMinute, row.endMinute),
    status: EventStatus.fromDbIndex(row.status),
  );

  @override
  bool operator ==(Object other) =>
      other is CalendarEvent &&
      other.id == id &&
      other.seriesId == seriesId &&
      other.date == date &&
      other.title == title &&
      other.tone == tone &&
      other.range == range &&
      other.status == status;

  @override
  int get hashCode =>
      Object.hash(id, seriesId, date, title, tone, range, status);
}
```

**Edit `lib/core/time/day_time.dart`**

Replace:

```dart
  return [
    for (var i = 0; i < 7; i++)
      DateTime(first.year, first.month, first.day + i),
  ];
}
```

With:

```dart
  return [
    for (var i = 0; i < 7; i++)
      DateTime(first.year, first.month, first.day + i),
  ];
}

/// A countdown for the session ring: "04:05", or "1:02:03" from one hour up.
/// Negative values show as zero.
String formatCountdown(int seconds) {
  final total = seconds < 0 ? 0 : seconds;
  final hours = total ~/ 3600;
  final minutes = ((total % 3600) ~/ 60).toString().padLeft(2, '0');
  final secs = (total % 60).toString().padLeft(2, '0');
  return hours == 0 ? '$minutes:$secs' : '$hours:$minutes:$secs';
}

/// Seconds spoken in words for screen readers: "1 hour 5 minutes 3 seconds".
/// Parts that are zero are left out.
String spokenDurationSeconds(int seconds) {
  final total = seconds < 0 ? 0 : seconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final secs = total % 60;
  final parts = [
    if (hours > 0) hours == 1 ? '1 hour' : '$hours hours',
    if (minutes > 0) minutes == 1 ? '1 minute' : '$minutes minutes',
    if (secs > 0 || total == 0) secs == 1 ? '1 second' : '$secs seconds',
  ];
  return parts.join(' ');
}
```

- [ ] **Step 4: Run the tests, the analyzer and the whole suite**

```bash
# expect: PASS — the new tests pass and the whole suite stays green
flutter test test/core/session/session_timing_test.dart test/core/time/countdown_format_test.dart && flutter analyze && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib/core lib/features/clock/model test/core
git commit -m "feat: session outcome, wall-clock timing model and countdown formats

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: The sessions table, schema v2 and its migration test

Spec §4.2's `sessions` table, added as schema **version 2** with the project's first migration step. Every duration is whole seconds and the instants are stored as whole seconds too (Drift's default), which is what lets the timer be pure arithmetic. A new `SessionDao` reads the running session joined to its event (a stream, so the screen updates by itself) and does the small writes the repository (Task 4) needs.

The migration test uses Drift's schema tools: `drift_schemas/` holds a JSON snapshot of each shipped version, and `drift_dev schema generate` turns those into `test/generated_migrations/`, which the test uses to build a real version-1 database, upgrade it, and check the result matches version 2 exactly. A second test puts an event into the version-1 database first and checks it survives.

**Files:**
- Create: `lib/data/tables/sessions_table.dart`, `lib/data/daos/session_dao.dart`
- Replace: `lib/data/database.dart`
- Create (generated): `lib/data/daos/session_dao.g.dart`, `drift_schemas/drift_schema_v2.json`, `test/generated_migrations/schema.dart`, `schema_v1.dart`, `schema_v2.dart`; regenerate `lib/data/database.g.dart`
- Test: `test/data/migration_test.dart`

**Interfaces:**
- Consumes: `SessionOutcome` (Task 2), `Events`, `EventRow`, `EventsCompanion`.
- Produces: `Sessions` table and `SessionRow` / `SessionsCompanion`; `db.sessionDao` (`SessionDao`) with `watchRunning(): Stream<RunningRow?>`, `running(): Future<RunningRow?>`, `sessionById(int)`, `eventById(int)`, `insertSession(SessionsCompanion)`, `updateSession(int, SessionsCompanion)`, `setEventStatus({eventId, status, updatedAt})`, `sessionsForEvent(int)`, `inTransaction(action)`; `typedef RunningRow = ({SessionRow session, EventRow event})`; `AppDatabase.schemaVersion == 2`.

- [ ] **Step 1: Write the failing test**

**Create `test/data/migration_test.dart`**

```dart
import 'package:drift_dev/api/migrations_native.dart';
import 'package:energy_clock/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../generated_migrations/schema.dart';

/// Every shipped schema version must upgrade to the current one without losing
/// data. The `drift_schemas/` dumps and `test/generated_migrations/` come from
/// `drift_dev schema dump` and `drift_dev schema generate`.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('version 1 upgrades to version 2 with the sessions table', () async {
    final schema = await verifier.schemaAt(1);
    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 2);
  });

  test('upgrading keeps the events that were already stored', () async {
    final schema = await verifier.schemaAt(1);
    // Seconds since the epoch, which is how Drift stores a DateTime.
    final seconds = DateTime(2026, 10, 7).millisecondsSinceEpoch ~/ 1000;
    schema.rawDatabase.execute(
      'INSERT INTO events (date, title, tone_index, start_minute, end_minute, '
      'status, created_at, updated_at) '
      "VALUES ($seconds, 'Deep work', 0, 540, 660, 0, $seconds, $seconds)",
    );

    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 2);

    final events = await database.eventDao.eventsForDay(DateTime(2026, 10, 7));
    expect(events.single.title, 'Deep work');
    expect(await database.sessionDao.running(), isNull);
  });

  test('a new install creates the same schema as the upgrade', () async {
    final schema = await verifier.schemaAt(2);
    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 2);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

```bash
# expect: FAIL — '../generated_migrations/schema.dart' does not exist yet
flutter test test/data/migration_test.dart
```

- [ ] **Step 3: Add the table, the DAO and the new schema version**

**Create `lib/data/tables/sessions_table.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:energy_clock/data/tables/events_table.dart';

/// One timed session on an event (spec §4.2). At most one row has
/// `outcome = 0` (running) at a time; the repository enforces that.
///
/// Every duration is whole seconds. The instants are stored as whole seconds
/// too, which is what lets the timer be pure wall-clock arithmetic.
@DataClassName('SessionRow')
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get eventId => integer().references(Events, #id)();

  /// When the session began.
  DateTimeColumn get startedAt => dateTime()();

  /// Null while the session is running.
  DateTimeColumn get endedAt => dateTime().nullable()();

  /// The planned length when the session started, plus any extensions.
  IntColumn get plannedSeconds => integer()();

  /// Completed pauses, in total.
  IntColumn get pausedSeconds => integer().withDefault(const Constant(0))();

  /// When the current pause began; null unless the session is paused.
  DateTimeColumn get pauseStartedAt => dateTime().nullable()();

  /// Time actually worked. Written when the session ends.
  IntColumn get activeSeconds => integer().withDefault(const Constant(0))();

  /// Time worked past the planned end. Written when the session ends.
  IntColumn get overtimeSeconds => integer().withDefault(const Constant(0))();

  /// 0 running, 1 completed, 2 finished early, 3 abandoned.
  IntColumn get outcome => integer().withDefault(const Constant(0))();
}
```

**Create `lib/data/daos/session_dao.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:energy_clock/core/session/session_outcome.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/tables/events_table.dart';
import 'package:energy_clock/data/tables/sessions_table.dart';

part 'session_dao.g.dart';

/// A running session together with the event it times.
typedef RunningRow = ({SessionRow session, EventRow event});

@DriftAccessor(tables: [Sessions, Events])
class SessionDao extends DatabaseAccessor<AppDatabase> with _$SessionDaoMixin {
  SessionDao(super.attachedDatabase);

  JoinedSelectStatement<HasResultSet, dynamic> _runningQuery() =>
      select(
          sessions,
        ).join([innerJoin(events, events.id.equalsExp(sessions.eventId))])
        ..where(sessions.outcome.equals(SessionOutcome.running.dbIndex))
        ..orderBy([OrderingTerm.desc(sessions.startedAt)]);

  RunningRow _toRunning(TypedResult row) =>
      (session: row.readTable(sessions), event: row.readTable(events));

  /// The running session, or null. Emits again whenever the session or its
  /// event changes. If corrupt data ever left two running rows, the newest
  /// wins.
  Stream<RunningRow?> watchRunning() => _runningQuery().watch().map(
    (rows) => rows.isEmpty ? null : _toRunning(rows.first),
  );

  Future<RunningRow?> running() async {
    final rows = await _runningQuery().get();
    return rows.isEmpty ? null : _toRunning(rows.first);
  }

  Future<SessionRow?> sessionById(int id) =>
      (select(sessions)..where((row) => row.id.equals(id))).getSingleOrNull();

  Future<EventRow?> eventById(int id) =>
      (select(events)..where((row) => row.id.equals(id))).getSingleOrNull();

  Future<int> insertSession(SessionsCompanion entry) =>
      into(sessions).insert(entry);

  Future<void> updateSession(int id, SessionsCompanion changes) =>
      (update(sessions)..where((row) => row.id.equals(id))).write(changes);

  Future<void> setEventStatus({
    required int eventId,
    required int status,
    required DateTime updatedAt,
  }) {
    return (update(events)..where((row) => row.id.equals(eventId))).write(
      EventsCompanion(status: Value(status), updatedAt: Value(updatedAt)),
    );
  }

  /// Every session of an event, newest first.
  Future<List<SessionRow>> sessionsForEvent(int eventId) =>
      (select(sessions)
            ..where((row) => row.eventId.equals(eventId))
            ..orderBy([(row) => OrderingTerm.desc(row.startedAt)]))
          .get();

  /// Runs [action] in one database transaction.
  Future<T> inTransaction<T>(Future<T> Function() action) =>
      transaction(action);
}
```

**Replace `lib/data/database.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:energy_clock/data/daos/event_dao.dart';
import 'package:energy_clock/data/daos/session_dao.dart';
import 'package:energy_clock/data/daos/settings_dao.dart';
import 'package:energy_clock/data/tables/event_series_table.dart';
import 'package:energy_clock/data/tables/events_table.dart';
import 'package:energy_clock/data/tables/sessions_table.dart';
import 'package:energy_clock/data/tables/settings_table.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Events, EventSeries, AppSettings, Sessions],
  daos: [EventDao, SettingsDao, SessionDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'energy_clock'));

  AppDatabase.forTesting(super.executor);

  /// Version 1: events, event series, settings. Version 2: sessions. Every
  /// bump needs a step in [migration] and a test in
  /// `test/data/migration_test.dart`; see `drift_schemas/`.
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(sessions);
      }
    },
  );
}
```

- [ ] **Step 4: Generate the Drift code, dump schema v2 and generate the migration helpers**

```bash
# expect: RUN — drift_schema_v1.json and v2.json, and schema.dart, schema_v1.dart, schema_v2.dart
DART="$(dirname "$(which flutter)")/dart"
"$DART" run build_runner build --delete-conflicting-outputs
"$DART" run drift_dev schema dump lib/data/database.dart drift_schemas/
"$DART" run drift_dev schema generate drift_schemas/ test/generated_migrations/
ls drift_schemas test/generated_migrations
```

- [ ] **Step 5: Run the migration test, the analyzer and the whole suite**

```bash
# expect: PASS — 3 migration tests pass; analyzer clean; the whole suite stays green
flutter test test/data/migration_test.dart && flutter analyze && flutter test
```

- [ ] **Step 6: Commit**

```bash
git add lib/data drift_schemas test/generated_migrations test/data/migration_test.dart
git commit -m "feat: sessions table, schema v2 and its migration test

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: The session repository, and deleting an event deletes its sessions

`SessionRepository` is what starts, steers and ends sessions (spec §6.2–§6.4). It lives in the shared data layer, not in the session feature, because the Clock feature starts sessions too and the boundary rule forbids one feature importing the other. Its rules, all pinned by the tests below:

- Only one session runs at a time; starting while one runs throws `SessionAlreadyRunningException`.
- The planned length is the event's length. `extend` adds seconds to it.
- `pause` records when the pause began; `resume` adds its length to the paused total. Repeating either does nothing.
- `finish` is *completed* if the planned time was reached (overtime recorded), *finished early* if not; either way the event becomes completed. `abandon` records *abandoned* and leaves the event planned. Every call on a session that has already ended does nothing.
- `closeOut` (for a session found after a killed app) is like `finish` but records at most the planned time.
- Deleting an event now also deletes its sessions, in one transaction.

**Files:**
- Create: `lib/data/models/session.dart`, `lib/data/repositories/session_repository.dart`
- Modify: `lib/data/daos/event_dao.dart` (and regenerate `event_dao.g.dart`)
- Test: `test/data/session_repository_test.dart`

**Interfaces:**
- Consumes: `SessionDao`, `SessionTiming`, `SessionOutcome`, `EventStatus`.
- Produces: `SessionRecord` (`id, eventId, startedAt, endedAt, plannedSeconds, pausedSeconds, pauseStartedAt, activeSeconds, overtimeSeconds, outcome`, `timing`); `RunningSession` (`session, eventTitle, eventTone, eventDate, eventRange`, `id`, `eventId`, `timing`); `abstract interface class SessionRepository { Stream<RunningSession?> watchRunning(); Future<RunningSession?> runningSession(); Future<int> start({required int eventId}); Future<void> pause(int); Future<void> resume(int); Future<void> extend(int, {required int seconds}); Future<SessionRecord?> finish(int); Future<void> abandon(int); Future<SessionRecord?> closeOut(int); }`; `DriftSessionRepository(SessionDao, {DateTime Function()? clock})`; `SessionAlreadyRunningException`, `SessionEventMissingException`.

- [ ] **Step 1: Write the failing test**

**Create `test/data/session_repository_test.dart`**

```dart
import 'package:drift/native.dart';
import 'package:energy_clock/core/event_status.dart';
import 'package:energy_clock/core/session/session_outcome.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/session_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SessionRepository repository;
  late DateTime now;

  final day = DateTime(2026, 10, 7);

  /// Plain `test` bodies cannot use `pumpAndSettle`, so the clock is a variable
  /// the test moves by hand.
  void advance(int seconds) => now = now.add(Duration(seconds: seconds));

  Future<int> addEvent({
    String title = 'Deep work',
    int tone = 0,
    int start = 600,
    int end = 660,
  }) {
    return db.eventDao.insertEvent(
      EventsCompanion.insert(
        date: day,
        title: title,
        toneIndex: tone,
        startMinute: start,
        endMinute: end,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<EventRow> eventRow(int id) async =>
      (await db.eventDao.eventsForDay(day)).firstWhere((row) => row.id == id);

  setUp(() {
    now = DateTime(2026, 10, 7, 10, 0, 0);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftSessionRepository(db.sessionDao, clock: () => now);
  });

  tearDown(() async {
    await db.close();
  });

  group('starting', () {
    test('plans the length of the event and reports it as running', () async {
      final eventId = await addEvent(
        title: 'Lunch walk',
        tone: 1,
        start: 750,
        end: 795,
      );

      final id = await repository.start(eventId: eventId);
      final running = await repository.runningSession();

      expect(running, isNotNull);
      expect(running!.id, id);
      expect(running.eventId, eventId);
      expect(running.eventTitle, 'Lunch walk');
      expect(running.eventTone, Tone.life);
      expect(running.session.plannedSeconds, 45 * 60);
      expect(running.session.startedAt, now);
      expect(running.session.outcome, SessionOutcome.running);
      expect(running.session.endedAt, isNull);
      expect(running.timing.isPaused, isFalse);
    });

    test('is refused while another session is running', () async {
      final first = await addEvent();
      final second = await addEvent(title: 'Email', start: 700, end: 730);
      await repository.start(eventId: first);

      expect(
        () => repository.start(eventId: second),
        throwsA(isA<SessionAlreadyRunningException>()),
      );
    });

    test('is refused for an event that does not exist', () async {
      expect(
        () => repository.start(eventId: 999),
        throwsA(isA<SessionEventMissingException>()),
      );
    });

    test('is allowed again once the last session has ended', () async {
      final first = await addEvent();
      final second = await addEvent(title: 'Email', start: 700, end: 730);
      final id = await repository.start(eventId: first);
      await repository.abandon(id);

      await repository.start(eventId: second);
      expect((await repository.runningSession())!.eventId, second);
    });

    test('nothing runs on a fresh database', () async {
      expect(await repository.runningSession(), isNull);
    });
  });

  group('pausing', () {
    test(
      'pause records when it began and resume adds it to the total',
      () async {
        final id = await repository.start(eventId: await addEvent());
        advance(300);
        await repository.pause(id);
        expect((await repository.runningSession())!.timing.isPaused, isTrue);

        advance(120);
        await repository.resume(id);

        final session = (await repository.runningSession())!.session;
        expect(session.pausedSeconds, 120);
        expect(session.pauseStartedAt, isNull);
      },
    );

    test('pauses add up across several pauses', () async {
      final id = await repository.start(eventId: await addEvent());
      await repository.pause(id);
      advance(60);
      await repository.resume(id);
      advance(100);
      await repository.pause(id);
      advance(30);
      await repository.resume(id);

      expect((await repository.runningSession())!.session.pausedSeconds, 90);
    });

    test('pausing twice keeps the first pause start', () async {
      final id = await repository.start(eventId: await addEvent());
      advance(10);
      await repository.pause(id);
      final first = (await repository.runningSession())!.session.pauseStartedAt;
      advance(50);
      await repository.pause(id);

      expect(
        (await repository.runningSession())!.session.pauseStartedAt,
        first,
      );
    });

    test('resuming a session that is not paused changes nothing', () async {
      final id = await repository.start(eventId: await addEvent());
      advance(60);
      await repository.resume(id);

      expect((await repository.runningSession())!.session.pausedSeconds, 0);
    });
  });

  group('extending', () {
    test('adds to the planned length', () async {
      final id = await repository.start(eventId: await addEvent());
      await repository.extend(id, seconds: 300);
      await repository.extend(id, seconds: 900);

      expect(
        (await repository.runningSession())!.session.plannedSeconds,
        3600 + 300 + 900,
      );
    });

    test('does nothing to a session that has ended', () async {
      final id = await repository.start(eventId: await addEvent());
      await repository.abandon(id);
      await repository.extend(id, seconds: 300);

      expect(await repository.runningSession(), isNull);
    });
  });

  group('finishing', () {
    test(
      'before the planned end is finished early, for the time worked',
      () async {
        final eventId = await addEvent();
        final id = await repository.start(eventId: eventId);
        advance(1200);

        final done = await repository.finish(id);

        expect(done!.outcome, SessionOutcome.finishedEarly);
        expect(done.activeSeconds, 1200);
        expect(done.overtimeSeconds, 0);
        expect(done.endedAt, now);
        expect(await repository.runningSession(), isNull);
        expect((await eventRow(eventId)).status, EventStatus.completed.dbIndex);
      },
    );

    test('at the planned end is completed', () async {
      final id = await repository.start(eventId: await addEvent());
      advance(3600);

      final done = await repository.finish(id);

      expect(done!.outcome, SessionOutcome.completed);
      expect(done.activeSeconds, 3600);
      expect(done.overtimeSeconds, 0);
    });

    test('past the planned end records the overtime', () async {
      final id = await repository.start(eventId: await addEvent());
      advance(3600 + 450);

      final done = await repository.finish(id);

      expect(done!.outcome, SessionOutcome.completed);
      expect(done.activeSeconds, 4050);
      expect(done.overtimeSeconds, 450);
    });

    test('an extension moves the planned end', () async {
      final id = await repository.start(eventId: await addEvent());
      await repository.extend(id, seconds: 900);
      advance(3600 + 100);

      final done = await repository.finish(id);

      expect(done!.outcome, SessionOutcome.finishedEarly);
      expect(done.activeSeconds, 3700);
    });

    test('time spent paused is not counted as work', () async {
      final id = await repository.start(eventId: await addEvent());
      advance(600);
      await repository.pause(id);
      advance(1000);
      await repository.resume(id);
      advance(600);

      final done = await repository.finish(id);

      expect(done!.activeSeconds, 1200);
      expect(done.pausedSeconds, 1000);
    });

    test('finishing while paused closes the pause', () async {
      final id = await repository.start(eventId: await addEvent());
      advance(600);
      await repository.pause(id);
      advance(500);

      final done = await repository.finish(id);

      expect(done!.activeSeconds, 600);
      expect(done.pausedSeconds, 500);
      expect(done.pauseStartedAt, isNull);
    });

    test(
      'a clock moved back records zero rather than a negative time',
      () async {
        final eventId = await addEvent();
        final id = await repository.start(eventId: eventId);
        advance(-7200);

        final done = await repository.finish(id);

        expect(done!.activeSeconds, 0);
        expect(done.outcome, SessionOutcome.finishedEarly);
      },
    );

    test('a second finish does nothing', () async {
      final id = await repository.start(eventId: await addEvent());
      advance(100);
      await repository.finish(id);
      advance(100);

      expect(await repository.finish(id), isNull);
    });
  });

  group('abandoning', () {
    test('is recorded as abandoned and leaves the event planned', () async {
      final eventId = await addEvent();
      final id = await repository.start(eventId: eventId);
      advance(400);

      await repository.abandon(id);

      final rows = await db.sessionDao.sessionsForEvent(eventId);
      expect(rows.single.outcome, SessionOutcome.abandoned.dbIndex);
      expect(rows.single.activeSeconds, 400);
      expect(rows.single.endedAt, now);
      expect(await repository.runningSession(), isNull);
      expect((await eventRow(eventId)).status, EventStatus.planned.dbIndex);
    });
  });

  group('closing out after the app was killed', () {
    test('caps the time at the planned length', () async {
      final eventId = await addEvent();
      final id = await repository.start(eventId: eventId);
      advance(3600 + 5 * 3600);

      final done = await repository.closeOut(id);

      expect(done!.outcome, SessionOutcome.completed);
      expect(done.activeSeconds, 3600);
      expect(done.overtimeSeconds, 0);
      expect((await eventRow(eventId)).status, EventStatus.completed.dbIndex);
    });

    test('before the planned end it is finished early, uncapped', () async {
      final id = await repository.start(eventId: await addEvent());
      advance(900);

      final done = await repository.closeOut(id);

      expect(done!.outcome, SessionOutcome.finishedEarly);
      expect(done.activeSeconds, 900);
    });
  });

  group('watching', () {
    test('emits the session, then null when it ends', () async {
      final id = await repository.start(eventId: await addEvent());
      final emissions = <RunningSession?>[];
      final subscription = repository.watchRunning().listen(emissions.add);
      addTearDown(subscription.cancel);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      advance(60);
      await repository.finish(id);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emissions.first?.id, id);
      expect(emissions.last, isNull);
    });
  });

  group('deleting an event', () {
    test('also deletes its sessions', () async {
      final eventId = await addEvent();
      final other = await addEvent(title: 'Email', start: 700, end: 730);
      final first = await repository.start(eventId: eventId);
      advance(60);
      await repository.finish(first);
      final second = await repository.start(eventId: other);
      advance(60);
      await repository.finish(second);

      await db.eventDao.deleteById(eventId);

      expect(await db.sessionDao.sessionsForEvent(eventId), isEmpty);
      expect(await db.sessionDao.sessionsForEvent(other), hasLength(1));
    });

    test('also removes a running session, so none points at a ghost', () async {
      final eventId = await addEvent();
      await repository.start(eventId: eventId);

      await db.eventDao.deleteById(eventId);

      expect(await repository.runningSession(), isNull);
    });
  });
}
```

- [ ] **Step 2: Run it to see it fail**

```bash
# expect: FAIL — 'package:energy_clock/data/repositories/session_repository.dart' does not exist
flutter test test/data/session_repository_test.dart
```

- [ ] **Step 3: Implement**

**Create `lib/data/models/session.dart`**

```dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/session/session_outcome.dart';
import 'package:energy_clock/core/session/session_timing.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/daos/session_dao.dart';
import 'package:energy_clock/data/database.dart';

/// A session as the rest of the app sees it, kept separate from the Drift row
/// so that widgets never depend on the persistence layer's generated types.
class SessionRecord {
  const SessionRecord({
    required this.id,
    required this.eventId,
    required this.startedAt,
    required this.endedAt,
    required this.plannedSeconds,
    required this.pausedSeconds,
    required this.pauseStartedAt,
    required this.activeSeconds,
    required this.overtimeSeconds,
    required this.outcome,
  });

  factory SessionRecord.fromRow(SessionRow row) => SessionRecord(
    id: row.id,
    eventId: row.eventId,
    startedAt: row.startedAt,
    endedAt: row.endedAt,
    plannedSeconds: row.plannedSeconds,
    pausedSeconds: row.pausedSeconds,
    pauseStartedAt: row.pauseStartedAt,
    activeSeconds: row.activeSeconds,
    overtimeSeconds: row.overtimeSeconds,
    outcome: SessionOutcome.fromDbIndex(row.outcome),
  );

  final int id;
  final int eventId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int plannedSeconds;
  final int pausedSeconds;
  final DateTime? pauseStartedAt;
  final int activeSeconds;
  final int overtimeSeconds;
  final SessionOutcome outcome;

  /// The wall-clock arithmetic for this session.
  SessionTiming get timing => SessionTiming(
    startedAt: startedAt,
    plannedSeconds: plannedSeconds,
    pausedSeconds: pausedSeconds,
    pauseStartedAt: pauseStartedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is SessionRecord &&
      other.id == id &&
      other.eventId == eventId &&
      other.startedAt == startedAt &&
      other.endedAt == endedAt &&
      other.plannedSeconds == plannedSeconds &&
      other.pausedSeconds == pausedSeconds &&
      other.pauseStartedAt == pauseStartedAt &&
      other.activeSeconds == activeSeconds &&
      other.overtimeSeconds == overtimeSeconds &&
      other.outcome == outcome;

  @override
  int get hashCode => Object.hash(
    id,
    eventId,
    startedAt,
    endedAt,
    plannedSeconds,
    pausedSeconds,
    pauseStartedAt,
    activeSeconds,
    overtimeSeconds,
    outcome,
  );
}

/// The session that is running now, with the details of its event, which is
/// all the session screen needs.
class RunningSession {
  const RunningSession({
    required this.session,
    required this.eventTitle,
    required this.eventTone,
    required this.eventDate,
    required this.eventRange,
  });

  factory RunningSession.fromRow(RunningRow row) => RunningSession(
    session: SessionRecord.fromRow(row.session),
    eventTitle: row.event.title,
    eventTone: Tone.fromDbIndex(row.event.toneIndex),
    eventDate: row.event.date,
    eventRange: MinuteRange(row.event.startMinute, row.event.endMinute),
  );

  final SessionRecord session;
  final String eventTitle;
  final Tone eventTone;

  /// Local midnight of the event's day.
  final DateTime eventDate;

  /// The slot the event holds on the dial.
  final MinuteRange eventRange;

  int get id => session.id;
  int get eventId => session.eventId;
  SessionTiming get timing => session.timing;

  @override
  bool operator ==(Object other) =>
      other is RunningSession &&
      other.session == session &&
      other.eventTitle == eventTitle &&
      other.eventTone == eventTone &&
      other.eventDate == eventDate &&
      other.eventRange == eventRange;

  @override
  int get hashCode =>
      Object.hash(session, eventTitle, eventTone, eventDate, eventRange);
}
```

**Create `lib/data/repositories/session_repository.dart`**

```dart
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:energy_clock/core/event_status.dart';
import 'package:energy_clock/core/session/session_outcome.dart';
import 'package:energy_clock/data/daos/session_dao.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/models/session.dart';

export 'package:energy_clock/data/models/session.dart';

/// Thrown by [SessionRepository.start] while another session is running. Only
/// one session runs at a time.
class SessionAlreadyRunningException implements Exception {
  const SessionAlreadyRunningException();
}

/// Thrown by [SessionRepository.start] when the event no longer exists.
class SessionEventMissingException implements Exception {
  const SessionEventMissingException();
}

/// Starts, steers and ends timed sessions (spec §6). Every method that changes
/// a session ignores a session that has already ended, so a double tap or a
/// late callback can never write twice.
abstract interface class SessionRepository {
  /// The running session, or null; emits again on every change.
  Stream<RunningSession?> watchRunning();

  Future<RunningSession?> runningSession();

  /// Starts a session on the event, planned for the event's length. Throws
  /// [SessionAlreadyRunningException] or [SessionEventMissingException].
  Future<int> start({required int eventId});

  Future<void> pause(int sessionId);

  Future<void> resume(int sessionId);

  /// Adds [seconds] to the planned length.
  Future<void> extend(int sessionId, {required int seconds});

  /// Ends the session now. Completed if it reached its planned end, finished
  /// early if not; either way the event becomes completed. Returns the
  /// finished session, or null if it was not running.
  Future<SessionRecord?> finish(int sessionId);

  /// Ends the session now as abandoned. The event stays planned.
  Future<void> abandon(int sessionId);

  /// Ends a session found after the app was killed. Like [finish], except that
  /// the recorded time is capped at the planned length: nobody can say how long
  /// the person really worked while the app was closed, and overtime nobody
  /// watched would spoil planned-versus-actual statistics.
  Future<SessionRecord?> closeOut(int sessionId);
}

class DriftSessionRepository implements SessionRepository {
  DriftSessionRepository(this._dao, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SessionDao _dao;
  final DateTime Function() _clock;

  static final int _running = SessionOutcome.running.dbIndex;

  @override
  Stream<RunningSession?> watchRunning() => _dao.watchRunning().map(
    (row) => row == null ? null : RunningSession.fromRow(row),
  );

  @override
  Future<RunningSession?> runningSession() async {
    final row = await _dao.running();
    return row == null ? null : RunningSession.fromRow(row);
  }

  @override
  Future<int> start({required int eventId}) {
    return _dao.inTransaction(() async {
      if (await _dao.running() != null) {
        throw const SessionAlreadyRunningException();
      }
      final event = await _dao.eventById(eventId);
      if (event == null) throw const SessionEventMissingException();
      return _dao.insertSession(
        SessionsCompanion.insert(
          eventId: eventId,
          startedAt: _clock(),
          plannedSeconds: (event.endMinute - event.startMinute) * 60,
        ),
      );
    });
  }

  @override
  Future<void> pause(int sessionId) {
    return _dao.inTransaction(() async {
      final row = await _dao.sessionById(sessionId);
      if (row == null || row.outcome != _running) return;
      if (row.pauseStartedAt != null) return;
      await _dao.updateSession(
        sessionId,
        SessionsCompanion(pauseStartedAt: Value(_clock())),
      );
    });
  }

  @override
  Future<void> resume(int sessionId) {
    return _dao.inTransaction(() async {
      final row = await _dao.sessionById(sessionId);
      if (row == null || row.outcome != _running) return;
      if (row.pauseStartedAt == null) return;
      final timing = SessionRecord.fromRow(row).timing;
      await _dao.updateSession(
        sessionId,
        SessionsCompanion(
          pausedSeconds: Value(timing.pausedSecondsTotalAt(_clock())),
          pauseStartedAt: const Value(null),
        ),
      );
    });
  }

  @override
  Future<void> extend(int sessionId, {required int seconds}) {
    assert(seconds > 0, 'An extension must add time');
    return _dao.inTransaction(() async {
      final row = await _dao.sessionById(sessionId);
      if (row == null || row.outcome != _running) return;
      await _dao.updateSession(
        sessionId,
        SessionsCompanion(plannedSeconds: Value(row.plannedSeconds + seconds)),
      );
    });
  }

  @override
  Future<SessionRecord?> finish(int sessionId) =>
      _end(sessionId, abandoned: false, capAtPlanned: false);

  @override
  Future<void> abandon(int sessionId) async {
    await _end(sessionId, abandoned: true, capAtPlanned: false);
  }

  @override
  Future<SessionRecord?> closeOut(int sessionId) =>
      _end(sessionId, abandoned: false, capAtPlanned: true);

  Future<SessionRecord?> _end(
    int sessionId, {
    required bool abandoned,
    required bool capAtPlanned,
  }) {
    return _dao.inTransaction(() async {
      final row = await _dao.sessionById(sessionId);
      if (row == null || row.outcome != _running) return null;

      final now = _clock();
      final timing = SessionRecord.fromRow(row).timing;
      var active = timing.elapsedSecondsAt(now);
      if (capAtPlanned) active = math.min(active, row.plannedSeconds);
      final overtime = math.max(0, active - row.plannedSeconds);
      final outcome = abandoned
          ? SessionOutcome.abandoned
          : active >= row.plannedSeconds
          ? SessionOutcome.completed
          : SessionOutcome.finishedEarly;

      await _dao.updateSession(
        sessionId,
        SessionsCompanion(
          endedAt: Value(now),
          pausedSeconds: Value(timing.pausedSecondsTotalAt(now)),
          pauseStartedAt: const Value(null),
          activeSeconds: Value(active),
          overtimeSeconds: Value(overtime),
          outcome: Value(outcome.dbIndex),
        ),
      );
      if (outcome.countsAsDone) {
        await _dao.setEventStatus(
          eventId: row.eventId,
          status: EventStatus.completed.dbIndex,
          updatedAt: now,
        );
      }
      return SessionRecord.fromRow((await _dao.sessionById(sessionId))!);
    });
  }
}
```

**Edit `lib/data/daos/event_dao.dart`**

Replace:

```dart
import 'package:energy_clock/data/tables/events_table.dart';
```

With:

```dart
import 'package:energy_clock/data/tables/events_table.dart';
import 'package:energy_clock/data/tables/sessions_table.dart';
```

**Edit `lib/data/daos/event_dao.dart`**

Replace:

```dart
@DriftAccessor(tables: [Events])
```

With:

```dart
@DriftAccessor(tables: [Events, Sessions])
```

**Edit `lib/data/daos/event_dao.dart`**

Replace:

```dart
  Future<void> deleteById(int id) =>
      (delete(events)..where((row) => row.id.equals(id))).go();
```

With:

```dart
  /// Deletes the event and every session timed on it, so no session is left
  /// pointing at an event that is gone.
  Future<void> deleteById(int id) {
    return transaction(() async {
      await (delete(sessions)..where((row) => row.eventId.equals(id))).go();
      await (delete(events)..where((row) => row.id.equals(id))).go();
    });
  }
```

- [ ] **Step 4: Regenerate the Drift code, then run the test, the analyzer and the whole suite**

```bash
# expect: RUN
"$(dirname "$(which flutter)")/dart" run build_runner build --delete-conflicting-outputs
```

```bash
# expect: PASS — the new repository tests pass; the existing event DAO and repository tests stay green
flutter test test/data/session_repository_test.dart && flutter analyze && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib/data test/data/session_repository_test.dart
git commit -m "feat: session repository; deleting an event deletes its sessions

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: The local notification service

Everything the app needs from notifications, behind an interface (`NotificationService`) so that features and tests never touch the plugin. `LocalNotificationService` implements it over `flutter_local_notifications` for iOS:

- The plugin starts on first use with **its own permission requests switched off**: the app asks when the first session starts, not at launch.
- `schedule` sends an **absolute instant in UTC** (`tz.UTC`; no time-zone database is loaded). iOS fires it at that moment whatever the time zone or daylight-saving rules are when it comes due. The timezone package names its built-in zone `Etc/UTC`, a name iOS's `NSTimeZone` knows (checked with `swift -e` on this Mac, and again on the simulator in Task 15).
- `openSettings` opens the app's notification settings through the plugin, so no Swift code is needed.

The test runs the plugin's real Dart code against a pretend iOS side (a mocked method channel) and checks what the app asks iOS to do. What iOS then does is checked by hand in Task 15.

**Files:**
- Create: `lib/data/notifications/notification_service.dart`, `lib/data/notifications/local_notification_service.dart`
- Replace: `lib/data/providers.dart`
- Test: `test/data/local_notification_service_test.dart`

**Interfaces:**
- Consumes: `DriftSessionRepository` (Task 4), `flutter_local_notifications`, `timezone`.
- Produces: `abstract interface class NotificationService { Future<bool> areEnabled(); Future<bool> requestPermission(); Future<void> schedule({required int id, required DateTime at, required String title, required String body}); Future<void> cancel(int id); Future<void> openSettings(); }`; `LocalNotificationService([FlutterLocalNotificationsPlugin? plugin])`; `sessionRepositoryProvider: Provider<SessionRepository>`; `notificationServiceProvider: Provider<NotificationService>`.

- [ ] **Step 1: Write the failing test**

**Create `test/data/local_notification_service_test.dart`**

```dart
import 'package:energy_clock/data/notifications/local_notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs the real plugin's Dart code against a pretend iOS side, to check what
/// the app asks iOS to do. What iOS then does (showing the permission prompt,
/// firing the notification) is checked by hand on the simulator.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  late List<MethodCall> calls;
  late Map<String, Object?> replies;
  late LocalNotificationService service;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    calls = [];
    replies = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return replies[call.method];
        });
    service = LocalNotificationService();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  List<String> methods() => [for (final call in calls) call.method];

  test('starts the plugin once, without asking for permission', () async {
    await service.areEnabled();
    await service.cancel(7);

    expect(methods().where((m) => m == 'initialize'), hasLength(1));
    final init = calls.firstWhere((c) => c.method == 'initialize');
    final arguments = init.arguments as Map<Object?, Object?>;
    expect(arguments['requestAlertPermission'], isFalse);
    expect(arguments['requestSoundPermission'], isFalse);
    expect(arguments['requestBadgePermission'], isFalse);
  });

  test('areEnabled reflects what iOS reports', () async {
    replies['checkPermissions'] = {'isEnabled': true};
    expect(await service.areEnabled(), isTrue);

    replies['checkPermissions'] = {'isEnabled': false};
    expect(await service.areEnabled(), isFalse);
  });

  test('requestPermission asks for alerts and sound only', () async {
    replies['requestPermissions'] = true;

    expect(await service.requestPermission(), isTrue);

    final call = calls.firstWhere((c) => c.method == 'requestPermissions');
    final arguments = call.arguments as Map<Object?, Object?>;
    expect(arguments['alert'], isTrue);
    expect(arguments['sound'], isTrue);
    expect(arguments['badge'], isFalse);
  });

  test('a refused request is false', () async {
    replies['requestPermissions'] = false;
    expect(await service.requestPermission(), isFalse);
  });

  test('schedule sends the instant in UTC', () async {
    final at = DateTime.utc(2099, 3, 28, 1, 30, 15);

    await service.schedule(id: 1001, at: at, title: 'Time is up', body: 'Body');

    final call = calls.firstWhere((c) => c.method == 'zonedSchedule');
    final arguments = call.arguments as Map<Object?, Object?>;
    expect(arguments['id'], 1001);
    expect(arguments['title'], 'Time is up');
    expect(arguments['body'], 'Body');
    // The timezone package names its built-in UTC zone `Etc/UTC`, a name
    // Foundation's NSTimeZone knows.
    expect(arguments['timeZoneName'], 'Etc/UTC');
    expect(arguments['scheduledDateTime'], '2099-03-28T01:30:15');
  });

  test('a local instant is converted to the same moment in UTC', () async {
    final local = DateTime(2099, 7, 1, 12, 0, 0);

    await service.schedule(id: 1, at: local, title: 't', body: 'b');

    final call = calls.firstWhere((c) => c.method == 'zonedSchedule');
    final arguments = call.arguments as Map<Object?, Object?>;
    final utc = local.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    expect(
      arguments['scheduledDateTime'],
      '${utc.year}-${two(utc.month)}-${two(utc.day)}'
      'T${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}',
    );
  });

  test('cancel removes the notification by id', () async {
    await service.cancel(1001);

    final call = calls.firstWhere((c) => c.method == 'cancel');
    expect(call.arguments, 1001);
  });

  test('openSettings asks iOS to open the notification settings', () async {
    await service.openSettings();

    expect(methods(), contains('openAppNotificationSettings'));
  });
}
```

- [ ] **Step 2: Run it to see it fail**

```bash
# expect: FAIL — 'package:energy_clock/data/notifications/local_notification_service.dart' does not exist
flutter test test/data/local_notification_service_test.dart
```

- [ ] **Step 3: Implement**

**Create `lib/data/notifications/notification_service.dart`**

```dart
/// What the app needs from local notifications. The plugin behind it is an
/// implementation detail, so features and tests depend only on this.
abstract interface class NotificationService {
  /// Whether the system will show this app's notifications right now.
  Future<bool> areEnabled();

  /// Shows the system permission prompt and returns whether it was granted.
  /// iOS shows the prompt once; after a refusal this returns false at once.
  Future<bool> requestPermission();

  /// Schedules a notification for the absolute instant [at], replacing any
  /// pending one with the same [id].
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  });

  /// Removes the pending notification [id], if any.
  Future<void> cancel(int id);

  /// Opens the app's notification settings in the Settings app.
  Future<void> openSettings();
}
```

**Create `lib/data/notifications/local_notification_service.dart`**

```dart
import 'package:energy_clock/data/notifications/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// [NotificationService] over `flutter_local_notifications`, for iOS.
///
/// The plugin starts on first use, with its own permission requests switched
/// off: the app asks when a person first starts a session, not at launch.
class LocalNotificationService implements NotificationService {
  LocalNotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<bool?>? _started;

  static const NotificationDetails _details = NotificationDetails(
    iOS: DarwinNotificationDetails(presentSound: true),
  );

  Future<void> _start() {
    return _started ??= _plugin.initialize(
      settings: const InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );
  }

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> areEnabled() async {
    await _start();
    final options = await _ios?.checkPermissions();
    return options?.isEnabled ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    await _start();
    return await _ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  /// [at] is an absolute instant, so it is sent in UTC: the system fires it at
  /// that moment whatever the time zone or daylight-saving rules are when it
  /// comes due.
  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    await _start();
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(at, tz.UTC),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _start();
    await _plugin.cancel(id: id);
  }

  @override
  Future<void> openSettings() async {
    await _start();
    await _ios?.openAppNotificationSettings();
  }
}
```

**Replace `lib/data/providers.dart`**

```dart
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/notifications/local_notification_service.dart';
import 'package:energy_clock/data/notifications/notification_service.dart';
import 'package:energy_clock/data/repositories/session_repository.dart';
import 'package:energy_clock/data/repositories/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app's single database. It lives in the data layer so that any feature,
/// and the app layer, can read it without importing another feature.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return DriftSettingsRepository(ref.watch(appDatabaseProvider).settingsDao);
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return DriftSessionRepository(ref.watch(appDatabaseProvider).sessionDao);
});

/// Local notifications. Tests replace it with a fake, so nothing in a test run
/// reaches the plugin.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return LocalNotificationService();
});
```

- [ ] **Step 4: Run the test, the analyzer and the whole suite**

```bash
# expect: PASS — 8 new tests pass; the whole suite stays green
flutter test test/data/local_notification_service_test.dart && flutter analyze && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib/data test/data/local_notification_service_test.dart
git commit -m "feat: local notification service

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Session copy, the session time style, and spoken button labels

Everything the later UI tasks and the alert logic need to say or draw, in one place: all the session copy in `lib/core/strings.dart` (so localisation stays possible later), a tabular-figure text style for the big countdown (Nunito's digits are all the same width, so the number cannot jitter as it changes), and an optional `semanticsLabel` on `AppButton`, so a button that reads "+5m" can be spoken as "Add 5 minutes". The strings are used by Tasks 10–14 and are checked there; this task's own test covers the button.

**Files:**
- Modify: `lib/core/strings.dart`, `lib/app/theme/app_typography.dart`, `lib/shared/widgets/app_button.dart`
- Test: `test/shared/widgets/app_button_semantics_test.dart`

**Interfaces:**
- Produces: `Strings.session*`, `Strings.alertsOff*`, `Strings.recovery*`, `Strings.sessionEndedTitle`, `Strings.sessionEndedBody(title)`, `Strings.openSettings`, `Strings.dismiss`, `Strings.eventCompleted`, `Strings.nowCompletedSuffix`; `AppTypography.sessionTime(double size)`; `AppButton({…, String? semanticsLabel})`.

- [ ] **Step 1: Write the failing test**

**Create `test/shared/widgets/app_button_semantics_test.dart`**

```dart
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> show(WidgetTester tester, {String? semanticsLabel}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppButton(
            label: '+5m',
            semanticsLabel: semanticsLabel,
            onPressed: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('a screen reader says the label by default', (tester) async {
    final handle = tester.ensureSemantics();
    await show(tester);

    expect(find.bySemanticsLabel('+5m'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a semantics label replaces it for screen readers only', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await show(tester, semanticsLabel: 'Add 5 minutes');

    expect(find.bySemanticsLabel('Add 5 minutes'), findsOneWidget);
    expect(find.bySemanticsLabel('+5m'), findsNothing);
    expect(find.text('+5m'), findsOneWidget);
    handle.dispose();
  });
}
```

- [ ] **Step 2: Run it to see it fail**

```bash
# expect: FAIL — 'semanticsLabel' is not a named parameter of AppButton
flutter test test/shared/widgets/app_button_semantics_test.dart
```

- [ ] **Step 3: Implement**

**Edit `lib/core/strings.dart`**

Replace:

```dart
  static const String sampleDayFailed = "Couldn't add the sample day.";
}
```

With:

```dart
  static const String sampleDayFailed = "Couldn't add the sample day.";

  // Starting a session.
  static const String sessionStart = 'Start session';
  static const String sessionStartShort = 'Start';
  static const String sessionDone = 'Done';
  static const String nowCompletedSuffix = ', completed';
  static const String eventCompleted = 'Completed';
  static const String sessionAlreadyRunning = 'A session is already running.';
  static const String sessionStartFailed = "Couldn't start the session.";

  // The session screen.
  static const String sessionPause = 'Pause';
  static const String sessionResume = 'Resume';
  static const String sessionAdd5 = '+5m';
  static const String sessionAdd15 = '+15m';
  static const String sessionAdd5Semantics = 'Add 5 minutes';
  static const String sessionAdd15Semantics = 'Add 15 minutes';
  static const String sessionFinishEarly = 'Finish early';
  static const String sessionFinish = 'Finish';
  static const String sessionAbandon = 'Abandon';
  static const String sessionAbandonTitle = 'Abandon this session?';
  static const String sessionAbandonBody =
      "It will be recorded as abandoned and won't count as completed.";
  static const String sessionKeepGoing = 'Keep going';
  static const String sessionRemaining = 'remaining';
  static const String sessionPaused = 'Paused';
  static const String sessionOvertime = 'Overtime';
  static String sessionPlanned(String duration) => 'Planned $duration';
  static String sessionEndsAt(String time) => 'ends $time';
  static String sessionWasDueAt(String time) => 'was due $time';
  static String sessionLogged(String title, String duration) =>
      'Logged $duration on $title.';
  static const String sessionAbandoned = 'Session abandoned.';
  static String sessionRingSemantics(
    String title,
    String tone,
    String time,
    String state,
  ) => '$title, $tone, $time$state';
  static const String sessionStatePaused = ', paused';
  static const String sessionStateOvertime = ', overtime';

  // Session alerts.
  static const String sessionEndedTitle = "Time's up";
  static String sessionEndedBody(String title) =>
      '$title is done. Open Energy Clock to finish, or keep going.';
  static const String alertsOffTitle = 'Alerts are off';
  static const String alertsOffBody =
      "You won't get an alert when time is up while the app is closed. The "
      'timer still works.';
  static const String openSettings = 'Open Settings';
  static const String dismiss = 'Dismiss';

  // Finding a session after the app was closed.
  static const String recoveryTitle = 'A session was still running';
  static String recoveryBody(String title, String elapsed) =>
      '$title has been going for $elapsed. Pick it up where you left off, or '
      'close it out.';
  static const String recoveryCloseOutHint =
      'Closing out records at most the planned time.';
  static const String recoveryUnderAMinute = 'under a minute';
  static const String recoveryResume = 'Resume';
  static const String recoveryCloseOut = 'Close out';
}
```

**Edit `lib/app/theme/app_typography.dart`**

Replace:

```dart
  /// Hour numerals around the dial.
```

With:

```dart
  /// The big countdown inside the session ring. [size] comes from the ring's
  /// diameter. Tabular figures, so the digits never jitter as they change.
  static TextStyle sessionTime(double size) =>
      _style(size, FontWeight.w800, height: 1.05, features: _tabular);

  /// Hour numerals around the dial.
```

**Edit `lib/shared/widgets/app_button.dart`**

Replace:

```dart
    this.variant = AppButtonVariant.primary,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
```

With:

```dart
    this.variant = AppButtonVariant.primary,
    this.semanticsLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;

  /// What a screen reader says when it differs from [label], for example "Add
  /// 5 minutes" for a button that reads "+5m".
  final String? semanticsLabel;
```

**Edit `lib/shared/widgets/app_button.dart`**

Replace:

```dart
        label: label,
        excludeSemantics: true,
```

With:

```dart
        label: semanticsLabel ?? label,
        excludeSemantics: true,
```

- [ ] **Step 4: Run the test, the analyzer and the whole suite**

```bash
# expect: PASS — 2 new tests pass; the whole suite stays green
flutter test test/shared/widgets/app_button_semantics_test.dart && flutter analyze && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib/core/strings.dart lib/app/theme/app_typography.dart lib/shared/widgets/app_button.dart test/shared/widgets/app_button_semantics_test.dart
git commit -m "feat: session copy, session time style and spoken button labels

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Stage 2 — Session logic

### Task 7: The session clock, the running-session stream and recovery state

Four small providers in the new session feature:

- `sessionNowSourceProvider`: where the feature reads the time. Tests replace it with a source they move by hand.
- `runningSessionProvider`: the running session as a stream, from `SessionRepository.watchRunning()`.
- `sessionNowProvider`: the current time, refreshed **on every whole second** while something watches it, and straight away when the app returns to the foreground (spec §6.2: "recomputed … on every return to the foreground"). It is `autoDispose`, so nothing ticks when no session screen is on screen. It reads the time from the source each tick rather than counting, so a late tick still shows the right number.
- `sessionRecoveryProvider`: read **once at launch**; the id of a session that was already running then, which means the app was killed during it (spec §6.5). A session started later is never a recovery.

**Files:**
- Create: `lib/features/session/providers.dart`
- Test: `test/features/session/session_now_test.dart`

**Interfaces:**
- Consumes: `sessionRepositoryProvider`, `RunningSession`.
- Produces: `sessionNowSourceProvider: Provider<DateTime Function()>`; `runningSessionProvider: StreamProvider<RunningSession?>`; `untilNextSecond(DateTime now): Duration`; `SessionNowNotifier` (an `AutoDisposeNotifier<DateTime>`, overridable in tests) and `sessionNowProvider`; `SessionRecoveryNotifier` (`AsyncNotifier<int?>` with `resolve()`) and `sessionRecoveryProvider`.

- [ ] **Step 1: Write the failing test**

**Create `test/features/session/session_now_test.dart`**

```dart
import 'package:energy_clock/features/session/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('untilNextSecond', () {
    test('waits for the next whole second', () {
      expect(
        untilNextSecond(DateTime(2026, 10, 7, 10, 0, 0, 400)),
        const Duration(milliseconds: 600),
      );
    });

    test('waits a full second when exactly on a boundary', () {
      expect(
        untilNextSecond(DateTime(2026, 10, 7, 10, 0, 5)),
        const Duration(seconds: 1),
      );
    });

    test('keeps microsecond precision', () {
      expect(
        untilNextSecond(DateTime(2026, 10, 7, 10, 0, 5, 999, 500)),
        const Duration(microseconds: 500),
      );
    });
  });

  group('SessionNowNotifier', () {
    late DateTime now;

    setUp(() {
      now = DateTime(2026, 10, 7, 10, 0, 0, 250);
    });

    Future<void> show(WidgetTester tester) {
      return tester.pumpWidget(
        ProviderScope(
          overrides: [sessionNowSourceProvider.overrideWithValue(() => now)],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) => Text(
                ref.watch(sessionNowProvider).toIso8601String(),
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('starts at the current time', (tester) async {
      await show(tester);
      expect(find.text(now.toIso8601String()), findsOneWidget);
    });

    testWidgets('ticks when the next whole second arrives, not before', (
      tester,
    ) async {
      await show(tester);
      final first = now.toIso8601String();

      now = DateTime(2026, 10, 7, 10, 0, 1, 0);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text(first), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text(now.toIso8601String()), findsOneWidget);
    });

    testWidgets('keeps ticking every second after that', (tester) async {
      await show(tester);
      await tester.pump(const Duration(milliseconds: 750));

      now = DateTime(2026, 10, 7, 10, 0, 1);
      await tester.pump(const Duration(seconds: 1));
      now = DateTime(2026, 10, 7, 10, 0, 2);
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(now.toIso8601String()), findsOneWidget);
    });

    testWidgets('refreshes at once when the app returns to the foreground', (
      tester,
    ) async {
      await show(tester);
      now = DateTime(2026, 10, 7, 11, 30, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(find.text(now.toIso8601String()), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text(now.toIso8601String()), findsOneWidget);
    });

    testWidgets('stops its timer when nothing watches it any more', (
      tester,
    ) async {
      await show(tester);
      await tester.pumpWidget(const SizedBox());
      // A timer left running would fail the test as still pending.
    });
  });
}
```

- [ ] **Step 2: Run it to see it fail**

```bash
# expect: FAIL — 'package:energy_clock/features/session/providers.dart' does not exist
flutter test test/features/session/session_now_test.dart
```

- [ ] **Step 3: Implement**

**Create `lib/features/session/providers.dart`**

```dart
import 'dart:async';

import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/session_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the session feature reads the time. Tests replace it with a source
/// they move by hand.
final sessionNowSourceProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// The running session, or null. Emits again whenever it changes.
final runningSessionProvider = StreamProvider<RunningSession?>((ref) {
  return ref.watch(sessionRepositoryProvider).watchRunning();
});

/// How long until the next whole second.
Duration untilNextSecond(DateTime now) => Duration(
  microseconds:
      Duration.microsecondsPerSecond -
      now.microsecondsSinceEpoch % Duration.microsecondsPerSecond,
);

/// The current time, refreshed on every whole second while something watches
/// it, and straight away when the app returns to the foreground. The session
/// screen is the only watcher, so nothing ticks when no session is on screen.
///
/// Remaining time is always worked out from this clock (spec §6.2), never
/// counted down, so a tick that arrives late shows the right number.
class SessionNowNotifier extends AutoDisposeNotifier<DateTime>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  DateTime build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _timer?.cancel();
    });
    final now = ref.read(sessionNowSourceProvider)();
    _schedule(now);
    return now;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _tick();
  }

  void _schedule(DateTime now) {
    _timer?.cancel();
    _timer = Timer(untilNextSecond(now), _tick);
  }

  void _tick() {
    final now = ref.read(sessionNowSourceProvider)();
    state = now;
    _schedule(now);
  }
}

final sessionNowProvider =
    NotifierProvider.autoDispose<SessionNowNotifier, DateTime>(
      SessionNowNotifier.new,
    );

/// The id of a session that was already running when the app started, which
/// means the app was killed during it, or null. The session screen offers to
/// resume it or close it out (spec §6.5) until [resolve] is called. It is read
/// once at launch, so a session started later never counts as a recovery.
class SessionRecoveryNotifier extends AsyncNotifier<int?> {
  @override
  Future<int?> build() async {
    final session = await ref.read(sessionRepositoryProvider).runningSession();
    return session?.id;
  }

  void resolve() => state = const AsyncData(null);
}

final sessionRecoveryProvider =
    AsyncNotifierProvider<SessionRecoveryNotifier, int?>(
      SessionRecoveryNotifier.new,
    );
```

- [ ] **Step 4: Run the test and the analyzer**

```bash
# expect: PASS — 8 new tests pass
flutter test test/features/session/session_now_test.dart && flutter analyze
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/session test/features/session/session_now_test.dart
git commit -m "feat: session clock, running-session stream and recovery state

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Test support for sessions and notifications

Widget tests cannot use a real Drift database (it completes its I/O on real timers that `testWidgets`' fake clock never advances), so the session feature gets in-memory fakes, wired into the existing `ClockHarness`:

- `FakeSessionRepository` follows the same rules as the Drift one (using the same `SessionTiming`) over the harness's fake events, reads the time from the harness clock, and records its calls (`calls`) and ended sessions (`ended`). `seedRunning` puts a session in the running state as if a previous launch had left it.
- `FakeNotificationService` records what it was asked to schedule and cancel, and can be told permission is off or refused.
- `FakeClock` now also tells followers when it moves. `FakeSessionNow` follows it, so in a test **one `clock.set(...)` moves every clock in the app** (the minute clock, the session repository and the session screen) with no timer. The real `SessionNowNotifier` has its own tests (Task 7); using it in screen tests would leave a timer pending, because the harness's provider container outlives the widget tree.
- `ClockHarness` overrides the session repository, the notification service, settings and both session clocks by default.

This task adds support code only; the existing suite is its test, and Tasks 9–14 are its users.

**Files:**
- Create: `test/support/fake_session_repository.dart`, `test/support/fake_notification_service.dart`
- Replace: `test/support/fake_clock.dart`, `test/support/clock_harness.dart`
- Modify: `test/support/fake_event_repository.dart`

**Interfaces:**
- Consumes: `SessionRepository`, `NotificationService`, `SessionNowNotifier`, `sessionNowSourceProvider`, `sessionNowProvider`.
- Produces: `FakeClock` (`current`, `set`, `follow`, `unfollow`); `FakeSessionNow(FakeClock)`; `FakeEventRepository.eventById(int)` and `.setStatus(int, EventStatus)`; `FakeSessionRepository({required FakeEventRepository events, required DateTime Function() clock})` with `calls`, `ended`, `running`, `seedRunning({eventId, startedAt, plannedSeconds, pausedSeconds, pauseStartedAt})`, `dispose()`; `FakeNotificationService({enabled, grantsRequest})` with `enabled`, `grantsRequest`, `failSchedule`, `requests`, `settingsOpened`, `pending`, `log`; `ClockHarness` gains `sessions`, `notifications`, `settings`.

- [ ] **Step 1: Add the support code**

**Create `test/support/fake_notification_service.dart`**

```dart
import 'package:energy_clock/data/notifications/notification_service.dart';

/// A [NotificationService] that remembers what it was asked to do.
class FakeNotificationService implements NotificationService {
  FakeNotificationService({this.enabled = true, this.grantsRequest = true});

  /// Whether the system currently allows notifications.
  bool enabled;

  /// What the permission prompt answers.
  bool grantsRequest;

  /// Makes [schedule] throw, as a failing plugin would.
  bool failSchedule = false;

  /// How many times the permission prompt was shown.
  int requests = 0;

  /// How many times the settings page was opened.
  int settingsOpened = 0;

  /// The pending notifications, by id.
  final Map<int, ({DateTime at, String title, String body})> pending = {};

  /// Every call, in order: `schedule 1001`, `cancel 1001`, `request`.
  final List<String> log = [];

  @override
  Future<bool> areEnabled() async => enabled;

  @override
  Future<bool> requestPermission() async {
    requests++;
    log.add('request');
    if (grantsRequest) enabled = true;
    return grantsRequest;
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    log.add('schedule $id');
    if (failSchedule) throw StateError('the plugin failed');
    pending[id] = (at: at, title: title, body: body);
  }

  @override
  Future<void> cancel(int id) async {
    log.add('cancel $id');
    pending.remove(id);
  }

  @override
  Future<void> openSettings() async {
    settingsOpened++;
  }
}
```

**Create `test/support/fake_session_repository.dart`**

```dart
import 'dart:async';
import 'dart:math' as math;

import 'package:energy_clock/core/event_status.dart';
import 'package:energy_clock/core/session/session_outcome.dart';
import 'package:energy_clock/data/repositories/session_repository.dart';

import 'fake_event_repository.dart';

/// In-memory [SessionRepository] for widget tests, for the same reason
/// [FakeEventRepository] exists: a real Drift database cannot deliver its
/// streams inside `testWidgets`. The behaviour against Drift is covered by
/// `test/data/session_repository_test.dart`.
///
/// It works on the events held by [events] and reads the time from [clock], so
/// a test that moves the clock moves the session with it.
class FakeSessionRepository implements SessionRepository {
  FakeSessionRepository({required this.events, required this._clock});

  final FakeEventRepository events;
  final DateTime Function() _clock;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Every repository call, by name, in order: `start`, `pause`, ...
  final List<String> calls = <String>[];

  /// The sessions that have ended, oldest first.
  final List<SessionRecord> ended = <SessionRecord>[];

  SessionRecord? _record;
  int _nextId = 1;

  void dispose() {
    unawaited(_changes.close());
  }

  /// The session that is running now, or null.
  RunningSession? get running {
    final record = _record;
    if (record == null) return null;
    final event = events.eventById(record.eventId)!;
    return RunningSession(
      session: record,
      eventTitle: event.title,
      eventTone: event.tone,
      eventDate: event.date,
      eventRange: event.range,
    );
  }

  /// Puts a session into the running state without going through [start], as
  /// if a previous launch of the app had left it there.
  void seedRunning({
    required int eventId,
    required DateTime startedAt,
    int plannedSeconds = 3600,
    int pausedSeconds = 0,
    DateTime? pauseStartedAt,
  }) {
    _record = SessionRecord(
      id: _nextId++,
      eventId: eventId,
      startedAt: startedAt,
      endedAt: null,
      plannedSeconds: plannedSeconds,
      pausedSeconds: pausedSeconds,
      pauseStartedAt: pauseStartedAt,
      activeSeconds: 0,
      overtimeSeconds: 0,
      outcome: SessionOutcome.running,
    );
    _notify();
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Stream<RunningSession?> watchRunning() async* {
    yield running;
    yield* _changes.stream.map((_) => running);
  }

  @override
  Future<RunningSession?> runningSession() async => running;

  @override
  Future<int> start({required int eventId}) async {
    calls.add('start');
    if (_record != null) throw const SessionAlreadyRunningException();
    final event = events.eventById(eventId);
    if (event == null) throw const SessionEventMissingException();
    final id = _nextId++;
    _record = SessionRecord(
      id: id,
      eventId: eventId,
      startedAt: _clock(),
      endedAt: null,
      plannedSeconds: event.range.durationMinutes * 60,
      pausedSeconds: 0,
      pauseStartedAt: null,
      activeSeconds: 0,
      overtimeSeconds: 0,
      outcome: SessionOutcome.running,
    );
    _notify();
    return id;
  }

  SessionRecord? _live(int sessionId) {
    final record = _record;
    return record != null && record.id == sessionId ? record : null;
  }

  void _replace(
    SessionRecord record, {
    int? plannedSeconds,
    int? pausedSeconds,
    DateTime? pauseStartedAt,
    bool clearPause = false,
  }) {
    _record = SessionRecord(
      id: record.id,
      eventId: record.eventId,
      startedAt: record.startedAt,
      endedAt: record.endedAt,
      plannedSeconds: plannedSeconds ?? record.plannedSeconds,
      pausedSeconds: pausedSeconds ?? record.pausedSeconds,
      pauseStartedAt: clearPause
          ? null
          : pauseStartedAt ?? record.pauseStartedAt,
      activeSeconds: record.activeSeconds,
      overtimeSeconds: record.overtimeSeconds,
      outcome: record.outcome,
    );
    _notify();
  }

  @override
  Future<void> pause(int sessionId) async {
    calls.add('pause');
    final record = _live(sessionId);
    if (record == null || record.pauseStartedAt != null) return;
    _replace(record, pauseStartedAt: _clock());
  }

  @override
  Future<void> resume(int sessionId) async {
    calls.add('resume');
    final record = _live(sessionId);
    if (record == null || record.pauseStartedAt == null) return;
    _replace(
      record,
      pausedSeconds: record.timing.pausedSecondsTotalAt(_clock()),
      clearPause: true,
    );
  }

  @override
  Future<void> extend(int sessionId, {required int seconds}) async {
    calls.add('extend $seconds');
    final record = _live(sessionId);
    if (record == null) return;
    _replace(record, plannedSeconds: record.plannedSeconds + seconds);
  }

  @override
  Future<SessionRecord?> finish(int sessionId) {
    calls.add('finish');
    return _end(sessionId, abandoned: false, capAtPlanned: false);
  }

  @override
  Future<void> abandon(int sessionId) async {
    calls.add('abandon');
    await _end(sessionId, abandoned: true, capAtPlanned: false);
  }

  @override
  Future<SessionRecord?> closeOut(int sessionId) {
    calls.add('closeOut');
    return _end(sessionId, abandoned: false, capAtPlanned: true);
  }

  Future<SessionRecord?> _end(
    int sessionId, {
    required bool abandoned,
    required bool capAtPlanned,
  }) async {
    final record = _live(sessionId);
    if (record == null) return null;
    final now = _clock();
    final timing = record.timing;
    var active = timing.elapsedSecondsAt(now);
    if (capAtPlanned) active = math.min(active, record.plannedSeconds);
    final outcome = abandoned
        ? SessionOutcome.abandoned
        : active >= record.plannedSeconds
        ? SessionOutcome.completed
        : SessionOutcome.finishedEarly;
    final done = SessionRecord(
      id: record.id,
      eventId: record.eventId,
      startedAt: record.startedAt,
      endedAt: now,
      plannedSeconds: record.plannedSeconds,
      pausedSeconds: timing.pausedSecondsTotalAt(now),
      pauseStartedAt: null,
      activeSeconds: active,
      overtimeSeconds: math.max(0, active - record.plannedSeconds),
      outcome: outcome,
    );
    ended.add(done);
    _record = null;
    if (outcome.countsAsDone) {
      events.setStatus(record.eventId, EventStatus.completed);
    }
    _notify();
    return done;
  }
}
```

**Replace `test/support/fake_clock.dart`**

```dart
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/session/providers.dart';

/// A [ClockNotifier] that never ticks by itself. Tests set the time directly:
///
///     clockProvider.overrideWith(() => FakeClock(DateTime(2026, 10, 3, 10, 30)))
///
/// [ClockHarness] also hands [current] to the session repository and the
/// session screen's clock, so one `set` moves every clock in the app.
class FakeClock extends ClockNotifier {
  FakeClock(DateTime initial) : _current = initial;

  DateTime _current;
  bool _built = false;
  final List<void Function(DateTime)> _followers = [];

  /// The time the fake clock currently reads.
  DateTime get current => _current;

  @override
  DateTime build() {
    _built = true;
    return _current;
  }

  /// Moves the fake clock, as a minute tick would.
  void set(DateTime time) {
    _current = time;
    if (_built) state = time;
    for (final follower in List.of(_followers)) {
      follower(time);
    }
  }

  void follow(void Function(DateTime) onChange) => _followers.add(onChange);

  void unfollow(void Function(DateTime) onChange) =>
      _followers.remove(onChange);
}

/// The session screen's clock, driven by a [FakeClock] instead of a timer: it
/// changes the moment the fake clock does. A real timer would still be pending
/// when `testWidgets` checks for stray timers, because the harness's provider
/// container outlives the widget tree. The real notifier has its own tests.
class FakeSessionNow extends SessionNowNotifier {
  FakeSessionNow(this._clock);

  final FakeClock _clock;

  @override
  DateTime build() {
    void onChange(DateTime time) => state = time;
    _clock.follow(onChange);
    ref.onDispose(() => _clock.unfollow(onChange));
    return _clock.current;
  }
}
```

**Replace `test/support/clock_harness.dart`**

```dart
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/session/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fake_clock.dart';
import 'fake_event_repository.dart';
import 'fake_notification_service.dart';
import 'fake_session_repository.dart';
import 'fake_settings_repository.dart';

/// A provider container with a fake clock, in-memory event, session and
/// settings repositories and a fake notification service, plus helpers to mount
/// a widget under it. The default clock is Wednesday 7 October 2026, 10:30, and
/// that day is selected. The one fake clock also drives the session repository
/// and the session screen's clock, so `clock.set(...)` moves everything.
/// [overrides] adds more provider overrides.
class ClockHarness {
  ClockHarness({
    DateTime? now,
    DateTime? selected,
    List<Override> overrides = const [],
  }) : clock = FakeClock(now ?? DateTime(2026, 10, 7, 10, 30)),
       repository = FakeEventRepository() {
    sessions = FakeSessionRepository(
      events: repository,
      clock: () => clock.current,
    );
    container = ProviderContainer(
      overrides: [
        clockProvider.overrideWith(() => clock),
        eventRepositoryProvider.overrideWithValue(repository),
        sessionRepositoryProvider.overrideWithValue(sessions),
        notificationServiceProvider.overrideWithValue(notifications),
        settingsRepositoryProvider.overrideWithValue(settings),
        sessionNowSourceProvider.overrideWithValue(() => clock.current),
        sessionNowProvider.overrideWith(() => FakeSessionNow(clock)),
        ...overrides,
      ],
    );
    if (selected != null) {
      container.read(selectedDateProvider.notifier).select(selected);
    }
  }

  final FakeClock clock;
  final FakeEventRepository repository;
  late final FakeSessionRepository sessions;
  final FakeNotificationService notifications = FakeNotificationService();
  final FakeSettingsRepository settings = FakeSettingsRepository();
  late final ProviderContainer container;

  /// [home] inside a themed app (light unless [theme] says otherwise).
  /// [textScale] and [reduceMotion] override the system settings.
  Widget app(
    Widget home, {
    double textScale = 1,
    bool reduceMotion = false,
    ThemeData? theme,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: theme ?? AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: child!,
        ),
        home: Scaffold(body: home),
      ),
    );
  }

  void dispose() {
    container.dispose();
    sessions.dispose();
    repository.dispose();
  }
}
```

**Edit `test/support/fake_event_repository.dart`**

Replace:

```dart
  @override
  Future<void> deleteEvent(int id) async {
    _events.removeWhere((event) => event.id == id);
    _notify();
  }
}
```

With:

```dart
  @override
  Future<void> deleteEvent(int id) async {
    _events.removeWhere((event) => event.id == id);
    _notify();
  }

  /// The event with [id], or null.
  CalendarEvent? eventById(int id) {
    for (final event in _events) {
      if (event.id == id) return event;
    }
    return null;
  }

  /// Changes an event's status, as finishing a session does.
  void setStatus(int id, EventStatus status) {
    final index = _events.indexWhere((event) => event.id == id);
    if (index == -1) return;
    final existing = _events[index];
    _events[index] = CalendarEvent(
      id: existing.id,
      seriesId: existing.seriesId,
      date: existing.date,
      title: existing.title,
      tone: existing.tone,
      range: existing.range,
      status: status,
    );
    _notify();
  }
}
```

- [ ] **Step 2: Run the analyzer and the whole suite**

Every existing test builds its screens through the harness or the fakes, so this proves the harness change broke nothing.

```bash
# expect: PASS — analyzer clean; every earlier test still passes
flutter analyze && flutter test
```

- [ ] **Step 3: Commit**

```bash
git add test/support
git commit -m "test: session and notification fakes, and a harness that moves every clock together

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 9: The session display model

`SessionDisplay.of(session, now)` is everything the screen shows at one instant, as plain data: whether it is paused or in overtime, the time left, the overtime, how much of the ring remains, the big text (`28:30`, or `+02:05` once in overtime), the same thing spoken for VoiceOver, and when the planned time runs out. Keeping it pure means the rules (zero is overtime, a pause freezes the number, an extension takes it back out of overtime) are tested without a widget.

**Files:**
- Create: `lib/features/session/model/session_display.dart`
- Test: `test/features/session/session_display_test.dart`

**Interfaces:**
- Consumes: `RunningSession`, `SessionTiming`, `formatCountdown`, `spokenDurationSeconds`, `formatDurationMinutes`.
- Produces: `SessionDisplay.of(RunningSession, DateTime)` with `isPaused`, `isOvertime`, `plannedSeconds`, `elapsedSeconds`, `remainingSeconds` (never negative), `overtimeSeconds`, `plannedEnd`, `fractionRemaining` (1 to 0), `timeText`, `spokenTime`, `plannedText`.

- [ ] **Step 1: Write the failing test**

**Create `test/features/session/session_display_test.dart`**

```dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/session/session_outcome.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/repositories/session_repository.dart';
import 'package:energy_clock/features/session/model/session_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 10, 7, 10, 0, 0);

  RunningSession session({
    int planned = 1500,
    int paused = 0,
    DateTime? pauseStartedAt,
  }) => RunningSession(
    session: SessionRecord(
      id: 1,
      eventId: 1,
      startedAt: start,
      endedAt: null,
      plannedSeconds: planned,
      pausedSeconds: paused,
      pauseStartedAt: pauseStartedAt,
      activeSeconds: 0,
      overtimeSeconds: 0,
      outcome: SessionOutcome.running,
    ),
    eventTitle: 'Deep work',
    eventTone: Tone.focus,
    eventDate: DateTime(2026, 10, 7),
    eventRange: const MinuteRange(600, 625),
  );

  DateTime at(int seconds) => start.add(Duration(seconds: seconds));

  group('while running', () {
    test('shows the time left and how much of the ring remains', () {
      final display = SessionDisplay.of(session(), at(375));

      expect(display.isPaused, isFalse);
      expect(display.isOvertime, isFalse);
      expect(display.remainingSeconds, 1125);
      expect(display.timeText, '18:45');
      expect(display.fractionRemaining, closeTo(0.75, 1e-9));
      expect(display.spokenTime, '18 minutes 45 seconds left');
      expect(display.plannedText, '25m');
    });

    test('starts with a full ring', () {
      final display = SessionDisplay.of(session(), at(0));
      expect(display.fractionRemaining, 1);
      expect(display.timeText, '25:00');
    });

    test('shows hours for a long session', () {
      final display = SessionDisplay.of(session(planned: 7200), at(0));
      expect(display.timeText, '2:00:00');
      expect(display.plannedText, '2h');
    });
  });

  group('in overtime', () {
    test('switches to a plus sign and counts up', () {
      final display = SessionDisplay.of(session(), at(1500 + 125));

      expect(display.isOvertime, isTrue);
      expect(display.remainingSeconds, 0);
      expect(display.overtimeSeconds, 125);
      expect(display.timeText, '+02:05');
      expect(display.fractionRemaining, 0);
      expect(display.spokenTime, '2 minutes 5 seconds over');
    });

    test('is already overtime, at +00:00, the moment the time is used up', () {
      final display = SessionDisplay.of(session(), at(1500));
      expect(display.isOvertime, isTrue);
      expect(display.timeText, '+00:00');
    });

    test('an extension takes it back out of overtime', () {
      final display = SessionDisplay.of(session(planned: 1800), at(1500));
      expect(display.isOvertime, isFalse);
      expect(display.timeText, '05:00');
    });
  });

  group('while paused', () {
    test('freezes the time', () {
      final paused = session(pauseStartedAt: at(300));
      expect(SessionDisplay.of(paused, at(300)).timeText, '20:00');
      expect(SessionDisplay.of(paused, at(900)).timeText, '20:00');
      expect(SessionDisplay.of(paused, at(900)).isPaused, isTrue);
    });
  });

  test('planned end follows pauses and extensions', () {
    final display = SessionDisplay.of(
      session(planned: 1800, paused: 120),
      at(10),
    );
    expect(display.plannedEnd, at(1920));
  });

  test('a clock moved back shows the full time, not a negative one', () {
    final display = SessionDisplay.of(session(), at(-3600));
    expect(display.timeText, '25:00');
    expect(display.fractionRemaining, 1);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

```bash
# expect: FAIL — 'package:energy_clock/features/session/model/session_display.dart' does not exist
flutter test test/features/session/session_display_test.dart
```

- [ ] **Step 3: Implement**

**Create `lib/features/session/model/session_display.dart`**

```dart
import 'dart:math' as math;

import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/repositories/session_repository.dart';

/// What the session screen shows at one moment. Pure data worked out from the
/// session and the time; the screen decides how to draw it.
class SessionDisplay {
  SessionDisplay._({
    required this.isPaused,
    required this.isOvertime,
    required this.plannedSeconds,
    required this.elapsedSeconds,
    required this.remainingSeconds,
    required this.overtimeSeconds,
    required this.plannedEnd,
  });

  factory SessionDisplay.of(RunningSession session, DateTime now) {
    final timing = session.timing;
    final remaining = timing.remainingSecondsAt(now);
    return SessionDisplay._(
      isPaused: timing.isPaused,
      isOvertime: timing.isOvertimeAt(now),
      plannedSeconds: timing.plannedSeconds,
      elapsedSeconds: timing.elapsedSecondsAt(now),
      remainingSeconds: math.max(0, remaining),
      overtimeSeconds: timing.overtimeSecondsAt(now),
      plannedEnd: timing.plannedEnd,
    );
  }

  final bool isPaused;

  /// The planned time is used up. Stays true while paused in overtime.
  final bool isOvertime;

  final int plannedSeconds;
  final int elapsedSeconds;

  /// Seconds left; zero in overtime.
  final int remainingSeconds;

  /// Seconds past the planned end; zero before it.
  final int overtimeSeconds;

  /// When the planned time runs out if the session keeps running.
  final DateTime plannedEnd;

  /// How much of the planned time is left, 1 to 0. Drives the ring.
  double get fractionRemaining =>
      plannedSeconds <= 0 ? 0 : (remainingSeconds / plannedSeconds).clamp(0, 1);

  /// The big number: time left, or "+" and the time over once in overtime.
  String get timeText => isOvertime
      ? '+${formatCountdown(overtimeSeconds)}'
      : formatCountdown(remainingSeconds);

  /// The time as a screen reader should say it.
  String get spokenTime => isOvertime
      ? '${spokenDurationSeconds(overtimeSeconds)} over'
      : '${spokenDurationSeconds(remainingSeconds)} left';

  /// The planned length in the dial's usual short form, "1h 30m".
  String get plannedText =>
      formatDurationMinutes((plannedSeconds / 60).round());
}
```

- [ ] **Step 4: Run the test and the analyzer**

```bash
# expect: PASS — 9 new tests pass
flutter test test/features/session/session_display_test.dart && flutter analyze
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/session/model test/features/session/session_display_test.dart
git commit -m "feat: session display model

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Alerts and recovery

`SessionAlertsNotifier` keeps the one "time is up" notification in step with the running session (spec §6.2):

- scheduled for the planned end while the session runs;
- removed while it is paused, once it has ended, or if the planned end has already passed;
- moved when the session is extended or a pause is resumed (a pause pushes the end later).

It reacts to the **session itself**, so every way of changing a session, and a session found after a relaunch, is handled in one place. Calls are carried out one after another in order, so a quick pause-resume cannot leave a stale notification. A plugin failure is caught and logged, never thrown: the alert is a convenience and must not break a session.

Permission is requested here, **the first time a session needs an alert**, never at launch; the app records in `settings` that it has asked (iOS cannot tell "never asked" from "refused"). A refusal sets the state to `denied`, which shows the one-time banner (Task 12). `sessionAlertsSyncProvider` is the listener that feeds the notifier from `runningSessionProvider`; it ignores re-emissions that change nothing (an unrelated event edit makes the stream emit again) and re-checks when the app returns to the foreground, so turning notifications on in Settings takes effect for the session in progress.

The recovery tests are here too, because they need the fakes from Task 8; the provider itself arrived in Task 7.

**Files:**
- Create: `lib/features/session/session_alerts.dart`
- Test: `test/features/session/session_alerts_test.dart`, `test/features/session/session_recovery_test.dart`

**Interfaces:**
- Consumes: `notificationServiceProvider`, `settingsRepositoryProvider`, `sessionNowSourceProvider`, `runningSessionProvider`, `Strings.sessionEndedTitle`, `Strings.sessionEndedBody`.
- Produces: `sessionEndNotificationId` (1001); `notificationsPromptedKey`, `notificationBannerSeenKey`; `enum AlertsStatus { unknown, granted, denied }`; `SessionAlertsNotifier` (`Notifier<AlertsStatus>`, `Future<void> sync(RunningSession?)`) and `sessionAlertsProvider`; `sessionAlertsSyncProvider: Provider<void>`; `notificationBannerVisibleProvider: FutureProvider<bool>`; `dismissNotificationBanner(WidgetRef)`.

- [ ] **Step 1: Write the failing tests**

**Create `test/features/session/session_alerts_test.dart`**

```dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/repositories/session_repository.dart';
import 'package:energy_clock/features/session/providers.dart';
import 'package:energy_clock/features/session/session_alerts.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;

  // The harness clock reads Wednesday 7 October 2026, 10:30:00.
  final now = DateTime(2026, 10, 7, 10, 30);

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Future<RunningSession> startSession({int start = 630, int end = 690}) async {
    final id = await harness.repository.createEvent(
      day: DateTime(2026, 10, 7),
      title: 'Deep work',
      tone: Tone.focus,
      range: MinuteRange(start, end),
    );
    await harness.sessions.start(eventId: id);
    return harness.sessions.running!;
  }

  SessionAlertsNotifier alerts() =>
      harness.container.read(sessionAlertsProvider.notifier);

  group('scheduling', () {
    test('schedules the alert for the planned end', () async {
      final session = await startSession();

      await alerts().sync(session);

      final pending = harness.notifications.pending[sessionEndNotificationId]!;
      expect(pending.at, now.add(const Duration(hours: 1)));
      expect(pending.title, "Time's up");
      expect(pending.body, contains('Deep work'));
      expect(
        harness.container.read(sessionAlertsProvider),
        AlertsStatus.granted,
      );
    });

    test('does not ask for permission when it is already granted', () async {
      await alerts().sync(await startSession());
      expect(harness.notifications.requests, 0);
    });

    test('a pause removes the alert and a resume puts it back later', () async {
      final session = await startSession();
      await alerts().sync(session);

      harness.clock.set(now.add(const Duration(minutes: 10)));
      await harness.sessions.pause(session.id);
      await alerts().sync(harness.sessions.running);
      expect(harness.notifications.pending, isEmpty);

      harness.clock.set(now.add(const Duration(minutes: 25)));
      await harness.sessions.resume(session.id);
      await alerts().sync(harness.sessions.running);

      // Planned end moves later by the 15 minutes spent paused.
      expect(
        harness.notifications.pending[sessionEndNotificationId]!.at,
        now.add(const Duration(hours: 1, minutes: 15)),
      );
    });

    test('an extension moves the alert later', () async {
      final session = await startSession();
      await harness.sessions.extend(session.id, seconds: 900);

      await alerts().sync(harness.sessions.running);

      expect(
        harness.notifications.pending[sessionEndNotificationId]!.at,
        now.add(const Duration(hours: 1, minutes: 15)),
      );
    });

    test('a session that has ended removes the alert', () async {
      final session = await startSession();
      await alerts().sync(session);

      await alerts().sync(null);

      expect(harness.notifications.pending, isEmpty);
    });

    test('a session already in overtime schedules nothing', () async {
      final session = await startSession();
      harness.clock.set(now.add(const Duration(hours: 2)));

      await alerts().sync(session);

      expect(harness.notifications.pending, isEmpty);
      expect(harness.notifications.log, ['cancel $sessionEndNotificationId']);
    });

    test('a plugin failure never throws', () async {
      harness.notifications.failSchedule = true;
      await expectLater(alerts().sync(await startSession()), completes);
    });

    test('quick changes are carried out in order', () async {
      final session = await startSession();
      final first = alerts().sync(session);
      final second = alerts().sync(null);
      final third = alerts().sync(session);
      await Future.wait([first, second, third]);

      expect(harness.notifications.log, [
        'schedule $sessionEndNotificationId',
        'cancel $sessionEndNotificationId',
        'schedule $sessionEndNotificationId',
      ]);
      expect(harness.notifications.pending, isNotEmpty);
    });
  });

  group('permission', () {
    test('asks once, the first time an alert is needed', () async {
      harness.notifications.enabled = false;
      final session = await startSession();

      await alerts().sync(session);
      await alerts().sync(session);

      expect(harness.notifications.requests, 1);
      expect(harness.settings.values[notificationsPromptedKey], isTrue);
      expect(
        harness.notifications.pending.containsKey(sessionEndNotificationId),
        isTrue,
      );
    });

    test('a refusal leaves the session alone and records the denial', () async {
      harness.notifications.enabled = false;
      harness.notifications.grantsRequest = false;

      await alerts().sync(await startSession());

      expect(harness.notifications.pending, isEmpty);
      expect(
        harness.container.read(sessionAlertsProvider),
        AlertsStatus.denied,
      );
    });

    test('never asks again after the prompt has been shown', () async {
      harness.notifications.enabled = false;
      harness.notifications.grantsRequest = false;
      final session = await startSession();

      await alerts().sync(session);
      await alerts().sync(session);

      expect(harness.notifications.requests, 1);
    });

    test(
      'turning notifications on in Settings takes effect on the next sync',
      () async {
        harness.notifications.enabled = false;
        harness.notifications.grantsRequest = false;
        final session = await startSession();
        await alerts().sync(session);

        harness.notifications.enabled = true;
        await alerts().sync(session);

        expect(
          harness.container.read(sessionAlertsProvider),
          AlertsStatus.granted,
        );
        expect(harness.notifications.pending, isNotEmpty);
      },
    );
  });

  group('the banner', () {
    test('is hidden until permission has been refused', () async {
      expect(
        await harness.container.read(notificationBannerVisibleProvider.future),
        isFalse,
      );
    });

    test('shows after a refusal, and stays hidden once dismissed', () async {
      harness.notifications.enabled = false;
      harness.notifications.grantsRequest = false;
      await alerts().sync(await startSession());

      expect(
        await harness.container.read(notificationBannerVisibleProvider.future),
        isTrue,
      );

      harness.settings.values[notificationBannerSeenKey] = true;
      harness.container.invalidate(notificationBannerVisibleProvider);

      expect(
        await harness.container.read(notificationBannerVisibleProvider.future),
        isFalse,
      );
    });
  });

  group('following the running session', () {
    test('schedules when a session starts and cancels when it ends', () async {
      harness.container.listen(sessionAlertsSyncProvider, (_, _) {});
      harness.container.listen(runningSessionProvider, (_, _) {});
      await pumpEventQueue();
      expect(harness.notifications.log, ['cancel $sessionEndNotificationId']);

      final session = await startSession();
      await pumpEventQueue();
      expect(
        harness.notifications.pending.containsKey(sessionEndNotificationId),
        isTrue,
      );

      await harness.sessions.finish(session.id);
      await pumpEventQueue();
      expect(harness.notifications.pending, isEmpty);
    });

    test('ignores re-emissions that change nothing', () async {
      harness.container.listen(sessionAlertsSyncProvider, (_, _) {});
      harness.container.listen(runningSessionProvider, (_, _) {});
      final session = await startSession();
      await pumpEventQueue();
      final calls = harness.notifications.log.length;

      // An unrelated event edit makes the running-session stream emit again.
      await harness.repository.createEvent(
        day: DateTime(2026, 10, 7),
        title: 'Email',
        tone: Tone.inbox,
        range: const MinuteRange(900, 930),
      );
      await pumpEventQueue();

      expect(harness.notifications.log.length, calls);
      expect(harness.sessions.running!.id, session.id);
    });
  });
}
```

**Create `test/features/session/session_recovery_test.dart`**

```dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/session/providers.dart';
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

  Future<int> addEvent() => harness.repository.createEvent(
    day: DateTime(2026, 10, 7),
    title: 'Deep work',
    tone: Tone.focus,
    range: const MinuteRange(540, 660),
  );

  test('a launch with nothing running has nothing to recover', () async {
    expect(
      await harness.container.read(sessionRecoveryProvider.future),
      isNull,
    );
  });

  test('a session already running at launch is offered for recovery', () async {
    final eventId = await addEvent();
    harness.sessions.seedRunning(
      eventId: eventId,
      startedAt: DateTime(2026, 10, 7, 9, 0),
    );

    final id = await harness.container.read(sessionRecoveryProvider.future);

    expect(id, harness.sessions.running!.id);
  });

  test('a session started after launch is not a recovery', () async {
    await harness.container.read(sessionRecoveryProvider.future);
    await harness.sessions.start(eventId: await addEvent());

    expect(harness.container.read(sessionRecoveryProvider).value, isNull);
  });

  test('resolving clears the offer', () async {
    final eventId = await addEvent();
    harness.sessions.seedRunning(
      eventId: eventId,
      startedAt: DateTime(2026, 10, 7, 9, 0),
    );
    await harness.container.read(sessionRecoveryProvider.future);

    harness.container.read(sessionRecoveryProvider.notifier).resolve();

    expect(harness.container.read(sessionRecoveryProvider).value, isNull);
  });
}
```

- [ ] **Step 2: Run them to see the alerts test fail**

```bash
# expect: FAIL — 'package:energy_clock/features/session/session_alerts.dart' does not exist (the recovery tests would pass on their own)
flutter test test/features/session/session_alerts_test.dart test/features/session/session_recovery_test.dart
```

- [ ] **Step 3: Implement**

**Create `lib/features/session/session_alerts.dart`**

```dart
import 'dart:async';

import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/notifications/notification_service.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/session_repository.dart';
import 'package:energy_clock/features/session/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The id of the one "time is up" notification. There is only ever one,
/// because only one session runs at a time.
const int sessionEndNotificationId = 1001;

/// Set once the system permission prompt has been shown, so the app never asks
/// twice. iOS cannot tell "never asked" from "refused", so the app remembers.
const String notificationsPromptedKey = 'notifications_prompted';

/// Set once the person has dismissed the "alerts are off" banner.
const String notificationBannerSeenKey = 'notification_banner_seen';

/// What the app knows about notification permission.
enum AlertsStatus {
  /// Not looked at yet, because no session has been started.
  unknown,
  granted,
  denied,
}

/// Keeps the "time is up" notification in line with the running session
/// (spec §6.2): scheduled for the planned end while the session runs, removed
/// while it is paused or once it has ended, and moved when it is extended. It
/// reacts to the session itself, so every way of changing a session, and a
/// session found after a relaunch, is handled in one place.
///
/// Permission is requested here, the first time a session needs an alert, not
/// at launch. A refused permission never stops a session; the screen shows a
/// one-time banner instead.
class SessionAlertsNotifier extends Notifier<AlertsStatus> {
  Future<void> _tail = Future<void>.value();

  @override
  AlertsStatus build() => AlertsStatus.unknown;

  /// Brings the pending notification in line with [session]. Calls are carried
  /// out one after another, in order, so a quick pause and resume cannot leave
  /// a stale notification behind.
  Future<void> sync(RunningSession? session) {
    final run = _tail.then((_) => _sync(session));
    _tail = run;
    return run;
  }

  Future<void> _sync(RunningSession? session) async {
    try {
      final service = ref.read(notificationServiceProvider);
      final now = ref.read(sessionNowSourceProvider)();
      final timing = session?.timing;
      if (session == null ||
          timing!.isPaused ||
          !timing.plannedEnd.isAfter(now)) {
        await service.cancel(sessionEndNotificationId);
        return;
      }
      if (!await _permitted(service)) {
        await service.cancel(sessionEndNotificationId);
        return;
      }
      await service.schedule(
        id: sessionEndNotificationId,
        at: timing.plannedEnd,
        title: Strings.sessionEndedTitle,
        body: Strings.sessionEndedBody(session.eventTitle),
      );
    } catch (error) {
      // The alert is a convenience; it must never break the session.
      debugPrint('Could not update the session alert: $error');
    }
  }

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
}

final sessionAlertsProvider =
    NotifierProvider<SessionAlertsNotifier, AlertsStatus>(
      SessionAlertsNotifier.new,
    );

/// Keeps [sessionAlertsProvider] in step with the running session. Watch it
/// from a widget that lives as long as the app does. Also re-checks when the
/// app returns to the foreground, so turning notifications on in Settings
/// takes effect for the session in progress.
final sessionAlertsSyncProvider = Provider<void>((ref) {
  var first = true;
  RunningSession? synced;

  void sync(RunningSession? session) {
    unawaited(ref.read(sessionAlertsProvider.notifier).sync(session));
  }

  ref.listen<AsyncValue<RunningSession?>>(runningSessionProvider, (
    previous,
    next,
  ) {
    if (!next.hasValue) return;
    final session = next.value;
    // The stream also re-emits when unrelated events change; only a change to
    // the session itself needs the notification redone.
    if (!first && session == synced) return;
    first = false;
    synced = session;
    sync(session);
  }, fireImmediately: true);

  final lifecycle = AppLifecycleListener(
    onResume: () => sync(ref.read(runningSessionProvider).valueOrNull),
  );
  ref.onDispose(lifecycle.dispose);
});

/// Whether to show the one-time "alerts are off" banner: permission was
/// refused and the person has not dismissed the banner yet.
final notificationBannerVisibleProvider = FutureProvider<bool>((ref) async {
  if (ref.watch(sessionAlertsProvider) != AlertsStatus.denied) return false;
  final seen = await ref
      .watch(settingsRepositoryProvider)
      .getBool(notificationBannerSeenKey);
  return !seen;
});

/// Hides the banner for good.
Future<void> dismissNotificationBanner(WidgetRef ref) async {
  await ref
      .read(settingsRepositoryProvider)
      .setBool(notificationBannerSeenKey, true);
  ref.invalidate(notificationBannerVisibleProvider);
}
```

- [ ] **Step 4: Run the tests and the analyzer**

```bash
# expect: PASS — 16 alerts tests and 4 recovery tests pass (the plugin-failure test prints one "Could not update the session alert" line; that is expected)
flutter test test/features/session/session_alerts_test.dart test/features/session/session_recovery_test.dart && flutter analyze
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/session/session_alerts.dart test/features/session
git commit -m "feat: keep the end-of-session alert in step with the running session

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Stage 3 — The session screen

### Task 11: The countdown ring

`CountdownRingPainter` draws a track and, over it, a rounded arc that starts at the top and runs clockwise for `fraction` of the circle (a whole circle at 1, only the track at 0). `CountdownRing` puts it on a raised round face like the dial's (a soft shadow in light mode, a hairline in dark), with the child in the middle and an optional single spoken sentence for VoiceOver. The ring is 6.5% of the diameter thick, which is thin enough to leave room for a seven-character time like `1:06:43`.

**Files:**
- Create: `lib/features/session/widgets/countdown_ring.dart`
- Test: `test/features/session/countdown_ring_test.dart`

**Interfaces:**
- Consumes: `context.appColors`.
- Produces: `CountdownRingPainter({fraction, thickness, color, trackColor})`; `CountdownRing({required diameter, required fraction, required color, required child, semanticsLabel})`; `CountdownRing.thicknessFor(double diameter)`; `CountdownRing.innerWidthFor(double diameter)`.

- [ ] **Step 1: Write the failing test**

**Create `test/features/session/countdown_ring_test.dart`**

```dart
import 'dart:math' as math;

import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/features/session/widgets/countdown_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const trackColor = Color(0xFF111111);
  const fillColor = Color(0xFF222222);

  Future<void> show(
    WidgetTester tester,
    double fraction, {
    String? semanticsLabel,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Center(
          child: CountdownRing(
            diameter: 300,
            fraction: fraction,
            color: fillColor,
            semanticsLabel: semanticsLabel,
            child: const Text('time', textDirection: TextDirection.ltr),
          ),
        ),
      ),
    );
  }

  RenderObject ringPaint(WidgetTester tester) => tester.renderObject(
    find
        .descendant(
          of: find.byType(CountdownRing),
          matching: find.byType(CustomPaint),
        )
        .first,
  );

  testWidgets('a part-filled ring paints an arc from the top, clockwise', (
    tester,
  ) async {
    await show(tester, 0.25);

    expect(
      ringPaint(tester),
      paints
        ..circle() // the track
        ..arc(
          startAngle: -math.pi / 2,
          sweepAngle: math.pi / 2,
          useCenter: false,
          color: fillColor,
        ),
    );
  });

  testWidgets('a full ring paints a whole circle, not an arc', (tester) async {
    await show(tester, 1);

    expect(
      ringPaint(tester),
      paints
        ..circle()
        ..circle(color: fillColor),
    );
  });

  testWidgets('an empty ring paints only the track', (tester) async {
    await show(tester, 0);

    expect(ringPaint(tester), paints..circle());
    expect(ringPaint(tester), isNot(paints..arc()));
  });

  testWidgets('shows its child in the middle', (tester) async {
    await show(tester, 0.5);
    expect(find.text('time'), findsOneWidget);
  });

  testWidgets('is read as the given sentence, and its child is not', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await show(tester, 0.5, semanticsLabel: 'Deep work, 10 minutes left');

    expect(find.bySemanticsLabel('Deep work, 10 minutes left'), findsOneWidget);
    expect(find.bySemanticsLabel('time'), findsNothing);
    handle.dispose();
  });

  group('the painter', () {
    CountdownRingPainter painter({
      double fraction = 0.5,
      double thickness = 10,
      Color color = fillColor,
      Color track = trackColor,
    }) => CountdownRingPainter(
      fraction: fraction,
      thickness: thickness,
      color: color,
      trackColor: track,
    );

    test('repaints only when something it draws changed', () {
      final base = painter();
      expect(base.shouldRepaint(painter()), isFalse);
      expect(base.shouldRepaint(painter(fraction: 0.4)), isTrue);
      expect(base.shouldRepaint(painter(thickness: 12)), isTrue);
      expect(base.shouldRepaint(painter(color: trackColor)), isTrue);
      expect(base.shouldRepaint(painter(track: fillColor)), isTrue);
    });
  });

  test(
    'the ring is thinner than a tenth of the face, and leaves room inside',
    () {
      expect(CountdownRing.thicknessFor(300), lessThan(30));
      expect(CountdownRing.innerWidthFor(300), greaterThan(150));
      expect(CountdownRing.innerWidthFor(300), lessThan(300));
    },
  );
}
```

- [ ] **Step 2: Run it to see it fail**

```bash
# expect: FAIL — 'package:energy_clock/features/session/widgets/countdown_ring.dart' does not exist
flutter test test/features/session/countdown_ring_test.dart
```

- [ ] **Step 3: Implement**

**Create `lib/features/session/widgets/countdown_ring.dart`**

```dart
import 'dart:math' as math;

import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// A ring that empties clockwise as time runs out. It starts full at the top.
/// A [fraction] of 1 is a full circle and 0 is nothing but the track.
class CountdownRingPainter extends CustomPainter {
  const CountdownRingPainter({
    required this.fraction,
    required this.thickness,
    required this.color,
    required this.trackColor,
  });

  /// How much of the ring is filled, 0 to 1.
  final double fraction;

  final double thickness;

  /// The filled part.
  final Color color;

  /// The empty part.
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - thickness) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = trackColor,
    );

    final filled = fraction.clamp(0.0, 1.0);
    if (filled <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..color = color;
    if (filled >= 1) {
      canvas.drawCircle(center, radius, paint);
    } else {
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * filled, false, paint);
    }
  }

  @override
  bool shouldRepaint(CountdownRingPainter old) =>
      old.fraction != fraction ||
      old.thickness != thickness ||
      old.color != color ||
      old.trackColor != trackColor;
}

/// The session's countdown: a raised round face like the dial's, the ring
/// around its edge, and [child] in the middle.
class CountdownRing extends StatelessWidget {
  const CountdownRing({
    required this.diameter,
    required this.fraction,
    required this.color,
    required this.child,
    this.semanticsLabel,
    super.key,
  });

  final double diameter;
  final double fraction;

  /// The filled part: the event's tone, or the danger colour in overtime.
  final Color color;

  final Widget child;
  final String? semanticsLabel;

  /// The ring's thickness for a face of [diameter].
  static double thicknessFor(double diameter) => diameter * 0.065;

  /// The width available for [child] inside the ring.
  static double innerWidthFor(double diameter) =>
      diameter - 2 * thicknessFor(diameter) - diameter * 0.12;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final thickness = thicknessFor(diameter);

    final ring = SizedBox.square(
      dimension: diameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surface,
          boxShadow: colors.faceShadow,
          border: colors.isDark ? Border.all(color: colors.outline) : null,
        ),
        child: CustomPaint(
          painter: CountdownRingPainter(
            fraction: fraction,
            thickness: thickness,
            color: color,
            trackColor: colors.outline,
          ),
          child: Center(
            child: SizedBox(width: innerWidthFor(diameter), child: child),
          ),
        ),
      ),
    );

    if (semanticsLabel == null) return ring;
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: ring,
    );
  }
}
```

- [ ] **Step 4: Run the test and the analyzer**

```bash
# expect: PASS — 7 new tests pass
flutter test test/features/session/countdown_ring_test.dart && flutter analyze
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/session/widgets/countdown_ring.dart test/features/session/countdown_ring_test.dart
git commit -m "feat: countdown ring

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 12: The session screen, and the Clock tab that shows it

The screen itself (spec §6.1), and the app-layer widget that puts it in the Clock tab's place while a session runs.

**What the screen shows.** The event's tone chip, title and slot; a big countdown ring in the tone's colour with the time left in the middle (`28:30`, or `1:06:43` from an hour up); under it "Planned 30m · ends 11:00"; then the buttons. Pause is the main button while time runs. Once the planned time is used up the ring turns solid red, the time becomes `+02:05` counting up with the word "Overtime", and **Finish takes over as the main button** (it was "Finish early"). A firm haptic tap marks the moment time runs out, if the screen is open. Abandon asks first; finishing and closing out show a "Logged 12m on Deep work." message.

**Three states of the lower half.** The ordinary buttons; the **recovery card** (Task 7's `sessionRecoveryProvider`) when the app found the session already running at launch, with Resume and Close out and the caption "Closing out records at most the planned time"; and, above the header, the one-time **alerts-off banner** when notification permission was refused.

**Layout.** The screen scrolls, so unlike the Clock page it can never overflow; `SessionLayoutPlan` only chooses the ring size (200–360 pt on a phone or a medium window, up to 520 on a wide one) and whether the buttons stack one to a row (text above 115%). A wide window gets two panes: the ring on the left, the details and buttons on the right. At normal text size the whole screen fits without scrolling at all eight sizes (Task 14 checks this).

**`ClockTab`** (app layer, because it composes two features) shows the day, or the session when one is running. It shows **nothing at all** until both the running session and the recovery state are known, so a session left running by a killed app opens on its recovery card instead of flashing the day or the buttons. If sessions cannot be read it shows the day: a broken read must never lock the person out. It also watches `sessionAlertsSyncProvider`, which keeps the notification in step for as long as the app lives. `TabScaffold` now builds `ClockTab` for the first tab, and `tab_scaffold_test.dart` gets session fakes.

**Files:**
- Create: `lib/features/session/session_layout.dart`, `lib/features/session/widgets/session_controls.dart`, `lib/features/session/widgets/alerts_banner.dart`, `lib/features/session/widgets/recovery_card.dart`, `lib/features/session/session_screen.dart`, `lib/app/navigation/clock_tab.dart`
- Modify: `lib/app/navigation/tab_scaffold.dart`, `test/app/tab_scaffold_test.dart`
- Test: `test/features/session/session_layout_test.dart`, `test/features/session/session_screen_test.dart`, `test/app/clock_tab_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 2–11: `SessionDisplay`, `CountdownRing`, `sessionNowProvider`, `runningSessionProvider`, `sessionRecoveryProvider`, `sessionAlertsSyncProvider`, `notificationBannerVisibleProvider`, `dismissNotificationBanner`, `sessionRepositoryProvider`, `notificationServiceProvider`, `confirmDestructive`, `ContentWidth`, `TabBarInset`, `ClockScreen`, `ClockHarness`.
- Produces: `SessionLayoutPlan.forSize(Size, {inset, textScale, windowClass, bannerVisible, recovering})` with `wide`, `stackedControls`, `ringDiameter` and constants `minRing` (200), `maxRing` (360), `maxWideRing` (520), `stackedControlsTextScale` (1.15); `SessionControls`, `AlertsBanner`, `RecoveryCard`; `SessionScreen({required RunningSession session})`; `ClockTab`. Widget keys the tests rely on: `session-ring`, `session-time`, `session-state`, `session-title`, `session-footer`, `session-pause`, `session-add-5`, `session-add-15`, `session-finish`, `session-abandon`, `recovery-resume`, `recovery-close-out`, `alerts-open-settings`, `alerts-dismiss`.

- [ ] **Step 1: Write the failing tests, and give the tab scaffold test the session fakes**

**Create `test/features/session/session_layout_test.dart`**

```dart
import 'package:energy_clock/features/session/session_layout.dart';
import 'package:energy_clock/shared/layout/window_class.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SessionLayoutPlan plan(
    Size size, {
    double inset = 84,
    double textScale = 1,
    WindowClass? windowClass,
    bool banner = false,
    bool recovering = false,
  }) => SessionLayoutPlan.forSize(
    size,
    inset: inset,
    textScale: textScale,
    windowClass: windowClass ?? windowClassFor(size.width),
    bannerVisible: banner,
    recovering: recovering,
  );

  group('on a phone', () {
    test('the ring fills the width on a tall phone, up to its maximum', () {
      final p = plan(const Size(402, 812), inset: 118);
      expect(p.wide, isFalse);
      expect(p.ringDiameter, 354); // 402 - 2 x 24
      expect(p.ringDiameter, lessThanOrEqualTo(SessionLayoutPlan.maxRing));
    });

    test('the ring shrinks to leave room on a short phone', () {
      final tall = plan(const Size(402, 812), inset: 118);
      final short = plan(const Size(375, 647));
      expect(short.ringDiameter, lessThan(tall.ringDiameter));
      expect(
        short.ringDiameter,
        greaterThanOrEqualTo(SessionLayoutPlan.minRing),
      );
    });

    test('the ring is never smaller than its minimum', () {
      final p = plan(const Size(320, 400), textScale: 2);
      expect(p.ringDiameter, SessionLayoutPlan.minRing);
    });

    test('a banner or the recovery card leaves less room for the ring', () {
      const size = Size(375, 647);
      final plain = plan(size).ringDiameter;
      expect(plan(size, banner: true).ringDiameter, lessThanOrEqualTo(plain));
      expect(
        plan(size, recovering: true).ringDiameter,
        lessThanOrEqualTo(plain),
      );
    });
  });

  group('the buttons', () {
    test('sit in two rows up to 115% text, then stack', () {
      expect(plan(const Size(402, 812)).stackedControls, isFalse);
      expect(
        plan(const Size(402, 812), textScale: 1.15).stackedControls,
        isFalse,
      );
      expect(
        plan(const Size(402, 812), textScale: 1.3).stackedControls,
        isTrue,
      );
    });
  });

  group('on a wide window', () {
    test('uses two panes and a large ring', () {
      final p = plan(const Size(1376, 1032), inset: 84);
      expect(p.wide, isTrue);
      expect(p.ringDiameter, greaterThan(SessionLayoutPlan.maxRing));
      expect(p.ringDiameter, lessThanOrEqualTo(SessionLayoutPlan.maxWideRing));
    });

    test('the ring is limited by the height of a landscape window', () {
      final p = plan(const Size(1194, 600), inset: 84);
      expect(p.ringDiameter, lessThanOrEqualTo(600 - 84));
    });

    test('a medium window is one column', () {
      final p = plan(const Size(744, 1133));
      expect(p.wide, isFalse);
      expect(p.ringDiameter, lessThanOrEqualTo(SessionLayoutPlan.maxRing));
    });
  });
}
```

**Create `test/features/session/session_screen_test.dart`**

```dart
import 'package:energy_clock/app/navigation/clock_tab.dart';
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/core/event_status.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/session/session_outcome.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/clock_screen.dart';
import 'package:energy_clock/features/session/widgets/countdown_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';
import '../../support/dial_pump.dart';

void main() {
  late ClockHarness harness;

  // The harness clock reads Wednesday 7 October 2026, 10:30:00.
  final start = DateTime(2026, 10, 7, 10, 30);

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  /// A 30-minute event, with a session started on it at 10:30.
  Future<int> beginSession({
    String title = 'Deep work',
    Tone tone = Tone.focus,
    int begin = 600,
    int end = 630,
  }) async {
    final eventId = await harness.repository.createEvent(
      day: DateTime(2026, 10, 7),
      title: title,
      tone: tone,
      range: MinuteRange(begin, end),
    );
    await harness.sessions.start(eventId: eventId);
    return eventId;
  }

  /// Moves every clock to [seconds] after the start and lets the screen
  /// redraw.
  Future<void> tickTo(WidgetTester tester, int seconds) async {
    harness.clock.set(start.add(Duration(seconds: seconds)));
    await tester.pump();
  }

  Future<void> show(
    WidgetTester tester, {
    double textScale = 1,
    bool reduceMotion = false,
  }) async {
    await tester.pumpWidget(
      harness.app(
        const ClockTab(),
        textScale: textScale,
        reduceMotion: reduceMotion,
      ),
    );
    await pumpDial(tester);
  }

  /// Opens the app on the Clock tab, then starts a session, as a person would.
  /// (A session that is already running when the app opens is a leftover.)
  Future<int> startAndShow(WidgetTester tester, {double textScale = 1}) async {
    await show(tester, textScale: textScale);
    final eventId = await beginSession();
    await pumpDial(tester);
    return eventId;
  }

  String timeText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('session-time'))).data!;

  String stateText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('session-state'))).data!;

  Finder button(String key) => find.byKey(ValueKey(key));

  group('what it shows', () {
    testWidgets('the title, tone, slot and the full time', (tester) async {
      await startAndShow(tester);

      expect(find.text('Deep work'), findsOneWidget);
      expect(find.text('Focus'), findsOneWidget);
      expect(find.text('10:00 – 10:30'), findsOneWidget);
      expect(timeText(tester), '30:00');
      expect(stateText(tester), Strings.sessionRemaining);
      expect(find.text('Planned 30m · ends 11:00'), findsOneWidget);
    });

    testWidgets('replaces the day while the session runs', (tester) async {
      await show(tester);
      expect(find.byType(ClockScreen), findsOneWidget);

      await beginSession();
      await pumpDial(tester);
      expect(find.byType(ClockScreen), findsNothing);
      expect(timeText(tester), '30:00');
    });

    testWidgets('counts down as the clock moves', (tester) async {
      await startAndShow(tester);

      await tickTo(tester, 90);
      expect(timeText(tester), '28:30');

      await tickTo(tester, 91);
      expect(timeText(tester), '28:29');
    });

    testWidgets('the ring empties as time passes', (tester) async {
      await startAndShow(tester);
      await tickTo(tester, 450);

      final ring = tester.widget<CountdownRing>(
        find.byKey(const ValueKey('session-ring')),
      );
      expect(ring.fraction, closeTo(0.75, 1e-9));
    });

    testWidgets('the ring is read as one sentence', (tester) async {
      final handle = tester.ensureSemantics();
      await startAndShow(tester);

      expect(
        find.bySemanticsLabel('Deep work, Focus, 30 minutes left'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('pausing', () {
    testWidgets('freezes the time and offers resume', (tester) async {
      await startAndShow(tester);
      await tickTo(tester, 90);

      await tester.tap(button('session-pause'));
      await tester.pump();
      expect(harness.sessions.calls, ['start', 'pause']);
      expect(stateText(tester), Strings.sessionPaused);
      expect(find.text(Strings.sessionResume), findsOneWidget);

      await tickTo(tester, 400);
      expect(timeText(tester), '28:30');
    });

    testWidgets('resume carries on from where it stopped', (tester) async {
      await startAndShow(tester);
      await tickTo(tester, 90);
      await tester.tap(button('session-pause'));
      await tickTo(tester, 400);

      await tester.tap(button('session-pause'));
      await tester.pump();
      expect(harness.sessions.calls, ['start', 'pause', 'resume']);
      expect(stateText(tester), Strings.sessionRemaining);

      await tickTo(tester, 460);
      // Paused from 90 s to 400 s, so 150 s of the 460 have been worked.
      expect(timeText(tester), '27:30');
    });
  });

  group('adding time', () {
    testWidgets('+5m and +15m lengthen the session', (tester) async {
      await startAndShow(tester);

      await tester.tap(button('session-add-5'));
      await tester.pump();
      expect(timeText(tester), '35:00');

      await tester.tap(button('session-add-15'));
      await tester.pump();
      expect(timeText(tester), '50:00');
      expect(harness.sessions.calls, ['start', 'extend 300', 'extend 900']);
    });

    testWidgets('the buttons are spoken in full', (tester) async {
      final handle = tester.ensureSemantics();
      await startAndShow(tester);

      expect(find.bySemanticsLabel('Add 5 minutes'), findsOneWidget);
      expect(find.bySemanticsLabel('Add 15 minutes'), findsOneWidget);
      handle.dispose();
    });
  });

  group('overtime', () {
    testWidgets('turns red and counts up', (tester) async {
      await startAndShow(tester);

      await tickTo(tester, 1800 + 10);

      expect(timeText(tester), '+00:10');
      expect(stateText(tester), Strings.sessionOvertime);
      final ring = tester.widget<CountdownRing>(
        find.byKey(const ValueKey('session-ring')),
      );
      expect(ring.color, AppColors.light.danger);
      expect(ring.fraction, 1);
      expect(find.text('Planned 30m · was due 11:00'), findsOneWidget);
    });

    testWidgets('Finish takes over from Finish early', (tester) async {
      await startAndShow(tester);
      expect(find.text(Strings.sessionFinishEarly), findsOneWidget);

      await tickTo(tester, 1800 + 10);

      expect(find.text(Strings.sessionFinishEarly), findsNothing);
      expect(find.text(Strings.sessionFinish), findsOneWidget);
    });

    testWidgets('adding time takes it back out of overtime', (tester) async {
      await startAndShow(tester);
      await tickTo(tester, 1800 + 10);

      await tester.tap(button('session-add-15'));
      await tester.pump();

      expect(timeText(tester), '14:50');
      expect(stateText(tester), Strings.sessionRemaining);
    });

    testWidgets('one firm tap when the time runs out, none before', (
      tester,
    ) async {
      final haptics = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              haptics.add(call.arguments as String);
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await startAndShow(tester);

      await tickTo(tester, 1799);
      expect(haptics, isEmpty);

      await tickTo(tester, 1800);
      expect(haptics, ['HapticFeedbackType.heavyImpact']);

      await tickTo(tester, 1801);
      expect(haptics, ['HapticFeedbackType.heavyImpact']);
    });
  });

  group('finishing', () {
    testWidgets('early records the time worked and completes the event', (
      tester,
    ) async {
      final eventId = await startAndShow(tester);
      await tickTo(tester, 12 * 60);

      await tester.tap(button('session-finish'));
      await pumpDial(tester);

      final done = harness.sessions.ended.single;
      expect(done.outcome, SessionOutcome.finishedEarly);
      expect(done.activeSeconds, 12 * 60);
      expect(
        harness.repository.eventById(eventId)!.status,
        EventStatus.completed,
      );
      expect(find.text('Logged 12m on Deep work.'), findsOneWidget);
      expect(find.byType(ClockScreen), findsOneWidget);
    });

    testWidgets('after the planned end counts as completed', (tester) async {
      await startAndShow(tester);
      await tickTo(tester, 1800 + 60);

      await tester.tap(button('session-finish'));
      await pumpDial(tester);

      final done = harness.sessions.ended.single;
      expect(done.outcome, SessionOutcome.completed);
      expect(done.overtimeSeconds, 60);
    });
  });

  group('abandoning', () {
    testWidgets('asks first, and keep going changes nothing', (tester) async {
      await startAndShow(tester);

      await tester.tap(button('session-abandon'));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      expect(find.text(Strings.sessionAbandonTitle), findsOneWidget);

      await tester.tap(find.text(Strings.sessionKeepGoing));
      await pumpDial(tester);

      expect(harness.sessions.ended, isEmpty);
      expect(timeText(tester), '30:00');
    });

    testWidgets('confirming records it as abandoned', (tester) async {
      final eventId = await startAndShow(tester);
      await tickTo(tester, 300);

      await tester.tap(button('session-abandon'));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, Strings.sessionAbandon),
        ),
      );
      await pumpDial(tester);

      expect(harness.sessions.ended.single.outcome, SessionOutcome.abandoned);
      expect(
        harness.repository.eventById(eventId)!.status,
        EventStatus.planned,
      );
      expect(find.text(Strings.sessionAbandoned), findsOneWidget);
      expect(find.byType(ClockScreen), findsOneWidget);
    });
  });

  group('a session left running by a killed app', () {
    Future<int> seedLeftover(WidgetTester tester) async {
      final eventId = await harness.repository.createEvent(
        day: DateTime(2026, 10, 7),
        title: 'Deep work',
        tone: Tone.focus,
        range: const MinuteRange(600, 660),
      );
      // Started at 10:10, so at 10:30 it has run 20 minutes of 60.
      harness.sessions.seedRunning(
        eventId: eventId,
        startedAt: DateTime(2026, 10, 7, 10, 10),
        plannedSeconds: 3600,
      );
      return eventId;
    }

    testWidgets('offers to resume or close out, instead of the controls', (
      tester,
    ) async {
      await seedLeftover(tester);
      await show(tester);

      expect(find.text(Strings.recoveryTitle), findsOneWidget);
      expect(find.textContaining('Deep work has been going for 20m'), findsOne);
      expect(button('session-pause'), findsNothing);
      expect(timeText(tester), '40:00');
    });

    testWidgets('says "under a minute" rather than 0m for a fresh one', (
      tester,
    ) async {
      final id = await harness.repository.createEvent(
        day: DateTime(2026, 10, 7),
        title: 'Deep work',
        tone: Tone.focus,
        range: const MinuteRange(600, 660),
      );
      harness.sessions.seedRunning(
        eventId: id,
        startedAt: DateTime(2026, 10, 7, 10, 29, 30),
      );
      await show(tester);

      expect(
        find.textContaining('Deep work has been going for under a minute'),
        findsOneWidget,
      );
    });

    testWidgets('resume carries on and brings the controls back', (
      tester,
    ) async {
      await seedLeftover(tester);
      await show(tester);

      await tester.tap(button('recovery-resume'));
      await pumpDial(tester);

      expect(find.text(Strings.recoveryTitle), findsNothing);
      expect(button('session-pause'), findsOneWidget);
      expect(harness.sessions.calls, isEmpty);
    });

    testWidgets('close out ends it and returns to the day', (tester) async {
      await seedLeftover(tester);
      await show(tester);

      await tester.tap(button('recovery-close-out'));
      await pumpDial(tester);

      expect(harness.sessions.calls, ['closeOut']);
      final done = harness.sessions.ended.single;
      expect(done.outcome, SessionOutcome.finishedEarly);
      expect(done.activeSeconds, 20 * 60);
      expect(find.byType(ClockScreen), findsOneWidget);
      expect(find.text('Logged 20m on Deep work.'), findsOneWidget);
    });

    testWidgets('a session started this launch is never offered', (
      tester,
    ) async {
      await show(tester);
      await beginSession();
      await pumpDial(tester);

      expect(find.text(Strings.recoveryTitle), findsNothing);
      expect(button('session-pause'), findsOneWidget);
    });
  });

  group('when notifications are off', () {
    setUp(() {
      harness.notifications.enabled = false;
      harness.notifications.grantsRequest = false;
    });

    testWidgets('a one-time banner explains it', (tester) async {
      await show(tester);
      await beginSession();
      await pumpDial(tester);

      expect(find.text(Strings.alertsOffTitle), findsOneWidget);
      expect(timeText(tester), '30:00');
    });

    testWidgets('dismissing it hides it for good', (tester) async {
      await show(tester);
      await beginSession();
      await pumpDial(tester);

      await tester.tap(button('alerts-dismiss'));
      await pumpDial(tester);

      expect(find.text(Strings.alertsOffTitle), findsNothing);
      expect(harness.settings.values['notification_banner_seen'], isTrue);
    });

    testWidgets('Open Settings opens the settings and hides the banner', (
      tester,
    ) async {
      await show(tester);
      await beginSession();
      await pumpDial(tester);

      await tester.tap(button('alerts-open-settings'));
      await pumpDial(tester);

      expect(harness.notifications.settingsOpened, 1);
      expect(find.text(Strings.alertsOffTitle), findsNothing);
    });
  });

  testWidgets('starting a session schedules the alert for its end', (
    tester,
  ) async {
    await show(tester);
    await beginSession();
    await pumpDial(tester);

    final pending = harness.notifications.pending.values.single;
    expect(pending.at, DateTime(2026, 10, 7, 11, 0));
  });
}
```

**Create `test/app/clock_tab_test.dart`**

```dart
import 'dart:async';

import 'package:energy_clock/app/navigation/clock_tab.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/session_repository.dart';
import 'package:energy_clock/features/clock/clock_screen.dart';
import 'package:energy_clock/features/session/session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/clock_harness.dart';
import '../support/dial_pump.dart';
import '../support/fake_session_repository.dart';

/// A session repository whose running-session stream the test controls.
class _GatedSessions extends FakeSessionRepository {
  _GatedSessions({required super.events, required super.clock});

  final Completer<void> gate = Completer<void>();
  bool failReads = false;

  @override
  Stream<RunningSession?> watchRunning() async* {
    await gate.future;
    if (failReads) throw StateError('the sessions are unreadable');
    yield* super.watchRunning();
  }
}

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Future<int> addEvent() => harness.repository.createEvent(
    day: DateTime(2026, 10, 7),
    title: 'Deep work',
    tone: Tone.focus,
    range: const MinuteRange(540, 720),
  );

  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(harness.app(const ClockTab()));
    await pumpDial(tester);
  }

  testWidgets('shows the day when no session is running', (tester) async {
    await show(tester);
    expect(find.byType(ClockScreen), findsOneWidget);
    expect(find.byType(SessionScreen), findsNothing);
  });

  testWidgets('shows nothing at all until the session is known', (
    tester,
  ) async {
    final gated = _GatedSessions(
      events: harness.repository,
      clock: () => harness.clock.current,
    );
    addTearDown(gated.dispose);
    final id = await addEvent();
    gated.seedRunning(eventId: id, startedAt: DateTime(2026, 10, 7, 10, 10));
    final own = ClockHarness(
      overrides: [sessionRepositoryProvider.overrideWithValue(gated)],
    );
    addTearDown(own.dispose);

    await tester.pumpWidget(own.app(const ClockTab()));
    await pumpDial(tester);
    expect(find.byType(ClockScreen), findsNothing);
    expect(find.byType(SessionScreen), findsNothing);

    gated.gate.complete();
    await pumpDial(tester);
    expect(find.byType(SessionScreen), findsOneWidget);
  });

  testWidgets('a session left running opens straight on the recovery card', (
    tester,
  ) async {
    final id = await addEvent();
    harness.sessions.seedRunning(
      eventId: id,
      startedAt: DateTime(2026, 10, 7, 10, 10),
    );

    await tester.pumpWidget(harness.app(const ClockTab()));
    // Frame by frame: the controls and the day must never show, even briefly.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byKey(const ValueKey('session-pause')), findsNothing);
      expect(find.byType(ClockScreen), findsNothing);
    }
    expect(find.text(Strings.recoveryTitle), findsOneWidget);
  });

  testWidgets('if sessions cannot be read, the day is shown', (tester) async {
    final broken = _GatedSessions(
      events: harness.repository,
      clock: () => harness.clock.current,
    )..failReads = true;
    addTearDown(broken.dispose);
    final own = ClockHarness(
      overrides: [sessionRepositoryProvider.overrideWithValue(broken)],
    );
    addTearDown(own.dispose);

    await tester.pumpWidget(own.app(const ClockTab()));
    broken.gate.complete();
    await pumpDial(tester);

    expect(find.byType(ClockScreen), findsOneWidget);
  });
}
```

**Edit `test/app/tab_scaffold_test.dart`**

Replace:

```dart
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/clock/clock_screen.dart';
```

With:

```dart
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/clock/clock_screen.dart';
```

**Edit `test/app/tab_scaffold_test.dart`**

Replace:

```dart
import '../support/fake_event_repository.dart';
```

With:

```dart
import '../support/fake_event_repository.dart';
import '../support/fake_notification_service.dart';
import '../support/fake_session_repository.dart';
import '../support/fake_settings_repository.dart';
```

**Edit `test/app/tab_scaffold_test.dart`**

Replace:

```dart
  late FakeEventRepository repository;

  setUp(() {
    repository = FakeEventRepository();
  });

  tearDown(() {
    repository.dispose();
  });

  Widget harness() {
    return ProviderScope(
      overrides: [eventRepositoryProvider.overrideWithValue(repository)],
```

With:

```dart
  late FakeEventRepository repository;
  late FakeSessionRepository sessions;

  setUp(() {
    repository = FakeEventRepository();
    sessions = FakeSessionRepository(events: repository, clock: DateTime.now);
  });

  tearDown(() {
    sessions.dispose();
    repository.dispose();
  });

  Widget harness() {
    return ProviderScope(
      overrides: [
        eventRepositoryProvider.overrideWithValue(repository),
        sessionRepositoryProvider.overrideWithValue(sessions),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
      ],
```

That edit only adds overrides, so `tab_scaffold_test.dart` still passes on its own now.

- [ ] **Step 2: Run the new tests to see them fail**

```bash
# expect: FAIL — 'package:energy_clock/features/session/session_layout.dart', '…/session_screen.dart' and 'package:energy_clock/app/navigation/clock_tab.dart' do not exist
flutter test test/features/session/session_layout_test.dart test/features/session/session_screen_test.dart test/app/clock_tab_test.dart
```

- [ ] **Step 3: Implement the layout rules, the three small widgets, the screen and the Clock tab**

**Create `lib/features/session/session_layout.dart`**

```dart
import 'dart:math' as math;

import 'package:energy_clock/shared/layout/window_class.dart';
import 'package:flutter/painting.dart';

/// How the session screen is arranged for a window. Unlike the Clock page, the
/// session screen scrolls when it must, so these numbers only choose the ring
/// size and whether the buttons stack; a wrong guess can never overflow.
class SessionLayoutPlan {
  const SessionLayoutPlan({
    required this.wide,
    required this.stackedControls,
    required this.ringDiameter,
  });

  /// Text scale above which the buttons stack one to a row.
  static const double stackedControlsTextScale = 1.15;

  /// The smallest ring. Below this the screen scrolls instead of shrinking it.
  static const double minRing = 200;

  /// The largest ring on a phone or a medium window.
  static const double maxRing = 360;

  /// The largest ring on a wide window.
  static const double maxWideRing = 520;

  /// Two panes: the ring on the left, the details and buttons on the right.
  final bool wide;

  /// One button per row, for large text.
  final bool stackedControls;

  final double ringDiameter;

  /// Chooses the layout for a body of [size], with [inset] of its bottom
  /// covered by the floating tab bar. [bannerVisible] and [recovering] say
  /// whether the taller cards are showing.
  factory SessionLayoutPlan.forSize(
    Size size, {
    required double inset,
    required double textScale,
    required WindowClass windowClass,
    required bool bannerVisible,
    required bool recovering,
  }) {
    final stacked = textScale > stackedControlsTextScale;
    final available = size.height - inset;

    if (windowClass == WindowClass.wide) {
      const paneGap = 24.0;
      final paneWidth = (size.width * 0.36).clamp(340.0, 440.0);
      final left = size.width - paneWidth - 3 * paneGap;
      final ring = math.min(left, available - 2 * paneGap);
      return SessionLayoutPlan(
        wide: true,
        stackedControls: stacked,
        ringDiameter: ring.clamp(minRing, maxWideRing).toDouble(),
      );
    }

    // Generous estimates, at normal text size, of what sits around the ring.
    final header = 49 + 80 * textScale;
    final footer = 20 * textScale;
    final controls = recovering
        ? 260 + 40 * textScale
        : stacked
        ? 248.0
        : 120.0;
    final banner = bannerVisible ? 150 + 30 * textScale : 0;
    const gaps = 4 * 16.0;
    final room = available - header - footer - controls - banner - gaps;
    final widest = math.min(size.width - 48, maxRing);
    return SessionLayoutPlan(
      wide: false,
      stackedControls: stacked,
      ringDiameter: room.clamp(minRing, math.max(minRing, widest)).toDouble(),
    );
  }
}
```

**Create `lib/features/session/widgets/session_controls.dart`**

```dart
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/session/model/session_display.dart';
import 'package:energy_clock/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';

/// The buttons under the ring: pause or resume, add time, finish, abandon.
///
/// Pause is the main button while the time runs. Once the time is used up,
/// Finish takes over, because that is what the person does next.
class SessionControls extends StatelessWidget {
  const SessionControls({
    required this.display,
    required this.stacked,
    required this.onPauseResume,
    required this.onExtend,
    required this.onFinish,
    required this.onAbandon,
    super.key,
  });

  final SessionDisplay display;

  /// One button per row, for large text. Otherwise two rows of buttons.
  final bool stacked;

  final VoidCallback onPauseResume;

  /// Called with the number of seconds to add.
  final void Function(int seconds) onExtend;

  final VoidCallback onFinish;
  final VoidCallback onAbandon;

  @override
  Widget build(BuildContext context) {
    final finishFirst = display.isOvertime && !display.isPaused;

    final pause = AppButton(
      key: const ValueKey('session-pause'),
      label: display.isPaused ? Strings.sessionResume : Strings.sessionPause,
      variant: finishFirst
          ? AppButtonVariant.secondary
          : AppButtonVariant.primary,
      onPressed: onPauseResume,
    );
    final add5 = AppButton(
      key: const ValueKey('session-add-5'),
      label: Strings.sessionAdd5,
      semanticsLabel: Strings.sessionAdd5Semantics,
      variant: AppButtonVariant.secondary,
      onPressed: () => onExtend(5 * 60),
    );
    final add15 = AppButton(
      key: const ValueKey('session-add-15'),
      label: Strings.sessionAdd15,
      semanticsLabel: Strings.sessionAdd15Semantics,
      variant: AppButtonVariant.secondary,
      onPressed: () => onExtend(15 * 60),
    );
    final finish = AppButton(
      key: const ValueKey('session-finish'),
      label: display.isOvertime
          ? Strings.sessionFinish
          : Strings.sessionFinishEarly,
      variant: finishFirst
          ? AppButtonVariant.primary
          : AppButtonVariant.secondary,
      onPressed: onFinish,
    );
    final abandon = AppButton(
      key: const ValueKey('session-abandon'),
      label: Strings.sessionAbandon,
      variant: AppButtonVariant.destructive,
      onPressed: onAbandon,
    );

    const gap = SizedBox(width: AppSpacing.sm, height: AppSpacing.sm);

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          pause,
          gap,
          Row(
            children: [
              Expanded(child: add5),
              gap,
              Expanded(child: add15),
            ],
          ),
          gap,
          finish,
          gap,
          abandon,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(flex: 3, child: pause),
            gap,
            Expanded(flex: 2, child: add5),
            gap,
            Expanded(flex: 2, child: add15),
          ],
        ),
        gap,
        Row(
          children: [
            Expanded(flex: 3, child: finish),
            gap,
            Expanded(flex: 2, child: abandon),
          ],
        ),
      ],
    );
  }
}
```

**Create `lib/features/session/widgets/alerts_banner.dart`**

```dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/shared/widgets/app_button.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// The one-time note shown when notifications are off: the timer works, but
/// nothing will tell the person when time is up while the app is closed.
class AlertsBanner extends StatelessWidget {
  const AlertsBanner({
    required this.onOpenSettings,
    required this.onDismiss,
    super.key,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(CupertinoIcons.bell_slash_fill, color: colors.muted),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Strings.alertsOffTitle,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      Strings.alertsOffBody,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  key: const ValueKey('alerts-open-settings'),
                  label: Strings.openSettings,
                  variant: AppButtonVariant.secondary,
                  onPressed: onOpenSettings,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  key: const ValueKey('alerts-dismiss'),
                  label: Strings.dismiss,
                  variant: AppButtonVariant.secondary,
                  onPressed: onDismiss,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

**Create `lib/features/session/widgets/recovery_card.dart`**

```dart
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/shared/widgets/app_button.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';

/// Shown in place of the controls when the app is opened and finds a session
/// that was left running (spec §6.5): pick it up again, or close it out.
class RecoveryCard extends StatelessWidget {
  const RecoveryCard({
    required this.title,
    required this.elapsed,
    required this.onResume,
    required this.onCloseOut,
    super.key,
  });

  /// The event's title.
  final String title;

  /// How long the session has been going, already formatted.
  final String elapsed;

  final VoidCallback onResume;
  final VoidCallback onCloseOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(Strings.recoveryTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            Strings.recoveryBody(title, elapsed),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            key: const ValueKey('recovery-resume'),
            label: Strings.recoveryResume,
            onPressed: onResume,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            key: const ValueKey('recovery-close-out'),
            label: Strings.recoveryCloseOut,
            variant: AppButtonVariant.secondary,
            onPressed: onCloseOut,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            Strings.recoveryCloseOutHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
```

**Create `lib/features/session/session_screen.dart`**

```dart
import 'dart:async';
import 'dart:math' as math;

import 'package:energy_clock/app/navigation/tab_bar_inset.dart';
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/app_typography.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/session_repository.dart';
import 'package:energy_clock/features/session/model/session_display.dart';
import 'package:energy_clock/features/session/providers.dart';
import 'package:energy_clock/features/session/session_alerts.dart';
import 'package:energy_clock/features/session/session_layout.dart';
import 'package:energy_clock/features/session/widgets/alerts_banner.dart';
import 'package:energy_clock/features/session/widgets/countdown_ring.dart';
import 'package:energy_clock/features/session/widgets/recovery_card.dart';
import 'package:energy_clock/features/session/widgets/session_controls.dart';
import 'package:energy_clock/shared/layout/content_width.dart';
import 'package:energy_clock/shared/layout/window_class.dart';
import 'package:energy_clock/shared/widgets/adaptive_dialog.dart';
import 'package:energy_clock/shared/widgets/tone_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The session view (spec §6.1): the running event's title and tone, a big
/// countdown ring, and the controls. It takes the Clock tab's place while a
/// session runs. Everything it shows is worked out from the clock, so it is
/// right the moment the app comes back to the foreground.
class SessionScreen extends ConsumerWidget {
  const SessionScreen({required this.session, super.key});

  final RunningSession session;

  SessionRepository _repository(WidgetRef ref) =>
      ref.read(sessionRepositoryProvider);

  void _announceLogged(ScaffoldMessengerState messenger, SessionRecord done) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          Strings.sessionLogged(
            session.eventTitle,
            formatDurationMinutes((done.activeSeconds / 60).round()),
          ),
        ),
      ),
    );
  }

  Future<void> _pauseOrResume(WidgetRef ref, SessionDisplay display) {
    unawaited(HapticFeedback.selectionClick());
    final repository = _repository(ref);
    return display.isPaused
        ? repository.resume(session.id)
        : repository.pause(session.id);
  }

  Future<void> _extend(WidgetRef ref, int seconds) {
    unawaited(HapticFeedback.selectionClick());
    return _repository(ref).extend(session.id, seconds: seconds);
  }

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    unawaited(HapticFeedback.mediumImpact());
    final done = await _repository(ref).finish(session.id);
    if (done != null) _announceLogged(messenger, done);
  }

  Future<void> _abandon(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: Strings.sessionAbandonTitle,
      body: Strings.sessionAbandonBody,
      confirmLabel: Strings.sessionAbandon,
      cancelLabel: Strings.sessionKeepGoing,
    );
    if (!confirmed) return;
    await _repository(ref).abandon(session.id);
    messenger.showSnackBar(
      const SnackBar(content: Text(Strings.sessionAbandoned)),
    );
  }

  Future<void> _closeOut(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final done = await _repository(ref).closeOut(session.id);
    ref.read(sessionRecoveryProvider.notifier).resolve();
    if (done != null) _announceLogged(messenger, done);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(sessionNowProvider);
    final display = SessionDisplay.of(session, now);
    final recovering =
        ref.watch(sessionRecoveryProvider).valueOrNull == session.id;
    final bannerVisible =
        ref.watch(notificationBannerVisibleProvider).valueOrNull ?? false;

    // One firm tap when the planned time runs out while the screen is open.
    ref.listen<DateTime>(sessionNowProvider, (previous, next) {
      if (previous == null) return;
      final was = SessionDisplay.of(session, previous);
      final isNow = SessionDisplay.of(session, next);
      if (!was.isOvertime && isNow.isOvertime && !isNow.isPaused) {
        unawaited(HapticFeedback.heavyImpact());
      }
    });

    final colors = context.appColors;
    final tone = context.toneColors.paletteFor(session.eventTone);
    final theme = Theme.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final inset = TabBarInset.of(context);

    final ringColor = display.isOvertime ? colors.danger : tone.solid;
    final stateLabel = display.isPaused
        ? Strings.sessionPaused
        : display.isOvertime
        ? Strings.sessionOvertime
        : Strings.sessionRemaining;
    final stateColor = display.isOvertime && !display.isPaused
        ? colors.danger
        : colors.muted;
    final semanticsLabel = Strings.sessionRingSemantics(
      session.eventTitle,
      session.eventTone.label,
      display.spokenTime,
      display.isPaused
          ? Strings.sessionStatePaused
          : display.isOvertime
          ? Strings.sessionStateOvertime
          : '',
    );

    final plannedEndMinute =
        display.plannedEnd.hour * 60 + display.plannedEnd.minute;
    final footer = display.isPaused
        ? Strings.sessionPlanned(display.plannedText)
        : display.isOvertime
        ? '${Strings.sessionPlanned(display.plannedText)} · '
              '${Strings.sessionWasDueAt(formatMinuteOfDay(plannedEndMinute))}'
        : '${Strings.sessionPlanned(display.plannedText)} · '
              '${Strings.sessionEndsAt(formatMinuteOfDay(plannedEndMinute))}';

    final header = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ToneChip(tone: session.eventTone),
        const SizedBox(height: AppSpacing.md),
        Text(
          session.eventTitle,
          key: const ValueKey('session-title'),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          formatMinuteRange(session.eventRange.start, session.eventRange.end),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );

    Widget ring(double diameter) {
      final timeSize = diameter * 0.18;
      return CountdownRing(
        key: const ValueKey('session-ring'),
        diameter: diameter,
        fraction: display.isOvertime ? 1 : display.fractionRemaining,
        color: ringColor,
        semanticsLabel: semanticsLabel,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              math.min(1.2, MediaQuery.textScalerOf(context).scale(1)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  display.timeText,
                  key: const ValueKey('session-time'),
                  maxLines: 1,
                  style: AppTypography.sessionTime(timeSize).copyWith(
                    color: display.isOvertime ? colors.danger : colors.ink,
                  ),
                ),
              ),
              Text(
                stateLabel,
                key: const ValueKey('session-state'),
                style: theme.textTheme.labelLarge!.copyWith(color: stateColor),
              ),
            ],
          ),
        ),
      );
    }

    Widget controls(bool stacked) {
      if (recovering) {
        return RecoveryCard(
          title: session.eventTitle,
          elapsed: display.elapsedSeconds < 60
              ? Strings.recoveryUnderAMinute
              : formatDurationMinutes(display.elapsedSeconds ~/ 60),
          onResume: () => ref.read(sessionRecoveryProvider.notifier).resolve(),
          onCloseOut: () => _closeOut(context, ref),
        );
      }
      return SessionControls(
        display: display,
        stacked: stacked,
        onPauseResume: () => _pauseOrResume(ref, display),
        onExtend: (seconds) => _extend(ref, seconds),
        onFinish: () => _finish(context, ref),
        onAbandon: () => _abandon(context, ref),
      );
    }

    final banner = bannerVisible
        ? AlertsBanner(
            onOpenSettings: () {
              ref.read(notificationServiceProvider).openSettings();
              dismissNotificationBanner(ref);
            },
            onDismiss: () => dismissNotificationBanner(ref),
          )
        : null;

    final footerText = Text(
      footer,
      key: const ValueKey('session-footer'),
      textAlign: TextAlign.center,
      style: theme.textTheme.labelLarge!.copyWith(color: colors.muted),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final plan = SessionLayoutPlan.forSize(
          constraints.biggest,
          inset: inset,
          textScale: textScale,
          windowClass: context.windowClass,
          bannerVisible: bannerVisible,
          recovering: recovering,
        );

        final Widget content;
        if (plan.wide) {
          content = Row(
            children: [
              Expanded(child: Center(child: ring(plan.ringDiameter))),
              const SizedBox(width: AppSpacing.xxl),
              SizedBox(
                width: (constraints.maxWidth * 0.36).clamp(340.0, 440.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (banner != null) ...[
                      banner,
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    header,
                    const SizedBox(height: AppSpacing.lg),
                    footerText,
                    const SizedBox(height: AppSpacing.lg),
                    controls(plan.stackedControls),
                  ],
                ),
              ),
            ],
          );
        } else {
          content = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (banner != null) ...[
                banner,
                const SizedBox(height: AppSpacing.lg),
              ],
              header,
              const SizedBox(height: AppSpacing.lg),
              Center(child: ring(plan.ringDiameter)),
              const SizedBox(height: AppSpacing.lg),
              footerText,
              const SizedBox(height: AppSpacing.lg),
              controls(plan.stackedControls),
            ],
          );
        }

        final padding = EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.lg,
          AppSpacing.xxl,
          inset,
        );
        final body = SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - padding.vertical,
            ),
            child: Center(child: content),
          ),
        );
        return plan.wide
            ? body
            : ContentWidth(maxWidth: ContentWidths.column, child: body);
      },
    );
  }
}
```

**Create `lib/app/navigation/clock_tab.dart`**

```dart
import 'package:energy_clock/features/clock/clock_screen.dart';
import 'package:energy_clock/features/session/providers.dart';
import 'package:energy_clock/features/session/session_alerts.dart';
import 'package:energy_clock/features/session/session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Clock tab. While a session is running its screen takes the place of the
/// day (spec §6.1); otherwise the day is shown. The other tabs stay reachable.
///
/// This lives in the app layer because it composes two features, and one
/// feature may not import the other.
class ClockTab extends ConsumerWidget {
  const ClockTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the "time is up" notification in step with the session for as long
    // as the app lives.
    ref.watch(sessionAlertsSyncProvider);

    final running = ref.watch(runningSessionProvider);
    // Read at launch: a session already running then was left by a killed app.
    final recovery = ref.watch(sessionRecoveryProvider);

    // Wait for both, so a session left running shows its recovery card from
    // the first frame instead of flashing the controls or the day.
    if (running.isLoading || recovery.isLoading) {
      return ColoredBox(color: Theme.of(context).scaffoldBackgroundColor);
    }

    // If the session cannot be read, show the day: a broken read must never
    // lock the person out of the app.
    final session = running.valueOrNull;
    if (session == null) return const ClockScreen();
    return SessionScreen(session: session);
  }
}
```

**Edit `lib/app/navigation/tab_scaffold.dart`**

Replace:

```dart
import 'package:energy_clock/app/navigation/app_tab_bar.dart';
```

With:

```dart
import 'package:energy_clock/app/navigation/app_tab_bar.dart';
import 'package:energy_clock/app/navigation/clock_tab.dart';
```

**Edit `lib/app/navigation/tab_scaffold.dart`**

Replace:

```dart
import 'package:energy_clock/features/calendar/calendar_screen.dart';
import 'package:energy_clock/features/clock/clock_screen.dart';
```

With:

```dart
import 'package:energy_clock/features/calendar/calendar_screen.dart';
```

**Edit `lib/app/navigation/tab_scaffold.dart`**

Replace:

```dart
    0 => const ClockScreen(),
```

With:

```dart
    0 => const ClockTab(),
```

- [ ] **Step 4: Run the tests, the analyzer and the whole suite**

```bash
# expect: PASS — 8 + 26 + 4 new tests pass; the shell, onboarding and every earlier test stay green
flutter test test/features/session/session_layout_test.dart test/features/session/session_screen_test.dart test/app/clock_tab_test.dart && flutter analyze && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/session lib/app/navigation test/features/session test/app
git commit -m "feat: session screen, shown in the Clock tab while a session runs

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Start a session from the Now card and the detail sheet

The Step 1 spec promised this button for Step 2. It appears in two places:

- **The Now card**, on the running event or the next one, as a pill beside the text: dark with light text on a neutral card; on a tone-coloured card the tone's own text colour as the fill and the tone colour as the text, so the pair keeps the contrast the tone palette already guarantees. It is at least 44 pt tall. Tapping the rest of the card still opens the detail sheet. The one-row card (short screens, large text) leaves it out, because the card opens the sheet, which has it. VoiceOver gets a **"Start session" custom action** on the card (the card is one merged node, so a nested button would be invisible to it). An event whose session is finished shows a **Done** label in its place.
- **The detail sheet**, as the main button above Edit. A finished event shows "Completed" and no Start.

Both go through `startSessionForEvent`, which starts the session, gives a light haptic, and shows a message if another session is somehow already running. `canStartSession` is the rule: the event must be planned and on today.

The four Clock screen goldens change, because the Now card in them now has a Start button. They are regenerated and **must be looked at**.

**Files:**
- Create: `lib/features/clock/widgets/start_session.dart`
- Replace: `lib/features/clock/widgets/now_card.dart`, `lib/features/clock/widgets/event_detail_sheet.dart`, `lib/features/clock/clock_screen.dart`
- Test: `test/features/clock/start_session_test.dart`, `test/app/clock_tab_start_test.dart`, `test/features/clock/now_card_start_golden_test.dart`
- Update: the four `test/features/clock/goldens/clock_*.png`; create three `now_card_*` goldens

**Interfaces:**
- Consumes: `sessionRepositoryProvider`, `SessionAlreadyRunningException`, `SessionEventMissingException`, `EventStatus`, `ClockTab`, `SessionScreen`.
- Produces: `canStartSession(CalendarEvent, DateTime now): bool`; `startSessionForEvent(BuildContext, WidgetRef, CalendarEvent): Future<bool>`; `NowCard({…, void Function(CalendarEvent)? onStartSession})`. Widget key `detail-start-session`.

- [ ] **Step 1: Write the failing tests**

**Create `test/features/clock/start_session_test.dart`**

```dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/event_detail_sheet.dart';
import 'package:energy_clock/features/clock/widgets/now_card.dart';
import 'package:energy_clock/features/clock/widgets/start_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  final today = DateTime(2026, 10, 7);
  final now = DateTime(2026, 10, 7, 10, 30);

  CalendarEvent event({
    DateTime? date,
    EventStatus status = EventStatus.planned,
  }) => CalendarEvent(
    id: 1,
    seriesId: null,
    date: date ?? today,
    title: 'Deep work',
    tone: Tone.focus,
    range: const MinuteRange(540, 720),
    status: status,
  );

  group('canStartSession', () {
    test('a planned event today can be started', () {
      expect(canStartSession(event(), now), isTrue);
    });

    test('an event that is already done cannot', () {
      expect(
        canStartSession(event(status: EventStatus.completed), now),
        isFalse,
      );
    });

    test('a skipped event cannot', () {
      expect(canStartSession(event(status: EventStatus.skipped), now), isFalse);
    });

    test('a future day cannot', () {
      expect(canStartSession(event(date: DateTime(2026, 10, 8)), now), isFalse);
    });

    test('a past day cannot', () {
      expect(canStartSession(event(date: DateTime(2026, 10, 6)), now), isFalse);
    });

    test('uses the given time, so late on the day still counts as today', () {
      expect(canStartSession(event(), DateTime(2026, 10, 7, 23, 59)), isTrue);
      expect(canStartSession(event(), DateTime(2026, 10, 8, 0, 1)), isFalse);
    });
  });

  group('the Now card', () {
    late ClockHarness harness;
    CalendarEvent? opened;
    CalendarEvent? started;

    setUp(() {
      harness = ClockHarness(); // Wednesday 7 October 2026, 10:30
      opened = null;
      started = null;
    });

    tearDown(() {
      harness.dispose();
    });

    Future<int> add(
      String title,
      int start,
      int end, {
      Tone tone = Tone.focus,
    }) => harness.repository.createEvent(
      day: today,
      title: title,
      tone: tone,
      range: MinuteRange(start, end),
    );

    Future<void> show(
      WidgetTester tester, {
      bool compact = false,
      bool withStart = true,
    }) async {
      await tester.pumpWidget(
        harness.app(
          UnconstrainedBox(
            constrainedAxis: Axis.horizontal,
            alignment: Alignment.topCenter,
            child: NowCard(
              compact: compact,
              onOpenEvent: (e) => opened = e,
              onStartSession: withStart ? (e) => started = e : null,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('a running event has a Start button that starts it', (
      tester,
    ) async {
      final id = await add('Deep work', 540, 720);
      await show(tester);

      expect(find.text(Strings.sessionStartShort), findsOneWidget);
      await tester.tap(find.text(Strings.sessionStartShort));

      expect(started?.id, id);
      expect(opened, isNull);
    });

    testWidgets('tapping the rest of the card still opens the details', (
      tester,
    ) async {
      final id = await add('Deep work', 540, 720);
      await show(tester);

      await tester.tap(find.text('Deep work'));

      expect(opened?.id, id);
      expect(started, isNull);
    });

    testWidgets('the next event has one too', (tester) async {
      final id = await add('Lunch walk', 750, 795, tone: Tone.life);
      await show(tester);

      await tester.tap(find.text(Strings.sessionStartShort));

      expect(started?.id, id);
    });

    testWidgets('the button is at least 44 points tall', (tester) async {
      await add('Deep work', 540, 720);
      await show(tester);

      final size = tester.getSize(
        find
            .ancestor(
              of: find.text(Strings.sessionStartShort),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('without a callback there is no button', (tester) async {
      await add('Deep work', 540, 720);
      await show(tester, withStart: false);

      expect(find.text(Strings.sessionStartShort), findsNothing);
    });

    testWidgets('the one-row card leaves it out', (tester) async {
      await add('Deep work', 540, 720);
      await show(tester, compact: true);

      expect(find.text(Strings.sessionStartShort), findsNothing);
    });

    testWidgets('an event whose session is finished says Done instead', (
      tester,
    ) async {
      final id = await add('Deep work', 540, 720);
      harness.repository.setStatus(id, EventStatus.completed);
      await show(tester);

      expect(find.text(Strings.sessionStartShort), findsNothing);
      expect(find.text(Strings.sessionDone), findsOneWidget);
    });

    testWidgets('a future day has no Start button', (tester) async {
      harness.container
          .read(selectedDateProvider.notifier)
          .select(DateTime(2026, 10, 8));
      await add('Deep work', 540, 720);
      await show(tester);

      expect(find.text(Strings.sessionStartShort), findsNothing);
    });

    testWidgets('VoiceOver gets a Start session action', (tester) async {
      final handle = tester.ensureSemantics();
      final id = await add('Deep work', 540, 720);
      await show(tester);

      final node = find.semantics.byLabel(RegExp('^Now:'));
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('^Now:'))),
        matchesSemantics(
          label: 'Now: Deep work, Focus, 1 hour 30 minutes left',
          isButton: true,
          hasTapAction: true,
          customActions: const [
            CustomSemanticsAction(label: Strings.sessionStart),
          ],
        ),
      );

      tester.semantics.performAction(
        node,
        SemanticsAction.customAction,
        args: CustomSemanticsAction.getIdentifier(
          const CustomSemanticsAction(label: Strings.sessionStart),
        ),
      );
      expect(started?.id, id);
      handle.dispose();
    });

    testWidgets('a completed event is spoken as completed', (tester) async {
      final handle = tester.ensureSemantics();
      final id = await add('Deep work', 540, 720);
      harness.repository.setStatus(id, EventStatus.completed);
      await show(tester);

      expect(
        find.bySemanticsLabel(RegExp('^Now: Deep work.*, completed\$')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('the detail sheet', () {
    late ClockHarness harness;

    setUp(() {
      harness = ClockHarness();
    });

    tearDown(() {
      harness.dispose();
    });

    Future<CalendarEvent> seed({
      DateTime? day,
      EventStatus status = EventStatus.planned,
    }) async {
      final id = await harness.repository.createEvent(
        day: day ?? today,
        title: 'Deep work',
        tone: Tone.focus,
        range: const MinuteRange(540, 720),
      );
      if (status != EventStatus.planned) {
        harness.repository.setStatus(id, status);
      }
      return harness.repository.eventById(id)!;
    }

    Future<void> open(
      WidgetTester tester,
      CalendarEvent event, {
      bool readOnly = false,
    }) async {
      await tester.pumpWidget(
        harness.app(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => EventDetailSheet.show(
                context,
                event: event,
                readOnly: readOnly,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets("today's planned event can be started from the sheet", (
      tester,
    ) async {
      final event = await seed();
      await open(tester, event);

      await tester.tap(find.byKey(const ValueKey('detail-start-session')));
      await tester.pumpAndSettle();

      expect(harness.sessions.running?.eventId, event.id);
      expect(find.byType(EventDetailSheet), findsNothing);
    });

    testWidgets('Start sits above Edit', (tester) async {
      await open(tester, await seed());

      final start = tester.getTopLeft(find.text(Strings.sessionStart)).dy;
      final edit = tester.getTopLeft(find.text(Strings.edit)).dy;
      expect(start, lessThan(edit));
    });

    testWidgets('a future day has no Start button', (tester) async {
      await open(tester, await seed(day: DateTime(2026, 10, 8)));
      expect(find.text(Strings.sessionStart), findsNothing);
    });

    testWidgets('a read-only sheet has none either', (tester) async {
      await open(tester, await seed(), readOnly: true);
      expect(find.text(Strings.sessionStart), findsNothing);
    });

    testWidgets('a finished event shows Completed and no Start', (
      tester,
    ) async {
      await open(tester, await seed(status: EventStatus.completed));

      expect(find.text(Strings.eventCompleted), findsOneWidget);
      expect(find.text(Strings.sessionStart), findsNothing);
    });

    testWidgets('while another session runs the sheet says so', (tester) async {
      final event = await seed();
      final other = await harness.repository.createEvent(
        day: today,
        title: 'Email',
        tone: Tone.inbox,
        range: const MinuteRange(900, 930),
      );
      await harness.sessions.start(eventId: other);
      await open(tester, event);

      await tester.tap(find.byKey(const ValueKey('detail-start-session')));
      await tester.pumpAndSettle();

      expect(find.text(Strings.sessionAlreadyRunning), findsOneWidget);
    });
  });
}
```

**Create `test/app/clock_tab_start_test.dart`**

```dart
import 'package:energy_clock/app/navigation/clock_tab.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/clock_screen.dart';
import 'package:energy_clock/features/session/session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/clock_harness.dart';
import '../support/dial_pump.dart';

/// The whole loop through the Clock tab: Start on the Now card, the session
/// screen, and back to the day with the event done.
void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Future<int> addEvent() => harness.repository.createEvent(
    day: DateTime(2026, 10, 7),
    title: 'Deep work',
    tone: Tone.focus,
    range: const MinuteRange(540, 720),
  );

  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(harness.app(const ClockTab()));
    await pumpDial(tester);
  }

  testWidgets('pressing Start on the Now card starts a session', (
    tester,
  ) async {
    await addEvent(); // 09:00-12:00, running at the harness's 10:30
    await show(tester);

    await tester.tap(find.text(Strings.sessionStartShort));
    await pumpDial(tester);

    expect(find.byType(SessionScreen), findsOneWidget);
    expect(find.byType(ClockScreen), findsNothing);
    expect(find.text('Deep work'), findsOneWidget);
    expect(harness.sessions.running, isNotNull);
  });

  testWidgets('finishing returns to the day, with the event done', (
    tester,
  ) async {
    await addEvent();
    await show(tester);
    await tester.tap(find.text(Strings.sessionStartShort));
    await pumpDial(tester);

    await tester.tap(find.byKey(const ValueKey('session-finish')));
    await pumpDial(tester);

    expect(find.byType(ClockScreen), findsOneWidget);
    expect(find.byType(SessionScreen), findsNothing);
    expect(find.text(Strings.sessionDone), findsOneWidget);
    expect(find.text(Strings.sessionStartShort), findsNothing);
  });
}
```

- [ ] **Step 2: Run them to see them fail**

```bash
# expect: FAIL — 'package:energy_clock/features/clock/widgets/start_session.dart' does not exist, and `NowCard` has no `onStartSession`
flutter test test/features/clock/start_session_test.dart test/app/clock_tab_start_test.dart
```

- [ ] **Step 3: Implement**

**Create `lib/features/clock/widgets/start_session.dart`**

```dart
import 'dart:async';

import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/session_repository.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether a session can be started on [event] at [now]: it still has to be
/// done, and it belongs to today. A past day is read-only, and a session is
/// for what you are doing now, not for a day that has not come yet.
bool canStartSession(CalendarEvent event, DateTime now) =>
    event.status == EventStatus.planned && event.date == startOfDay(now);

/// Starts a session on [event]. Returns true when it started; the session
/// screen then takes the Clock tab's place by itself. Used by the Now card and
/// the detail sheet.
Future<bool> startSessionForEvent(
  BuildContext context,
  WidgetRef ref,
  CalendarEvent event,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(sessionRepositoryProvider).start(eventId: event.id);
    unawaited(HapticFeedback.mediumImpact());
    return true;
  } on SessionAlreadyRunningException {
    messenger.showSnackBar(
      const SnackBar(content: Text(Strings.sessionAlreadyRunning)),
    );
  } on SessionEventMissingException {
    messenger.showSnackBar(
      const SnackBar(content: Text(Strings.sessionStartFailed)),
    );
  }
  return false;
}
```

**Replace `lib/features/clock/widgets/now_card.dart`**

```dart
import 'dart:math' as math;

import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:energy_clock/features/clock/model/now_status.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/start_session.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:energy_clock/shared/widgets/press_scale.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The card under the dial. A running event fills it with the tone's colour;
/// otherwise it is neutral and says what is next, invites you to plan, or
/// summarises another day. Tapping opens the running or next event.
class NowCard extends ConsumerWidget {
  const NowCard({
    required this.onOpenEvent,
    this.onStartSession,
    this.compact = false,
    super.key,
  });

  /// Height at normal text size.
  static const double height = 96;

  /// The height to budget for the full card at [textScale]. Its four lines of
  /// text (caption, title, time left, progress bar) outgrow [height] as soon as
  /// text is larger than normal: about 98 pt at 115% and 107 pt at 130%.
  static double heightFor(double textScale) =>
      math.max(height, 36 + 56 * textScale);

  /// The height to budget for the one-row variant at [textScale].
  static double compactHeightFor(double textScale) => 24 + 28 * textScale;

  final void Function(CalendarEvent event) onOpenEvent;

  /// Called when Start is pressed on the running or next event. Null leaves
  /// the Start button out. The one-row variant never has it: the card opens the
  /// detail sheet, which does.
  final void Function(CalendarEvent event)? onStartSession;

  /// One row: the title and, for a running or next event, a short time. Used
  /// on short screens and at large text sizes.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDateProvider);
    final now = ref.watch(clockProvider);
    final events =
        ref.watch(dayEventsProvider).valueOrNull ?? const <CalendarEvent>[];
    final status = computeNowStatus(
      events: events,
      selectedDay: selected,
      now: now,
    );
    final view = _describe(context, status, selected);
    final theme = Theme.of(context);
    final colors = context.appColors;

    final primary = view.foreground ?? colors.ink;
    final secondary = view.foreground ?? colors.muted;

    final body = compact
        ? Row(
            children: [
              Expanded(
                child: Text(
                  view.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall!.copyWith(color: primary),
                ),
              ),
              if (view.compactDetail != null) ...[
                const SizedBox(width: AppSpacing.md),
                Text(
                  view.compactDetail!,
                  style: theme.textTheme.labelLarge!.copyWith(color: secondary),
                ),
              ],
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (view.caption != null)
                Text(
                  view.caption!,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color:
                        view.foreground?.withValues(alpha: 0.85) ??
                        colors.muted,
                  ),
                ),
              Text(
                view.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium!.copyWith(color: primary),
              ),
              if (view.detail != null)
                Text(
                  view.detail!,
                  style: theme.textTheme.labelLarge!.copyWith(
                    color: view.foreground ?? colors.muted,
                  ),
                ),
              if (view.progress != null) ...[
                const SizedBox(height: 6),
                _ProgressBar(progress: view.progress!, color: primary),
              ],
            ],
          );

    final event = view.event;
    final canStart =
        !compact &&
        event != null &&
        onStartSession != null &&
        canStartSession(event, now);
    final isDone =
        !compact && event != null && event.status == EventStatus.completed;

    final Widget? trailing = canStart
        ? _StartButton(
            fill: view.foreground ?? colors.ink,
            foreground: view.fill ?? colors.onInk,
            onTap: () => onStartSession!(event),
          )
        : isDone
        ? _DoneLabel(color: primary)
        : null;

    final card = AppCard(
      color: view.fill,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      onTap: event == null ? null : () => onOpenEvent(event),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: compact ? 0 : height - 24),
        child: Align(
          alignment: Alignment.centerLeft,
          child: trailing == null
              ? body
              : Row(
                  children: [
                    Expanded(child: body),
                    const SizedBox(width: AppSpacing.md),
                    trailing,
                  ],
                ),
        ),
      ),
    );

    if (view.semanticsLabel == null) return MergeSemantics(child: card);
    return Semantics(
      button: true,
      label: isDone
          ? '${view.semanticsLabel}${Strings.nowCompletedSuffix}'
          : view.semanticsLabel,
      excludeSemantics: true,
      onTap: event == null ? null : () => onOpenEvent(event),
      customSemanticsActions: canStart
          ? {
              const CustomSemanticsAction(label: Strings.sessionStart): () =>
                  onStartSession!(event),
            }
          : null,
      child: card,
    );
  }

  _NowView _describe(
    BuildContext context,
    NowStatus status,
    DateTime selected,
  ) {
    final tones = context.toneColors;
    return switch (status) {
      NowActive(
        :final event,
        :final minutesLeft,
        :final progress,
        :final overlappingCount,
      ) =>
        _NowView(
          fill: tones.fillFor(event.tone),
          foreground: tones.labelFor(event.tone),
          caption: overlappingCount > 0
              ? '${event.tone.label} · ${Strings.nowOverlapping(overlappingCount)}'
              : event.tone.label,
          title: event.title,
          detail:
              '${Strings.nowTimeLeft(formatDurationMinutes(minutesLeft))} · '
              '${Strings.nowUntil(formatMinuteOfDay(event.endMinute))}',
          compactDetail: Strings.nowTimeLeft(
            formatDurationMinutes(minutesLeft),
          ),
          progress: progress,
          event: event,
          semanticsLabel: Strings.nowSemantics(
            event.title,
            event.tone.label,
            spokenDurationMinutes(minutesLeft),
          ),
        ),
      NowNext(:final event, :final minutesUntil) => _NowView(
        caption: Strings.nowNextUp,
        title: event.title,
        detail: Strings.nowStartsAt(
          formatMinuteOfDay(event.startMinute),
          formatDurationMinutes(minutesUntil),
        ),
        compactDetail: formatDurationMinutes(minutesUntil),
        event: event,
        semanticsLabel: Strings.nextSemantics(
          event.title,
          event.tone.label,
          spokenDurationMinutes(minutesUntil),
        ),
      ),
      NowFree() => const _NowView(
        title: Strings.emptyDayTitle,
        detail: Strings.emptyDayHint,
      ),
      NowDone(:final eventCount, :final plannedMinutes) => _NowView(
        title: Strings.nowDoneTitle,
        detail: Strings.plannedSummary(
          eventCount,
          formatDurationMinutes(plannedMinutes),
        ),
      ),
      DaySummary(:final eventCount, :final plannedMinutes, :final isPast) =>
        isPast
            ? _NowView(
                caption: Strings.readOnlyChip,
                title: eventCount == 0
                    ? Strings.pastNothingPlanned
                    : Strings.pastSummary(
                        eventCount,
                        formatDurationMinutes(plannedMinutes),
                      ),
              )
            : _NowView(
                title: Strings.dayCountTitle(
                  DateFormat('EEEE').format(selected),
                  eventCount,
                ),
                detail: Strings.plannedDuration(
                  formatDurationMinutes(plannedMinutes),
                ),
              ),
    };
  }
}

/// Everything the card needs to draw one state.
class _NowView {
  const _NowView({
    required this.title,
    this.caption,
    this.detail,
    this.compactDetail,
    this.fill,
    this.foreground,
    this.progress,
    this.event,
    this.semanticsLabel,
  });

  final String title;
  final String? caption;
  final String? detail;

  /// The short text beside the title in the one-row variant.
  final String? compactDetail;

  /// Null keeps the card neutral.
  final Color? fill;
  final Color? foreground;
  final double? progress;

  /// The event a tap opens, if any.
  final CalendarEvent? event;
  final String? semanticsLabel;
}

/// The pill on the card that starts a session. At least 44 pt tall.
class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.fill,
    required this.foreground,
    required this.onTap,
  });

  final Color fill;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.play_fill, size: 14, color: foreground),
                const SizedBox(width: 6),
                Text(
                  Strings.sessionStartShort,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge!.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stands where Start would, for an event whose session is finished.
class _DoneLabel extends StatelessWidget {
  const _DoneLabel({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(CupertinoIcons.checkmark_circle_fill, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          Strings.sessionDone,
          style: Theme.of(context).textTheme.labelLarge!.copyWith(color: color),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: SizedBox(
        height: 4,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: color.withValues(alpha: 0.25)),
            ),
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Replace `lib/features/clock/widgets/event_detail_sheet.dart`**

```dart
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/delete_event.dart';
import 'package:energy_clock/features/clock/widgets/event_sheet.dart';
import 'package:energy_clock/features/clock/widgets/start_session.dart';
import 'package:energy_clock/shared/widgets/app_button.dart';
import 'package:energy_clock/shared/widgets/tone_chip.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EventDetailSheet extends ConsumerWidget {
  const EventDetailSheet({
    required this.event,
    required this.readOnly,
    super.key,
  });

  final CalendarEvent event;
  final bool readOnly;

  static Future<void> show(
    BuildContext context, {
    required CalendarEvent event,
    required bool readOnly,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => EventDetailSheet(event: event, readOnly: readOnly),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final deleted = await confirmAndDeleteEvent(context, ref, event);
    if (deleted && context.mounted) Navigator.of(context).pop();
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final started = await startSessionForEvent(context, ref, event);
    if (started) navigator.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final canStart =
        !readOnly && canStartSession(event, ref.watch(clockProvider));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xs,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ToneChip(tone: event.tone),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(event.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            formatMinuteRange(event.startMinute, event.endMinute),
            style: theme.textTheme.bodyLarge,
          ),
          Text(
            formatDurationMinutes(event.range.durationMinutes),
            style: theme.textTheme.bodySmall,
          ),
          if (event.status == EventStatus.completed) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  CupertinoIcons.checkmark_circle_fill,
                  size: 16,
                  color: colors.muted,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(Strings.eventCompleted, style: theme.textTheme.bodySmall),
              ],
            ),
          ],
          if (!readOnly) ...[
            const SizedBox(height: AppSpacing.xxl),
            if (canStart) ...[
              AppButton(
                key: const ValueKey('detail-start-session'),
                label: Strings.sessionStart,
                onPressed: () => _start(context, ref),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            AppButton(
              label: Strings.edit,
              variant: AppButtonVariant.secondary,
              onPressed: () {
                final navigator = Navigator.of(context);
                final target = event;
                navigator.pop();
                EventSheet.show(
                  navigator.context,
                  day: target.date,
                  initialRange: target.range,
                  existing: target,
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: Strings.delete,
              variant: AppButtonVariant.destructive,
              onPressed: () => _delete(context, ref),
            ),
          ],
        ],
      ),
    );
  }
}
```

**Replace `lib/features/clock/clock_screen.dart`**

```dart
import 'dart:async';

import 'package:energy_clock/app/navigation/tab_bar_inset.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/features/clock/clock_layout.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/clock_header.dart';
import 'package:energy_clock/features/clock/widgets/day_load_bar.dart';
import 'package:energy_clock/features/clock/widgets/delete_event.dart';
import 'package:energy_clock/features/clock/widgets/dial_view.dart';
import 'package:energy_clock/features/clock/widgets/event_detail_sheet.dart';
import 'package:energy_clock/features/clock/widgets/event_sheet.dart';
import 'package:energy_clock/features/clock/widgets/now_card.dart';
import 'package:energy_clock/features/clock/widgets/start_session.dart';
import 'package:energy_clock/features/clock/widgets/todays_plan_list.dart';
import 'package:energy_clock/features/clock/widgets/week_strip.dart';
import 'package:energy_clock/shared/layout/content_width.dart';
import 'package:energy_clock/shared/layout/window_class.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The largest outer radius the dial gets on a wide window.
const double _wideDialMaxRadius = 340;

/// The Clock tab. Narrow and medium windows stack everything in one
/// non-scrolling column (a medium window centres it at 560 pt). A wide window
/// uses two panes: the dial on the left; the header, week strip, Now card,
/// day-load bar and Today's plan list on the right.
class ClockScreen extends ConsumerWidget {
  const ClockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDateProvider);
    final now = ref.watch(clockProvider);
    final events = ref.watch(dayEventsProvider);
    final readOnly = isPastDay(selected, now: now);
    final inset = TabBarInset.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final windowClass = context.windowClass;
    final hasEvents = events.valueOrNull?.isNotEmpty ?? false;

    void openCreate(MinuteRange range) =>
        EventSheet.show(context, day: selected, initialRange: range);

    void openDetail(CalendarEvent event) =>
        EventDetailSheet.show(context, event: event, readOnly: readOnly);

    void startSession(CalendarEvent event) =>
        unawaited(startSessionForEvent(context, ref, event));

    void openEdit(CalendarEvent event) => EventSheet.show(
      context,
      day: event.date,
      initialRange: event.range,
      existing: event,
    );

    Widget dialArea({double? maxRadius}) => events.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => const Center(child: Text(Strings.loadFailed)),
      data: (dayEvents) => DialView(
        events: dayEvents,
        day: selected,
        readOnly: readOnly,
        maxRadius: maxRadius,
        onCreateRequested: openCreate,
        onEventTapped: openDetail,
        onEditRequested: openEdit,
        onDeleteRequested: (event) =>
            confirmAndDeleteEvent(context, ref, event),
        onMoveRequested: (event, range) async {
          try {
            await ref
                .read(eventRepositoryProvider)
                .moveEvent(id: event.id, day: selected, range: range);
          } on RingOverflowException {
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text(Strings.ringOverflow)));
          }
        },
      ),
    );

    if (windowClass == WindowClass.wide) {
      final width = MediaQuery.sizeOf(context).width;
      final paneWidth = (width * 0.36).clamp(340.0, 440.0).toDouble();
      final largeText = textScale > ClockLayoutPlan.largeTextScale;

      return Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.xxl, 0, AppSpacing.xxl, inset),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: dialArea(maxRadius: _wideDialMaxRadius)),
            const SizedBox(width: AppSpacing.xxl),
            SizedBox(
              width: paneWidth,
              child: Column(
                children: [
                  ClockHeader(
                    onAdd: () => openCreate(const MinuteRange(540, 600)),
                  ),
                  WeekStrip(showDots: !largeText),
                  const SizedBox(height: ClockLayoutPlan.gap),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: NowCard(
                      compact: largeText,
                      onOpenEvent: openDetail,
                      onStartSession: startSession,
                    ),
                  ),
                  if (hasEvents && !largeText) ...[
                    const SizedBox(height: ClockLayoutPlan.gap),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: DayLoadBar(),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: TodaysPlanList(onOpenEvent: openDetail),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ContentWidth(
      maxWidth: windowClass == WindowClass.narrow
          ? double.infinity
          : ContentWidths.column,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final plan = ClockLayoutPlan.forHeight(
            constraints.maxHeight - inset,
            textScale: textScale,
            hasDayLoad: hasEvents,
          );

          return Padding(
            padding: EdgeInsets.only(bottom: inset),
            child: Column(
              children: [
                ClockHeader(
                  showDate: plan.showHeaderDate,
                  onAdd: () => openCreate(const MinuteRange(540, 600)),
                ),
                WeekStrip(showDots: plan.showWeekDots),
                const SizedBox(height: ClockLayoutPlan.gap),
                Expanded(child: dialArea()),
                const SizedBox(height: ClockLayoutPlan.gap),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: NowCard(
                    compact: plan.compactNowCard,
                    onOpenEvent: openDetail,
                    onStartSession: startSession,
                  ),
                ),
                if (plan.showDayLoad) ...[
                  const SizedBox(height: ClockLayoutPlan.gap),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: DayLoadBar(),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Run the new tests and the analyzer**

```bash
# expect: PASS — 22 + 2 new tests pass
flutter test test/features/clock/start_session_test.dart test/app/clock_tab_start_test.dart && flutter analyze
```

- [ ] **Step 5: Run the whole suite and see only the four Clock screen goldens fail**

The Now card in those images now has a Start button, so they differ. Nothing else should fail.

```bash
# expect: FAIL — exactly four failures, all in test/features/clock/clock_screen_golden_test.dart (iPhone light, iPhone dark, iPad 11" portrait, iPad 11" landscape)
flutter test
```

- [ ] **Step 6: Regenerate those four goldens, and clear the failure folder the failing run left behind**

```bash
# expect: UPDATE
flutter test test/features/clock/clock_screen_golden_test.dart --update-goldens
rm -rf test/features/clock/failures
```

- [ ] **Step 7: Look at the four images**

```bash
# expect: MANUAL — in each, the Now card shows a dark "Start" pill on the right with the tone-coloured text, the card text is not cramped, and the rest of the screen is unchanged. The play icon draws as an empty box in the images only, because the Cupertino icon font does not load in tests; the tab icons do the same.
open test/features/clock/goldens/clock_iphone_light.png test/features/clock/goldens/clock_iphone_dark.png test/features/clock/goldens/clock_ipad_portrait_light.png test/features/clock/goldens/clock_ipad_landscape_light.png
```

- [ ] **Step 8: Add goldens for the other card states**

A running Inbox event with Start (light), the next event with Start (dark), and a finished event saying Done (light).

**Create `test/features/clock/now_card_start_golden_test.dart`**

```dart
// Golden images of the Now card with its Start button, and with Done in its
// place. The clock is fixed at Wednesday 7 October 2026, 10:30, animations are
// off, and `test/flutter_test_config.dart` loads Nunito.
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/event_status.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/widgets/now_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

const cardKey = ValueKey('now-card-start-golden');

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Future<int> add(String title, Tone tone, int start, int end) =>
      harness.repository.createEvent(
        day: DateTime(2026, 10, 7),
        title: title,
        tone: tone,
        range: MinuteRange(start, end),
      );

  Future<void> check(WidgetTester tester, ThemeData theme, String file) async {
    await tester.pumpWidget(
      harness.app(
        // Loose and top-left, with the card on unbounded height, so the image
        // is as tall as the card and no taller.
        Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: cardKey,
            child: Builder(
              builder: (context) => ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: 358,
                    child: UnconstrainedBox(
                      constrainedAxis: Axis.horizontal,
                      child: NowCard(
                        onOpenEvent: (_) {},
                        onStartSession: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        theme: theme,
        reduceMotion: true,
      ),
    );
    await tester.pump();
    await expectLater(find.byKey(cardKey), matchesGoldenFile('goldens/$file'));
  }

  testWidgets('a running Inbox event with Start, light', (tester) async {
    await add('Email and calls', Tone.inbox, 600, 660);
    await check(tester, AppTheme.light, 'now_card_start_inbox_light.png');
  });

  testWidgets('the next event with Start, dark', (tester) async {
    await add('Lunch walk', Tone.life, 750, 795);
    await check(tester, AppTheme.dark, 'now_card_start_next_dark.png');
  });

  testWidgets('a finished event says Done, light', (tester) async {
    final id = await add('Deep work', Tone.focus, 540, 720);
    harness.repository.setStatus(id, EventStatus.completed);
    await check(tester, AppTheme.light, 'now_card_done_light.png');
  });
}
```

```bash
# expect: UPDATE
flutter test test/features/clock/now_card_start_golden_test.dart --update-goldens
```

```bash
# expect: MANUAL — each image is the card at its natural height: orange with a dark Start pill; a dark neutral card with a light Start pill; a purple card with "Done" on the right
open test/features/clock/goldens/now_card_start_inbox_light.png test/features/clock/goldens/now_card_start_next_dark.png test/features/clock/goldens/now_card_done_light.png
```

- [ ] **Step 9: Run the whole suite**

```bash
# expect: PASS — analyzer clean; everything passes
flutter analyze && flutter test
```

- [ ] **Step 10: Commit**

```bash
git add lib/features/clock test/features/clock test/app/clock_tab_start_test.dart
git commit -m "feat: start a session from the Now card and the detail sheet

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 14: The layout matrix and goldens for the session screen

Step 1's rule for every later screen: check it at the eight window sizes. This task adds the session screen's version of the Clock matrix: **eight window sizes × four text sizes (100%, 130%, 200% and iOS's largest, 312%) × four states** (running, overtime, the recovery card, and the alerts-off banner), 128 cases. Each asserts no overflow exceptions, a ring between its minimum (200 pt) and its maximum for the window class, that every button can be scrolled into view, and — separately, at normal text size — that **the whole screen fits without scrolling** at all eight sizes, with the buttons beside the ring on wide windows.

Seven goldens pin how it looks: running (light), overtime (dark), paused Life (light), the recovery card (light), a small iPhone (dark), an iPad 13" landscape two-pane (dark) and an iPad 11" portrait (light). They run inside the real tab shell, so the tab bar shows.

These tests pin behaviour built in Task 12, so they pass on the first run; what needs a person is looking at the goldens.

**Files:**
- Test: `test/features/session/session_layout_matrix_test.dart`, `test/features/session/session_screen_golden_test.dart`
- Create (generated): `test/features/session/goldens/session_*.png` (7 images)

- [ ] **Step 1: Add the layout matrix**

**Create `test/features/session/session_layout_matrix_test.dart`**

```dart
import 'package:energy_clock/app/navigation/clock_tab.dart';
import 'package:energy_clock/app/navigation/tab_bar_inset.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/session/session_alerts.dart';
import 'package:energy_clock/features/session/session_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';
import '../../support/dial_pump.dart';

/// The window sizes the Clock screen is tested at, and so the session screen,
/// which takes the same tab's place. The flag says whether it is a wide window,
/// which gets two panes.
const sizes = <String, (Size, bool)>{
  'iPhone SE': (Size(375, 667), false),
  'iPhone 17 Pro': (Size(402, 874), false),
  'iPad mini portrait': (Size(744, 1133), false),
  'iPad 11" portrait': (Size(834, 1194), false),
  'iPad 11" landscape': (Size(1194, 834), true),
  'iPad 13" portrait': (Size(1032, 1376), true),
  'iPad 13" landscape': (Size(1376, 1032), true),
  'narrow Split View': (Size(320, 1000), false),
};

/// What the screen is showing. Each changes the height of the content.
enum _State { running, overtime, recovering, alertsOffBanner }

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness(); // Wednesday 7 October 2026, 10:30
  });

  tearDown(() {
    harness.dispose();
  });

  /// Opens the app with a session left running, as a killed app would. Unless
  /// the state is [_State.recovering], the recovery card is then resumed so the
  /// ordinary controls show.
  Future<void> open(WidgetTester tester, _State state, double textScale) async {
    final eventId = await harness.repository.createEvent(
      day: DateTime(2026, 10, 7),
      title: 'A deep work session with a rather long title',
      tone: Tone.focus,
      range: const MinuteRange(600, 660),
    );
    harness.sessions.seedRunning(
      eventId: eventId,
      // Started at 09:00 it is long past its end at 10:30: overtime.
      startedAt: state == _State.overtime
          ? DateTime(2026, 10, 7, 9, 0)
          : DateTime(2026, 10, 7, 10, 20),
    );
    if (state == _State.alertsOffBanner) {
      harness.notifications
        ..enabled = false
        ..grantsRequest = false;
    }

    await tester.pumpWidget(
      harness.app(
        const TabBarInset(height: 84, child: ClockTab()),
        textScale: textScale,
      ),
    );
    await pumpDial(tester);

    if (state != _State.recovering) {
      final resume = find.byKey(const ValueKey('recovery-resume'));
      await tester.ensureVisible(resume);
      await tester.tap(resume);
      await pumpDial(tester);
    }
    if (state == _State.alertsOffBanner) {
      // The banner shows once an alert has been tried and refused.
      await harness.container
          .read(sessionAlertsProvider.notifier)
          .sync(harness.sessions.running);
      await pumpDial(tester);
    }
  }

  for (final entry in sizes.entries) {
    final (size, wide) = entry.value;
    // 3.12 is Dynamic Type's largest accessibility size on iOS.
    for (final textScale in const [1.0, 1.3, 2.0, 3.12]) {
      for (final state in _State.values) {
        testWidgets(
          '${entry.key} (${size.width.toInt()} x ${size.height.toInt()}), '
          'text ${(textScale * 100).toInt()}%, ${state.name}',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);

            await open(tester, state, textScale);

            expect(tester.takeException(), isNull);

            final ring = tester.getRect(
              find.byKey(const ValueKey('session-ring')),
            );
            expect(
              ring.shortestSide,
              greaterThanOrEqualTo(SessionLayoutPlan.minRing),
              reason: 'the ring is never smaller than its minimum',
            );
            expect(ring.left, greaterThanOrEqualTo(0));
            expect(ring.right, lessThanOrEqualTo(size.width));
            expect(
              ring.shortestSide,
              lessThanOrEqualTo(
                wide
                    ? SessionLayoutPlan.maxWideRing
                    : SessionLayoutPlan.maxRing,
              ),
            );

            // Every button can be reached by scrolling.
            final reachable = state == _State.recovering
                ? const ['recovery-resume', 'recovery-close-out']
                : const [
                    'session-pause',
                    'session-add-5',
                    'session-add-15',
                    'session-finish',
                    'session-abandon',
                  ];
            for (final key in reachable) {
              final finder = find.byKey(ValueKey(key));
              expect(finder, findsOneWidget, reason: key);
              await tester.ensureVisible(finder);
              await tester.pump();
              expect(tester.takeException(), isNull);
            }
          },
        );
      }
    }
  }

  group('without scrolling at normal text size', () {
    for (final entry in sizes.entries) {
      final (size, wide) = entry.value;
      testWidgets('${entry.key}: the whole screen fits', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await open(tester, _State.running, 1);

        final abandon = tester.getRect(
          find.byKey(const ValueKey('session-abandon')),
        );
        final pause = tester.getRect(
          find.byKey(const ValueKey('session-pause')),
        );
        final title = tester.getRect(
          find.byKey(const ValueKey('session-title')),
        );
        // The floating tab bar covers the bottom 84 points.
        expect(abandon.bottom, lessThanOrEqualTo(size.height - 84));
        expect(title.top, greaterThanOrEqualTo(0));
        if (wide) {
          final ring = tester.getRect(
            find.byKey(const ValueKey('session-ring')),
          );
          expect(pause.left, greaterThan(ring.right));
        }
      });
    }
  });
}
```

- [ ] **Step 2: Run it**

```bash
# expect: PASS — 136 tests pass
flutter test test/features/session/session_layout_matrix_test.dart
```

- [ ] **Step 3: Add the goldens and generate them**

**Create `test/features/session/session_screen_golden_test.dart`**

```dart
// Golden images of the session screen inside the real tab shell: the countdown
// running, in overtime, paused, a session found after a kill, and the wide
// iPad layout. The clock is fixed at Wednesday 7 October 2026, 10:30,
// animations are off, and `test/flutter_test_config.dart` loads Nunito, so
// every image is deterministic and shows real text.
import 'package:energy_clock/app/navigation/tab_scaffold.dart';
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';
import '../../support/dial_pump.dart';

const screenKey = ValueKey('session-screen-golden');

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  /// Opens the shell, starts a session on a new event and moves the clock
  /// [secondsIn] seconds after the 10:30 start. [leftover] makes it a session
  /// found at launch instead.
  Future<void> check(
    WidgetTester tester, {
    required Size size,
    required ThemeData theme,
    required String file,
    String title = 'Deep work',
    Tone tone = Tone.focus,
    int begin = 600,
    int end = 690,
    int secondsIn = 0,
    bool pause = false,
    bool leftover = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final eventId = await harness.repository.createEvent(
      day: DateTime(2026, 10, 7),
      title: title,
      tone: tone,
      range: MinuteRange(begin, end),
    );
    if (leftover) {
      harness.sessions.seedRunning(
        eventId: eventId,
        startedAt: DateTime(2026, 10, 7, 10, 10),
        plannedSeconds: (end - begin) * 60,
      );
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: RepaintBoundary(
          key: screenKey,
          child: MaterialApp(
            theme: theme,
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const TabScaffold(),
          ),
        ),
      ),
    );
    await pumpDial(tester);

    if (!leftover) {
      final sessionId = await harness.sessions.start(eventId: eventId);
      await pumpDial(tester);
      harness.clock.set(
        DateTime(2026, 10, 7, 10, 30).add(Duration(seconds: secondsIn)),
      );
      if (pause) {
        await harness.sessions.pause(sessionId);
      }
      await pumpDial(tester);
    }
    await expectLater(
      find.byKey(screenKey),
      matchesGoldenFile('goldens/$file'),
    );
  }

  testWidgets('iPhone, running a Focus session, light', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.light,
      file: 'session_iphone_running_light.png',
      secondsIn: 23 * 60 + 17,
    );
  });

  testWidgets('iPhone, overtime, dark', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.dark,
      file: 'session_iphone_overtime_dark.png',
      title: 'Email and calls',
      tone: Tone.inbox,
      begin: 600,
      end: 645,
      secondsIn: 45 * 60 + 125,
    );
  });

  testWidgets('iPhone, paused Life session, light', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.light,
      file: 'session_iphone_paused_light.png',
      title: 'Lunch walk',
      tone: Tone.life,
      begin: 600,
      end: 645,
      secondsIn: 12 * 60,
      pause: true,
    );
  });

  testWidgets('iPhone, a session found after the app was killed, light', (
    tester,
  ) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.light,
      file: 'session_iphone_recovery_light.png',
      leftover: true,
    );
  });

  testWidgets('small iPhone, running, dark', (tester) async {
    await check(
      tester,
      size: const Size(375, 667),
      theme: AppTheme.dark,
      file: 'session_iphone_se_running_dark.png',
      secondsIn: 5 * 60,
    );
  });

  testWidgets('iPad 13" landscape (wide), running an Inbox session, dark', (
    tester,
  ) async {
    await check(
      tester,
      size: const Size(1376, 1032),
      theme: AppTheme.dark,
      file: 'session_ipad_landscape_dark.png',
      title: 'Email and calls',
      tone: Tone.inbox,
      begin: 600,
      end: 660,
      secondsIn: 8 * 60,
    );
  });

  testWidgets('iPad 11" portrait (medium), running, light', (tester) async {
    await check(
      tester,
      size: const Size(834, 1194),
      theme: AppTheme.light,
      file: 'session_ipad_portrait_light.png',
      secondsIn: 40 * 60,
    );
  });
}
```

```bash
# expect: UPDATE
flutter test test/features/session/session_screen_golden_test.dart --update-goldens
rm -rf test/features/session/failures
```

- [ ] **Step 4: Look at the seven images**

```bash
# expect: MANUAL — running: a purple ring about three-quarters full around "1:06:43" and "remaining", the Focus chip, "Deep work", "Planned 1h 30m · ends 12:00", and Pause / +5m / +15m / Finish early / Abandon. Overtime (dark): a solid red ring and "+02:05" in red over "Overtime", with Finish as the light main button. Paused: "33:00" over "Paused", Resume as the main button, no "ends" time in the footer. Recovery: "A session was still running", Resume and Close out. iPad landscape: the ring on the left, the chip, title and buttons in a column on the right. On every image the digits sit comfortably inside the ring and nothing touches the tab bar.
open test/features/session/goldens/*.png
```

- [ ] **Step 5: Run the whole suite**

```bash
# expect: PASS — analyzer clean; everything passes (about 900 tests)
flutter analyze && flutter test
```

- [ ] **Step 6: Commit**

```bash
git add test/features/session
git commit -m "test: session screen layout matrix and goldens

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Stage 4 — Final checks

### Task 15: Format, full run, and the checks only a simulator can do

The automated tests prove the logic and the layouts. Three things they cannot prove, and which a first attempt at this feature could easily get wrong, need a real app on a simulator: **that the permission prompt appears when the first session starts, that the notification really fires at the planned end (including the UTC scheduling and the `Etc/UTC` zone name), and that a killed app finds its session again.** This task runs the final automated checks and then walks through all of them, with the screenshots reviewed by the person.

**Files:** none expected. If `dart format` changes anything, commit that.

- [ ] **Step 1: Format, analyze and run everything**

```bash
# expect: PASS — format changes nothing (the code in this plan is already formatted); analyzer clean; about 900 tests pass, 587 of them from before this step
DART="$(dirname "$(which flutter)")/dart"
"$DART" format --set-exit-if-changed lib test
flutter analyze
flutter test
```

If `dart format` does report changes, run it without `--set-exit-if-changed`, re-run the tests, and commit the result as `style: apply dart format`.

- [ ] **Step 2: Build and install on the iPhone 17 Pro simulator**

Open the live panel first (`attach` in the simulator tool), then:

```bash
# expect: RUN
flutter build ios --simulator --debug --no-codesign
```

Launch `build/ios/iphonesimulator/Runner.app` with the simulator tool's `launch` action. The simulator keeps its data between installs, so the existing events and the Step 2 database migration (v1 to v2) are exercised on real data: the app must open on the Clock tab with every earlier event still there.

- [ ] **Step 3: Make a throwaway event to test on**

The event sheet's time steppers move five minutes at a time, and a busy day may refuse a fourth overlapping ring, so add the test event straight into the simulator's database instead. Pick a slot where the day is quiet.

```bash
# expect: MANUAL — the app reopens with a small "Timer test" arc at 18:00 (it is a 15-minute event)
C=$(xcrun simctl get_app_container booted com.selfloop.energyClock data)
TODAY=$(python3 -c "import datetime; print(int(datetime.datetime.now().replace(hour=0, minute=0, second=0, microsecond=0).timestamp()))")
NOW=$(date +%s)
sqlite3 "$C/Documents/energy_clock.sqlite" "insert into events (series_id,date,title,tone_index,start_minute,end_minute,status,created_at,updated_at) values (NULL,$TODAY,'Timer test',0,1080,1095,0,$NOW,$NOW);"
xcrun simctl terminate booted com.selfloop.energyClock
xcrun simctl launch booted com.selfloop.energyClock
```

- [ ] **Step 4: Start, permission, and the countdown**

Check each of these, taking a screenshot where it says so:

1. Tap the "Timer test" arc, wait for the sheet to settle, and see **Start session** above Edit. (Taps made while the sheet is still sliding up miss the button; wait a second.)
2. Tap **Start session**. The session screen replaces the day and the **system notification prompt appears** (it is in the simulator's language; the app's own text is English). Tap Allow. *Screenshot.*
3. The ring is purple (Focus), the time counts down in whole seconds, "Planned 15m · ends …" shows. Pause: the number freezes and the word becomes "Paused". Resume. Tap +5m: the time jumps by five minutes. Switch to another tab and back: the countdown is still right.

- [ ] **Step 5: Kill the app and find the session again**

```bash
# expect: MANUAL — the app opens straight on the card "A session was still running" with Resume and Close out (never the day, and never the ordinary buttons, first). The ring beside it shows the true time left. "Timer test has been going for 0m" reads "under a minute" if less than a minute has passed.
xcrun simctl terminate booted com.selfloop.energyClock
xcrun simctl launch booted com.selfloop.energyClock
```

- [ ] **Step 6: The notification fires at the planned end**

Shorten the running session so it ends about ninety seconds from now, relaunch, resume, send the app to the background and wait. Do this promptly after the relaunch; the planned end is fixed once you change it.

```bash
# expect: MANUAL — the app opens on the recovery card
C=$(xcrun simctl get_app_container booted com.selfloop.energyClock data)
NOW=$(date +%s)
START=$(sqlite3 "$C/Documents/energy_clock.sqlite" "select started_at from sessions where outcome=0")
xcrun simctl terminate booted com.selfloop.energyClock
sqlite3 "$C/Documents/energy_clock.sqlite" "update sessions set planned_seconds=$((NOW + 90 - START)) where outcome=0;"
xcrun simctl launch booted com.selfloop.energyClock
```

Then, with the simulator tool: tap **Resume**, press the HOME button, and wait until about ninety seconds after the `update`. Open the notification shade (swipe down from the very top edge) and take a screenshot:

- **Expected:** a notification from Energy Clock reading "Time's up — Timer test is done. Open Energy Clock to finish, or keep going." delivered at the planned end.
- Open the app. **Expected:** the ring is solid red, the number is `+00:` followed by the seconds since the end, the word is "Overtime", the footer reads "was due" and the time, and **Finish** is the dark main button. The overtime counted while the app was in the background, which proves the wall-clock arithmetic. *Screenshot.*
- Tap **Finish**. **Expected:** the day returns with the "Timer test" event done; a message "Logged 2m on Timer test." shows briefly.

```bash
# expect: MANUAL — one session row with outcome 1 (completed) and overtime_seconds greater than 0, and the event with status 1
C=$(xcrun simctl get_app_container booted com.selfloop.energyClock data)
sqlite3 -header "$C/Documents/energy_clock.sqlite" "select id,event_id,planned_seconds,paused_seconds,active_seconds,overtime_seconds,outcome from sessions; select id,title,status from events where title='Timer test';"
```

- [ ] **Step 7: If notifications are refused**

Reset the app's permission and start another session on a new test event (repeat Step 3 with a new title), but tap **Don't Allow** at the prompt.

```bash
# expect: MANUAL — permission and the two remembered flags are cleared, so the next session asks again
xcrun simctl terminate booted com.selfloop.energyClock
xcrun simctl privacy booted reset notifications com.selfloop.energyClock
C=$(xcrun simctl get_app_container booted com.selfloop.energyClock data)
sqlite3 "$C/Documents/energy_clock.sqlite" "delete from app_settings where key in ('notifications_prompted','notification_banner_seen');"
xcrun simctl launch booted com.selfloop.energyClock
```

- **Expected after Don't Allow:** the session still runs; a card "Alerts are off" appears above the title with **Open Settings** and **Dismiss**. Dismiss it; start a later session: the banner does not return and the prompt does not appear again.

- [ ] **Step 8: iPad, a small iPhone, dark mode, large text**

With the simulator tool on the iPad Pro 13-inch and a small iPhone (create an iPhone SE-size simulator if none exists), start a session and check, with screenshots:

- iPad landscape: two panes, the ring on the left, the details and buttons on the right. iPad portrait: one centred column. Rotate mid-session: the time keeps counting.
- Small iPhone: the whole screen fits without scrolling at normal text size.
- Dark mode (`xcrun simctl ui booted appearance dark`): the ring, the red overtime colour and the cards are readable; then set it back to light.
- Largest text size (Settings → Accessibility → Display & Text Size → Larger Text): the buttons stack one to a row, the screen scrolls, nothing is cut off.
- VoiceOver spot check with the Accessibility Inspector: the ring reads as one sentence ("Timer test, Focus, 14 minutes 20 seconds left"); the +5m button reads "Add 5 minutes"; the Now card offers a "Start session" action.

- [ ] **Step 9: Clean up the test data**

```bash
# expect: MANUAL — only the events that were there before remain
xcrun simctl terminate booted com.selfloop.energyClock
C=$(xcrun simctl get_app_container booted com.selfloop.energyClock data)
sqlite3 "$C/Documents/energy_clock.sqlite" "delete from sessions where event_id in (select id from events where title like 'Timer test%'); delete from events where title like 'Timer test%'; select count(*) from events;"
xcrun simctl launch booted com.selfloop.energyClock
```

- [ ] **Step 10: Review with the person**

Share the screenshots from Steps 4, 6, 7 and 8. The things to ask about are the ones this plan decided without them (see "Decisions and amendments"): that the session takes the whole Clock tab, what close-out records, and the "Finish early" / "Finish" wording.

- [ ] **Step 11: Commit anything left over**

If Step 1 changed formatting:

```bash
git add lib test
git commit -m "style: apply dart format

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

## What Step 3 inherits

- `SessionRepository` and `sessions` rows are the source for Steps 4 and 5; nothing needs to be called when a session finishes.
- Notifications: the `NotificationService` interface, `sessionAlertsProvider` and the one-time-banner pattern are what Step 5's "event starting soon", Weekly Roundup and daily-reminder notifications should extend, with settings for each.
- Recurring events (Step 3) must materialise **before** a session can start on them; `canStartSession` only looks at the `events` row.
- The Calendar tab placeholder is unchanged. The Profile tab's "Replay intro" (Step 1 spec) and the notification toggles belong to Step 5.
- Step 6 must check the plugin's privacy manifest.
