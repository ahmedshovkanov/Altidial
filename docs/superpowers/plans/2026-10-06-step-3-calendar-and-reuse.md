# Energy Clock — Step 3: Calendar and Reuse Tools — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Calendar tab shows a month of days, each with a ring of its tone balance; swiping moves between months and tapping a day opens it on the Clock tab. Events can repeat (every day, weekdays, or chosen weekdays, with an optional end date), and editing or deleting one of them asks "this event" or "this and all future events". A day can be saved as a template and applied to an empty day, and an empty day can copy yesterday.

**Architecture:** Recurrence is *materialised* (Aug 23 spec §4.3): a repeating event is a row in `event_series`, and `SeriesMaterialiser` expands it into ordinary `events` rows whenever a day, a week of dots or a month is read, so nothing downstream contains recurrence logic. "This and all future" splits a series: the old one ends the day before, a new one starts. A deleted occurrence is kept as a `skipped` row so the series cannot bring it back. Templates and copy-yesterday are one `ReuseRepository` (fill an empty day from another plan). The Calendar reads one grouped SQL query per month through `CalendarRepository`; its day cell is a small `CustomPainter` ring. All the new repositories sit in the shared data layer (Riverpod providers in `lib/data/providers.dart`), so the Clock and Calendar features never import each other; `lib/app/` composes them.

**Tech Stack:** Flutter 3.44.7, Dart 3.12.2, `flutter_riverpod` 2.6, `drift` + `drift_flutter` (schema v3; `drift_dev schema` for the migration tests), `intl`. **No new packages.**

**Spec:** `docs/superpowers/specs/2026-08-23-energy-clock-design.md`. This plan implements §7 (Calendar, recurring events, day templates, copy-yesterday: "Phase 3" of §14), §4.3 (recurrence by materialisation), §5.4 (empty-day affordances), the `day_templates` and `day_template_items` tables of §4.2, and the Phase 3 parts of §12–§13. The Step 1 spec (`docs/superpowers/specs/2026-10-03-step-1-foundation-design.md`) left the Calendar tab as a placeholder "for Step 3". Where this plan departs from or fills gaps in the Aug 23 spec, the "Decisions and amendments" table below records it. **It must run after Steps 1 and 2 are merged** (the design system, the Clock screen, the session screen, the test harness and the layout matrix it builds on).

## Global Constraints

These apply to every task. Copied from the earlier specs and plans, with the schema line updated for this step.

- **Platform:** iOS 15+. iPhone in portrait; iPad in all four orientations with resizable windows. Flutter 3.44.7 / Dart 3.12.2.
- **Language:** English-only. All user-facing copy lives in `lib/core/strings.dart`. No localisation framework.
- **Tones are fixed:** exactly three — Focus (purple), Life (green), Inbox (orange). Not addable, removable, renameable, or recolourable.
- **Colour only ever encodes a tone.** UI accent (buttons, selected pills, today's marker) is near-black in light mode and near-white in dark mode, never purple. The calendar's rings are the only new colour on screen, and they are tone colours.
- **No hard-coded colours in feature code.** Nothing under `lib/features/` may contain `Color(0x` or `Colors.`. Every colour comes from `context.appColors`, `context.toneColors`, `AppColors.transparent`, or `Theme.of(context).colorScheme`. Enforced by `test/architecture/no_hardcoded_colors_test.dart`.
- **Boundary rule:** no file under `lib/features/<a>/` may import from `lib/features/<b>/`. `lib/app/` composes features and may import them. Cross-feature communication goes through repositories exposed as Riverpod providers in `lib/data/providers.dart`. The data layer (`lib/data/`) and `lib/core/` import no feature.
- **Minute domain:** `startMinute` is 0–1439, `endMinute` is 1–1440 and exclusive, and never exceeds 1440. At most three overlapping rings per day; a write that needs a fourth is refused with "Up to three overlapping events."
- **Derived, never accumulated:** a day's ring, a month's tone totals and a template's summary are computed from `events` and `day_template_items` rows when shown; nothing counts them up as events change. Recurrence is expanded into rows once, in `SeriesMaterialiser` only.
- **Local dates:** every date is a local midnight; a day, week or month is stepped with calendar arithmetic (`DateTime(y, m, d + 1)`), never with a 24-hour `Duration`, so a daylight-saving change cannot drop or repeat a day.
- **Window classes:** narrow under 600 pt, medium 600–899 pt, wide 900 pt and up. Layout follows the app window width, not the device name. Every new screen is checked at the eight sizes of the layout matrix.
- **Tap targets** are at least 44 pt. Two controls are exceptions that follow the week strip's precedent: the repeat picker's weekday toggles and the Calendar's day cells are a seventh of the width, so on the narrowest window (320 pt) they are about 40 pt wide (never under 36); they are never shorter than 40 pt (the toggles are 48 pt tall). **Contrast:** text pairs at least 4.5:1, arcs against the face at least 3:1. The calendar rings sit on the card `surface`, the pair the existing tone-colour tests already cover; day numbers use `ink`, `muted` and `onInk` on `surface`.
- **Reduce Motion:** every animation added here (the month page slide) becomes a jump under Reduce Motion, and the buttons' press-scale already honours it.
- **New runtime packages:** none.
- **Schema:** version 3. Every schema change ships with a migration step and a migration test (`test/data/migration_test.dart`), built on `drift_schemas/` and `test/generated_migrations/`.
- **Tooling:** run Dart commands, including `build_runner` and `drift_dev`, with the Flutter SDK's `dart` (`"$(dirname "$(which flutter)")/dart"`). The first `dart` on this machine's PATH is 3.10 and fails on this project.
- **Style:** `flutter analyze` must stay clean; the repo follows `dart format` and the lints in `analysis_options.yaml` (single quotes, `unawaited_futures`, `prefer_final_locals`, `always_declare_return_types`). The code in this plan is already formatted; Task 21 only confirms it.
- **Commit messages** use the repo's conventional prefixes (`feat:`, `fix:`, `test:`, `refactor:`, `docs:`, `chore:`) and end with a blank line and the trailer `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## Decisions and amendments

These were settled while writing the plan from the Aug 23 spec. They are the places where the spec was silent, ambiguous, or has since been overtaken by Steps 1–2. **Rows 2, 5, 7 and 8 are the ones most worth a second look.**

| # | Area | Decision | Why |
|---|---|---|---|
| 1 | When a series becomes events | The materialiser runs **whenever a day, a week strip's dots, or a calendar month is read** (inside the repositories' `watch…` methods), for any day including past ones. The Aug 23 spec's "next 7 days whenever the app foregrounds" job is **not** in this step. | Spec §4.3 says "when a day is opened". The foreground job exists to feed notifications and the Stats period, which arrive in Steps 4–5; each will call `SeriesMaterialiser.materialise(from, to)` for the window it needs. |
| 2 | "This and all future" | It **splits** the series: the old series ends the day before, its later occurrences are deleted, and a **new series starts on the edited day** with the new values. Earlier days keep the old values. A deleted-occurrence marker on a later day is cleared, so that day fills again under the new series. The same call turns a one-off event into a repeating one, or a repeating one back into a one-off. | The spec says to "rewrite the `event_series` row", which would rewrite days already lived and lose their history. Splitting keeps the past true. |
| 3 | Changing how an event repeats | Changing the rule of an occurrence cannot apply to one day, so the prompt then offers **only** "This and all future events" and says so. | A single occurrence cannot have a different rule from its series. |
| 4 | Dragging an occurrence | Moving or resizing a series occurrence on the dial changes **that event only**, without asking. | A drag is a quick gesture; a prompt in the middle of it would be wrong. To change the whole series, use the edit sheet. |
| 5 | A fourth ring | If a series occurrence would need a fourth overlapping ring on a day that is already full, it is **not created** on that day. It is tried again whenever that day is next read, so it appears as soon as there is room. | The dial cannot draw four rings, and the spec does not say what to do. The alternative, refusing the series, would block creating "Standup" because of one busy Thursday three weeks away. |
| 6 | Deleting one occurrence | The occurrence becomes a `skipped` row (spec §4.3). Every day, week-dot and month query leaves skipped rows out; a day that has only skipped rows counts as empty. | Otherwise the series would create it again the next time the day is opened. |
| 7 | Where Copy yesterday and Apply template show | **Copy yesterday** is offered only on an empty editable day *and* when yesterday has events; **Apply template** on every empty editable day. Both are in the ⋯ menu always, and also as two buttons under the Now card when the screen has room (the row is dropped first when space is short, and at text sizes above 130%). Save as template is in the same menu on any day that has events, past days included. | Spec §5.4 says the buttons sit "beneath the dial" on an empty editable day; it does not say what to do with no yesterday. The Clock never scrolls, so the buttons must give way like the day-load bar does, and the menu is the fallback. |
| 8 | The header on a past day | A past day **no longer shows the disabled + button**; the room goes to the new ⋯ menu. The Read-only chip and the Today pill stop growing at 130% text. | Adding the menu to a 320 pt window overflowed the row; the overflow was already latent (Read-only chip, Today pill and + at 200% text did not fit). |
| 9 | Where the reuse tools' screens live | In `features/clock` (the sheets, the menu, the buttons), with the data side in `lib/data/`. `features/calendar` holds only the month grid. | Spec §3.1 lists "reuse tools" under `features/calendar`, but they act on a day of the dial, and the boundary rule would force the Calendar to import the Clock. |
| 10 | Weeks | The Calendar's weeks start on **Monday** until the first-day-of-week setting exists (Step 5). | The week strip already does. |
| 11 | Calendar range | Open-ended both ways (a page view that starts in the middle of 2,400 months); a month's events are expanded when its page is built. | The spec bounds nothing. A month that is never looked at is never expanded. |
| 12 | The legend | The legend under the grid shows each tone's **planned hours for the month**, which uses the data already loaded and fills the page. | Colour only means a tone, so the rings need a key; the totals are free. |
| 13 | Templates | A template stores a day's events (title, tone, times) and a name of up to 60 characters. It can be applied to an empty day and deleted; there is no rename or reorder. Copying a day makes plain one-off events, planned, even from completed ones or from series occurrences. | Spec §7 describes save and apply only. Rename and reorder can wait until someone asks. |
| 14 | `events` indexes | Schema v3 adds the indexes the Aug 23 spec §4.2 asked for, on `(date)` and `(seriesId, date)`, which v1 never created. | The month query and the materialiser both scan `events` by date range. |
| 15 | Small moves | `RingOverflowException` moves from the Clock's repository file to `core/geometry/ring_layout.dart` (the data layer may not import a feature). `EventRepository` re-exports it, so no import changes. | The series repository throws it. |

## Out of scope (later steps)

- The foreground "next 7 days" materialising job and every notification setting ("event starting soon", Weekly Roundup, daily planning reminder): Step 5.
- Stats, streak, score, XP and badges: Steps 4–5. (Stats must expand the period it reads; see row 1.)
- First-day-of-week setting: Step 5.
- Renaming or reordering templates; editing a template's events; a year view; creating an event by tapping a Calendar day (tapping opens the day on the Clock).
- Moving an occurrence to another day, or a series with different times on different weekdays.

## How to read the steps

- **Create / Replace / Edit / Delete** blocks give the exact file change. A **Replace** block is the whole new file. An **Edit** block shows the exact text to find (`Replace:`) and what to put there (`With:`); an Edit block may hold several `Replace:` / `With:` pairs, applied in order, and each find text appears exactly once.
- A bash block whose first line is `# expect: PASS` must succeed; `# expect: FAIL` must fail for the stated reason; `# expect: RUN` and `# expect: UPDATE` are setup commands that must succeed; `# expect: MANUAL` is done by a person or the controller.
- Generated files (`*.g.dart`, `drift_schemas/*.json`, `test/generated_migrations/*`, golden images) are produced by the bash steps, not by file blocks. Commit them with the task.
- Golden images and the simulator walkthrough must be **looked at**, not just generated. Steps that say so name what to check.
- If a snippet does not compile against Flutter 3.44.7, fix the API usage minimally, keep the behaviour and the tests' intent, and say so in your report.
- `testWidgets` runs in fake time. A Clock screen on an empty day has a hint that pulses forever, so tests there use `pumpDial` (a bounded run of frames) or turn Reduce Motion on (`harness.app(…, reduceMotion: true)`) before using `pumpAndSettle`.
- Test counts in the `# expect: PASS` lines are the tests that task adds; the baseline before this step is 902, and the whole suite is 1,362 tests at the end of Task 21.

## File Structure

**Created:**

| File | Responsibility |
|---|---|
| `lib/core/recurrence/recurrence_rule.dart` | `RecurrenceKind`, `RecurrenceRule`, `occurrenceDates`: how an event repeats, pure Dart |
| `lib/core/recurrence/recurrence_text.dart` | `describeRecurrence`: "Every Mon, Wed and Fri, until …" |
| `lib/core/time/month_time.dart` | `startOfMonth`, `addMonths`, `daysInMonth`, `monthsBetween`, `monthWeeks` |
| `lib/data/tables/day_templates_table.dart` | `day_templates` and `day_template_items` tables |
| `lib/data/daos/series_dao.dart` | Series and their events: queries and writes |
| `lib/data/daos/template_dao.dart` | Templates and the events they are saved from and applied to |
| `lib/data/models/series_row_rule.dart` | `EventSeriesRow.rule` |
| `lib/data/models/day_template.dart` | `DayTemplate`, `TemplateItem` |
| `lib/data/repositories/series_materialiser.dart` | `SeriesMaterialiser`: expands series into events, idempotent |
| `lib/data/repositories/series_repository.dart` | `SeriesRepository`: make an event repeat; "this and all future" edit and delete |
| `lib/data/repositories/reuse_repository.dart` | `ReuseRepository`: day templates and copy-day |
| `lib/data/repositories/calendar_repository.dart` | `CalendarRepository`: a month's tone minutes per day |
| `lib/shared/widgets/adaptive_choice.dart` | `chooseOne`: a native action sheet on iOS, a dialog elsewhere |
| `lib/features/clock/widgets/repeat_picker.dart` | The Repeat control of the event sheet |
| `lib/features/clock/widgets/edit_scope.dart` | "This event" or "this and all future events" prompts |
| `lib/features/clock/widgets/template_name_dialog.dart` | Asks for a template's name |
| `lib/features/clock/widgets/reuse_actions.dart` | Save a day as a template; copy yesterday |
| `lib/features/clock/widgets/template_picker_sheet.dart` | The list of templates, to apply or delete |
| `lib/features/clock/widgets/reuse_row.dart` | The empty day's Copy yesterday / Apply template buttons |
| `lib/features/calendar/model/ring_segments.dart` | `ringSegments`: a day's tone arcs, pure Dart |
| `lib/features/calendar/widgets/day_ring_painter.dart` | Paints a day's ring |
| `lib/features/calendar/widgets/day_cell.dart` | One day of the grid |
| `lib/features/calendar/calendar_layout.dart` | Cell and card sizes from the window |
| `lib/features/calendar/providers.dart` | `monthLoadProvider` |
| `lib/features/calendar/widgets/month_header.dart` | Month title, arrows, Today pill |
| `lib/features/calendar/widgets/month_page.dart` | One month: weekday labels, grid, legend |
| `lib/app/navigation/calendar_tab.dart` | The Calendar tab (composes the Calendar with the shared clock) |
| `drift_schemas/drift_schema_v3.json`, `test/generated_migrations/schema_v3.dart` | Schema v3 snapshot and its migration helper (generated) |
| `test/support/fake_series_repository.dart`, `fake_reuse_repository.dart`, `fake_calendar_repository.dart` | In-memory fakes |
| About 40 test files, golden images for the Clock empty day, the day cell and the Calendar | See each task |

**Replaced:** `lib/data/daos/event_dao.dart`, `lib/features/calendar/calendar_screen.dart`, `lib/app/navigation/tab_scaffold.dart`, `lib/features/clock/clock_layout.dart`, `lib/features/clock/widgets/clock_header.dart`, `lib/features/clock/widgets/delete_event.dart`, `test/data/migration_test.dart`.

**Modified:** `lib/core/strings.dart`, `lib/core/geometry/ring_layout.dart`, `lib/shared/layout/content_width.dart`, `lib/data/database.dart`, `lib/data/providers.dart`, `lib/data/tables/events_table.dart`, `lib/features/clock/clock_screen.dart`, `lib/features/clock/providers.dart`, `lib/features/clock/data/event_repository.dart`, `lib/features/clock/widgets/event_sheet.dart`, `lib/features/clock/widgets/event_detail_sheet.dart`, `README.md`, the generated `*.g.dart` files, the four Clock screen goldens, `test/support/clock_harness.dart`, `test/support/fake_event_repository.dart`, `test/app/tab_scaffold_test.dart`, `test/features/clock/clock_header_test.dart`, `test/features/clock/clock_screen_test.dart`.

---

## Stage 1 — Data and logic

### Task 1: The recurrence rule and how it reads

The pure model first. `RecurrenceRule` says how an event repeats (never, daily, weekdays, or chosen weekdays, with an optional last day). `occurrenceDates` turns a rule and a start date into the dates it covers inside a range; the materialiser (Task 5) calls it. `describeRecurrence` turns a rule into the words the detail sheet shows ("Every Mon, Wed and Fri, until 31 Dec 2026"). Nothing here touches the database or Flutter.

The weekday mask follows the Aug 23 spec: seven bits, **Monday is bit 0**. Only a custom rule stores a mask; daily and weekdays are fixed shapes, so their mask is derived.

**Files:**
- Create: `lib/core/recurrence/recurrence_rule.dart`, `lib/core/recurrence/recurrence_text.dart`
- Modify: `lib/core/strings.dart`
- Test: `test/core/recurrence/recurrence_rule_test.dart`, `test/core/recurrence/recurrence_text_test.dart`

**Interfaces:**
- Produces: `RecurrenceKind { none, daily, weekdays, custom }` with `dbIndex` and `fromDbIndex`; `RecurrenceRule` with constructors `.none()`, `.daily({until})`, `.weekdays({until})`, `.custom(Set<int> weekdays, {until})` (weekday numbers are `DateTime.monday`…`DateTime.sunday`), `RecurrenceRule.fromStored({kindIndex, weekdayMask, until})`, and members `kind`, `weekdayMask`, `until`, `repeats`, `effectiveMask`, `weekdays`, `occursOnWeekday(int)`, `withUntil(DateTime?)`; `occurrenceDates({rule, validFrom, from, toExclusive})`; `describeRecurrence(RecurrenceRule)`; `Strings.weekdayShort`, `Strings.weekdayLong`, `Strings.weekdayInitials` (Monday first) and the repeat copy listed in Step 3.

- [ ] **Step 1: Write the failing tests**

**Create `test/core/recurrence/recurrence_rule_test.dart`**

```dart
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecurrenceKind', () {
    test('keeps its stable database numbers', () {
      expect(RecurrenceKind.none.dbIndex, 0);
      expect(RecurrenceKind.daily.dbIndex, 1);
      expect(RecurrenceKind.weekdays.dbIndex, 2);
      expect(RecurrenceKind.custom.dbIndex, 3);
    });

    test('is rebuilt from its database number', () {
      for (final kind in RecurrenceKind.values) {
        expect(RecurrenceKind.fromDbIndex(kind.dbIndex), kind);
      }
      expect(() => RecurrenceKind.fromDbIndex(9), throwsArgumentError);
    });
  });

  group('RecurrenceRule', () {
    test('none does not repeat and occurs on no weekday', () {
      const rule = RecurrenceRule.none();
      expect(rule.repeats, isFalse);
      expect(rule.effectiveMask, 0);
      for (var weekday = 1; weekday <= 7; weekday++) {
        expect(rule.occursOnWeekday(weekday), isFalse);
      }
    });

    test('daily occurs on every weekday', () {
      final rule = RecurrenceRule.daily();
      expect(rule.repeats, isTrue);
      expect(rule.effectiveMask, 127);
      expect(rule.weekdays, {1, 2, 3, 4, 5, 6, 7});
    });

    test('weekdays occurs Monday to Friday', () {
      final rule = RecurrenceRule.weekdays();
      expect(rule.effectiveMask, 31);
      expect(rule.weekdays, {1, 2, 3, 4, 5});
      expect(rule.occursOnWeekday(DateTime.friday), isTrue);
      expect(rule.occursOnWeekday(DateTime.saturday), isFalse);
    });

    test('custom keeps the chosen days, with Monday as bit 0', () {
      final rule = RecurrenceRule.custom({
        DateTime.monday,
        DateTime.wednesday,
        DateTime.sunday,
      });
      expect(rule.weekdayMask, 1 + 4 + 64);
      expect(rule.effectiveMask, 69);
      expect(rule.weekdays, {1, 3, 7});
      expect(rule.occursOnWeekday(DateTime.tuesday), isFalse);
    });

    test('custom needs at least one day', () {
      expect(() => RecurrenceRule.custom({}), throwsAssertionError);
    });

    test('an end day is stored as local midnight', () {
      final rule = RecurrenceRule.daily(until: DateTime(2026, 12, 31, 17, 45));
      expect(rule.until, DateTime(2026, 12, 31));
    });

    test('withUntil changes only the end day', () {
      final rule = RecurrenceRule.custom({1, 3});
      final ended = rule.withUntil(DateTime(2026, 11, 1));
      expect(ended.kind, RecurrenceKind.custom);
      expect(ended.weekdayMask, rule.weekdayMask);
      expect(ended.until, DateTime(2026, 11, 1));
      expect(ended.withUntil(null).until, isNull);
    });

    test('fromStored rebuilds each kind', () {
      expect(
        RecurrenceRule.fromStored(kindIndex: 0, weekdayMask: 0),
        const RecurrenceRule.none(),
      );
      expect(
        RecurrenceRule.fromStored(kindIndex: 1, weekdayMask: 0),
        RecurrenceRule.daily(),
      );
      expect(
        RecurrenceRule.fromStored(
          kindIndex: 2,
          weekdayMask: 0,
          until: DateTime(2026, 11, 1),
        ),
        RecurrenceRule.weekdays(until: DateTime(2026, 11, 1)),
      );
      expect(
        RecurrenceRule.fromStored(kindIndex: 3, weekdayMask: 5),
        RecurrenceRule.custom({1, 3}),
      );
    });

    test('a custom rule stored with no days reads back as none', () {
      expect(
        RecurrenceRule.fromStored(kindIndex: 3, weekdayMask: 0),
        const RecurrenceRule.none(),
      );
    });

    test('equal rules are equal and hash alike', () {
      expect(RecurrenceRule.daily(), RecurrenceRule.daily());
      expect(RecurrenceRule.daily().hashCode, RecurrenceRule.daily().hashCode);
      expect(RecurrenceRule.daily(), isNot(RecurrenceRule.weekdays()));
      expect(
        RecurrenceRule.daily(until: DateTime(2026, 11, 1)),
        isNot(RecurrenceRule.daily()),
      );
    });
  });

  group('occurrenceDates', () {
    final monday = DateTime(2026, 10, 5);

    test('a daily rule gives every day of the range', () {
      final dates = occurrenceDates(
        rule: RecurrenceRule.daily(),
        validFrom: monday,
        from: monday,
        toExclusive: DateTime(2026, 10, 8),
      );
      expect(dates, [
        DateTime(2026, 10, 5),
        DateTime(2026, 10, 6),
        DateTime(2026, 10, 7),
      ]);
    });

    test('a weekdays rule skips the weekend', () {
      final dates = occurrenceDates(
        rule: RecurrenceRule.weekdays(),
        validFrom: monday,
        from: monday,
        toExclusive: DateTime(2026, 10, 13),
      );
      expect(dates.map((day) => day.day), [5, 6, 7, 8, 9, 12]);
    });

    test('a custom rule gives only its days', () {
      final dates = occurrenceDates(
        rule: RecurrenceRule.custom({DateTime.tuesday, DateTime.saturday}),
        validFrom: monday,
        from: monday,
        toExclusive: DateTime(2026, 10, 19),
      );
      expect(dates.map((day) => day.day), [6, 10, 13, 17]);
    });

    test('nothing comes before the first day', () {
      final dates = occurrenceDates(
        rule: RecurrenceRule.daily(),
        validFrom: DateTime(2026, 10, 7),
        from: monday,
        toExclusive: DateTime(2026, 10, 10),
      );
      expect(dates.map((day) => day.day), [7, 8, 9]);
    });

    test('the end day is included and nothing comes after it', () {
      final dates = occurrenceDates(
        rule: RecurrenceRule.daily(until: DateTime(2026, 10, 7)),
        validFrom: monday,
        from: monday,
        toExclusive: DateTime(2026, 10, 12),
      );
      expect(dates.map((day) => day.day), [5, 6, 7]);
    });

    test('a range wholly after the end day is empty', () {
      final dates = occurrenceDates(
        rule: RecurrenceRule.daily(until: DateTime(2026, 10, 7)),
        validFrom: monday,
        from: DateTime(2026, 10, 8),
        toExclusive: DateTime(2026, 10, 12),
      );
      expect(dates, isEmpty);
    });

    test('a rule that does not repeat gives nothing', () {
      final dates = occurrenceDates(
        rule: const RecurrenceRule.none(),
        validFrom: monday,
        from: monday,
        toExclusive: DateTime(2026, 10, 12),
      );
      expect(dates, isEmpty);
    });

    test('an empty range gives nothing', () {
      final dates = occurrenceDates(
        rule: RecurrenceRule.daily(),
        validFrom: monday,
        from: monday,
        toExclusive: monday,
      );
      expect(dates, isEmpty);
    });

    test('every date is a distinct local midnight across a year', () {
      // A year crosses both daylight-saving changes in any zone that has them.
      final dates = occurrenceDates(
        rule: RecurrenceRule.daily(),
        validFrom: DateTime(2026, 1, 1),
        from: DateTime(2026, 1, 1),
        toExclusive: DateTime(2027, 1, 1),
      );
      expect(dates, hasLength(365));
      expect(dates.toSet(), hasLength(365));
      for (final date in dates) {
        expect(date.hour, 0);
        expect(date.minute, 0);
      }
    });
  });
}
```

**Create `test/core/recurrence/recurrence_text_test.dart`**

```dart
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/recurrence/recurrence_text.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('names the common shapes', () {
    expect(describeRecurrence(RecurrenceRule.daily()), 'Every day');
    expect(describeRecurrence(RecurrenceRule.weekdays()), 'Weekdays');
    expect(describeRecurrence(const RecurrenceRule.none()), 'Does not repeat');
  });

  test('lists the days of a custom rule', () {
    expect(
      describeRecurrence(RecurrenceRule.custom({1, 3, 5})),
      'Every Mon, Wed and Fri',
    );
    expect(describeRecurrence(RecurrenceRule.custom({6})), 'Every Sat');
    expect(
      describeRecurrence(RecurrenceRule.custom({2, 4})),
      'Every Tue and Thu',
    );
  });

  test('a custom rule that is really every day or weekdays says so', () {
    expect(
      describeRecurrence(RecurrenceRule.custom({1, 2, 3, 4, 5, 6, 7})),
      'Every day',
    );
    expect(
      describeRecurrence(RecurrenceRule.custom({1, 2, 3, 4, 5})),
      'Weekdays',
    );
  });

  test('adds the end day', () {
    expect(
      describeRecurrence(RecurrenceRule.daily(until: DateTime(2026, 12, 31))),
      'Every day, until 31 Dec 2026',
    );
    expect(
      describeRecurrence(
        RecurrenceRule.custom({1, 3}, until: DateTime(2027, 1, 5)),
      ),
      'Every Mon and Wed, until 5 Jan 2027',
    );
  });

  test('the weekday lists run Monday first and have seven entries', () {
    expect(Strings.weekdayShort, hasLength(7));
    expect(Strings.weekdayLong, hasLength(7));
    expect(Strings.weekdayInitials, hasLength(7));
    expect(Strings.weekdayShort.first, 'Mon');
    expect(Strings.weekdayLong.last, 'Sunday');
    expect(Strings.weekdayInitials.first, 'M');
  });
}
```

- [ ] **Step 2: Run the tests to see them fail**

```bash
# expect: FAIL — the recurrence files and the weekday strings do not exist yet
flutter test test/core/recurrence
```

- [ ] **Step 3: Write the code**

**Create `lib/core/recurrence/recurrence_rule.dart`**

```dart
import 'package:energy_clock/core/time/day_time.dart';

/// How an event repeats. Persisted as [dbIndex] in
/// `event_series.recurrenceKind`; never reorder or reuse these numbers.
enum RecurrenceKind {
  none(0),
  daily(1),
  weekdays(2),
  custom(3);

  const RecurrenceKind(this.dbIndex);

  final int dbIndex;

  static RecurrenceKind fromDbIndex(int index) {
    for (final kind in RecurrenceKind.values) {
      if (kind.dbIndex == index) return kind;
    }
    throw ArgumentError.value(index, 'index', 'Unknown recurrence kind');
  }
}

/// The weekday mask bit for [weekday] (`DateTime.monday` … `DateTime.sunday`).
/// Monday is bit 0, as in the spec.
int _bitFor(int weekday) => 1 << (weekday - DateTime.monday);

const int _everyDayMask = 127;
const int _weekdaysMask = 31;

/// How an event repeats, and the last day it may occur on.
///
/// The first day is not part of the rule: it belongs to the series
/// (`event_series.validFrom`). [until] is the last day an occurrence may fall
/// on, as a local midnight, or null for a series that never ends.
class RecurrenceRule {
  const RecurrenceRule._(this.kind, this.weekdayMask, this.until);

  /// An event that does not repeat.
  const RecurrenceRule.none()
    : kind = RecurrenceKind.none,
      weekdayMask = 0,
      until = null;

  RecurrenceRule.daily({DateTime? until})
    : kind = RecurrenceKind.daily,
      weekdayMask = 0,
      until = until == null ? null : startOfDay(until);

  /// Monday to Friday.
  RecurrenceRule.weekdays({DateTime? until})
    : kind = RecurrenceKind.weekdays,
      weekdayMask = 0,
      until = until == null ? null : startOfDay(until);

  /// The given weekdays, as `DateTime.monday` … `DateTime.sunday`.
  RecurrenceRule.custom(Set<int> weekdays, {DateTime? until})
    : assert(weekdays.isNotEmpty, 'A custom rule needs at least one day'),
      kind = RecurrenceKind.custom,
      weekdayMask = weekdays.fold<int>(0, (mask, day) => mask | _bitFor(day)),
      until = until == null ? null : startOfDay(until);

  /// Rebuilds a rule from its stored columns. A custom rule with no days
  /// cannot occur on any day, so it reads back as [RecurrenceRule.none].
  factory RecurrenceRule.fromStored({
    required int kindIndex,
    required int weekdayMask,
    DateTime? until,
  }) {
    switch (RecurrenceKind.fromDbIndex(kindIndex)) {
      case RecurrenceKind.none:
        return const RecurrenceRule.none();
      case RecurrenceKind.daily:
        return RecurrenceRule.daily(until: until);
      case RecurrenceKind.weekdays:
        return RecurrenceRule.weekdays(until: until);
      case RecurrenceKind.custom:
        final mask = weekdayMask & _everyDayMask;
        if (mask == 0) return const RecurrenceRule.none();
        return RecurrenceRule._(
          RecurrenceKind.custom,
          mask,
          until == null ? null : startOfDay(until),
        );
    }
  }

  final RecurrenceKind kind;

  /// The stored mask. Only a custom rule has one; it is 0 for every other kind.
  final int weekdayMask;

  /// The last day an occurrence may fall on, or null.
  final DateTime? until;

  bool get repeats => kind != RecurrenceKind.none;

  /// The seven-bit mask of the days this rule occurs on, whatever its kind.
  int get effectiveMask => switch (kind) {
    RecurrenceKind.none => 0,
    RecurrenceKind.daily => _everyDayMask,
    RecurrenceKind.weekdays => _weekdaysMask,
    RecurrenceKind.custom => weekdayMask,
  };

  /// The weekdays this rule occurs on, as `DateTime.monday` … `DateTime.sunday`.
  Set<int> get weekdays => {
    for (var day = DateTime.monday; day <= DateTime.sunday; day++)
      if (occursOnWeekday(day)) day,
  };

  bool occursOnWeekday(int weekday) => effectiveMask & _bitFor(weekday) != 0;

  RecurrenceRule withUntil(DateTime? until) => RecurrenceRule._(
    kind,
    weekdayMask,
    until == null ? null : startOfDay(until),
  );

  @override
  bool operator ==(Object other) =>
      other is RecurrenceRule &&
      other.kind == kind &&
      other.weekdayMask == weekdayMask &&
      other.until == until;

  @override
  int get hashCode => Object.hash(kind, weekdayMask, until);

  @override
  String toString() => 'RecurrenceRule($kind, mask $weekdayMask, until $until)';
}

/// The days in [from, toExclusive) on which a series that follows [rule] and
/// starts on [validFrom] has an occurrence. Calendar arithmetic throughout, so
/// a daylight-saving change can never drop or repeat a day.
List<DateTime> occurrenceDates({
  required RecurrenceRule rule,
  required DateTime validFrom,
  required DateTime from,
  required DateTime toExclusive,
}) {
  if (!rule.repeats) return const [];
  final start = startOfDay(validFrom);
  final firstDay = startOfDay(from);
  final end = startOfDay(toExclusive);
  final last = rule.until;

  final dates = <DateTime>[];
  for (
    var day = firstDay.isBefore(start) ? start : firstDay;
    day.isBefore(end);
    day = nextDay(day)
  ) {
    if (last != null && day.isAfter(last)) break;
    if (rule.occursOnWeekday(day.weekday)) dates.add(day);
  }
  return dates;
}
```

**Create `lib/core/recurrence/recurrence_text.dart`**

```dart
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:intl/intl.dart';

/// How a rule reads to a person: "Every day", "Weekdays",
/// "Every Mon, Wed and Fri", each followed by ", until 31 Dec 2026" when the
/// series ends.
String describeRecurrence(RecurrenceRule rule) {
  if (!rule.repeats) return Strings.repeatNone;

  final mask = rule.effectiveMask;
  final base = switch (mask) {
    127 => Strings.repeatDaily,
    31 => Strings.repeatWeekdays,
    _ => Strings.repeatEvery(
      Strings.joinWords([
        for (final weekday in rule.weekdays)
          Strings.weekdayShort[weekday - DateTime.monday],
      ]),
    ),
  };

  final until = rule.until;
  if (until == null) return base;
  return '$base, ${Strings.repeatUntil(DateFormat('d MMM y').format(until))}';
}
```

**Edit `lib/core/strings.dart`**

Replace:

```dart
  static const String recoveryResume = 'Resume';
  static const String recoveryCloseOut = 'Close out';
}
```

With:

```dart
  static const String recoveryResume = 'Resume';
  static const String recoveryCloseOut = 'Close out';

  // Days of the week, Monday first.
  static const List<String> weekdayShort = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const List<String> weekdayLong = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const List<String> weekdayInitials = [
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  // Repeating events.
  static const String repeatLabel = 'Repeat';
  static const String repeatNone = 'Does not repeat';
  static const String repeatNever = 'Never';
  static const String repeatDaily = 'Every day';
  static const String repeatWeekdays = 'Weekdays';
  static const String repeatCustom = 'Custom';
  static String repeatEvery(String days) => 'Every $days';
  static String repeatUntil(String date) => 'until $date';
}
```

- [ ] **Step 4: Run the tests to see them pass**

```bash
# expect: PASS
flutter test test/core/recurrence test/core/strings_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/core/recurrence lib/core/strings.dart test/core/recurrence
git commit -m "feat: recurrence rule, occurrence dates and their wording

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Month helpers

The Calendar tab and the month queries both need to find the first of a month, step months, and lay a month out as weeks. These are pure date functions, kept apart from the Clock's day helpers in `day_time.dart`. All of them use calendar arithmetic (the `DateTime` constructor normalises out-of-range months and days), never `Duration`.

**Files:**
- Create: `lib/core/time/month_time.dart`
- Test: `test/core/time/month_time_test.dart`

**Interfaces:**
- Produces: `startOfMonth(DateTime)`, `addMonths(DateTime month, int delta)`, `daysInMonth(DateTime month)`, `monthsBetween(DateTime from, DateTime to)`, `monthWeeks(DateTime month)` returning rows of seven `DateTime?` cells, Monday first, with `null` outside the month.

- [ ] **Step 1: Write the failing test**

**Create `test/core/time/month_time_test.dart`**

```dart
import 'package:energy_clock/core/time/month_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startOfMonth gives local midnight on the first', () {
    expect(startOfMonth(DateTime(2026, 10, 17, 14, 30)), DateTime(2026, 10));
  });

  test('addMonths steps across year ends and returns the first', () {
    expect(addMonths(DateTime(2026, 10, 17), 1), DateTime(2026, 11));
    expect(addMonths(DateTime(2026, 12, 31), 1), DateTime(2027));
    expect(addMonths(DateTime(2026, 1, 31), -1), DateTime(2025, 12));
    expect(addMonths(DateTime(2026, 10, 5), 0), DateTime(2026, 10));
    expect(addMonths(DateTime(2026, 10, 5), 14), DateTime(2027, 12));
    expect(addMonths(DateTime(2026, 10, 5), -24), DateTime(2024, 10));
  });

  test('daysInMonth knows month lengths and leap years', () {
    expect(daysInMonth(DateTime(2026, 10)), 31);
    expect(daysInMonth(DateTime(2026, 11)), 30);
    expect(daysInMonth(DateTime(2026, 2)), 28);
    expect(daysInMonth(DateTime(2028, 2)), 29);
    expect(daysInMonth(DateTime(2026, 12, 15)), 31);
  });

  test('monthsBetween counts whole months, in either direction', () {
    expect(monthsBetween(DateTime(2026, 10), DateTime(2026, 10)), 0);
    expect(monthsBetween(DateTime(2026, 10, 31), DateTime(2026, 11, 1)), 1);
    expect(monthsBetween(DateTime(2026, 10), DateTime(2027, 2)), 4);
    expect(monthsBetween(DateTime(2026, 10), DateTime(2025, 12)), -10);
  });

  group('monthWeeks', () {
    test('October 2026 starts on a Thursday and fills five weeks', () {
      final weeks = monthWeeks(DateTime(2026, 10));
      expect(weeks, hasLength(5));
      for (final week in weeks) {
        expect(week, hasLength(7));
      }
      // Monday to Wednesday before the 1st are empty.
      expect(weeks.first.take(3), everyElement(isNull));
      expect(weeks.first[3], DateTime(2026, 10, 1));
      expect(weeks.first[6], DateTime(2026, 10, 4));
      // The 31st is a Saturday; the Sunday after it is empty.
      expect(weeks.last[5], DateTime(2026, 10, 31));
      expect(weeks.last[6], isNull);
    });

    test('a month that starts on Monday and has 28 days is four weeks', () {
      final weeks = monthWeeks(DateTime(2027, 2));
      expect(weeks, hasLength(4));
      expect(weeks.first.first, DateTime(2027, 2, 1));
      expect(weeks.last.last, DateTime(2027, 2, 28));
    });

    test('a month can need six weeks', () {
      // 1 August 2026 is a Saturday and August has 31 days.
      final weeks = monthWeeks(DateTime(2026, 8));
      expect(weeks, hasLength(6));
      expect(weeks.first[5], DateTime(2026, 8, 1));
      expect(weeks.last[0], DateTime(2026, 8, 31));
    });

    test('every day of the month appears once, in order', () {
      final days = [
        for (final week in monthWeeks(DateTime(2026, 10)))
          for (final day in week)
            if (day != null) day.day,
      ];
      expect(days, [for (var day = 1; day <= 31; day++) day]);
    });

    test('any day of the month gives the same layout', () {
      expect(
        monthWeeks(DateTime(2026, 10, 17)),
        monthWeeks(DateTime(2026, 10)),
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to see it fail**

```bash
# expect: FAIL — lib/core/time/month_time.dart does not exist yet
flutter test test/core/time/month_time_test.dart
```

- [ ] **Step 3: Write the code**

**Create `lib/core/time/month_time.dart`**

```dart
/// The first day of the month containing [day], at local midnight.
DateTime startOfMonth(DateTime day) => DateTime(day.year, day.month);

/// The first day of the month [delta] months after [month]'s month (before it,
/// if negative). Calendar arithmetic: the `DateTime` constructor carries a
/// month past 12 or before 1 into the year.
DateTime addMonths(DateTime month, int delta) =>
    DateTime(month.year, month.month + delta);

/// How many days [month]'s month has.
int daysInMonth(DateTime month) => DateTime(month.year, month.month + 1, 0).day;

/// Whole months from [from]'s month to [to]'s month; negative when [to] is
/// earlier. Only the year and month count, never the day.
int monthsBetween(DateTime from, DateTime to) =>
    (to.year - from.year) * 12 + (to.month - from.month);

/// [month]'s month laid out as rows of seven cells, Monday first. A cell is
/// that day's local midnight, or null where the row runs outside the month.
List<List<DateTime?>> monthWeeks(DateTime month) {
  final first = startOfMonth(month);
  final leading = first.weekday - DateTime.monday;
  final cells = <DateTime?>[
    for (var i = 0; i < leading; i++) null,
    for (var day = 1; day <= daysInMonth(first); day++)
      DateTime(first.year, first.month, day),
  ];
  while (cells.length % 7 != 0) {
    cells.add(null);
  }
  return [
    for (var start = 0; start < cells.length; start += 7)
      cells.sublist(start, start + 7),
  ];
}
```

- [ ] **Step 4: Run the test to see it pass**

```bash
# expect: PASS
flutter test test/core/time/month_time_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/core/time/month_time.dart test/core/time/month_time_test.dart
git commit -m "feat: month helpers for the calendar

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---
### Task 3: Schema v3 — day templates and the event indexes

Version 3 adds the two template tables from the Aug 23 spec §4.2 (`day_templates`, `day_template_items`) and the two indexes the spec asks for on `events`, `(date)` and `(seriesId, date)`, which version 1 never created. Both queries this step adds (a month of days, and "which occurrences of this series already exist") scan `events` by date range, so the indexes now earn their keep. This is the project's second migration, with its test.

`event_series` already has every column recurrence needs (it was created in v1 for this step), so it does not change.

**Files:**
- Create: `lib/data/tables/day_templates_table.dart`, `drift_schemas/drift_schema_v3.json` (generated), `test/generated_migrations/schema_v3.dart` (generated)
- Modify: `lib/data/tables/events_table.dart`, `lib/data/database.dart`, the generated `lib/data/database.g.dart` and `test/generated_migrations/schema.dart`
- Test: `test/data/migration_test.dart`

**Interfaces:**
- Produces: tables `DayTemplates` (`id`, `name`, `createdAt`) and `DayTemplateItems` (`id`, `templateId`, `title`, `toneIndex`, `startMinute`, `endMinute`), their data classes `DayTemplateRow` and `DayTemplateItemRow`, the table getters `dayTemplates` and `dayTemplateItems` on `AppDatabase`, and `schemaVersion == 3`.

- [ ] **Step 1: Write the failing migration test**

The test now upgrades from every shipped version: from 1 and from 2 to 3, keeping the data each version held, and checks a fresh install matches the upgraded schema.

**Replace `test/data/migration_test.dart`**

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

  // Seconds since the epoch, which is how Drift stores a DateTime.
  final seconds = DateTime(2026, 10, 7).millisecondsSinceEpoch ~/ 1000;

  const insertEvent =
      'INSERT INTO events (date, title, tone_index, start_minute, end_minute, '
      'status, created_at, updated_at) ';

  test('version 1 upgrades to version 3', () async {
    final schema = await verifier.schemaAt(1);
    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 3);
  });

  test('version 2 upgrades to version 3', () async {
    final schema = await verifier.schemaAt(2);
    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 3);
  });

  test('upgrading from version 1 keeps the events that were stored', () async {
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase.execute(
      "$insertEvent VALUES ($seconds, 'Deep work', 0, 540, 660, 0, $seconds, $seconds)",
    );

    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 3);

    final events = await database.eventDao.eventsForDay(DateTime(2026, 10, 7));
    expect(events.single.title, 'Deep work');
    expect(await database.sessionDao.running(), isNull);
  });

  test('upgrading from version 2 keeps events and sessions', () async {
    final schema = await verifier.schemaAt(2);
    schema.rawDatabase.execute(
      "$insertEvent VALUES ($seconds, 'Deep work', 0, 540, 660, 0, $seconds, $seconds)",
    );
    schema.rawDatabase.execute(
      'INSERT INTO sessions (event_id, started_at, planned_seconds, '
      'paused_seconds, active_seconds, overtime_seconds, outcome) '
      'VALUES (1, $seconds, 3600, 0, 0, 0, 0)',
    );

    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 3);

    final events = await database.eventDao.eventsForDay(DateTime(2026, 10, 7));
    expect(events.single.title, 'Deep work');
    final running = await database.sessionDao.running();
    expect(running, isNotNull);
    expect(running!.session.plannedSeconds, 3600);
    expect(await database.select(database.dayTemplates).get(), isEmpty);
  });

  test('a new install creates the same schema as the upgrade', () async {
    final schema = await verifier.schemaAt(3);
    final database = AppDatabase.forTesting(schema.newConnection());
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 3);
  });
}
```

- [ ] **Step 2: Run the test to see it fail**

```bash
# expect: FAIL — there is no schema version 3 yet ("Unknown schema version" or a validation error)
flutter test test/data/migration_test.dart
```

- [ ] **Step 3: Write the tables, the indexes and the migration**

**Create `lib/data/tables/day_templates_table.dart`**

```dart
import 'package:drift/drift.dart';

/// A named day plan the person saved to reuse (spec §7, day templates). The
/// events of the plan are in [DayTemplateItems].
@DataClassName('DayTemplateRow')
class DayTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 60)();

  DateTimeColumn get createdAt => dateTime()();
}

/// One event of a template: the same fields as an event, minus the day and the
/// status, which a template does not have.
@DataClassName('DayTemplateItemRow')
class DayTemplateItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get templateId => integer().references(DayTemplates, #id)();

  TextColumn get title => text().withLength(min: 1, max: 120)();

  IntColumn get toneIndex => integer()();

  /// 0–1439.
  IntColumn get startMinute => integer()();

  /// 1–1440, exclusive.
  IntColumn get endMinute => integer()();
}
```

**Edit `lib/data/tables/events_table.dart`**

Replace:

```dart
@DataClassName('EventRow')
class Events extends Table {
```

With:

```dart
@TableIndex(name: 'events_date', columns: {#date})
@TableIndex(name: 'events_series_date', columns: {#seriesId, #date})
@DataClassName('EventRow')
class Events extends Table {
```

**Edit `lib/data/database.dart`**

Replace:

```dart
import 'package:energy_clock/data/tables/event_series_table.dart';
```

With:

```dart
import 'package:energy_clock/data/tables/day_templates_table.dart';
import 'package:energy_clock/data/tables/event_series_table.dart';
```

Replace:

```dart
  tables: [Events, EventSeries, AppSettings, Sessions],
```

With:

```dart
  tables: [
    Events,
    EventSeries,
    AppSettings,
    Sessions,
    DayTemplates,
    DayTemplateItems,
  ],
```

Replace:

```dart
  /// Version 1: events, event series, settings. Version 2: sessions. Every
  /// bump needs a step in [migration] and a test in
  /// `test/data/migration_test.dart`; see `drift_schemas/`.
  @override
  int get schemaVersion => 2;
```

With:

```dart
  /// Version 1: events, event series, settings. Version 2: sessions. Version 3:
  /// day templates, and the indexes on events. Every bump needs a step in
  /// [migration] and a test in `test/data/migration_test.dart`; see
  /// `drift_schemas/`.
  @override
  int get schemaVersion => 3;
```

Replace:

```dart
      if (from < 2) {
        await migrator.createTable(sessions);
      }
```

With:

```dart
      if (from < 2) {
        await migrator.createTable(sessions);
      }
      if (from < 3) {
        await migrator.createTable(dayTemplates);
        await migrator.createTable(dayTemplateItems);
        await migrator.createIndex(eventsDate);
        await migrator.createIndex(eventsSeriesDate);
      }
```

- [ ] **Step 4: Generate the Drift code, dump schema v3 and generate the migration helpers**

```bash
# expect: RUN — drift_schema_v3.json, and schema_v3.dart plus an updated schema.dart
DART="$(dirname "$(which flutter)")/dart"
"$DART" run build_runner build --delete-conflicting-outputs
"$DART" run drift_dev schema dump lib/data/database.dart drift_schemas/
"$DART" run drift_dev schema generate drift_schemas/ test/generated_migrations/
ls drift_schemas test/generated_migrations
```

- [ ] **Step 5: Run the migration test, the analyzer and the whole suite**

```bash
# expect: PASS — 5 migration tests pass; analyzer clean; the whole suite stays green
flutter test test/data/migration_test.dart && flutter analyze && flutter test
```

- [ ] **Step 6: Commit**

```bash
git add lib/data drift_schemas test/generated_migrations test/data/migration_test.dart
git commit -m "feat: day template tables, event indexes and schema v3

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---
### Task 4: Skipped events stay hidden, and a month of tone minutes

Spec §4.3: deleting one occurrence of a recurring series must not let the series bring it back, so the occurrence is **kept as a row with `status = skipped`** instead of removed. That makes "skipped" a state every day query has to respect: a skipped row is a tombstone, never an event. This task teaches `EventDao` both halves: day and tone queries leave skipped rows out, and `deleteById` skips an occurrence that belongs to a series (and still removes a one-off).

The same file gains `watchToneMinutes`, the query behind the Calendar's month rings: planned minutes per tone for each day in a range, in one grouped query (spec §3.3, "one grouped query"). Overlapping events count twice, as in the day-load bar, because overlap is extra load.

**Files:**
- Replace: `lib/data/daos/event_dao.dart`
- Modify: `lib/features/clock/data/event_repository.dart`, the generated `lib/data/daos/event_dao.g.dart`
- Test: `test/data/event_dao_skip_test.dart`, `test/data/event_dao_minutes_test.dart`

**Interfaces:**
- Consumes: `EventStatus.skipped.dbIndex` from `lib/core/event_status.dart`.
- Produces: `EventDao.deleteById(int id, {DateTime? now})` (series occurrences are skipped, one-offs removed, sessions of either are removed); `EventDao.eventsForDay`, `watchDay` and `watchToneDays` that exclude skipped rows; `EventDao.watchToneMinutes(DateTime from, DateTime toExclusive)` returning `Stream<List<({DateTime date, int toneIndex, int minutes})>>`.

- [ ] **Step 1: Write the failing tests**

**Create `test/data/event_dao_skip_test.dart`**

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:energy_clock/core/event_status.dart';
import 'package:energy_clock/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  final day = DateTime(2026, 10, 7);
  final now = DateTime(2026, 10, 7, 9);

  Future<int> add({
    int? seriesId,
    int status = 0,
    int start = 540,
    int end = 600,
    int tone = 0,
  }) {
    return db.eventDao.insertEvent(
      EventsCompanion.insert(
        seriesId: Value(seriesId),
        date: day,
        title: 'Event',
        toneIndex: tone,
        startMinute: start,
        endMinute: end,
        status: Value(status),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<List<EventRow>> everyRow() => db.select(db.events).get();

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('skipped rows', () {
    test('are left out of the day queries', () async {
      await add();
      await add(status: EventStatus.skipped.dbIndex, start: 700, end: 760);

      expect(await db.eventDao.eventsForDay(day), hasLength(1));
      expect(await db.eventDao.watchDay(day).first, hasLength(1));
    });

    test('are left out of the tone days', () async {
      await add(status: EventStatus.skipped.dbIndex, tone: 2);

      final rows = await db.eventDao
          .watchToneDays(day, DateTime(2026, 10, 8))
          .first;
      expect(rows, isEmpty);
    });

    test('completed events are still shown', () async {
      await add(status: EventStatus.completed.dbIndex);
      expect(await db.eventDao.eventsForDay(day), hasLength(1));
    });
  });

  group('deleteById', () {
    test('removes a one-off event', () async {
      final id = await add();

      await db.eventDao.deleteById(id, now: now);

      expect(await everyRow(), isEmpty);
    });

    test('keeps an occurrence of a series as a skipped row', () async {
      final id = await add(seriesId: 4);

      await db.eventDao.deleteById(id, now: DateTime(2026, 10, 7, 12));

      final rows = await everyRow();
      expect(rows, hasLength(1));
      expect(rows.single.id, id);
      expect(rows.single.seriesId, 4);
      expect(rows.single.status, EventStatus.skipped.dbIndex);
      expect(rows.single.updatedAt, DateTime(2026, 10, 7, 12));
      expect(await db.eventDao.eventsForDay(day), isEmpty);
    });

    test('removes the sessions of either kind of event', () async {
      final oneOff = await add();
      final occurrence = await add(seriesId: 4, start: 700, end: 760);
      for (final eventId in [oneOff, occurrence]) {
        await db
            .into(db.sessions)
            .insert(
              SessionsCompanion.insert(
                eventId: eventId,
                startedAt: now,
                plannedSeconds: 3600,
              ),
            );
      }

      await db.eventDao.deleteById(oneOff, now: now);
      await db.eventDao.deleteById(occurrence, now: now);

      expect(await db.select(db.sessions).get(), isEmpty);
    });

    test('deleting an event that is already gone does nothing', () async {
      await db.eventDao.deleteById(99, now: now);
      expect(await everyRow(), isEmpty);
    });
  });
}
```

**Create `test/data/event_dao_minutes_test.dart`**

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:energy_clock/core/event_status.dart';
import 'package:energy_clock/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 10, 3);

  Future<int> add(
    DateTime date,
    int toneIndex,
    int start,
    int end, {
    int status = 0,
  }) {
    return db.eventDao.insertEvent(
      EventsCompanion.insert(
        date: date,
        title: 'Event',
        toneIndex: toneIndex,
        startMinute: start,
        endMinute: end,
        status: Value(status),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<Map<String, int>> minutes(DateTime from, DateTime to) async {
    final rows = await db.eventDao.watchToneMinutes(from, to).first;
    return {
      for (final row in rows) '${row.date.day}:${row.toneIndex}': row.minutes,
    };
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('sums the minutes of each tone on each day', () async {
    await add(DateTime(2026, 10, 5), 0, 60, 120);
    await add(DateTime(2026, 10, 5), 0, 300, 390);
    await add(DateTime(2026, 10, 5), 2, 180, 195);
    await add(DateTime(2026, 10, 6), 1, 60, 105);

    expect(await minutes(DateTime(2026, 10, 1), DateTime(2026, 11, 1)), {
      '5:0': 150,
      '5:2': 15,
      '6:1': 45,
    });
  });

  test('overlapping events count twice', () async {
    await add(DateTime(2026, 10, 5), 0, 60, 120);
    await add(DateTime(2026, 10, 5), 0, 90, 150);

    expect(await minutes(DateTime(2026, 10, 1), DateTime(2026, 11, 1)), {
      '5:0': 120,
    });
  });

  test('leaves out days outside the range and the end day itself', () async {
    await add(DateTime(2026, 9, 30), 0, 60, 120);
    await add(DateTime(2026, 10, 1), 0, 60, 120);
    await add(DateTime(2026, 11, 1), 0, 60, 120);

    expect(await minutes(DateTime(2026, 10, 1), DateTime(2026, 11, 1)), {
      '1:0': 60,
    });
  });

  test('leaves out skipped events and keeps completed ones', () async {
    await add(
      DateTime(2026, 10, 5),
      0,
      60,
      120,
      status: EventStatus.skipped.dbIndex,
    );
    await add(
      DateTime(2026, 10, 6),
      1,
      60,
      120,
      status: EventStatus.completed.dbIndex,
    );

    expect(await minutes(DateTime(2026, 10, 1), DateTime(2026, 11, 1)), {
      '6:1': 60,
    });
  });

  test('an empty range is an empty list', () async {
    expect(
      await minutes(DateTime(2026, 10, 1), DateTime(2026, 11, 1)),
      isEmpty,
    );
  });

  test('emits again when an event is added', () async {
    final seen = <int>[];
    final subscription = db.eventDao
        .watchToneMinutes(DateTime(2026, 10, 1), DateTime(2026, 11, 1))
        .listen((rows) => seen.add(rows.length));
    addTearDown(subscription.cancel);

    await pumpEventQueue();
    await add(DateTime(2026, 10, 5), 0, 60, 120);
    await pumpEventQueue();

    expect(seen.first, 0);
    expect(seen.last, 1);
  });
}
```

- [ ] **Step 2: Run the tests to see them fail**

```bash
# expect: FAIL — deleteById has no `now` parameter, watchToneMinutes does not exist
flutter test test/data/event_dao_skip_test.dart test/data/event_dao_minutes_test.dart
```

- [ ] **Step 3: Write the code**

**Replace `lib/data/daos/event_dao.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:energy_clock/core/event_status.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/tables/events_table.dart';
import 'package:energy_clock/data/tables/sessions_table.dart';

part 'event_dao.g.dart';

@DriftAccessor(tables: [Events, Sessions])
class EventDao extends DatabaseAccessor<AppDatabase> with _$EventDaoMixin {
  EventDao(super.attachedDatabase);

  static final int _skipped = EventStatus.skipped.dbIndex;

  /// One day's events in start order. A deleted occurrence of a series is kept
  /// as a skipped row (spec §4.3); it is a tombstone, never an event, so every
  /// query here leaves it out.
  SimpleSelectStatement<$EventsTable, EventRow> _dayQuery(DateTime day) =>
      select(events)
        ..where((row) => row.date.equals(day) & row.status.isNotValue(_skipped))
        ..orderBy([
          (row) => OrderingTerm(expression: row.startMinute),
          (row) => OrderingTerm(expression: row.id),
        ]);

  Stream<List<EventRow>> watchDay(DateTime day) => _dayQuery(day).watch();

  Future<List<EventRow>> eventsForDay(DateTime day) => _dayQuery(day).get();

  Future<int> insertEvent(EventsCompanion entry) => into(events).insert(entry);

  Future<void> updateTimes({
    required int id,
    required int startMinute,
    required int endMinute,
    required DateTime updatedAt,
  }) {
    return (update(events)..where((row) => row.id.equals(id))).write(
      EventsCompanion(
        startMinute: Value(startMinute),
        endMinute: Value(endMinute),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  Future<void> updateDetails({
    required int id,
    required String title,
    required int toneIndex,
    required DateTime updatedAt,
  }) {
    return (update(events)..where((row) => row.id.equals(id))).write(
      EventsCompanion(
        title: Value(title),
        toneIndex: Value(toneIndex),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  /// Deletes the event and every session timed on it, so no session is left
  /// pointing at an event that is gone.
  ///
  /// An occurrence of a recurring series is not removed but marked skipped:
  /// the series would otherwise create it again the next time its day is
  /// opened. [now] stamps the skipped row's `updatedAt`.
  Future<void> deleteById(int id, {DateTime? now}) {
    return transaction(() async {
      final row = await (select(
        events,
      )..where((e) => e.id.equals(id))).getSingleOrNull();
      if (row == null) return;

      await (delete(sessions)..where((s) => s.eventId.equals(id))).go();
      if (row.seriesId == null) {
        await (delete(events)..where((e) => e.id.equals(id))).go();
      } else {
        await (update(events)..where((e) => e.id.equals(id))).write(
          EventsCompanion(
            status: Value(_skipped),
            updatedAt: Value.absentIfNull(now),
          ),
        );
      }
    });
  }

  /// Distinct (date, tone) pairs for dates in [from, toExclusive). Feeds the
  /// week strip's dots without loading any events.
  Stream<List<({DateTime date, int toneIndex})>> watchToneDays(
    DateTime from,
    DateTime toExclusive,
  ) {
    final query = selectOnly(events, distinct: true)
      ..addColumns([events.date, events.toneIndex])
      ..where(
        events.date.isBiggerOrEqualValue(from) &
            events.date.isSmallerThanValue(toExclusive) &
            events.status.isNotValue(_skipped),
      );
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          (
            date: row.read(events.date)!,
            toneIndex: row.read(events.toneIndex)!,
          ),
      ],
    );
  }

  /// Planned minutes per tone for each date in [from, toExclusive): one row for
  /// every (date, tone) that has events. Feeds the Calendar's month rings with
  /// one grouped query. Overlapping events count twice, because overlap is
  /// extra load.
  Stream<List<({DateTime date, int toneIndex, int minutes})>> watchToneMinutes(
    DateTime from,
    DateTime toExclusive,
  ) {
    final minutes = (events.endMinute - events.startMinute).sum();
    final query = selectOnly(events)
      ..addColumns([events.date, events.toneIndex, minutes])
      ..where(
        events.date.isBiggerOrEqualValue(from) &
            events.date.isSmallerThanValue(toExclusive) &
            events.status.isNotValue(_skipped),
      )
      ..groupBy([events.date, events.toneIndex]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          (
            date: row.read(events.date)!,
            toneIndex: row.read(events.toneIndex)!,
            minutes: row.read(minutes) ?? 0,
          ),
      ],
    );
  }
}
```

**Edit `lib/features/clock/data/event_repository.dart`**

Replace:

```dart
  Future<void> deleteEvent(int id) => _dao.deleteById(id);
```

With:

```dart
  Future<void> deleteEvent(int id) => _dao.deleteById(id, now: _clock());
```

- [ ] **Step 4: Regenerate the DAO code and run the tests**

```bash
# expect: PASS — 13 new tests; the DAO's existing tests and the whole suite stay green
DART="$(dirname "$(which flutter)")/dart"
"$DART" run build_runner build --delete-conflicting-outputs
flutter test test/data && flutter analyze && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib/data lib/features/clock/data/event_repository.dart test/data
git commit -m "feat: skipped events stay hidden; month tone minutes query

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: The series DAO and the materialiser

Spec §4.3, "the single most important simplification in the design": a recurring series is **expanded into ordinary `events` rows**, one per day, so that nothing else in the app contains recurrence logic. `SeriesMaterialiser.materialise(from, toExclusive)` is the one function that does it. It is idempotent: for each day a series covers, it creates the occurrence only if no row for that `(series, day)` exists yet. Skipped rows count as existing, which is exactly what stops a deleted occurrence coming back; an occurrence the person moved or renamed is left alone.

Two decisions the spec leaves open:

- **A fourth ring.** If a series occurrence would need a fourth overlapping ring on a day that is already full, it is **not created** on that day (the dial can only draw three). It is tried again the next time the day is read, so it appears as soon as there is room.
- **Past days.** The materialiser fills any day it is asked about, past ones included, because a series that was running on a day nobody opened still planned that day.

`SeriesDao` is the data access for it, and for the series edits of Task 6. `EventSeriesRowRule` turns a stored series row into a `RecurrenceRule`.

**Files:**
- Create: `lib/data/daos/series_dao.dart`, `lib/data/models/series_row_rule.dart`, `lib/data/repositories/series_materialiser.dart`, the generated `lib/data/daos/series_dao.g.dart`
- Modify: `lib/data/database.dart`, the generated `lib/data/database.g.dart`
- Test: `test/data/series_dao_test.dart`, `test/data/series_materialiser_test.dart`

**Interfaces:**
- Consumes: `RecurrenceRule`, `occurrenceDates` (Task 1); `wouldOverflowRings` from `lib/core/geometry/ring_layout.dart`; `startOfDay`, `nextDay` from `lib/core/time/day_time.dart`.
- Produces: `AppDatabase.seriesDao`; `SeriesDao` with `insertSeries(EventSeriesCompanion) → Future<int>`, `seriesById(int) → Future<EventSeriesRow?>`, `seriesCovering(DateTime from, DateTime toExclusive) → Future<List<EventSeriesRow>>`, `setValidUntil(int id, DateTime? validUntil)`, `deleteSeries(int id)`, `occurrenceKeys(from, toExclusive) → Future<Set<({int seriesId, DateTime date})>>`, `liveEventsBetween(from, toExclusive) → Future<List<EventRow>>`, `eventById(int) → Future<EventRow?>`, `insertEvent(EventsCompanion) → Future<int>`, `rewriteEvent({id, title, toneIndex, startMinute, endMinute, seriesId, updatedAt})`, `deleteOccurrencesFrom(int seriesId, DateTime from)`, `deleteEventAndSessions(int id)`, `inTransaction<T>(Future<T> Function())`; extension `EventSeriesRowRule.rule` on `EventSeriesRow`; `SeriesMaterialiser(SeriesDao, {DateTime Function()? clock})` with `materialise(DateTime from, DateTime toExclusive)` and `materialiseDay(DateTime day)`.

- [ ] **Step 1: Write the failing tests**

**Create `test/data/series_dao_test.dart`**

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:energy_clock/core/event_status.dart';
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/models/series_row_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 10, 1, 9);

  Future<int> addSeries({required DateTime validFrom, RecurrenceRule? rule}) {
    final used = rule ?? RecurrenceRule.daily();
    return db.seriesDao.insertSeries(
      EventSeriesCompanion.insert(
        title: 'Standup',
        toneIndex: 2,
        startMinute: 540,
        endMinute: 570,
        recurrenceKind: used.kind.dbIndex,
        weekdayMask: Value(used.weekdayMask),
        validFrom: validFrom,
        validUntil: Value(used.until),
        createdAt: now,
      ),
    );
  }

  Future<int> addEvent(
    DateTime date, {
    int? seriesId,
    int status = 0,
    int start = 540,
  }) {
    return db.seriesDao.insertEvent(
      EventsCompanion.insert(
        seriesId: Value(seriesId),
        date: date,
        title: 'Standup',
        toneIndex: 2,
        startMinute: start,
        endMinute: start + 30,
        status: Value(status),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('a stored series reads back as its rule', () async {
    final id = await addSeries(
      validFrom: DateTime(2026, 10, 5),
      rule: RecurrenceRule.custom({1, 3}, until: DateTime(2026, 12, 31)),
    );

    final row = await db.seriesDao.seriesById(id);
    expect(
      row!.rule,
      RecurrenceRule.custom({1, 3}, until: DateTime(2026, 12, 31)),
    );
    expect(row.validFrom, DateTime(2026, 10, 5));
    expect(await db.seriesDao.seriesById(99), isNull);
  });

  group('seriesCovering', () {
    test('finds series that can have a day in the range', () async {
      final open = await addSeries(validFrom: DateTime(2026, 10, 1));
      final ended = await addSeries(
        validFrom: DateTime(2026, 9, 1),
        rule: RecurrenceRule.daily(until: DateTime(2026, 10, 9)),
      );
      await addSeries(validFrom: DateTime(2026, 11, 1));

      final covering = await db.seriesDao.seriesCovering(
        DateTime(2026, 10, 10),
        DateTime(2026, 10, 17),
      );
      expect(covering.map((row) => row.id), [open]);

      final early = await db.seriesDao.seriesCovering(
        DateTime(2026, 10, 9),
        DateTime(2026, 10, 10),
      );
      expect(early.map((row) => row.id), [open, ended]);
    });

    test(
      'a series starting on the last day of the range is included',
      () async {
        final id = await addSeries(validFrom: DateTime(2026, 10, 16));
        final covering = await db.seriesDao.seriesCovering(
          DateTime(2026, 10, 10),
          DateTime(2026, 10, 17),
        );
        expect(covering.map((row) => row.id), [id]);
      },
    );
  });

  test('setValidUntil ends a series and null reopens it', () async {
    final id = await addSeries(validFrom: DateTime(2026, 10, 1));

    await db.seriesDao.setValidUntil(id, DateTime(2026, 10, 20));
    expect(
      (await db.seriesDao.seriesById(id))!.validUntil,
      DateTime(2026, 10, 20),
    );

    await db.seriesDao.setValidUntil(id, null);
    expect((await db.seriesDao.seriesById(id))!.validUntil, isNull);
  });

  test('deleteSeries removes the row', () async {
    final id = await addSeries(validFrom: DateTime(2026, 10, 1));
    await db.seriesDao.deleteSeries(id);
    expect(await db.seriesDao.seriesById(id), isNull);
  });

  test(
    'occurrenceKeys includes skipped rows and leaves one-offs out',
    () async {
      final id = await addSeries(validFrom: DateTime(2026, 10, 1));
      await addEvent(DateTime(2026, 10, 5), seriesId: id);
      await addEvent(
        DateTime(2026, 10, 6),
        seriesId: id,
        status: EventStatus.skipped.dbIndex,
      );
      await addEvent(DateTime(2026, 10, 7));
      await addEvent(DateTime(2026, 10, 20), seriesId: id);

      final keys = await db.seriesDao.occurrenceKeys(
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 15),
      );
      expect(keys, {
        (seriesId: id, date: DateTime(2026, 10, 5)),
        (seriesId: id, date: DateTime(2026, 10, 6)),
      });
    },
  );

  test('liveEventsBetween leaves out skipped rows and other days', () async {
    await addEvent(DateTime(2026, 10, 5));
    await addEvent(DateTime(2026, 10, 5), status: EventStatus.skipped.dbIndex);
    await addEvent(DateTime(2026, 10, 20));

    final rows = await db.seriesDao.liveEventsBetween(
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 15),
    );
    expect(rows, hasLength(1));
  });

  test(
    'rewriteEvent changes the fields and can detach from the series',
    () async {
      final id = await addSeries(validFrom: DateTime(2026, 10, 1));
      final eventId = await addEvent(DateTime(2026, 10, 5), seriesId: id);

      await db.seriesDao.rewriteEvent(
        id: eventId,
        title: 'Planning',
        toneIndex: 0,
        startMinute: 600,
        endMinute: 660,
        seriesId: null,
        updatedAt: DateTime(2026, 10, 5, 8),
      );

      final row = (await db.seriesDao.eventById(eventId))!;
      expect(row.title, 'Planning');
      expect(row.toneIndex, 0);
      expect(row.startMinute, 600);
      expect(row.endMinute, 660);
      expect(row.seriesId, isNull);
      expect(row.updatedAt, DateTime(2026, 10, 5, 8));
    },
  );

  test(
    'deleteOccurrencesFrom removes that day and later, and their sessions',
    () async {
      final id = await addSeries(validFrom: DateTime(2026, 10, 1));
      final other = await addSeries(validFrom: DateTime(2026, 10, 1));
      final before = await addEvent(DateTime(2026, 10, 4), seriesId: id);
      final onDay = await addEvent(DateTime(2026, 10, 5), seriesId: id);
      await addEvent(DateTime(2026, 10, 6), seriesId: id, status: 2);
      await addEvent(DateTime(2026, 10, 6), seriesId: other);
      await addEvent(DateTime(2026, 10, 5));
      await db
          .into(db.sessions)
          .insert(
            SessionsCompanion.insert(
              eventId: onDay,
              startedAt: now,
              plannedSeconds: 1800,
            ),
          );

      await db.seriesDao.deleteOccurrencesFrom(id, DateTime(2026, 10, 5));

      final rows = await db.select(db.events).get();
      expect(rows.where((row) => row.seriesId == id).map((row) => row.id), [
        before,
      ]);
      expect(rows.where((row) => row.seriesId == other), hasLength(1));
      expect(rows.where((row) => row.seriesId == null), hasLength(1));
      expect(await db.select(db.sessions).get(), isEmpty);
    },
  );

  test('deleteEventAndSessions removes the row for good', () async {
    final id = await addSeries(validFrom: DateTime(2026, 10, 1));
    final occurrence = await addEvent(DateTime(2026, 10, 5), seriesId: id);
    final keep = await addEvent(DateTime(2026, 10, 5), seriesId: id);
    await db
        .into(db.sessions)
        .insert(
          SessionsCompanion.insert(
            eventId: occurrence,
            startedAt: now,
            plannedSeconds: 1800,
          ),
        );

    await db.seriesDao.deleteEventAndSessions(occurrence);

    final rows = await db.select(db.events).get();
    expect(rows.map((row) => row.id), [keep]);
    expect(await db.select(db.sessions).get(), isEmpty);
  });
}
```

**Create `test/data/series_materialiser_test.dart`**

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:energy_clock/core/event_status.dart';
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/series_materialiser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SeriesMaterialiser materialiser;

  final created = DateTime(2026, 10, 1, 9);
  final monday = DateTime(2026, 10, 5);
  final nextMonday = DateTime(2026, 10, 12);

  Future<int> addSeries({
    required DateTime validFrom,
    RecurrenceRule? rule,
    String title = 'Standup',
    int tone = 2,
    int start = 540,
    int end = 570,
  }) {
    final used = rule ?? RecurrenceRule.daily();
    return db.seriesDao.insertSeries(
      EventSeriesCompanion.insert(
        title: title,
        toneIndex: tone,
        startMinute: start,
        endMinute: end,
        recurrenceKind: used.kind.dbIndex,
        weekdayMask: Value(used.weekdayMask),
        validFrom: validFrom,
        validUntil: Value(used.until),
        createdAt: created,
      ),
    );
  }

  Future<int> addEvent(
    DateTime date, {
    int? seriesId,
    int status = 0,
    int start = 540,
    int end = 600,
  }) {
    return db.seriesDao.insertEvent(
      EventsCompanion.insert(
        seriesId: Value(seriesId),
        date: date,
        title: 'Other',
        toneIndex: 0,
        startMinute: start,
        endMinute: end,
        status: Value(status),
        createdAt: created,
        updatedAt: created,
      ),
    );
  }

  Future<List<EventRow>> rows() => db.select(db.events).get();

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    materialiser = SeriesMaterialiser(db.seriesDao, clock: () => created);
  });

  tearDown(() async {
    await db.close();
  });

  test('a daily series becomes one event per day of the range', () async {
    final id = await addSeries(validFrom: monday);

    await materialiser.materialise(monday, nextMonday);

    final events = await rows();
    expect(events, hasLength(7));
    expect(events.every((row) => row.seriesId == id), isTrue);
    expect(events.map((row) => row.date.day).toList()..sort(), [
      5,
      6,
      7,
      8,
      9,
      10,
      11,
    ]);
  });

  test('the events carry the series fields and start planned', () async {
    await addSeries(
      validFrom: monday,
      title: 'Deep work',
      tone: 0,
      start: 600,
      end: 720,
    );

    await materialiser.materialiseDay(monday);

    final event = (await rows()).single;
    expect(event.title, 'Deep work');
    expect(event.toneIndex, 0);
    expect(event.startMinute, 600);
    expect(event.endMinute, 720);
    expect(event.status, EventStatus.planned.dbIndex);
    expect(event.date, monday);
    expect(event.createdAt, created);
    expect(event.updatedAt, created);
  });

  test('running it again changes nothing', () async {
    await addSeries(validFrom: monday);

    await materialiser.materialise(monday, nextMonday);
    await materialiser.materialise(monday, nextMonday);
    await materialiser.materialiseDay(DateTime(2026, 10, 7));

    expect(await rows(), hasLength(7));
  });

  test('a weekdays series skips the weekend', () async {
    await addSeries(validFrom: monday, rule: RecurrenceRule.weekdays());

    await materialiser.materialise(monday, nextMonday);

    expect((await rows()).map((row) => row.date.weekday).toSet(), {
      1,
      2,
      3,
      4,
      5,
    });
  });

  test('a custom series gives only its days', () async {
    await addSeries(
      validFrom: monday,
      rule: RecurrenceRule.custom({DateTime.tuesday, DateTime.thursday}),
    );

    await materialiser.materialise(monday, nextMonday);

    expect((await rows()).map((row) => row.date.day).toList()..sort(), [6, 8]);
  });

  test(
    'nothing is created before the series starts or after it ends',
    () async {
      await addSeries(
        validFrom: DateTime(2026, 10, 7),
        rule: RecurrenceRule.daily(until: DateTime(2026, 10, 9)),
      );

      await materialiser.materialise(monday, nextMonday);

      expect((await rows()).map((row) => row.date.day).toList()..sort(), [
        7,
        8,
        9,
      ]);
    },
  );

  test('a deleted occurrence stays deleted', () async {
    final id = await addSeries(validFrom: monday);
    await materialiser.materialise(monday, nextMonday);
    final tuesday = (await rows()).firstWhere((row) => row.date.day == 6);

    await db.eventDao.deleteById(tuesday.id, now: created);
    await materialiser.materialise(monday, nextMonday);

    final events = await rows();
    expect(events, hasLength(7));
    expect(
      events.singleWhere((row) => row.date.day == 6).status,
      EventStatus.skipped.dbIndex,
    );
    expect(await db.eventDao.eventsForDay(DateTime(2026, 10, 6)), isEmpty);
    expect(events.every((row) => row.seriesId == id), isTrue);
  });

  test('an occurrence the person changed is left alone', () async {
    await addSeries(validFrom: monday);
    await materialiser.materialiseDay(monday);
    final event = (await rows()).single;
    await db.eventDao.updateTimes(
      id: event.id,
      startMinute: 900,
      endMinute: 960,
      updatedAt: created,
    );

    await materialiser.materialiseDay(monday);

    final events = await rows();
    expect(events, hasLength(1));
    expect(events.single.startMinute, 900);
  });

  test('a completed occurrence is not duplicated', () async {
    await addSeries(validFrom: monday);
    await materialiser.materialiseDay(monday);
    final event = (await rows()).single;
    await db.sessionDao.setEventStatus(
      eventId: event.id,
      status: EventStatus.completed.dbIndex,
      updatedAt: created,
    );

    await materialiser.materialiseDay(monday);

    expect(await rows(), hasLength(1));
  });

  test('two series on one day each get their event', () async {
    await addSeries(validFrom: monday, title: 'A', start: 540, end: 570);
    await addSeries(validFrom: monday, title: 'B', start: 600, end: 660);

    await materialiser.materialiseDay(monday);

    expect((await rows()).map((row) => row.title).toSet(), {'A', 'B'});
  });

  test('an occurrence that would need a fourth ring waits for room', () async {
    for (var i = 0; i < 3; i++) {
      await addEvent(monday);
    }
    await addSeries(validFrom: monday, start: 560, end: 620);

    await materialiser.materialise(monday, DateTime(2026, 10, 7));

    final onMonday = (await rows()).where((row) => row.date == monday);
    expect(onMonday, hasLength(3));
    final onTuesday = (await rows()).where((row) => row.date.day == 6);
    expect(onTuesday, hasLength(1));

    // Room appears: the occurrence is created the next time the day is read.
    await db.eventDao.deleteById(onMonday.first.id, now: created);
    await materialiser.materialiseDay(monday);

    expect((await rows()).where((row) => row.date == monday), hasLength(3));
    expect(
      (await db.eventDao.eventsForDay(
        monday,
      )).where((row) => row.seriesId != null),
      hasLength(1),
    );
  });

  test('an occurrence is never put in over the ring limit', () async {
    // Four series at the same time would need four rings. Only the three
    // oldest are created.
    await addSeries(validFrom: monday, title: 'A');
    await addSeries(validFrom: monday, title: 'B');
    await addSeries(validFrom: monday, title: 'C');
    await addSeries(validFrom: monday, title: 'D');

    await materialiser.materialiseDay(monday);

    expect(await rows(), hasLength(3));
  });

  test('past days are filled like any other', () async {
    await addSeries(validFrom: DateTime(2026, 9, 1));

    await materialiser.materialise(
      DateTime(2026, 9, 28),
      DateTime(2026, 10, 1),
    );

    expect(await rows(), hasLength(3));
  });

  test('an empty or backwards range does nothing', () async {
    await addSeries(validFrom: monday);

    await materialiser.materialise(monday, monday);
    await materialiser.materialise(nextMonday, monday);

    expect(await rows(), isEmpty);
  });

  test('a range with no series does nothing', () async {
    await materialiser.materialise(monday, nextMonday);
    expect(await rows(), isEmpty);
  });

  test('days outside the range are not touched', () async {
    await addSeries(validFrom: monday);

    await materialiser.materialise(monday, DateTime(2026, 10, 7));

    expect((await rows()).map((row) => row.date.day).toList()..sort(), [5, 6]);
  });

  test('a series stored with no repeat creates nothing', () async {
    await addSeries(validFrom: monday, rule: const RecurrenceRule.none());

    await materialiser.materialise(monday, nextMonday);

    expect(await rows(), isEmpty);
  });
}
```

- [ ] **Step 2: Run the tests to see them fail**

```bash
# expect: FAIL — seriesDao, SeriesMaterialiser and series_row_rule.dart do not exist yet
flutter test test/data/series_dao_test.dart test/data/series_materialiser_test.dart
```

- [ ] **Step 3: Write the code**

**Create `lib/data/models/series_row_rule.dart`**

```dart
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/data/database.dart';

/// Reads a stored series back as the rule it follows. The series' last day
/// (`validUntil`) is the rule's end day.
extension EventSeriesRowRule on EventSeriesRow {
  RecurrenceRule get rule => RecurrenceRule.fromStored(
    kindIndex: recurrenceKind,
    weekdayMask: weekdayMask,
    until: validUntil,
  );
}
```

**Create `lib/data/daos/series_dao.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:energy_clock/core/event_status.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/tables/event_series_table.dart';
import 'package:energy_clock/data/tables/events_table.dart';
import 'package:energy_clock/data/tables/sessions_table.dart';

part 'series_dao.g.dart';

/// Recurring series and the events they create (spec §4.2 and §4.3).
@DriftAccessor(tables: [EventSeries, Events, Sessions])
class SeriesDao extends DatabaseAccessor<AppDatabase> with _$SeriesDaoMixin {
  SeriesDao(super.attachedDatabase);

  static final int _skipped = EventStatus.skipped.dbIndex;

  Future<int> insertSeries(EventSeriesCompanion entry) =>
      into(eventSeries).insert(entry);

  Future<EventSeriesRow?> seriesById(int id) => (select(
    eventSeries,
  )..where((row) => row.id.equals(id))).getSingleOrNull();

  /// The series that can have an occurrence somewhere in [from, toExclusive):
  /// started before the range ends, and not ended before it begins. Oldest
  /// first, so a crowded day always favours the older series.
  Future<List<EventSeriesRow>> seriesCovering(
    DateTime from,
    DateTime toExclusive,
  ) {
    return (select(eventSeries)
          ..where(
            (row) =>
                row.validFrom.isSmallerThanValue(toExclusive) &
                (row.validUntil.isNull() |
                    row.validUntil.isBiggerOrEqualValue(from)),
          )
          ..orderBy([(row) => OrderingTerm(expression: row.id)]))
        .get();
  }

  /// Ends the series after [validUntil] (that day is its last), or reopens it
  /// when [validUntil] is null.
  Future<void> setValidUntil(int id, DateTime? validUntil) {
    return (update(eventSeries)..where((row) => row.id.equals(id))).write(
      EventSeriesCompanion(validUntil: Value(validUntil)),
    );
  }

  Future<void> deleteSeries(int id) =>
      (delete(eventSeries)..where((row) => row.id.equals(id))).go();

  /// The (series, day) pair of every event a series has created in
  /// [from, toExclusive). Skipped rows are included on purpose: they are what
  /// stops a deleted occurrence being created again.
  Future<Set<({int seriesId, DateTime date})>> occurrenceKeys(
    DateTime from,
    DateTime toExclusive,
  ) async {
    final rows =
        await (select(events)..where(
              (row) =>
                  row.seriesId.isNotNull() &
                  row.date.isBiggerOrEqualValue(from) &
                  row.date.isSmallerThanValue(toExclusive),
            ))
            .get();
    return {for (final row in rows) (seriesId: row.seriesId!, date: row.date)};
  }

  /// Every event that is really on a day in [from, toExclusive), skipped rows
  /// left out. The materialiser checks ring room against these.
  Future<List<EventRow>> liveEventsBetween(
    DateTime from,
    DateTime toExclusive,
  ) {
    return (select(events)..where(
          (row) =>
              row.date.isBiggerOrEqualValue(from) &
              row.date.isSmallerThanValue(toExclusive) &
              row.status.isNotValue(_skipped),
        ))
        .get();
  }

  Future<EventRow?> eventById(int id) =>
      (select(events)..where((row) => row.id.equals(id))).getSingleOrNull();

  Future<int> insertEvent(EventsCompanion entry) => into(events).insert(entry);

  /// Rewrites one event's fields and which series it belongs to; [seriesId]
  /// null detaches it into a one-off.
  Future<void> rewriteEvent({
    required int id,
    required String title,
    required int toneIndex,
    required int startMinute,
    required int endMinute,
    required int? seriesId,
    required DateTime updatedAt,
  }) {
    return (update(events)..where((row) => row.id.equals(id))).write(
      EventsCompanion(
        title: Value(title),
        toneIndex: Value(toneIndex),
        startMinute: Value(startMinute),
        endMinute: Value(endMinute),
        seriesId: Value(seriesId),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  /// Deletes every event the series has on [from] or later, skipped rows
  /// included, together with their sessions.
  Future<void> deleteOccurrencesFrom(int seriesId, DateTime from) async {
    final rows =
        await (select(events)..where(
              (row) =>
                  row.seriesId.equals(seriesId) &
                  row.date.isBiggerOrEqualValue(from),
            ))
            .get();
    if (rows.isEmpty) return;
    final ids = [for (final row in rows) row.id];
    await (delete(sessions)..where((row) => row.eventId.isIn(ids))).go();
    await (delete(events)..where((row) => row.id.isIn(ids))).go();
  }

  /// Deletes one event and its sessions, for good, whatever it belongs to.
  Future<void> deleteEventAndSessions(int id) async {
    await (delete(sessions)..where((row) => row.eventId.equals(id))).go();
    await (delete(events)..where((row) => row.id.equals(id))).go();
  }

  /// Runs [action] in one database transaction.
  Future<T> inTransaction<T>(Future<T> Function() action) =>
      transaction(action);
}
```

**Create `lib/data/repositories/series_materialiser.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/geometry/ring_layout.dart';
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/daos/series_dao.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/models/series_row_rule.dart';

/// Expands recurring series into ordinary `events` rows (spec §4.3), so that
/// nothing downstream contains recurrence logic.
///
/// It is idempotent. For every day a series covers, an event is created only
/// if the series has no row on that day yet; a skipped row counts as a row,
/// and an occurrence the person moved or renamed is never overwritten.
///
/// A series occurrence that would need a fourth overlapping ring is not
/// created on that day (the dial can draw three). It is tried again whenever
/// the day is next materialised, so it appears as soon as there is room.
class SeriesMaterialiser {
  SeriesMaterialiser(this._dao, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SeriesDao _dao;
  final DateTime Function() _clock;

  Future<void> materialiseDay(DateTime day) =>
      materialise(day, nextDay(startOfDay(day)));

  /// Fills the days in [from, toExclusive) in one transaction.
  Future<void> materialise(DateTime from, DateTime toExclusive) {
    final start = startOfDay(from);
    final end = startOfDay(toExclusive);
    if (!start.isBefore(end)) return Future.value();

    return _dao.inTransaction(() async {
      final series = await _dao.seriesCovering(start, end);
      if (series.isEmpty) return;

      final existing = await _dao.occurrenceKeys(start, end);
      final rangesByDay = <DateTime, List<MinuteRange>>{};
      for (final row in await _dao.liveEventsBetween(start, end)) {
        rangesByDay
            .putIfAbsent(row.date, () => [])
            .add(MinuteRange(row.startMinute, row.endMinute));
      }

      final now = _clock();
      for (final row in series) {
        final range = MinuteRange(row.startMinute, row.endMinute);
        for (final date in occurrenceDates(
          rule: row.rule,
          validFrom: row.validFrom,
          from: start,
          toExclusive: end,
        )) {
          if (existing.contains((seriesId: row.id, date: date))) continue;

          final onDay = rangesByDay.putIfAbsent(date, () => []);
          if (wouldOverflowRings(existing: onDay, candidate: range)) continue;

          await _dao.insertEvent(
            EventsCompanion.insert(
              seriesId: Value(row.id),
              date: date,
              title: row.title,
              toneIndex: row.toneIndex,
              startMinute: row.startMinute,
              endMinute: row.endMinute,
              createdAt: now,
              updatedAt: now,
            ),
          );
          onDay.add(range);
        }
      }
    });
  }
}
```

**Edit `lib/data/database.dart`**

Replace:

```dart
import 'package:energy_clock/data/daos/session_dao.dart';
```

With:

```dart
import 'package:energy_clock/data/daos/series_dao.dart';
import 'package:energy_clock/data/daos/session_dao.dart';
```

Replace:

```dart
  daos: [EventDao, SettingsDao, SessionDao],
```

With:

```dart
  daos: [EventDao, SettingsDao, SessionDao, SeriesDao],
```

- [ ] **Step 4: Regenerate the Drift code and run the tests**

```bash
# expect: PASS — 27 new tests; the whole suite stays green and the analyzer is clean
DART="$(dirname "$(which flutter)")/dart"
"$DART" run build_runner build --delete-conflicting-outputs
flutter test test/data && flutter analyze && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib/data test/data
git commit -m "feat: series DAO and the materialiser that expands recurring events

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---
### Task 6: The series repository — repeat, edit "this and all future", delete "this and all future"

`SeriesRepository` is the write side of recurrence, three operations the event sheet and the detail sheet need (spec §7, "Editing an occurrence prompts 'This event' or 'This and all future'"):

- **`createRecurring`**: a new event that repeats. It writes the series and the first occurrence in one transaction.
- **`updateFromHere`**: "this and all future". The edited event keeps its row; the series is **split**. The old series ends the day before, its later occurrences are deleted, and a new series starts on this day with the new values. Earlier days keep the old values: history is not rewritten. The same call turns a one-off event into a repeating one (it has no old series to end), and a rule of "never" turns a repeating event back into a one-off.
- **`deleteFromHere`**: removes this occurrence and every later one, and ends the series the day before (or removes the series if this was its first day).

Deleting just **one** occurrence is `EventRepository.deleteEvent`, which since Task 4 skips a series occurrence instead of removing it.

Decisions: the split replaces the Aug 23 spec's "rewrite the `event_series` row and delete not-yet-past rows", which would also have rewritten the meaning of days already lived; a deleted-occurrence tombstone on a later day is deleted by "this and all future", so a day the person had cleared fills again under the new series (the spec says the same: later rows "re-expand on next view with the new values").

`RingOverflowException` moves from the Clock feature's repository file to `lib/core/geometry/ring_layout.dart` (it is about ring layout, and the data layer may not import a feature). `event_repository.dart` re-exports it, so no existing import changes.

**Files:**
- Create: `lib/data/repositories/series_repository.dart`
- Modify: `lib/core/geometry/ring_layout.dart`, `lib/features/clock/data/event_repository.dart`
- Test: `test/data/series_repository_test.dart`

**Interfaces:**
- Consumes: `SeriesDao`, `SeriesMaterialiser` (Task 5); `RecurrenceRule` (Task 1); `MinuteRange`, `Tone`.
- Produces: `RingOverflowException` (now in `ring_layout.dart`); `SeriesRepository` with `ruleFor(int seriesId) → Future<RecurrenceRule?>`, `createRecurring({day, title, tone, range, rule}) → Future<int>` (the new event's id), `updateFromHere({eventId, title, tone, range, rule}) → Future<void>`, `deleteFromHere(int eventId) → Future<void>`; `DriftSeriesRepository(SeriesDao, {DateTime Function()? clock})`. `createRecurring` and `updateFromHere` throw `RingOverflowException` when the event's own day cannot take it, and then write nothing.

- [ ] **Step 1: Write the failing test**

**Create `test/data/series_repository_test.dart`**

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:energy_clock/core/event_status.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/geometry/ring_layout.dart';
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/models/series_row_rule.dart';
import 'package:energy_clock/data/repositories/series_materialiser.dart';
import 'package:energy_clock/data/repositories/series_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SeriesRepository repository;
  late SeriesMaterialiser materialiser;

  final now = DateTime(2026, 10, 5, 8);
  final monday = DateTime(2026, 10, 5);
  final tuesday = DateTime(2026, 10, 6);
  final wednesday = DateTime(2026, 10, 7);
  final friday = DateTime(2026, 10, 9);
  final nextMonday = DateTime(2026, 10, 12);

  /// Every event row, earliest day first (skipped rows included).
  Future<List<EventRow>> rows() async {
    final all = await db.select(db.events).get();
    all.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
    return all;
  }

  Future<EventRow> rowOn(DateTime day) async =>
      (await rows()).singleWhere((row) => row.date == day);

  /// Creates "Standup" every day from Monday and fills the week.
  Future<int> createDailyWeek() async {
    final eventId = await repository.createRecurring(
      day: monday,
      title: 'Standup',
      tone: Tone.inbox,
      range: const MinuteRange(540, 570),
      rule: RecurrenceRule.daily(),
    );
    await materialiser.materialise(monday, nextMonday);
    return (await db.seriesDao.eventById(eventId))!.seriesId!;
  }

  Future<int> addOneOff(DateTime day, int start, int end) {
    return db.seriesDao.insertEvent(
      EventsCompanion.insert(
        date: day,
        title: 'One-off',
        toneIndex: 0,
        startMinute: start,
        endMinute: end,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftSeriesRepository(db.seriesDao, clock: () => now);
    materialiser = SeriesMaterialiser(db.seriesDao, clock: () => now);
  });

  tearDown(() async {
    await db.close();
  });

  group('createRecurring', () {
    test('writes the series and its first event', () async {
      final eventId = await repository.createRecurring(
        day: DateTime(2026, 10, 5, 17, 30),
        title: 'Standup',
        tone: Tone.inbox,
        range: const MinuteRange(540, 570),
        rule: RecurrenceRule.weekdays(),
      );

      final events = await rows();
      expect(events, hasLength(1));
      expect(events.single.id, eventId);
      expect(events.single.date, monday);
      expect(events.single.status, EventStatus.planned.dbIndex);

      final series = (await db.seriesDao.seriesById(events.single.seriesId!))!;
      expect(series.title, 'Standup');
      expect(series.toneIndex, Tone.inbox.dbIndex);
      expect(series.startMinute, 540);
      expect(series.endMinute, 570);
      expect(series.rule, RecurrenceRule.weekdays());
      expect(series.validFrom, monday);
      expect(series.createdAt, now);
    });

    test('the rest of the series appears when its days are filled', () async {
      final seriesId = await createDailyWeek();

      final events = await rows();
      expect(events, hasLength(7));
      expect(events.every((row) => row.seriesId == seriesId), isTrue);
    });

    test(
      'the first event exists even if its weekday is not in the rule',
      () async {
        await repository.createRecurring(
          day: monday,
          title: 'Gym',
          tone: Tone.life,
          range: const MinuteRange(1020, 1080),
          rule: RecurrenceRule.custom({DateTime.tuesday}),
        );
        await materialiser.materialise(monday, nextMonday);

        expect((await rows()).map((row) => row.date.day), [5, 6]);
      },
    );

    test('keeps the end day of the rule', () async {
      final eventId = await repository.createRecurring(
        day: monday,
        title: 'Standup',
        tone: Tone.inbox,
        range: const MinuteRange(540, 570),
        rule: RecurrenceRule.daily(until: DateTime(2026, 10, 20)),
      );

      final seriesId = (await db.seriesDao.eventById(eventId))!.seriesId!;
      expect(
        (await db.seriesDao.seriesById(seriesId))!.validUntil,
        DateTime(2026, 10, 20),
      );
    });

    test('an end day before the first day is moved up to it', () async {
      final eventId = await repository.createRecurring(
        day: monday,
        title: 'Standup',
        tone: Tone.inbox,
        range: const MinuteRange(540, 570),
        rule: RecurrenceRule.daily(until: DateTime(2026, 10, 1)),
      );

      final seriesId = (await db.seriesDao.eventById(eventId))!.seriesId!;
      expect((await db.seriesDao.seriesById(seriesId))!.validUntil, monday);
    });

    test('refuses a fourth ring and writes nothing', () async {
      for (var i = 0; i < 3; i++) {
        await addOneOff(monday, 540, 600);
      }

      await expectLater(
        repository.createRecurring(
          day: monday,
          title: 'Standup',
          tone: Tone.inbox,
          range: const MinuteRange(560, 620),
          rule: RecurrenceRule.daily(),
        ),
        throwsA(isA<RingOverflowException>()),
      );

      expect(await rows(), hasLength(3));
      expect(await db.select(db.eventSeries).get(), isEmpty);
    });
  });

  test(
    'ruleFor returns the stored rule, and null for a missing series',
    () async {
      final seriesId = await createDailyWeek();

      expect(await repository.ruleFor(seriesId), RecurrenceRule.daily());
      expect(await repository.ruleFor(999), isNull);
    },
  );

  group('updateFromHere', () {
    test('splits the series: earlier days keep the old values', () async {
      final oldSeries = await createDailyWeek();
      final onWednesday = await rowOn(wednesday);

      await repository.updateFromHere(
        eventId: onWednesday.id,
        title: 'Planning',
        tone: Tone.focus,
        range: const MinuteRange(600, 660),
        rule: RecurrenceRule.daily(),
      );
      await materialiser.materialise(monday, nextMonday);

      final events = await rows();
      expect(events, hasLength(7));
      for (final row in events.where((row) => row.date.day < 7)) {
        expect(row.title, 'Standup');
        expect(row.seriesId, oldSeries);
      }
      final newSeries = events[2].seriesId!;
      expect(newSeries, isNot(oldSeries));
      for (final row in events.where((row) => row.date.day >= 7)) {
        expect(row.title, 'Planning');
        expect(row.toneIndex, Tone.focus.dbIndex);
        expect(row.startMinute, 600);
        expect(row.endMinute, 660);
        expect(row.seriesId, newSeries);
      }
      expect(events[2].id, onWednesday.id);

      expect((await db.seriesDao.seriesById(oldSeries))!.validUntil, tuesday);
      final created = (await db.seriesDao.seriesById(newSeries))!;
      expect(created.validFrom, wednesday);
      expect(created.title, 'Planning');
    });

    test('a later deleted day comes back under the new series', () async {
      await createDailyWeek();
      await db.eventDao.deleteById((await rowOn(friday)).id, now: now);
      final onWednesday = await rowOn(wednesday);

      await repository.updateFromHere(
        eventId: onWednesday.id,
        title: 'Planning',
        tone: Tone.focus,
        range: const MinuteRange(600, 660),
        rule: RecurrenceRule.daily(),
      );
      await materialiser.materialise(monday, nextMonday);

      final onFriday = await db.eventDao.eventsForDay(friday);
      expect(onFriday.single.title, 'Planning');
    });

    test(
      'a rule of never keeps this event alone and removes the later ones',
      () async {
        final oldSeries = await createDailyWeek();
        final onWednesday = await rowOn(wednesday);

        await repository.updateFromHere(
          eventId: onWednesday.id,
          title: 'Once',
          tone: Tone.life,
          range: const MinuteRange(700, 760),
          rule: const RecurrenceRule.none(),
        );
        await materialiser.materialise(monday, nextMonday);

        final events = await rows();
        expect(events.map((row) => row.date.day), [5, 6, 7]);
        expect(events.last.title, 'Once');
        expect(events.last.seriesId, isNull);
        expect((await db.seriesDao.seriesById(oldSeries))!.validUntil, tuesday);
      },
    );

    test('editing the first day replaces the series', () async {
      final oldSeries = await createDailyWeek();
      final onMonday = await rowOn(monday);

      await repository.updateFromHere(
        eventId: onMonday.id,
        title: 'Planning',
        tone: Tone.focus,
        range: const MinuteRange(600, 660),
        rule: RecurrenceRule.daily(),
      );

      expect(await db.seriesDao.seriesById(oldSeries), isNull);
      final series = await db.select(db.eventSeries).get();
      expect(series, hasLength(1));
      expect(series.single.title, 'Planning');
      expect(series.single.validFrom, monday);
    });

    test('changing the rule changes which days fill', () async {
      await createDailyWeek();
      final onWednesday = await rowOn(wednesday);

      await repository.updateFromHere(
        eventId: onWednesday.id,
        title: 'Standup',
        tone: Tone.inbox,
        range: const MinuteRange(540, 570),
        rule: RecurrenceRule.weekdays(),
      );
      await materialiser.materialise(monday, nextMonday);

      expect((await rows()).map((row) => row.date.day), [5, 6, 7, 8, 9]);
    });

    test('turns a one-off event into a repeating one', () async {
      final eventId = await addOneOff(wednesday, 540, 600);

      await repository.updateFromHere(
        eventId: eventId,
        title: 'Weekly review',
        tone: Tone.focus,
        range: const MinuteRange(540, 600),
        rule: RecurrenceRule.custom({DateTime.wednesday, DateTime.friday}),
      );
      await materialiser.materialise(monday, nextMonday);

      final events = await rows();
      expect(events.map((row) => row.date.day), [7, 9]);
      expect(events.first.id, eventId);
      expect(events.first.title, 'Weekly review');
      expect(events.first.seriesId, isNotNull);
      expect(events.first.seriesId, events.last.seriesId);
    });

    test('refuses a fourth ring and changes nothing', () async {
      final seriesId = await createDailyWeek();
      final onWednesday = await rowOn(wednesday);
      for (var i = 0; i < 3; i++) {
        await addOneOff(wednesday, 600, 700);
      }
      final before = await rows();

      await expectLater(
        repository.updateFromHere(
          eventId: onWednesday.id,
          title: 'Moved',
          tone: Tone.focus,
          range: const MinuteRange(650, 680),
          rule: RecurrenceRule.daily(),
        ),
        throwsA(isA<RingOverflowException>()),
      );

      expect(await rows(), before);
      expect((await db.seriesDao.seriesById(seriesId))!.validUntil, isNull);
    });

    test('an event that is gone is ignored', () async {
      await repository.updateFromHere(
        eventId: 999,
        title: 'Nothing',
        tone: Tone.life,
        range: const MinuteRange(540, 600),
        rule: RecurrenceRule.daily(),
      );
      expect(await db.select(db.eventSeries).get(), isEmpty);
    });

    test('the sessions of the edited event are kept', () async {
      await createDailyWeek();
      final onWednesday = await rowOn(wednesday);
      await db
          .into(db.sessions)
          .insert(
            SessionsCompanion.insert(
              eventId: onWednesday.id,
              startedAt: now,
              plannedSeconds: 1800,
              outcome: const Value(1),
            ),
          );

      await repository.updateFromHere(
        eventId: onWednesday.id,
        title: 'Planning',
        tone: Tone.focus,
        range: const MinuteRange(600, 660),
        rule: RecurrenceRule.daily(),
      );

      expect(await db.select(db.sessions).get(), hasLength(1));
    });
  });

  group('deleteFromHere', () {
    test('removes this day and later, and ends the series', () async {
      final seriesId = await createDailyWeek();
      final onWednesday = await rowOn(wednesday);

      await repository.deleteFromHere(onWednesday.id);
      await materialiser.materialise(monday, nextMonday);

      expect((await rows()).map((row) => row.date.day), [5, 6]);
      expect((await db.seriesDao.seriesById(seriesId))!.validUntil, tuesday);
    });

    test('deleting the first day removes the series', () async {
      final seriesId = await createDailyWeek();
      final onMonday = await rowOn(monday);

      await repository.deleteFromHere(onMonday.id);
      await materialiser.materialise(monday, nextMonday);

      expect(await rows(), isEmpty);
      expect(await db.seriesDao.seriesById(seriesId), isNull);
    });

    test('later deleted days go too', () async {
      await createDailyWeek();
      await db.eventDao.deleteById((await rowOn(friday)).id, now: now);

      await repository.deleteFromHere((await rowOn(wednesday)).id);

      expect((await rows()).map((row) => row.date.day), [5, 6]);
    });

    test('removes a one-off event and its sessions', () async {
      final eventId = await addOneOff(wednesday, 540, 600);
      await db
          .into(db.sessions)
          .insert(
            SessionsCompanion.insert(
              eventId: eventId,
              startedAt: now,
              plannedSeconds: 3600,
            ),
          );

      await repository.deleteFromHere(eventId);

      expect(await rows(), isEmpty);
      expect(await db.select(db.sessions).get(), isEmpty);
    });

    test('an event that is gone is ignored', () async {
      await repository.deleteFromHere(999);
      expect(await rows(), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run the test to see it fail**

```bash
# expect: FAIL — series_repository.dart does not exist yet
flutter test test/data/series_repository_test.dart
```

- [ ] **Step 3: Write the code**

**Edit `lib/core/geometry/ring_layout.dart`**

Replace:

```dart
/// True when adding [candidate] to [existing] would require a fourth ring.
```

With:

```dart
/// Thrown when a write would require a fourth overlapping ring.
class RingOverflowException implements Exception {
  const RingOverflowException();
}

/// True when adding [candidate] to [existing] would require a fourth ring.
```

**Edit `lib/features/clock/data/event_repository.dart`**

Replace:

```dart
export 'package:energy_clock/features/clock/model/calendar_event.dart';

/// Thrown when a write would require a fourth overlapping ring.
class RingOverflowException implements Exception {
  const RingOverflowException();
}
```

With:

```dart
export 'package:energy_clock/core/geometry/ring_layout.dart'
    show RingOverflowException;
export 'package:energy_clock/features/clock/model/calendar_event.dart';
```

**Create `lib/data/repositories/series_repository.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/geometry/ring_layout.dart';
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/daos/series_dao.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/models/series_row_rule.dart';

/// Writes recurring events (spec §7): making an event repeat, and editing or
/// deleting "this and all future" of a series. Deleting a single occurrence is
/// `EventRepository.deleteEvent`, which skips it.
///
/// Days are filled in by `SeriesMaterialiser`, not here: these methods change
/// the series and the one event the person is looking at, and the later days
/// follow the next time they are read.
abstract interface class SeriesRepository {
  /// The rule of the series, or null if it no longer exists.
  Future<RecurrenceRule?> ruleFor(int seriesId);

  /// Creates an event on [day] that repeats by [rule] (which must repeat), and
  /// its series, which starts on [day]. The event on [day] exists even when
  /// its weekday is not in the rule. Returns the event's id. Throws
  /// `RingOverflowException`, writing nothing, if [day] cannot take it.
  Future<int> createRecurring({
    required DateTime day,
    required String title,
    required Tone tone,
    required MinuteRange range,
    required RecurrenceRule rule,
  });

  /// "This and all future". The event keeps its row and takes the new values.
  /// If it belongs to a series, that series ends the day before and its later
  /// days are removed; if [rule] repeats, a new series starts on the event's
  /// day, so a one-off event becomes a repeating one. A rule of "never" leaves
  /// the event as a one-off. Throws `RingOverflowException`, changing nothing,
  /// if the new times do not fit the event's own day. An event that no longer
  /// exists is ignored.
  Future<void> updateFromHere({
    required int eventId,
    required String title,
    required Tone tone,
    required MinuteRange range,
    required RecurrenceRule rule,
  });

  /// Deletes the event and, if it belongs to a series, every later day of it,
  /// and ends the series the day before (or removes the series, if this was its
  /// first day). An event that no longer exists is ignored.
  Future<void> deleteFromHere(int eventId);
}

class DriftSeriesRepository implements SeriesRepository {
  DriftSeriesRepository(this._dao, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SeriesDao _dao;
  final DateTime Function() _clock;

  @override
  Future<RecurrenceRule?> ruleFor(int seriesId) async =>
      (await _dao.seriesById(seriesId))?.rule;

  @override
  Future<int> createRecurring({
    required DateTime day,
    required String title,
    required Tone tone,
    required MinuteRange range,
    required RecurrenceRule rule,
  }) {
    assert(rule.repeats, 'createRecurring needs a rule that repeats');
    final first = startOfDay(day);
    return _dao.inTransaction(() async {
      await _guardRings(day: first, range: range);
      final now = _clock();
      final seriesId = await _insertSeries(
        title: title,
        tone: tone,
        range: range,
        rule: rule,
        validFrom: first,
        now: now,
      );
      return _dao.insertEvent(
        EventsCompanion.insert(
          seriesId: Value(seriesId),
          date: first,
          title: title,
          toneIndex: tone.dbIndex,
          startMinute: range.start,
          endMinute: range.end,
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
  }

  @override
  Future<void> updateFromHere({
    required int eventId,
    required String title,
    required Tone tone,
    required MinuteRange range,
    required RecurrenceRule rule,
  }) {
    return _dao.inTransaction(() async {
      final event = await _dao.eventById(eventId);
      if (event == null) return;
      final day = event.date;
      await _guardRings(day: day, range: range, excludingId: eventId);

      final oldSeriesId = event.seriesId;
      if (oldSeriesId != null) {
        await _endBefore(oldSeriesId, day);
        // This day's row is rewritten below; only the later days go.
        await _dao.deleteOccurrencesFrom(oldSeriesId, nextDay(day));
      }

      final now = _clock();
      final newSeriesId = rule.repeats
          ? await _insertSeries(
              title: title,
              tone: tone,
              range: range,
              rule: rule,
              validFrom: day,
              now: now,
            )
          : null;
      await _dao.rewriteEvent(
        id: eventId,
        title: title,
        toneIndex: tone.dbIndex,
        startMinute: range.start,
        endMinute: range.end,
        seriesId: newSeriesId,
        updatedAt: now,
      );
    });
  }

  @override
  Future<void> deleteFromHere(int eventId) {
    return _dao.inTransaction(() async {
      final event = await _dao.eventById(eventId);
      if (event == null) return;

      final seriesId = event.seriesId;
      if (seriesId == null) {
        await _dao.deleteEventAndSessions(eventId);
        return;
      }
      await _endBefore(seriesId, event.date);
      await _dao.deleteOccurrencesFrom(seriesId, event.date);
    });
  }

  /// Ends the series the day before [day]. A series that starts on [day] (or
  /// later) has no earlier days to keep, so it is removed.
  Future<void> _endBefore(int seriesId, DateTime day) async {
    final series = await _dao.seriesById(seriesId);
    if (series == null) return;
    if (!series.validFrom.isBefore(day)) {
      await _dao.deleteSeries(seriesId);
    } else {
      await _dao.setValidUntil(seriesId, previousDay(day));
    }
  }

  Future<int> _insertSeries({
    required String title,
    required Tone tone,
    required MinuteRange range,
    required RecurrenceRule rule,
    required DateTime validFrom,
    required DateTime now,
  }) {
    final until = rule.until;
    return _dao.insertSeries(
      EventSeriesCompanion.insert(
        title: title,
        toneIndex: tone.dbIndex,
        startMinute: range.start,
        endMinute: range.end,
        recurrenceKind: rule.kind.dbIndex,
        weekdayMask: Value(rule.weekdayMask),
        validFrom: validFrom,
        // An end day before the first day would make an empty series.
        validUntil: Value(
          until != null && until.isBefore(validFrom) ? validFrom : until,
        ),
        createdAt: now,
      ),
    );
  }

  Future<void> _guardRings({
    required DateTime day,
    required MinuteRange range,
    int? excludingId,
  }) async {
    final rows = await _dao.liveEventsBetween(day, nextDay(day));
    final existing = [
      for (final row in rows)
        if (row.id != excludingId) MinuteRange(row.startMinute, row.endMinute),
    ];
    if (wouldOverflowRings(existing: existing, candidate: range)) {
      throw const RingOverflowException();
    }
  }
}
```

- [ ] **Step 4: Run the tests, the analyzer and the whole suite**

```bash
# expect: PASS — 21 new tests; analyzer clean; the whole suite stays green
flutter test test/data/series_repository_test.dart && flutter analyze && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat: series repository for repeating events and this-and-future edits

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---
### Task 7: Day templates and copy-yesterday

The other two reuse tools of spec §7, one repository for both because they are the same move: fill an empty day from another day's plan.

- **Day templates.** `saveTemplate` stores a day's events as a named template (title, tone and times, nothing else: no status, no series). `applyTemplate` creates those events on an **empty** day. Templates can be listed (newest first) and deleted.
- **Copy yesterday.** `copyDay(from, to)` duplicates one day's events onto an empty day, as ordinary one-off events that start planned (a completed event on the source day is copied as planned, and a recurring occurrence is copied as a plain event: copying a day is not a way to extend a series).

Both refuse a day that already has events (`DayNotEmptyException`): the spec does not offer a template on a non-empty day, and the repository enforces it as well as the UI. A day holding only skipped rows (deleted occurrences) counts as empty, because skipped rows are tombstones, not events. Neither needs a ring check: the source was a valid day, and the target is empty.

**Files:**
- Create: `lib/data/daos/template_dao.dart`, `lib/data/models/day_template.dart`, `lib/data/repositories/reuse_repository.dart`, the generated `lib/data/daos/template_dao.g.dart`
- Modify: `lib/data/database.dart`, the generated `lib/data/database.g.dart`
- Test: `test/data/reuse_repository_test.dart`

**Interfaces:**
- Consumes: `Tone`, `MinuteRange`, `startOfDay`; the Task 3 tables.
- Produces: `AppDatabase.templateDao`; `TemplateItem({title, tone, range})`; `DayTemplate({id, name, items})` with `eventCount`, `totalMinutes` and `tones` (fixed tone order); `EmptyDayException`; `DayNotEmptyException`; `ReuseRepository` with `watchTemplates() → Stream<List<DayTemplate>>`, `saveTemplate({name, day}) → Future<int>`, `deleteTemplate(int id)`, `applyTemplate({templateId, day}) → Future<int>` (events created), `copyDay({from, to}) → Future<int>` (events created); `DriftReuseRepository(TemplateDao, {DateTime Function()? clock})`; `maxTemplateNameLength` (60).

- [ ] **Step 1: Write the failing test**

**Create `test/data/reuse_repository_test.dart`**

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:energy_clock/core/event_status.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/reuse_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ReuseRepository repository;
  late DateTime now;

  final yesterday = DateTime(2026, 10, 6);
  final today = DateTime(2026, 10, 7);

  Future<int> addEvent(
    DateTime day, {
    String title = 'Deep work',
    int tone = 0,
    int start = 540,
    int end = 660,
    int status = 0,
    int? seriesId,
  }) {
    return db.eventDao.insertEvent(
      EventsCompanion.insert(
        seriesId: Value(seriesId),
        date: day,
        title: title,
        toneIndex: tone,
        startMinute: start,
        endMinute: end,
        status: Value(status),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<List<EventRow>> onDay(DateTime day) => db.eventDao.eventsForDay(day);

  setUp(() {
    now = DateTime(2026, 10, 7, 8);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftReuseRepository(db.templateDao, clock: () => now);
  });

  tearDown(() async {
    await db.close();
  });

  group('saveTemplate', () {
    test('stores the day as a named template', () async {
      await addEvent(yesterday);
      await addEvent(
        yesterday,
        title: 'Lunch walk',
        tone: 1,
        start: 750,
        end: 795,
      );

      final id = await repository.saveTemplate(
        name: '  Office day ',
        day: yesterday,
      );

      final templates = await repository.watchTemplates().first;
      expect(templates, hasLength(1));
      expect(templates.single.id, id);
      expect(templates.single.name, 'Office day');
      expect(templates.single.eventCount, 2);
      expect(templates.single.totalMinutes, 165);
      expect(templates.single.tones, [Tone.focus, Tone.life]);
      final items = templates.single.items;
      expect(items.map((item) => item.title), ['Deep work', 'Lunch walk']);
      expect(items.first.tone, Tone.focus);
      expect(items.first.range, const MinuteRange(540, 660));
    });

    test('leaves out skipped events and keeps the rest', () async {
      await addEvent(yesterday);
      await addEvent(
        yesterday,
        title: 'Cancelled',
        status: EventStatus.skipped.dbIndex,
        seriesId: 3,
      );

      await repository.saveTemplate(name: 'Day', day: yesterday);

      final template = (await repository.watchTemplates().first).single;
      expect(template.items.map((item) => item.title), ['Deep work']);
    });

    test('refuses a day with nothing on it', () async {
      await expectLater(
        repository.saveTemplate(name: 'Day', day: yesterday),
        throwsA(isA<EmptyDayException>()),
      );
      expect(await repository.watchTemplates().first, isEmpty);
    });

    test('refuses an empty name', () async {
      await addEvent(yesterday);
      expect(
        () => repository.saveTemplate(name: '   ', day: yesterday),
        throwsArgumentError,
      );
    });

    test('a name that is too long is cut to the limit', () async {
      await addEvent(yesterday);

      await repository.saveTemplate(
        name: 'x' * (maxTemplateNameLength + 20),
        day: yesterday,
      );

      final name = (await repository.watchTemplates().first).single.name;
      expect(name, hasLength(maxTemplateNameLength));
    });
  });

  group('watchTemplates', () {
    test('lists the newest template first, items in start order', () async {
      await addEvent(yesterday, title: 'Late', start: 900, end: 960);
      await addEvent(yesterday, title: 'Early', start: 480, end: 540);
      await repository.saveTemplate(name: 'First', day: yesterday);
      now = now.add(const Duration(minutes: 5));
      await repository.saveTemplate(name: 'Second', day: yesterday);

      final templates = await repository.watchTemplates().first;

      expect(templates.map((template) => template.name), ['Second', 'First']);
      expect(templates.first.items.map((item) => item.title), [
        'Early',
        'Late',
      ]);
    });

    test('emits again when a template is saved or deleted', () async {
      await addEvent(yesterday);
      final counts = <int>[];
      final subscription = repository.watchTemplates().listen(
        (templates) => counts.add(templates.length),
      );
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      final id = await repository.saveTemplate(name: 'Day', day: yesterday);
      await pumpEventQueue();
      await repository.deleteTemplate(id);
      await pumpEventQueue();

      expect(counts.first, 0);
      expect(counts, contains(1));
      expect(counts.last, 0);
    });
  });

  test('deleteTemplate removes the template and its items', () async {
    await addEvent(yesterday);
    final id = await repository.saveTemplate(name: 'Day', day: yesterday);

    await repository.deleteTemplate(id);

    expect(await db.select(db.dayTemplates).get(), isEmpty);
    expect(await db.select(db.dayTemplateItems).get(), isEmpty);
  });

  group('applyTemplate', () {
    test('creates the template events on an empty day', () async {
      await addEvent(yesterday);
      await addEvent(
        yesterday,
        title: 'Lunch walk',
        tone: 1,
        start: 750,
        end: 795,
      );
      final id = await repository.saveTemplate(name: 'Day', day: yesterday);

      final created = await repository.applyTemplate(
        templateId: id,
        day: DateTime(2026, 10, 7, 15),
      );

      expect(created, 2);
      final events = await onDay(today);
      expect(events.map((row) => row.title), ['Deep work', 'Lunch walk']);
      expect(events.map((row) => row.toneIndex), [0, 1]);
      expect(events.map((row) => row.startMinute), [540, 750]);
      expect(events.map((row) => row.endMinute), [660, 795]);
      expect(events.every((row) => row.seriesId == null), isTrue);
      expect(
        events.every((row) => row.status == EventStatus.planned.dbIndex),
        isTrue,
      );
      expect(events.first.createdAt, now);
    });

    test('refuses a day that already has events and writes nothing', () async {
      await addEvent(yesterday);
      final id = await repository.saveTemplate(name: 'Day', day: yesterday);
      await addEvent(today, title: 'Already here');

      await expectLater(
        repository.applyTemplate(templateId: id, day: today),
        throwsA(isA<DayNotEmptyException>()),
      );

      expect((await onDay(today)).map((row) => row.title), ['Already here']);
    });

    test('a day with only deleted occurrences counts as empty', () async {
      await addEvent(yesterday);
      final id = await repository.saveTemplate(name: 'Day', day: yesterday);
      await addEvent(
        today,
        title: 'Cancelled',
        status: EventStatus.skipped.dbIndex,
        seriesId: 3,
      );

      expect(await repository.applyTemplate(templateId: id, day: today), 1);
    });

    test('a template that is gone creates nothing', () async {
      expect(await repository.applyTemplate(templateId: 99, day: today), 0);
      expect(await onDay(today), isEmpty);
    });

    test('overlapping events apply as they were', () async {
      await addEvent(yesterday, start: 540, end: 660);
      await addEvent(yesterday, title: 'B', start: 600, end: 700);
      await addEvent(yesterday, title: 'C', start: 620, end: 720);
      final id = await repository.saveTemplate(name: 'Busy', day: yesterday);

      expect(await repository.applyTemplate(templateId: id, day: today), 3);
    });
  });

  group('copyDay', () {
    test('copies the events as planned one-offs', () async {
      await addEvent(yesterday);
      await addEvent(
        yesterday,
        title: 'Standup',
        tone: 2,
        start: 700,
        end: 730,
        seriesId: 5,
        status: EventStatus.completed.dbIndex,
      );

      final created = await repository.copyDay(from: yesterday, to: today);

      expect(created, 2);
      final events = await onDay(today);
      expect(events.map((row) => row.title), ['Deep work', 'Standup']);
      expect(events.map((row) => row.toneIndex), [0, 2]);
      expect(events.map((row) => row.startMinute), [540, 700]);
      expect(events.every((row) => row.seriesId == null), isTrue);
      expect(
        events.every((row) => row.status == EventStatus.planned.dbIndex),
        isTrue,
      );
      expect(await onDay(yesterday), hasLength(2));
    });

    test('leaves out skipped events', () async {
      await addEvent(yesterday);
      await addEvent(
        yesterday,
        title: 'Cancelled',
        status: EventStatus.skipped.dbIndex,
        seriesId: 3,
      );

      expect(await repository.copyDay(from: yesterday, to: today), 1);
    });

    test('refuses a day that already has events', () async {
      await addEvent(yesterday);
      await addEvent(today, title: 'Already here');

      await expectLater(
        repository.copyDay(from: yesterday, to: today),
        throwsA(isA<DayNotEmptyException>()),
      );

      expect(await onDay(today), hasLength(1));
    });

    test('an empty source day copies nothing', () async {
      expect(await repository.copyDay(from: yesterday, to: today), 0);
      expect(await onDay(today), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run the test to see it fail**

```bash
# expect: FAIL — templateDao and reuse_repository.dart do not exist yet
flutter test test/data/reuse_repository_test.dart
```

- [ ] **Step 3: Write the code**

**Create `lib/data/models/day_template.dart`**

```dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';

/// One event of a saved template.
class TemplateItem {
  const TemplateItem({
    required this.title,
    required this.tone,
    required this.range,
  });

  final String title;
  final Tone tone;
  final MinuteRange range;
}

/// A saved day plan: a name and the events it puts on a day.
class DayTemplate {
  const DayTemplate({
    required this.id,
    required this.name,
    required this.items,
  });

  final int id;
  final String name;

  /// In start order.
  final List<TemplateItem> items;

  int get eventCount => items.length;

  /// Overlapping events count twice, as in the day-load bar.
  int get totalMinutes =>
      items.fold<int>(0, (sum, item) => sum + item.range.durationMinutes);

  /// The tones the template uses, in the fixed tone order.
  List<Tone> get tones => [
    for (final tone in Tone.values)
      if (items.any((item) => item.tone == tone)) tone,
  ];
}
```

**Create `lib/data/daos/template_dao.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:energy_clock/core/event_status.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/tables/day_templates_table.dart';
import 'package:energy_clock/data/tables/events_table.dart';

part 'template_dao.g.dart';

/// A template and its events, for the template list.
typedef TemplateWithItems = ({
  DayTemplateRow template,
  List<DayTemplateItemRow> items,
});

/// Day templates, and the events of a day that a template is saved from or
/// applied to (spec §7).
@DriftAccessor(tables: [DayTemplates, DayTemplateItems, Events])
class TemplateDao extends DatabaseAccessor<AppDatabase>
    with _$TemplateDaoMixin {
  TemplateDao(super.attachedDatabase);

  static final int _skipped = EventStatus.skipped.dbIndex;

  /// Every template, newest first, each with its items in start order.
  Stream<List<TemplateWithItems>> watchTemplates() {
    final query =
        select(dayTemplates).join([
          leftOuterJoin(
            dayTemplateItems,
            dayTemplateItems.templateId.equalsExp(dayTemplates.id),
          ),
        ])..orderBy([
          OrderingTerm.desc(dayTemplates.createdAt),
          OrderingTerm.desc(dayTemplates.id),
          OrderingTerm.asc(dayTemplateItems.startMinute),
          OrderingTerm.asc(dayTemplateItems.id),
        ]);

    return query.watch().map((rows) {
      final byId = <int, TemplateWithItems>{};
      for (final row in rows) {
        final template = row.readTable(dayTemplates);
        final entry = byId.putIfAbsent(
          template.id,
          () => (template: template, items: <DayTemplateItemRow>[]),
        );
        final item = row.readTableOrNull(dayTemplateItems);
        if (item != null) entry.items.add(item);
      }
      return byId.values.toList();
    });
  }

  Future<int> insertTemplate(DayTemplatesCompanion entry) =>
      into(dayTemplates).insert(entry);

  Future<void> insertItem(DayTemplateItemsCompanion entry) =>
      into(dayTemplateItems).insert(entry);

  /// A template's items in start order.
  Future<List<DayTemplateItemRow>> itemsFor(int templateId) {
    return (select(dayTemplateItems)
          ..where((row) => row.templateId.equals(templateId))
          ..orderBy([
            (row) => OrderingTerm(expression: row.startMinute),
            (row) => OrderingTerm(expression: row.id),
          ]))
        .get();
  }

  Future<void> deleteTemplate(int id) async {
    await (delete(
      dayTemplateItems,
    )..where((row) => row.templateId.equals(id))).go();
    await (delete(dayTemplates)..where((row) => row.id.equals(id))).go();
  }

  /// The events really on [day] in start order; skipped rows are left out.
  Future<List<EventRow>> liveEventsOn(DateTime day) {
    return (select(events)
          ..where(
            (row) => row.date.equals(day) & row.status.isNotValue(_skipped),
          )
          ..orderBy([
            (row) => OrderingTerm(expression: row.startMinute),
            (row) => OrderingTerm(expression: row.id),
          ]))
        .get();
  }

  Future<int> insertEvent(EventsCompanion entry) => into(events).insert(entry);

  /// Runs [action] in one database transaction.
  Future<T> inTransaction<T>(Future<T> Function() action) =>
      transaction(action);
}
```

**Create `lib/data/repositories/reuse_repository.dart`**

```dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/daos/template_dao.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/models/day_template.dart';

export 'package:energy_clock/data/models/day_template.dart';

/// The longest template name; matches the column.
const int maxTemplateNameLength = 60;

/// Thrown by [ReuseRepository.saveTemplate] when the day has no events.
class EmptyDayException implements Exception {
  const EmptyDayException();
}

/// Thrown when a template or a copy would land on a day that already has
/// events. Templates and copy-yesterday only fill an empty day (spec §7).
class DayNotEmptyException implements Exception {
  const DayNotEmptyException();
}

/// Fills a day from another day's plan: day templates and copy-yesterday.
abstract interface class ReuseRepository {
  /// Every template, newest first.
  Stream<List<DayTemplate>> watchTemplates();

  /// Saves the events of [day] as a template named [name] (trimmed, and cut to
  /// [maxTemplateNameLength]). Throws [EmptyDayException] if the day has no
  /// events, and [ArgumentError] if the name is empty. Returns the new id.
  Future<int> saveTemplate({required String name, required DateTime day});

  Future<void> deleteTemplate(int id);

  /// Creates the template's events on [day], as planned one-off events.
  /// Returns how many it created (0 if the template no longer exists). Throws
  /// [DayNotEmptyException] if [day] already has events.
  Future<int> applyTemplate({required int templateId, required DateTime day});

  /// Copies the events of [from] onto [to], as planned one-off events. Returns
  /// how many it created. Throws [DayNotEmptyException] if [to] already has
  /// events.
  Future<int> copyDay({required DateTime from, required DateTime to});
}

class DriftReuseRepository implements ReuseRepository {
  DriftReuseRepository(this._dao, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final TemplateDao _dao;
  final DateTime Function() _clock;

  @override
  Stream<List<DayTemplate>> watchTemplates() => _dao.watchTemplates().map(
    (groups) => [
      for (final group in groups)
        DayTemplate(
          id: group.template.id,
          name: group.template.name,
          items: [
            for (final item in group.items)
              TemplateItem(
                title: item.title,
                tone: Tone.fromDbIndex(item.toneIndex),
                range: MinuteRange(item.startMinute, item.endMinute),
              ),
          ],
        ),
    ],
  );

  @override
  Future<int> saveTemplate({required String name, required DateTime day}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'A template needs a name');
    }
    final clipped = trimmed.length > maxTemplateNameLength
        ? trimmed.substring(0, maxTemplateNameLength)
        : trimmed;

    return _dao.inTransaction(() async {
      final events = await _dao.liveEventsOn(startOfDay(day));
      if (events.isEmpty) throw const EmptyDayException();

      final id = await _dao.insertTemplate(
        DayTemplatesCompanion.insert(name: clipped, createdAt: _clock()),
      );
      for (final event in events) {
        await _dao.insertItem(
          DayTemplateItemsCompanion.insert(
            templateId: id,
            title: event.title,
            toneIndex: event.toneIndex,
            startMinute: event.startMinute,
            endMinute: event.endMinute,
          ),
        );
      }
      return id;
    });
  }

  @override
  Future<void> deleteTemplate(int id) =>
      _dao.inTransaction(() => _dao.deleteTemplate(id));

  @override
  Future<int> applyTemplate({required int templateId, required DateTime day}) {
    final target = startOfDay(day);
    return _dao.inTransaction(() async {
      await _requireEmpty(target);
      final items = await _dao.itemsFor(templateId);
      final now = _clock();
      for (final item in items) {
        await _dao.insertEvent(
          EventsCompanion.insert(
            date: target,
            title: item.title,
            toneIndex: item.toneIndex,
            startMinute: item.startMinute,
            endMinute: item.endMinute,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      return items.length;
    });
  }

  @override
  Future<int> copyDay({required DateTime from, required DateTime to}) {
    final target = startOfDay(to);
    return _dao.inTransaction(() async {
      await _requireEmpty(target);
      final source = await _dao.liveEventsOn(startOfDay(from));
      final now = _clock();
      for (final event in source) {
        await _dao.insertEvent(
          EventsCompanion.insert(
            date: target,
            title: event.title,
            toneIndex: event.toneIndex,
            startMinute: event.startMinute,
            endMinute: event.endMinute,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      return source.length;
    });
  }

  Future<void> _requireEmpty(DateTime day) async {
    if ((await _dao.liveEventsOn(day)).isNotEmpty) {
      throw const DayNotEmptyException();
    }
  }
}
```

**Edit `lib/data/database.dart`**

Replace:

```dart
import 'package:energy_clock/data/daos/settings_dao.dart';
```

With:

```dart
import 'package:energy_clock/data/daos/settings_dao.dart';
import 'package:energy_clock/data/daos/template_dao.dart';
```

Replace:

```dart
  daos: [EventDao, SettingsDao, SessionDao, SeriesDao],
```

With:

```dart
  daos: [EventDao, SettingsDao, SessionDao, SeriesDao, TemplateDao],
```

- [ ] **Step 4: Regenerate the Drift code, then run the tests, the analyzer and the whole suite**

```bash
# expect: PASS — 17 new tests; analyzer clean; the whole suite stays green
DART="$(dirname "$(which flutter)")/dart"
"$DART" run build_runner build --delete-conflicting-outputs
flutter test test/data/reuse_repository_test.dart && flutter analyze && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib/data test/data
git commit -m "feat: day templates and copy-day

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---
### Task 8: Reading a day fills it; the calendar repository; the providers

Until now nothing calls the materialiser, so a series would never produce a day. Spec §4.3: "When a day is opened — or when notifications are scheduled for an upcoming window — any `event_series` covering that date that has not yet produced a row in `events` is expanded into one." The place that implements "a day is opened" is the repository's watch methods, so the Clock screen, the week strip and the Calendar all get recurring events without knowing recurrence exists:

- `DriftEventRepository.watchDay(day)` fills that day, then streams it.
- `DriftEventRepository.watchTonesByDay(from, to)` (the week strip's dots) fills the range, then streams it.
- The new `CalendarRepository.watchMonth(month)` fills the month, then streams the planned minutes per tone for each day of it.

If filling a day fails, the day is shown as stored instead: a broken expansion must never lock the person out of the app (the same rule `ClockTab` follows when a session cannot be read).

This task also adds the Riverpod providers for the Step 3 repositories to `lib/data/providers.dart`, next to the session repository's, so a feature can use them without importing another feature.

**Files:**
- Create: `lib/data/repositories/calendar_repository.dart`
- Modify: `lib/features/clock/data/event_repository.dart`, `lib/features/clock/providers.dart`, `lib/data/providers.dart`
- Test: `test/features/clock/event_repository_series_test.dart`, `test/data/calendar_repository_test.dart`, `test/data/providers_step3_test.dart`

**Interfaces:**
- Consumes: `SeriesMaterialiser`, `SeriesRepository`, `ReuseRepository` (Tasks 5–7); `EventDao.watchToneMinutes` (Task 4); `startOfMonth`, `addMonths` (Task 2).
- Produces: `DriftEventRepository(dao, {clock, materialiser})` (new optional `materialiser`); `ToneMinutes` (`Map<Tone, int>`); `CalendarRepository.watchMonth(DateTime month) → Stream<Map<DateTime, ToneMinutes>>` (days with no events are absent; keys are local midnights); `DriftCalendarRepository(EventDao, {SeriesMaterialiser? materialiser})`; providers `seriesMaterialiserProvider`, `seriesRepositoryProvider`, `reuseRepositoryProvider`, `calendarRepositoryProvider` in `lib/data/providers.dart`.

- [ ] **Step 1: Write the failing tests**

**Create `test/features/clock/event_repository_series_test.dart`**

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/series_materialiser.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftEventRepository repository;

  final created = DateTime(2026, 10, 1, 9);
  final monday = DateTime(2026, 10, 5);
  final tuesday = DateTime(2026, 10, 6);

  Future<int> addSeries({
    required DateTime validFrom,
    RecurrenceRule? rule,
    String title = 'Standup',
  }) {
    final used = rule ?? RecurrenceRule.daily();
    return db.seriesDao.insertSeries(
      EventSeriesCompanion.insert(
        title: title,
        toneIndex: Tone.inbox.dbIndex,
        startMinute: 540,
        endMinute: 570,
        recurrenceKind: used.kind.dbIndex,
        weekdayMask: Value(used.weekdayMask),
        validFrom: validFrom,
        validUntil: Value(used.until),
        createdAt: created,
      ),
    );
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftEventRepository(
      db.eventDao,
      clock: () => created,
      materialiser: SeriesMaterialiser(db.seriesDao, clock: () => created),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('watching a day first fills it from its series', () async {
    final seriesId = await addSeries(validFrom: monday);

    final events = await repository.watchDay(tuesday).first;

    expect(events, hasLength(1));
    expect(events.single.title, 'Standup');
    expect(events.single.seriesId, seriesId);
    expect(events.single.date, tuesday);
    expect(events.single.tone, Tone.inbox);
  });

  test('watching the same day again does not duplicate it', () async {
    await addSeries(validFrom: monday);

    await repository.watchDay(tuesday).first;
    final again = await repository.watchDay(tuesday).first;

    expect(again, hasLength(1));
  });

  test('a day before the series starts stays empty', () async {
    await addSeries(validFrom: tuesday);
    expect(await repository.watchDay(monday).first, isEmpty);
  });

  test('without a materialiser nothing is created', () async {
    await addSeries(validFrom: monday);
    final plain = DriftEventRepository(db.eventDao);

    expect(await plain.watchDay(tuesday).first, isEmpty);
  });

  test(
    'a deleted occurrence stays deleted when the day is read again',
    () async {
      await addSeries(validFrom: monday);
      final first = await repository.watchDay(tuesday).first;

      await repository.deleteEvent(first.single.id);

      expect(await repository.watchDay(tuesday).first, isEmpty);
    },
  );

  test('a moved occurrence keeps its series and its new time', () async {
    final seriesId = await addSeries(validFrom: monday);
    final first = await repository.watchDay(tuesday).first;

    await repository.moveEvent(
      id: first.single.id,
      day: tuesday,
      range: const MinuteRange(900, 960),
    );
    final again = await repository.watchDay(tuesday).first;

    expect(again, hasLength(1));
    expect(again.single.range, const MinuteRange(900, 960));
    expect(again.single.seriesId, seriesId);
  });

  test(
    'the week strip dots include days that have only been planned by a series',
    () async {
      await addSeries(validFrom: monday, rule: RecurrenceRule.weekdays());

      final byDay = await repository
          .watchTonesByDay(monday, DateTime(2026, 10, 12))
          .first;

      expect(byDay.keys.map((day) => day.day).toSet(), {5, 6, 7, 8, 9});
      expect(byDay[monday], {Tone.inbox});
    },
  );

  test(
    'a series occurrence on a full day waits instead of breaking the dial',
    () async {
      for (var i = 0; i < 3; i++) {
        await repository.createEvent(
          day: tuesday,
          title: 'Busy $i',
          tone: Tone.focus,
          range: const MinuteRange(540, 600),
        );
      }
      await addSeries(validFrom: monday);

      final events = await repository.watchDay(tuesday).first;

      expect(events, hasLength(3));
      expect(events.every((event) => event.seriesId == null), isTrue);
    },
  );
}
```

**Create `test/data/calendar_repository_test.dart`**

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:energy_clock/core/event_status.dart';
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/calendar_repository.dart';
import 'package:energy_clock/data/repositories/series_materialiser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CalendarRepository repository;

  final created = DateTime(2026, 10, 1, 9);
  final october = DateTime(2026, 10, 17);

  Future<int> addEvent(
    DateTime day,
    Tone tone,
    int start,
    int end, {
    int status = 0,
  }) {
    return db.eventDao.insertEvent(
      EventsCompanion.insert(
        date: day,
        title: 'Event',
        toneIndex: tone.dbIndex,
        startMinute: start,
        endMinute: end,
        status: Value(status),
        createdAt: created,
        updatedAt: created,
      ),
    );
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftCalendarRepository(
      db.eventDao,
      materialiser: SeriesMaterialiser(db.seriesDao, clock: () => created),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('gives planned minutes per tone for each day of the month', () async {
    await addEvent(DateTime(2026, 10, 5), Tone.focus, 60, 180);
    await addEvent(DateTime(2026, 10, 5), Tone.life, 300, 360);
    await addEvent(DateTime(2026, 10, 5), Tone.focus, 400, 430);
    await addEvent(DateTime(2026, 10, 31), Tone.inbox, 60, 90);

    final month = await repository.watchMonth(october).first;

    expect(month.keys, {DateTime(2026, 10, 5), DateTime(2026, 10, 31)});
    expect(month[DateTime(2026, 10, 5)], {Tone.focus: 150, Tone.life: 60});
    expect(month[DateTime(2026, 10, 31)], {Tone.inbox: 30});
  });

  test('leaves out other months and skipped events', () async {
    await addEvent(DateTime(2026, 9, 30), Tone.focus, 60, 120);
    await addEvent(DateTime(2026, 11, 1), Tone.focus, 60, 120);
    await addEvent(
      DateTime(2026, 10, 5),
      Tone.focus,
      60,
      120,
      status: EventStatus.skipped.dbIndex,
    );

    expect(await repository.watchMonth(october).first, isEmpty);
  });

  test('fills the month from its series before reading it', () async {
    await db.seriesDao.insertSeries(
      EventSeriesCompanion.insert(
        title: 'Standup',
        toneIndex: Tone.inbox.dbIndex,
        startMinute: 540,
        endMinute: 570,
        recurrenceKind: RecurrenceKind.weekdays.dbIndex,
        validFrom: DateTime(2026, 10, 1),
        createdAt: created,
      ),
    );

    final month = await repository.watchMonth(october).first;

    // October 2026 has 22 weekdays; each is 30 minutes of Inbox.
    expect(month, hasLength(22));
    expect(month[DateTime(2026, 10, 1)], {Tone.inbox: 30});
    expect(month.containsKey(DateTime(2026, 10, 3)), isFalse);
  });

  test('a future month is filled too', () async {
    await db.seriesDao.insertSeries(
      EventSeriesCompanion.insert(
        title: 'Review',
        toneIndex: Tone.focus.dbIndex,
        startMinute: 600,
        endMinute: 660,
        recurrenceKind: RecurrenceKind.custom.dbIndex,
        weekdayMask: const Value(1),
        validFrom: DateTime(2026, 10, 1),
        createdAt: created,
      ),
    );

    final month = await repository.watchMonth(DateTime(2027, 1, 20)).first;

    // Mondays in January 2027: 4, 11, 18, 25.
    expect(month.keys.map((day) => day.day), [4, 11, 18, 25]);
    expect(month.values.every((minutes) => minutes[Tone.focus] == 60), isTrue);
  });

  test('without a materialiser it only reads what is stored', () async {
    await db.seriesDao.insertSeries(
      EventSeriesCompanion.insert(
        title: 'Standup',
        toneIndex: Tone.inbox.dbIndex,
        startMinute: 540,
        endMinute: 570,
        recurrenceKind: RecurrenceKind.daily.dbIndex,
        validFrom: DateTime(2026, 10, 1),
        createdAt: created,
      ),
    );
    final plain = DriftCalendarRepository(db.eventDao);

    expect(await plain.watchMonth(october).first, isEmpty);
  });

  test('emits again when an event is added', () async {
    final sizes = <int>[];
    final subscription = repository
        .watchMonth(october)
        .listen((month) => sizes.add(month.length));
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    await addEvent(DateTime(2026, 10, 5), Tone.focus, 60, 120);
    await pumpEventQueue();

    expect(sizes.first, 0);
    expect(sizes.last, 1);
  });
}
```

**Create `test/data/providers_step3_test.dart`**

```dart
import 'package:drift/native.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/calendar_repository.dart';
import 'package:energy_clock/data/repositories/reuse_repository.dart';
import 'package:energy_clock/data/repositories/series_materialiser.dart';
import 'package:energy_clock/data/repositories/series_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the Step 3 repositories are built on the shared database', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    expect(
      container.read(seriesMaterialiserProvider),
      isA<SeriesMaterialiser>(),
    );
    expect(
      container.read(seriesRepositoryProvider),
      isA<DriftSeriesRepository>(),
    );
    expect(
      container.read(reuseRepositoryProvider),
      isA<DriftReuseRepository>(),
    );
    expect(
      container.read(calendarRepositoryProvider),
      isA<DriftCalendarRepository>(),
    );
  });
}
```

- [ ] **Step 2: Run the tests to see them fail**

```bash
# expect: FAIL — materialiser: is not a DriftEventRepository parameter; calendar_repository.dart and the new providers do not exist
flutter test test/features/clock/event_repository_series_test.dart test/data/calendar_repository_test.dart test/data/providers_step3_test.dart
```

- [ ] **Step 3: Write the code**

**Create `lib/data/repositories/calendar_repository.dart`**

```dart
import 'package:energy_clock/core/time/month_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/daos/event_dao.dart';
import 'package:energy_clock/data/repositories/series_materialiser.dart';

/// Planned minutes per tone for one day. A tone with no events is absent.
typedef ToneMinutes = Map<Tone, int>;

/// What the Calendar tab reads: how each day of a month is planned.
abstract interface class CalendarRepository {
  /// The planned minutes per tone for every day of [month]'s month that has
  /// events (days with none are absent), keyed by local midnight. Recurring
  /// series are expanded into the month first, so a repeating event shows on
  /// every day it covers. Emits again whenever an event changes.
  Stream<Map<DateTime, ToneMinutes>> watchMonth(DateTime month);
}

class DriftCalendarRepository implements CalendarRepository {
  DriftCalendarRepository(this._dao, {this._materialiser});

  final EventDao _dao;
  final SeriesMaterialiser? _materialiser;

  @override
  Stream<Map<DateTime, ToneMinutes>> watchMonth(DateTime month) async* {
    final first = startOfMonth(month);
    final end = addMonths(first, 1);

    final materialiser = _materialiser;
    if (materialiser != null) {
      try {
        await materialiser.materialise(first, end);
      } on Object {
        // Show the month as stored: a failed expansion must not blank the
        // Calendar.
      }
    }

    yield* _dao.watchToneMinutes(first, end).map((rows) {
      final byDay = <DateTime, ToneMinutes>{};
      for (final row in rows) {
        final minutes = byDay.putIfAbsent(row.date, () => <Tone, int>{});
        minutes[Tone.fromDbIndex(row.toneIndex)] = row.minutes;
      }
      return byDay;
    });
  }
}
```

**Edit `lib/features/clock/data/event_repository.dart`**

Replace:

```dart
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
```

With:

```dart
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/series_materialiser.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
```

Replace:

```dart
class DriftEventRepository implements EventRepository {
  DriftEventRepository(this._dao, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final EventDao _dao;
  final DateTime Function() _clock;

  @override
  Stream<List<CalendarEvent>> watchDay(DateTime day) => _dao
      .watchDay(startOfDay(day))
      .map((rows) => rows.map(CalendarEvent.fromRow).toList());
```

With:

```dart
class DriftEventRepository implements EventRepository {
  /// [materialiser], when given, fills a day from its recurring series each
  /// time the day (or a range of days) is watched.
  DriftEventRepository(
    this._dao, {
    DateTime Function()? clock,
    this._materialiser,
  }) : _clock = clock ?? DateTime.now;

  final EventDao _dao;
  final DateTime Function() _clock;
  final SeriesMaterialiser? _materialiser;

  /// Expands the series that cover [from, toExclusive). If that fails, the days
  /// are shown as stored: a broken expansion must never lock the person out of
  /// their day.
  Future<void> _fill(DateTime from, DateTime toExclusive) async {
    final materialiser = _materialiser;
    if (materialiser == null) return;
    try {
      await materialiser.materialise(from, toExclusive);
    } on Object {
      // Fall through to what is stored.
    }
  }

  @override
  Stream<List<CalendarEvent>> watchDay(DateTime day) async* {
    final start = startOfDay(day);
    await _fill(start, nextDay(start));
    yield* _dao
        .watchDay(start)
        .map((rows) => rows.map(CalendarEvent.fromRow).toList());
  }
```

Replace:

```dart
  Stream<Map<DateTime, Set<Tone>>> watchTonesByDay(
    DateTime from,
    DateTime toExclusive,
  ) {
    return _dao.watchToneDays(startOfDay(from), startOfDay(toExclusive)).map((
      rows,
    ) {
      final byDay = <DateTime, Set<Tone>>{};
      for (final row in rows) {
        byDay
            .putIfAbsent(startOfDay(row.date), () => <Tone>{})
            .add(Tone.fromDbIndex(row.toneIndex));
      }
      return byDay;
    });
  }
```

With:

```dart
  Stream<Map<DateTime, Set<Tone>>> watchTonesByDay(
    DateTime from,
    DateTime toExclusive,
  ) async* {
    final start = startOfDay(from);
    final end = startOfDay(toExclusive);
    await _fill(start, end);
    yield* _dao.watchToneDays(start, end).map((rows) {
      final byDay = <DateTime, Set<Tone>>{};
      for (final row in rows) {
        byDay
            .putIfAbsent(startOfDay(row.date), () => <Tone>{})
            .add(Tone.fromDbIndex(row.toneIndex));
      }
      return byDay;
    });
  }
```

**Edit `lib/data/providers.dart`**

Replace:

```dart
import 'package:energy_clock/data/repositories/session_repository.dart';
import 'package:energy_clock/data/repositories/settings_repository.dart';
```

With:

```dart
import 'package:energy_clock/data/repositories/calendar_repository.dart';
import 'package:energy_clock/data/repositories/reuse_repository.dart';
import 'package:energy_clock/data/repositories/series_materialiser.dart';
import 'package:energy_clock/data/repositories/series_repository.dart';
import 'package:energy_clock/data/repositories/session_repository.dart';
import 'package:energy_clock/data/repositories/settings_repository.dart';
```

Replace:

```dart
/// Local notifications. Tests replace it with a fake, so nothing in a test run
/// reaches the plugin.
```

With:

```dart
/// Expands recurring series into events (spec §4.3). The event repository and
/// the calendar repository both call it when a day or a month is read.
final seriesMaterialiserProvider = Provider<SeriesMaterialiser>((ref) {
  return SeriesMaterialiser(ref.watch(appDatabaseProvider).seriesDao);
});

/// Makes events repeat, and edits or deletes "this and all future".
final seriesRepositoryProvider = Provider<SeriesRepository>((ref) {
  return DriftSeriesRepository(ref.watch(appDatabaseProvider).seriesDao);
});

/// Day templates and copy-yesterday.
final reuseRepositoryProvider = Provider<ReuseRepository>((ref) {
  return DriftReuseRepository(ref.watch(appDatabaseProvider).templateDao);
});

/// How each day of a month is planned, for the Calendar tab.
final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return DriftCalendarRepository(
    ref.watch(appDatabaseProvider).eventDao,
    materialiser: ref.watch(seriesMaterialiserProvider),
  );
});

/// Local notifications. Tests replace it with a fake, so nothing in a test run
/// reaches the plugin.
```

**Edit `lib/features/clock/providers.dart`**

Replace:

```dart
final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return DriftEventRepository(ref.watch(appDatabaseProvider).eventDao);
});
```

With:

```dart
final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return DriftEventRepository(
    ref.watch(appDatabaseProvider).eventDao,
    materialiser: ref.watch(seriesMaterialiserProvider),
  );
});
```

- [ ] **Step 4: Run the tests, the analyzer and the whole suite**

```bash
# expect: PASS — 15 new tests; analyzer clean; the whole suite stays green
flutter test test/features/clock/event_repository_series_test.dart test/data/calendar_repository_test.dart test/data/providers_step3_test.dart && flutter analyze && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat: reading a day or a month fills it from its series

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---
## Stage 2 — Repeating events in the Clock

### Task 9: In-memory fakes for the new repositories, and the harness

Widget tests cannot use a real Drift database (its I/O runs on real timers the fake clock never advances; see `fake_event_repository.dart`), so every repository a screen reads has an in-memory fake. This task adds three, shaped like the real ones and sharing `FakeEventRepository`'s events so that what a test does through one is visible through the others:

- `FakeSeriesRepository`: creating a repeating event, "this and all future" edits and deletes. It records each call and applies the effect on the fake events, so a sheet test can assert both.
- `FakeReuseRepository`: templates, apply, and copy-day, with the real repository's refusals (`EmptyDayException`, `DayNotEmptyException`).
- `FakeCalendarRepository`: the month's tone minutes, computed from the fake events and re-emitted when they change.

`FakeEventRepository` gains a few helpers for them, and `ClockHarness` overrides the three new providers, so every existing harness test keeps working. A small test checks the fakes themselves, since many tests will lean on them.

**Files:**
- Create: `test/support/fake_series_repository.dart`, `test/support/fake_reuse_repository.dart`, `test/support/fake_calendar_repository.dart`
- Modify: `test/support/fake_event_repository.dart`, `test/support/clock_harness.dart`
- Test: `test/support/fake_repositories_test.dart`

**Interfaces:**
- Produces (all in `test/support/`): `FakeEventRepository.all`, `.changes`, `.addOccurrence({seriesId, day, title, tone, range, status}) → int`, `.setSeriesId(int id, int? seriesId)`, `.removeSeriesFrom(int seriesId, DateTime from)`; `FakeSeriesRepository(FakeEventRepository)` with `rules`, `addSeries(RecurrenceRule) → int`, and call logs `created`, `updated`, `deletedFrom`; `FakeReuseRepository(FakeEventRepository)` with `templates`, `addTemplate(String, List<TemplateItem>) → int`, `dispose()`; `FakeCalendarRepository(FakeEventRepository)`; `ClockHarness.series`, `.reuse`, `.calendar`.

- [ ] **Step 1: Write the failing test**

**Create `test/support/fake_repositories_test.dart`**

```dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/repositories/reuse_repository.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'clock_harness.dart';

void main() {
  late ClockHarness harness;

  final monday = DateTime(2026, 10, 5);
  final tuesday = DateTime(2026, 10, 6);
  final wednesday = DateTime(2026, 10, 7);

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  group('FakeSeriesRepository', () {
    test(
      'createRecurring adds an event that belongs to a new series',
      () async {
        final id = await harness.series.createRecurring(
          day: wednesday,
          title: 'Standup',
          tone: Tone.inbox,
          range: const MinuteRange(540, 570),
          rule: RecurrenceRule.daily(),
        );

        final event = harness.repository.eventById(id)!;
        expect(event.seriesId, isNotNull);
        expect(harness.series.rules[event.seriesId], RecurrenceRule.daily());
        expect(harness.series.created, hasLength(1));
        expect(harness.series.created.single.title, 'Standup');
      },
    );

    test('createRecurring refuses a fourth ring', () async {
      for (var i = 0; i < 3; i++) {
        await harness.repository.createEvent(
          day: wednesday,
          title: 'Busy',
          tone: Tone.focus,
          range: const MinuteRange(540, 600),
        );
      }
      await expectLater(
        harness.series.createRecurring(
          day: wednesday,
          title: 'Standup',
          tone: Tone.inbox,
          range: const MinuteRange(560, 620),
          rule: RecurrenceRule.daily(),
        ),
        throwsA(isA<RingOverflowException>()),
      );
    });

    test(
      'updateFromHere rewrites the event and drops the later days',
      () async {
        final seriesId = harness.series.addSeries(RecurrenceRule.daily());
        final first = harness.repository.addOccurrence(
          seriesId: seriesId,
          day: wednesday,
        );
        harness.repository.addOccurrence(
          seriesId: seriesId,
          day: DateTime(2026, 10, 8),
        );
        final earlier = harness.repository.addOccurrence(
          seriesId: seriesId,
          day: tuesday,
        );

        await harness.series.updateFromHere(
          eventId: first,
          title: 'Planning',
          tone: Tone.focus,
          range: const MinuteRange(600, 660),
          rule: RecurrenceRule.weekdays(),
        );

        final event = harness.repository.eventById(first)!;
        expect(event.title, 'Planning');
        expect(event.tone, Tone.focus);
        expect(event.range, const MinuteRange(600, 660));
        expect(event.seriesId, isNot(seriesId));
        expect(harness.series.rules[event.seriesId], RecurrenceRule.weekdays());
        expect(harness.repository.all.map((e) => e.date.day), [7, 6]);
        expect(harness.repository.eventById(earlier)!.seriesId, seriesId);
        expect(harness.series.updated, hasLength(1));
      },
    );

    test('updateFromHere with no repeat makes the event a one-off', () async {
      final seriesId = harness.series.addSeries(RecurrenceRule.daily());
      final id = harness.repository.addOccurrence(
        seriesId: seriesId,
        day: wednesday,
      );

      await harness.series.updateFromHere(
        eventId: id,
        title: 'Once',
        tone: Tone.life,
        range: const MinuteRange(540, 600),
        rule: const RecurrenceRule.none(),
      );

      expect(harness.repository.eventById(id)!.seriesId, isNull);
    });

    test('deleteFromHere removes this day and later ones', () async {
      final seriesId = harness.series.addSeries(RecurrenceRule.daily());
      final earlier = harness.repository.addOccurrence(
        seriesId: seriesId,
        day: tuesday,
      );
      final id = harness.repository.addOccurrence(
        seriesId: seriesId,
        day: wednesday,
      );
      harness.repository.addOccurrence(
        seriesId: seriesId,
        day: DateTime(2026, 10, 8),
      );

      await harness.series.deleteFromHere(id);

      expect(harness.repository.all.map((e) => e.id), [earlier]);
      expect(harness.series.deletedFrom, [id]);
    });

    test('ruleFor reads the stored rule', () async {
      final seriesId = harness.series.addSeries(RecurrenceRule.weekdays());
      expect(await harness.series.ruleFor(seriesId), RecurrenceRule.weekdays());
      expect(await harness.series.ruleFor(999), isNull);
    });
  });

  group('FakeReuseRepository', () {
    Future<void> addDay(DateTime day) async {
      await harness.repository.createEvent(
        day: day,
        title: 'Deep work',
        tone: Tone.focus,
        range: const MinuteRange(540, 660),
      );
      await harness.repository.createEvent(
        day: day,
        title: 'Lunch walk',
        tone: Tone.life,
        range: const MinuteRange(750, 795),
      );
    }

    test('saves a day as a template and applies it to an empty day', () async {
      await addDay(monday);

      final id = await harness.reuse.saveTemplate(
        name: ' Office ',
        day: monday,
      );
      final templates = await harness.reuse.watchTemplates().first;
      expect(templates.single.name, 'Office');
      expect(templates.single.eventCount, 2);

      final created = await harness.reuse.applyTemplate(
        templateId: id,
        day: tuesday,
      );
      expect(created, 2);
      expect(
        (await harness.repository.eventsForDay(tuesday)).map((e) => e.title),
        ['Deep work', 'Lunch walk'],
      );
    });

    test('refuses an empty day and a day that is not empty', () async {
      await expectLater(
        harness.reuse.saveTemplate(name: 'Day', day: monday),
        throwsA(isA<EmptyDayException>()),
      );

      await addDay(monday);
      final id = await harness.reuse.saveTemplate(name: 'Day', day: monday);
      await expectLater(
        harness.reuse.applyTemplate(templateId: id, day: monday),
        throwsA(isA<DayNotEmptyException>()),
      );
      await expectLater(
        harness.reuse.copyDay(from: tuesday, to: monday),
        throwsA(isA<DayNotEmptyException>()),
      );
    });

    test('copyDay duplicates a day as planned events', () async {
      await addDay(monday);
      harness.repository.setStatus(
        (await harness.repository.eventsForDay(monday)).first.id,
        EventStatus.completed,
      );

      expect(await harness.reuse.copyDay(from: monday, to: tuesday), 2);

      final copied = await harness.repository.eventsForDay(tuesday);
      expect(copied.map((e) => e.status).toSet(), {EventStatus.planned});
    });

    test('lists the newest template first and deletes by id', () async {
      await addDay(monday);
      final first = await harness.reuse.saveTemplate(name: 'A', day: monday);
      await harness.reuse.saveTemplate(name: 'B', day: monday);

      var templates = await harness.reuse.watchTemplates().first;
      expect(templates.map((t) => t.name), ['B', 'A']);

      await harness.reuse.deleteTemplate(first);
      templates = await harness.reuse.watchTemplates().first;
      expect(templates.map((t) => t.name), ['B']);
    });
  });

  group('FakeCalendarRepository', () {
    test('sums the minutes per tone for the month', () async {
      await harness.repository.createEvent(
        day: monday,
        title: 'A',
        tone: Tone.focus,
        range: const MinuteRange(60, 120),
      );
      await harness.repository.createEvent(
        day: monday,
        title: 'B',
        tone: Tone.focus,
        range: const MinuteRange(300, 330),
      );
      await harness.repository.createEvent(
        day: DateTime(2026, 11, 2),
        title: 'Next month',
        tone: Tone.life,
        range: const MinuteRange(60, 120),
      );

      final month = await harness.calendar
          .watchMonth(DateTime(2026, 10, 20))
          .first;

      expect(month, {
        monday: {Tone.focus: 90},
      });
    });

    test('emits again when an event is added', () async {
      final sizes = <int>[];
      final subscription = harness.calendar
          .watchMonth(monday)
          .listen((month) => sizes.add(month.length));
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await harness.repository.createEvent(
        day: monday,
        title: 'A',
        tone: Tone.focus,
        range: const MinuteRange(60, 120),
      );
      await pumpEventQueue();

      expect(sizes.first, 0);
      expect(sizes.last, 1);
    });
  });
}
```

- [ ] **Step 2: Run the test to see it fail**

```bash
# expect: FAIL — the fakes, the harness fields and the FakeEventRepository helpers do not exist yet
flutter test test/support/fake_repositories_test.dart
```

- [ ] **Step 3: Write the fakes and the harness**

**Edit `test/support/fake_event_repository.dart`**

Replace:

```dart
  /// The event with [id], or null.
```

With:

```dart
  /// Every event, in creation order. For fakes that look across days.
  List<CalendarEvent> get all => List.unmodifiable(_events);

  /// Emits whenever an event is added, changed or removed.
  Stream<void> get changes => _changes.stream;

  /// Adds an event that belongs to a series, as the real materialiser would.
  /// Does not check rings.
  int addOccurrence({
    required int seriesId,
    required DateTime day,
    String title = 'Standup',
    Tone tone = Tone.inbox,
    MinuteRange range = const MinuteRange(540, 570),
    EventStatus status = EventStatus.planned,
  }) {
    final id = _nextId++;
    _events.add(
      CalendarEvent(
        id: id,
        seriesId: seriesId,
        date: startOfDay(day),
        title: title,
        tone: tone,
        range: range,
        status: status,
      ),
    );
    _notify();
    return id;
  }

  /// Puts an event in a series, or (null) makes it a one-off.
  void setSeriesId(int id, int? seriesId) {
    final index = _events.indexWhere((event) => event.id == id);
    if (index == -1) return;
    final existing = _events[index];
    _events[index] = CalendarEvent(
      id: existing.id,
      seriesId: seriesId,
      date: existing.date,
      title: existing.title,
      tone: existing.tone,
      range: existing.range,
      status: existing.status,
    );
    _notify();
  }

  /// Removes every event of the series dated [from] or later.
  void removeSeriesFrom(int seriesId, DateTime from) {
    final start = startOfDay(from);
    _events.removeWhere(
      (event) => event.seriesId == seriesId && !event.date.isBefore(start),
    );
    _notify();
  }

  /// The event with [id], or null.
```

**Create `test/support/fake_series_repository.dart`**

```dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/repositories/series_repository.dart';

import 'fake_event_repository.dart';

/// In-memory [SeriesRepository] for widget tests. It records every call and
/// applies the same effects as the real one to [FakeEventRepository]'s events:
/// a new repeating event, an edit that splits the series, a delete from here.
/// It does not create the later days of a series; tests that need them add
/// occurrences with [FakeEventRepository.addOccurrence].
class FakeSeriesRepository implements SeriesRepository {
  FakeSeriesRepository(this._events);

  final FakeEventRepository _events;

  /// The rule of each series by id. Tests may seed it with [addSeries].
  final Map<int, RecurrenceRule> rules = {};

  /// Every `createRecurring` call.
  final List<
    ({
      DateTime day,
      String title,
      Tone tone,
      MinuteRange range,
      RecurrenceRule rule,
    })
  >
  created = [];

  /// Every `updateFromHere` call.
  final List<
    ({
      int eventId,
      String title,
      Tone tone,
      MinuteRange range,
      RecurrenceRule rule,
    })
  >
  updated = [];

  /// The event id of every `deleteFromHere` call.
  final List<int> deletedFrom = [];

  int _nextSeriesId = 100;

  /// Starts a series with [rule] and returns its id.
  int addSeries(RecurrenceRule rule) {
    final id = _nextSeriesId++;
    rules[id] = rule;
    return id;
  }

  @override
  Future<RecurrenceRule?> ruleFor(int seriesId) async => rules[seriesId];

  @override
  Future<int> createRecurring({
    required DateTime day,
    required String title,
    required Tone tone,
    required MinuteRange range,
    required RecurrenceRule rule,
  }) async {
    final id = await _events.createEvent(
      day: day,
      title: title,
      tone: tone,
      range: range,
    );
    _events.setSeriesId(id, addSeries(rule));
    created.add((
      day: startOfDay(day),
      title: title,
      tone: tone,
      range: range,
      rule: rule,
    ));
    return id;
  }

  @override
  Future<void> updateFromHere({
    required int eventId,
    required String title,
    required Tone tone,
    required MinuteRange range,
    required RecurrenceRule rule,
  }) async {
    final event = _events.eventById(eventId);
    if (event == null) return;
    await _events.moveEvent(id: eventId, day: event.date, range: range);
    await _events.updateDetails(id: eventId, title: title, tone: tone);

    final oldSeries = event.seriesId;
    if (oldSeries != null) {
      _events.removeSeriesFrom(oldSeries, nextDay(event.date));
    }
    _events.setSeriesId(eventId, rule.repeats ? addSeries(rule) : null);
    updated.add((
      eventId: eventId,
      title: title,
      tone: tone,
      range: range,
      rule: rule,
    ));
  }

  @override
  Future<void> deleteFromHere(int eventId) async {
    final event = _events.eventById(eventId);
    if (event == null) return;
    deletedFrom.add(eventId);

    final seriesId = event.seriesId;
    if (seriesId == null) {
      await _events.deleteEvent(eventId);
    } else {
      _events.removeSeriesFrom(seriesId, event.date);
    }
  }
}
```

**Create `test/support/fake_reuse_repository.dart`**

```dart
import 'dart:async';

import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/repositories/reuse_repository.dart';

import 'fake_event_repository.dart';

/// In-memory [ReuseRepository] for widget tests. Templates live in memory;
/// applying one and copying a day create events in [FakeEventRepository], with
/// the same refusals as the real repository.
class FakeReuseRepository implements ReuseRepository {
  FakeReuseRepository(this._events);

  final FakeEventRepository _events;
  final List<DayTemplate> _templates = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();
  int _nextId = 1;

  void dispose() {
    unawaited(_changes.close());
  }

  /// The saved templates, oldest first.
  List<DayTemplate> get templates => List.unmodifiable(_templates);

  /// Adds a template directly and returns its id.
  int addTemplate(String name, List<TemplateItem> items) {
    final id = _nextId++;
    _templates.add(DayTemplate(id: id, name: name, items: items));
    _notify();
    return id;
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  List<DayTemplate> _newestFirst() => _templates.reversed.toList();

  @override
  Stream<List<DayTemplate>> watchTemplates() async* {
    yield _newestFirst();
    yield* _changes.stream.map((_) => _newestFirst());
  }

  @override
  Future<int> saveTemplate({
    required String name,
    required DateTime day,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'A template needs a name');
    }
    final events = await _events.eventsForDay(day);
    if (events.isEmpty) throw const EmptyDayException();
    return addTemplate(trimmed, [
      for (final event in events)
        TemplateItem(title: event.title, tone: event.tone, range: event.range),
    ]);
  }

  @override
  Future<void> deleteTemplate(int id) async {
    _templates.removeWhere((template) => template.id == id);
    _notify();
  }

  Future<void> _requireEmpty(DateTime day) async {
    if ((await _events.eventsForDay(day)).isNotEmpty) {
      throw const DayNotEmptyException();
    }
  }

  @override
  Future<int> applyTemplate({
    required int templateId,
    required DateTime day,
  }) async {
    await _requireEmpty(day);
    final matches = _templates.where((template) => template.id == templateId);
    if (matches.isEmpty) return 0;
    final items = matches.single.items;
    for (final item in items) {
      await _events.createEvent(
        day: startOfDay(day),
        title: item.title,
        tone: item.tone,
        range: item.range,
      );
    }
    return items.length;
  }

  @override
  Future<int> copyDay({required DateTime from, required DateTime to}) async {
    await _requireEmpty(to);
    final source = await _events.eventsForDay(from);
    for (final event in source) {
      await _events.createEvent(
        day: startOfDay(to),
        title: event.title,
        tone: event.tone,
        range: event.range,
      );
    }
    return source.length;
  }
}
```

**Create `test/support/fake_calendar_repository.dart`**

```dart
import 'package:energy_clock/core/event_status.dart';
import 'package:energy_clock/core/time/month_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/repositories/calendar_repository.dart';

import 'fake_event_repository.dart';

/// In-memory [CalendarRepository] for widget tests: the planned minutes per
/// tone of each day of a month, worked out from [FakeEventRepository]'s events
/// and sent again when they change.
class FakeCalendarRepository implements CalendarRepository {
  FakeCalendarRepository(this._events);

  final FakeEventRepository _events;

  Map<DateTime, ToneMinutes> _month(DateTime month) {
    final first = startOfMonth(month);
    final end = addMonths(first, 1);
    final byDay = <DateTime, ToneMinutes>{};
    for (final event in _events.all) {
      if (event.date.isBefore(first) || !event.date.isBefore(end)) continue;
      if (event.status == EventStatus.skipped) continue;
      final minutes = byDay.putIfAbsent(event.date, () => <Tone, int>{});
      minutes[event.tone] =
          (minutes[event.tone] ?? 0) + event.range.durationMinutes;
    }
    return byDay;
  }

  @override
  Stream<Map<DateTime, ToneMinutes>> watchMonth(DateTime month) async* {
    yield _month(month);
    yield* _events.changes.map((_) => _month(month));
  }
}
```

**Edit `test/support/clock_harness.dart`**

Replace:

```dart
import 'fake_clock.dart';
import 'fake_event_repository.dart';
import 'fake_notification_service.dart';
import 'fake_session_repository.dart';
import 'fake_settings_repository.dart';
```

With:

```dart
import 'fake_calendar_repository.dart';
import 'fake_clock.dart';
import 'fake_event_repository.dart';
import 'fake_notification_service.dart';
import 'fake_reuse_repository.dart';
import 'fake_series_repository.dart';
import 'fake_session_repository.dart';
import 'fake_settings_repository.dart';
```

Replace:

```dart
/// A provider container with a fake clock, in-memory event, session and
/// settings repositories and a fake notification service, plus helpers to mount
```

With:

```dart
/// A provider container with a fake clock, in-memory event, series, reuse,
/// calendar, session and settings repositories (the series, reuse and calendar
/// fakes share the event fake's events) and a fake notification service, plus
/// helpers to mount
```

Replace:

```dart
    sessions = FakeSessionRepository(
      events: repository,
      clock: () => clock.current,
    );
```

With:

```dart
    series = FakeSeriesRepository(repository);
    reuse = FakeReuseRepository(repository);
    calendar = FakeCalendarRepository(repository);
    sessions = FakeSessionRepository(
      events: repository,
      clock: () => clock.current,
    );
```

Replace:

```dart
        eventRepositoryProvider.overrideWithValue(repository),
        sessionRepositoryProvider.overrideWithValue(sessions),
```

With:

```dart
        eventRepositoryProvider.overrideWithValue(repository),
        seriesRepositoryProvider.overrideWithValue(series),
        reuseRepositoryProvider.overrideWithValue(reuse),
        calendarRepositoryProvider.overrideWithValue(calendar),
        sessionRepositoryProvider.overrideWithValue(sessions),
```

Replace:

```dart
  final FakeEventRepository repository;
  late final FakeSessionRepository sessions;
```

With:

```dart
  final FakeEventRepository repository;
  late final FakeSeriesRepository series;
  late final FakeReuseRepository reuse;
  late final FakeCalendarRepository calendar;
  late final FakeSessionRepository sessions;
```

Replace:

```dart
    container.dispose();
    sessions.dispose();
    repository.dispose();
```

With:

```dart
    container.dispose();
    sessions.dispose();
    reuse.dispose();
    repository.dispose();
```

- [ ] **Step 4: Run the test, the analyzer and the whole suite**

```bash
# expect: PASS — 12 new tests; analyzer clean; every existing harness test stays green
flutter test test/support/fake_repositories_test.dart && flutter analyze && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add test
git commit -m "test: fakes for the series, reuse and calendar repositories

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---
### Task 10: The repeat picker

The control the event sheet uses to set how an event repeats (spec §7: "daily, weekdays, or a custom weekday picker, with an optional end date"). It is a stateless widget over a `RecurrenceRule`: it shows the rule and reports each change through `onChanged`, so the event sheet owns the state.

- A row of pills: **Never · Every day · Weekdays · Custom**.
- **Custom** reveals seven weekday toggles (M T W T F S S), starting with the event's own weekday selected. At least one day always stays selected: tapping the last selected day does nothing.
- Once an event repeats, an **Ends** row appears: **No end** or **On a date** (opens the platform date picker, from the event's day to ten years on; the chosen date shows on the pill).
- Every pill is at least 44 pt tall and has a spoken label and selected state; weekday toggles are spoken as "Monday", not "M".

Switching between daily, weekdays and custom keeps the end date; switching to "Never" drops it.

**Files:**
- Create: `lib/features/clock/widgets/repeat_picker.dart`
- Modify: `lib/core/strings.dart`
- Test: `test/features/clock/repeat_picker_test.dart`

**Interfaces:**
- Consumes: `RecurrenceRule`, `RecurrenceKind` (Task 1); `Strings.weekdayLong`, `Strings.weekdayInitials`, `Strings.repeatLabel` and the kind labels (Task 1).
- Produces: `RepeatPicker({required RecurrenceRule rule, required DateTime firstDay, required ValueChanged<RecurrenceRule> onChanged})`; `Strings.repeatEndsLabel`, `Strings.repeatNoEnd`, `Strings.repeatEndsOnDate`, `Strings.repeatEndsOn(String)`, `Strings.repeatEndHelp`.

- [ ] **Step 1: Write the failing test**

**Create `test/features/clock/repeat_picker_test.dart`**

```dart
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/clock/widgets/repeat_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;

  // Wednesday 7 October 2026.
  final firstDay = DateTime(2026, 10, 7);

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  /// Mounts the picker with its state held here, as the event sheet holds it,
  /// and records every change.
  Future<List<RecurrenceRule>> pump(
    WidgetTester tester, {
    RecurrenceRule rule = const RecurrenceRule.none(),
    double textScale = 1,
  }) async {
    final changes = <RecurrenceRule>[];
    await tester.pumpWidget(
      harness.app(
        StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: RepeatPicker(
              rule: rule,
              firstDay: firstDay,
              onChanged: (next) {
                changes.add(next);
                setState(() => rule = next);
              },
            ),
          ),
        ),
        textScale: textScale,
      ),
    );
    return changes;
  }

  testWidgets('shows the four kinds and no end row while not repeating', (
    tester,
  ) async {
    await pump(tester);

    for (final label in [
      Strings.repeatNever,
      Strings.repeatDaily,
      Strings.repeatWeekdays,
      Strings.repeatCustom,
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text(Strings.repeatEndsLabel), findsNothing);
    expect(find.text('M'), findsNothing);
  });

  testWidgets('the current kind reads as selected', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, rule: RecurrenceRule.weekdays());

    expect(
      tester.getSemantics(find.bySemanticsLabel(Strings.repeatWeekdays)),
      matchesSemantics(
        label: Strings.repeatWeekdays,
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel(Strings.repeatDaily)),
      matchesSemantics(
        label: Strings.repeatDaily,
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('weekday toggles are spoken as the full day name', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, rule: RecurrenceRule.custom({DateTime.wednesday}));

    expect(
      tester.getSemantics(find.byKey(const ValueKey('repeat-day-3'))),
      matchesSemantics(
        label: 'Wednesday',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('repeat-day-4'))),
      matchesSemantics(
        label: 'Thursday',
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('tapping a kind reports the rule', (tester) async {
    final changes = await pump(tester);

    await tester.tap(find.text(Strings.repeatDaily));
    await tester.pump();
    expect(changes.last, RecurrenceRule.daily());

    await tester.tap(find.text(Strings.repeatWeekdays));
    await tester.pump();
    expect(changes.last, RecurrenceRule.weekdays());

    await tester.tap(find.text(Strings.repeatNever));
    await tester.pump();
    expect(changes.last, const RecurrenceRule.none());
  });

  testWidgets('custom starts with the first day selected and shows the days', (
    tester,
  ) async {
    final changes = await pump(tester);

    await tester.tap(find.text(Strings.repeatCustom));
    await tester.pump();

    expect(changes.last, RecurrenceRule.custom({DateTime.wednesday}));
    expect(find.text('M'), findsOneWidget);
    expect(find.text('S'), findsNWidgets(2));
  });

  testWidgets('weekday toggles add and remove days', (tester) async {
    final changes = await pump(
      tester,
      rule: RecurrenceRule.custom({DateTime.wednesday}),
    );

    await tester.tap(find.byKey(const ValueKey('repeat-day-5')));
    await tester.pump();
    expect(changes.last, RecurrenceRule.custom({3, 5}));

    await tester.tap(find.byKey(const ValueKey('repeat-day-3')));
    await tester.pump();
    expect(changes.last, RecurrenceRule.custom({5}));
  });

  testWidgets('the last selected day cannot be switched off', (tester) async {
    final changes = await pump(
      tester,
      rule: RecurrenceRule.custom({DateTime.friday}),
    );

    await tester.tap(find.byKey(const ValueKey('repeat-day-5')));
    await tester.pump();

    expect(changes, isEmpty);
  });

  testWidgets('switching kind keeps the end day, switching to never drops it', (
    tester,
  ) async {
    final changes = await pump(
      tester,
      rule: RecurrenceRule.daily(until: DateTime(2026, 12, 31)),
    );

    await tester.tap(find.text(Strings.repeatWeekdays));
    await tester.pump();
    expect(
      changes.last,
      RecurrenceRule.weekdays(until: DateTime(2026, 12, 31)),
    );

    await tester.tap(find.text(Strings.repeatNever));
    await tester.pump();
    expect(changes.last, const RecurrenceRule.none());
    expect(find.text(Strings.repeatEndsLabel), findsNothing);
  });

  testWidgets('the end row appears once the event repeats', (tester) async {
    await pump(tester, rule: RecurrenceRule.daily());

    expect(find.text(Strings.repeatEndsLabel), findsOneWidget);
    expect(find.text(Strings.repeatNoEnd), findsOneWidget);
    expect(find.text(Strings.repeatEndsOnDate), findsOneWidget);
  });

  testWidgets('picking an end date reports it and shows it on the pill', (
    tester,
  ) async {
    final changes = await pump(tester, rule: RecurrenceRule.daily());

    await tester.tap(find.text(Strings.repeatEndsOnDate));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);

    // The picker opens on a month after the first day; accept it.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(changes.last, RecurrenceRule.daily(until: DateTime(2026, 11, 7)));
    expect(find.text(Strings.repeatEndsOn('7 Nov 2026')), findsOneWidget);
  });

  testWidgets('no end clears the end day', (tester) async {
    final changes = await pump(
      tester,
      rule: RecurrenceRule.daily(until: DateTime(2026, 12, 31)),
    );
    expect(find.text(Strings.repeatEndsOn('31 Dec 2026')), findsOneWidget);

    await tester.tap(find.text(Strings.repeatNoEnd));
    await tester.pump();

    expect(changes.last, RecurrenceRule.daily());
  });

  testWidgets('cancelling the date picker changes nothing', (tester) async {
    final changes = await pump(tester, rule: RecurrenceRule.daily());

    await tester.tap(find.text(Strings.repeatEndsOnDate));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(changes, isEmpty);
  });

  testWidgets('every pill and toggle is at least 44 points tall', (
    tester,
  ) async {
    await pump(tester, rule: RecurrenceRule.custom({DateTime.wednesday}));

    for (final label in [
      Strings.repeatNever,
      Strings.repeatDaily,
      Strings.repeatWeekdays,
      Strings.repeatCustom,
      Strings.repeatNoEnd,
      Strings.repeatEndsOnDate,
    ]) {
      final pill = find.ancestor(
        of: find.text(label),
        matching: find.byType(DecoratedBox),
      );
      expect(
        tester.getSize(pill.first).height,
        greaterThanOrEqualTo(44),
        reason: label,
      );
    }
    for (var weekday = 1; weekday <= 7; weekday++) {
      expect(
        tester.getSize(find.byKey(ValueKey('repeat-day-$weekday'))).height,
        greaterThanOrEqualTo(44),
      );
    }
  });

  for (final width in [320.0, 375.0, 402.0]) {
    for (final textScale in [1.0, 2.0, 3.12]) {
      testWidgets(
        'fits a ${width.toInt()} pt window at text ${(textScale * 100).toInt()}%',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await pump(
            tester,
            rule: RecurrenceRule.custom({
              DateTime.monday,
              DateTime.thursday,
            }, until: DateTime(2026, 12, 31)),
            textScale: textScale,
          );

          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
```

- [ ] **Step 2: Run the test to see it fail**

```bash
# expect: FAIL — repeat_picker.dart and the new strings do not exist yet
flutter test test/features/clock/repeat_picker_test.dart
```

- [ ] **Step 3: Write the code**

**Edit `lib/core/strings.dart`**

Replace:

```dart
  static String repeatUntil(String date) => 'until $date';
}
```

With:

```dart
  static String repeatUntil(String date) => 'until $date';
  static const String repeatEndsLabel = 'Ends';
  static const String repeatNoEnd = 'No end';
  static const String repeatEndsOnDate = 'On a date';
  static String repeatEndsOn(String date) => 'On $date';
  static const String repeatEndHelp = 'Last day it repeats';
}
```

**Create `lib/features/clock/widgets/repeat_picker.dart`**

```dart
import 'dart:async';

import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/shared/widgets/press_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// How an event repeats: Never, Every day, Weekdays or Custom, with seven
/// weekday toggles for Custom and an optional end date once it repeats.
///
/// It holds no state. It shows [rule] and reports every change through
/// [onChanged], so the event sheet owns the value. [firstDay] is the event's
/// own day: Custom starts with its weekday selected, and the end date cannot
/// be earlier than it.
class RepeatPicker extends StatelessWidget {
  const RepeatPicker({
    required this.rule,
    required this.firstDay,
    required this.onChanged,
    super.key,
  });

  final RecurrenceRule rule;
  final DateTime firstDay;
  final ValueChanged<RecurrenceRule> onChanged;

  void _selectKind(RecurrenceKind kind) {
    final until = rule.until;
    onChanged(switch (kind) {
      RecurrenceKind.none => const RecurrenceRule.none(),
      RecurrenceKind.daily => RecurrenceRule.daily(until: until),
      RecurrenceKind.weekdays => RecurrenceRule.weekdays(until: until),
      RecurrenceKind.custom =>
        rule.kind == RecurrenceKind.custom
            ? rule
            : RecurrenceRule.custom({firstDay.weekday}, until: until),
    });
  }

  void _toggleDay(int weekday) {
    final days = {...rule.weekdays};
    if (!days.add(weekday)) {
      // At least one day always stays on.
      if (days.length == 1) return;
      days.remove(weekday);
    }
    onChanged(RecurrenceRule.custom(days, until: rule.until));
  }

  Future<void> _pickEndDate(BuildContext context) async {
    final first = startOfDay(firstDay);
    final suggested = DateTime(first.year, first.month + 1, first.day);
    final current = rule.until;
    final initial = current == null || current.isBefore(first)
        ? suggested
        : current;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(first.year + 10, first.month, first.day),
      helpText: Strings.repeatEndHelp,
    );
    if (picked != null) onChanged(rule.withUntil(picked));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final until = rule.until;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(Strings.repeatLabel, style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _Pill(
              label: Strings.repeatNever,
              selected: !rule.repeats,
              onTap: () => _selectKind(RecurrenceKind.none),
            ),
            _Pill(
              label: Strings.repeatDaily,
              selected: rule.kind == RecurrenceKind.daily,
              onTap: () => _selectKind(RecurrenceKind.daily),
            ),
            _Pill(
              label: Strings.repeatWeekdays,
              selected: rule.kind == RecurrenceKind.weekdays,
              onTap: () => _selectKind(RecurrenceKind.weekdays),
            ),
            _Pill(
              label: Strings.repeatCustom,
              selected: rule.kind == RecurrenceKind.custom,
              onTap: () => _selectKind(RecurrenceKind.custom),
            ),
          ],
        ),
        if (rule.kind == RecurrenceKind.custom) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _DayToggle(
                      key: ValueKey('repeat-day-${DateTime.monday + i}'),
                      initial: Strings.weekdayInitials[i],
                      name: Strings.weekdayLong[i],
                      selected: rule.occursOnWeekday(DateTime.monday + i),
                      onTap: () => _toggleDay(DateTime.monday + i),
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (rule.repeats) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(Strings.repeatEndsLabel, style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _Pill(
                label: Strings.repeatNoEnd,
                selected: until == null,
                onTap: () => onChanged(rule.withUntil(null)),
              ),
              _Pill(
                label: until == null
                    ? Strings.repeatEndsOnDate
                    : Strings.repeatEndsOn(DateFormat('d MMM y').format(until)),
                selected: until != null,
                onTap: () => unawaited(_pickEndDate(context)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A rounded choice: ink fill when selected, a faint ink fill otherwise.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        onTap: () {
          if (!selected) unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? colors.ink : colors.ink.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                    color: selected ? colors.onInk : colors.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One weekday of the custom picker: its initial, read aloud as the full name.
/// A seventh of the row wide and 48 pt tall.
class _DayToggle extends StatelessWidget {
  const _DayToggle({
    required this.initial,
    required this.name,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String initial;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? colors.ink : colors.ink.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          child: SizedBox(
            height: 48,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  initial,
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                    color: selected ? colors.onInk : colors.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test, the analyzer and the whole suite**

```bash
# expect: PASS — 22 new tests; analyzer clean; the whole suite stays green
flutter test test/features/clock/repeat_picker_test.dart && flutter analyze && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat: repeat picker with weekday toggles and an end date

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---
### Task 11: Asking "this event" or "this and all future"

Spec §7: editing an occurrence of a repeating event "prompts 'This event' or 'This and all future'". Deleting one needs the same question. This task adds the prompt, in two layers:

- `chooseOne` (shared): a platform-adaptive picker of one option out of a few, with a cancel. On iOS it is the native action sheet; elsewhere a Material dialog. It follows `confirmDestructive`'s rule of checking for iOS explicitly rather than using an `.adaptive` widget, which also picks the iOS style on macOS and would change what `flutter test` sees on a Mac.
- `askEditScope` and `askDeleteScope` (Clock feature): the two questions, with the app's wording. When the person has changed **how the event repeats**, "this event only" would make no sense (a single occurrence cannot have a different rule), so the prompt offers only "This and all future events" and says so.

**Files:**
- Create: `lib/shared/widgets/adaptive_choice.dart`, `lib/features/clock/widgets/edit_scope.dart`
- Modify: `lib/core/strings.dart`
- Test: `test/shared/widgets/adaptive_choice_test.dart`, `test/features/clock/edit_scope_test.dart`

**Interfaces:**
- Produces: `ChoiceOption<T>({required String label, required T value, bool destructive = false})`; `chooseOne<T>(BuildContext, {required String title, String? body, required List<ChoiceOption<T>> options, required String cancelLabel}) → Future<T?>` (null when cancelled or dismissed); `enum EditScope { thisEvent, thisAndFuture }`; `askEditScope(BuildContext, {bool ruleChanged = false}) → Future<EditScope?>`; `askDeleteScope(BuildContext) → Future<EditScope?>`; `Strings.editScopeTitle`, `.deleteScopeTitle`, `.scopeThisEvent`, `.scopeThisAndFuture`, `.repeatChangeTitle`, `.repeatChangeBody`.

- [ ] **Step 1: Write the failing tests**

**Create `test/shared/widgets/adaptive_choice_test.dart`**

```dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/shared/widgets/adaptive_choice.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens the chooser from a button and returns what it resolved to, once the
/// caller has driven it.
class ChooserResult {
  bool done = false;
  String? value;
}

Future<ChooserResult> openChooser(
  WidgetTester tester, {
  String? body = 'Which ones?',
  bool destructive = false,
}) async {
  final result = ChooserResult();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result.value = await chooseOne<String>(
                context,
                title: 'Edit repeating event',
                body: body,
                options: [
                  ChoiceOption(
                    label: 'This event',
                    value: 'one',
                    destructive: destructive,
                  ),
                  ChoiceOption(
                    label: 'This and all future events',
                    value: 'future',
                    destructive: destructive,
                  ),
                ],
                cancelLabel: 'Cancel',
              );
              result.done = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  group('Material', () {
    final android = TargetPlatformVariant.only(TargetPlatform.android);

    testWidgets('shows the title, the body and every option', (tester) async {
      await openChooser(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Edit repeating event'), findsOneWidget);
      expect(find.text('Which ones?'), findsOneWidget);
      expect(find.text('This event'), findsOneWidget);
      expect(find.text('This and all future events'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    }, variant: android);

    testWidgets('leaves the body out when there is none', (tester) async {
      await openChooser(tester, body: null);
      expect(find.text('Which ones?'), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
    }, variant: android);

    testWidgets('returns the chosen option', (tester) async {
      final result = await openChooser(tester);

      await tester.tap(find.text('This and all future events'));
      await tester.pumpAndSettle();

      expect(result.done, isTrue);
      expect(result.value, 'future');
      expect(find.byType(AlertDialog), findsNothing);
    }, variant: android);

    testWidgets('cancel returns null', (tester) async {
      final result = await openChooser(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result.done, isTrue);
      expect(result.value, isNull);
    }, variant: android);

    testWidgets('a destructive option uses the danger colour', (tester) async {
      await openChooser(tester, destructive: true);

      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'This event'),
      );
      expect(
        button.style!.foregroundColor!.resolve({}),
        AppColors.light.danger,
      );
      final cancel = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Cancel'),
      );
      expect(cancel.style, isNull);
    }, variant: android);

    testWidgets('tapping outside returns null', (tester) async {
      final result = await openChooser(tester);

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(result.done, isTrue);
      expect(result.value, isNull);
    }, variant: android);
  });

  group('iOS', () {
    final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

    testWidgets('shows a native action sheet', (tester) async {
      await openChooser(tester);

      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Edit repeating event'), findsOneWidget);
      expect(find.text('Which ones?'), findsOneWidget);
      expect(find.text('This event'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    }, variant: ios);

    testWidgets('returns the chosen option', (tester) async {
      final result = await openChooser(tester);

      await tester.tap(find.text('This event'));
      await tester.pumpAndSettle();

      expect(result.value, 'one');
      expect(find.byType(CupertinoActionSheet), findsNothing);
    }, variant: ios);

    testWidgets('cancel returns null', (tester) async {
      final result = await openChooser(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result.done, isTrue);
      expect(result.value, isNull);
    }, variant: ios);

    testWidgets('a destructive option is marked destructive', (tester) async {
      await openChooser(tester, destructive: true);

      final action = tester.widget<CupertinoActionSheetAction>(
        find.widgetWithText(CupertinoActionSheetAction, 'This event'),
      );
      expect(action.isDestructiveAction, isTrue);
    }, variant: ios);
  });
}
```

**Create `test/features/clock/edit_scope_test.dart`**

```dart
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/clock/widgets/edit_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Runs [ask] from a button. [onResult] receives what it resolved to.
  Future<void> open(
    WidgetTester tester,
    Future<EditScope?> Function(BuildContext) ask, {
    void Function(EditScope?)? onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final scope = await ask(context);
                onResult?.call(scope);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('an edit offers this event and this and all future', (
    tester,
  ) async {
    await open(tester, askEditScope);

    expect(find.text(Strings.editScopeTitle), findsOneWidget);
    expect(find.text(Strings.scopeThisEvent), findsOneWidget);
    expect(find.text(Strings.scopeThisAndFuture), findsOneWidget);
    expect(find.text(Strings.cancel), findsOneWidget);
  });

  testWidgets('choosing this event resolves to thisEvent', (tester) async {
    final results = <EditScope?>[];
    await open(tester, askEditScope, onResult: results.add);

    await tester.tap(find.text(Strings.scopeThisEvent));
    await tester.pumpAndSettle();

    expect(results, [EditScope.thisEvent]);
  });

  testWidgets('choosing this and all future resolves to thisAndFuture', (
    tester,
  ) async {
    final results = <EditScope?>[];
    await open(tester, askEditScope, onResult: results.add);

    await tester.tap(find.text(Strings.scopeThisAndFuture));
    await tester.pumpAndSettle();

    expect(results, [EditScope.thisAndFuture]);
  });

  testWidgets('cancelling resolves to null', (tester) async {
    final results = <EditScope?>[];
    await open(tester, askEditScope, onResult: results.add);

    await tester.tap(find.text(Strings.cancel));
    await tester.pumpAndSettle();

    expect(results, [null]);
  });

  testWidgets('changing how it repeats offers only this and all future', (
    tester,
  ) async {
    await open(tester, (context) => askEditScope(context, ruleChanged: true));

    expect(find.text(Strings.repeatChangeTitle), findsOneWidget);
    expect(find.text(Strings.repeatChangeBody), findsOneWidget);
    expect(find.text(Strings.scopeThisAndFuture), findsOneWidget);
    expect(find.text(Strings.scopeThisEvent), findsNothing);
  });

  testWidgets('deleting asks with the delete wording', (tester) async {
    await open(tester, askDeleteScope);

    expect(find.text(Strings.deleteScopeTitle), findsOneWidget);
    expect(find.text(Strings.scopeThisEvent), findsOneWidget);
    expect(find.text(Strings.scopeThisAndFuture), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the tests to see them fail**

```bash
# expect: FAIL — adaptive_choice.dart, edit_scope.dart and the strings do not exist yet
flutter test test/shared/widgets/adaptive_choice_test.dart test/features/clock/edit_scope_test.dart
```

- [ ] **Step 3: Write the code**

**Edit `lib/core/strings.dart`**

Replace:

```dart
  static const String repeatEndHelp = 'Last day it repeats';
}
```

With:

```dart
  static const String repeatEndHelp = 'Last day it repeats';

  // Choosing how far a change to a repeating event reaches.
  static const String editScopeTitle = 'Edit repeating event';
  static const String deleteScopeTitle = 'Delete repeating event';
  static const String scopeThisEvent = 'This event';
  static const String scopeThisAndFuture = 'This and all future events';
  static const String repeatChangeTitle = 'Change how it repeats?';
  static const String repeatChangeBody =
      'This applies to this event and all future ones.';
}
```

**Create `lib/shared/widgets/adaptive_choice.dart`**

```dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// One choice offered by [chooseOne].
class ChoiceOption<T> {
  const ChoiceOption({
    required this.label,
    required this.value,
    this.destructive = false,
  });

  final String label;
  final T value;

  /// Shown in the destructive style (red on iOS, the `danger` colour
  /// elsewhere).
  final bool destructive;
}

/// Asks the person to pick one of [options], or cancel. Returns the picked
/// option's value, or null when they cancel or dismiss it. Shows the native
/// action sheet on iOS and a Material dialog on every other platform.
///
/// Like `confirmDestructive`, the choice is an explicit check for iOS, not an
/// `.adaptive` widget, which also picks the iOS style on macOS: `flutter test`
/// reports the host's platform, and this app only ships to iOS.
Future<T?> chooseOne<T>(
  BuildContext context, {
  required String title,
  required List<ChoiceOption<T>> options,
  required String cancelLabel,
  String? body,
}) {
  final isIos = Theme.of(context).platform == TargetPlatform.iOS;

  if (isIos) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(title),
        message: body == null ? null : Text(body),
        actions: [
          for (final option in options)
            CupertinoActionSheetAction(
              isDestructiveAction: option.destructive,
              onPressed: () => Navigator.of(sheetContext).pop(option.value),
              child: Text(option.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(cancelLabel),
        ),
      ),
    );
  }

  return showDialog<T>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(cancelLabel),
        ),
        for (final option in options)
          TextButton(
            style: option.destructive
                ? TextButton.styleFrom(
                    foregroundColor: dialogContext.appColors.danger,
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(option.value),
            child: Text(option.label),
          ),
      ],
    ),
  );
}
```

**Create `lib/features/clock/widgets/edit_scope.dart`**

```dart
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/shared/widgets/adaptive_choice.dart';
import 'package:flutter/widgets.dart';

/// How far a change to one event of a repeating series reaches.
enum EditScope {
  /// Only the event the person is looking at. The series is left alone.
  thisEvent,

  /// This event and every later one: the series is split here.
  thisAndFuture,
}

/// Asks how far an edit of a repeating event reaches. Returns null when the
/// person cancels.
///
/// When [ruleChanged] is true they have changed how the event repeats, which
/// cannot apply to a single occurrence, so only "this and all future" is
/// offered and the prompt says so.
Future<EditScope?> askEditScope(
  BuildContext context, {
  bool ruleChanged = false,
}) {
  if (ruleChanged) {
    return chooseOne<EditScope>(
      context,
      title: Strings.repeatChangeTitle,
      body: Strings.repeatChangeBody,
      options: const [
        ChoiceOption(
          label: Strings.scopeThisAndFuture,
          value: EditScope.thisAndFuture,
        ),
      ],
      cancelLabel: Strings.cancel,
    );
  }
  return chooseOne<EditScope>(
    context,
    title: Strings.editScopeTitle,
    options: const [
      ChoiceOption(label: Strings.scopeThisEvent, value: EditScope.thisEvent),
      ChoiceOption(
        label: Strings.scopeThisAndFuture,
        value: EditScope.thisAndFuture,
      ),
    ],
    cancelLabel: Strings.cancel,
  );
}

/// Asks how far a delete of a repeating event reaches. Returns null when the
/// person cancels.
Future<EditScope?> askDeleteScope(BuildContext context) {
  return chooseOne<EditScope>(
    context,
    title: Strings.deleteScopeTitle,
    options: const [
      ChoiceOption(
        label: Strings.scopeThisEvent,
        value: EditScope.thisEvent,
        destructive: true,
      ),
      ChoiceOption(
        label: Strings.scopeThisAndFuture,
        value: EditScope.thisAndFuture,
        destructive: true,
      ),
    ],
    cancelLabel: Strings.cancel,
  );
}
```

- [ ] **Step 4: Run the tests, the analyzer and the whole suite**

```bash
# expect: PASS — 16 new tests; analyzer clean; the whole suite stays green
flutter test test/shared/widgets/adaptive_choice_test.dart test/features/clock/edit_scope_test.dart && flutter analyze && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat: ask whether a change reaches this event or all future ones

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---
### Task 12: The event sheet repeats

The new/edit sheet gains the **Repeat** section (spec §5.2 and §7: "a repeat option"), and saving learns the three situations repetition creates:

| The sheet is… | Repeat is… | Saving does |
|---|---|---|
| New | Never | `createEvent` (unchanged) |
| New | anything else | `SeriesRepository.createRecurring` |
| Editing a **one-off** event | Never | move + update the event (unchanged) |
| Editing a one-off event | anything else | `updateFromHere`: the event starts repeating; no question to ask |
| Editing an **occurrence** of a series | unchanged, nothing else changed | just closes |
| Editing an occurrence | changed times/title/tone | asks **This event** or **This and all future events**; "this event" is move + update, "future" is `updateFromHere` |
| Editing an occurrence | **changed repeat rule** | asks, offering only **This and all future events** (a single occurrence cannot have a different rule) |

The rule of an occurrence comes from its series; it loads a moment after the sheet opens (the sheet waits for it on Save, so a quick Save cannot read a rule that has not arrived). A fourth overlapping ring is refused with the usual message, for a repeating event too, and the sheet stays open. Dragging an occurrence on the dial moves **that event only**, without asking.

**Files:**
- Modify: `lib/features/clock/widgets/event_sheet.dart`
- Test: `test/features/clock/event_sheet_repeat_test.dart`

**Interfaces:**
- Consumes: `RepeatPicker` (Task 10); `askEditScope`, `EditScope` (Task 11); `seriesRepositoryProvider` (Task 8); `SeriesRepository.createRecurring`, `updateFromHere`, `ruleFor` (Task 6).
- Produces: nothing new for later tasks; `EventSheet.show` keeps its signature.

- [ ] **Step 1: Write the failing test**

**Create `test/features/clock/event_sheet_repeat_test.dart`**

```dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/widgets/event_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;

  // Wednesday 7 October 2026.
  final day = DateTime(2026, 10, 7);

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  /// An occurrence of a weekdays series, on [day].
  int addOccurrence({RecurrenceRule? rule}) {
    final seriesId = harness.series.addSeries(
      rule ?? RecurrenceRule.weekdays(),
    );
    return harness.repository.addOccurrence(
      seriesId: seriesId,
      day: day,
      title: 'Standup',
      range: const MinuteRange(540, 570),
    );
  }

  Future<void> openSheet(WidgetTester tester, {int? editing}) async {
    tester.view.physicalSize = const Size(402, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final existing = editing == null
        ? null
        : harness.repository.eventById(editing);
    await tester.pumpWidget(
      harness.app(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => EventSheet.show(
              context,
              day: day,
              initialRange: existing?.range ?? const MinuteRange(540, 720),
              existing: existing,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapLabel(WidgetTester tester, String label) async {
    final finder = find.text(label);
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) => tapLabel(tester, Strings.save);

  testWidgets('a new event starts as never repeating', (tester) async {
    final handle = tester.ensureSemantics();
    await openSheet(tester);

    expect(
      tester.getSemantics(find.bySemanticsLabel(Strings.repeatNever)),
      matchesSemantics(
        label: Strings.repeatNever,
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    expect(find.text(Strings.repeatEndsLabel), findsNothing);
    handle.dispose();
  });

  testWidgets('a repeating event is created as a series', (tester) async {
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), 'Standup');
    await tapLabel(tester, Strings.repeatWeekdays);

    await save(tester);

    expect(find.byType(EventSheet), findsNothing);
    final created = harness.series.created.single;
    expect(created.title, 'Standup');
    expect(created.tone, Tone.focus);
    expect(created.range, const MinuteRange(540, 720));
    expect(created.rule, RecurrenceRule.weekdays());
    expect(created.day, day);
    final events = await harness.repository.eventsForDay(day);
    expect(events.single.seriesId, isNotNull);
  });

  testWidgets('an event that does not repeat is created without a series', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), 'Deep work');

    await save(tester);

    expect(harness.series.created, isEmpty);
    final events = await harness.repository.eventsForDay(day);
    expect(events.single.seriesId, isNull);
  });

  testWidgets('custom starts on the day of the week of the event', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), 'Review');
    await tapLabel(tester, Strings.repeatCustom);

    await save(tester);

    expect(
      harness.series.created.single.rule,
      RecurrenceRule.custom({DateTime.wednesday}),
    );
  });

  testWidgets('an end date is saved with the rule', (tester) async {
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), 'Standup');
    await tapLabel(tester, Strings.repeatDaily);
    await tapLabel(tester, Strings.repeatEndsOnDate);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await save(tester);

    expect(
      harness.series.created.single.rule,
      RecurrenceRule.daily(until: DateTime(2026, 11, 7)),
    );
  });

  testWidgets('a repeating event on a full day is refused with a message', (
    tester,
  ) async {
    for (final range in const [
      MinuteRange(540, 720),
      MinuteRange(600, 660),
      MinuteRange(610, 620),
    ]) {
      await harness.repository.createEvent(
        day: day,
        title: 'Existing',
        tone: Tone.focus,
        range: range,
      );
    }
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), 'Fourth');
    await tapLabel(tester, Strings.repeatDaily);

    await save(tester);

    expect(find.text(Strings.ringOverflow), findsOneWidget);
    expect(find.byType(EventSheet), findsOneWidget);
    expect(harness.series.created, isEmpty);
    expect(await harness.repository.eventsForDay(day), hasLength(3));
  });

  group('editing a one-off event', () {
    late int id;

    setUp(() async {
      id = await harness.repository.createEvent(
        day: day,
        title: 'Deep work',
        tone: Tone.focus,
        range: const MinuteRange(540, 720),
      );
    });

    testWidgets('saves without asking anything', (tester) async {
      await openSheet(tester, editing: id);
      await tester.enterText(find.byType(TextField), 'Renamed');

      await save(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(EventSheet), findsNothing);
      expect(harness.repository.eventById(id)!.title, 'Renamed');
      expect(harness.series.updated, isEmpty);
    });

    testWidgets('can start repeating, without asking', (tester) async {
      await openSheet(tester, editing: id);
      await tapLabel(tester, Strings.repeatWeekdays);

      await save(tester);

      expect(find.byType(AlertDialog), findsNothing);
      final updated = harness.series.updated.single;
      expect(updated.eventId, id);
      expect(updated.rule, RecurrenceRule.weekdays());
      expect(harness.repository.eventById(id)!.seriesId, isNotNull);
    });
  });

  group('editing an occurrence of a series', () {
    testWidgets('shows the rule of its series', (tester) async {
      final handle = tester.ensureSemantics();
      final id = addOccurrence();
      await openSheet(tester, editing: id);

      expect(
        tester.getSemantics(find.bySemanticsLabel(Strings.repeatWeekdays)),
        matchesSemantics(
          label: Strings.repeatWeekdays,
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('saving with nothing changed just closes', (tester) async {
      final id = addOccurrence();
      await openSheet(tester, editing: id);

      await save(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(EventSheet), findsNothing);
      expect(harness.series.updated, isEmpty);
    });

    testWidgets('a changed title asks, and "this event" leaves the series', (
      tester,
    ) async {
      final id = addOccurrence();
      final seriesId = harness.repository.eventById(id)!.seriesId;
      await openSheet(tester, editing: id);
      await tester.enterText(find.byType(TextField), 'Renamed');

      await save(tester);
      expect(find.text(Strings.editScopeTitle), findsOneWidget);
      await tester.tap(find.text(Strings.scopeThisEvent));
      await tester.pumpAndSettle();

      expect(find.byType(EventSheet), findsNothing);
      final event = harness.repository.eventById(id)!;
      expect(event.title, 'Renamed');
      expect(event.seriesId, seriesId);
      expect(harness.series.updated, isEmpty);
    });

    testWidgets('"this and all future events" splits the series', (
      tester,
    ) async {
      final id = addOccurrence();
      final seriesId = harness.repository.eventById(id)!.seriesId;
      await openSheet(tester, editing: id);
      await tester.enterText(find.byType(TextField), 'Renamed');

      await save(tester);
      await tester.tap(find.text(Strings.scopeThisAndFuture));
      await tester.pumpAndSettle();

      final updated = harness.series.updated.single;
      expect(updated.eventId, id);
      expect(updated.title, 'Renamed');
      expect(updated.rule, RecurrenceRule.weekdays());
      final event = harness.repository.eventById(id)!;
      expect(event.title, 'Renamed');
      expect(event.seriesId, isNot(seriesId));
    });

    testWidgets('a changed time counts as a change', (tester) async {
      final id = addOccurrence();
      await openSheet(tester, editing: id);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is IconButton &&
              widget.tooltip == Strings.stepperIncrease(Strings.endLabel),
        ),
      );
      await tester.pump();

      await save(tester);

      expect(find.text(Strings.editScopeTitle), findsOneWidget);
    });

    testWidgets('cancelling the question keeps the sheet and changes nothing', (
      tester,
    ) async {
      final id = addOccurrence();
      await openSheet(tester, editing: id);
      await tester.enterText(find.byType(TextField), 'Renamed');

      await save(tester);
      await tester.tap(find.text(Strings.cancel));
      await tester.pumpAndSettle();

      expect(find.byType(EventSheet), findsOneWidget);
      expect(harness.repository.eventById(id)!.title, 'Standup');
      expect(harness.series.updated, isEmpty);
    });

    testWidgets('changing the rule offers only "this and all future"', (
      tester,
    ) async {
      final id = addOccurrence();
      await openSheet(tester, editing: id);
      await tapLabel(tester, Strings.repeatDaily);

      await save(tester);

      expect(find.text(Strings.repeatChangeTitle), findsOneWidget);
      expect(find.text(Strings.scopeThisEvent), findsNothing);
      await tester.tap(find.text(Strings.scopeThisAndFuture));
      await tester.pumpAndSettle();

      expect(harness.series.updated.single.rule, RecurrenceRule.daily());
    });

    testWidgets('turning repeat off makes it a one-off from here', (
      tester,
    ) async {
      final id = addOccurrence();
      await openSheet(tester, editing: id);
      await tapLabel(tester, Strings.repeatNever);

      await save(tester);
      await tester.tap(find.text(Strings.scopeThisAndFuture));
      await tester.pumpAndSettle();

      expect(harness.series.updated.single.rule, const RecurrenceRule.none());
      expect(harness.repository.eventById(id)!.seriesId, isNull);
    });

    testWidgets('a fourth overlapping ring is refused with a message', (
      tester,
    ) async {
      final id = addOccurrence();
      // Three events that overlap each other, starting where the occurrence
      // ends. Stretching the occurrence's end over all three needs a fourth
      // ring.
      for (final range in const [
        MinuteRange(570, 700),
        MinuteRange(575, 700),
        MinuteRange(580, 700),
      ]) {
        await harness.repository.createEvent(
          day: day,
          title: 'Busy',
          tone: Tone.focus,
          range: range,
        );
      }
      await openSheet(tester, editing: id);
      for (var i = 0; i < 3; i++) {
        await tester.tap(
          find.byWidgetPredicate(
            (widget) =>
                widget is IconButton &&
                widget.tooltip == Strings.stepperIncrease(Strings.endLabel),
          ),
        );
        await tester.pump();
      }

      await save(tester);
      await tester.tap(find.text(Strings.scopeThisEvent));
      await tester.pumpAndSettle();

      expect(find.text(Strings.ringOverflow), findsOneWidget);
      expect(find.byType(EventSheet), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run the test to see it fail**

```bash
# expect: FAIL — the sheet has no Repeat section yet
flutter test test/features/clock/event_sheet_repeat_test.dart
```

- [ ] **Step 3: Write the code**

**Edit `lib/features/clock/widgets/event_sheet.dart`**

Replace:

```dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
```

With:

```dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/strings.dart';
```

Replace:

```dart
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:energy_clock/features/clock/providers.dart';
```

With:

```dart
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/edit_scope.dart';
import 'package:energy_clock/features/clock/widgets/repeat_picker.dart';
```

Replace:

```dart
  String? _titleError;
  String? _saveError;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }
```

With:

```dart
  String? _titleError;
  String? _saveError;

  /// How the event repeats. For an occurrence of a series it becomes the
  /// series' rule once that has loaded. [_originalRule] is what it started as,
  /// to tell whether the person changed it.
  RecurrenceRule _rule = const RecurrenceRule.none();
  RecurrenceRule _originalRule = const RecurrenceRule.none();
  Future<void>? _ruleLoad;

  @override
  void initState() {
    super.initState();
    final seriesId = widget.existing?.seriesId;
    if (seriesId != null) _ruleLoad = _loadRule(seriesId);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  /// Reads the series' rule. If it cannot be read, or the series is gone, the
  /// event is treated as not repeating.
  Future<void> _loadRule(int seriesId) async {
    RecurrenceRule? loaded;
    try {
      loaded = await ref.read(seriesRepositoryProvider).ruleFor(seriesId);
    } on Object {
      loaded = null;
    }
    if (!mounted || loaded == null) return;
    final rule = loaded;
    setState(() {
      // Keep a choice the person made before the rule arrived.
      if (_rule == _originalRule) _rule = rule;
      _originalRule = rule;
    });
  }
```

Replace:

```dart
    final repository = ref.read(eventRepositoryProvider);
    try {
      final existing = widget.existing;
      if (existing == null) {
        await repository.createEvent(
          day: widget.day,
          title: title,
          tone: _tone,
          range: _range,
        );
      } else {
        await repository.moveEvent(
          id: existing.id,
          day: widget.day,
          range: _range,
        );
        await repository.updateDetails(
          id: existing.id,
          title: title,
          tone: _tone,
        );
      }
    } on RingOverflowException {
      setState(() => _saveError = Strings.ringOverflow);
      return;
    }

    if (mounted) Navigator.of(context).pop();
  }
```

With:

```dart
    try {
      final existing = widget.existing;
      if (existing == null) {
        await _create(title);
      } else if (!await _update(existing, title)) {
        return;
      }
    } on RingOverflowException {
      setState(() => _saveError = Strings.ringOverflow);
      return;
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _create(String title) async {
    if (_rule.repeats) {
      await ref
          .read(seriesRepositoryProvider)
          .createRecurring(
            day: widget.day,
            title: title,
            tone: _tone,
            range: _range,
            rule: _rule,
          );
    } else {
      await ref
          .read(eventRepositoryProvider)
          .createEvent(
            day: widget.day,
            title: title,
            tone: _tone,
            range: _range,
          );
    }
  }

  /// Saves the edit of [existing]. Returns false if the person cancelled the
  /// question of how far it reaches.
  Future<bool> _update(CalendarEvent existing, String title) async {
    // A quick Save must not read a rule that has not arrived yet.
    await _ruleLoad;
    if (!mounted) return false;

    final events = ref.read(eventRepositoryProvider);
    final series = ref.read(seriesRepositoryProvider);

    Future<void> thisEventOnly() async {
      await events.moveEvent(id: existing.id, day: widget.day, range: _range);
      await events.updateDetails(id: existing.id, title: title, tone: _tone);
    }

    Future<void> fromHere() => series.updateFromHere(
      eventId: existing.id,
      title: title,
      tone: _tone,
      range: _range,
      rule: _rule,
    );

    if (existing.seriesId == null) {
      // A one-off event: it stays one, or it starts repeating.
      await (_rule.repeats ? fromHere() : thisEventOnly());
      return true;
    }

    final ruleChanged = _rule != _originalRule;
    final unchanged =
        !ruleChanged &&
        title == existing.title &&
        _tone == existing.tone &&
        _range == existing.range;
    if (unchanged) return true;

    final scope = await askEditScope(context, ruleChanged: ruleChanged);
    if (scope == null) return false;
    await (scope == EditScope.thisEvent ? thisEventOnly() : fromHere());
    return true;
  }
```

Replace:

```dart
          if (_saveError != null) ...[
```

With:

```dart
          const SizedBox(height: AppSpacing.xl),
          RepeatPicker(
            rule: _rule,
            firstDay: widget.day,
            onChanged: (rule) => setState(() => _rule = rule),
          ),
          if (_saveError != null) ...[
```

- [ ] **Step 4: Run the sheet tests, the analyzer and the whole suite**

```bash
# expect: PASS — 17 new tests; analyzer clean; the existing sheet tests and the whole suite stay green
flutter test test/features/clock/event_sheet_repeat_test.dart && flutter analyze && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat: repeat option in the event sheet, with this-or-future edits

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---
### Task 13: The detail sheet shows how an event repeats, and deleting asks how far

Two changes for an occurrence of a series:

- The **detail sheet** shows how it repeats ("Every Mon, Wed and Fri, until 31 Dec 2026") on a line with the repeat icon, under the duration. A one-off event shows nothing there.
- **Delete** asks "This event" or "This and all future events" instead of the plain confirmation. "This event" is `EventRepository.deleteEvent`, which skips the occurrence so the series cannot bring it back (Task 4); "this and all future" is `SeriesRepository.deleteFromHere` (Task 6). A one-off event keeps the existing "Delete this event?" confirmation.

`confirmAndDeleteEvent` is the one place that deletes: the detail sheet and the dial's VoiceOver Delete action both call it, so both get the question.

**Files:**
- Modify: `lib/features/clock/providers.dart`, `lib/features/clock/widgets/event_detail_sheet.dart`
- Replace: `lib/features/clock/widgets/delete_event.dart`
- Test: `test/features/clock/series_delete_test.dart`

**Interfaces:**
- Consumes: `askDeleteScope`, `EditScope` (Task 11); `describeRecurrence` (Task 1); `SeriesRepository.ruleFor`, `deleteFromHere`.
- Produces: `seriesRuleProvider` (`FutureProvider.family<RecurrenceRule?, int>`, keyed by series id) in `lib/features/clock/providers.dart`; `confirmAndDeleteEvent` unchanged in signature (`Future<bool> Function(BuildContext, WidgetRef, CalendarEvent)`), now series-aware.

- [ ] **Step 1: Write the failing test**

**Create `test/features/clock/series_delete_test.dart`**

```dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:energy_clock/features/clock/widgets/delete_event.dart';
import 'package:energy_clock/features/clock/widgets/event_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;

  // Wednesday 7 October 2026.
  final day = DateTime(2026, 10, 7);

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  /// Wednesday's occurrence of a series that also has one on the Tuesday
  /// before and one on the Thursday after.
  ({int series, int before, int on, int after}) addSeries({
    RecurrenceRule? rule,
  }) {
    final series = harness.series.addSeries(
      rule ?? RecurrenceRule.custom({1, 3, 5}, until: DateTime(2026, 12, 31)),
    );
    int add(DateTime date) => harness.repository.addOccurrence(
      seriesId: series,
      day: date,
      title: 'Standup',
      range: const MinuteRange(540, 570),
    );
    return (
      series: series,
      before: add(DateTime(2026, 10, 6)),
      on: add(day),
      after: add(DateTime(2026, 10, 8)),
    );
  }

  Future<void> openDetail(WidgetTester tester, CalendarEvent event) async {
    await tester.pumpWidget(
      harness.app(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () =>
                EventDetailSheet.show(context, event: event, readOnly: false),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('the detail sheet', () {
    testWidgets('says how an occurrence repeats', (tester) async {
      final ids = addSeries();
      await openDetail(tester, harness.repository.eventById(ids.on)!);

      expect(
        find.text('Every Mon, Wed and Fri, until 31 Dec 2026'),
        findsOneWidget,
      );
    });

    testWidgets('says nothing about repeating for a one-off event', (
      tester,
    ) async {
      final id = await harness.repository.createEvent(
        day: day,
        title: 'Deep work',
        tone: Tone.focus,
        range: const MinuteRange(540, 720),
      );
      await openDetail(tester, harness.repository.eventById(id)!);

      expect(find.textContaining('Every'), findsNothing);
      expect(find.textContaining('Weekdays'), findsNothing);
    });

    testWidgets('deleting asks how far, and "this event" closes the sheet', (
      tester,
    ) async {
      final ids = addSeries();
      await openDetail(tester, harness.repository.eventById(ids.on)!);

      await tester.tap(find.text(Strings.delete));
      await tester.pumpAndSettle();
      expect(find.text(Strings.deleteScopeTitle), findsOneWidget);
      expect(find.text(Strings.deleteConfirmTitle), findsNothing);
      await tester.tap(find.text(Strings.scopeThisEvent));
      await tester.pumpAndSettle();

      expect(find.byType(EventDetailSheet), findsNothing);
      expect(harness.repository.eventById(ids.on), isNull);
      expect(harness.repository.eventById(ids.before), isNotNull);
      expect(harness.repository.eventById(ids.after), isNotNull);
      expect(harness.series.deletedFrom, isEmpty);
    });
  });

  group('confirmAndDeleteEvent', () {
    /// Mounts a button that runs the delete on event [eventId] and taps it.
    /// Returns a getter for what the delete resolved to.
    Future<bool? Function()> run(WidgetTester tester, int eventId) async {
      bool? result;
      await tester.pumpWidget(
        harness.app(
          Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () async {
                result = await confirmAndDeleteEvent(
                  context,
                  ref,
                  harness.repository.eventById(eventId)!,
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      return () => result;
    }

    testWidgets('"this and all future events" removes this day and later', (
      tester,
    ) async {
      final ids = addSeries();
      final result = await run(tester, ids.on);

      await tester.tap(find.text(Strings.scopeThisAndFuture));
      await tester.pumpAndSettle();

      expect(result(), isTrue);
      expect(harness.series.deletedFrom, [ids.on]);
      expect(harness.repository.eventById(ids.on), isNull);
      expect(harness.repository.eventById(ids.after), isNull);
      expect(harness.repository.eventById(ids.before), isNotNull);
    });

    testWidgets('cancelling the question deletes nothing and returns false', (
      tester,
    ) async {
      final ids = addSeries();
      final result = await run(tester, ids.on);

      await tester.tap(find.text(Strings.cancel));
      await tester.pumpAndSettle();

      expect(result(), isFalse);
      expect(harness.repository.eventById(ids.on), isNotNull);
      expect(harness.series.deletedFrom, isEmpty);
    });

    testWidgets('a one-off event still gets the plain confirmation', (
      tester,
    ) async {
      final id = await harness.repository.createEvent(
        day: day,
        title: 'Deep work',
        tone: Tone.focus,
        range: const MinuteRange(540, 720),
      );
      await run(tester, id);

      expect(find.text(Strings.deleteConfirmTitle), findsOneWidget);
      expect(find.text(Strings.deleteScopeTitle), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run the test to see it fail**

```bash
# expect: FAIL — the detail sheet has no repeat line and deleting does not ask yet
flutter test test/features/clock/series_delete_test.dart
```

- [ ] **Step 3: Write the code**

**Edit `lib/features/clock/providers.dart`**

Replace:

```dart
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
```

With:

```dart
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
```

Replace:

```dart
      return ref.watch(eventRepositoryProvider).watchTonesByDay(weekStart, end);
    });
```

With:

```dart
      return ref.watch(eventRepositoryProvider).watchTonesByDay(weekStart, end);
    });

/// How a series repeats, keyed by series id, for the detail sheet. Null when
/// the series no longer exists.
final seriesRuleProvider = FutureProvider.family<RecurrenceRule?, int>((
  ref,
  seriesId,
) {
  return ref.watch(seriesRepositoryProvider).ruleFor(seriesId);
});
```

**Edit `lib/features/clock/widgets/event_detail_sheet.dart`**

Replace:

```dart
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
```

With:

```dart
import 'package:energy_clock/core/recurrence/recurrence_text.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
```

Replace:

```dart
          Text(
            formatDurationMinutes(event.range.durationMinutes),
            style: theme.textTheme.bodySmall,
          ),
```

With:

```dart
          Text(
            formatDurationMinutes(event.range.durationMinutes),
            style: theme.textTheme.bodySmall,
          ),
          if (event.seriesId != null) _RepeatLine(seriesId: event.seriesId!),
```

Replace:

```dart
              onPressed: () => _delete(context, ref),
            ),
          ],
        ],
      ),
    );
  }
}
```

With:

```dart
              onPressed: () => _delete(context, ref),
            ),
          ],
        ],
      ),
    );
  }
}

/// How the event's series repeats, on one line with the repeat icon. Draws
/// nothing until the rule has loaded, or if the series is gone.
class _RepeatLine extends ConsumerWidget {
  const _RepeatLine({required this.seriesId});

  final int seriesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rule = ref.watch(seriesRuleProvider(seriesId)).valueOrNull;
    if (rule == null || !rule.repeats) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Icon(CupertinoIcons.repeat, size: 16, color: context.appColors.muted),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              describeRecurrence(rule),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
```

**Replace `lib/features/clock/widgets/delete_event.dart`**

```dart
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/edit_scope.dart';
import 'package:energy_clock/shared/widgets/adaptive_dialog.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asks, then deletes [event]. Returns true when it was deleted. Used by the
/// detail sheet and by the dial's VoiceOver Delete action.
///
/// An occurrence of a repeating series asks how far the delete reaches: "this
/// event" skips just that day, so the series cannot bring it back; "this and
/// all future events" ends the series here. Any other event asks for a plain
/// confirmation.
Future<bool> confirmAndDeleteEvent(
  BuildContext context,
  WidgetRef ref,
  CalendarEvent event,
) async {
  if (event.seriesId != null) {
    final scope = await askDeleteScope(context);
    if (scope == null) return false;
    switch (scope) {
      case EditScope.thisEvent:
        await ref.read(eventRepositoryProvider).deleteEvent(event.id);
      case EditScope.thisAndFuture:
        await ref.read(seriesRepositoryProvider).deleteFromHere(event.id);
    }
    return true;
  }

  final confirmed = await confirmDestructive(
    context,
    title: Strings.deleteConfirmTitle,
    body: Strings.deleteConfirmBody,
    confirmLabel: Strings.delete,
    cancelLabel: Strings.cancel,
  );
  if (!confirmed) return false;
  await ref.read(eventRepositoryProvider).deleteEvent(event.id);
  return true;
}
```

- [ ] **Step 4: Run the tests, the analyzer and the whole suite**

```bash
# expect: PASS — 6 new tests; analyzer clean; the existing detail and delete tests and the whole suite stay green
flutter test test/features/clock/series_delete_test.dart && flutter analyze && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat: show how an event repeats; ask how far a delete reaches

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---
## Stage 3 — Reuse tools in the Clock

### Task 14: The day's overflow menu — save as template, copy yesterday

Spec §7: "Day templates. Saved from a day's overflow menu as a named template" and §5.4: an empty editable day offers Copy yesterday and Apply template. This task adds the **overflow menu** (a round ⋯ button in the Clock header, left of +) and the first two actions in it. Apply template needs the picker sheet, which is Task 15; the menu already has its slot.

What the menu offers depends on the day, and the button is left out when it would be empty:

| Item | Shown when |
|---|---|
| **Save as template** | the day has at least one event (past days too: a good day is worth saving) |
| **Copy yesterday** | the day is empty and editable, and yesterday has events (a button that could copy nothing is not offered; the spec does not say, this is a decision) |
| **Apply template** | the day is empty and editable (Task 15) |

Saving asks for a name in a small dialog (up to 60 characters, a name is required), then confirms with a snackbar. Copy yesterday needs no question: the events appear on the dial. `ClockHeader` stays a plain widget (it takes an optional callback per item and shows an item only when it has one); `ClockScreen` decides which apply.

The header row has to hold one more button, so two things change in it. A **past day no longer shows the + button** (it was disabled and did nothing; the Read-only chip already says why), and the **Read-only chip and the Today pill stop growing at 130% text**. Without the second change a past day already overflowed a 320 pt window at large text sizes, and the new button would have made it worse. `ClockHeader` is replaced as a whole file; two existing tests (the header test and the Clock screen test) and the four Clock screen goldens are updated for it.

**Files:**
- Create: `lib/features/clock/widgets/template_name_dialog.dart`, `lib/features/clock/widgets/reuse_actions.dart`
- Replace: `lib/features/clock/widgets/clock_header.dart`
- Modify: `lib/core/strings.dart`, `lib/features/clock/providers.dart`, `lib/features/clock/clock_screen.dart`, `test/features/clock/clock_header_test.dart`, `test/features/clock/clock_screen_test.dart`, and the four Clock screen goldens in `test/features/clock/goldens/` (the day's header now shows the ⋯ button)
- Test: `test/features/clock/template_name_dialog_test.dart`, `test/features/clock/reuse_actions_test.dart`, `test/features/clock/clock_header_menu_test.dart`, `test/features/clock/clock_screen_reuse_test.dart`

**Interfaces:**
- Consumes: `ReuseRepository` and `reuseRepositoryProvider` (Tasks 7–8), `maxTemplateNameLength`, `DayNotEmptyException`, `EmptyDayException`; `previousDay` from `day_time.dart`.
- Produces: `askTemplateName(BuildContext) → Future<String?>`; `saveDayAsTemplate(BuildContext, WidgetRef, DateTime day) → Future<void>`; `copyPreviousDay(BuildContext, WidgetRef, DateTime day) → Future<void>`; `previousDayEventsProvider` (`StreamProvider<List<CalendarEvent>>`: the day before the selected one); `ClockHeader({required onAdd, onSaveTemplate, onCopyYesterday, onApplyTemplate, showDate})` with the three new optional `VoidCallback?`; strings `moreActions`, `saveAsTemplate`, `copyYesterday`, `applyTemplate`, `templateNameTitle`, `templateNameLabel`, `templateNameHint`, `templateNameRequired`, `templateSaved(String)`, `templateSaveFailed`, `copyFailed`, `dayNotEmpty`.

- [ ] **Step 1: Write the failing tests**

**Create `test/features/clock/template_name_dialog_test.dart`**

```dart
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/repositories/reuse_repository.dart';
import 'package:energy_clock/features/clock/widgets/template_name_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Opens the dialog; [results] collects what it resolves to (null for a
  /// cancel).
  Future<void> open(WidgetTester tester, List<String?> results) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  results.add(await askTemplateName(context)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('returns the name, trimmed', (tester) async {
    final results = <String?>[];
    await open(tester, results);

    await tester.enterText(find.byType(TextField), '  Office day ');
    await tester.tap(find.text(Strings.save));
    await tester.pumpAndSettle();

    expect(results, ['Office day']);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('asks for a name and stays open when it is empty', (
    tester,
  ) async {
    final results = <String?>[];
    await open(tester, results);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text(Strings.save));
    await tester.pumpAndSettle();

    expect(find.text(Strings.templateNameRequired), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(results, isEmpty);
  });

  testWidgets('cancel returns null', (tester) async {
    final results = <String?>[];
    await open(tester, results);

    await tester.tap(find.text(Strings.cancel));
    await tester.pumpAndSettle();

    expect(results, [null]);
  });

  testWidgets('the name cannot be longer than a template allows', (
    tester,
  ) async {
    final results = <String?>[];
    await open(tester, results);

    await tester.enterText(find.byType(TextField), 'x' * 100);
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, hasLength(maxTemplateNameLength));
  });

  testWidgets('shows the title, label and hint', (tester) async {
    await open(tester, []);

    expect(find.text(Strings.templateNameTitle), findsOneWidget);
    expect(find.text(Strings.templateNameLabel), findsOneWidget);
  });
}
```

**Create `test/features/clock/reuse_actions_test.dart`**

```dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/widgets/reuse_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;

  final yesterday = DateTime(2026, 10, 6);
  final today = DateTime(2026, 10, 7);

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> addDay(DateTime day) async {
    await harness.repository.createEvent(
      day: day,
      title: 'Deep work',
      tone: Tone.focus,
      range: const MinuteRange(540, 660),
    );
    await harness.repository.createEvent(
      day: day,
      title: 'Lunch walk',
      tone: Tone.life,
      range: const MinuteRange(750, 795),
    );
  }

  /// Mounts one button that runs [action] on [today] and taps it.
  Future<void> run(
    WidgetTester tester,
    Future<void> Function(BuildContext, WidgetRef, DateTime) action,
  ) async {
    await tester.pumpWidget(
      harness.app(
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => action(context, ref, today),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  group('saveDayAsTemplate', () {
    testWidgets('saves the day under the name and says so', (tester) async {
      await addDay(today);
      await run(tester, saveDayAsTemplate);

      await tester.enterText(find.byType(TextField), 'Office day');
      await tester.tap(find.text(Strings.save));
      await tester.pumpAndSettle();

      final template = harness.reuse.templates.single;
      expect(template.name, 'Office day');
      expect(template.eventCount, 2);
      expect(find.text(Strings.templateSaved('Office day')), findsOneWidget);
    });

    testWidgets('cancelling the name saves nothing', (tester) async {
      await addDay(today);
      await run(tester, saveDayAsTemplate);

      await tester.tap(find.text(Strings.cancel));
      await tester.pumpAndSettle();

      expect(harness.reuse.templates, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a day with nothing on it says it could not save', (
      tester,
    ) async {
      await run(tester, saveDayAsTemplate);

      await tester.enterText(find.byType(TextField), 'Empty');
      await tester.tap(find.text(Strings.save));
      await tester.pumpAndSettle();

      expect(harness.reuse.templates, isEmpty);
      expect(find.text(Strings.templateSaveFailed), findsOneWidget);
    });
  });

  group('copyPreviousDay', () {
    testWidgets('copies yesterday onto the day', (tester) async {
      await addDay(yesterday);
      await run(tester, copyPreviousDay);

      final copied = await harness.repository.eventsForDay(today);
      expect(copied.map((event) => event.title), ['Deep work', 'Lunch walk']);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a day that already has events is left alone and says so', (
      tester,
    ) async {
      await addDay(yesterday);
      await harness.repository.createEvent(
        day: today,
        title: 'Already here',
        tone: Tone.inbox,
        range: const MinuteRange(900, 960),
      );
      await run(tester, copyPreviousDay);

      expect(await harness.repository.eventsForDay(today), hasLength(1));
      expect(find.text(Strings.dayNotEmpty), findsOneWidget);
    });
  });
}
```

**Create `test/features/clock/clock_header_menu_test.dart`**

```dart
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/clock_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

Finder moreButton() => find.byTooltip(Strings.moreActions);

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness(); // Wednesday 7 October 2026
  });

  tearDown(() {
    harness.dispose();
  });

  testWidgets('there is no menu button when no action applies', (tester) async {
    await tester.pumpWidget(harness.app(ClockHeader(onAdd: () {})));
    expect(moreButton(), findsNothing);
  });

  testWidgets('lists exactly the actions that were given', (tester) async {
    await tester.pumpWidget(
      harness.app(ClockHeader(onAdd: () {}, onSaveTemplate: () {})),
    );

    await tester.tap(moreButton());
    await tester.pumpAndSettle();

    expect(find.text(Strings.saveAsTemplate), findsOneWidget);
    expect(find.text(Strings.copyYesterday), findsNothing);
    expect(find.text(Strings.applyTemplate), findsNothing);
  });

  testWidgets('lists all three when all are given', (tester) async {
    await tester.pumpWidget(
      harness.app(
        ClockHeader(
          onAdd: () {},
          onSaveTemplate: () {},
          onCopyYesterday: () {},
          onApplyTemplate: () {},
        ),
      ),
    );

    await tester.tap(moreButton());
    await tester.pumpAndSettle();

    expect(find.text(Strings.saveAsTemplate), findsOneWidget);
    expect(find.text(Strings.copyYesterday), findsOneWidget);
    expect(find.text(Strings.applyTemplate), findsOneWidget);
  });

  testWidgets('choosing an action calls it and closes the menu', (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(
      harness.app(
        ClockHeader(
          onAdd: () {},
          onSaveTemplate: () => calls.add('save'),
          onCopyYesterday: () => calls.add('copy'),
          onApplyTemplate: () => calls.add('apply'),
        ),
      ),
    );

    await tester.tap(moreButton());
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.copyYesterday));
    await tester.pumpAndSettle();

    expect(calls, ['copy']);
    expect(find.text(Strings.copyYesterday), findsNothing);
  });

  testWidgets('a past day has the menu but no + button', (tester) async {
    harness.container
        .read(selectedDateProvider.notifier)
        .select(DateTime(2026, 10, 5));
    await tester.pumpWidget(
      harness.app(ClockHeader(onAdd: () {}, onSaveTemplate: () {})),
    );

    expect(moreButton(), findsOneWidget);
    expect(find.byTooltip(Strings.addEvent), findsNothing);
    expect(find.text(Strings.readOnlyChip), findsOneWidget);
  });

  testWidgets('the menu button is at least 44 x 44', (tester) async {
    await tester.pumpWidget(
      harness.app(ClockHeader(onAdd: () {}, onSaveTemplate: () {})),
    );

    final size = tester.getSize(moreButton());
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  for (final textScale in [1.0, 2.0, 3.12]) {
    testWidgets(
      'a past day with every control fits 320 pt at text ${(textScale * 100).toInt()}%',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        harness.container
            .read(selectedDateProvider.notifier)
            .select(DateTime(2026, 10, 5));

        await tester.pumpWidget(
          harness.app(
            ClockHeader(onAdd: () {}, onSaveTemplate: () {}),
            textScale: textScale,
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );
  }
}
```

**Create `test/features/clock/clock_screen_reuse_test.dart`**

```dart
import 'package:energy_clock/app/navigation/tab_bar_inset.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/clock_screen.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';
import '../../support/dial_pump.dart';

Finder moreButton() => find.byTooltip(Strings.moreActions);

/// A menu item by its label. On an empty day the buttons beneath the dial use
/// the same words, so a plain text finder can match twice.
Finder menuItem(String label) => find.descendant(
  of: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
  matching: find.text(label),
);

void main() {
  late ClockHarness harness;

  final yesterday = DateTime(2026, 10, 6);
  final today = DateTime(2026, 10, 7);

  setUp(() {
    harness = ClockHarness(); // Wednesday 7 October 2026, 10:30
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> addDay(DateTime day) async {
    await harness.repository.createEvent(
      day: day,
      title: 'Deep work',
      tone: Tone.focus,
      range: const MinuteRange(540, 660),
    );
  }

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Reduced motion stops the empty day's pulsing hint, so the menu can settle.
    await tester.pumpWidget(
      harness.app(
        const TabBarInset(height: 84, child: ClockScreen()),
        reduceMotion: true,
      ),
    );
    await pumpDial(tester);
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(moreButton());
    await tester.pumpAndSettle();
  }

  testWidgets('a day with events offers Save as template only', (tester) async {
    await addDay(today);
    await addDay(yesterday);
    await mount(tester);

    await openMenu(tester);

    expect(menuItem(Strings.saveAsTemplate), findsOneWidget);
    expect(menuItem(Strings.copyYesterday), findsNothing);
    expect(menuItem(Strings.applyTemplate), findsNothing);
  });

  testWidgets('Save as template asks for a name and saves the day', (
    tester,
  ) async {
    await addDay(today);
    await mount(tester);

    await openMenu(tester);
    await tester.tap(menuItem(Strings.saveAsTemplate));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Office day');
    await tester.tap(find.text(Strings.save));
    await tester.pumpAndSettle();

    expect(harness.reuse.templates.single.name, 'Office day');
    expect(find.text(Strings.templateSaved('Office day')), findsOneWidget);
  });

  testWidgets('an empty day after a busy one offers Copy yesterday', (
    tester,
  ) async {
    await addDay(yesterday);
    await mount(tester);

    await openMenu(tester);
    expect(menuItem(Strings.copyYesterday), findsOneWidget);
    expect(menuItem(Strings.saveAsTemplate), findsNothing);

    await tester.tap(menuItem(Strings.copyYesterday));
    await pumpDial(tester);

    expect(await harness.repository.eventsForDay(today), hasLength(1));
    expect(moreButton(), findsOneWidget);
  });

  testWidgets('an empty day after an empty one has nothing to copy', (
    tester,
  ) async {
    await mount(tester);
    expect(menuItem(Strings.copyYesterday), findsNothing);
  });

  testWidgets('a past day with events can still be saved as a template', (
    tester,
  ) async {
    await addDay(yesterday);
    harness.container.read(selectedDateProvider.notifier).select(yesterday);
    await mount(tester);

    await openMenu(tester);

    expect(menuItem(Strings.saveAsTemplate), findsOneWidget);
    expect(menuItem(Strings.copyYesterday), findsNothing);
  });

  testWidgets('a past day with no events has no menu', (tester) async {
    harness.container.read(selectedDateProvider.notifier).select(yesterday);
    await mount(tester);

    expect(moreButton(), findsNothing);
  });
}
```

- [ ] **Step 2: Run the tests to see them fail**

```bash
# expect: FAIL — the dialog, the actions, the header menu and the strings do not exist yet
flutter test test/features/clock/template_name_dialog_test.dart test/features/clock/reuse_actions_test.dart test/features/clock/clock_header_menu_test.dart test/features/clock/clock_screen_reuse_test.dart
```

- [ ] **Step 3: Write the code**

**Edit `lib/core/strings.dart`**

Replace:

```dart
  static const String repeatChangeBody =
      'This applies to this event and all future ones.';
}
```

With:

```dart
  static const String repeatChangeBody =
      'This applies to this event and all future ones.';

  // Reusing a day: templates and copy-yesterday.
  static const String moreActions = 'More';
  static const String saveAsTemplate = 'Save as template';
  static const String copyYesterday = 'Copy yesterday';
  static const String applyTemplate = 'Apply template';
  static const String templateNameTitle = 'Save as template';
  static const String templateNameLabel = 'Template name';
  static const String templateNameHint = 'Workday';
  static const String templateNameRequired = 'Enter a name';
  static String templateSaved(String name) => 'Saved "$name" as a template.';
  static const String templateSaveFailed = "Couldn't save the template.";
  static const String copyFailed = "Couldn't copy that day.";
  static const String dayNotEmpty = 'That day already has events.';
}
```

**Create `lib/features/clock/widgets/template_name_dialog.dart`**

```dart
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/repositories/reuse_repository.dart';
import 'package:flutter/material.dart';

/// Asks for a template's name. Returns it trimmed, or null if the person
/// cancels. A name is required, and at most [maxTemplateNameLength] long.
Future<String?> askTemplateName(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _TemplateNameDialog(),
  );
}

class _TemplateNameDialog extends StatefulWidget {
  const _TemplateNameDialog();

  @override
  State<_TemplateNameDialog> createState() => _TemplateNameDialogState();
}

class _TemplateNameDialogState extends State<_TemplateNameDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = Strings.templateNameRequired);
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(Strings.templateNameTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: maxTemplateNameLength,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: Strings.templateNameLabel,
          hintText: Strings.templateNameHint,
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Strings.cancel),
        ),
        TextButton(onPressed: _submit, child: const Text(Strings.save)),
      ],
    );
  }
}
```

**Create `lib/features/clock/widgets/reuse_actions.dart`**

```dart
import 'dart:async';

import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/reuse_repository.dart';
import 'package:energy_clock/features/clock/widgets/template_name_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asks for a name, then saves [day]'s events as a template and says so.
Future<void> saveDayAsTemplate(
  BuildContext context,
  WidgetRef ref,
  DateTime day,
) async {
  final name = await askTemplateName(context);
  if (name == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(reuseRepositoryProvider).saveTemplate(name: name, day: day);
    messenger.showSnackBar(
      SnackBar(content: Text(Strings.templateSaved(name))),
    );
  } on Object {
    messenger.showSnackBar(
      const SnackBar(content: Text(Strings.templateSaveFailed)),
    );
  }
}

/// Copies the day before [day] onto it. The events appear on the dial, so
/// success needs no message; a failure says what went wrong.
Future<void> copyPreviousDay(
  BuildContext context,
  WidgetRef ref,
  DateTime day,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref
        .read(reuseRepositoryProvider)
        .copyDay(from: previousDay(day), to: day);
    unawaited(HapticFeedback.mediumImpact());
  } on DayNotEmptyException {
    messenger.showSnackBar(const SnackBar(content: Text(Strings.dayNotEmpty)));
  } on Object {
    messenger.showSnackBar(const SnackBar(content: Text(Strings.copyFailed)));
  }
}
```

**Edit `lib/features/clock/providers.dart`**

Replace:

```dart
final dayEventsProvider = StreamProvider<List<CalendarEvent>>((ref) {
  return ref
      .watch(eventRepositoryProvider)
      .watchDay(ref.watch(selectedDateProvider));
});
```

With:

```dart
final dayEventsProvider = StreamProvider<List<CalendarEvent>>((ref) {
  return ref
      .watch(eventRepositoryProvider)
      .watchDay(ref.watch(selectedDateProvider));
});

/// The events of the day before the selected one, to know whether "Copy
/// yesterday" has anything to copy.
final previousDayEventsProvider = StreamProvider<List<CalendarEvent>>((ref) {
  return ref
      .watch(eventRepositoryProvider)
      .watchDay(previousDay(ref.watch(selectedDateProvider)));
});
```

**Replace `lib/features/clock/widgets/clock_header.dart`**

```dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The Clock screen's header: the day name and date, a Today pill when you are
/// on another day, a "Read-only" chip on past days, an overflow menu, and the
/// round + button. A past day cannot be added to, so it has no + button; that
/// room goes to the chip and the menu.
class ClockHeader extends ConsumerWidget {
  const ClockHeader({
    required this.onAdd,
    this.onSaveTemplate,
    this.onCopyYesterday,
    this.onApplyTemplate,
    this.showDate = true,
    super.key,
  });

  /// Height at normal text size, with the date line.
  static const double height = 48;

  /// The height to budget at [textScale], with or without the date line.
  static double heightFor(double textScale, {required bool showDate}) =>
      (showDate ? 44 : 30) * textScale + 4;

  /// The Read-only chip and the Today pill are small labels in a row that also
  /// has to hold the title and the round buttons, so their text stops growing
  /// at this scale. Without it a past day overflowed a 320 pt window at large
  /// text sizes.
  static const double _maxPillTextScale = 1.3;

  final VoidCallback onAdd;

  /// The overflow menu's actions. An action is listed only when it has a
  /// callback, and the ⋯ button is left out when none has.
  final VoidCallback? onSaveTemplate;
  final VoidCallback? onCopyYesterday;
  final VoidCallback? onApplyTemplate;

  /// The date line under the day name; dropped on a very short screen.
  final bool showDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDateProvider);
    final now = ref.watch(clockProvider);
    final isToday = selected == startOfDay(now);
    final readOnly = isPastDay(selected, now: now);
    final colors = context.appColors;
    final theme = Theme.of(context);
    final hasMenu =
        onSaveTemplate != null ||
        onCopyYesterday != null ||
        onApplyTemplate != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        0,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: height - 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The day name is the one line that must stay on one line,
                  // so it shrinks rather than wraps at very large text sizes.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      DateFormat('EEEE').format(selected),
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  if (showDate)
                    Text(
                      DateFormat('d MMMM y').format(selected),
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (readOnly) ...[
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: _maxPillTextScale,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.outline),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 6,
                    ),
                    child: Text(
                      Strings.readOnlyChip,
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            if (!isToday) ...[
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: _maxPillTextScale,
                child: TextButton(
                  onPressed: ref.read(selectedDateProvider.notifier).today,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.ink,
                    backgroundColor: colors.ink.withValues(alpha: 0.08),
                    shape: const StadiumBorder(),
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                  ),
                  child: const Text(Strings.today),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            if (hasMenu) ...[
              _MoreMenu(
                onSaveTemplate: onSaveTemplate,
                onCopyYesterday: onCopyYesterday,
                onApplyTemplate: onApplyTemplate,
              ),
              if (!readOnly) const SizedBox(width: AppSpacing.sm),
            ],
            if (!readOnly)
              IconButton.filled(
                icon: const Icon(Icons.add),
                tooltip: Strings.addEvent,
                onPressed: onAdd,
                style: IconButton.styleFrom(
                  backgroundColor: colors.ink,
                  foregroundColor: colors.onInk,
                  minimumSize: const Size(44, 44),
                  shape: const CircleBorder(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _MoreAction { saveTemplate, copyYesterday, applyTemplate }

/// The round ⋯ button and its menu. A faint ink circle, like the stepper
/// buttons, so the filled + stays the one primary control.
class _MoreMenu extends StatelessWidget {
  const _MoreMenu({
    required this.onSaveTemplate,
    required this.onCopyYesterday,
    required this.onApplyTemplate,
  });

  final VoidCallback? onSaveTemplate;
  final VoidCallback? onCopyYesterday;
  final VoidCallback? onApplyTemplate;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return PopupMenuButton<_MoreAction>(
      tooltip: Strings.moreActions,
      onSelected: (action) => switch (action) {
        _MoreAction.saveTemplate => onSaveTemplate?.call(),
        _MoreAction.copyYesterday => onCopyYesterday?.call(),
        _MoreAction.applyTemplate => onApplyTemplate?.call(),
      },
      itemBuilder: (context) => [
        if (onSaveTemplate != null)
          const PopupMenuItem(
            value: _MoreAction.saveTemplate,
            child: Text(Strings.saveAsTemplate),
          ),
        if (onCopyYesterday != null)
          const PopupMenuItem(
            value: _MoreAction.copyYesterday,
            child: Text(Strings.copyYesterday),
          ),
        if (onApplyTemplate != null)
          const PopupMenuItem(
            value: _MoreAction.applyTemplate,
            child: Text(Strings.applyTemplate),
          ),
      ],
      child: SizedBox.square(
        dimension: 44,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.ink.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.more_horiz, color: colors.ink),
        ),
      ),
    );
  }
}
```

**Edit `test/features/clock/clock_header_test.dart`**

A past day no longer has a + button at all (it was disabled and did nothing).

Replace:

```dart
  testWidgets('a past day shows the Read-only chip and disables +', (
    tester,
  ) async {
    harness = ClockHarness(selected: DateTime(2026, 10, 6));
    var adds = 0;
    await tester.pumpWidget(harness.app(ClockHeader(onAdd: () => adds++)));

    expect(find.text(Strings.readOnlyChip), findsOneWidget);
    expect(tester.widget<IconButton>(addButton()).onPressed, isNull);
    await tester.tap(addButton(), warnIfMissed: false);
    expect(adds, 0);
  });
```

With:

```dart
  testWidgets('a past day shows the Read-only chip and has no + button', (
    tester,
  ) async {
    harness = ClockHarness(selected: DateTime(2026, 10, 6));
    await tester.pumpWidget(harness.app(ClockHeader(onAdd: () {})));

    expect(find.text(Strings.readOnlyChip), findsOneWidget);
    expect(addButton(), findsNothing);
  });
```

**Edit `test/features/clock/clock_screen_test.dart`**

Replace:

```dart
  testWidgets('a past day is read-only: chip shown and + disabled', (
    tester,
  ) async {
    setWindow(tester, 402, 874);
    await tester.pumpWidget(harness.app(screen()));
    harness.container
        .read(selectedDateProvider.notifier)
        .select(DateTime(2026, 10, 6));
    await pumpDial(tester);

    expect(find.text(Strings.readOnlyChip), findsWidgets);
    final add = tester.widget<IconButton>(
      find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == Strings.addEvent,
      ),
    );
    expect(add.onPressed, isNull);
  });
```

With:

```dart
  testWidgets('a past day is read-only: chip shown and no + button', (
    tester,
  ) async {
    setWindow(tester, 402, 874);
    await tester.pumpWidget(harness.app(screen()));
    harness.container
        .read(selectedDateProvider.notifier)
        .select(DateTime(2026, 10, 6));
    await pumpDial(tester);

    expect(find.text(Strings.readOnlyChip), findsWidgets);
    expect(find.byTooltip(Strings.addEvent), findsNothing);
  });
```

**Edit `lib/features/clock/clock_screen.dart`**

Replace:

```dart
import 'package:energy_clock/features/clock/widgets/now_card.dart';
import 'package:energy_clock/features/clock/widgets/start_session.dart';
```

With:

```dart
import 'package:energy_clock/features/clock/widgets/now_card.dart';
import 'package:energy_clock/features/clock/widgets/reuse_actions.dart';
import 'package:energy_clock/features/clock/widgets/start_session.dart';
```

Replace:

```dart
    final hasEvents = events.valueOrNull?.isNotEmpty ?? false;
```

With:

```dart
    final hasEvents = events.valueOrNull?.isNotEmpty ?? false;
    // An empty day that can still be edited: the reuse tools fill it.
    final canFill = !readOnly && events.hasValue && !hasEvents;
    final yesterdayHasEvents =
        ref.watch(previousDayEventsProvider).valueOrNull?.isNotEmpty ?? false;
```

Replace:

```dart
    Widget dialArea({double? maxRadius}) => events.when(
```

With:

```dart
    Widget header({bool showDate = true}) => ClockHeader(
      showDate: showDate,
      onAdd: () => openCreate(const MinuteRange(540, 600)),
      onSaveTemplate: hasEvents
          ? () => unawaited(saveDayAsTemplate(context, ref, selected))
          : null,
      onCopyYesterday: canFill && yesterdayHasEvents
          ? () => unawaited(copyPreviousDay(context, ref, selected))
          : null,
    );

    Widget dialArea({double? maxRadius}) => events.when(
```

Replace:

```dart
                  ClockHeader(
                    onAdd: () => openCreate(const MinuteRange(540, 600)),
                  ),
                  WeekStrip(showDots: !largeText),
```

With:

```dart
                  header(),
                  WeekStrip(showDots: !largeText),
```

Replace:

```dart
                ClockHeader(
                  showDate: plan.showHeaderDate,
                  onAdd: () => openCreate(const MinuteRange(540, 600)),
                ),
```

With:

```dart
                header(showDate: plan.showHeaderDate),
```

- [ ] **Step 4: Run the new tests**

```bash
# expect: PASS — 25 new tests, and the header tests
flutter test test/features/clock/template_name_dialog_test.dart test/features/clock/reuse_actions_test.dart test/features/clock/clock_header_menu_test.dart test/features/clock/clock_screen_reuse_test.dart test/features/clock/clock_header_test.dart test/features/clock/clock_screen_test.dart
```

- [ ] **Step 5: Regenerate the Clock screen goldens and look at them**

The four Clock screen goldens (iPhone light and dark, iPad portrait and landscape) show a day with events, so their header now has the ⋯ button left of +. That is the intended change; nothing else on them should move. Regenerate them, then **open the four images** and check the header: day name and date on the left, ⋯ and + on the right, the dial and the rest unchanged.

```bash
# expect: RUN — rewrites 4 PNGs; then open them in test/features/clock/goldens/clock_*.png
flutter test --update-goldens test/features/clock/clock_screen_golden_test.dart
rm -rf test/features/clock/failures
git status --short test/features/clock/goldens
```

- [ ] **Step 6: Run the analyzer and the whole suite**

```bash
# expect: PASS — analyzer clean; the whole suite stays green
flutter analyze && flutter test
```

- [ ] **Step 7: Commit**

```bash
git add lib test
git commit -m "feat: day overflow menu with save as template and copy yesterday

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---
### Task 15: The template picker — apply a template to an empty day

The last reuse action: **Apply template**. It opens a bottom sheet listing the saved templates, newest first. Each row shows the name, "5 events · 6h 30m" and a dot for every tone it uses; tapping a row puts that plan on the day and closes the sheet. A trash button on the row deletes the template (after the usual confirmation). With no templates the sheet explains how to make one.

Spec §7: applying a template to a non-empty day "is not offered", so the menu item exists only on an empty, editable day (Task 14's rule). The repository refuses a non-empty day too; if that ever happens (say the day filled in while the sheet was open) the sheet closes and says so.

**Files:**
- Create: `lib/features/clock/widgets/template_picker_sheet.dart`
- Modify: `lib/core/strings.dart`, `lib/features/clock/providers.dart`, `lib/features/clock/clock_screen.dart`
- Test: `test/features/clock/template_picker_sheet_test.dart`

**Interfaces:**
- Consumes: `ReuseRepository.watchTemplates`, `applyTemplate`, `deleteTemplate`, `DayTemplate`, `DayNotEmptyException` (Task 7); `confirmDestructive`.
- Produces: `templatesProvider` (`StreamProvider<List<DayTemplate>>`); `TemplatePickerSheet.show(BuildContext, {required DateTime day}) → Future<void>`; strings `templatesEmptyTitle`, `templatesEmptyBody`, `templatesLoadFailed`, `templateSummary(int, String)`, `templateSemantics(String, String, String)`, `deleteTemplate`, `deleteTemplateTitle`, `deleteTemplateBody`, `applyFailed`.

- [ ] **Step 1: Write the failing test**

**Create `test/features/clock/template_picker_sheet_test.dart`**

```dart
import 'package:energy_clock/app/navigation/tab_bar_inset.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/repositories/reuse_repository.dart';
import 'package:energy_clock/features/clock/clock_screen.dart';
import 'package:energy_clock/features/clock/widgets/template_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';
import '../../support/dial_pump.dart';

/// A menu item by its label. On an empty day the buttons beneath the dial use
/// the same words, so a plain text finder can match twice.
Finder menuItem(String label) => find.descendant(
  of: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
  matching: find.text(label),
);

void main() {
  late ClockHarness harness;

  // Wednesday 7 October 2026.
  final today = DateTime(2026, 10, 7);

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  int addOffice() => harness.reuse.addTemplate('Office day', const [
    TemplateItem(
      title: 'Deep work',
      tone: Tone.focus,
      range: MinuteRange(540, 660),
    ),
    TemplateItem(
      title: 'Lunch walk',
      tone: Tone.life,
      range: MinuteRange(750, 795),
    ),
  ]);

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness.app(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => TemplatePickerSheet.show(context, day: today),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists the templates, newest first, with their summary', (
    tester,
  ) async {
    addOffice();
    harness.reuse.addTemplate('Quiet day', const [
      TemplateItem(
        title: 'Read',
        tone: Tone.life,
        range: MinuteRange(600, 660),
      ),
    ]);
    await open(tester);

    expect(find.text(Strings.applyTemplate), findsOneWidget);
    expect(find.text('Office day'), findsOneWidget);
    expect(find.text('Quiet day'), findsOneWidget);
    expect(find.text('2 events · 2h 45m'), findsOneWidget);
    expect(find.text('1 event · 1h'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Quiet day')).dy,
      lessThan(tester.getTopLeft(find.text('Office day')).dy),
    );
  });

  testWidgets('shows a dot for each tone a template uses', (tester) async {
    final id = addOffice();
    await open(tester);

    expect(find.byKey(ValueKey('template-dot-$id-focus')), findsOneWidget);
    expect(find.byKey(ValueKey('template-dot-$id-life')), findsOneWidget);
    expect(find.byKey(ValueKey('template-dot-$id-inbox')), findsNothing);
  });

  testWidgets('a row is read as one button with its summary', (tester) async {
    final handle = tester.ensureSemantics();
    addOffice();
    await open(tester);

    expect(
      tester.getSemantics(
        find.bySemanticsLabel('Office day, 2 events, 2 hours 45 minutes'),
      ),
      matchesSemantics(
        label: 'Office day, 2 events, 2 hours 45 minutes',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('with no templates it explains how to make one', (tester) async {
    await open(tester);

    expect(find.text(Strings.templatesEmptyTitle), findsOneWidget);
    expect(find.text(Strings.templatesEmptyBody), findsOneWidget);
  });

  testWidgets('tapping a template puts its events on the day and closes', (
    tester,
  ) async {
    addOffice();
    await open(tester);

    await tester.tap(find.text('Office day'));
    await tester.pumpAndSettle();

    expect(find.byType(TemplatePickerSheet), findsNothing);
    final events = await harness.repository.eventsForDay(today);
    expect(events.map((event) => event.title), ['Deep work', 'Lunch walk']);
  });

  testWidgets('a day that filled up meanwhile closes the sheet and says so', (
    tester,
  ) async {
    addOffice();
    await open(tester);
    await harness.repository.createEvent(
      day: today,
      title: 'Already here',
      tone: Tone.inbox,
      range: const MinuteRange(900, 960),
    );

    await tester.tap(find.text('Office day'));
    await tester.pumpAndSettle();

    expect(find.byType(TemplatePickerSheet), findsNothing);
    expect(find.text(Strings.dayNotEmpty), findsOneWidget);
    expect(await harness.repository.eventsForDay(today), hasLength(1));
  });

  testWidgets('deleting asks first, and confirming removes the template', (
    tester,
  ) async {
    addOffice();
    await open(tester);

    await tester.tap(find.byTooltip(Strings.deleteTemplate));
    await tester.pumpAndSettle();
    expect(find.text(Strings.deleteTemplateTitle), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, Strings.delete));
    await tester.pumpAndSettle();

    expect(harness.reuse.templates, isEmpty);
    expect(find.text('Office day'), findsNothing);
    expect(find.text(Strings.templatesEmptyTitle), findsOneWidget);
  });

  testWidgets('cancelling the delete keeps the template', (tester) async {
    addOffice();
    await open(tester);

    await tester.tap(find.byTooltip(Strings.deleteTemplate));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, Strings.cancel));
    await tester.pumpAndSettle();

    expect(harness.reuse.templates, hasLength(1));
    expect(find.text('Office day'), findsOneWidget);
  });

  testWidgets('the delete button is at least 44 x 44', (tester) async {
    addOffice();
    await open(tester);

    final size = tester.getSize(find.byTooltip(Strings.deleteTemplate));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('a long list scrolls inside the sheet', (tester) async {
    for (var i = 0; i < 25; i++) {
      harness.reuse.addTemplate('Template $i', const [
        TemplateItem(
          title: 'Block',
          tone: Tone.focus,
          range: MinuteRange(540, 600),
        ),
      ]);
    }
    await open(tester);

    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('Template 0'), findsOneWidget);
  });

  for (final width in [320.0, 402.0, 834.0]) {
    for (final textScale in [1.0, 2.0, 3.12]) {
      testWidgets(
        'fits a ${width.toInt()} pt window at text ${(textScale * 100).toInt()}%',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          addOffice();
          harness.reuse.addTemplate(
            'A template with a rather long name that has to wrap somewhere',
            const [
              TemplateItem(
                title: 'Block',
                tone: Tone.inbox,
                range: MinuteRange(540, 600),
              ),
            ],
          );
          await tester.pumpWidget(
            harness.app(
              Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      TemplatePickerSheet.show(context, day: today),
                  child: const Text('open'),
                ),
              ),
              textScale: textScale,
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  group('from the Clock screen', () {
    testWidgets('an empty day offers Apply template and fills from it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addOffice();
      await tester.pumpWidget(
        harness.app(
          const TabBarInset(height: 84, child: ClockScreen()),
          reduceMotion: true,
        ),
      );
      await pumpDial(tester);

      await tester.tap(find.byTooltip(Strings.moreActions));
      await tester.pumpAndSettle();
      await tester.tap(menuItem(Strings.applyTemplate));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Office day'));
      await tester.pumpAndSettle();

      expect(find.byType(TemplatePickerSheet), findsNothing);
      expect(await harness.repository.eventsForDay(today), hasLength(2));
    });

    testWidgets('a day with events does not offer it', (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await harness.repository.createEvent(
        day: today,
        title: 'Deep work',
        tone: Tone.focus,
        range: const MinuteRange(540, 660),
      );
      await tester.pumpWidget(
        harness.app(const TabBarInset(height: 84, child: ClockScreen())),
      );
      await pumpDial(tester);

      await tester.tap(find.byTooltip(Strings.moreActions));
      await tester.pumpAndSettle();

      expect(menuItem(Strings.applyTemplate), findsNothing);
      expect(menuItem(Strings.saveAsTemplate), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run the test to see it fail**

```bash
# expect: FAIL — template_picker_sheet.dart and the strings do not exist yet
flutter test test/features/clock/template_picker_sheet_test.dart
```

- [ ] **Step 3: Write the code**

**Edit `lib/core/strings.dart`**

Replace:

```dart
  static const String dayNotEmpty = 'That day already has events.';
}
```

With:

```dart
  static const String dayNotEmpty = 'That day already has events.';

  // The template picker.
  static const String templatesEmptyTitle = 'No templates yet';
  static const String templatesEmptyBody =
      'Open the ⋯ menu on a day you like and choose Save as template.';
  static const String templatesLoadFailed = "Couldn't load your templates.";
  static String templateSummary(int count, String duration) =>
      '${eventCount(count)} · $duration';
  static String templateSemantics(
    String name,
    String events,
    String duration,
  ) => '$name, $events, $duration';
  static const String deleteTemplate = 'Delete template';
  static const String deleteTemplateTitle = 'Delete this template?';
  static const String deleteTemplateBody =
      'Days you already made from it are not changed.';
  static const String applyFailed = "Couldn't apply the template.";
}
```

**Edit `lib/features/clock/providers.dart`**

Replace:

```dart
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
```

With:

```dart
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/reuse_repository.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
```

Replace:

```dart
/// How a series repeats, keyed by series id, for the detail sheet. Null when
```

With:

```dart
/// The saved day templates, newest first, for the template picker.
final templatesProvider = StreamProvider<List<DayTemplate>>((ref) {
  return ref.watch(reuseRepositoryProvider).watchTemplates();
});

/// How a series repeats, keyed by series id, for the detail sheet. Null when
```

**Create `lib/features/clock/widgets/template_picker_sheet.dart`**

```dart
import 'dart:async';

import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/reuse_repository.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/shared/widgets/adaptive_dialog.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:energy_clock/shared/widgets/press_scale.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A bottom sheet of the saved day templates. Tapping one puts its events on
/// [day] and closes the sheet; the trash button deletes a template after a
/// confirmation. Only an empty day is offered this sheet (spec §7), and the
/// repository refuses a day that is not empty.
class TemplatePickerSheet extends ConsumerWidget {
  const TemplatePickerSheet({required this.day, super.key});

  final DateTime day;

  static Future<void> show(BuildContext context, {required DateTime day}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => TemplatePickerSheet(day: day),
    );
  }

  Future<void> _apply(
    BuildContext context,
    WidgetRef ref,
    DayTemplate template,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(reuseRepositoryProvider)
          .applyTemplate(templateId: template.id, day: day);
      navigator.pop();
      unawaited(HapticFeedback.mediumImpact());
    } on DayNotEmptyException {
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text(Strings.dayNotEmpty)),
      );
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text(Strings.applyFailed)),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    DayTemplate template,
  ) async {
    final confirmed = await confirmDestructive(
      context,
      title: Strings.deleteTemplateTitle,
      body: Strings.deleteTemplateBody,
      confirmLabel: Strings.delete,
      cancelLabel: Strings.cancel,
    );
    if (!confirmed) return;
    await ref.read(reuseRepositoryProvider).deleteTemplate(template.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(templatesProvider);

    return Padding(
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
          Text(
            Strings.applyTemplate,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          templates.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: Text(Strings.templatesLoadFailed)),
            ),
            data: (list) => list.isEmpty
                ? const _EmptyState()
                : Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: list.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) => _TemplateTile(
                        template: list[index],
                        onApply: () => _apply(context, ref, list[index]),
                        onDelete: () => _delete(context, ref, list[index]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          Text(
            Strings.templatesEmptyTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            Strings.templatesEmptyBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// One template: its name, a summary line with a dot per tone, and a trash
/// button. The name and summary are one button that applies the template.
class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.template,
    required this.onApply,
    required this.onDelete,
  });

  final DayTemplate template;
  final VoidCallback onApply;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toneColors = context.toneColors;
    final colors = context.appColors;
    final summary = Strings.templateSummary(
      template.eventCount,
      formatDurationMinutes(template.totalMinutes),
    );

    return AppCard(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: Strings.templateSemantics(
                template.name,
                Strings.eventCount(template.eventCount),
                spokenDurationMinutes(template.totalMinutes),
              ),
              excludeSemantics: true,
              onTap: onApply,
              child: PressScale(
                onTap: onApply,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              summary,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          for (final tone in template.tones)
                            Padding(
                              padding: const EdgeInsets.only(right: 3),
                              child: DecoratedBox(
                                key: ValueKey(
                                  'template-dot-${template.id}-${tone.name}',
                                ),
                                decoration: BoxDecoration(
                                  color: toneColors.fillFor(tone),
                                  shape: BoxShape.circle,
                                ),
                                child: const SizedBox.square(dimension: 8),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(CupertinoIcons.trash, size: 20, color: colors.muted),
            tooltip: Strings.deleteTemplate,
            onPressed: onDelete,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
        ],
      ),
    );
  }
}
```

**Edit `lib/features/clock/clock_screen.dart`**

Replace:

```dart
import 'package:energy_clock/features/clock/widgets/start_session.dart';
```

With:

```dart
import 'package:energy_clock/features/clock/widgets/start_session.dart';
import 'package:energy_clock/features/clock/widgets/template_picker_sheet.dart';
```

Replace:

```dart
      onCopyYesterday: canFill && yesterdayHasEvents
          ? () => unawaited(copyPreviousDay(context, ref, selected))
          : null,
    );
```

With:

```dart
      onCopyYesterday: canFill && yesterdayHasEvents
          ? () => unawaited(copyPreviousDay(context, ref, selected))
          : null,
      onApplyTemplate: canFill
          ? () => unawaited(TemplatePickerSheet.show(context, day: selected))
          : null,
    );
```

- [ ] **Step 4: Run the tests, the analyzer and the whole suite**

```bash
# expect: PASS — 21 new tests; analyzer clean; the whole suite stays green
flutter test test/features/clock/template_picker_sheet_test.dart && flutter analyze && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat: template picker sheet and apply template

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---
### Task 16: The empty day's Copy yesterday and Apply template buttons

Spec §5.4: "An empty, editable day shows **Copy yesterday** and **Apply template** buttons beneath the dial, alongside the invitation to drag out a first event." Both actions already work from the overflow menu (Tasks 14–15); this task puts them where a person looks on an empty day.

- A `ReuseRow` of two pill buttons. **Copy yesterday** is left out when yesterday has no events (nothing to copy); **Apply template** is always there on an empty editable day (its sheet explains an empty template list).
- It sits **under the Now card, in the slot the day-load bar uses** on a day with events (an empty day has no bar, so the slot is free).
- The Clock screen never scrolls, so the row is part of `ClockLayoutPlan`: it reserves 52 pt (an 8 pt gap and a 44 pt row) and is **dropped before anything else gives way** when the dial would be under 300 pt, and always at text sizes above 130%. The menu keeps the same two actions, so nothing is lost when the row is dropped.
- On a wide window the row goes in the right pane, under the Now card.

**Files:**
- Create: `lib/features/clock/widgets/reuse_row.dart`
- Replace: `lib/features/clock/clock_layout.dart`
- Modify: `lib/features/clock/clock_screen.dart`, the goldens listed in Step 5
- Test: `test/features/clock/reuse_row_test.dart`, `test/features/clock/clock_layout_reuse_test.dart`, `test/features/clock/clock_screen_reuse_row_test.dart`, `test/features/clock/clock_screen_empty_golden_test.dart`

**Interfaces:**
- Consumes: `copyPreviousDay`, `TemplatePickerSheet.show` (Tasks 14–15); `previousDayEventsProvider`.
- Produces: `ReuseRow({required VoidCallback? onCopyYesterday, required VoidCallback onApplyTemplate})` with `ReuseRow.height` (44); `ClockLayoutPlan.forHeight(available, {textScale, hasDayLoad, hasReuseTools})` and the field `showReuseTools`.

- [ ] **Step 1: Write the failing tests**

**Create `test/features/clock/reuse_row_test.dart`**

```dart
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/clock/widgets/reuse_row.dart';
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

  testWidgets('shows both buttons and calls the one that is tapped', (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(
      harness.app(
        ReuseRow(
          onCopyYesterday: () => calls.add('copy'),
          onApplyTemplate: () => calls.add('apply'),
        ),
      ),
    );

    await tester.tap(find.text(Strings.copyYesterday));
    await tester.tap(find.text(Strings.applyTemplate));

    expect(calls, ['copy', 'apply']);
  });

  testWidgets('leaves Copy yesterday out when there is nothing to copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness.app(ReuseRow(onCopyYesterday: null, onApplyTemplate: () {})),
    );

    expect(find.text(Strings.copyYesterday), findsNothing);
    expect(find.text(Strings.applyTemplate), findsOneWidget);
  });

  testWidgets('the buttons are read as buttons', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      harness.app(ReuseRow(onCopyYesterday: () {}, onApplyTemplate: () {})),
    );

    for (final label in [Strings.copyYesterday, Strings.applyTemplate]) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        matchesSemantics(label: label, isButton: true, hasTapAction: true),
      );
    }
    handle.dispose();
  });

  testWidgets('the row is ${ReuseRow.height} points tall', (tester) async {
    await tester.pumpWidget(
      harness.app(ReuseRow(onCopyYesterday: () {}, onApplyTemplate: () {})),
    );

    expect(tester.getSize(find.byType(ReuseRow)).height, ReuseRow.height);
  });

  for (final width in [320.0, 375.0]) {
    for (final textScale in [1.0, 1.3, 3.12]) {
      testWidgets(
        'fits ${width.toInt()} pt at text ${(textScale * 100).toInt()}%',
        (tester) async {
          tester.view.physicalSize = Size(width, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            harness.app(
              ReuseRow(onCopyYesterday: () {}, onApplyTemplate: () {}),
              textScale: textScale,
            ),
          );

          expect(tester.takeException(), isNull);
          expect(tester.getSize(find.byType(ReuseRow)).height, ReuseRow.height);
        },
      );
    }
  }
}
```

**Create `test/features/clock/clock_layout_reuse_test.dart`**

```dart
import 'package:energy_clock/features/clock/clock_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a day that needs no reuse row plans exactly as before', () {
    final plain = ClockLayoutPlan.forHeight(697, hasDayLoad: false);
    final explicit = ClockLayoutPlan.forHeight(
      697,
      hasDayLoad: false,
      hasReuseTools: false,
    );

    expect(plain.showReuseTools, isFalse);
    expect(explicit.dialHeight, plain.dialHeight);
  });

  test('a tall phone shows the row and the dial gives up 52 points', () {
    final without = ClockLayoutPlan.forHeight(697, hasDayLoad: false);
    final with_ = ClockLayoutPlan.forHeight(
      697,
      hasDayLoad: false,
      hasReuseTools: true,
    );

    expect(with_.showReuseTools, isTrue);
    expect(without.dialHeight - with_.dialHeight, closeTo(52, 1e-9));
    expect(with_.compactNowCard, isFalse);
    expect(with_.showHeaderDate, isTrue);
  });

  test('the row is dropped exactly when the dial would be under 300', () {
    // Without the day-load bar: dial = height - 220 - 52 with the row.
    expect(
      ClockLayoutPlan.forHeight(
        572,
        hasDayLoad: false,
        hasReuseTools: true,
      ).showReuseTools,
      isTrue,
    );
    expect(
      ClockLayoutPlan.forHeight(
        571,
        hasDayLoad: false,
        hasReuseTools: true,
      ).showReuseTools,
      isFalse,
    );
  });

  test('the row goes before the Now card shrinks', () {
    final plan = ClockLayoutPlan.forHeight(
      563,
      hasDayLoad: false,
      hasReuseTools: true,
    );

    expect(plan.showReuseTools, isFalse);
    expect(plan.compactNowCard, isFalse);
    expect(plan.dialHeight, closeTo(343, 1e-9));
  });

  test('large text never shows the row', () {
    final plan = ClockLayoutPlan.forHeight(
      1400,
      textScale: 1.31,
      hasDayLoad: false,
      hasReuseTools: true,
    );

    expect(plan.showReuseTools, isFalse);
  });

  test('text at 130% still has room for it', () {
    final plan = ClockLayoutPlan.forHeight(
      1400,
      textScale: 1.3,
      hasDayLoad: false,
      hasReuseTools: true,
    );

    expect(plan.showReuseTools, isTrue);
  });
}
```

**Create `test/features/clock/clock_screen_reuse_row_test.dart`**

```dart
import 'package:energy_clock/app/navigation/tab_bar_inset.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/clock_screen.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/dial_view.dart';
import 'package:energy_clock/features/clock/widgets/reuse_row.dart';
import 'package:energy_clock/features/clock/widgets/template_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';
import '../../support/dial_pump.dart';

void main() {
  late ClockHarness harness;

  final yesterday = DateTime(2026, 10, 6);
  final today = DateTime(2026, 10, 7);

  setUp(() {
    harness = ClockHarness(); // Wednesday 7 October 2026, 10:30
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> addEvent(DateTime day) => harness.repository.createEvent(
    day: day,
    title: 'Deep work',
    tone: Tone.focus,
    range: const MinuteRange(540, 660),
  );

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(402, 874),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness.app(
        const TabBarInset(height: 84, child: ClockScreen()),
        textScale: textScale,
        reduceMotion: true,
      ),
    );
    await pumpDial(tester);
  }

  testWidgets('an empty editable day shows both buttons beneath the dial', (
    tester,
  ) async {
    await addEvent(yesterday);
    await mount(tester);

    expect(find.byType(ReuseRow), findsOneWidget);
    // The row's buttons, not the overflow menu's items (the menu is closed).
    expect(find.text(Strings.copyYesterday), findsOneWidget);
    expect(find.text(Strings.applyTemplate), findsOneWidget);
    expect(find.text(Strings.emptyDayTitle), findsOneWidget);
  });

  testWidgets('with nothing to copy only Apply template is shown', (
    tester,
  ) async {
    await mount(tester);

    expect(find.text(Strings.copyYesterday), findsNothing);
    expect(find.text(Strings.applyTemplate), findsOneWidget);
  });

  testWidgets('Copy yesterday fills the day and the row goes away', (
    tester,
  ) async {
    await addEvent(yesterday);
    await mount(tester);

    await tester.tap(find.text(Strings.copyYesterday));
    await pumpDial(tester);

    expect(await harness.repository.eventsForDay(today), hasLength(1));
    expect(find.byType(ReuseRow), findsNothing);
  });

  testWidgets('Apply template opens the picker', (tester) async {
    await mount(tester);

    await tester.tap(find.text(Strings.applyTemplate));
    await tester.pumpAndSettle();

    expect(find.byType(TemplatePickerSheet), findsOneWidget);
  });

  testWidgets('a day with events shows no row', (tester) async {
    await addEvent(today);
    await addEvent(yesterday);
    await mount(tester);

    expect(find.byType(ReuseRow), findsNothing);
  });

  testWidgets('a past day shows no row', (tester) async {
    harness.container.read(selectedDateProvider.notifier).select(yesterday);
    await mount(tester);

    expect(find.byType(ReuseRow), findsNothing);
  });

  testWidgets('large text drops the row; the menu still has the actions', (
    tester,
  ) async {
    await addEvent(yesterday);
    await mount(tester, textScale: 2);

    expect(find.byType(ReuseRow), findsNothing);
    await tester.tap(find.byTooltip(Strings.moreActions));
    await tester.pumpAndSettle();
    expect(find.text(Strings.copyYesterday), findsOneWidget);
    expect(find.text(Strings.applyTemplate), findsOneWidget);
  });

  testWidgets('a short window drops the row too', (tester) async {
    await addEvent(yesterday);
    // 640 - 84 (the tab bar) leaves 556 pt: a dial of 291 with the row.
    await mount(tester, size: const Size(375, 640));

    expect(find.byType(ReuseRow), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a wide window puts the row in the right pane', (tester) async {
    await addEvent(yesterday);
    await mount(tester, size: const Size(1194, 834));

    expect(find.byType(ReuseRow), findsOneWidget);
    final row = tester.getTopLeft(find.byType(ReuseRow));
    final dial = tester.getCenter(find.byType(DialView));
    expect(row.dx, greaterThan(dial.dx));
    expect(tester.takeException(), isNull);
  });
}
```

**Create `test/features/clock/clock_screen_empty_golden_test.dart`**

```dart
// Golden image of the Clock tab on an empty editable day: the invitation to
// drag out a first event, and the Copy yesterday and Apply template buttons
// beneath it. Animations are off and the clock is fixed at Wednesday 7 October
// 2026, 10:30, so the image is deterministic.
import 'package:energy_clock/app/navigation/tab_scaffold.dart';
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';
import '../../support/dial_pump.dart';

const screenKey = ValueKey('clock-empty-golden');

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> check(
    WidgetTester tester, {
    required Size size,
    required ThemeData theme,
    required String file,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Yesterday has events, so Copy yesterday is offered.
    await harness.repository.createEvent(
      day: DateTime(2026, 10, 6),
      title: 'Deep work',
      tone: Tone.focus,
      range: const MinuteRange(540, 660),
    );

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
    await tester.pump(const Duration(seconds: 1));
    await expectLater(
      find.byKey(screenKey),
      matchesGoldenFile('goldens/$file'),
    );
  }

  testWidgets('iPhone 17 Pro, empty day, light', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.light,
      file: 'clock_iphone_empty_light.png',
    );
  });

  testWidgets('iPhone 17 Pro, empty day, dark', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.dark,
      file: 'clock_iphone_empty_dark.png',
    );
  });

  testWidgets('iPad 11" landscape, empty day, light', (tester) async {
    await check(
      tester,
      size: const Size(1194, 834),
      theme: AppTheme.light,
      file: 'clock_ipad_landscape_empty_light.png',
    );
  });
}
```

- [ ] **Step 2: Run the tests to see them fail**

```bash
# expect: FAIL — reuse_row.dart and ClockLayoutPlan.showReuseTools do not exist yet (the golden test has no images yet either)
flutter test test/features/clock/reuse_row_test.dart test/features/clock/clock_layout_reuse_test.dart test/features/clock/clock_screen_reuse_row_test.dart
```

- [ ] **Step 3: Write the code**

**Create `lib/features/clock/widgets/reuse_row.dart`**

```dart
import 'dart:async';

import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/shared/widgets/press_scale.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The two ways to fill an empty day from another: Copy yesterday and Apply
/// template (spec §5.4). Two faint-ink pills side by side, 44 pt tall.
///
/// [onCopyYesterday] is null when yesterday has no events, and the button is
/// then left out. The label text scales down to fit rather than wrapping.
class ReuseRow extends StatelessWidget {
  const ReuseRow({
    required this.onCopyYesterday,
    required this.onApplyTemplate,
    super.key,
  });

  /// The row's height.
  static const double height = 44;

  final VoidCallback? onCopyYesterday;
  final VoidCallback onApplyTemplate;

  @override
  Widget build(BuildContext context) {
    final copy = onCopyYesterday;

    return SizedBox(
      height: height,
      child: Row(
        children: [
          if (copy != null) ...[
            Expanded(
              child: _ReuseButton(
                label: Strings.copyYesterday,
                icon: CupertinoIcons.doc_on_doc,
                onTap: copy,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: _ReuseButton(
              label: Strings.applyTemplate,
              icon: CupertinoIcons.rectangle_grid_2x2,
              onTap: onApplyTemplate,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReuseButton extends StatelessWidget {
  const _ReuseButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.ink.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: colors.ink),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      label,
                      maxLines: 1,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge!.copyWith(color: colors.ink),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

**Replace `lib/features/clock/clock_layout.dart`**

```dart
import 'package:energy_clock/features/clock/widgets/clock_header.dart';
import 'package:energy_clock/features/clock/widgets/day_load_bar.dart';
import 'package:energy_clock/features/clock/widgets/now_card.dart';
import 'package:energy_clock/features/clock/widgets/reuse_row.dart';
import 'package:energy_clock/features/clock/widgets/week_strip.dart';

/// Which optional pieces of the Clock screen fit, decided from the height left
/// for them and the text size.
///
/// The page never scrolls (a vertical scroll would compete with the dial's drag
/// gestures), so instead it gives way in a fixed order:
///
/// 1. At text sizes above 130%: no day-load bar, no reuse row, no week dots,
///    one-row Now card.
/// 2. Otherwise, if the dial would be under 300 pt: drop the day-load bar and
///    the reuse row (an empty day has the row where a day with events has the
///    bar; the overflow menu keeps the same actions).
/// 3. If it would still be under 260 pt: make the Now card one row.
/// 4. If it would still be under 240 pt: drop the header's date line.
class ClockLayoutPlan {
  const ClockLayoutPlan({
    required this.showDayLoad,
    required this.compactNowCard,
    required this.showHeaderDate,
    required this.showWeekDots,
    required this.dialHeight,
    this.showReuseTools = false,
  });

  final bool showDayLoad;
  final bool compactNowCard;
  final bool showHeaderDate;
  final bool showWeekDots;

  /// Whether the Copy yesterday / Apply template row has room.
  final bool showReuseTools;

  /// The height the dial area is left with under this plan.
  final double dialHeight;

  /// Space between the stacked pieces.
  static const double gap = 8;

  static const double smallDial = 300;
  static const double tinyDial = 260;
  static const double minDial = 240;
  static const double largeTextScale = 1.3;

  /// Plans the screen for [available] pt of height, after the floating tab bar.
  /// [hasDayLoad] is false on a day with no events, when the bar draws nothing
  /// and so reserves no room. [hasReuseTools] is true on an empty editable day,
  /// which wants the reuse row in the bar's place.
  static ClockLayoutPlan forHeight(
    double available, {
    double textScale = 1,
    bool hasDayLoad = true,
    bool hasReuseTools = false,
  }) {
    final scale = textScale.clamp(1.0, 2.0);
    final largeText = scale > largeTextScale;

    double dialFor({
      required bool dayLoad,
      required bool reuse,
      required bool compact,
      required bool date,
    }) {
      final header = ClockHeader.heightFor(scale, showDate: date);
      final strip = WeekStrip.heightFor(scale);
      final now = compact
          ? NowCard.compactHeightFor(scale)
          : NowCard.heightFor(scale);
      final bar = dayLoad ? gap + DayLoadBar.height : 0;
      final tools = reuse ? gap + ReuseRow.height : 0;
      // A gap under the strip and another above the Now card.
      return available - header - strip - gap - gap - now - bar - tools;
    }

    var dayLoad = hasDayLoad && !largeText;
    var reuse = hasReuseTools && !largeText;
    var compact = largeText;
    var date = true;
    var dial = dialFor(
      dayLoad: dayLoad,
      reuse: reuse,
      compact: compact,
      date: date,
    );

    if (dayLoad && dial < smallDial) {
      dayLoad = false;
      dial = dialFor(
        dayLoad: dayLoad,
        reuse: reuse,
        compact: compact,
        date: date,
      );
    }
    if (reuse && dial < smallDial) {
      reuse = false;
      dial = dialFor(
        dayLoad: dayLoad,
        reuse: reuse,
        compact: compact,
        date: date,
      );
    }
    if (!compact && dial < tinyDial) {
      compact = true;
      dial = dialFor(
        dayLoad: dayLoad,
        reuse: reuse,
        compact: compact,
        date: date,
      );
    }
    if (date && dial < minDial) {
      date = false;
      dial = dialFor(
        dayLoad: dayLoad,
        reuse: reuse,
        compact: compact,
        date: date,
      );
    }

    return ClockLayoutPlan(
      showDayLoad: dayLoad,
      showReuseTools: reuse,
      compactNowCard: compact,
      showHeaderDate: date,
      showWeekDots: !largeText,
      dialHeight: dial,
    );
  }
}
```

**Edit `lib/features/clock/clock_screen.dart`**

Replace:

```dart
import 'package:energy_clock/features/clock/widgets/reuse_actions.dart';
```

With:

```dart
import 'package:energy_clock/features/clock/widgets/reuse_actions.dart';
import 'package:energy_clock/features/clock/widgets/reuse_row.dart';
```

Replace:

```dart
    Widget header({bool showDate = true}) => ClockHeader(
      showDate: showDate,
      onAdd: () => openCreate(const MinuteRange(540, 600)),
      onSaveTemplate: hasEvents
          ? () => unawaited(saveDayAsTemplate(context, ref, selected))
          : null,
      onCopyYesterday: canFill && yesterdayHasEvents
          ? () => unawaited(copyPreviousDay(context, ref, selected))
          : null,
      onApplyTemplate: canFill
          ? () => unawaited(TemplatePickerSheet.show(context, day: selected))
          : null,
    );
```

With:

```dart
    // The two ways to fill an empty day; null when they do not apply.
    final VoidCallback? copyYesterday = canFill && yesterdayHasEvents
        ? () => unawaited(copyPreviousDay(context, ref, selected))
        : null;
    final VoidCallback? applyTemplate = canFill
        ? () => unawaited(TemplatePickerSheet.show(context, day: selected))
        : null;

    Widget header({bool showDate = true}) => ClockHeader(
      showDate: showDate,
      onAdd: () => openCreate(const MinuteRange(540, 600)),
      onSaveTemplate: hasEvents
          ? () => unawaited(saveDayAsTemplate(context, ref, selected))
          : null,
      onCopyYesterday: copyYesterday,
      onApplyTemplate: applyTemplate,
    );

    final Widget? reuse = applyTemplate == null
        ? null
        : ReuseRow(
            onCopyYesterday: copyYesterday,
            onApplyTemplate: applyTemplate,
          );
```

Replace:

```dart
                  if (hasEvents && !largeText) ...[
                    const SizedBox(height: ClockLayoutPlan.gap),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: DayLoadBar(),
                    ),
                  ],
```

With:

```dart
                  if (hasEvents && !largeText) ...[
                    const SizedBox(height: ClockLayoutPlan.gap),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: DayLoadBar(),
                    ),
                  ],
                  if (reuse != null && !largeText) ...[
                    const SizedBox(height: ClockLayoutPlan.gap),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: reuse,
                    ),
                  ],
```

Replace:

```dart
            hasDayLoad: hasEvents,
          );
```

With:

```dart
            hasDayLoad: hasEvents,
            hasReuseTools: applyTemplate != null,
          );
```

Replace:

```dart
                if (plan.showDayLoad) ...[
                  const SizedBox(height: ClockLayoutPlan.gap),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: DayLoadBar(),
                  ),
                ],
```

With:

```dart
                if (plan.showDayLoad) ...[
                  const SizedBox(height: ClockLayoutPlan.gap),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: DayLoadBar(),
                  ),
                ],
                if (plan.showReuseTools && reuse != null) ...[
                  const SizedBox(height: ClockLayoutPlan.gap),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: reuse,
                  ),
                ],
```

- [ ] **Step 4: Run the new tests, the analyzer and the whole suite**

```bash
# expect: PASS — 25 new tests; analyzer clean; the Clock layout matrix and the other Clock tests stay green (the empty-day golden test has no images until Step 5)
flutter test test/features/clock/reuse_row_test.dart test/features/clock/clock_layout_reuse_test.dart test/features/clock/clock_screen_reuse_row_test.dart test/features/clock/clock_layout_matrix_test.dart test/features/clock/clock_screen_test.dart test/features/clock/clock_screen_wide_test.dart && flutter analyze
```

- [ ] **Step 5: Create the empty-day goldens and look at them**

```bash
# expect: RUN — writes clock_iphone_empty_light.png, clock_iphone_empty_dark.png and clock_ipad_landscape_empty_light.png
flutter test --update-goldens test/features/clock/clock_screen_empty_golden_test.dart
rm -rf test/features/clock/failures
ls test/features/clock/goldens | grep empty
```

Open the three images (`test/features/clock/goldens/clock_iphone_empty_light.png`, `…_dark.png`, `clock_ipad_landscape_empty_light.png`). Check: under the Now card ("Nothing planned yet") the two pills Copy yesterday and Apply template sit on one row with the same left and right edges as the card; no day-load bar; the dial is smaller than on a day with events but still large; on the iPad the row is in the right pane. If anything looks cramped or misaligned, fix `ReuseRow` or its padding before committing.

- [ ] **Step 6: Run the analyzer and the whole suite**

```bash
# expect: PASS — analyzer clean; the whole suite stays green
flutter analyze && flutter test
```

- [ ] **Step 7: Commit**

```bash
git add lib test
git commit -m "feat: Copy yesterday and Apply template buttons on an empty day

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---
## Stage 4 — The Calendar tab

### Task 17: A day's tone ring and the day cell

Spec §7: "Each day cell renders a miniature ring showing that day's tone balance, so a month's character is visible without reading numbers." This task builds that cell. It is the Calendar's one new visual idea, so it gets its own task and goldens before any screen exists.

- **`ringSegments`** (pure): splits a full circle between the tones in proportion to their planned minutes, in the fixed tone order starting at the top, with a gap between neighbours so adjacent tones never touch. A tone with a sliver of the day still gets a visible arc (a minimum sweep); one tone alone is a full circle with no gap.
- **`DayRingPainter`**: draws those arcs as thin rounded strokes in the tone colours. A day with no events gets a faint full circle (the `outline` colour, decorative), so every cell reads as a day.
- **`DayCell`**: the ring with the day number inside. **Today** is a filled ink disc with the number in `onInk`; **past days** have a muted number (they are read-only); future days an ink one. The whole cell is one button (the parent sizes it, at least 40 pt), read aloud as "Wednesday 7 October, Focus 3 hours and Life 1 hour planned, today".

Colour only ever means a tone: the rings use the tone colours, everything else is neutral. The ring colours sit on the card `surface`, a pair the existing contrast tests already cover.

**Files:**
- Create: `lib/features/calendar/model/ring_segments.dart`, `lib/features/calendar/widgets/day_ring_painter.dart`, `lib/features/calendar/widgets/day_cell.dart`
- Test: `test/features/calendar/ring_segments_test.dart`, `test/features/calendar/day_cell_test.dart`, `test/features/calendar/day_cell_golden_test.dart`, `test/features/calendar/goldens/day_cells_light.png` and `day_cells_dark.png` (generated)

**Interfaces:**
- Consumes: `ToneMinutes` (Task 8); `Tone`; `context.toneColors`, `context.appColors`; `Strings.weekDaySemantics`; `spokenDurationMinutes`.
- Produces: `RingSegment({tone, startAngle, sweepAngle})`; `ringSegments(Map<Tone, int> minutes, {double gap = 0.2, double minSweep = 0.25}) → List<RingSegment>` (empty for no minutes; angles in radians, clockwise from the top); `DayRingPainter({segments, colors, emptyColor, strokeWidth})`; `DayCell({required DateTime day, required double size, required ToneMinutes minutes, required bool isToday, required bool isPast, required VoidCallback onTap})`.

- [ ] **Step 1: Write the failing tests**

**Create `test/features/calendar/ring_segments_test.dart`**

```dart
import 'dart:math' as math;

import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/calendar/model/ring_segments.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const full = 2 * math.pi;
  const top = -math.pi / 2;

  test('a day with no minutes has no segments', () {
    expect(ringSegments(const {}), isEmpty);
    expect(ringSegments({Tone.focus: 0, Tone.life: 0}), isEmpty);
  });

  test('one tone alone is a full circle from the top, with no gap', () {
    final segments = ringSegments({Tone.life: 90});

    expect(segments, hasLength(1));
    expect(segments.single.tone, Tone.life);
    expect(segments.single.startAngle, top);
    expect(segments.single.sweepAngle, full);
  });

  test('a tone with no minutes is left out', () {
    final segments = ringSegments({
      Tone.focus: 60,
      Tone.life: 0,
      Tone.inbox: 60,
    });
    expect(segments.map((segment) => segment.tone), [Tone.focus, Tone.inbox]);
  });

  test('segments follow the fixed tone order, whatever the map order', () {
    final segments = ringSegments({
      Tone.inbox: 30,
      Tone.life: 30,
      Tone.focus: 30,
    });
    expect(segments.map((segment) => segment.tone), Tone.values);
  });

  test('sweeps are proportional to the minutes', () {
    final segments = ringSegments({Tone.focus: 120, Tone.life: 60}, gap: 0.2);

    // 120 and 60 minutes share the circle minus two gaps, two to one.
    expect(segments[0].sweepAngle / segments[1].sweepAngle, closeTo(2, 1e-9));
  });

  test('segments and gaps together fill the circle exactly', () {
    for (final minutes in [
      {Tone.focus: 100, Tone.life: 50},
      {Tone.focus: 100, Tone.life: 50, Tone.inbox: 25},
      {Tone.focus: 1000, Tone.life: 1, Tone.inbox: 1},
    ]) {
      final segments = ringSegments(minutes, gap: 0.3);
      final swept = segments.fold<double>(0, (sum, s) => sum + s.sweepAngle);
      expect(swept + segments.length * 0.3, closeTo(full, 1e-9));
    }
  });

  test('the first segment starts half a gap past the top', () {
    final segments = ringSegments({Tone.focus: 60, Tone.life: 60}, gap: 0.4);
    expect(segments.first.startAngle, closeTo(top + 0.2, 1e-9));
  });

  test('each segment starts one gap after the previous one ends', () {
    final segments = ringSegments({
      Tone.focus: 60,
      Tone.life: 30,
      Tone.inbox: 30,
    }, gap: 0.25);

    for (var i = 1; i < segments.length; i++) {
      final previousEnd =
          segments[i - 1].startAngle + segments[i - 1].sweepAngle;
      expect(segments[i].startAngle, closeTo(previousEnd + 0.25, 1e-9));
    }
  });

  test('a sliver of the day still gets a visible arc', () {
    final segments = ringSegments({Tone.focus: 1000, Tone.inbox: 1});

    expect(segments.last.tone, Tone.inbox);
    expect(segments.last.sweepAngle, greaterThan(0.2));
  });

  test('segments compare by value', () {
    expect(
      const RingSegment(Tone.focus, 0, 1),
      const RingSegment(Tone.focus, 0, 1),
    );
    expect(
      const RingSegment(Tone.focus, 0, 1),
      isNot(const RingSegment(Tone.life, 0, 1)),
    );
    expect(
      const RingSegment(Tone.focus, 0, 1).hashCode,
      const RingSegment(Tone.focus, 0, 1).hashCode,
    );
  });
}
```

**Create `test/features/calendar/day_cell_test.dart`**

```dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/calendar/widgets/day_cell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;

  // Wednesday 7 October 2026.
  final day = DateTime(2026, 10, 7);

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Widget cell({
    Map<Tone, int> minutes = const {},
    bool isToday = false,
    bool isPast = false,
    VoidCallback? onTap,
    double size = 48,
  }) {
    return Center(
      child: DayCell(
        day: day,
        size: size,
        minutes: minutes,
        isToday: isToday,
        isPast: isPast,
        onTap: onTap ?? () {},
      ),
    );
  }

  testWidgets('shows the day of the month', (tester) async {
    await tester.pumpWidget(harness.app(cell()));
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('tapping the cell calls onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(harness.app(cell(onTap: () => taps++)));

    await tester.tap(find.byType(DayCell));

    expect(taps, 1);
  });

  testWidgets('a future day has an ink number, a past day a muted one', (
    tester,
  ) async {
    await tester.pumpWidget(harness.app(cell()));
    final context = tester.element(find.byType(DayCell));
    final colors = context.appColors;
    expect(tester.widget<Text>(find.text('7')).style!.color, colors.ink);

    await tester.pumpWidget(harness.app(cell(isPast: true)));
    expect(tester.widget<Text>(find.text('7')).style!.color, colors.muted);
  });

  testWidgets('today has an ink disc and the number in onInk', (tester) async {
    await tester.pumpWidget(harness.app(cell(isToday: true)));
    final colors = tester.element(find.byType(DayCell)).appColors;

    expect(tester.widget<Text>(find.text('7')).style!.color, colors.onInk);
    final disc = find.byKey(const ValueKey('day-cell-today-disc'));
    expect(disc, findsOneWidget);
    final decoration =
        tester.widget<DecoratedBox>(disc).decoration as BoxDecoration;
    expect(decoration.color, colors.ink);
    expect(decoration.shape, BoxShape.circle);
  });

  testWidgets('other days have no disc', (tester) async {
    await tester.pumpWidget(harness.app(cell()));
    expect(find.byKey(const ValueKey('day-cell-today-disc')), findsNothing);
  });

  testWidgets('is read aloud with the date, the tones and the minutes', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      harness.app(cell(minutes: {Tone.focus: 180, Tone.life: 60})),
    );

    expect(
      tester.getSemantics(find.byType(DayCell)),
      matchesSemantics(
        label: 'Wednesday 7 October, Focus 3 hours and Life 1 hour planned',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('says today, and says nothing about tones on an empty day', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(harness.app(cell(isToday: true)));

    expect(
      tester.getSemantics(find.byType(DayCell)),
      matchesSemantics(
        label: 'Wednesday 7 October, today',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('keeps its size at the largest text size', (tester) async {
    await tester.pumpWidget(
      harness.app(cell(isToday: true, size: 44), textScale: 3.12),
    );

    expect(tester.getSize(find.byType(DayCell)), const Size(44, 44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('is the size it is given, at least 40 points', (tester) async {
    await tester.pumpWidget(harness.app(cell(size: 40)));
    expect(tester.getSize(find.byType(DayCell)), const Size(40, 40));
  });
}
```

**Create `test/features/calendar/day_cell_golden_test.dart`**

```dart
// Golden images of the Calendar's day cell: an empty day, one tone, two tones,
// three tones, a sliver of one tone, today, and a past day, in light and dark.
// `test/flutter_test_config.dart` loads Nunito, so the numbers are real text.
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/calendar/widgets/day_cell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const goldenKey = ValueKey('day-cells-golden');

Widget cells(ThemeData theme) {
  Widget cell(
    int day,
    Map<Tone, int> minutes, {
    bool isToday = false,
    bool isPast = false,
    double size = 56,
  }) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: DayCell(
        day: DateTime(2026, 10, day),
        size: size,
        minutes: minutes,
        isToday: isToday,
        isPast: isPast,
        onTap: () {},
      ),
    );
  }

  return MaterialApp(
    theme: theme,
    debugShowCheckedModeBanner: false,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: Scaffold(
      body: Center(
        child: RepaintBoundary(
          key: goldenKey,
          child: ColoredBox(
            color: theme.scaffoldBackgroundColor,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Wrap(
                  spacing: 2,
                  runSpacing: 2,
                  children: [
                    cell(1, const {}, isPast: true),
                    cell(2, const {Tone.focus: 180}, isPast: true),
                    cell(3, const {
                      Tone.life: 120,
                      Tone.inbox: 60,
                    }, isPast: true),
                    cell(4, const {
                      Tone.focus: 240,
                      Tone.life: 90,
                      Tone.inbox: 60,
                    }),
                    cell(5, const {Tone.focus: 600, Tone.life: 5}),
                    cell(7, const {
                      Tone.focus: 180,
                      Tone.life: 60,
                      Tone.inbox: 90,
                    }, isToday: true),
                    cell(8, const {}),
                    cell(9, const {Tone.inbox: 45}, size: 44),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('day cells, light', (tester) async {
    tester.view.physicalSize = const Size(340, 260);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(cells(AppTheme.light));
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byKey(goldenKey),
      matchesGoldenFile('goldens/day_cells_light.png'),
    );
  });

  testWidgets('day cells, dark', (tester) async {
    tester.view.physicalSize = const Size(340, 260);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(cells(AppTheme.dark));
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byKey(goldenKey),
      matchesGoldenFile('goldens/day_cells_dark.png'),
    );
  });
}
```

- [ ] **Step 2: Run the tests to see them fail**

```bash
# expect: FAIL — ring_segments.dart and day_cell.dart do not exist yet
flutter test test/features/calendar
```

- [ ] **Step 3: Write the code**

**Create `lib/features/calendar/model/ring_segments.dart`**

```dart
import 'dart:math' as math;

import 'package:energy_clock/core/tone.dart';

/// One tone's arc of a day ring. Angles are in radians, clockwise, measured
/// from the positive x axis as Flutter's canvas does, so a ring that starts at
/// the top starts at -pi/2.
class RingSegment {
  const RingSegment(this.tone, this.startAngle, this.sweepAngle);

  final Tone tone;
  final double startAngle;
  final double sweepAngle;

  @override
  bool operator ==(Object other) =>
      other is RingSegment &&
      other.tone == tone &&
      other.startAngle == startAngle &&
      other.sweepAngle == sweepAngle;

  @override
  int get hashCode => Object.hash(tone, startAngle, sweepAngle);

  @override
  String toString() => 'RingSegment($tone, $startAngle, $sweepAngle)';
}

/// Splits a full circle between the tones in proportion to [minutes], in the
/// fixed tone order, starting at the top. Tones with no minutes are left out,
/// and a day with none at all has no segments.
///
/// One tone alone is a full circle. Otherwise each arc is followed by a [gap]
/// (radians) so neighbours never touch, and an arc is never shorter than
/// [minSweep], so a sliver of one tone is still visible; the arcs are scaled
/// so that arcs and gaps together fill the circle exactly.
List<RingSegment> ringSegments(
  Map<Tone, int> minutes, {
  double gap = 0.2,
  double minSweep = 0.25,
}) {
  const full = 2 * math.pi;
  const top = -math.pi / 2;

  final present = [
    for (final tone in Tone.values)
      if ((minutes[tone] ?? 0) > 0) tone,
  ];
  if (present.isEmpty) return const [];
  if (present.length == 1) return [RingSegment(present.single, top, full)];

  final total = present.fold<int>(0, (sum, tone) => sum + minutes[tone]!);
  final room = full - present.length * gap;
  final raw = [
    for (final tone in present)
      math.max(minSweep, room * minutes[tone]! / total),
  ];
  final scale = room / raw.fold<double>(0, (sum, sweep) => sum + sweep);

  final segments = <RingSegment>[];
  var angle = top + gap / 2;
  for (var i = 0; i < present.length; i++) {
    final sweep = raw[i] * scale;
    segments.add(RingSegment(present[i], angle, sweep));
    angle += sweep + gap;
  }
  return segments;
}
```

**Create `lib/features/calendar/widgets/day_ring_painter.dart`**

```dart
import 'dart:math' as math;

import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/calendar/model/ring_segments.dart';
import 'package:flutter/rendering.dart';

/// Paints one day's tone ring: a thin rounded arc per tone in its colour, or a
/// faint full circle in [emptyColor] when the day has no events.
class DayRingPainter extends CustomPainter {
  const DayRingPainter({
    required this.segments,
    required this.colors,
    required this.emptyColor,
    required this.strokeWidth,
  });

  final List<RingSegment> segments;

  /// The colour of each tone's arc.
  final Map<Tone, Color> colors;
  final Color emptyColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final center = size.center(Offset.zero);

    if (segments.isEmpty) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, strokeWidth / 2)
          ..color = emptyColor,
      );
      return;
    }

    final rect = Rect.fromCircle(center: center, radius: radius);
    for (final segment in segments) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = colors[segment.tone]!;
      canvas.drawArc(
        rect,
        segment.startAngle,
        segment.sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(DayRingPainter oldDelegate) =>
      oldDelegate.emptyColor != emptyColor ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.segments.length != segments.length ||
      !_sameSegments(oldDelegate.segments) ||
      !_sameColors(oldDelegate.colors);

  bool _sameSegments(List<RingSegment> other) {
    for (var i = 0; i < segments.length; i++) {
      if (other[i] != segments[i]) return false;
    }
    return true;
  }

  bool _sameColors(Map<Tone, Color> other) {
    for (final tone in Tone.values) {
      if (other[tone] != colors[tone]) return false;
    }
    return true;
  }
}
```

**Create `lib/features/calendar/widgets/day_cell.dart`**

```dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/repositories/calendar_repository.dart';
import 'package:energy_clock/features/calendar/model/ring_segments.dart';
import 'package:energy_clock/features/calendar/widgets/day_ring_painter.dart';
import 'package:energy_clock/shared/widgets/press_scale.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// One day of the month grid: a ring showing the day's tone balance with the
/// day number inside (spec §7). Today is a filled ink disc, past days have a
/// muted number, and the whole cell is one button.
class DayCell extends StatelessWidget {
  const DayCell({
    required this.day,
    required this.size,
    required this.minutes,
    required this.isToday,
    required this.isPast,
    required this.onTap,
    super.key,
  });

  final DateTime day;

  /// The cell is a square of this side.
  final double size;

  /// The day's planned minutes per tone; empty for a day with no events.
  final ToneMinutes minutes;

  final bool isToday;
  final bool isPast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final toneColors = context.toneColors;
    final theme = Theme.of(context);

    final stroke = (size * 0.1).clamp(3.0, 6.0);
    final radius = (size - stroke) / 2;
    // The gap must be wider than the two rounded ends that meet in it.
    final gap = stroke / radius + 0.14;
    final inner = size - 2 * (stroke + 3);

    final ordered = [
      for (final tone in Tone.values)
        if ((minutes[tone] ?? 0) > 0) tone,
    ];
    final label = Strings.weekDaySemantics(
      DateFormat('EEEE d MMMM').format(day),
      tones: Strings.joinWords([
        for (final tone in ordered)
          '${tone.label} ${spokenDurationMinutes(minutes[tone]!)}',
      ]),
      isToday: isToday,
    );

    final numberColor = isToday
        ? colors.onInk
        : (isPast ? colors.muted : colors.ink);

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        onTap: onTap,
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(size),
                painter: DayRingPainter(
                  segments: ringSegments(minutes, gap: gap),
                  colors: {
                    for (final tone in Tone.values)
                      tone: toneColors.fillFor(tone),
                  },
                  emptyColor: colors.outline,
                  strokeWidth: stroke,
                ),
              ),
              if (isToday)
                DecoratedBox(
                  key: const ValueKey('day-cell-today-disc'),
                  decoration: BoxDecoration(
                    color: colors.ink,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(dimension: inner),
                ),
              SizedBox.square(
                dimension: inner,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${day.day}',
                      style: theme.textTheme.labelLarge!.copyWith(
                        fontSize: (size * 0.3).clamp(13.0, 20.0),
                        color: numberColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the tests, the analyzer and the whole suite**

```bash
# expect: PASS — 19 new tests (the two golden tests have no images until Step 5); analyzer clean
flutter test test/features/calendar/ring_segments_test.dart test/features/calendar/day_cell_test.dart && flutter analyze
```

- [ ] **Step 5: Create the day cell goldens and look at them**

```bash
# expect: RUN — writes day_cells_light.png and day_cells_dark.png
flutter test --update-goldens test/features/calendar/day_cell_golden_test.dart
rm -rf test/features/calendar/failures
ls test/features/calendar/goldens
```

Open both images and check: an empty day is a faint thin circle; one tone is a full ring; two and three tones are arcs in purple, green and orange with clear gaps between them and rounded ends; the 5-minute Life sliver next to 600 minutes of Focus is still visible; today is a dark disc with a light number; past days have a grey number; nothing is clipped. If the gaps look uneven or an arc is invisible, adjust `gap` / `minSweep` in `ringSegments` or the painter before committing.

- [ ] **Step 6: Run the whole suite**

```bash
# expect: PASS — the whole suite stays green
flutter analyze && flutter test
```

- [ ] **Step 7: Commit**

```bash
git add lib test
git commit -m "feat: calendar day cell with a tone-balance ring

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---
### Task 18: One month: the header, the grid and the legend

The Calendar's visible parts, before any paging. A **month header** (the month and year, previous and next buttons, and a Today pill when you are looking at another month) and a **month page**: the weekday labels and the weeks of day cells in a card, a one-line legend naming the three tones (colour only ever means a tone, so the rings need a key) with how much of each the month holds, and, for a month with nothing planned, a short invitation.

- Weeks start on **Monday** (the app's weeks do until the first-day-of-week setting exists in Step 5); days outside the month are blank.
- `CalendarLayout` sizes the cells from the window: seven columns across the card, between 36 and 76 pt, never wider than 640 pt, and smaller if the height needs it. On the narrowest window (320 pt) the card's padding shrinks so the cells stay about 40 pt.
- The page scrolls vertically if a very short window or a huge text size cannot fit it; nothing on it competes with that gesture.
- Weekday labels and the header's small buttons stop growing at 130% text, as the Clock's pills do.
- A month page reads its data from `monthLoadProvider`, which watches `CalendarRepository.watchMonth` (Task 8): it fills the month from its recurring series first, so repeating events show on every day they cover.

**Files:**
- Create: `lib/features/calendar/calendar_layout.dart`, `lib/features/calendar/providers.dart`, `lib/features/calendar/widgets/month_header.dart`, `lib/features/calendar/widgets/month_page.dart`
- Modify: `lib/core/strings.dart`, `lib/shared/layout/content_width.dart`
- Test: `test/features/calendar/calendar_layout_test.dart`, `test/features/calendar/month_header_test.dart`, `test/features/calendar/month_page_test.dart`

**Interfaces:**
- Consumes: `DayCell` (Task 17); `monthWeeks`, `startOfMonth` (Task 2); `calendarRepositoryProvider` and `ToneMinutes` (Task 8).
- Produces: `CalendarLayout({cellSize, cardPadding})` with `cardWidth` and `CalendarLayout.forArea(Size area, {double textScale = 1})`; `monthLoadProvider` (`StreamProvider.family<Map<DateTime, ToneMinutes>, DateTime>`, keyed by the first of the month); `MonthHeader({required month, required isCurrentMonth, required onPrevious, required onNext, required onToday})`; `MonthPage({required month, required today, required onOpenDay})`; `ContentWidths.calendar` (640); strings `previousMonth`, `nextMonth`, `calendarEmptyMonth`.

- [ ] **Step 1: Write the failing tests**

**Create `test/features/calendar/calendar_layout_test.dart`**

```dart
import 'package:energy_clock/features/calendar/calendar_layout.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a phone is limited by its width: seven cells across the card', () {
    final layout = CalendarLayout.forArea(const Size(402, 900));

    expect(layout.cardPadding, 12);
    // (402 - 2 * 16 margin - 2 * 12 padding) / 7.
    expect(layout.cellSize, closeTo(346 / 7, 1e-9));
    expect(layout.cardWidth, closeTo(7 * layout.cellSize + 24, 1e-9));
  });

  test(
    'the narrowest window shrinks the card padding to keep cells near 40',
    () {
      final layout = CalendarLayout.forArea(const Size(320, 900));

      expect(layout.cardPadding, 4);
      expect(layout.cellSize, closeTo(40, 1e-9));
      expect(layout.cardWidth, lessThanOrEqualTo(320 - 32));
    },
  );

  test('a wide window stops at the largest cell and the content width', () {
    final layout = CalendarLayout.forArea(const Size(1194, 1000));

    expect(layout.cellSize, CalendarLayout.maxCell);
    expect(layout.cardWidth, lessThanOrEqualTo(640));
  });

  test('a short window makes the cells smaller, but not under the minimum', () {
    final roomy = CalendarLayout.forArea(const Size(402, 900));
    final tight = CalendarLayout.forArea(const Size(402, 400));
    final tiny = CalendarLayout.forArea(const Size(402, 200));

    expect(tight.cellSize, lessThan(roomy.cellSize));
    expect(tiny.cellSize, CalendarLayout.minCell);
  });

  test('larger text asks for more room, so the cells never grow with it', () {
    final normal = CalendarLayout.forArea(const Size(834, 560));
    final large = CalendarLayout.forArea(const Size(834, 560), textScale: 1.3);

    expect(large.cellSize, lessThanOrEqualTo(normal.cellSize));
  });

  test('text above 130% asks for no more room than 130%', () {
    final capped = CalendarLayout.forArea(const Size(834, 560), textScale: 1.3);
    final huge = CalendarLayout.forArea(const Size(834, 560), textScale: 3.12);

    expect(huge.cellSize, capped.cellSize);
  });

  test('the card always fits inside the window', () {
    for (final width in [320.0, 375.0, 402.0, 744.0, 834.0, 1194.0]) {
      final layout = CalendarLayout.forArea(Size(width, 700));
      expect(layout.cardWidth, lessThanOrEqualTo(width), reason: '$width');
    }
  });
}
```

**Create `test/features/calendar/month_header_test.dart`**

```dart
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/calendar/widgets/month_header.dart';
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

  Widget header({
    bool isCurrentMonth = true,
    VoidCallback? onPrevious,
    VoidCallback? onNext,
    VoidCallback? onToday,
  }) {
    return MonthHeader(
      month: DateTime(2026, 10),
      isCurrentMonth: isCurrentMonth,
      onPrevious: onPrevious ?? () {},
      onNext: onNext ?? () {},
      onToday: onToday ?? () {},
    );
  }

  testWidgets('shows the month and the year', (tester) async {
    await tester.pumpWidget(harness.app(header()));
    expect(find.text('October 2026'), findsOneWidget);
  });

  testWidgets('the title is a screen reader heading', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(harness.app(header()));

    expect(
      tester.getSemantics(find.text('October 2026')),
      matchesSemantics(label: 'October 2026', isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('the arrows call onPrevious and onNext', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      harness.app(
        header(
          onPrevious: () => calls.add('previous'),
          onNext: () => calls.add('next'),
        ),
      ),
    );

    await tester.tap(find.byTooltip(Strings.previousMonth));
    await tester.tap(find.byTooltip(Strings.nextMonth));

    expect(calls, ['previous', 'next']);
  });

  testWidgets('the Today pill shows only away from the current month', (
    tester,
  ) async {
    var today = 0;
    await tester.pumpWidget(harness.app(header()));
    expect(find.text(Strings.today), findsNothing);

    await tester.pumpWidget(
      harness.app(header(isCurrentMonth: false, onToday: () => today++)),
    );
    await tester.tap(find.text(Strings.today));

    expect(today, 1);
  });

  testWidgets('the arrows are at least 44 x 44', (tester) async {
    await tester.pumpWidget(harness.app(header()));

    for (final tooltip in [Strings.previousMonth, Strings.nextMonth]) {
      final size = tester.getSize(find.byTooltip(tooltip));
      expect(size.width, greaterThanOrEqualTo(44), reason: tooltip);
      expect(size.height, greaterThanOrEqualTo(44), reason: tooltip);
    }
  });

  for (final textScale in [1.0, 2.0, 3.12]) {
    testWidgets(
      'a long month name fits 320 pt at text ${(textScale * 100).toInt()}%',
      (tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          harness.app(
            MonthHeader(
              month: DateTime(2026, 9),
              isCurrentMonth: false,
              onPrevious: () {},
              onNext: () {},
              onToday: () {},
            ),
            textScale: textScale,
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );
  }
}
```

**Create `test/features/calendar/month_page_test.dart`**

```dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/calendar/widgets/day_cell.dart';
import 'package:energy_clock/features/calendar/widgets/month_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;

  // Wednesday 7 October 2026.
  final today = DateTime(2026, 10, 7);
  final october = DateTime(2026, 10);

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Finder cell(DateTime day) => find.byKey(
    ValueKey(
      'day-${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}',
    ),
  );

  Future<void> mount(
    WidgetTester tester, {
    DateTime? month,
    ValueChanged<DateTime>? onOpenDay,
    Size size = const Size(402, 800),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness.app(
        MonthPage(
          month: month ?? october,
          today: today,
          onOpenDay: onOpenDay ?? (_) {},
        ),
        textScale: textScale,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the weekday labels, Monday first', (tester) async {
    await mount(tester);

    final labels = [
      for (final name in Strings.weekdayShort)
        tester.getTopLeft(find.text(name)).dx,
    ];
    expect(labels, orderedEquals([...labels]..sort()));
    for (final name in Strings.weekdayShort) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('shows one cell per day of the month', (tester) async {
    await mount(tester);

    expect(find.byType(DayCell), findsNWidgets(31));
    expect(cell(DateTime(2026, 10, 1)), findsOneWidget);
    expect(cell(DateTime(2026, 10, 31)), findsOneWidget);
    expect(cell(DateTime(2026, 9, 30)), findsNothing);
    expect(cell(DateTime(2026, 11)), findsNothing);
  });

  testWidgets('lines the days up under their weekday', (tester) async {
    await mount(tester);

    double centerX(DateTime day) => tester.getCenter(cell(day)).dx;
    double labelX(String name) => tester.getCenter(find.text(name)).dx;

    // 1 October 2026 is a Thursday; the 5th a Monday; the 11th a Sunday.
    expect(centerX(DateTime(2026, 10, 1)), closeTo(labelX('Thu'), 1));
    expect(centerX(DateTime(2026, 10, 5)), closeTo(labelX('Mon'), 1));
    expect(centerX(DateTime(2026, 10, 11)), closeTo(labelX('Sun'), 1));
    // The 8th is one row below the 1st, in the same column.
    expect(
      centerX(DateTime(2026, 10, 8)),
      closeTo(centerX(DateTime(2026, 10, 1)), 1e-6),
    );
    expect(
      tester.getCenter(cell(DateTime(2026, 10, 8))).dy,
      greaterThan(tester.getCenter(cell(DateTime(2026, 10, 1))).dy),
    );
  });

  testWidgets('today has the disc and past days are muted', (tester) async {
    await mount(tester);
    final colors = tester.element(find.byType(MonthPage)).appColors;

    expect(
      find.descendant(
        of: cell(today),
        matching: find.byKey(const ValueKey('day-cell-today-disc')),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: cell(DateTime(2026, 10, 6)),
              matching: find.text('6'),
            ),
          )
          .style!
          .color,
      colors.muted,
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: cell(DateTime(2026, 10, 8)),
              matching: find.text('8'),
            ),
          )
          .style!
          .color,
      colors.ink,
    );
  });

  testWidgets('tapping a day opens it', (tester) async {
    final opened = <DateTime>[];
    await mount(tester, onOpenDay: opened.add);

    await tester.tap(cell(DateTime(2026, 10, 20)));
    await tester.tap(cell(DateTime(2026, 10, 2)));

    expect(opened, [DateTime(2026, 10, 20), DateTime(2026, 10, 2)]);
  });

  testWidgets('the rings show what is planned', (tester) async {
    final handle = tester.ensureSemantics();
    await harness.repository.createEvent(
      day: DateTime(2026, 10, 12),
      title: 'Deep work',
      tone: Tone.focus,
      range: const MinuteRange(540, 720),
    );
    await harness.repository.createEvent(
      day: DateTime(2026, 10, 12),
      title: 'Lunch walk',
      tone: Tone.life,
      range: const MinuteRange(750, 795),
    );
    await mount(tester);

    expect(
      tester.getSemantics(cell(DateTime(2026, 10, 12))).label,
      'Monday 12 October, Focus 3 hours and Life 45 minutes planned',
    );
    expect(
      tester.getSemantics(cell(DateTime(2026, 10, 13))).label,
      'Tuesday 13 October',
    );
    handle.dispose();
  });

  testWidgets('a new event appears on the grid', (tester) async {
    final handle = tester.ensureSemantics();
    await mount(tester);
    expect(
      tester.getSemantics(cell(DateTime(2026, 10, 14))).label,
      'Wednesday 14 October',
    );

    await harness.repository.createEvent(
      day: DateTime(2026, 10, 14),
      title: 'Walk',
      tone: Tone.life,
      range: const MinuteRange(600, 660),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(cell(DateTime(2026, 10, 14))).label,
      'Wednesday 14 October, Life 1 hour planned',
    );
    handle.dispose();
  });

  testWidgets('names the three tones in a legend', (tester) async {
    await mount(tester);

    for (final tone in Tone.values) {
      expect(find.text(tone.label), findsOneWidget);
    }
  });

  testWidgets('the legend says how much of each tone the month holds', (
    tester,
  ) async {
    for (final (day, tone, start, end) in [
      (12, Tone.focus, 540, 720),
      (13, Tone.focus, 540, 600),
      (14, Tone.life, 600, 645),
    ]) {
      await harness.repository.createEvent(
        day: DateTime(2026, 10, day),
        title: 'Event',
        tone: tone,
        range: MinuteRange(start, end),
      );
    }
    await mount(tester);

    expect(find.text('4h'), findsOneWidget);
    expect(find.text('45m'), findsOneWidget);
    // Inbox has nothing planned, so it shows only its name.
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('0m'), findsNothing);
  });

  testWidgets('invites the person to plan a month with nothing in it', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text(Strings.calendarEmptyMonth), findsOneWidget);

    await harness.repository.createEvent(
      day: DateTime(2026, 10, 14),
      title: 'Walk',
      tone: Tone.life,
      range: const MinuteRange(600, 660),
    );
    await tester.pumpAndSettle();

    expect(find.text(Strings.calendarEmptyMonth), findsNothing);
  });

  testWidgets('a month that needs six weeks lays out without overflow', (
    tester,
  ) async {
    // 1 August 2026 is a Saturday and August has 31 days: six rows.
    await mount(tester, month: DateTime(2026, 8));

    expect(find.byType(DayCell), findsNWidgets(31));
    expect(tester.takeException(), isNull);
  });

  testWidgets('other months show no today disc', (tester) async {
    await mount(tester, month: DateTime(2026, 11));

    expect(find.byKey(const ValueKey('day-cell-today-disc')), findsNothing);
    expect(find.byType(DayCell), findsNWidgets(30));
  });

  for (final (name, size) in const [
    ('iPhone SE', Size(375, 667)),
    ('iPhone 17 Pro', Size(402, 874)),
    ('narrow Split View', Size(320, 700)),
    ('iPad 11" portrait', Size(834, 1194)),
    ('iPad 11" landscape', Size(1194, 834)),
  ]) {
    for (final textScale in [1.0, 1.3, 2.0, 3.12]) {
      testWidgets('$name at text ${(textScale * 100).toInt()}% lays out', (
        tester,
      ) async {
        await mount(
          tester,
          month: DateTime(2026, 8),
          size: size,
          textScale: textScale,
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(DayCell), findsNWidgets(31));
        // Every cell is at least 36 points.
        final cellSize = tester.getSize(find.byType(DayCell).first);
        expect(cellSize.width, greaterThanOrEqualTo(36));
      });
    }
  }
}
```

- [ ] **Step 2: Run the tests to see them fail**

```bash
# expect: FAIL — calendar_layout.dart, month_header.dart, month_page.dart, the provider and the strings do not exist yet
flutter test test/features/calendar/calendar_layout_test.dart test/features/calendar/month_header_test.dart test/features/calendar/month_page_test.dart
```

- [ ] **Step 3: Write the code**

**Edit `lib/core/strings.dart`**

Replace:

```dart
  static const String applyFailed = "Couldn't apply the template.";
}
```

With:

```dart
  static const String applyFailed = "Couldn't apply the template.";

  // The Calendar.
  static const String previousMonth = 'Previous month';
  static const String nextMonth = 'Next month';
  static const String calendarEmptyMonth =
      'Nothing planned this month yet. Tap a day to plan it.';
}
```

**Edit `lib/shared/layout/content_width.dart`**

Replace:

```dart
  /// Modal sheets and dialogs.
  static const double sheet = 560;
```

With:

```dart
  /// The Calendar's month card.
  static const double calendar = 640;

  /// Modal sheets and dialogs.
  static const double sheet = 560;
```

**Create `lib/features/calendar/calendar_layout.dart`**

```dart
import 'dart:math' as math;

import 'package:energy_clock/shared/layout/content_width.dart';
import 'package:flutter/painting.dart';

/// How big the month grid is, from the room the window gives it.
///
/// Seven cells fill the card's width; the cells are at most [maxCell] pt and
/// the card at most [ContentWidths.calendar] wide. A short window makes the
/// cells smaller (down to [minCell]), after which the page scrolls. On the
/// narrowest windows the card's padding shrinks too, so the cells stay near
/// 40 pt.
class CalendarLayout {
  const CalendarLayout({required this.cellSize, required this.cardPadding});

  final double cellSize;
  final double cardPadding;

  /// The width of the card holding the grid.
  double get cardWidth => 7 * cellSize + 2 * cardPadding;

  static const double minCell = 36;
  static const double maxCell = 76;

  /// The space either side of the card.
  static const double pageMargin = 16;

  /// The gap between two weeks.
  static const double rowGap = 4;

  /// Height of the weekday labels and of the legend at normal text size.
  static const double weekdayRowHeight = 22;
  static const double legendHeight = 34;

  /// Text sizes above this ask for no more room than this.
  static const double _maxTextScale = 1.3;

  static CalendarLayout forArea(Size area, {double textScale = 1}) {
    final scale = textScale.clamp(1.0, _maxTextScale);
    final cardPadding = area.width < 360 ? 4.0 : 12.0;

    final usableWidth = math.min(
      area.width - 2 * pageMargin,
      ContentWidths.calendar,
    );
    final byWidth = (usableWidth - 2 * cardPadding) / 7;

    // Six weeks is the most a month needs; the rest of the page is chrome: the
    // weekday labels, the card's padding, the gaps between weeks, the legend
    // and the space around them.
    final chrome =
        weekdayRowHeight * scale +
        legendHeight * scale +
        2 * cardPadding +
        5 * rowGap +
        pageMargin * 2;
    final byHeight = (area.height - chrome) / 6;

    final cell = math.min(byWidth, byHeight).clamp(minCell, maxCell);
    return CalendarLayout(cellSize: cell.toDouble(), cardPadding: cardPadding);
  }
}
```

**Create `lib/features/calendar/providers.dart`**

```dart
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/calendar_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How each day of a month is planned, keyed by the first of the month. The
/// repository fills the month from its recurring series before reading it, so
/// repeating events show on every day they cover.
final monthLoadProvider =
    StreamProvider.family<Map<DateTime, ToneMinutes>, DateTime>((ref, month) {
      return ref.watch(calendarRepositoryProvider).watchMonth(month);
    });
```

**Create `lib/features/calendar/widgets/month_header.dart`**

```dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The Calendar's header: the month and year, a Today pill when another month
/// is showing, and previous and next buttons.
class MonthHeader extends StatelessWidget {
  const MonthHeader({
    required this.month,
    required this.isCurrentMonth,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    super.key,
  });

  /// The first of the month shown.
  final DateTime month;

  /// Whether [month] is the month of today; the Today pill is hidden then.
  final bool isCurrentMonth;

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  /// The pill's text stops growing here, as the Clock header's does.
  static const double _maxPillTextScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            // The month name is the one thing that must stay on one line, so
            // it shrinks rather than wraps at very large text sizes.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Semantics(
                header: true,
                child: Text(
                  DateFormat('MMMM y').format(month),
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ),
          ),
          if (!isCurrentMonth) ...[
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: _maxPillTextScale,
              child: TextButton(
                onPressed: onToday,
                style: TextButton.styleFrom(
                  foregroundColor: colors.ink,
                  backgroundColor: colors.ink.withValues(alpha: 0.08),
                  shape: const StadiumBorder(),
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                ),
                child: const Text(Strings.today),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          _ArrowButton(
            icon: CupertinoIcons.chevron_left,
            tooltip: Strings.previousMonth,
            onPressed: onPrevious,
          ),
          const SizedBox(width: AppSpacing.xs),
          _ArrowButton(
            icon: CupertinoIcons.chevron_right,
            tooltip: Strings.nextMonth,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: colors.ink.withValues(alpha: 0.08),
        foregroundColor: colors.ink,
        minimumSize: const Size(44, 44),
        shape: const CircleBorder(),
      ),
    );
  }
}
```

**Create `lib/features/calendar/widgets/month_page.dart`**

```dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/time/month_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/repositories/calendar_repository.dart';
import 'package:energy_clock/features/calendar/calendar_layout.dart';
import 'package:energy_clock/features/calendar/providers.dart';
import 'package:energy_clock/features/calendar/widgets/day_cell.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One month: the weekday labels and the weeks of day cells in a card, the
/// legend, and, for a month with nothing planned, a short invitation.
///
/// Weeks start on Monday; days outside the month are blank. The page scrolls
/// if a very short window or a huge text size cannot fit it.
class MonthPage extends ConsumerWidget {
  const MonthPage({
    required this.month,
    required this.today,
    required this.onOpenDay,
    super.key,
  });

  /// The first of the month shown.
  final DateTime month;

  /// Today, at local midnight.
  final DateTime today;

  final ValueChanged<DateTime> onOpenDay;

  static String _keyFor(DateTime day) =>
      'day-${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final load = ref.watch(monthLoadProvider(startOfMonth(month)));
    final planned = load.valueOrNull ?? const <DateTime, ToneMinutes>{};
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final theme = Theme.of(context);
    final toneColors = context.toneColors;
    final ink = context.appColors.ink;

    // How much of each tone the month holds.
    final totals = <Tone, int>{};
    for (final day in planned.values) {
      day.forEach((tone, minutes) {
        totals[tone] = (totals[tone] ?? 0) + minutes;
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = CalendarLayout.forArea(
          Size(constraints.maxWidth, constraints.maxHeight),
          textScale: textScale,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            CalendarLayout.pageMargin,
            AppSpacing.sm,
            CalendarLayout.pageMargin,
            AppSpacing.lg,
          ),
          child: Center(
            child: SizedBox(
              width: layout.cardWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppCard(
                    padding: EdgeInsets.all(layout.cardPadding),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MediaQuery.withClampedTextScaling(
                          maxScaleFactor: 1.3,
                          child: SizedBox(
                            height: CalendarLayout.weekdayRowHeight * 1.3,
                            child: Row(
                              children: [
                                for (final name in Strings.weekdayShort)
                                  SizedBox(
                                    width: layout.cellSize,
                                    child: Center(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          name,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        for (final week in monthWeeks(month)) ...[
                          const SizedBox(height: CalendarLayout.rowGap),
                          Row(
                            children: [
                              for (final day in week)
                                SizedBox.square(
                                  dimension: layout.cellSize,
                                  child: day == null
                                      ? null
                                      : DayCell(
                                          key: ValueKey(_keyFor(day)),
                                          day: day,
                                          size: layout.cellSize,
                                          minutes:
                                              planned[day] ??
                                              const <Tone, int>{},
                                          isToday: day == today,
                                          isPast: day.isBefore(today),
                                          onTap: () => onOpenDay(day),
                                        ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final tone in Tone.values)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: toneColors.fillFor(tone),
                                shape: BoxShape.circle,
                              ),
                              child: const SizedBox.square(dimension: 10),
                            ),
                            const SizedBox(width: AppSpacing.xs + 2),
                            Text(tone.label, style: theme.textTheme.bodySmall),
                            if ((totals[tone] ?? 0) > 0) ...[
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                formatDurationMinutes(totals[tone]!),
                                style: theme.textTheme.bodySmall!.copyWith(
                                  color: ink,
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                  if (load.hasValue && planned.isEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      Strings.calendarEmptyMonth,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run the tests, the analyzer and the whole suite**

```bash
# expect: PASS — 47 new tests; analyzer clean; the whole suite stays green
flutter test test/features/calendar/calendar_layout_test.dart test/features/calendar/month_header_test.dart test/features/calendar/month_page_test.dart && flutter analyze && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat: calendar month header, grid and legend

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---
### Task 19: The Calendar tab — swipe between months, tap a day to open it

Everything the Calendar needs now exists as parts; this task assembles the tab and removes the last "coming soon" placeholder for it.

- **`CalendarScreen`** replaces the placeholder: the month header over a `PageView` of month pages. Swiping left and right (or the arrows) moves between months; the Today pill returns to the current month. The page view is open-ended in both directions (it starts in the middle of 2,400 months, as the week strip does), and only the pages near the visible one are built. Under Reduce Motion a month change jumps instead of sliding.
- **`CalendarTab`** (app layer) composes it: it supplies today from the shared clock, so a tab left open across midnight moves its Today marker, and it is the only place that knows both features.
- **`TabScaffold`** handles "tap a day": it selects that date for the Clock tab and switches to it (spec §7: "Tapping a day opens the Clock tab focused on that date"). The Clock's own selected date is the only state involved, so a past day opens read-only and a future day editable, as everywhere else.

**Files:**
- Replace: `lib/features/calendar/calendar_screen.dart`, `lib/app/navigation/tab_scaffold.dart`
- Create: `lib/app/navigation/calendar_tab.dart`
- Modify: `test/app/tab_scaffold_test.dart`
- Test: `test/features/calendar/calendar_screen_test.dart`, `test/app/tab_scaffold_calendar_test.dart`

**Interfaces:**
- Consumes: `MonthHeader`, `MonthPage` (Task 18); `selectedDateProvider` and `clockProvider` from `lib/features/clock/providers.dart`; `TabBarInset`.
- Produces: `CalendarScreen({required DateTime today, required ValueChanged<DateTime> onOpenDay})`; `CalendarTab({required ValueChanged<DateTime> onOpenDay})`; `TabScaffold` as a `ConsumerStatefulWidget` that opens a tapped day on the Clock tab.

- [ ] **Step 1: Write the failing tests**

**Create `test/features/calendar/calendar_screen_test.dart`**

```dart
import 'package:energy_clock/app/navigation/tab_bar_inset.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/calendar/calendar_screen.dart';
import 'package:energy_clock/features/calendar/widgets/day_cell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;

  // Wednesday 7 October 2026.
  final today = DateTime(2026, 10, 7);

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Finder cell(int month, int day, {int year = 2026}) => find.byKey(
    ValueKey(
      'day-$year-${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}',
    ),
  );

  Widget screen({
    DateTime? today_,
    ValueChanged<DateTime>? onOpenDay,
    double inset = 0,
  }) {
    return TabBarInset(
      height: inset,
      child: CalendarScreen(
        today: today_ ?? today,
        onOpenDay: onOpenDay ?? (_) {},
      ),
    );
  }

  Future<void> mount(
    WidgetTester tester, {
    Widget? child,
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness.app(child ?? screen(), reduceMotion: reduceMotion),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the current month, with today marked', (tester) async {
    await mount(tester);

    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text(Strings.today), findsNothing);
    expect(
      find.descendant(
        of: cell(10, 7),
        matching: find.byKey(const ValueKey('day-cell-today-disc')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the next arrow shows the next month and the Today pill', (
    tester,
  ) async {
    await mount(tester);

    await tester.tap(find.byTooltip(Strings.nextMonth));
    await tester.pumpAndSettle();

    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text(Strings.today), findsOneWidget);
    expect(cell(11, 30), findsOneWidget);
    expect(cell(10, 7), findsNothing);
  });

  testWidgets('the previous arrow shows the month before', (tester) async {
    await mount(tester);

    await tester.tap(find.byTooltip(Strings.previousMonth));
    await tester.pumpAndSettle();

    expect(find.text('September 2026'), findsOneWidget);
    expect(cell(9, 30), findsOneWidget);
  });

  testWidgets('swiping moves between months', (tester) async {
    await mount(tester);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text(Strings.today), findsNothing);
  });

  testWidgets('the Today pill comes back to the current month', (tester) async {
    await mount(tester);
    for (var i = 0; i < 14; i++) {
      await tester.tap(find.byTooltip(Strings.nextMonth));
      await tester.pumpAndSettle();
    }
    expect(find.text('December 2027'), findsOneWidget);

    await tester.tap(find.text(Strings.today));
    await tester.pumpAndSettle();

    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text(Strings.today), findsNothing);
  });

  testWidgets('it can go back as well as forward, across a year end', (
    tester,
  ) async {
    await mount(tester);
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byTooltip(Strings.previousMonth));
      await tester.pumpAndSettle();
    }
    expect(find.text('December 2025'), findsOneWidget);
  });

  testWidgets('tapping a day opens it', (tester) async {
    final opened = <DateTime>[];
    await mount(tester, child: screen(onOpenDay: opened.add));

    await tester.tap(cell(10, 20));
    await tester.tap(find.byTooltip(Strings.nextMonth));
    await tester.pumpAndSettle();
    await tester.tap(cell(11, 3));

    expect(opened, [DateTime(2026, 10, 20), DateTime(2026, 11, 3)]);
  });

  testWidgets('each month shows its own plans', (tester) async {
    final handle = tester.ensureSemantics();
    await harness.repository.createEvent(
      day: DateTime(2026, 11, 3),
      title: 'Planning',
      tone: Tone.focus,
      range: const MinuteRange(540, 600),
    );
    await mount(tester);
    expect(find.text(Strings.calendarEmptyMonth), findsOneWidget);

    await tester.tap(find.byTooltip(Strings.nextMonth));
    await tester.pumpAndSettle();

    expect(find.text(Strings.calendarEmptyMonth), findsNothing);
    expect(
      tester.getSemantics(cell(11, 3)).label,
      'Tuesday 3 November, Focus 1 hour planned',
    );
    handle.dispose();
  });

  testWidgets('under Reduce Motion a month change jumps at once', (
    tester,
  ) async {
    await mount(tester, reduceMotion: true);

    await tester.tap(find.byTooltip(Strings.nextMonth));
    await tester.pump();

    expect(find.text('November 2026'), findsOneWidget);
  });

  testWidgets('when the month rolls over, the old one gets a Today pill', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text(Strings.today), findsNothing);

    // Midnight passes on 31 October: today is now 1 November.
    await tester.pumpWidget(harness.app(screen(today_: DateTime(2026, 11, 1))));
    await tester.pumpAndSettle();

    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text(Strings.today), findsOneWidget);

    await tester.tap(find.text(Strings.today));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
  });

  testWidgets('leaves room for the floating tab bar', (tester) async {
    await mount(tester, child: screen(inset: 84));

    final legendBottom = tester.getBottomLeft(find.text(Tone.inbox.label)).dy;
    expect(legendBottom, lessThanOrEqualTo(874 - 84));
    expect(find.byType(DayCell), findsNWidgets(31));
  });
}
```

**Create `test/app/tab_scaffold_calendar_test.dart`**

```dart
import 'package:energy_clock/app/navigation/app_tab_bar.dart';
import 'package:energy_clock/app/navigation/tab_scaffold.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/calendar/calendar_screen.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/clock_harness.dart';
import '../support/dial_pump.dart';

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness(); // Wednesday 7 October 2026
  });

  tearDown(() {
    harness.dispose();
  });

  // Reduced motion stops the empty Clock day's pulsing hint, which stays alive
  // under the Calendar tab, so the tests can settle.
  Widget app() => harness.app(const TabScaffold(), reduceMotion: true);

  int selectedTab(WidgetTester tester) =>
      tester.widget<AppTabBar>(find.byType(AppTabBar)).selectedIndex;

  testWidgets('the Calendar tab shows the month, not a placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await pumpDial(tester);

    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await pumpDial(tester);

    expect(find.byType(CalendarScreen), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text(Strings.comingSoon(Strings.tabCalendar)), findsNothing);
  });

  testWidgets('tapping a day opens it on the Clock tab', (tester) async {
    await tester.pumpWidget(app());
    await pumpDial(tester);
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await pumpDial(tester);

    await tester.tap(find.byKey(const ValueKey('day-2026-10-20')));
    await pumpDial(tester);

    expect(selectedTab(tester), 0);
    expect(
      harness.container.read(selectedDateProvider),
      DateTime(2026, 10, 20),
    );
    expect(find.text('Tuesday'), findsOneWidget);
    expect(find.text('20 October 2026'), findsOneWidget);
  });

  testWidgets('a past day opens read-only', (tester) async {
    await tester.pumpWidget(app());
    await pumpDial(tester);
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await pumpDial(tester);

    await tester.tap(find.byKey(const ValueKey('day-2026-10-02')));
    await pumpDial(tester);

    expect(selectedTab(tester), 0);
    expect(find.text(Strings.readOnlyChip), findsWidgets);
  });

  testWidgets('going back to the Calendar keeps the month it was on', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await pumpDial(tester);
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await pumpDial(tester);
    await tester.tap(find.byTooltip(Strings.nextMonth));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tab-0')));
    await pumpDial(tester);
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await pumpDial(tester);

    expect(find.text('November 2026'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the tests to see them fail**

```bash
# expect: FAIL — CalendarScreen has no today/onOpenDay parameters yet, and the Calendar tab is still a placeholder
flutter test test/features/calendar/calendar_screen_test.dart test/app/tab_scaffold_calendar_test.dart
```

- [ ] **Step 3: Write the code**

**Replace `lib/features/calendar/calendar_screen.dart`**

```dart
import 'dart:async';

import 'package:energy_clock/app/navigation/tab_bar_inset.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/time/month_time.dart';
import 'package:energy_clock/features/calendar/widgets/month_header.dart';
import 'package:energy_clock/features/calendar/widgets/month_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Calendar tab: the month header over a page view of months. Swipe or use
/// the arrows to move between months; the Today pill returns to the current
/// one. Tapping a day calls [onOpenDay] (spec §7).
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({
    required this.today,
    required this.onOpenDay,
    super.key,
  });

  /// Today at local midnight. It comes from the shared clock, so a tab left
  /// open across midnight moves its Today marker.
  final DateTime today;

  final ValueChanged<DateTime> onOpenDay;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  /// The page view is open-ended both ways. This page shows [_anchorMonth],
  /// the month that was current when the screen was built.
  static const int _centerPage = 1200;

  late final DateTime _anchorMonth;
  late final PageController _controller;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _anchorMonth = startOfMonth(widget.today);
    _visibleMonth = _anchorMonth;
    _controller = PageController(initialPage: _centerPage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DateTime _monthForPage(int page) =>
      addMonths(_anchorMonth, page - _centerPage);

  int _pageForMonth(DateTime month) =>
      _centerPage + monthsBetween(_anchorMonth, month);

  void _goToPage(int page) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(page);
    } else {
      unawaited(
        _controller.animateToPage(
          page,
          duration: AppMotion.base,
          curve: AppMotion.standard,
        ),
      );
    }
  }

  void _step(int delta) =>
      _goToPage((_controller.page ?? _centerPage).round() + delta);

  @override
  Widget build(BuildContext context) {
    final currentMonth = startOfMonth(widget.today);

    return Padding(
      padding: EdgeInsets.only(bottom: TabBarInset.of(context)),
      child: Column(
        children: [
          MonthHeader(
            month: _visibleMonth,
            isCurrentMonth: _visibleMonth == currentMonth,
            onPrevious: () => _step(-1),
            onNext: () => _step(1),
            onToday: () => _goToPage(_pageForMonth(currentMonth)),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (page) =>
                  setState(() => _visibleMonth = _monthForPage(page)),
              itemBuilder: (context, page) => MonthPage(
                month: _monthForPage(page),
                today: widget.today,
                onOpenDay: widget.onOpenDay,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

**Create `lib/app/navigation/calendar_tab.dart`**

```dart
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/features/calendar/calendar_screen.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Calendar tab. It lives in the app layer because it uses the shared
/// clock, which the Clock feature owns, and one feature may not import
/// another.
class CalendarTab extends ConsumerWidget {
  const CalendarTab({required this.onOpenDay, super.key});

  /// Called with the day the person tapped.
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CalendarScreen(
      today: startOfDay(ref.watch(clockProvider)),
      onOpenDay: onOpenDay,
    );
  }
}
```

**Replace `lib/app/navigation/tab_scaffold.dart`**

```dart
import 'package:energy_clock/app/navigation/app_tab_bar.dart';
import 'package:energy_clock/app/navigation/calendar_tab.dart';
import 'package:energy_clock/app/navigation/clock_tab.dart';
import 'package:energy_clock/app/navigation/tab_bar_inset.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/progress/profile_screen.dart';
import 'package:energy_clock/features/stats/stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hosts the four tabs behind a floating bar. Each tab is built the first time
/// it is selected and then kept alive, so switching back keeps its state.
class TabScaffold extends ConsumerStatefulWidget {
  const TabScaffold({super.key});

  @override
  ConsumerState<TabScaffold> createState() => _TabScaffoldState();
}

class _TabScaffoldState extends ConsumerState<TabScaffold> {
  int _index = 0;
  final Set<int> _visited = {0};

  Widget _screen(int index) => switch (index) {
    0 => const ClockTab(),
    1 => CalendarTab(onOpenDay: _openDay),
    2 => const StatsScreen(),
    _ => const ProfileScreen(),
  };

  void _select(int index) {
    setState(() {
      _index = index;
      _visited.add(index);
    });
  }

  /// A day was tapped in the Calendar: show it on the Clock tab. The Clock's
  /// selected date is the only state involved, so a past day opens read-only
  /// and a future day editable, as everywhere else.
  void _openDay(DateTime day) {
    ref.read(selectedDateProvider.notifier).select(day);
    _select(0);
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final inset =
        AppTabBar.height + AppTabBar.bottomMargin + bottomSafe + AppSpacing.sm;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: TabBarInset(
                height: inset,
                child: IndexedStack(
                  index: _index,
                  children: [
                    for (var i = 0; i < AppTabBar.tabCount; i++)
                      _visited.contains(i)
                          ? _screen(i)
                          : const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomSafe + AppTabBar.bottomMargin,
            child: AppTabBar(selectedIndex: _index, onSelected: _select),
          ),
        ],
      ),
    );
  }
}
```

**Edit `test/app/tab_scaffold_test.dart`**

The scaffold's own test builds its overrides by hand, so it needs the calendar fake now that the Calendar tab reads data, and the "tabs are built the first time they are visited" test asks for the real screen instead of the placeholder.

Replace:

```dart
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/clock/clock_screen.dart';
```

With:

```dart
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/calendar/calendar_screen.dart';
import 'package:energy_clock/features/clock/clock_screen.dart';
```

Replace:

```dart
import '../support/dial_pump.dart';
import '../support/fake_event_repository.dart';
```

With:

```dart
import '../support/dial_pump.dart';
import '../support/fake_calendar_repository.dart';
import '../support/fake_event_repository.dart';
```

Replace:

```dart
        eventRepositoryProvider.overrideWithValue(repository),
        sessionRepositoryProvider.overrideWithValue(sessions),
```

With:

```dart
        eventRepositoryProvider.overrideWithValue(repository),
        calendarRepositoryProvider.overrideWithValue(
          FakeCalendarRepository(repository),
        ),
        sessionRepositoryProvider.overrideWithValue(sessions),
```

Replace:

```dart
    expect(find.text(Strings.comingSoon(Strings.tabStats)), findsNothing);
    expect(find.text(Strings.comingSoon(Strings.tabCalendar)), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await pumpDial(tester);
    expect(find.text(Strings.comingSoon(Strings.tabCalendar)), findsOneWidget);
```

With:

```dart
    expect(find.text(Strings.comingSoon(Strings.tabStats)), findsNothing);
    expect(find.byType(CalendarScreen), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await pumpDial(tester);
    expect(find.byType(CalendarScreen), findsOneWidget);
```

- [ ] **Step 4: Run the tests, the analyzer and the whole suite**

```bash
# expect: PASS — 15 new tests; analyzer clean; the tab scaffold tests and the whole suite stay green
flutter test test/features/calendar/calendar_screen_test.dart test/app/tab_scaffold_calendar_test.dart test/app/tab_scaffold_test.dart && flutter analyze && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat: calendar tab with month paging; a tapped day opens on the Clock

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---
### Task 20: The Calendar at every window size, and its goldens

Like the Clock and the session screen, the Calendar must work at every window the app can be given. This task adds no feature code; it pins the Calendar's layout with a matrix test and its look with golden images, then asks for the images to be looked at.

- **Layout matrix:** the eight window sizes of the Clock matrix (iPhone SE to the 13" iPad in both orientations, plus a 320 pt Split View), at 100%, 130%, 200% and 312% text, for a busy month, an empty month, and a six-week month. In every one: nothing overflows, every day cell is built and at least 36 pt wide, and the card sits inside the window. At 100% text, where nothing should need scrolling, the whole page also fits above the floating tab bar.
- **Goldens:** the Calendar tab on an iPhone in light and dark, with a month of mixed plans, today and past days; an iPhone with an empty month (the invitation); and an iPad in landscape.

**Files:**
- Test: `test/features/calendar/calendar_layout_matrix_test.dart`, `test/features/calendar/calendar_screen_golden_test.dart`, `test/features/calendar/goldens/calendar_iphone_light.png`, `calendar_iphone_dark.png`, `calendar_iphone_empty_light.png`, `calendar_ipad_landscape_light.png` (generated)

- [ ] **Step 1: Write the tests**

**Create `test/features/calendar/calendar_layout_matrix_test.dart`**

```dart
import 'package:energy_clock/app/navigation/tab_bar_inset.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/calendar/calendar_screen.dart';
import 'package:energy_clock/features/calendar/widgets/day_cell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

/// The window sizes the Calendar is tested at: the same as the Clock's.
const sizes = <String, Size>{
  'iPhone SE': Size(375, 667),
  'iPhone 17 Pro': Size(402, 874),
  'iPad mini portrait': Size(744, 1133),
  'iPad 11" portrait': Size(834, 1194),
  'iPad 11" landscape': Size(1194, 834),
  'iPad 13" portrait': Size(1032, 1376),
  'iPad 13" landscape': Size(1376, 1032),
  'narrow Split View': Size(320, 1000),
};

/// The tab bar's reserve on a phone with no home indicator.
const double shellInset = 84;

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness(); // Wednesday 7 October 2026
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> plan(DateTime day, Tone tone, int start, int minutes) =>
      harness.repository.createEvent(
        day: day,
        title: 'Event',
        tone: tone,
        range: MinuteRange(start, start + minutes),
      );

  /// A month with something on most days, in every combination of tones.
  Future<void> fillMonth(int month) async {
    for (var day = 1; day <= 28; day++) {
      final date = DateTime(2026, month, day);
      await plan(date, Tone.values[day % 3], 360, 30 + (day * 17) % 240);
      if (day.isEven) await plan(date, Tone.values[(day + 1) % 3], 720, 60);
      if (day % 5 == 0) await plan(date, Tone.values[(day + 2) % 3], 1000, 45);
    }
  }

  for (final entry in sizes.entries) {
    final size = entry.value;
    for (final textScale in const [1.0, 1.3, 2.0, 3.12]) {
      for (final (label, month, fill) in const [
        ('a busy month', 10, true),
        ('an empty month', 11, false),
        ('a six-week month', 8, true),
      ]) {
        testWidgets(
          '${entry.key} (${size.width.toInt()} x ${size.height.toInt()}), '
          'text ${(textScale * 100).toInt()}%, $label',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            if (fill) await fillMonth(month);

            // Open on the month under test, with today inside it.
            final today = DateTime(2026, month, 7);
            await tester.pumpWidget(
              harness.app(
                TabBarInset(
                  height: shellInset,
                  child: CalendarScreen(today: today, onOpenDay: (_) {}),
                ),
                textScale: textScale,
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);

            final cells = find.byType(DayCell);
            final days = DateUtils.getDaysInMonth(2026, month);
            expect(cells, findsNWidgets(days));
            expect(tester.getSize(cells.first).width, greaterThanOrEqualTo(36));

            // The card, and so every column, is inside the window.
            final first = tester.getTopLeft(find.byType(DayCell).first);
            final lastCell = find.byType(DayCell).last;
            final last = tester.getTopRight(lastCell);
            expect(first.dx, greaterThanOrEqualTo(0));
            expect(last.dx, lessThanOrEqualTo(size.width));

            // At normal text nothing should need scrolling: the legend and the
            // empty-month invitation end above the tab bar.
            if (textScale == 1.0) {
              final bottom = tester
                  .getBottomLeft(find.text(Tone.inbox.label))
                  .dy;
              expect(bottom, lessThanOrEqualTo(size.height - shellInset));
              if (!fill) {
                expect(
                  tester
                      .getBottomLeft(find.text(Strings.calendarEmptyMonth))
                      .dy,
                  lessThanOrEqualTo(size.height - shellInset),
                );
              }
            }
          },
        );
      }
    }
  }
}
```

**Create `test/features/calendar/calendar_screen_golden_test.dart`**

```dart
// Golden images of the Calendar tab, with the floating tab bar: an iPhone in
// light and dark with a month of mixed plans, an iPhone with an empty month,
// and an iPad in landscape. The clock is fixed at Wednesday 7 October 2026,
// 10:30, animations are off, and `test/flutter_test_config.dart` loads Nunito,
// so every image is deterministic and shows real text.
import 'package:energy_clock/app/navigation/tab_scaffold.dart';
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

const screenKey = ValueKey('calendar-screen-golden');

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  /// October 2026: a mix of one, two and three tones, a day of almost only
  /// one tone, and nothing at all on some days.
  Future<void> seedOctober() async {
    Future<void> plan(int day, List<(Tone, int)> blocks) async {
      var start = 360;
      for (final (tone, minutes) in blocks) {
        await harness.repository.createEvent(
          day: DateTime(2026, 10, day),
          title: 'Event',
          tone: tone,
          range: MinuteRange(start, start + minutes),
        );
        start += 240;
      }
    }

    await plan(1, [(Tone.focus, 180), (Tone.life, 60)]);
    await plan(2, [(Tone.inbox, 90)]);
    await plan(3, [(Tone.life, 120)]);
    await plan(5, [(Tone.focus, 240), (Tone.life, 90), (Tone.inbox, 60)]);
    await plan(6, [(Tone.focus, 120)]);
    await plan(7, [(Tone.focus, 180), (Tone.life, 60), (Tone.inbox, 90)]);
    await plan(8, [(Tone.inbox, 45), (Tone.life, 45)]);
    await plan(9, [(Tone.focus, 235), (Tone.life, 5)]);
    await plan(12, [(Tone.life, 60)]);
    await plan(13, [(Tone.focus, 120), (Tone.inbox, 60)]);
    await plan(14, [(Tone.focus, 60), (Tone.life, 60), (Tone.inbox, 60)]);
    await plan(15, [(Tone.focus, 200)]);
    await plan(19, [(Tone.inbox, 30), (Tone.life, 90)]);
    await plan(20, [(Tone.focus, 150), (Tone.inbox, 30)]);
    await plan(21, [(Tone.life, 45)]);
    await plan(26, [(Tone.focus, 90), (Tone.life, 30)]);
    await plan(28, [(Tone.inbox, 60)]);
    await plan(30, [(Tone.focus, 120), (Tone.life, 120), (Tone.inbox, 120)]);
  }

  Future<void> check(
    WidgetTester tester, {
    required Size size,
    required ThemeData theme,
    required String file,
    bool seeded = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (seeded) await seedOctober();

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
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(screenKey),
      matchesGoldenFile('goldens/$file'),
    );
  }

  testWidgets('iPhone 17 Pro, light', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.light,
      file: 'calendar_iphone_light.png',
    );
  });

  testWidgets('iPhone 17 Pro, dark', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.dark,
      file: 'calendar_iphone_dark.png',
    );
  });

  testWidgets('iPhone 17 Pro, an empty month, light', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.light,
      file: 'calendar_iphone_empty_light.png',
      seeded: false,
    );
  });

  testWidgets('iPad 11" landscape, light', (tester) async {
    await check(
      tester,
      size: const Size(1194, 834),
      theme: AppTheme.light,
      file: 'calendar_ipad_landscape_light.png',
    );
  });
}
```

- [ ] **Step 2: Run the matrix**

```bash
# expect: PASS — 96 matrix tests (8 sizes x 4 text sizes x 3 months)
flutter test test/features/calendar/calendar_layout_matrix_test.dart
```

If a case fails because the page needs more room than the window gives at 100% text, fix `CalendarLayout` (the chrome budget, or the cell range) rather than loosening the test.

- [ ] **Step 3: Create the goldens and look at them**

```bash
# expect: RUN — writes the four calendar_*.png images
flutter test --update-goldens test/features/calendar/calendar_screen_golden_test.dart
rm -rf test/features/calendar/failures
ls test/features/calendar/goldens | grep calendar_
```

Open the four images in `test/features/calendar/goldens/` and check:

- **iPhone, light and dark:** the title "October 2026" with the two arrows on the right and no Today pill; weekday labels; today (the 7th) is a dark disc with a light number; days 1–6 have grey numbers, later days ink-coloured numbers; rings are purple, green and orange with clear gaps, the 9th is almost all purple with a small green sliver, days with nothing are a faint grey circle; the legend (Focus, Life, Inbox, each with the month's total hours for that tone) sits under the card; nothing is clipped, and the card does not touch the tab bar.
- **Empty month:** all faint circles, and the invitation text under the legend.
- **iPad landscape:** the card is centred, with cells larger than on the phone; the header title stays at the left edge of the window.

If something is off (an uneven gap, a number that is hard to read, an arc colour that looks wrong in dark mode), fix `DayCell`, `MonthPage` or `CalendarLayout` and regenerate before continuing.

- [ ] **Step 4: Run the analyzer and the whole suite**

```bash
# expect: PASS — analyzer clean; the whole suite stays green
flutter analyze && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add test
git commit -m "test: calendar layout matrix and goldens

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---
## Stage 5 — Finish

### Task 21: README, format check, and the simulator walkthrough

The last task changes no behaviour. It brings the README up to date (it still says the Calendar is a placeholder, and does not mention the session timer from Step 2), confirms the code is formatted and the whole suite is green, and then does the one check no automated test can: running the app and looking at it. Memory of the earlier steps: looking at the golden images and at the simulator found bugs that every test had missed, so this step is not optional.

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update the README**

**Edit `README.md`**

Replace:

```markdown
It runs on iPhone (portrait) and iPad (all orientations). The dial planner, the week strip, the Now card and the event sheets are done; the Calendar, Stats and Profile tabs are still placeholders.
```

With:

```markdown
It runs on iPhone (portrait) and iPad (all orientations). The dial planner, the week strip, the Now card, the event sheets, the session timer, repeating events, day templates, Copy yesterday and the Calendar are done; the Stats and Profile tabs are still placeholders.
```

Replace:

```markdown
  features/     clock (calendar, stats and profile are placeholders)
```

With:

```markdown
  features/     clock, session, calendar (stats and profile are placeholders)
```

- [ ] **Step 2: Check the formatting, the analyzer and the whole suite**

The code in this plan is already formatted, so the format check must report no changes.

```bash
# expect: PASS — "Formatted ... (0 changed)", analyzer clean, every test passes
DART="$(dirname "$(which flutter)")/dart"
"$DART" format --output=none --set-exit-if-changed lib test
flutter analyze && flutter test
```

If `dart format` does report changes, run `"$DART" format lib test`, look at the diff to see what the plan's text had drifted from, and commit the result as `style: apply dart format`.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: describe the Calendar, repeating events and day templates

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 4: Walk through the app on the simulator**

```bash
# expect: MANUAL — a person or the controller runs the app and works through the list below
flutter run -d "iPhone 17 Pro"
```

Work through this list on **iPhone 17 Pro**, then repeat the parts marked ◆ on an **iPad** (portrait and landscape) and in a **narrow Split View**. Save screenshots of every numbered item to `build/review/step-3/` (git-ignored) and look at each one. Today in the app is whatever the simulator's date is, so the weekdays below are examples.

1. **Repeat.** On today, drag out an event, title it "Standup", choose **Weekdays**, save. Swipe the week strip forward: tone dots appear on the coming weekdays and not on Saturday or Sunday. ◆
2. **The detail sheet.** Open a later "Standup": the line "Weekdays" with the repeat icon shows under the duration.
3. **Edit one.** Open a later Standup, rename it "Standup (long)", Save, choose **This event**. Only that day changes; the next day is still "Standup".
4. **Edit this and all future.** Open a later Standup, change its time, Save, choose **This and all future events**. The days before it are unchanged and the days after it have the new time.
5. **Change the rule.** Open one, tap **Every day**, Save: the prompt offers only "This and all future events" and says why.
6. **Delete one, delete the rest.** Delete one Standup with **This event**; leave the app (swipe it away) and open it again: that day is still empty. Delete another with **This and all future events**: every later day is empty, earlier ones remain.
7. **Full day.** On a day with three overlapping events, try to add a fourth repeating event: the message "Up to three overlapping events." shows, and the sheet stays open.
8. **Save a template.** On a busy day tap ⋯, **Save as template**, name it "Workday". The snackbar confirms. ◆
9. **Copy yesterday.** Open an empty day after a busy one: the **Copy yesterday** and **Apply template** buttons sit under the Now card. Tap **Copy yesterday**: the events appear and the buttons go away. ◆
10. **Apply a template.** On another empty day tap **Apply template**, pick "Workday": the day fills. Open the picker again: delete the template with the trash button and confirm. ◆
11. **Calendar.** Open the Calendar tab: the month shows a ring on every day with events (purple, green and orange arcs with gaps), today as a dark disc, past days' numbers grey, and the legend with each tone's hours. Swipe to the next and previous months and use the arrows; the **Today** pill appears and returns. A month with no plans shows the invitation. The Standup days show a ring all the way to the end of the month. ◆
12. **Open a day.** Tap a day in the Calendar: the Clock tab opens on that date. Tap a past day: it shows **Read-only**; tap a future day: it is editable.
13. **Dark mode.** Repeat 11 in dark mode (Settings, Developer, or the simulator's Appearance menu): the rings keep their hues and the numbers stay readable. ◆
14. **Large text.** Settings, Accessibility, Display & Text Size, Larger Text, drag to the largest size: the Calendar, the repeat picker and the template picker stay usable and nothing is cut off. ◆
15. **VoiceOver, briefly.** Turn it on and swipe through the Calendar: a day is read as "Wednesday 7 October, Focus 3 hours and Life 1 hour planned, today"; the repeat pills are read as selected or not.

Fix anything that looks wrong at its source (and add a test that would have caught it) before calling the step done. Note that the iPad and Split View checks and VoiceOver need the simulator-control permission for those devices; if it is not granted, say so in the report instead of skipping silently.

---
