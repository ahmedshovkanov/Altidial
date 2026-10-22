# Energy Clock — Step 1A: Foundation, Dial v2, Clock Screen and Sheets — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the plain Clock tab with the bold design system: a dial that resizes with its overlapping rings, a week strip, a tone-coloured Now card, a day-load bar, and restyled event sheets. When this plan is done the app runs on iPhone and on medium-width windows with all tests green.

**Architecture:** Design tokens and theme extensions live in `lib/app/theme/`; shared widgets in `lib/shared/`; the Clock feature keeps its structure under `lib/features/clock/`. All polar math stays in the pure-Dart `DialGeometry`, which gains a ring count. Screen logic that can be pure (Now-card state, day load, layout rules) is written as pure functions with unit tests; widgets are thin renderers over Riverpod providers. A single `clockProvider` ticks once a minute and replaces the dial's private timer.

**Tech Stack:** Flutter 3.44.7, Dart 3.12.2, `flutter_riverpod` 2.6, `drift` + `drift_flutter`, `intl`, bundled Nunito font (static TTF assets). No new runtime packages.

**Spec:** `docs/superpowers/specs/2026-10-03-step-1-foundation-design.md`. This plan implements §§4, 6, 7, 8 (narrow and medium layouts), 9, 11 (except settings), 12 and the matching parts of §§13–14. Plan 1B (`docs/superpowers/plans/2026-10-04-step-1b-ipad-brand-onboarding.md`) implements the wide layout, iPad settings, brand assets, onboarding and the final checks, and must run after this plan.

## Global Constraints

These apply to every task. Copied from the spec and the Phase 1 plan.

- **Platform:** iOS 15+. iPhone in portrait; iPad in all four orientations with resizable windows (iPad specifics land in Plan 1B). Flutter 3.44.7 / Dart 3.12.2.
- **Language:** English-only. All user-facing copy lives in `lib/core/strings.dart`. No localisation framework.
- **Tones are fixed:** exactly three — Focus (purple), Life (green), Inbox (orange). Not addable, removable, renameable, or recolourable.
- **Colour only ever encodes a tone.** UI accent (buttons, selected tab) is near-black in light mode and near-white in dark mode, never purple.
- **No hard-coded colours in feature code.** Nothing under `lib/features/` may contain `Color(0x` or `Colors.`. Every colour comes from `context.appColors`, `context.toneColors`, `AppColors.transparent`, or `Theme.of(context).colorScheme`. Enforced by `test/architecture/no_hardcoded_colors_test.dart` (Task 9).
- **Boundary rule:** no file under `lib/features/<a>/` may import from `lib/features/<b>/`. `lib/app/` composes features and may import them. Cross-feature communication goes through repositories exposed as Riverpod providers.
- **Minute domain:** `startMinute` is 0–1439, `endMinute` is 1–1440 and exclusive, and never exceeds 1440. Cross-midnight events are not allowed.
- **Drag rules:** snap to 5-minute increments; minimum event duration 15 minutes; a drag past the end of day clamps at `endMinute` 1440.
- **Overlaps:** allowed, up to 3 rings. A fourth simultaneous event is refused with "Up to three overlapping events." Ring assignment is computed at render time, never stored.
- **Editability:** past days are read-only. Today and future days are editable.
- **Window classes:** narrow under 600 pt, medium 600–899 pt, wide 900 pt and up. Layout follows the app window width, not the device name.
- **Tap targets** are at least 44 pt. **Contrast:** text pairs at least 4.5:1, arcs against the face at least 3:1.
- **No new runtime packages.** No charting library, HTTP client, or analytics SDK.
- **Schema:** no schema change in this plan, so no migration.
- **Tooling:** run Dart commands with the Flutter SDK's `dart` (`"$(dirname "$(which flutter)")/dart"`). The first `dart` on this machine's PATH is 3.10 and fails on this project.
- **Style:** `flutter analyze` must stay clean; the repo follows `dart format` and the lints in `analysis_options.yaml` (single quotes, `unawaited_futures`, `prefer_final_locals`, `always_declare_return_types`).
- **Commit messages** use the repo's conventional prefixes (`feat:`, `fix:`, `test:`, `refactor:`, `docs:`, `chore:`) and end with a blank line and the trailer `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## How to read the steps

- **Create / Replace / Edit / Delete** blocks give the exact file change. A **Replace** block is the whole new file. An **Edit** block shows the exact text to find (`Replace:`) and what to put there (`With:`); the find text appears exactly once.
- A bash block whose first line is `# expect: PASS` must succeed; `# expect: FAIL` must fail for the stated reason; `# expect: RUN` and `# expect: UPDATE` are setup commands that must succeed.
- If a snippet does not compile against Flutter 3.44.7, fix the API usage minimally, keep the behaviour and the tests' intent, and say so in your report.

## File Structure

**Created:**

| File | Responsibility |
|---|---|
| `lib/data/providers.dart` | `appDatabaseProvider` (moved out of the Clock feature) |
| `lib/app/theme/tokens.dart` | `AppSpacing`, `AppRadii`, `AppMotion` |
| `lib/app/theme/app_colors.dart` | `AppColors` theme extension: page, surface, ink, muted, outline, danger, night tint, shadows |
| `lib/app/theme/app_typography.dart` | Nunito text styles and the Material `TextTheme` |
| `lib/shared/layout/window_class.dart` | `WindowClass`, `windowClassFor` |
| `lib/shared/layout/content_width.dart` | `ContentWidth`, `ContentWidths` |
| `lib/shared/widgets/press_scale.dart` | Press-in scale feedback |
| `lib/shared/widgets/app_card.dart` | `AppCard` |
| `lib/shared/widgets/tone_chip.dart` | `ToneChip` |
| `lib/shared/widgets/app_button.dart` | `AppButton` |
| `lib/shared/widgets/section_header.dart` | `SectionHeader` |
| `lib/shared/widgets/adaptive_dialog.dart` | `confirmDestructive` |
| `lib/shared/widgets/ring_mark.dart` | Three-arc ring painter shared by the tab icon, onboarding and brand assets |
| `lib/app/navigation/tab_bar_inset.dart` | Space the floating tab bar covers |
| `lib/app/navigation/tab_dial_icon.dart` | The Clock tab icon |
| `lib/app/navigation/app_tab_bar.dart` | The floating tab bar |
| `lib/features/clock/model/active_event.dart` | `activeEventsAt`: the one rule for which event is running |
| `lib/features/clock/model/now_status.dart` | `computeNowStatus` and its result types |
| `lib/features/clock/model/day_load.dart` | `computeDayLoad`, `segmentWidths` |
| `lib/features/clock/clock_layout.dart` | `ClockLayoutPlan` vertical-space rules |
| `lib/features/clock/widgets/clock_header.dart` | Day name, date, Today and + buttons |
| `lib/features/clock/widgets/week_strip.dart` | Seven day pills with tone dots |
| `lib/features/clock/widgets/now_card.dart` | The tone-coloured Now card |
| `lib/features/clock/widgets/day_load_bar.dart` | The tone-split day-load bar |
| `lib/features/clock/widgets/dial_semantics.dart` | VoiceOver nodes over the dial |
| `lib/features/clock/widgets/delete_event.dart` | Confirm-and-delete helper |
| `assets/fonts/Nunito-{Regular,SemiBold,Bold,ExtraBold}.ttf`, `assets/fonts/OFL.txt` | Bundled font and its licence |
| `test/flutter_test_config.dart` | Loads Nunito for every test (added in Task 14) |
| `test/support/contrast.dart`, `test/support/fake_clock.dart` | Test helpers |

**Modified:** `lib/core/strings.dart`, `lib/core/time/day_time.dart`, `lib/core/geometry/dial_geometry.dart`, `lib/app/theme/tone_colors.dart`, `lib/app/theme/app_theme.dart`, `lib/app/navigation/tab_scaffold.dart`, `lib/main.dart`, `pubspec.yaml`, `lib/data/daos/event_dao.dart`, `lib/features/clock/providers.dart`, `lib/features/clock/data/event_repository.dart`, `lib/features/clock/clock_screen.dart`, `lib/features/clock/widgets/dial_painter.dart`, `lib/features/clock/widgets/dial_view.dart`, `lib/features/clock/widgets/event_sheet.dart`, `lib/features/clock/widgets/event_detail_sheet.dart`, and the matching tests.

**Deleted:** `lib/features/clock/widgets/day_header.dart`, `test/features/clock/day_header_test.dart`.

---

## Stage 1 — Foundation

### Task 1: Move `appDatabaseProvider` into `lib/data/`

Onboarding (Plan 1B) and later steps need the database, and features must not import each other, so the provider moves to the data layer. `eventRepositoryProvider` stays where it is.

**Files:**
- Create: `lib/data/providers.dart`
- Replace: `lib/features/clock/providers.dart`
- Test: `test/data/providers_test.dart`

**Interfaces:**
- Produces: `appDatabaseProvider` (`Provider<AppDatabase>`) in `package:energy_clock/data/providers.dart`.
- Consumes: `AppDatabase` from `lib/data/database.dart`.

- [ ] **Step 1: Write the failing test**

**Create `test/data/providers_test.dart`**

```dart
import 'package:drift/native.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the event repository is built on the shared database provider', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    expect(container.read(appDatabaseProvider), same(database));
    expect(
      container.read(eventRepositoryProvider),
      isA<DriftEventRepository>(),
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
# expect: FAIL — "Target of URI doesn't exist: 'package:energy_clock/data/providers.dart'"
flutter test test/data/providers_test.dart
```

- [ ] **Step 3: Move the provider**

**Create `lib/data/providers.dart`**

```dart
import 'package:energy_clock/data/database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app's single database. It lives in the data layer so that any feature,
/// and the app layer, can read it without importing another feature.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});
```

**Replace `lib/features/clock/providers.dart`**

```dart
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return DriftEventRepository(ref.watch(appDatabaseProvider).eventDao);
});

/// The day the Clock tab is showing. Always local midnight.
class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => startOfDay(DateTime.now());

  void select(DateTime day) => state = startOfDay(day);
  void next() => state = nextDay(state);
  void previous() => state = previousDay(state);
  void today() => state = startOfDay(DateTime.now());
}

final selectedDateProvider = NotifierProvider<SelectedDateNotifier, DateTime>(
  SelectedDateNotifier.new,
);

final dayEventsProvider = StreamProvider<List<CalendarEvent>>((ref) {
  return ref
      .watch(eventRepositoryProvider)
      .watchDay(ref.watch(selectedDateProvider));
});
```

- [ ] **Step 4: Run the new test and the whole suite**

```bash
# expect: PASS
flutter test test/data/providers_test.dart && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib/data/providers.dart lib/features/clock/providers.dart test/data/providers_test.dart
git commit -m "refactor: move appDatabaseProvider into lib/data

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Copy and small helpers

All new user-facing copy for this plan, plus three pure helpers: a spoken duration for screen readers, and Monday-first week helpers. Defining the copy once here means later tasks only use it.

**Files:**
- Edit: `lib/core/strings.dart`
- Edit: `lib/core/time/day_time.dart`
- Test: `test/core/strings_test.dart`, `test/core/time/week_and_speech_test.dart`

**Interfaces:**
- Produces (in `Strings`): `tabSemantics`, `readOnlyChip`, `nowNextUp`, `nowDoneTitle`, `pastNothingPlanned`, `nowTimeLeft`, `nowUntil`, `nowStartsAt`, `nowOverlapping`, `eventCount`, `plannedSummary`, `plannedDuration`, `pastSummary`, `dayCountTitle`, `nowSemantics`, `nextSemantics`, `dayLoadSemantics`, `weekDaySemantics`, `dialSemanticsLabel`, `eventSemantics`, `planTitleToday`, `planTitleFor`, `joinWords`.
- Produces (in `day_time.dart`): `spokenDurationMinutes(int)`, `startOfWeek(DateTime)`, `daysOfWeek(DateTime)`.

- [ ] **Step 1: Write the failing tests**

**Create `test/core/strings_test.dart`**

```dart
import 'package:energy_clock/core/strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('joinWords reads naturally', () {
    expect(Strings.joinWords(const []), '');
    expect(Strings.joinWords(const ['Focus']), 'Focus');
    expect(Strings.joinWords(const ['Focus', 'Life']), 'Focus and Life');
    expect(
      Strings.joinWords(const ['Focus', 'Life', 'Inbox']),
      'Focus, Life and Inbox',
    );
  });

  test('event counts are pluralised', () {
    expect(Strings.eventCount(0), '0 events');
    expect(Strings.eventCount(1), '1 event');
    expect(Strings.eventCount(5), '5 events');
  });

  test('now-card copy', () {
    expect(Strings.nowTimeLeft('42m'), '42m left');
    expect(Strings.nowUntil('11:00'), 'until 11:00');
    expect(
      Strings.nowStartsAt('12:30', '40m'),
      'Starts at 12:30 · in 40m',
    );
    expect(Strings.nowOverlapping(2), '+2 overlapping');
    expect(Strings.plannedSummary(5, '6h 30m'), '5 events · 6h 30m planned');
    expect(Strings.plannedDuration('6h 30m'), '6h 30m planned');
    expect(Strings.pastSummary(1, '1h'), '1 event · 1h');
    expect(Strings.dayCountTitle('Tuesday', 5), 'Tuesday · 5 events');
  });

  test('screen-reader copy reads as one sentence', () {
    expect(
      Strings.eventSemantics(
        'Deep work',
        'Focus',
        '09:00',
        '11:00',
        '2 hours',
      ),
      'Deep work, Focus, 09:00 to 11:00, 2 hours',
    );
    expect(
      Strings.nowSemantics('Deep work', 'Focus', '42 minutes'),
      'Now: Deep work, Focus, 42 minutes left',
    );
    expect(
      Strings.nextSemantics('Lunch', 'Life', '40 minutes'),
      'Next up: Lunch, Life, starts in 40 minutes',
    );
    expect(
      Strings.dayLoadSemantics('Focus 4 hours, Life 2 hours'),
      'Planned load: Focus 4 hours, Life 2 hours',
    );
    expect(Strings.tabSemantics('Clock', 1, 4), 'Clock, tab 1 of 4');
  });

  test('week day semantics mention planned tones and today', () {
    expect(
      Strings.weekDaySemantics(
        'Tuesday 6 October',
        tones: 'Focus and Life',
        isToday: true,
      ),
      'Tuesday 6 October, Focus and Life planned, today',
    );
    expect(
      Strings.weekDaySemantics('Tuesday 6 October', tones: '', isToday: false),
      'Tuesday 6 October',
    );
  });

  test('plan list titles', () {
    expect(Strings.planTitleToday, "Today's plan");
    expect(Strings.planTitleFor('Tuesday'), "Tuesday's plan");
  });
}
```

**Create `test/core/time/week_and_speech_test.dart`**

```dart
import 'package:energy_clock/core/time/day_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('spokenDurationMinutes', () {
    test('minutes only', () {
      expect(spokenDurationMinutes(45), '45 minutes');
      expect(spokenDurationMinutes(1), '1 minute');
    });

    test('whole hours', () {
      expect(spokenDurationMinutes(60), '1 hour');
      expect(spokenDurationMinutes(120), '2 hours');
    });

    test('hours and minutes', () {
      expect(spokenDurationMinutes(90), '1 hour 30 minutes');
      expect(spokenDurationMinutes(61), '1 hour 1 minute');
    });
  });

  group('startOfWeek', () {
    test('a Saturday maps to the Monday before it', () {
      // 3 October 2026 is a Saturday.
      expect(startOfWeek(DateTime(2026, 10, 3)), DateTime(2026, 9, 28));
    });

    test('a Monday maps to itself', () {
      expect(startOfWeek(DateTime(2026, 9, 28)), DateTime(2026, 9, 28));
    });

    test('a Sunday belongs to the week that started six days earlier', () {
      expect(startOfWeek(DateTime(2026, 10, 4)), DateTime(2026, 9, 28));
    });

    test('ignores the time of day', () {
      expect(startOfWeek(DateTime(2026, 10, 3, 23, 59)), DateTime(2026, 9, 28));
    });

    test('is calendar arithmetic across a month boundary', () {
      expect(startOfWeek(DateTime(2026, 11, 1)), DateTime(2026, 10, 26));
    });
  });

  test('daysOfWeek returns seven consecutive local midnights, Monday first', () {
    final days = daysOfWeek(DateTime(2026, 10, 3, 15));
    expect(days, hasLength(7));
    expect(days.first, DateTime(2026, 9, 28));
    expect(days.last, DateTime(2026, 10, 4));
    for (var i = 1; i < days.length; i++) {
      expect(days[i], DateTime(2026, 9, 28 + i));
    }
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL — compile errors: 'joinWords', 'spokenDurationMinutes', 'startOfWeek' are not defined
flutter test test/core/strings_test.dart test/core/time/week_and_speech_test.dart
```

- [ ] **Step 3: Add the copy and the helpers**

**Edit `lib/core/strings.dart`**

Replace:

```dart
  static const String deleteConfirmBody = "This can't be undone.";
}
```

With:

```dart
  static const String deleteConfirmBody = "This can't be undone.";

  // Tab bar and header.
  static String tabSemantics(String label, int position, int count) =>
      '$label, tab $position of $count';
  static const String readOnlyChip = 'Read-only';

  // Now card.
  static const String nowNextUp = 'Next up';
  static const String nowDoneTitle = 'All done for today';
  static const String pastNothingPlanned = 'Nothing was planned';
  static String nowTimeLeft(String duration) => '$duration left';
  static String nowUntil(String end) => 'until $end';
  static String nowStartsAt(String start, String inDuration) =>
      'Starts at $start · in $inDuration';
  static String nowOverlapping(int count) => '+$count overlapping';
  static String eventCount(int count) =>
      count == 1 ? '1 event' : '$count events';
  static String plannedSummary(int count, String duration) =>
      '${eventCount(count)} · $duration planned';
  static String plannedDuration(String duration) => '$duration planned';
  static String pastSummary(int count, String duration) =>
      '${eventCount(count)} · $duration';
  static String dayCountTitle(String weekday, int count) =>
      '$weekday · ${eventCount(count)}';
  static String nowSemantics(String title, String tone, String timeLeft) =>
      'Now: $title, $tone, $timeLeft left';
  static String nextSemantics(String title, String tone, String startsIn) =>
      'Next up: $title, $tone, starts in $startsIn';

  // Day-load bar.
  static String dayLoadSemantics(String parts) => 'Planned load: $parts';

  // Week strip.
  static String weekDaySemantics(
    String date, {
    required String tones,
    required bool isToday,
  }) {
    final planned = tones.isEmpty ? '' : ', $tones planned';
    final today = isToday ? ', today' : '';
    return '$date$planned$today';
  }

  // Dial.
  static const String dialSemanticsLabel = '24-hour day dial';
  static String eventSemantics(
    String title,
    String tone,
    String start,
    String end,
    String duration,
  ) => '$title, $tone, $start to $end, $duration';

  // Today's plan list (wide windows).
  static const String planTitleToday = "Today's plan";
  static String planTitleFor(String weekday) => "$weekday's plan";

  /// "Focus", "Focus and Life", "Focus, Life and Inbox".
  static String joinWords(List<String> items) {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.single;
    final head = items.sublist(0, items.length - 1).join(', ');
    return '$head and ${items.last}';
  }
}
```

**Edit `lib/core/time/day_time.dart`**

Replace:

```dart
bool isPastDay(DateTime day, {DateTime? now}) {
  final today = startOfDay(now ?? DateTime.now());
  return startOfDay(day).isBefore(today);
}
```

With:

```dart
bool isPastDay(DateTime day, {DateTime? now}) {
  final today = startOfDay(now ?? DateTime.now());
  return startOfDay(day).isBefore(today);
}

/// A duration spoken in full words, for screen readers: "1 hour 30 minutes".
String spokenDurationMinutes(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  final hourText = hours == 1 ? '1 hour' : '$hours hours';
  final minuteText = remainder == 1 ? '1 minute' : '$remainder minutes';
  if (hours == 0) return minuteText;
  if (remainder == 0) return hourText;
  return '$hourText $minuteText';
}

/// The Monday on or before [day], at local midnight. Weeks start on Monday
/// until the first-day-of-week setting exists. Calendar arithmetic, so a DST
/// change inside the week cannot move the result by a day.
DateTime startOfWeek(DateTime day) {
  final midnight = startOfDay(day);
  return DateTime(
    midnight.year,
    midnight.month,
    midnight.day - (midnight.weekday - DateTime.monday),
  );
}

/// The seven local midnights of the week containing [day], Monday first.
List<DateTime> daysOfWeek(DateTime day) {
  final first = startOfWeek(day);
  return [
    for (var i = 0; i < 7; i++) DateTime(first.year, first.month, first.day + i),
  ];
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
# expect: PASS
flutter test test/core/strings_test.dart test/core/time/week_and_speech_test.dart test/core/time/day_time_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/core/strings.dart lib/core/time/day_time.dart test/core/strings_test.dart test/core/time/week_and_speech_test.dart
git commit -m "feat: add Step 1 copy, spoken durations, and week helpers

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Design tokens and `AppColors`

**Files:**
- Create: `lib/app/theme/tokens.dart`, `lib/app/theme/app_colors.dart`
- Create: `test/support/contrast.dart`
- Test: `test/app/app_colors_test.dart`

**Interfaces:**
- Produces: `AppSpacing` (`xs` 4, `sm` 8, `md` 12, `lg` 16, `xl` 20, `xxl` 24, `xxxl` 32, `huge` 40), `AppRadii` (`chip` 12, `control` 16, `card` 24, `sheet` 28, `pill` 999), `AppMotion` (`fast` 150 ms, `base` 250 ms, `slow` 400 ms, `standard` = `Curves.easeOutCubic`, `pop` = `Curves.easeOutBack`); `AppColors` with fields `brightness`, `page`, `surface`, `ink`, `onInk`, `muted`, `outline`, `danger`, `nightTint`, getters `isDark`, `cardShadow`, `faceShadow`, `barShadow`, constant `AppColors.transparent`, statics `AppColors.light` / `AppColors.dark`, and `context.appColors`.
- Produces (test helper): `contrastRatio(Color a, Color b)` in `test/support/contrast.dart`.

- [ ] **Step 1: Write the failing test and the contrast helper**

**Create `test/support/contrast.dart`**

```dart
import 'dart:math' as math;

import 'package:flutter/painting.dart';

double _linear(double channel) => channel <= 0.04045
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

/// WCAG relative luminance of an opaque colour.
double relativeLuminance(Color color) =>
    0.2126 * _linear(color.r) +
    0.7152 * _linear(color.g) +
    0.0722 * _linear(color.b);

/// WCAG contrast ratio between two opaque colours, 1.0 to 21.0.
double contrastRatio(Color a, Color b) {
  final first = relativeLuminance(a);
  final second = relativeLuminance(b);
  final lighter = math.max(first, second);
  final darker = math.min(first, second);
  return (lighter + 0.05) / (darker + 0.05);
}
```

**Create `test/app/app_colors_test.dart`**

```dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/contrast.dart';

void main() {
  test('contrast helper matches known values', () {
    expect(
      contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21, 0.001),
    );
    expect(
      contrastRatio(const Color(0xFFFFFFFF), const Color(0xFFFFFFFF)),
      closeTo(1, 0.001),
    );
  });

  for (final entry in {
    'light': AppColors.light,
    'dark': AppColors.dark,
  }.entries) {
    group('${entry.key} neutrals', () {
      final colors = entry.value;

      test('text on the page and on cards is at least 4.5:1', () {
        expect(contrastRatio(colors.ink, colors.page), greaterThanOrEqualTo(4.5));
        expect(
          contrastRatio(colors.ink, colors.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(colors.muted, colors.page),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(colors.muted, colors.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(colors.danger, colors.page),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(colors.danger, colors.surface),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('text on an ink button is at least 4.5:1', () {
        expect(contrastRatio(colors.onInk, colors.ink), greaterThanOrEqualTo(4.5));
      });
    });
  }

  test('light mode has shadows; dark mode uses borders instead', () {
    expect(AppColors.light.cardShadow, isNotEmpty);
    expect(AppColors.light.faceShadow, isNotEmpty);
    expect(AppColors.light.barShadow, isNotEmpty);
    expect(AppColors.dark.cardShadow, isEmpty);
    expect(AppColors.dark.faceShadow, isEmpty);
    expect(AppColors.dark.barShadow, isEmpty);
    expect(AppColors.light.isDark, isFalse);
    expect(AppColors.dark.isDark, isTrue);
  });

  test('light and dark differ for every colour', () {
    expect(AppColors.light.page, isNot(AppColors.dark.page));
    expect(AppColors.light.surface, isNot(AppColors.dark.surface));
    expect(AppColors.light.ink, isNot(AppColors.dark.ink));
  });

  test('lerp blends and equality follows the values', () {
    final mid = AppColors.light.lerp(AppColors.dark, 0.5);
    expect(mid, isA<AppColors>());
    expect(AppColors.light, AppColors.light.copyWith());
    expect(AppColors.light.hashCode, AppColors.light.copyWith().hashCode);
    expect(AppColors.light, isNot(AppColors.dark));
    expect(
      AppColors.light.copyWith(ink: const Color(0xFF000000)).ink,
      const Color(0xFF000000),
    );
  });

  test('tokens hold the specified scales', () {
    expect(AppSpacing.xs, 4);
    expect(AppSpacing.huge, 40);
    expect(AppRadii.card, 24);
    expect(AppRadii.pill, 999);
    expect(AppMotion.fast, const Duration(milliseconds: 150));
    expect(AppMotion.base, const Duration(milliseconds: 250));
    expect(AppMotion.slow, const Duration(milliseconds: 400));
    expect(AppMotion.standard, Curves.easeOutCubic);
    expect(AppMotion.pop, Curves.easeOutBack);
  });

  testWidgets('context.appColors reads the theme extension', (tester) async {
    late AppColors read;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [AppColors.dark]),
        home: Builder(
          builder: (context) {
            read = context.appColors;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(read, AppColors.dark);
  });

  testWidgets('context.appColors throws a clear error when the theme lacks it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            expect(() => context.appColors, throwsStateError);
            return const SizedBox();
          },
        ),
      ),
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
# expect: FAIL — "Target of URI doesn't exist: 'package:energy_clock/app/theme/app_colors.dart'"
flutter test test/app/app_colors_test.dart
```

- [ ] **Step 3: Write the tokens and colours**

**Create `lib/app/theme/tokens.dart`**

```dart
import 'package:flutter/animation.dart';

/// Spacing scale, in logical pixels.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
}

/// Corner radii.
abstract final class AppRadii {
  static const double chip = 12;
  static const double control = 16;
  static const double card = 24;
  static const double sheet = 28;
  static const double pill = 999;
}

/// Animation durations and curves. All durations drop to zero when the system
/// asks for reduced motion; callers check `MediaQuery.disableAnimationsOf`.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  /// Standard ease for sweeps, fades and slides.
  static const Curve standard = Curves.easeOutCubic;

  /// Slight overshoot for pops and the dial resize.
  static const Curve pop = Curves.easeOutBack;
}
```

**Create `lib/app/theme/app_colors.dart`**

```dart
import 'package:flutter/material.dart';

/// Neutral colours and elevation. Tone colours live in `ToneColors`. Colour on
/// screen only ever means a tone, so everything here is deliberately neutral.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.page,
    required this.surface,
    required this.ink,
    required this.onInk,
    required this.muted,
    required this.outline,
    required this.danger,
    required this.nightTint,
  });

  /// A fully transparent colour. Feature code may not hard-code colours, so it
  /// uses this when it needs "no fill".
  static const Color transparent = Color(0x00000000);

  static const AppColors light = AppColors(
    brightness: Brightness.light,
    page: Color(0xFFF4F5F7),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF17141F),
    onInk: Color(0xFFFFFFFF),
    muted: Color(0xFF5E5B6B),
    outline: Color(0xFFE4E4EA),
    danger: Color(0xFFC4261B),
    nightTint: Color(0x144A6FA5),
  );

  static const AppColors dark = AppColors(
    brightness: Brightness.dark,
    page: Color(0xFF0F0F14),
    surface: Color(0xFF1A1A22),
    ink: Color(0xFFF4F4F8),
    onInk: Color(0xFF17141F),
    muted: Color(0xFFA7A5B5),
    outline: Color(0xFF2C2C38),
    danger: Color(0xFFFF6B63),
    nightTint: Color(0x1F7C9CFF),
  );

  final Brightness brightness;

  /// The page background.
  final Color page;

  /// Cards, the dial face, and sheets.
  final Color surface;

  /// Text, buttons, and the selected tab.
  final Color ink;

  /// Text on [ink].
  final Color onInk;

  /// Secondary text.
  final Color muted;

  /// Hairlines. Decorative only.
  final Color outline;

  /// Delete and error.
  final Color danger;

  /// The faint tint over night hours on the dial face. Decorative only.
  final Color nightTint;

  bool get isDark => brightness == Brightness.dark;

  /// Soft shadow under cards. Dark mode uses a hairline border instead.
  List<BoxShadow> get cardShadow => isDark
      ? const []
      : [
          BoxShadow(
            color: ink.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ];

  /// Shadow that raises the dial face off the page.
  List<BoxShadow> get faceShadow => isDark
      ? const []
      : [
          BoxShadow(
            color: ink.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ];

  /// Shadow under the floating tab bar.
  List<BoxShadow> get barShadow => isDark
      ? const []
      : [
          BoxShadow(
            color: ink.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ];

  @override
  AppColors copyWith({
    Brightness? brightness,
    Color? page,
    Color? surface,
    Color? ink,
    Color? onInk,
    Color? muted,
    Color? outline,
    Color? danger,
    Color? nightTint,
  }) {
    return AppColors(
      brightness: brightness ?? this.brightness,
      page: page ?? this.page,
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      onInk: onInk ?? this.onInk,
      muted: muted ?? this.muted,
      outline: outline ?? this.outline,
      danger: danger ?? this.danger,
      nightTint: nightTint ?? this.nightTint,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      page: Color.lerp(page, other.page, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      onInk: Color.lerp(onInk, other.onInk, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      nightTint: Color.lerp(nightTint, other.nightTint, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppColors &&
      other.brightness == brightness &&
      other.page == page &&
      other.surface == surface &&
      other.ink == ink &&
      other.onInk == onInk &&
      other.muted == muted &&
      other.outline == outline &&
      other.danger == danger &&
      other.nightTint == nightTint;

  @override
  int get hashCode => Object.hash(
    brightness,
    page,
    surface,
    ink,
    onInk,
    muted,
    outline,
    danger,
    nightTint,
  );
}

extension AppColorsContext on BuildContext {
  AppColors get appColors {
    final colors = Theme.of(this).extension<AppColors>();
    if (colors == null) {
      throw StateError(
        'AppColors is missing from the theme. Build the app with '
        'AppTheme.light or AppTheme.dark.',
      );
    }
    return colors;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
# expect: PASS
flutter test test/app/app_colors_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/app/theme/tokens.dart lib/app/theme/app_colors.dart test/support/contrast.dart test/app/app_colors_test.dart
git commit -m "feat: add design tokens and neutral colour extension

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Tone palettes

`ToneColors` becomes a per-tone table of four colours (`solid`, `onSolid`, `soft`, `deep`). The existing `fillFor` / `labelFor` calls keep working as thin wrappers, so no call site changes. This changes the dial's colours, so the golden images are regenerated at the end of the task.

**Files:**
- Replace: `lib/app/theme/tone_colors.dart`
- Replace: `test/app/tone_colors_test.dart`
- Regenerate: `test/features/clock/goldens/*.png`

**Interfaces:**
- Produces: `TonePalette(solid, onSolid, soft, deep)`; `ToneColors(focus:, life:, inbox:)` with `paletteFor(Tone)`, `fillFor` (= `solid`), `labelFor` (= `onSolid`), `softFor`, `deepFor`, `copyWith`, `lerp`, `==`; statics `ToneColors.light` / `ToneColors.dark`; `context.toneColors` (unchanged).
- Consumes: `Tone` from `lib/core/tone.dart`; `AppColors` and `contrastRatio` (tests only).

- [ ] **Step 1: Write the failing test**

**Replace `test/app/tone_colors_test.dart`**

```dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/contrast.dart';

void main() {
  final modes = {
    'light': (ToneColors.light, AppColors.light),
    'dark': (ToneColors.dark, AppColors.dark),
  };

  test('every tone has a distinct solid in both themes', () {
    for (final (tones, _) in modes.values) {
      final solids = Tone.values.map(tones.fillFor).toSet();
      expect(solids, hasLength(Tone.values.length));
    }
  });

  test('light and dark solids differ for every tone', () {
    for (final tone in Tone.values) {
      expect(
        ToneColors.light.fillFor(tone),
        isNot(ToneColors.dark.fillFor(tone)),
      );
    }
  });

  test('focus solid matches the specified light palette value', () {
    expect(ToneColors.light.fillFor(Tone.focus), const Color(0xFF6D4AFF));
    expect(ToneColors.light.fillFor(Tone.life), const Color(0xFF14A85A));
    expect(ToneColors.light.fillFor(Tone.inbox), const Color(0xFFF26B00));
  });

  test('every accessor reads the same palette', () {
    for (final tone in Tone.values) {
      final palette = ToneColors.light.paletteFor(tone);
      expect(ToneColors.light.fillFor(tone), palette.solid);
      expect(ToneColors.light.labelFor(tone), palette.onSolid);
      expect(ToneColors.light.softFor(tone), palette.soft);
      expect(ToneColors.light.deepFor(tone), palette.deep);
    }
  });

  test('lerp returns a ToneColors halfway between the palettes', () {
    final result = ToneColors.light.lerp(ToneColors.dark, 0.5);
    expect(result, isA<ToneColors>());
    expect(
      result.fillFor(Tone.focus),
      Color.lerp(
        ToneColors.light.fillFor(Tone.focus),
        ToneColors.dark.fillFor(Tone.focus),
        0.5,
      ),
    );
  });

  test('equality and hashCode follow the values', () {
    expect(ToneColors.light, ToneColors.light.copyWith());
    expect(ToneColors.light.hashCode, ToneColors.light.copyWith().hashCode);
    expect(ToneColors.light, isNot(ToneColors.dark));
  });

  test('copyWith replaces one palette', () {
    final replaced = ToneColors.light.copyWith(
      life: ToneColors.dark.paletteFor(Tone.life),
    );
    expect(replaced.paletteFor(Tone.life), ToneColors.dark.paletteFor(Tone.life));
    expect(
      replaced.paletteFor(Tone.focus),
      ToneColors.light.paletteFor(Tone.focus),
    );
  });

  for (final entry in modes.entries) {
    group('${entry.key} contrast', () {
      final (tones, app) = entry.value;

      for (final tone in Tone.values) {
        test('${tone.label}: label on the arc is at least 4.5:1', () {
          expect(
            contrastRatio(tones.labelFor(tone), tones.fillFor(tone)),
            greaterThanOrEqualTo(4.5),
          );
        });

        test('${tone.label}: the arc against the face is at least 3:1', () {
          expect(
            contrastRatio(tones.fillFor(tone), app.surface),
            greaterThanOrEqualTo(3),
          );
        });

        test('${tone.label}: chip text on its soft fill is at least 4.5:1', () {
          expect(
            contrastRatio(tones.deepFor(tone), tones.softFor(tone)),
            greaterThanOrEqualTo(4.5),
          );
        });

        test('${tone.label}: deep text on the page is at least 4.5:1', () {
          expect(
            contrastRatio(tones.deepFor(tone), app.page),
            greaterThanOrEqualTo(4.5),
          );
        });
      }
    });
  }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
# expect: FAIL — 'paletteFor' / 'softFor' / 'deepFor' are not defined; the old focus value is 0xFFD8D2FF
flutter test test/app/tone_colors_test.dart
```

- [ ] **Step 3: Replace `ToneColors`**

**Replace `lib/app/theme/tone_colors.dart`**

```dart
import 'package:energy_clock/core/tone.dart';
import 'package:flutter/material.dart';

/// The four colours one tone needs.
@immutable
class TonePalette {
  const TonePalette({
    required this.solid,
    required this.onSolid,
    required this.soft,
    required this.deep,
  });

  /// Arcs, the Now card, and day-load segments.
  final Color solid;

  /// Text drawn on [solid]. White on Focus; near-black on Life and Inbox,
  /// because white is too faint on green and orange.
  final Color onSolid;

  /// Chip background.
  final Color soft;

  /// Text on [soft] or on the page.
  final Color deep;

  static TonePalette lerp(TonePalette a, TonePalette b, double t) {
    return TonePalette(
      solid: Color.lerp(a.solid, b.solid, t)!,
      onSolid: Color.lerp(a.onSolid, b.onSolid, t)!,
      soft: Color.lerp(a.soft, b.soft, t)!,
      deep: Color.lerp(a.deep, b.deep, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TonePalette &&
      other.solid == solid &&
      other.onSolid == onSolid &&
      other.soft == soft &&
      other.deep == deep;

  @override
  int get hashCode => Object.hash(solid, onSolid, soft, deep);
}

/// Per-tone colours. Held in a theme extension rather than on [Tone] itself so
/// that light and dark palettes can differ while the tone identity stays a pure
/// domain concept.
@immutable
class ToneColors extends ThemeExtension<ToneColors> {
  const ToneColors({
    required this.focus,
    required this.life,
    required this.inbox,
  });

  static const ToneColors light = ToneColors(
    focus: TonePalette(
      solid: Color(0xFF6D4AFF),
      onSolid: Color(0xFFFFFFFF),
      soft: Color(0xFFECE8FF),
      deep: Color(0xFF4A2FD1),
    ),
    life: TonePalette(
      solid: Color(0xFF14A85A),
      onSolid: Color(0xFF17141F),
      soft: Color(0xFFDDF7EA),
      deep: Color(0xFF0E7A47),
    ),
    inbox: TonePalette(
      solid: Color(0xFFF26B00),
      onSolid: Color(0xFF17141F),
      soft: Color(0xFFFFEBD6),
      deep: Color(0xFF9A4D00),
    ),
  );

  static const ToneColors dark = ToneColors(
    focus: TonePalette(
      solid: Color(0xFF8E78FF),
      onSolid: Color(0xFF17141F),
      soft: Color(0xFF2A2450),
      deep: Color(0xFFC9BEFF),
    ),
    life: TonePalette(
      solid: Color(0xFF34D399),
      onSolid: Color(0xFF17141F),
      soft: Color(0xFF16382B),
      deep: Color(0xFFA7F3D0),
    ),
    inbox: TonePalette(
      solid: Color(0xFFFFA040),
      onSolid: Color(0xFF17141F),
      soft: Color(0xFF402A12),
      deep: Color(0xFFFFD2A1),
    ),
  );

  final TonePalette focus;
  final TonePalette life;
  final TonePalette inbox;

  TonePalette paletteFor(Tone tone) => switch (tone) {
    Tone.focus => focus,
    Tone.life => life,
    Tone.inbox => inbox,
  };

  /// The arc colour. Kept as a wrapper so existing call sites keep working.
  Color fillFor(Tone tone) => paletteFor(tone).solid;

  /// Text drawn on the arc colour.
  Color labelFor(Tone tone) => paletteFor(tone).onSolid;

  Color softFor(Tone tone) => paletteFor(tone).soft;

  Color deepFor(Tone tone) => paletteFor(tone).deep;

  @override
  ToneColors copyWith({
    TonePalette? focus,
    TonePalette? life,
    TonePalette? inbox,
  }) {
    return ToneColors(
      focus: focus ?? this.focus,
      life: life ?? this.life,
      inbox: inbox ?? this.inbox,
    );
  }

  @override
  ToneColors lerp(ThemeExtension<ToneColors>? other, double t) {
    if (other is! ToneColors) return this;
    return ToneColors(
      focus: TonePalette.lerp(focus, other.focus, t),
      life: TonePalette.lerp(life, other.life, t),
      inbox: TonePalette.lerp(inbox, other.inbox, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ToneColors &&
      other.focus == focus &&
      other.life == life &&
      other.inbox == inbox;

  @override
  int get hashCode => Object.hash(focus, life, inbox);
}

extension ToneColorsContext on BuildContext {
  ToneColors get toneColors {
    final colors = Theme.of(this).extension<ToneColors>();
    if (colors == null) {
      throw StateError(
        'ToneColors is missing from the theme. Build the app with '
        'AppTheme.light or AppTheme.dark.',
      );
    }
    return colors;
  }
}
```

- [ ] **Step 4: Run the tone tests, then see which goldens changed**

```bash
# expect: PASS
flutter test test/app/tone_colors_test.dart
```

```bash
# expect: FAIL — the four dial goldens no longer match because the arc colours changed
flutter test test/features/clock/dial_golden_test.dart
```

- [ ] **Step 5: Regenerate the goldens and look at them**

```bash
# expect: UPDATE
flutter test --update-goldens test/features/clock/dial_golden_test.dart
```

Open `test/features/clock/goldens/dial_tones_light.png` and `dial_overlaps_light.png` and confirm the arcs are now vivid purple, green and orange (not pastel) and the faces are unchanged. Then run the whole suite.

```bash
# expect: PASS
flutter test
```

- [ ] **Step 6: Commit**

```bash
git add lib/app/theme/tone_colors.dart test/app/tone_colors_test.dart test/features/clock/goldens
git commit -m "feat: bold per-tone palettes with verified contrast

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Nunito, typography and the new theme

**Controller pre-flight (before dispatching this task).** The font files are not in the repo and downloading needs the user's approval. Ask the user: "May I download Nunito (the variable font, 277 KB, and its OFL.txt licence, 4 KB) from github.com/google/fonts, and cut four static weights from it with fontTools?" Then run this in the repo root. Nunito is only published as a variable font, so the four static weights are generated locally with `fontTools`, which is installed on this machine.

```bash
# expect: MANUAL — needs the user's approval to download; the files are committed afterwards
mkdir -p assets/fonts
curl -L -o /tmp/Nunito-vf.ttf "https://raw.githubusercontent.com/google/fonts/main/ofl/nunito/Nunito%5Bwght%5D.ttf"
curl -L -o assets/fonts/OFL.txt "https://raw.githubusercontent.com/google/fonts/main/ofl/nunito/OFL.txt"
for pair in Regular:400 SemiBold:600 Bold:700 ExtraBold:800; do
  name="${pair%%:*}"; weight="${pair##*:}"
  python3 -m fontTools.varLib.instancer /tmp/Nunito-vf.ttf "wght=$weight" -o "assets/fonts/Nunito-$name.ttf"
done
ls -la assets/fonts
```

Check that `assets/fonts/OFL.txt` has no "Reserved Font Name" clause. If it does, stop and ask the user, because cutting static instances would be a modified version. The task below assumes the four static files and `OFL.txt` exist.

**Files:**
- Edit: `pubspec.yaml`
- Replace: `lib/main.dart`, `lib/app/theme/app_theme.dart`
- Create: `lib/app/theme/app_typography.dart`
- Test: `test/app/app_theme_test.dart`
- Regenerate: `test/features/clock/goldens/*.png`

**Interfaces:**
- Produces: `AppTypography.fontFamily` (`'Nunito'`), `AppTypography.displayTime(double faceRadius)`, `AppTypography.dialNumeral(double faceRadius)`, `AppTypography.arcLabel(double ringWidth)`, `AppTypography.textTheme({required Color ink, required Color muted})`. Material roles used by the rest of the plan: `titleLarge` (28/800), `titleMedium` (20/700), `titleSmall` (16/700), `bodyMedium` (16/400), `bodySmall` (12/600 muted), `labelLarge` (14/700), `labelMedium` (12/600 muted).
- Produces: `AppTheme.light` / `AppTheme.dark` carrying `AppColors` and `ToneColors` extensions, bottom sheets capped at 560 pt wide.
- Note: the font is bundled and declared here, but tests keep Flutter's box-shaped test font until Task 14 loads Nunito for every test, together with the fixed-clock goldens. Until then a golden shows the same box for every glyph, so it does not change with the time of day. (Loading Nunito any earlier would put the real current time in the dial's centre text into every golden, and the goldens would fail a minute later.)

- [ ] **Step 1: Write the failing test**

**Create `test/app/app_theme_test.dart`**

```dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/app/theme/app_typography.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final entry in {
    'light': (AppTheme.light, AppColors.light, ToneColors.light),
    'dark': (AppTheme.dark, AppColors.dark, ToneColors.dark),
  }.entries) {
    group(entry.key, () {
      final (theme, colors, tones) = entry.value;

      test('carries the app colour extensions', () {
        expect(theme.extension<AppColors>(), colors);
        expect(theme.extension<ToneColors>(), tones);
      });

      test('ink is the primary colour and the page is the background', () {
        expect(theme.colorScheme.primary, colors.ink);
        expect(theme.colorScheme.onPrimary, colors.onInk);
        expect(theme.colorScheme.error, colors.danger);
        expect(theme.scaffoldBackgroundColor, colors.page);
        expect(theme.colorScheme.brightness, colors.brightness);
      });

      test('text uses Nunito at the specified sizes and weights', () {
        final text = theme.textTheme;
        expect(text.titleLarge!.fontFamily, AppTypography.fontFamily);
        expect(text.titleLarge!.fontSize, 28);
        expect(text.titleLarge!.fontWeight, FontWeight.w800);
        expect(text.titleMedium!.fontSize, 20);
        expect(text.titleMedium!.fontWeight, FontWeight.w700);
        expect(text.bodyMedium!.fontSize, 16);
        expect(text.bodyMedium!.fontWeight, FontWeight.w400);
        expect(text.labelLarge!.fontSize, 14);
        expect(text.bodySmall!.fontSize, 12);
        expect(text.titleLarge!.color, colors.ink);
        expect(text.bodySmall!.color, colors.muted);
      });

      test('modal bottom sheets are capped at 560 pt wide', () {
        expect(theme.bottomSheetTheme.constraints?.maxWidth, 560);
        expect(theme.bottomSheetTheme.backgroundColor, colors.surface);
      });
    });
  }

  group('dial text styles scale with the dial', () {
    test('the centre time is clamped between 22 and 44', () {
      expect(AppTypography.displayTime(50).fontSize, 22);
      expect(AppTypography.displayTime(100).fontSize, closeTo(22, 0.001));
      expect(AppTypography.displayTime(150).fontSize, closeTo(33, 0.001));
      expect(AppTypography.displayTime(400).fontSize, 44);
    });

    test('numerals are at least 11 and arc labels at least 10', () {
      expect(AppTypography.dialNumeral(40).fontSize, 11);
      expect(AppTypography.dialNumeral(150).fontSize, closeTo(19.5, 0.001));
      expect(AppTypography.arcLabel(10).fontSize, 10);
      expect(AppTypography.arcLabel(30).fontSize, 15);
    });

    test('times use tabular figures', () {
      expect(
        AppTypography.displayTime(100).fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
# expect: FAIL — 'AppTypography' is not defined
flutter test test/app/app_theme_test.dart
```

- [ ] **Step 3: Declare the font, load it in tests, and write the typography and theme**

**Edit `pubspec.yaml`**

Replace:

```yaml
  uses-material-design: true
```

With:

```yaml
  uses-material-design: true

  assets:
    - assets/fonts/OFL.txt

  fonts:
    - family: Nunito
      fonts:
        - asset: assets/fonts/Nunito-Regular.ttf
          weight: 400
        - asset: assets/fonts/Nunito-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Nunito-Bold.ttf
          weight: 700
        - asset: assets/fonts/Nunito-ExtraBold.ttf
          weight: 800
```

**Create `lib/app/theme/app_typography.dart`**

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The one typeface and the text styles built on it (spec §4.2). Colour is
/// applied by the theme or by the caller.
abstract final class AppTypography {
  static const String fontFamily = 'Nunito';

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  static TextStyle _style(
    double size,
    FontWeight weight, {
    double? height,
    List<FontFeature>? features,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      height: height,
      fontFeatures: features,
    );
  }

  /// The time in the dial centre. Scales with the dial, between 22 and 44.
  static TextStyle displayTime(double faceRadius) => _style(
    (0.22 * faceRadius).clamp(22.0, 44.0),
    FontWeight.w800,
    height: 1.1,
    features: _tabular,
  );

  /// Hour numerals around the dial.
  static TextStyle dialNumeral(double faceRadius) => _style(
    math.max(11.0, 0.13 * faceRadius),
    FontWeight.w800,
    height: 1,
    features: _tabular,
  );

  /// The curved title on an event arc.
  static TextStyle arcLabel(double ringWidth) =>
      _style(math.max(10.0, 0.5 * ringWidth), FontWeight.w800, height: 1);

  /// The Material text theme, mapped from the spec's styles:
  /// `titleLarge` 28/800, `titleMedium` 20/700, `titleSmall` 16/700 (strong
  /// body), `bodyMedium` 16/400, `bodySmall` 12/600 (caption), `labelLarge`
  /// 14/700.
  static TextTheme textTheme({required Color ink, required Color muted}) {
    TextStyle style(
      double size,
      FontWeight weight,
      Color color, {
      double? height,
    }) => _style(size, weight, height: height).copyWith(color: color);

    return TextTheme(
      displaySmall: style(34, FontWeight.w800, ink, height: 1.1),
      headlineSmall: style(28, FontWeight.w800, ink, height: 1.15),
      titleLarge: style(28, FontWeight.w800, ink, height: 1.15),
      titleMedium: style(20, FontWeight.w700, ink, height: 1.2),
      titleSmall: style(16, FontWeight.w700, ink, height: 1.25),
      bodyLarge: style(16, FontWeight.w400, ink, height: 1.3),
      bodyMedium: style(16, FontWeight.w400, ink, height: 1.3),
      bodySmall: style(12, FontWeight.w600, muted, height: 1.25),
      labelLarge: style(14, FontWeight.w700, ink, height: 1.2),
      labelMedium: style(12, FontWeight.w600, muted, height: 1.2),
      labelSmall: style(11, FontWeight.w600, muted, height: 1.2),
    );
  }
}
```

**Replace `lib/app/theme/app_theme.dart`**

```dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/app_typography.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(AppColors.light, ToneColors.light);
  static ThemeData get dark => _build(AppColors.dark, ToneColors.dark);

  static ThemeData _build(AppColors colors, ToneColors toneColors) {
    final scheme = ColorScheme(
      brightness: colors.brightness,
      primary: colors.ink,
      onPrimary: colors.onInk,
      secondary: colors.ink,
      onSecondary: colors.onInk,
      error: colors.danger,
      onError: colors.onInk,
      surface: colors.surface,
      onSurface: colors.ink,
      onSurfaceVariant: colors.muted,
      outline: colors.outline,
      outlineVariant: colors.outline,
      surfaceContainerLowest: colors.surface,
      surfaceContainerLow: colors.surface,
      surfaceContainer: colors.surface,
      surfaceContainerHigh: colors.surface,
      surfaceContainerHighest: colors.page,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.page,
      fontFamily: AppTypography.fontFamily,
      textTheme: AppTypography.textTheme(ink: colors.ink, muted: colors.muted),
      splashFactory: NoSplash.splashFactory,
      dividerColor: colors.outline,
      // Each sheet asks for the drag handle itself (`showDragHandle: true`)
      // once it scrolls, so a short window can never overflow it.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        modalBackgroundColor: colors.surface,
        dragHandleColor: colors.muted.withValues(alpha: 0.4),
        constraints: const BoxConstraints(maxWidth: 560),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
      ),
      extensions: <ThemeExtension<Object?>>[colors, toneColors],
    );
  }
}
```

**Replace `lib/main.dart`**

```dart
import 'package:energy_clock/app/app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Nunito is licensed under the SIL Open Font Licence; list it on the
  // licences page.
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(<String>['Nunito'], text);
  });
  runApp(const ProviderScope(child: EnergyClockApp()));
}
```

- [ ] **Step 4: Run the theme tests, regenerate the goldens, run everything**

```bash
# expect: PASS
flutter test test/app/app_theme_test.dart
```

The theme change gives the dial's numerals and labels different box sizes, so the goldens are regenerated.

```bash
# expect: UPDATE
flutter test --update-goldens test/features/clock/dial_golden_test.dart
```

Open `test/features/clock/goldens/dial_tones_light.png`: the numerals are still solid boxes (Flutter's test font; real text arrives in Task 14), now slightly larger than before. Then:

```bash
# expect: PASS
flutter analyze && flutter test
```

- [ ] **Step 5: Commit** (the font files are included because they were added in the pre-flight)

```bash
git add assets/fonts pubspec.yaml pubspec.lock lib/main.dart lib/app/theme test/app/app_theme_test.dart test/features/clock
git commit -m "feat: bundle Nunito and build the theme from tokens

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Adaptive layout helpers

**Files:**
- Create: `lib/shared/layout/window_class.dart`, `lib/shared/layout/content_width.dart`
- Test: `test/shared/layout/layout_helpers_test.dart`

**Interfaces:**
- Produces: `enum WindowClass { narrow, medium, wide }`; `windowClassFor(double width)` (under 600 → narrow, 600–899.99 → medium, 900+ → wide); `context.windowClass`; `ContentWidth({required double maxWidth, required Widget child})`; `abstract final class ContentWidths { column = 560, sheet = 560, onboarding = 480, tabBar = 480 }`.

- [ ] **Step 1: Write the failing test**

**Create `test/shared/layout/layout_helpers_test.dart`**

```dart
import 'package:energy_clock/shared/layout/content_width.dart';
import 'package:energy_clock/shared/layout/window_class.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('windowClassFor', () {
    test('splits at 600 and 900', () {
      expect(windowClassFor(320), WindowClass.narrow);
      expect(windowClassFor(599), WindowClass.narrow);
      expect(windowClassFor(599.9), WindowClass.narrow);
      expect(windowClassFor(600), WindowClass.medium);
      expect(windowClassFor(899), WindowClass.medium);
      expect(windowClassFor(899.9), WindowClass.medium);
      expect(windowClassFor(900), WindowClass.wide);
      expect(windowClassFor(1376), WindowClass.wide);
    });
  });

  group('ContentWidths', () {
    test('hold the specified maximum widths', () {
      expect(ContentWidths.column, 560);
      expect(ContentWidths.sheet, 560);
      expect(ContentWidths.onboarding, 480);
      expect(ContentWidths.tabBar, 480);
    });
  });

  testWidgets('context.windowClass follows the window width', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late WindowClass read;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            read = context.windowClass;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(read, WindowClass.wide);

    tester.view.physicalSize = const Size(400, 800);
    await tester.pump();
    expect(read, WindowClass.narrow);
  });

  testWidgets('ContentWidth centres its child and caps the width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: ContentWidth(
          maxWidth: 560,
          child: SizedBox(key: Key('content'), height: 40),
        ),
      ),
    );
    final box = tester.getRect(find.byKey(const Key('content')));
    expect(box.width, 560);
    expect(box.center.dx, 500);
    expect(box.top, 0);
  });

  testWidgets('ContentWidth lets a narrower window through unchanged', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: ContentWidth(
          maxWidth: 560,
          child: SizedBox(key: Key('content'), height: 40),
        ),
      ),
    );
    expect(tester.getRect(find.byKey(const Key('content'))).width, 400);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
# expect: FAIL — "Target of URI doesn't exist: 'package:energy_clock/shared/layout/content_width.dart'"
flutter test test/shared/layout/layout_helpers_test.dart
```

- [ ] **Step 3: Write the helpers**

**Create `lib/shared/layout/window_class.dart`**

```dart
import 'package:flutter/widgets.dart';

/// How much room the app window has. Layout follows the window width, not the
/// device name, because iPad windows resize in Split View, Slide Over, and
/// iPadOS windowing.
enum WindowClass { narrow, medium, wide }

const double mediumWindowMinWidth = 600;
const double wideWindowMinWidth = 900;

WindowClass windowClassFor(double width) {
  if (width >= wideWindowMinWidth) return WindowClass.wide;
  if (width >= mediumWindowMinWidth) return WindowClass.medium;
  return WindowClass.narrow;
}

extension WindowClassContext on BuildContext {
  WindowClass get windowClass => windowClassFor(MediaQuery.sizeOf(this).width);
}
```

**Create `lib/shared/layout/content_width.dart`**

```dart
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Maximum content widths, in logical pixels.
abstract final class ContentWidths {
  /// The single-column Clock layout on medium windows.
  static const double column = 560;

  /// Modal sheets and dialogs.
  static const double sheet = 560;

  static const double onboarding = 480;
  static const double tabBar = 480;
}

/// Centres [child] horizontally at the smaller of [maxWidth] and the available
/// width. The child is given exactly that width (not a loose maximum), so it
/// fills it: on a window narrower than [maxWidth] it fills the whole window.
class ContentWidth extends StatelessWidget {
  const ContentWidth({required this.maxWidth, required this.child, super.key});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? math.min(maxWidth, constraints.maxWidth)
            : maxWidth;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: width, child: child),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
# expect: PASS
flutter test test/shared/layout/layout_helpers_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/shared/layout test/shared/layout
git commit -m "feat: add window classes and content-width helper

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Shared components

`PressScale`, `AppCard`, `ToneChip`, `AppButton`, `SectionHeader`, the adaptive confirm dialog, and the three-arc `RingMark` painter that the tab icon, onboarding, and brand assets all share.

**Files:**
- Create: `lib/shared/widgets/press_scale.dart`, `app_card.dart`, `tone_chip.dart`, `app_button.dart`, `section_header.dart`, `adaptive_dialog.dart`, `ring_mark.dart`
- Test: `test/shared/widgets/shared_widgets_test.dart`, `test/shared/widgets/adaptive_dialog_test.dart`

**Interfaces:**
- Produces: `PressScale({required Widget child, VoidCallback? onTap, double pressedScale = 0.97})`; `AppCard({required Widget child, EdgeInsetsGeometry padding = EdgeInsets.all(16), Color? color, VoidCallback? onTap})`; `ToneChip({required Tone tone})`; `AppButton({required String label, required VoidCallback? onPressed, AppButtonVariant variant = primary})` with `enum AppButtonVariant { primary, secondary, destructive }`; `SectionHeader({required String title, Widget? trailing})`; `Future<bool> confirmDestructive(BuildContext, {required String title, required String body, required String confirmLabel, required String cancelLabel})`; `RingMarkPainter({required List<Color> colors, double progress = 1, double strokeFraction = 0.2, double gapRadians = 0.9})` and `RingMark({required List<Color> colors, required double size, double progress = 1, double strokeFraction = 0.2})`.
- Consumes: `AppColors`, `ToneColors`, `AppSpacing`, `AppRadii`, `AppMotion` from Tasks 3–4; `Tone`.

- [ ] **Step 1: Write the failing tests**

**Create `test/shared/widgets/shared_widgets_test.dart`**

```dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/shared/widgets/app_button.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:energy_clock/shared/widgets/press_scale.dart';
import 'package:energy_clock/shared/widgets/ring_mark.dart';
import 'package:energy_clock/shared/widgets/section_header.dart';
import 'package:energy_clock/shared/widgets/tone_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.light,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('AppButton', () {
    testWidgets('a primary button is ink with onInk text and is tappable', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(AppButton(label: 'Save', onPressed: () => taps++)),
      );

      final text = tester.widget<Text>(find.text('Save'));
      expect(text.style!.color, AppColors.light.onInk);
      final decoration = tester.widget<DecoratedBox>(
        find.ancestor(
          of: find.text('Save'),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(
        (decoration.decoration as BoxDecoration).color,
        AppColors.light.ink,
      );
      expect(tester.getSize(find.byType(AppButton)).height, greaterThanOrEqualTo(56));

      await tester.tap(find.text('Save'));
      expect(taps, 1);
    });

    testWidgets('a disabled button is faded and does nothing', (tester) async {
      await tester.pumpWidget(host(const AppButton(label: 'Save', onPressed: null)));
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.38);
      await tester.tap(find.text('Save'));
      // No exception and no callback to observe: the button is inert.
    });

    testWidgets('a destructive button uses the danger colour', (tester) async {
      await tester.pumpWidget(
        host(
          AppButton(
            label: 'Delete',
            variant: AppButtonVariant.destructive,
            onPressed: () {},
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.text('Delete')).style!.color,
        AppColors.light.danger,
      );
    });

    testWidgets('a secondary button is a faint ink fill with ink text', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          AppButton(
            label: 'Edit',
            variant: AppButtonVariant.secondary,
            onPressed: () {},
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.text('Edit')).style!.color,
        AppColors.light.ink,
      );
    });

    testWidgets('exposes button semantics with its label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(AppButton(label: 'Save', onPressed: () {})));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Save')),
        matchesSemantics(
          label: 'Save',
          isButton: true,
          hasTapAction: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      handle.dispose();
    });
  });

  group('PressScale', () {
    testWidgets('scales down while pressed and back on release', (tester) async {
      await tester.pumpWidget(
        host(
          PressScale(
            onTap: () {},
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );
      double scale() => tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
      expect(scale(), 1);

      final gesture = await tester.startGesture(tester.getCenter(find.byType(PressScale)));
      await tester.pump();
      expect(scale(), 0.97);
      await gesture.up();
      await tester.pump();
      expect(scale(), 1);
    });

    testWidgets('does not scale when reduced motion is on', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: PressScale(
                onTap: () {},
                child: const SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(tester.getCenter(find.byType(PressScale)));
      await tester.pump();
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
      await gesture.up();
    });
  });

  group('AppCard', () {
    testWidgets('has a shadow in light mode and a border in dark mode', (
      tester,
    ) async {
      await tester.pumpWidget(host(const AppCard(child: Text('hi'))));
      var shape = tester.widget<DecoratedBox>(
        find.descendant(of: find.byType(AppCard), matching: find.byType(DecoratedBox)).first,
      ).decoration as ShapeDecoration;
      expect(shape.shadows, isNotEmpty);
      expect(shape.color, AppColors.light.surface);

      await tester.pumpWidget(host(const AppCard(child: Text('hi')), theme: AppTheme.dark));
      // A theme change animates, so let it finish before reading the card.
      await tester.pumpAndSettle();
      shape = tester.widget<DecoratedBox>(
        find.descendant(of: find.byType(AppCard), matching: find.byType(DecoratedBox)).first,
      ).decoration as ShapeDecoration;
      expect(shape.shadows, isEmpty);
      final border = shape.shape as RoundedRectangleBorder;
      expect(border.side.color, AppColors.dark.outline);
    });

    testWidgets('a custom colour overrides the fill and onTap makes it tappable', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          AppCard(
            color: AppColors.light.ink,
            onTap: () => taps++,
            child: const Text('tap me'),
          ),
        ),
      );
      await tester.tap(find.text('tap me'));
      expect(taps, 1);
    });
  });

  testWidgets('ToneChip shows the tone name on its soft fill', (tester) async {
    await tester.pumpWidget(host(const ToneChip(tone: Tone.life)));
    expect(find.text('Life'), findsOneWidget);
    final text = tester.widget<Text>(find.text('Life'));
    expect(text.style!.color, isNotNull);
  });

  testWidgets('SectionHeader shows its title and optional trailing widget', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const SectionHeader(title: 'Plan', trailing: Text('See all'))),
    );
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
  });

  group('RingMark', () {
    test('paints three arcs without throwing and repaints on change', () {
      const painter = RingMarkPainter(
        colors: [Color(0xFF111111), Color(0xFF222222), Color(0xFF333333)],
      );
      const other = RingMarkPainter(
        colors: [Color(0xFF111111), Color(0xFF222222), Color(0xFF333333)],
        progress: 0.5,
      );
      expect(painter.shouldRepaint(other), isTrue);
      expect(
        painter.shouldRepaint(
          const RingMarkPainter(
            colors: [Color(0xFF111111), Color(0xFF222222), Color(0xFF333333)],
          ),
        ),
        isFalse,
      );
    });

    testWidgets('is decorative: it adds nothing to the semantics tree', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: RingMark(
            colors: [Color(0xFF111111), Color(0xFF222222), Color(0xFF333333)],
            size: 48,
          ),
        ),
      );
      expect(find.semantics.byLabel(RegExp('.')), findsNothing);
      handle.dispose();
    });
  });
}
```

**Create `test/shared/widgets/adaptive_dialog_test.dart`**

```dart
import 'package:energy_clock/shared/widgets/adaptive_dialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<bool?> openDialog(WidgetTester tester) async {
  bool? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await confirmDestructive(
                context,
                title: 'Delete this event?',
                body: "This can't be undone.",
                confirmLabel: 'Delete',
                cancelLabel: 'Cancel',
              );
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
  testWidgets('Material: confirming returns true', (tester) async {
    await openDialog(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Delete this event?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Material: cancelling returns false', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await confirmDestructive(
                  context,
                  title: 'Delete this event?',
                  body: 'Body',
                  confirmLabel: 'Delete',
                  cancelLabel: 'Cancel',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('iOS: renders the native alert with a destructive action', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await confirmDestructive(
                  context,
                  title: 'Delete this event?',
                  body: 'Body',
                  confirmLabel: 'Delete',
                  cancelLabel: 'Cancel',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    final destructive = tester.widget<CupertinoDialogAction>(
      find.widgetWithText(CupertinoDialogAction, 'Delete'),
    );
    expect(destructive.isDestructiveAction, isTrue);

    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Delete'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL — the shared widget files do not exist yet
flutter test test/shared/widgets
```

- [ ] **Step 3: Write the components**

**Create `lib/shared/widgets/press_scale.dart`**

```dart
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:flutter/widgets.dart';

/// Gives a tappable child a subtle press-in scale, in place of a splash.
/// Skipped when the system asks for reduced motion.
class PressScale extends StatefulWidget {
  const PressScale({
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed == pressed || widget.onTap == null) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed && !reduceMotion ? widget.pressedScale : 1,
        duration: reduceMotion ? Duration.zero : AppMotion.fast,
        curve: AppMotion.standard,
        child: widget.child,
      ),
    );
  }
}
```

**Create `lib/shared/widgets/app_card.dart`**

```dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/shared/widgets/press_scale.dart';
import 'package:flutter/material.dart';

/// A rounded card on the `surface` colour. Light mode lifts it with a soft
/// shadow; dark mode draws a hairline border instead.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Overrides the fill, for example with a tone colour on the Now card.
  final Color? color;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
      side: colors.isDark ? BorderSide(color: colors.outline) : BorderSide.none,
    );
    final card = DecoratedBox(
      decoration: ShapeDecoration(
        color: color ?? colors.surface,
        shape: shape,
        shadows: colors.cardShadow,
      ),
      child: Padding(padding: padding, child: child),
    );
    return onTap == null ? card : PressScale(onTap: onTap, child: card);
  }
}
```

**Create `lib/shared/widgets/tone_chip.dart`**

```dart
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:flutter/material.dart';

/// A pill naming a tone: its `soft` fill, a `solid` dot, and `deep` text.
class ToneChip extends StatelessWidget {
  const ToneChip({required this.tone, super.key});

  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.toneColors.paletteFor(tone);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.soft,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: palette.solid,
                shape: BoxShape.circle,
              ),
              child: const SizedBox.square(dimension: 8),
            ),
            const SizedBox(width: 6),
            Text(
              tone.label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge!.copyWith(color: palette.deep),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Create `lib/shared/widgets/app_button.dart`**

```dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/shared/widgets/press_scale.dart';
import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary, destructive }

/// A tall, full-width button. Primary is `ink` with `onInk` text, secondary is
/// a faint ink fill, destructive is text in the `danger` colour.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final enabled = onPressed != null;
    final (fill, foreground) = switch (variant) {
      AppButtonVariant.primary => (colors.ink, colors.onInk),
      AppButtonVariant.secondary => (
        colors.ink.withValues(alpha: 0.08),
        colors.ink,
      ),
      AppButtonVariant.destructive => (AppColors.transparent, colors.danger),
    };

    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        excludeSemantics: true,
        onTap: onPressed,
        child: PressScale(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall!.copyWith(color: foreground),
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

**Create `lib/shared/widgets/section_header.dart`**

```dart
import 'package:flutter/material.dart';

/// A section title with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
```

**Create `lib/shared/widgets/adaptive_dialog.dart`**

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Asks the user to confirm a destructive action. Shows the native alert on
/// iOS and a Material dialog on every other platform. Returns true only when
/// the user confirms.
///
/// The choice is an explicit check for iOS, not `AlertDialog.adaptive`, which
/// also picks the iOS style on macOS. `flutter test` reports the host's
/// platform, so on a Mac the adaptive widget would change what tests see; this
/// app only ships to iOS, so only iOS gets the native alert.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
}) async {
  final isIos = Theme.of(context).platform == TargetPlatform.iOS;

  final result = isIos
      ? await showCupertinoDialog<bool>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(cancelLabel),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        )
      : await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(cancelLabel),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        );
  return result ?? false;
}
```

**Create `lib/shared/widgets/ring_mark.dart`**

```dart
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Draws a ring made of arcs, one per colour, with rounded ends and a gap
/// between them. Used for the Clock tab icon, the onboarding illustration, and
/// the generated app icon and launch logo.
class RingMarkPainter extends CustomPainter {
  const RingMarkPainter({
    required this.colors,
    this.progress = 1,
    this.strokeFraction = 0.2,
    this.gapRadians = 0.9,
  });

  /// One arc per colour, clockwise from the top.
  final List<Color> colors;

  /// 0 to 1: how much of each arc is drawn, for a sweep-in animation.
  final double progress;

  /// Stroke width as a fraction of the diameter.
  final double strokeFraction;

  /// Gap between neighbouring arcs, measured between their centrelines. Round
  /// caps eat into it, so keep it well above `strokeFraction * 2.5`.
  final double gapRadians;

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.isEmpty) return;
    final stroke = size.shortestSide * strokeFraction;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.shortestSide - stroke) / 2,
    );
    final arc = (2 * math.pi - colors.length * gapRadians) / colors.length;
    for (var i = 0; i < colors.length; i++) {
      final start = -math.pi / 2 + i * (arc + gapRadians) + gapRadians / 2;
      canvas.drawArc(
        rect,
        start,
        arc * progress,
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(RingMarkPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.strokeFraction != strokeFraction ||
      oldDelegate.gapRadians != gapRadians ||
      !_sameColors(oldDelegate.colors, colors);

  static bool _sameColors(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// A square [RingMarkPainter]. Decorative, so hidden from screen readers.
class RingMark extends StatelessWidget {
  const RingMark({
    required this.colors,
    required this.size,
    this.progress = 1,
    this.strokeFraction = 0.2,
    super.key,
  });

  final List<Color> colors;
  final double size;
  final double progress;
  final double strokeFraction;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: RingMarkPainter(
          colors: colors,
          progress: progress,
          strokeFraction: strokeFraction,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
# expect: PASS
flutter test test/shared/widgets
```

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets test/shared/widgets
git commit -m "feat: add shared card, chip, button, header, dialog, and ring mark

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Floating tab bar and tab shell

Replaces the Material `NavigationBar`. The selected tab is an ink pill showing its icon and label; the others are icons only. All four tabs stay alive once visited and are built lazily the first time they are selected.

**Files:**
- Create: `lib/app/navigation/tab_bar_inset.dart`, `tab_dial_icon.dart`, `app_tab_bar.dart`
- Replace: `lib/app/navigation/tab_scaffold.dart`, `test/app/tab_scaffold_test.dart`
- Test: `test/app/app_tab_bar_test.dart`

**Interfaces:**
- Produces: `TabBarInset.of(BuildContext)` → `double` (0 when absent); `TabDialIcon({required bool selected, required Color color, double size = 24})`; `AppTabBar({required int selectedIndex, required ValueChanged<int> onSelected})` with `AppTabBar.height` (64), `AppTabBar.bottomMargin` (12), `AppTabBar.tabCount` (4); tab items are keyed `ValueKey('tab-0')` … `ValueKey('tab-3')`.
- Consumes: `AppColors`, `ToneColors`, `RingMark`, `PressScale`, `ContentWidth`, `ContentWidths.tabBar`, `Strings.tabSemantics`, `Strings.tab*`.

- [ ] **Step 1: Write the failing tests**

**Create `test/app/app_tab_bar_test.dart`**

```dart
import 'package:energy_clock/app/navigation/app_tab_bar.dart';
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host({required int selected, required ValueChanged<int> onSelected}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: AppTabBar(selectedIndex: selected, onSelected: onSelected),
      ),
    ),
  );
}

void main() {
  testWidgets('only the selected tab shows its label', (tester) async {
    await tester.pumpWidget(host(selected: 1, onSelected: (_) {}));

    expect(find.text(Strings.tabCalendar), findsOneWidget);
    expect(find.text(Strings.tabClock), findsNothing);
    expect(find.text(Strings.tabStats), findsNothing);
    expect(find.text(Strings.tabProfile), findsNothing);
  });

  testWidgets('tapping an item reports its index', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(host(selected: 0, onSelected: taps.add));

    await tester.tap(find.byKey(const ValueKey('tab-2')));
    await tester.tap(find.byKey(const ValueKey('tab-3')));
    expect(taps, [2, 3]);
  });

  testWidgets('every item is at least 44 x 44', (tester) async {
    await tester.pumpWidget(host(selected: 0, onSelected: (_) {}));
    for (var i = 0; i < 4; i++) {
      final size = tester.getSize(find.byKey(ValueKey('tab-$i')));
      expect(size.width, greaterThanOrEqualTo(44), reason: 'tab $i width');
      expect(size.height, greaterThanOrEqualTo(44), reason: 'tab $i height');
    }
  });

  testWidgets('semantics report selected state and position', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(selected: 0, onSelected: (_) {}));

    expect(
      tester.getSemantics(find.bySemanticsLabel('Clock, tab 1 of 4')),
      matchesSemantics(
        label: 'Clock, tab 1 of 4',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Profile, tab 4 of 4')),
      matchesSemantics(
        label: 'Profile, tab 4 of 4',
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('the pill is capped at 480 pt and centred on a wide window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(selected: 0, onSelected: (_) {}));
    final pill = find
        .descendant(
          of: find.byType(AppTabBar),
          matching: find.byType(DecoratedBox),
        )
        .first;
    // 480 pt of bar, less 16 pt of padding on each side.
    expect(tester.getSize(pill).width, lessThanOrEqualTo(480));
    expect(tester.getCenter(pill).dx, closeTo(600, 0.5));
  });

  testWidgets('the pill fills a narrow window less its side padding', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(selected: 0, onSelected: (_) {}));
    final pill = find
        .descendant(
          of: find.byType(AppTabBar),
          matching: find.byType(DecoratedBox),
        )
        .first;
    expect(tester.getSize(pill).width, 375 - 32);
  });

  testWidgets('large text does not overflow the bar', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: AppTabBar(selectedIndex: 1, onSelected: (_) {}),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
```

**Replace `test/app/tab_scaffold_test.dart`**

```dart
import 'package:energy_clock/app/navigation/tab_bar_inset.dart';
import 'package:energy_clock/app/navigation/tab_scaffold.dart';
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/clock/clock_screen.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/dial_pump.dart';
import '../support/fake_event_repository.dart';

void main() {
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
      child: MaterialApp(theme: AppTheme.light, home: const TabScaffold()),
    );
  }

  testWidgets('starts on Clock with four tabs', (tester) async {
    await tester.pumpWidget(harness());
    await pumpDial(tester);

    for (var i = 0; i < 4; i++) {
      expect(find.byKey(ValueKey('tab-$i')), findsOneWidget);
    }
    expect(find.byType(ClockScreen), findsOneWidget);
    expect(find.text(Strings.tabClock), findsOneWidget);
  });

  testWidgets('tapping a tab switches the screen', (tester) async {
    await tester.pumpWidget(harness());
    await pumpDial(tester);

    await tester.tap(find.byKey(const ValueKey('tab-2')));
    await pumpDial(tester);

    expect(find.text(Strings.comingSoon(Strings.tabStats)), findsOneWidget);
    expect(find.text(Strings.tabStats), findsOneWidget);
    expect(find.text(Strings.tabClock), findsNothing);
  });

  testWidgets('tabs are built the first time they are visited', (tester) async {
    await tester.pumpWidget(harness());
    await pumpDial(tester);

    expect(find.text(Strings.comingSoon(Strings.tabStats)), findsNothing);
    expect(find.text(Strings.comingSoon(Strings.tabCalendar)), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await pumpDial(tester);
    expect(find.text(Strings.comingSoon(Strings.tabCalendar)), findsOneWidget);
  });

  testWidgets('a visited tab keeps its state when you switch away and back', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await pumpDial(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TabScaffold)),
    );
    container.read(selectedDateProvider.notifier).select(DateTime(2031, 5, 4));
    await pumpDial(tester);

    await tester.tap(find.byKey(const ValueKey('tab-3')));
    await pumpDial(tester);
    await tester.tap(find.byKey(const ValueKey('tab-0')));
    await pumpDial(tester);

    expect(find.byType(ClockScreen), findsOneWidget);
    expect(container.read(selectedDateProvider), DateTime(2031, 5, 4));
  });

  testWidgets('screens receive the space the floating bar covers', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await pumpDial(tester);

    final inset = TabBarInset.of(tester.element(find.byType(ClockScreen)));
    expect(inset, greaterThanOrEqualTo(64 + 12));
  });

  testWidgets('TabBarInset.of is zero outside a tab shell', (tester) async {
    late double inset;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            inset = TabBarInset.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(inset, 0);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL — 'package:energy_clock/app/navigation/app_tab_bar.dart' and 'tab_bar_inset.dart' do not exist
flutter test test/app
```

- [ ] **Step 3: Write the tab bar and the shell**

**Create `lib/app/navigation/tab_bar_inset.dart`**

```dart
import 'package:flutter/widgets.dart';

/// Tells screens how much bottom space the floating tab bar covers, so they can
/// pad their content. Zero when there is no tab shell above.
class TabBarInset extends InheritedWidget {
  const TabBarInset({required this.height, required super.child, super.key});

  final double height;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabBarInset>()?.height ?? 0;

  @override
  bool updateShouldNotify(TabBarInset oldWidget) => oldWidget.height != height;
}
```

**Create `lib/app/navigation/tab_dial_icon.dart`**

```dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/shared/widgets/ring_mark.dart';
import 'package:flutter/widgets.dart';

/// The Clock tab icon: a tiny three-arc ring. Unselected it is one flat
/// [color]. Selected, it sits on the ink pill, so it uses the opposite theme's
/// tone colours to stay vivid against it.
class TabDialIcon extends StatelessWidget {
  const TabDialIcon({
    required this.selected,
    required this.color,
    this.size = 24,
    super.key,
  });

  final bool selected;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tones = context.appColors.isDark ? ToneColors.light : ToneColors.dark;
    final arcs = selected
        ? [tones.focus.solid, tones.life.solid, tones.inbox.solid]
        : [color, color, color];
    return RingMark(colors: arcs, size: size, strokeFraction: 0.22);
  }
}
```

**Create `lib/app/navigation/app_tab_bar.dart`**

```dart
import 'dart:async';

import 'package:energy_clock/app/navigation/tab_dial_icon.dart';
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/shared/layout/content_width.dart';
import 'package:energy_clock/shared/widgets/press_scale.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The floating pill that switches between the four tabs. The selected tab is
/// an ink pill with its icon and label; the others show only their icon.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  static const double height = 64;
  static const double bottomMargin = 12;
  static const int tabCount = 4;

  static const List<String> _labels = [
    Strings.tabClock,
    Strings.tabCalendar,
    Strings.tabStats,
    Strings.tabProfile,
  ];

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  Widget _icon(int index, bool selected, Color color) => switch (index) {
    0 => TabDialIcon(selected: selected, color: color),
    1 => Icon(CupertinoIcons.calendar, color: color, size: 24),
    2 => Icon(
      selected ? CupertinoIcons.chart_bar_alt_fill : CupertinoIcons.chart_bar,
      color: color,
      size: 24,
    ),
    _ => Icon(
      selected ? CupertinoIcons.person_fill : CupertinoIcons.person,
      color: color,
      size: 24,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ContentWidth(
      maxWidth: ContentWidths.tabBar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        // Tab labels are short and the bar is a fixed size, so they scale up
        // to 120% and no further.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: colors.surface,
              shape: StadiumBorder(
                side: colors.isDark
                    ? BorderSide(color: colors.outline)
                    : BorderSide.none,
              ),
              shadows: colors.barShadow,
            ),
            child: SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    for (var i = 0; i < tabCount; i++)
                      Expanded(
                        flex: i == selectedIndex ? 2 : 1,
                        child: _TabItem(
                          key: ValueKey('tab-$i'),
                          label: _labels[i],
                          position: i + 1,
                          selected: i == selectedIndex,
                          icon: (color) => _icon(i, i == selectedIndex, color),
                          onTap: () => onSelected(i),
                        ),
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

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.position,
    required this.selected,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String label;
  final int position;
  final bool selected;
  final Widget Function(Color color) icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final foreground = selected ? colors.onInk : colors.muted;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      selected: selected,
      label: Strings.tabSemantics(label, position, AppTabBar.tabCount),
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        onTap: () {
          if (!selected) unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        child: AnimatedContainer(
          duration: reduceMotion ? Duration.zero : AppMotion.base,
          curve: AppMotion.standard,
          decoration: BoxDecoration(
            color: selected ? colors.ink : AppColors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon(foreground),
              if (selected) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge!.copyWith(color: foreground),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

**Replace `lib/app/navigation/tab_scaffold.dart`**

```dart
import 'package:energy_clock/app/navigation/app_tab_bar.dart';
import 'package:energy_clock/app/navigation/tab_bar_inset.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/features/calendar/calendar_screen.dart';
import 'package:energy_clock/features/clock/clock_screen.dart';
import 'package:energy_clock/features/progress/profile_screen.dart';
import 'package:energy_clock/features/stats/stats_screen.dart';
import 'package:flutter/material.dart';

/// Hosts the four tabs behind a floating bar. Each tab is built the first time
/// it is selected and then kept alive, so switching back keeps its state.
class TabScaffold extends StatefulWidget {
  const TabScaffold({super.key});

  @override
  State<TabScaffold> createState() => _TabScaffoldState();
}

class _TabScaffoldState extends State<TabScaffold> {
  int _index = 0;
  final Set<int> _visited = {0};

  static Widget _screen(int index) => switch (index) {
    0 => const ClockScreen(),
    1 => const CalendarScreen(),
    2 => const StatsScreen(),
    _ => const ProfileScreen(),
  };

  void _select(int index) {
    setState(() {
      _index = index;
      _visited.add(index);
    });
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
                      _visited.contains(i) ? _screen(i) : const SizedBox.shrink(),
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

- [ ] **Step 4: Run the tests to verify they pass**

```bash
# expect: PASS
flutter test test/app && flutter analyze
```

- [ ] **Step 5: Commit**

```bash
git add lib/app/navigation test/app/app_tab_bar_test.dart test/app/tab_scaffold_test.dart
git commit -m "feat: floating tab bar with lazily built, kept-alive tabs

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Guard against hard-coded colours

The spec forbids hard-coded colours in feature code. This test makes that a rule the build enforces. Today's feature code already passes it.

**Files:**
- Test: `test/architecture/no_hardcoded_colors_test.dart`

**Interfaces:**
- Consumes: nothing. Produces: a test that fails when any `lib/features/**.dart` file contains `Color(0x` or `Colors.` as a whole word.

- [ ] **Step 1: Write the test**

**Create `test/architecture/no_hardcoded_colors_test.dart`**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Feature code gets every colour from the theme (`context.appColors`,
/// `context.toneColors`, `AppColors.transparent`, or the colour scheme). The
/// word boundaries stop identifiers such as `toneColors.` from matching.
final RegExp _hardCoded = RegExp(r'\bColor\(0x|\bColors\.');

void main() {
  test('feature code never hard-codes a colour', () {
    final offenders = <String>[];
    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart') || entity.path.endsWith('.g.dart')) {
        continue;
      }
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_hardCoded.hasMatch(lines[i])) {
          offenders.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Use context.appColors / context.toneColors / AppColors.transparent '
          'instead of a literal colour:\n${offenders.join('\n')}',
    );
  });

  test('the pattern matches real violations and ignores toneColors', () {
    expect(_hardCoded.hasMatch('color: Colors.red,'), isTrue);
    expect(_hardCoded.hasMatch('const Color(0xFF123456)'), isTrue);
    expect(_hardCoded.hasMatch('toneColors.fillFor(tone)'), isFalse);
    expect(_hardCoded.hasMatch('context.toneColors.focus'), isFalse);
  });
}
```

- [ ] **Step 2: Run the test**

```bash
# expect: PASS — feature code is already clean
flutter test test/architecture/no_hardcoded_colors_test.dart
```

- [ ] **Step 3: Run the whole suite and the analyzer — this is the end of Stage 1**

```bash
# expect: PASS
flutter analyze && flutter test
```

- [ ] **Step 4: Commit**

```bash
git add test/architecture
git commit -m "test: forbid hard-coded colours in feature code

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```


---

## Stage 2 — Dial v2

### Task 10: Ring-count-aware dial geometry

The face grows when fewer rings are in use: about 0.805 of the outer radius with one ring, 0.677 with two, 0.589 with three. Three rings equals the geometry the app has today, so today's size is the worst case. Touches get a 12 pt slop, and where two rings' reach overlaps the nearer centre wins.

Every existing geometry test keeps passing unchanged, because `ringCount` defaults to `maxRings` and `hitSlop` defaults to 0 for hand-built geometries.

**Files:**
- Replace: `lib/core/geometry/dial_geometry.dart`
- Test: `test/core/geometry/dial_geometry_rings_test.dart`

**Interfaces:**
- Produces: `DialGeometry` gains `ringCount` (int, default `maxRings`) and `hitSlop` (double, default 0); `DialGeometry.fitted(Size, {int ringCount = 3, double? maxRadius, double hitSlop = DialGeometry.defaultHitSlop})`; `DialGeometry.lerp(a, b, t)`; `DialGeometry.defaultHitSlop` (12). `orbitOuterRadius` equals the outer radius for every ring count; `ringAtPoint` and `isInOrbitBand` honour `hitSlop`.
- Consumes: `minutesPerDay` from `day_time.dart`.

- [ ] **Step 1: Write the failing test**

**Create `test/core/geometry/dial_geometry_rings_test.dart`**

```dart
import 'dart:ui';

import 'package:energy_clock/core/geometry/dial_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A 400-wide box leaves an outer radius of 192.
  const box = Size(400, 400);
  const outer = 192.0;

  group('fitted for each ring count', () {
    test('the face fills 0.805, 0.677 and 0.589 of the outer radius', () {
      expect(DialGeometry.fitted(box, ringCount: 1).faceRadius, closeTo(outer * 0.805, 1e-9));
      expect(DialGeometry.fitted(box, ringCount: 2).faceRadius, closeTo(outer * 0.677, 1e-9));
      expect(DialGeometry.fitted(box, ringCount: 3).faceRadius, closeTo(outer * 0.589, 1e-9));
    });

    test('three rings is the default and matches the original geometry', () {
      final geometry = DialGeometry.fitted(box);
      expect(geometry.ringCount, 3);
      expect(geometry.ringWidth, closeTo(outer * 0.11, 1e-9));
      expect(geometry.ringGap, closeTo(outer * 0.018, 1e-9));
      expect(geometry.firstRingInset, closeTo(outer * 0.045, 1e-9));
      expect(geometry.faceRadius, closeTo(outer * 0.589, 1e-9));
    });

    test('fewer rings give a bigger face and thicker arcs', () {
      final one = DialGeometry.fitted(box, ringCount: 1);
      final two = DialGeometry.fitted(box, ringCount: 2);
      final three = DialGeometry.fitted(box, ringCount: 3);
      expect(one.faceRadius, greaterThan(two.faceRadius));
      expect(two.faceRadius, greaterThan(three.faceRadius));
      expect(one.ringWidth, greaterThan(two.ringWidth));
      expect(two.ringWidth, greaterThan(three.ringWidth));
    });

    test('the outermost ring always ends at the outer radius', () {
      for (var count = 1; count <= 3; count++) {
        final geometry = DialGeometry.fitted(box, ringCount: count);
        expect(geometry.orbitOuterRadius, closeTo(outer, 1e-9), reason: '$count rings');
        expect(geometry.ringCount, count);
      }
    });

    test('maxRadius caps the dial and keeps it centred in the box', () {
      final geometry = DialGeometry.fitted(
        const Size(1000, 800),
        ringCount: 1,
        maxRadius: 340,
      );
      expect(geometry.orbitOuterRadius, closeTo(340, 1e-9));
      expect(geometry.center, const Offset(500, 400));
    });

    test('a roomy box is limited by its shorter side', () {
      final geometry = DialGeometry.fitted(const Size(800, 400), ringCount: 1);
      expect(geometry.orbitOuterRadius, closeTo(192, 1e-9));
    });

    test('rejects a ring count outside 1 to 3', () {
      expect(() => DialGeometry.fitted(box, ringCount: 0), throwsAssertionError);
      expect(() => DialGeometry.fitted(box, ringCount: 4), throwsAssertionError);
    });

    test('the hit slop defaults to 12', () {
      expect(DialGeometry.fitted(box).hitSlop, DialGeometry.defaultHitSlop);
      expect(DialGeometry.defaultHitSlop, 12);
    });
  });

  group('touch targets', () {
    test('a one-ring dial on a small phone still has 44 pt targets', () {
      // iPhone SE: about 330 pt of dial box, so an outer radius near 157.
      final geometry = DialGeometry.fitted(const Size(330, 330), ringCount: 1);
      final band =
          geometry.orbitOuterRadius -
          geometry.orbitInnerRadius +
          2 * geometry.hitSlop;
      final ring = geometry.ringWidth + 2 * geometry.hitSlop;
      expect(band, greaterThanOrEqualTo(44));
      expect(ring, greaterThanOrEqualTo(44));
    });
  });

  group('hit testing with slop', () {
    // Rings centred at 118, 142 and 166 from the centre, each 20 thick.
    const geometry = DialGeometry(
      center: Offset(200, 200),
      faceRadius: 100,
      firstRingInset: 8,
      ringWidth: 20,
      ringGap: 4,
      hitSlop: 6,
    );

    Offset at(double radius) => Offset(200 + radius, 200);

    test('a point inside a ring still maps to it', () {
      expect(geometry.ringAtPoint(at(118)), 0);
      expect(geometry.ringAtPoint(at(142)), 1);
      expect(geometry.ringAtPoint(at(166)), 2);
    });

    test('a point in the gap goes to the nearer ring centre', () {
      // Radius 131 is 13 from ring 0 and 11 from ring 1; both are in reach.
      expect(geometry.ringAtPoint(at(131)), 1);
      expect(geometry.ringAtPoint(at(129)), 0);
    });

    test('a point just off the outer ring still counts', () {
      expect(geometry.ringAtPoint(at(180)), 2);
      expect(geometry.ringAtPoint(at(183)), isNull);
    });

    test('a point just inside the orbit still counts for ring 0', () {
      expect(geometry.ringAtPoint(at(103)), 0);
      expect(geometry.ringAtPoint(at(100)), isNull);
    });

    test('with no slop a gap is a miss, as before', () {
      const strict = DialGeometry(
        center: Offset(200, 200),
        faceRadius: 100,
        firstRingInset: 8,
        ringWidth: 20,
        ringGap: 4,
      );
      expect(strict.ringAtPoint(at(130)), isNull);
      expect(strict.ringAtPoint(at(127.5)), 0);
    });

    test('the creation band is widened by the slop on both sides', () {
      // Orbit runs 108 to 176; with slop 6 the band is 102 to 182.
      expect(geometry.isInOrbitBand(at(101)), isFalse);
      expect(geometry.isInOrbitBand(at(103)), isTrue);
      expect(geometry.isInOrbitBand(at(181)), isTrue);
      expect(geometry.isInOrbitBand(at(183)), isFalse);
    });

    test('a one-ring geometry has no ring 1 or 2 to hit', () {
      const one = DialGeometry(
        center: Offset(200, 200),
        faceRadius: 100,
        firstRingInset: 8,
        ringWidth: 20,
        ringGap: 4,
        ringCount: 1,
      );
      expect(one.ringAtPoint(at(118)), 0);
      expect(one.ringAtPoint(at(142)), isNull);
      expect(one.orbitOuterRadius, 128);
    });
  });

  group('lerp', () {
    test('returns the end sizes at t = 0 and t = 1', () {
      final a = DialGeometry.fitted(box, ringCount: 1);
      final b = DialGeometry.fitted(box, ringCount: 3);
      // The ring count of the result is always the target's, so at t = 0 only
      // the sizes match the start.
      final start = DialGeometry.lerp(a, b, 0);
      expect(start.faceRadius, a.faceRadius);
      expect(start.ringWidth, a.ringWidth);
      expect(start.ringGap, a.ringGap);
      expect(start.firstRingInset, a.firstRingInset);
      expect(DialGeometry.lerp(a, b, 1), b);
    });

    test('blends the sizes halfway at t = 0.5', () {
      final a = DialGeometry.fitted(box, ringCount: 1);
      final b = DialGeometry.fitted(box, ringCount: 3);
      final mid = DialGeometry.lerp(a, b, 0.5);
      expect(mid.faceRadius, closeTo((a.faceRadius + b.faceRadius) / 2, 1e-9));
      expect(mid.ringWidth, closeTo((a.ringWidth + b.ringWidth) / 2, 1e-9));
      expect(mid.center, a.center);
    });

    test('keeps the target ring count for hit testing', () {
      final a = DialGeometry.fitted(box, ringCount: 1);
      final b = DialGeometry.fitted(box, ringCount: 3);
      expect(DialGeometry.lerp(a, b, 0.3).ringCount, 3);
    });
  });

  test('equality and hashCode include the new fields', () {
    final a = DialGeometry.fitted(box, ringCount: 2);
    final b = DialGeometry.fitted(box, ringCount: 2);
    final c = DialGeometry.fitted(box, ringCount: 3);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
    expect(
      a,
      isNot(DialGeometry.fitted(box, ringCount: 2, hitSlop: 0)),
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
# expect: FAIL — 'ringCount', 'hitSlop', 'lerp' and the named 'fitted' parameters do not exist
flutter test test/core/geometry/dial_geometry_rings_test.dart
```

- [ ] **Step 3: Replace the geometry**

**Replace `lib/core/geometry/dial_geometry.dart`**

```dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:energy_clock/core/time/day_time.dart';

/// Pure polar math for the 24-hour dial. Deliberately free of any rendering
/// dependency beyond [Offset] so it can be unit-tested directly — testing
/// math is trivial where testing a painter is not.
class DialGeometry {
  const DialGeometry({
    required this.center,
    required this.faceRadius,
    required this.firstRingInset,
    required this.ringWidth,
    required this.ringGap,
    this.ringCount = maxRings,
    this.hitSlop = 0,
  });

  /// Overlapping events beyond this many rings are refused.
  static const int maxRings = 3;

  /// How far a touch may miss a ring or the creation band and still count, in
  /// logical pixels. [fitted] uses this; hand-built geometries default to 0.
  static const double defaultHitSlop = 12;

  static const double _quarterTurn = math.pi / 2;
  static const double _fullTurn = math.pi * 2;

  final Offset center;

  /// Radius of the clock face itself.
  final double faceRadius;

  /// Gap between the face edge and the inner edge of ring 0.
  final double firstRingInset;

  /// Thickness of each event ring.
  final double ringWidth;

  /// Gap between adjacent rings.
  final double ringGap;

  /// How many rings this geometry has room for, 1 to [maxRings]. [fitted]
  /// sizes the face to leave exactly this many.
  final int ringCount;

  /// Extra reach on each side of every ring and of the creation band when hit
  /// testing. Where two rings' reach overlaps, the ring with the nearer centre
  /// wins.
  final double hitSlop;

  /// Radians for a minute of day, with minute 0 at the top and the day
  /// running clockwise.
  double angleForMinute(double minute) =>
      minute / minutesPerDay * _fullTurn - _quarterTurn;

  /// Inverse of [angleForMinute], normalised into 0–1439.
  int minuteForAngle(double angle) {
    final normalised = (angle + _quarterTurn) % _fullTurn;
    final positive = normalised < 0 ? normalised + _fullTurn : normalised;
    final minute = (positive / _fullTurn * minutesPerDay).round();
    return minute % minutesPerDay;
  }

  /// The minute of day the dial points at for [point], 0–1439.
  int minuteAtPoint(Offset point) {
    final delta = point - center;
    return minuteForAngle(math.atan2(delta.dy, delta.dx));
  }

  double radiusAtPoint(Offset point) => (point - center).distance;

  /// Inner edge of ring 0.
  double get orbitInnerRadius => faceRadius + firstRingInset;

  /// Outer edge of the outermost ring. For a geometry built by [fitted] this
  /// is the dial's outer radius, whatever the ring count.
  double get orbitOuterRadius =>
      ringCenterRadius(ringCount - 1) + ringWidth / 2;

  /// Centreline radius of ring [index], counting outward from 0.
  double ringCenterRadius(int index) =>
      orbitInnerRadius + ringWidth / 2 + index * (ringWidth + ringGap);

  /// The ring nearest [point], or null when the point is further than half a
  /// ring width plus [hitSlop] from every ring's centreline.
  int? ringAtPoint(Offset point) {
    final radius = radiusAtPoint(point);
    int? best;
    var bestDistance = double.infinity;
    for (var index = 0; index < ringCount; index++) {
      final distance = (radius - ringCenterRadius(index)).abs();
      if (distance <= ringWidth / 2 + hitSlop && distance < bestDistance) {
        best = index;
        bestDistance = distance;
      }
    }
    return best;
  }

  /// True anywhere in the orbit band, gaps and slop included. This is the area
  /// that accepts a drag-to-create gesture.
  bool isInOrbitBand(Offset point) {
    final radius = radiusAtPoint(point);
    return radius >= orbitInnerRadius - hitSlop &&
        radius <= orbitOuterRadius + hitSlop;
  }

  /// The point at [radius] and [angle] from [center].
  Offset pointOnCircle(double radius, double angle) => Offset(
    center.dx + radius * math.cos(angle),
    center.dy + radius * math.sin(angle),
  );

  /// True when a label centred at [angle] would render upside-down if drawn
  /// with the outward-facing orientation used on the top half of the dial.
  ///
  /// Text following the outside of a circle inverts once it passes the
  /// horizontal, so labels below the centre are drawn flipped instead.
  ///
  /// The 1e-9 tolerance matches this file's other closeTo comparisons: at
  /// exactly 1080 minutes (due west), angleForMinute lands on math.pi, whose
  /// double representation is not exactly π, so math.sin of it is a small
  /// positive epsilon (~1.2e-16) rather than the mathematically-true zero. A
  /// bare `> 0` would misclassify that exact boundary as inverted.
  bool isLabelInverted(double angle) => math.sin(angle) > 1e-9;

  /// Ring thickness as a fraction of the outer radius, by ring count. Fewer
  /// rings mean thicker arcs and a bigger face; three rings reproduces the
  /// original Phase 1 proportions.
  static const Map<int, double> _ringWidthFactor = {1: 0.15, 2: 0.13, 3: 0.11};

  /// Derives every radius from the available box so the dial scales across
  /// screens from one source of truth. [ringCount] is how many rings are in
  /// use: the face takes whatever room the other rings leave. [maxRadius]
  /// caps the dial on very large windows; the dial stays centred in [size].
  static DialGeometry fitted(
    Size size, {
    int ringCount = maxRings,
    double? maxRadius,
    double hitSlop = defaultHitSlop,
  }) {
    assert(
      ringCount >= 1 && ringCount <= maxRings,
      'ringCount must be between 1 and $maxRings',
    );
    final available = size.shortestSide / 2 - 8;
    final outerRadius = maxRadius == null
        ? available
        : math.min(available, maxRadius);
    final ringWidth = outerRadius * _ringWidthFactor[ringCount]!;
    final ringGap = outerRadius * 0.018;
    final firstRingInset = outerRadius * 0.045;
    final faceRadius =
        outerRadius -
        firstRingInset -
        ringCount * ringWidth -
        (ringCount - 1) * ringGap;

    return DialGeometry(
      center: Offset(size.width / 2, size.height / 2),
      faceRadius: faceRadius,
      firstRingInset: firstRingInset,
      ringWidth: ringWidth,
      ringGap: ringGap,
      ringCount: ringCount,
      hitSlop: hitSlop,
    );
  }

  /// Blends two geometries for the resize animation. The result keeps [b]'s
  /// ring count, because hit testing always uses the target geometry.
  static DialGeometry lerp(DialGeometry a, DialGeometry b, double t) {
    return DialGeometry(
      center: Offset.lerp(a.center, b.center, t)!,
      faceRadius: lerpDouble(a.faceRadius, b.faceRadius, t)!,
      firstRingInset: lerpDouble(a.firstRingInset, b.firstRingInset, t)!,
      ringWidth: lerpDouble(a.ringWidth, b.ringWidth, t)!,
      ringGap: lerpDouble(a.ringGap, b.ringGap, t)!,
      ringCount: b.ringCount,
      hitSlop: lerpDouble(a.hitSlop, b.hitSlop, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DialGeometry &&
      other.center == center &&
      other.faceRadius == faceRadius &&
      other.firstRingInset == firstRingInset &&
      other.ringWidth == ringWidth &&
      other.ringGap == ringGap &&
      other.ringCount == ringCount &&
      other.hitSlop == hitSlop;

  @override
  int get hashCode => Object.hash(
    center,
    faceRadius,
    firstRingInset,
    ringWidth,
    ringGap,
    ringCount,
    hitSlop,
  );
}
```

- [ ] **Step 4: Run the new test, then every geometry and hit-testing test**

```bash
# expect: PASS
flutter test test/core/geometry test/features/clock/dial_hit_test_test.dart
```

- [ ] **Step 5: Run the whole suite**

The dial view still passes `DialGeometry.fitted(size)` (three rings), so nothing visual has changed and the goldens still match.

```bash
# expect: PASS
flutter analyze && flutter test
```

- [ ] **Step 6: Commit**

```bash
git add lib/core/geometry/dial_geometry.dart test/core/geometry/dial_geometry_rings_test.dart
git commit -m "feat: dial geometry that resizes with the ring count and widens touch targets

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Shared minute clock and the active-event rule

One `clockProvider` ticks at each minute boundary and replaces the dial's private 20-second timer later in this stage. Tests override it with a controllable fake. The "which event is active now?" rule also lives here as a pure function, so the dial and the Now card (Task 15) can never disagree: the latest-started event wins, ties go to the higher id.

**Files:**
- Replace: `lib/features/clock/providers.dart`
- Create: `lib/features/clock/model/active_event.dart`, `test/support/fake_clock.dart`
- Test: `test/features/clock/clock_provider_test.dart`, `test/features/clock/active_event_test.dart`

**Interfaces:**
- Produces: `untilNextMinute(DateTime)` → `Duration`; `ClockNotifier extends Notifier<DateTime>`; `clockProvider` (`NotifierProvider<ClockNotifier, DateTime>`); `activeEventsAt(List<CalendarEvent>, int minute)` → `List<CalendarEvent>` (latest-started first); test helper `FakeClock(DateTime initial)` with `set(DateTime)`.
- Consumes: `CalendarEvent`, `MinuteRange`, `Tone`.

- [ ] **Step 1: Write the failing tests**

**Create `test/support/fake_clock.dart`**

```dart
import 'package:energy_clock/features/clock/providers.dart';

/// A [ClockNotifier] that never ticks by itself. Tests set the time directly:
///
///     clockProvider.overrideWith(() => FakeClock(DateTime(2026, 10, 3, 10, 30)))
class FakeClock extends ClockNotifier {
  FakeClock(this._initial);

  final DateTime _initial;

  @override
  DateTime build() => _initial;

  /// Moves the fake clock, as a minute tick would.
  void set(DateTime time) => state = time;
}
```

**Create `test/features/clock/clock_provider_test.dart`**

```dart
import 'package:energy_clock/features/clock/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';

void main() {
  group('untilNextMinute', () {
    test('a whole minute from a minute boundary', () {
      expect(
        untilNextMinute(DateTime(2026, 10, 3, 10, 30)),
        const Duration(minutes: 1),
      );
    });

    test('the rest of the minute otherwise', () {
      expect(
        untilNextMinute(DateTime(2026, 10, 3, 10, 30, 45, 500)),
        const Duration(seconds: 14, milliseconds: 500),
      );
    });

    test('crosses midnight', () {
      expect(
        untilNextMinute(DateTime(2026, 10, 3, 23, 59, 59)),
        const Duration(seconds: 1),
      );
    });
  });

  test('a fake clock is deterministic and can be moved', () {
    final fake = FakeClock(DateTime(2026, 10, 3, 10, 30));
    final container = ProviderContainer(
      overrides: [clockProvider.overrideWith(() => fake)],
    );
    addTearDown(container.dispose);

    expect(container.read(clockProvider), DateTime(2026, 10, 3, 10, 30));
    fake.set(DateTime(2026, 10, 3, 10, 31));
    expect(container.read(clockProvider), DateTime(2026, 10, 3, 10, 31));
  });

  test('the selected day starts at the clock\'s today and Today returns to it', () {
    final fake = FakeClock(DateTime(2026, 10, 3, 10, 30));
    final container = ProviderContainer(
      overrides: [clockProvider.overrideWith(() => fake)],
    );
    addTearDown(container.dispose);

    expect(container.read(selectedDateProvider), DateTime(2026, 10, 3));
    container
        .read(selectedDateProvider.notifier)
        .select(DateTime(2026, 12, 25, 18));
    expect(container.read(selectedDateProvider), DateTime(2026, 12, 25));
    container.read(selectedDateProvider.notifier).today();
    expect(container.read(selectedDateProvider), DateTime(2026, 10, 3));
  });

  test('the real clock starts at the current time', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final read = container.read(clockProvider);
    expect(DateTime.now().difference(read).inSeconds.abs(), lessThan(2));
  });

  testWidgets('the real clock ticks once a minute and reschedules itself', (
    tester,
  ) async {
    // The test binding fakes timers but not DateTime.now(), so where the first
    // tick lands depends on the wall-clock second the test runs in. What always
    // holds: every 61-second window contains at least one tick.
    var changes = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            ref.listen(clockProvider, (_, _) => changes++);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(changes, 0);

    await tester.pump(const Duration(seconds: 61));
    final afterFirstWindow = changes;
    expect(afterFirstWindow, greaterThanOrEqualTo(1));

    await tester.pump(const Duration(seconds: 61));
    expect(changes, greaterThan(afterFirstWindow));
  });

  testWidgets('disposing the scope cancels the timer', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            ref.watch(clockProvider);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    // The framework fails the test if a timer is still pending here.
  });
}
```

**Create `test/features/clock/active_event_test.dart`**

```dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/active_event.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent event(int id, int start, int end) => CalendarEvent(
  id: id,
  seriesId: null,
  date: DateTime(2026, 10, 3),
  title: 'Event $id',
  tone: Tone.focus,
  range: MinuteRange(start, end),
  status: EventStatus.planned,
);

void main() {
  test('nothing is active outside every event', () {
    expect(activeEventsAt([event(1, 540, 600)], 500), isEmpty);
    expect(activeEventsAt(const [], 500), isEmpty);
  });

  test('an event is active from its start minute', () {
    expect(activeEventsAt([event(1, 540, 600)], 540).map((e) => e.id), [1]);
  });

  test('an event is not active at its end minute (end is exclusive)', () {
    expect(activeEventsAt([event(1, 540, 600)], 600), isEmpty);
    expect(activeEventsAt([event(1, 540, 600)], 599).map((e) => e.id), [1]);
  });

  test('overlapping events list the latest-started first', () {
    final events = [event(1, 540, 720), event(2, 600, 660), event(3, 630, 700)];
    expect(activeEventsAt(events, 640).map((e) => e.id), [3, 2, 1]);
  });

  test('events that start together go to the higher id first', () {
    final events = [event(1, 600, 700), event(2, 600, 650)];
    expect(activeEventsAt(events, 610).map((e) => e.id), [2, 1]);
  });

  test('does not modify the list it is given', () {
    final events = [event(1, 540, 720), event(2, 600, 660)];
    activeEventsAt(events, 610);
    expect(events.map((e) => e.id), [1, 2]);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL — 'ClockNotifier', 'clockProvider', 'untilNextMinute' and 'active_event.dart' do not exist
flutter test test/features/clock/clock_provider_test.dart test/features/clock/active_event_test.dart
```

- [ ] **Step 3: Write the clock and the rule**

**Replace `lib/features/clock/providers.dart`**

```dart
import 'dart:async';

import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return DriftEventRepository(ref.watch(appDatabaseProvider).eventDao);
});

/// The day the Clock tab is showing. Always local midnight. "Today" is the
/// shared clock's today, so tests that fake the clock get a fake today too.
class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => startOfDay(ref.read(clockProvider));

  void select(DateTime day) => state = startOfDay(day);
  void next() => state = nextDay(state);
  void previous() => state = previousDay(state);
  void today() => state = startOfDay(ref.read(clockProvider));
}

final selectedDateProvider = NotifierProvider<SelectedDateNotifier, DateTime>(
  SelectedDateNotifier.new,
);

final dayEventsProvider = StreamProvider<List<CalendarEvent>>((ref) {
  return ref
      .watch(eventRepositoryProvider)
      .watchDay(ref.watch(selectedDateProvider));
});

/// How long until the next minute boundary. The clock ticks on the boundary so
/// anything that shows the time changes exactly when the minute does.
Duration untilNextMinute(DateTime now) {
  final next = DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
  return next.difference(now);
}

/// The current time, updated once a minute. The one shared source for
/// everything on the Clock screen that depends on "now". Tests override it with
/// `clockProvider.overrideWith(() => FakeClock(...))`.
class ClockNotifier extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    final now = DateTime.now();
    _schedule(now);
    ref.onDispose(() => _timer?.cancel());
    return now;
  }

  void _schedule(DateTime now) {
    _timer = Timer(untilNextMinute(now), () {
      final tick = DateTime.now();
      state = tick;
      _schedule(tick);
    });
  }
}

final clockProvider = NotifierProvider<ClockNotifier, DateTime>(
  ClockNotifier.new,
);
```

**Create `lib/features/clock/model/active_event.dart`**

```dart
import 'package:energy_clock/features/clock/model/calendar_event.dart';

/// The events running at [minute] (`start <= minute < end`), latest-started
/// first; events that start together go to the higher id first. The first one
/// is the event shown as "now" everywhere, so the dial and the Now card always
/// agree. Does not modify [events].
List<CalendarEvent> activeEventsAt(List<CalendarEvent> events, int minute) {
  final active = [
    for (final event in events)
      if (minute >= event.startMinute && minute < event.endMinute) event,
  ];
  active.sort((a, b) {
    final byStart = b.startMinute.compareTo(a.startMinute);
    return byStart != 0 ? byStart : b.id.compareTo(a.id);
  });
  return active;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
# expect: PASS
flutter test test/features/clock/clock_provider_test.dart test/features/clock/active_event_test.dart && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/clock/providers.dart lib/features/clock/model/active_event.dart test/support/fake_clock.dart test/features/clock/clock_provider_test.dart test/features/clock/active_event_test.dart
git commit -m "feat: shared minute clock and one active-event rule

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Dial painter v2

The painter draws the bold look: a raised face, a faint night tint, hour ticks and numerals in Nunito, thick arcs with white or near-black labels, and a thick marker on the rim in place of the long hand, so the time in the centre is never covered. It also supports a partial sweep per arc, for the arrival animation.

The painter takes a `DialStyle` instead of a handful of loose colours, so it never reads the theme itself. `DialView` is updated in the same task to pass the new parameters, because the old ones no longer exist. The goldens are regenerated at the end.

**Files:**
- Replace: `lib/features/clock/widgets/dial_painter.dart`, `test/features/clock/dial_painter_test.dart`
- Edit: `lib/features/clock/widgets/dial_view.dart` (only the `DialPainter(...)` call and the theme reads; the full rewrite is Task 13)
- Regenerate: `test/features/clock/goldens/*.png`

**Interfaces:**
- Produces: `DialStyle({required Color page, surface, outline, ink, nightTint, required bool isDark, bool showNightTint = true})` with `DialStyle.fromColors(AppColors, {bool showNightTint = true})`; `DialPainter({required DialGeometry geometry, required List<CalendarEvent> events, required Map<int,int> ringByEventId, required ToneColors toneColors, required DialStyle style, int? nowMinute, Tone? markerTone, Map<int,double> arcProgress = const {}, bool popStyle = false, MinuteRange? ghostRange, Tone? ghostTone, double ghostOpacity = 0.55, TextScaler textScaler = TextScaler.noScaling})`.
- Consumes: `DialGeometry` (Task 10), `AppColors`, `ToneColors`, `AppTypography` (Tasks 3–5), `CalendarEvent`.

- [ ] **Step 1: Write the failing tests**

**Replace `test/features/clock/dial_painter_test.dart`**

```dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/geometry/dial_geometry.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:energy_clock/features/clock/widgets/dial_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const size = Size(390, 390);

CalendarEvent event(
  int id,
  MinuteRange range,
  Tone tone, {
  String title = '',
}) {
  return CalendarEvent(
    id: id,
    seriesId: null,
    date: DateTime(2026, 8, 23),
    title: title,
    tone: tone,
    range: range,
    status: EventStatus.planned,
  );
}

DialStyle lightStyle({bool showNightTint = true}) =>
    DialStyle.fromColors(AppColors.light, showNightTint: showNightTint);

DialPainter buildPainter({
  int ringCount = 1,
  int? nowMinute,
  Tone? markerTone,
  List<CalendarEvent> events = const [],
  Map<int, int> rings = const {},
  Map<int, double> arcProgress = const {},
  bool popStyle = false,
  MinuteRange? ghostRange,
  Tone? ghostTone,
  double ghostOpacity = 0.55,
  DialStyle? style,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return DialPainter(
    geometry: DialGeometry.fitted(size, ringCount: ringCount),
    events: events,
    ringByEventId: rings,
    toneColors: ToneColors.light,
    style: style ?? lightStyle(),
    nowMinute: nowMinute,
    markerTone: markerTone,
    arcProgress: arcProgress,
    popStyle: popStyle,
    ghostRange: ghostRange,
    ghostTone: ghostTone,
    ghostOpacity: ghostOpacity,
    textScaler: textScaler,
  );
}

void paint(DialPainter painter) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, size);
  recorder.endRecording().dispose();
}

/// Renders the painter to raw RGBA so a test can read individual pixels.
Future<ByteData> render(DialPainter painter) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  picture.dispose();
  image.dispose();
  return data;
}

Color pixel(ByteData data, Offset point) {
  final index = (point.dy.round() * size.width.toInt() + point.dx.round()) * 4;
  return Color.fromARGB(
    data.getUint8(index + 3),
    data.getUint8(index),
    data.getUint8(index + 1),
    data.getUint8(index + 2),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final geometry = DialGeometry.fitted(size, ringCount: 1);
  // A point near the outer edge of ring 0, clear of the curved label.
  Offset onArc(int minute) => geometry.pointOnCircle(
    geometry.ringCenterRadius(0) + geometry.ringWidth * 0.38,
    geometry.angleForMinute(minute.toDouble()),
  );

  group('painting does not throw', () {
    test('an empty dial', () {
      expect(() => paint(buildPainter()), returnsNormally);
    });

    test('events across all three rings', () {
      final events = [
        event(1, const MinuteRange(540, 720), Tone.focus, title: 'Deep work'),
        event(2, const MinuteRange(600, 660), Tone.life, title: 'Lunch'),
        event(3, const MinuteRange(610, 620), Tone.inbox, title: 'Email'),
      ];
      expect(
        () => paint(
          buildPainter(
            ringCount: 3,
            events: events,
            rings: const {1: 0, 2: 1, 3: 2},
          ),
        ),
        returnsNormally,
      );
    });

    test('an event that has no ring assigned is skipped', () {
      final events = [
        event(1, const MinuteRange(540, 720), Tone.focus, title: 'Deep work'),
        event(2, const MinuteRange(600, 660), Tone.life, title: 'Overflowed'),
      ];
      expect(
        () => paint(buildPainter(events: events, rings: const {1: 0})),
        returnsNormally,
      );
    });

    test('a very short arc with no room for its label', () {
      final events = [
        event(
          1,
          const MinuteRange(540, 555),
          Tone.focus,
          title: 'A very long event title that cannot possibly fit',
        ),
      ];
      expect(
        () => paint(buildPainter(events: events, rings: const {1: 0})),
        returnsNormally,
      );
    });

    test('the ghost arc during a drag', () {
      expect(
        () => paint(
          buildPainter(
            ghostRange: const MinuteRange(540, 720),
            ghostTone: Tone.focus,
          ),
        ),
        returnsNormally,
      );
    });

    test('the rim marker, with and without a tone', () {
      expect(() => paint(buildPainter(nowMinute: 630)), returnsNormally);
      expect(
        () => paint(buildPainter(nowMinute: 630, markerTone: Tone.life)),
        returnsNormally,
      );
    });

    test('a half-swept arc, in pop style and in dark mode', () {
      final events = [event(1, const MinuteRange(540, 720), Tone.focus)];
      expect(
        () => paint(
          buildPainter(
            events: events,
            rings: const {1: 0},
            arcProgress: const {1: 0.5},
            popStyle: true,
          ),
        ),
        returnsNormally,
      );
      expect(
        () => paint(
          buildPainter(style: DialStyle.fromColors(AppColors.dark)),
        ),
        returnsNormally,
      );
    });

    test('with the night tint off and with enlarged text', () {
      expect(
        () => paint(buildPainter(style: lightStyle(showNightTint: false))),
        returnsNormally,
      );
      expect(
        () => paint(buildPainter(textScaler: const TextScaler.linear(1.2))),
        returnsNormally,
      );
    });
  });

  group('what is drawn', () {
    test('an arc is painted in its tone colour', () async {
      final data = await render(
        buildPainter(
          events: [event(1, const MinuteRange(540, 720), Tone.focus)],
          rings: const {1: 0},
        ),
      );
      expect(pixel(data, onArc(630)), ToneColors.light.fillFor(Tone.focus));
    });

    test('an arc stops where its progress says', () async {
      final data = await render(
        buildPainter(
          events: [event(1, const MinuteRange(540, 720), Tone.focus)],
          rings: const {1: 0},
          arcProgress: const {1: 0.5},
        ),
      );
      // A quarter of the way along the range is drawn; three quarters is not.
      expect(pixel(data, onArc(585)), ToneColors.light.fillFor(Tone.focus));
      expect(pixel(data, onArc(675)).a, 0);
    });

    test('an arc with zero progress is not drawn at all', () async {
      final data = await render(
        buildPainter(
          events: [event(1, const MinuteRange(540, 720), Tone.focus)],
          rings: const {1: 0},
          arcProgress: const {1: 0},
        ),
      );
      expect(pixel(data, onArc(585)).a, 0);
    });

    test('the ghost is drawn at the requested opacity on ring 0', () async {
      final data = await render(
        buildPainter(
          ghostRange: const MinuteRange(540, 720),
          ghostTone: Tone.life,
          ghostOpacity: 1,
        ),
      );
      expect(pixel(data, onArc(630)), ToneColors.light.fillFor(Tone.life));
    });

    test('the marker rides the rim in the tone colour, else in ink', () async {
      final face = buildPainter(nowMinute: 360, markerTone: Tone.life);
      final spot = geometry.pointOnCircle(
        geometry.faceRadius * 0.88,
        geometry.angleForMinute(360),
      );
      expect(
        pixel(await render(face), spot),
        ToneColors.light.fillFor(Tone.life),
      );
      expect(
        pixel(await render(buildPainter(nowMinute: 360)), spot),
        AppColors.light.ink,
      );
    });

    test('no marker is drawn when there is no now minute', () async {
      final spot = geometry.pointOnCircle(
        geometry.faceRadius * 0.88,
        geometry.angleForMinute(360),
      );
      final colour = pixel(await render(buildPainter()), spot);
      expect(colour, isNot(AppColors.light.ink));
      expect(colour, isNot(ToneColors.light.fillFor(Tone.life)));
    });

    test('night hours are tinted and day hours are not', () async {
      final centre = geometry.center;
      final night = centre + Offset(0, -geometry.faceRadius * 0.40); // 00:00
      final day = centre + Offset(0, geometry.faceRadius * 0.40); // 12:00
      final tinted = await render(buildPainter());
      expect(pixel(tinted, night), isNot(AppColors.light.surface));
      expect(pixel(tinted, day), AppColors.light.surface);

      final plain = await render(
        buildPainter(style: lightStyle(showNightTint: false)),
      );
      expect(pixel(plain, night), AppColors.light.surface);
    });
  });

  group('shouldRepaint', () {
    test('repaints when the now minute changes', () {
      expect(
        buildPainter(nowMinute: 600).shouldRepaint(buildPainter(nowMinute: 601)),
        isTrue,
      );
    });

    test('does not repaint when nothing changed', () {
      expect(
        buildPainter(nowMinute: 600).shouldRepaint(buildPainter(nowMinute: 600)),
        isFalse,
      );
    });

    test('repaints when the style changes', () {
      expect(
        buildPainter().shouldRepaint(
          buildPainter(style: DialStyle.fromColors(AppColors.dark)),
        ),
        isTrue,
      );
    });

    test('repaints when the sweep progress, marker tone or ghost changes', () {
      final base = buildPainter(
        events: [event(1, const MinuteRange(540, 720), Tone.focus)],
        rings: const {1: 0},
      );
      expect(
        base.shouldRepaint(
          buildPainter(
            events: [event(1, const MinuteRange(540, 720), Tone.focus)],
            rings: const {1: 0},
            arcProgress: const {1: 0.4},
          ),
        ),
        isTrue,
      );
      expect(
        buildPainter(markerTone: Tone.life, nowMinute: 5).shouldRepaint(
          buildPainter(markerTone: Tone.focus, nowMinute: 5),
        ),
        isTrue,
      );
      expect(
        buildPainter(ghostOpacity: 0.3).shouldRepaint(
          buildPainter(ghostOpacity: 0.4),
        ),
        isTrue,
      );
    });

    test('does not repaint for an equal but non-identical event list', () {
      final one = [event(1, const MinuteRange(540, 720), Tone.focus)];
      final two = [event(1, const MinuteRange(540, 720), Tone.focus)];
      final a = buildPainter(events: one, rings: {1: 0});
      final b = buildPainter(events: two, rings: {1: 0});
      expect(a.shouldRepaint(b), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
# expect: FAIL — 'DialStyle' and the new DialPainter parameters do not exist
flutter test test/features/clock/dial_painter_test.dart
```

- [ ] **Step 3: Replace the painter and keep `DialView` compiling**

**Replace `lib/features/clock/widgets/dial_painter.dart`**

```dart
import 'dart:math' as math;

import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/app_typography.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/geometry/dial_geometry.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The neutral colours the dial is drawn with. The caller resolves them from
/// the theme, so the painter never reads the theme itself.
@immutable
class DialStyle {
  const DialStyle({
    required this.page,
    required this.surface,
    required this.outline,
    required this.ink,
    required this.nightTint,
    required this.isDark,
    this.showNightTint = true,
  });

  factory DialStyle.fromColors(AppColors colors, {bool showNightTint = true}) {
    return DialStyle(
      page: colors.page,
      surface: colors.surface,
      outline: colors.outline,
      ink: colors.ink,
      nightTint: colors.nightTint,
      isDark: colors.isDark,
      showNightTint: showNightTint,
    );
  }

  /// What is behind the arcs; used for the thin outline that separates
  /// neighbouring arcs.
  final Color page;

  /// The face.
  final Color surface;

  /// Hairline around the face in dark mode.
  final Color outline;

  /// Ticks, numerals, and the marker when no event is active.
  final Color ink;

  /// The faint tint over night hours.
  final Color nightTint;

  final bool isDark;

  /// Lets the night tint be switched off if it looks busy.
  final bool showNightTint;

  @override
  bool operator ==(Object other) =>
      other is DialStyle &&
      other.page == page &&
      other.surface == surface &&
      other.outline == outline &&
      other.ink == ink &&
      other.nightTint == nightTint &&
      other.isDark == isDark &&
      other.showNightTint == showNightTint;

  @override
  int get hashCode =>
      Object.hash(page, surface, outline, ink, nightTint, isDark, showNightTint);
}

/// Renders the 24-hour dial: raised face, night tint, ticks, numerals, event
/// arcs with curved labels, the ghost arc, and the rim marker for "now". All
/// positioning comes from [DialGeometry] — this class owns no math of its own.
class DialPainter extends CustomPainter {
  const DialPainter({
    required this.geometry,
    required this.events,
    required this.ringByEventId,
    required this.toneColors,
    required this.style,
    this.nowMinute,
    this.markerTone,
    this.arcProgress = const {},
    this.popStyle = false,
    this.ghostRange,
    this.ghostTone,
    this.ghostOpacity = 0.55,
    this.textScaler = TextScaler.noScaling,
  });

  final DialGeometry geometry;
  final List<CalendarEvent> events;
  final Map<int, int> ringByEventId;
  final ToneColors toneColors;
  final DialStyle style;

  /// Null on any day that is not today — the marker is only meaningful there.
  final int? nowMinute;

  /// The tone of the event running now; the marker takes its colour. Null
  /// draws the marker in ink.
  final Tone? markerTone;

  /// How much of each arc is drawn, by event id, for the arrival animation. An
  /// id that is missing is fully drawn.
  final Map<int, double> arcProgress;

  /// When true, an animating arc also grows from 90% to 100% of its thickness.
  final bool popStyle;

  /// Live preview while the user drags out a new event, and the pulsing hint
  /// on an empty day.
  final MinuteRange? ghostRange;
  final Tone? ghostTone;
  final double ghostOpacity;

  /// Text drawn on the dial is geometry, so callers clamp this to 1.2.
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    _paintFace(canvas);
    if (style.showNightTint) _paintNightTint(canvas);
    _paintTicks(canvas);
    _paintNumerals(canvas);
    _paintEvents(canvas);
    _paintGhost(canvas);
    _paintMarker(canvas);
  }

  void _paintFace(Canvas canvas) {
    final center = geometry.center;
    final radius = geometry.faceRadius;
    if (!style.isDark) {
      canvas.drawCircle(
        center.translate(0, 6),
        radius,
        Paint()
          ..color = style.ink.withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
    canvas.drawCircle(center, radius, Paint()..color = style.surface);
    if (style.isDark) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = style.outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  /// Night runs 21:00 to 06:00 and wraps midnight; the edges fade over an hour.
  void _paintNightTint(Canvas canvas) {
    const hour = 1 / 24;
    final clear = style.nightTint.withValues(alpha: 0);
    final gradient = SweepGradient(
      transform: const GradientRotation(-math.pi / 2),
      colors: [
        style.nightTint,
        style.nightTint,
        clear,
        clear,
        style.nightTint,
        style.nightTint,
      ],
      stops: const [0, 5 * hour, 6 * hour, 20 * hour, 21 * hour, 1],
    );
    final rect = Rect.fromCircle(
      center: geometry.center,
      radius: geometry.faceRadius,
    );
    canvas.drawCircle(
      geometry.center,
      geometry.faceRadius - 0.5,
      Paint()..shader = gradient.createShader(rect),
    );
  }

  void _paintTicks(Canvas canvas) {
    final paint = Paint()
      ..color = style.ink.withValues(alpha: 0.4)
      ..strokeCap = StrokeCap.round;
    for (var hour = 0; hour < 24; hour++) {
      final isMajor = hour % 3 == 0;
      final length = geometry.faceRadius * (isMajor ? 0.085 : 0.045);
      paint.strokeWidth = isMajor ? 2.2 : 1.2;

      final angle = geometry.angleForMinute(hour * 60.0);
      final outer = geometry.pointOnCircle(geometry.faceRadius - 4, angle);
      final inner = geometry.pointOnCircle(
        geometry.faceRadius - 4 - length,
        angle,
      );
      canvas.drawLine(inner, outer, paint);
    }
  }

  void _paintNumerals(Canvas canvas) {
    final radius = geometry.faceRadius * 0.70;
    final numeral = AppTypography.dialNumeral(
      geometry.faceRadius,
    ).copyWith(color: style.ink);
    for (var hour = 0; hour < 24; hour += 3) {
      final painter = TextPainter(
        text: TextSpan(text: '$hour', style: numeral),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();

      final angle = geometry.angleForMinute(hour * 60.0);
      final position = geometry.pointOnCircle(radius, angle);
      painter.paint(
        canvas,
        position - Offset(painter.width / 2, painter.height / 2),
      );
      painter.dispose();
    }
  }

  void _paintEvents(Canvas canvas) {
    for (final calendarEvent in events) {
      final ring = ringByEventId[calendarEvent.id];
      if (ring == null) continue;

      final animating = arcProgress.containsKey(calendarEvent.id);
      final progress = arcProgress[calendarEvent.id] ?? 1.0;
      if (progress <= 0) continue;

      final radius = geometry.ringCenterRadius(ring);
      final thickness = popStyle && animating
          ? geometry.ringWidth * (0.9 + 0.1 * progress)
          : geometry.ringWidth;
      _paintArc(
        canvas,
        radius: radius,
        range: calendarEvent.range,
        color: toneColors.fillFor(calendarEvent.tone),
        thickness: thickness,
        progress: math.min(progress, 1),
        outline: style.page,
      );
      if (progress >= 1) {
        _paintCurvedLabel(
          canvas,
          text: calendarEvent.title,
          radius: radius,
          range: calendarEvent.range,
          color: toneColors.labelFor(calendarEvent.tone),
        );
      }
    }
  }

  void _paintGhost(Canvas canvas) {
    final range = ghostRange;
    final tone = ghostTone;
    if (range == null || tone == null) return;

    _paintArc(
      canvas,
      radius: geometry.ringCenterRadius(0),
      range: range,
      color: toneColors.fillFor(tone).withValues(alpha: ghostOpacity),
      thickness: geometry.ringWidth,
    );
  }

  void _paintArc(
    Canvas canvas, {
    required double radius,
    required MinuteRange range,
    required Color color,
    required double thickness,
    double progress = 1,
    Color? outline,
  }) {
    final startAngle = geometry.angleForMinute(range.start.toDouble());
    final fullSweep = geometry.angleForMinute(range.end.toDouble()) - startAngle;
    final sweep = fullSweep * progress;
    final rect = Rect.fromCircle(center: geometry.center, radius: radius);

    if (outline != null) {
      canvas.drawArc(
        rect,
        startAngle,
        sweep,
        false,
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness + 4
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawArc(
      rect,
      startAngle,
      sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Draws the title along the arc, one glyph at a time. Omits the label
  /// entirely when the arc is too short to hold it — a clipped or overlapping
  /// label is worse than none, and the event is still identifiable by tap.
  void _paintCurvedLabel(
    Canvas canvas, {
    required String text,
    required double radius,
    required MinuteRange range,
    required Color color,
  }) {
    if (text.isEmpty) return;

    final labelStyle = AppTypography.arcLabel(
      geometry.ringWidth,
    ).copyWith(color: color);

    final measure = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    final totalWidth = measure.width;
    measure.dispose();

    final startAngle = geometry.angleForMinute(range.start.toDouble());
    final sweep = geometry.angleForMinute(range.end.toDouble()) - startAngle;
    final availableWidth = sweep * radius;
    if (totalWidth > availableWidth * 0.88) return;

    final margin = (sweep - totalWidth / radius) / 2;
    final inverted = geometry.isLabelInverted(startAngle + sweep / 2);

    final glyphs = inverted
        ? text.characters.toList().reversed
        : text.characters;
    var angle = inverted ? startAngle + sweep - margin : startAngle + margin;

    for (final glyph in glyphs) {
      final painter = TextPainter(
        text: TextSpan(text: glyph, style: labelStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();

      final glyphWidth = painter.width;
      final glyphAngle = inverted
          ? angle - (glyphWidth / 2) / radius
          : angle + (glyphWidth / 2) / radius;

      canvas.save();
      canvas.translate(geometry.center.dx, geometry.center.dy);
      canvas.rotate(
        inverted ? glyphAngle - math.pi / 2 : glyphAngle + math.pi / 2,
      );
      canvas.translate(0, inverted ? radius : -radius);
      painter.paint(canvas, Offset(-glyphWidth / 2, -painter.height / 2));
      canvas.restore();

      angle += inverted ? -glyphWidth / radius : glyphWidth / radius;
      painter.dispose();
    }
  }

  /// A thick capsule on the rim of the face marks the current minute. It
  /// stays clear of the numerals and of the centre text.
  void _paintMarker(Canvas canvas) {
    final minute = nowMinute;
    if (minute == null) return;

    final angle = geometry.angleForMinute(minute.toDouble());
    final inner = geometry.pointOnCircle(geometry.faceRadius * 0.80, angle);
    final outer = geometry.pointOnCircle(geometry.faceRadius * 0.96, angle);
    final thickness = math.max(6.0, 0.05 * geometry.faceRadius);
    final tone = markerTone;
    final color = tone == null ? style.ink : toneColors.fillFor(tone);

    canvas.drawLine(
      inner,
      outer,
      Paint()
        ..color = style.surface
        ..strokeWidth = thickness + 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      inner,
      outer,
      Paint()
        ..color = color
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(DialPainter oldDelegate) {
    return oldDelegate.geometry != geometry ||
        !listEquals(oldDelegate.events, events) ||
        !mapEquals(oldDelegate.ringByEventId, ringByEventId) ||
        oldDelegate.toneColors != toneColors ||
        oldDelegate.style != style ||
        oldDelegate.nowMinute != nowMinute ||
        oldDelegate.markerTone != markerTone ||
        !mapEquals(oldDelegate.arcProgress, arcProgress) ||
        oldDelegate.popStyle != popStyle ||
        oldDelegate.ghostRange != ghostRange ||
        oldDelegate.ghostTone != ghostTone ||
        oldDelegate.ghostOpacity != ghostOpacity ||
        oldDelegate.textScaler != textScaler;
  }
}
```

**Edit `lib/features/clock/widgets/dial_view.dart`** — only so it compiles against the new painter. Task 13 rewrites this file.

Replace:

```dart
                painter: DialPainter(
                  geometry: geometry,
                  events: paintedEvents,
                  ringByEventId: _assignment.ringByEventId,
                  toneColors: toneColors,
                  faceColor: theme.colorScheme.surface,
                  faceBorderColor: theme.colorScheme.outlineVariant,
                  tickColor: theme.colorScheme.outline,
                  numeralStyle:
                      theme.textTheme.titleMedium ??
                      const TextStyle(fontSize: 16),
                  handColor: theme.colorScheme.onSurface,
                  nowMinute: _isToday ? minuteOfDay(_now) : null,
                  ghostRange: ghost,
                  ghostTone: ghost == null ? null : defaultDraftTone,
                ),
```

With:

```dart
                painter: DialPainter(
                  geometry: geometry,
                  events: paintedEvents,
                  ringByEventId: _assignment.ringByEventId,
                  toneColors: toneColors,
                  style: DialStyle.fromColors(context.appColors),
                  nowMinute: _isToday ? minuteOfDay(_now) : null,
                  markerTone: _currentTone,
                  ghostRange: ghost,
                  ghostTone: ghost == null ? null : defaultDraftTone,
                ),
```

**Edit `lib/features/clock/widgets/dial_view.dart`** — the import for `context.appColors`.

Replace:

```dart
import 'package:energy_clock/app/theme/tone_colors.dart';
```

With:

```dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
```

- [ ] **Step 4: Run the painter tests, then regenerate the goldens**

```bash
# expect: PASS
flutter test test/features/clock/dial_painter_test.dart
```

```bash
# expect: UPDATE
flutter test --update-goldens test/features/clock/dial_golden_test.dart
```

Open `test/features/clock/goldens/dial_tones_light.png` and check: a raised white face with a soft shadow, a faint cool tint on the left and top-left (night), thick arcs in vivid purple, green and orange, and no long hand. The numerals and the centre text are still boxes (Flutter's test font; real text arrives in Task 14), and there is no rim marker because the golden's day is in the past. Then:

```bash
# expect: PASS
flutter analyze && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/clock/widgets/dial_painter.dart lib/features/clock/widgets/dial_view.dart test/features/clock/dial_painter_test.dart test/features/clock/goldens
git commit -m "feat: bold dial painter with night tint, rim marker and sweepable arcs

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Dial view v2 and VoiceOver support

The dial now reads "rings in use" from the day's events and animates its face between ring counts, sweeps arcs in, pops new ones, pulses a hint arc on an empty day, shows the time and the active tone in the centre, and takes "now" from `clockProvider`. A transparent layer of VoiceOver nodes sits over it, one per event. The nodes are not wrapped in `IgnorePointer`, because that blocks their actions: a node over an empty box is already transparent to touches.

The drag and tap logic is unchanged. It runs against the target geometry, never a mid-animation one, and drag state is held in minutes, so a rotation mid-drag simply continues.

**Files:**
- Replace: `lib/features/clock/widgets/dial_view.dart`, `test/features/clock/dial_view_test.dart`
- Edit: `test/features/clock/dial_golden_test.dart` (the harness only: animations off), `test/support/dial_pump.dart` (its comment)
- Create: `lib/features/clock/widgets/dial_semantics.dart`, `lib/features/clock/widgets/delete_event.dart`
- Test: `test/features/clock/dial_semantics_test.dart`, `test/features/clock/delete_event_test.dart`
- Regenerate: `test/features/clock/goldens/*.png`

**Interfaces:**
- Produces: `DialView({required List<CalendarEvent> events, required DateTime day, required bool readOnly, double? maxRadius, onCreateRequested, onEventTapped, onMoveRequested, onEditRequested(CalendarEvent), onDeleteRequested(CalendarEvent)})`; `DialSemantics({required DialGeometry geometry, required List<CalendarEvent> events, required Map<int,int> ringByEventId, required bool readOnly, onOpen, onEdit, onDelete})` with `DialSemantics.editAction` and `DialSemantics.deleteAction`; `confirmAndDeleteEvent(BuildContext, WidgetRef, CalendarEvent)` → `Future<bool>`.
- Consumes: `clockProvider`, `activeEventsAt` (Task 11); `DialGeometry` (Task 10); `DialPainter`, `DialStyle` (Task 12); `AppTypography`, `AppMotion`; `confirmDestructive` (Task 7); `Strings`, `spokenDurationMinutes` (Task 2).

- [ ] **Step 1: Write the failing tests**

**Replace `test/features/clock/dial_view_test.dart`**

```dart
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/geometry/dial_geometry.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/dial_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/dial_pump.dart';
import '../../support/fake_clock.dart';

final DateTime today = DateTime(2026, 10, 3);
final DateTime fakeNow = DateTime(2026, 10, 3, 10, 30);

CalendarEvent event(int id, MinuteRange range, Tone tone) => CalendarEvent(
  id: id,
  seriesId: null,
  date: today,
  title: 'Event $id',
  tone: tone,
  range: range,
  status: EventStatus.planned,
);

Widget harness({
  List<CalendarEvent> events = const [],
  bool readOnly = false,
  bool reduceMotion = false,
  void Function(MinuteRange)? onCreateRequested,
  void Function(CalendarEvent)? onEventTapped,
}) {
  return ProviderScope(
    overrides: [clockProvider.overrideWith(() => FakeClock(fakeNow))],
    child: MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 390,
            height: 390,
            child: DialView(
              events: events,
              day: today,
              readOnly: readOnly,
              onCreateRequested: onCreateRequested,
              onEventTapped: onEventTapped,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  const box = Size(390, 390);
  final oneRing = DialGeometry.fitted(box, ringCount: 1);
  final twoRings = DialGeometry.fitted(box, ringCount: 2);

  /// Where a touch at [radius] from the centre, straight above it, lands.
  Offset above(WidgetTester tester, double radius) =>
      tester.getCenter(find.byType(DialView)) + Offset(0, -radius);

  // NOTE on Flutter's actual gesture semantics (verified against
  // packages/flutter/lib/src/gestures/monodrag.dart in this checkout's SDK,
  // and against this widget by instrumenting it directly):
  //
  // GestureDetector's pan family is backed by PanGestureRecognizer, whose
  // internal state machine is ready -> possible -> accepted -> ready.
  // `onPanStart` fires exactly when the recognizer transitions from
  // `possible` to `accepted`. `onPanCancel` fires only when pointer tracking
  // stops while the recognizer is still `possible`; once `accepted`, the same
  // path always routes to `onPanEnd`, even for a raw PointerCancelEvent. So a
  // pan that has already called onPanStart can never subsequently invoke
  // onPanCancel — only onPanEnd. `onPanCancel` covers a touch that begins
  // inside the orbit band but is interrupted before it ever starts a drag, in
  // which case `_onPanStart` never runs and no drag field is touched.
  //
  // The tests below pin down that such a touch is inert and that the dial
  // keeps working normally for the next real gesture.

  testWidgets('a completed drag in the orbit band creates once', (
    tester,
  ) async {
    var created = 0;
    await tester.pumpWidget(harness(onCreateRequested: (_) => created++));
    await pumpDial(tester);

    final start = above(tester, oneRing.orbitInnerRadius + oneRing.ringWidth / 2);
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 20));
    // A tangential (sideways) move, not a move toward the centre: with the
    // default DragStartBehavior.start, DragStartDetails.localPosition is the
    // pointer's position once the pan is *recognised* (after crossing
    // kPanSlop), not the original down position.
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 20));
    await gesture.up();
    await pumpDial(tester);

    expect(created, 1);
  });

  testWidgets('a touch that never starts a drag is cancelled cleanly and the '
      'dial keeps working', (tester) async {
    var created = 0;
    await tester.pumpWidget(harness(onCreateRequested: (_) => created++));
    await pumpDial(tester);

    final start = above(tester, oneRing.orbitInnerRadius + oneRing.ringWidth / 2);
    final firstTouch = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 20));
    await firstTouch.cancel();
    await pumpDial(tester);
    expect(created, 0);

    final secondTouch = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 20));
    await secondTouch.moveBy(const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 20));
    await secondTouch.up();
    await pumpDial(tester);

    expect(created, 1);
  });

  testWidgets('with no overlaps the face is large, so a drag that starts on '
      'its outer part does not create', (tester) async {
    var created = 0;
    await tester.pumpWidget(harness(onCreateRequested: (_) => created++));
    await pumpDial(tester);

    // Inside the face of a one-ring dial, but inside the creation band of a
    // three-ring one.
    final gesture = await tester.startGesture(
      above(tester, oneRing.faceRadius * 0.9),
    );
    await tester.pump(const Duration(milliseconds: 20));
    await gesture.moveBy(const Offset(40, 0));
    await gesture.up();
    await pumpDial(tester);

    expect(created, 0);
  });

  testWidgets('two overlapping events bring the creation band inwards', (
    tester,
  ) async {
    var created = 0;
    await tester.pumpWidget(
      harness(
        events: [
          event(1, const MinuteRange(540, 720), Tone.focus),
          event(2, const MinuteRange(600, 660), Tone.life),
        ],
        onCreateRequested: (_) => created++,
      ),
    );
    await pumpDial(tester);

    // The same spot that missed above is now in the band: the rings crowd the
    // face to a smaller size. Minute 0 (the top) has no event on it.
    final start = above(tester, twoRings.orbitInnerRadius + twoRings.ringWidth / 2);
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 20));
    await gesture.moveBy(const Offset(40, 0));
    await gesture.up();
    await pumpDial(tester);

    expect(created, 1);
  });

  testWidgets('tapping an arc reports the event', (tester) async {
    CalendarEvent? tapped;
    final focus = event(1, const MinuteRange(540, 720), Tone.focus);
    await tester.pumpWidget(
      harness(events: [focus], onEventTapped: (e) => tapped = e),
    );
    await pumpDial(tester);
    await tester.pump(const Duration(seconds: 1)); // let the arc finish sweeping

    final centre = tester.getCenter(find.byType(DialView));
    final spot = oneRing.pointOnCircle(
      oneRing.ringCenterRadius(0),
      oneRing.angleForMinute(630),
    );
    await tester.tapAt(centre + (spot - oneRing.center));
    await pumpDial(tester);

    expect(tapped, focus);
  });

  group('the centre', () {
    testWidgets('shows the clock time', (tester) async {
      await tester.pumpWidget(harness());
      await pumpDial(tester);
      expect(find.text('10:30'), findsOneWidget);
    });

    testWidgets('names the tone of the event running now', (tester) async {
      await tester.pumpWidget(
        harness(events: [event(1, const MinuteRange(540, 720), Tone.focus)]),
      );
      await pumpDial(tester);
      expect(find.text('Focus'), findsOneWidget);
    });

    testWidgets('names no tone when nothing is running', (tester) async {
      await tester.pumpWidget(
        harness(events: [event(1, const MinuteRange(780, 840), Tone.life)]),
      );
      await pumpDial(tester);
      expect(find.text('Life'), findsNothing);
    });

    testWidgets('when two events run at once the latest-started names the tone', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          events: [
            event(1, const MinuteRange(540, 720), Tone.focus),
            event(2, const MinuteRange(600, 660), Tone.inbox),
          ],
        ),
      );
      await pumpDial(tester);
      expect(find.text('Inbox'), findsOneWidget);
      expect(find.text('Focus'), findsNothing);
    });
  });

  group('motion', () {
    testWidgets('an empty editable day pulses its hint arc', (tester) async {
      await tester.pumpWidget(harness());
      await pumpDial(tester);
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('reduced motion stops the pulse', (tester) async {
      await tester.pumpWidget(harness(reduceMotion: true));
      await pumpDial(tester);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a read-only day has no hint to pulse', (tester) async {
      await tester.pumpWidget(harness(readOnly: true));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('arcs sweep in on first paint and then settle', (tester) async {
      await tester.pumpWidget(
        harness(events: [event(1, const MinuteRange(540, 720), Tone.focus)]),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a newly created event pops in and then settles', (tester) async {
      final events = ValueNotifier<List<CalendarEvent>>([
        event(1, const MinuteRange(540, 720), Tone.focus),
      ]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [clockProvider.overrideWith(() => FakeClock(fakeNow))],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: ValueListenableBuilder<List<CalendarEvent>>(
                valueListenable: events,
                builder: (context, value, _) => SizedBox(
                  width: 390,
                  height: 390,
                  child: DialView(events: value, day: today, readOnly: false),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);

      events.value = [
        ...events.value,
        event(2, const MinuteRange(780, 840), Tone.life),
      ];
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('growing from one ring to two animates the face, then settles', (
      tester,
    ) async {
      final events = ValueNotifier<List<CalendarEvent>>([
        event(1, const MinuteRange(540, 720), Tone.focus),
      ]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [clockProvider.overrideWith(() => FakeClock(fakeNow))],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: ValueListenableBuilder<List<CalendarEvent>>(
                valueListenable: events,
                builder: (context, value, _) => SizedBox(
                  width: 390,
                  height: 390,
                  child: DialView(events: value, day: today, readOnly: false),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      events.value = [
        ...events.value,
        event(2, const MinuteRange(600, 660), Tone.life),
      ];
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
```

**Create `test/features/clock/dial_semantics_test.dart`**

```dart
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/geometry/dial_geometry.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/dial_semantics.dart';
import 'package:energy_clock/features/clock/widgets/dial_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/dial_pump.dart';
import '../../support/fake_clock.dart';

final DateTime today = DateTime(2026, 10, 3);

CalendarEvent event(int id, String title, MinuteRange range, Tone tone) =>
    CalendarEvent(
      id: id,
      seriesId: null,
      date: today,
      title: title,
      tone: tone,
      range: range,
      status: EventStatus.planned,
    );

Widget harness({
  required List<CalendarEvent> events,
  bool readOnly = false,
  void Function(CalendarEvent)? onTapped,
  void Function(CalendarEvent)? onEdit,
  void Function(CalendarEvent)? onDelete,
}) {
  return ProviderScope(
    overrides: [
      clockProvider.overrideWith(() => FakeClock(DateTime(2026, 10, 3, 10, 30))),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 390,
            height: 390,
            child: DialView(
              events: events,
              day: today,
              readOnly: readOnly,
              onEventTapped: onTapped,
              onEditRequested: onEdit,
              onDeleteRequested: onDelete,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  final deepWork = event(1, 'Deep work', const MinuteRange(540, 660), Tone.focus);
  final lunch = event(2, 'Lunch', const MinuteRange(750, 810), Tone.life);

  testWidgets('the dial is a labelled group', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(harness(events: [deepWork]));
    await pumpDial(tester);

    expect(
      find.semantics.byLabel(Strings.dialSemanticsLabel),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('each event reads as one sentence', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(harness(events: [deepWork, lunch], onTapped: (_) {}));
    await pumpDial(tester);

    expect(
      find.semantics.byLabel('Deep work, Focus, 09:00 to 11:00, 2 hours'),
      findsOneWidget,
    );
    expect(
      find.semantics.byLabel('Lunch, Life, 12:30 to 13:30, 1 hour'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('an editable day offers open, edit and delete', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      harness(
        events: [deepWork],
        onTapped: (_) {},
        onEdit: (_) {},
        onDelete: (_) {},
      ),
    );
    await pumpDial(tester);

    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp('Deep work'))),
      matchesSemantics(
        label: 'Deep work, Focus, 09:00 to 11:00, 2 hours',
        isButton: true,
        hasTapAction: true,
        customActions: const [
          DialSemantics.editAction,
          DialSemantics.deleteAction,
        ],
      ),
    );
    handle.dispose();
  });

  testWidgets('a read-only day offers open only', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      harness(
        events: [deepWork],
        readOnly: true,
        onTapped: (_) {},
        onEdit: (_) {},
        onDelete: (_) {},
      ),
    );
    await pumpDial(tester);

    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp('Deep work'))),
      matchesSemantics(
        label: 'Deep work, Focus, 09:00 to 11:00, 2 hours',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('the actions call back with the event', (tester) async {
    final handle = tester.ensureSemantics();
    CalendarEvent? opened;
    CalendarEvent? edited;
    CalendarEvent? deleted;
    await tester.pumpWidget(
      harness(
        events: [deepWork],
        onTapped: (e) => opened = e,
        onEdit: (e) => edited = e,
        onDelete: (e) => deleted = e,
      ),
    );
    await pumpDial(tester);

    final node = find.semantics.byLabel(RegExp('Deep work'));
    tester.semantics.tap(node);
    expect(opened, deepWork);

    tester.semantics.performAction(
      node,
      SemanticsAction.customAction,
      args: CustomSemanticsAction.getIdentifier(DialSemantics.editAction),
    );
    expect(edited, deepWork);

    tester.semantics.performAction(
      node,
      SemanticsAction.customAction,
      args: CustomSemanticsAction.getIdentifier(DialSemantics.deleteAction),
    );
    expect(deleted, deepWork);
    handle.dispose();
  });

  testWidgets('the nodes follow their arcs', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(harness(events: [deepWork], onTapped: (_) {}));
    await pumpDial(tester);

    final geometry = DialGeometry.fitted(const Size(390, 390), ringCount: 1);
    // The Semantics widget sits exactly where its node is, so its global rect
    // is the node's footprint on screen.
    final nodeRect = tester.getRect(find.bySemanticsLabel(RegExp('Deep work')));
    final dialTopLeft = tester.getTopLeft(find.byType(DialView));
    final arcMiddle =
        dialTopLeft +
        geometry.pointOnCircle(
          geometry.ringCenterRadius(0),
          geometry.angleForMinute(600),
        );
    expect(nodeRect.contains(arcMiddle), isTrue);
    handle.dispose();
  });

  testWidgets('the overlay lets touches through to the dial', (tester) async {
    CalendarEvent? tapped;
    await tester.pumpWidget(harness(events: [deepWork], onTapped: (e) => tapped = e));
    await pumpDial(tester);

    final geometry = DialGeometry.fitted(const Size(390, 390), ringCount: 1);
    final centre = tester.getCenter(find.byType(DialView));
    final spot = geometry.pointOnCircle(
      geometry.ringCenterRadius(0),
      geometry.angleForMinute(600),
    );
    await tester.tapAt(centre + (spot - geometry.center));
    await pumpDial(tester);
    expect(tapped, deepWork);
  });
}
```

**Create `test/features/clock/delete_event_test.dart`**

```dart
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/delete_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_event_repository.dart';

void main() {
  late FakeEventRepository repository;
  final day = DateTime(2026, 10, 3);
  bool? result;

  setUp(() {
    repository = FakeEventRepository();
    result = null;
  });

  tearDown(() {
    repository.dispose();
  });

  Future<void> open(WidgetTester tester) async {
    await repository.createEvent(
      day: day,
      title: 'Deep work',
      tone: Tone.focus,
      range: const MinuteRange(540, 720),
    );
    final CalendarEvent event = (await repository.eventsForDay(day)).single;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [eventRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await confirmAndDeleteEvent(context, ref, event);
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  testWidgets('confirming deletes the event and returns true', (tester) async {
    await open(tester);
    expect(find.text(Strings.deleteConfirmTitle), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, Strings.delete));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(await repository.eventsForDay(day), isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('cancelling keeps the event and returns false', (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(TextButton, Strings.cancel));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(await repository.eventsForDay(day), hasLength(1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL — 'DialSemantics', 'confirmAndDeleteEvent' and the new DialView parameters do not exist
flutter test test/features/clock/dial_view_test.dart test/features/clock/dial_semantics_test.dart test/features/clock/delete_event_test.dart
```

- [ ] **Step 3: Write the semantics layer, the delete helper, and the new dial view**

**Create `lib/features/clock/widgets/delete_event.dart`**

```dart
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/shared/widgets/adaptive_dialog.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asks for confirmation, then deletes [event]. Returns true when it was
/// deleted. Used by the detail sheet and by the dial's VoiceOver Delete action.
Future<bool> confirmAndDeleteEvent(
  BuildContext context,
  WidgetRef ref,
  CalendarEvent event,
) async {
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

**Create `lib/features/clock/widgets/dial_semantics.dart`**

```dart
import 'package:energy_clock/core/geometry/dial_geometry.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

/// Screen-reader nodes laid over the dial: the dial as a labelled group and
/// one node per event, in chronological order, each placed over its arc.
///
/// The nodes sit over an empty box, which is already transparent to touches.
/// They must not be wrapped in `IgnorePointer`: that also blocks their
/// semantic actions.
class DialSemantics extends StatelessWidget {
  const DialSemantics({
    required this.geometry,
    required this.events,
    required this.ringByEventId,
    required this.readOnly,
    this.onOpen,
    this.onEdit,
    this.onDelete,
    super.key,
  });

  static const CustomSemanticsAction editAction = CustomSemanticsAction(
    label: Strings.edit,
  );
  static const CustomSemanticsAction deleteAction = CustomSemanticsAction(
    label: Strings.delete,
  );

  final DialGeometry geometry;
  final List<CalendarEvent> events;
  final Map<int, int> ringByEventId;

  /// A read-only day offers "open" only.
  final bool readOnly;

  final void Function(CalendarEvent event)? onOpen;
  final void Function(CalendarEvent event)? onEdit;
  final void Function(CalendarEvent event)? onDelete;

  Rect _arcBounds(CalendarEvent event, int ring) {
    final radius = geometry.ringCenterRadius(ring);
    final start = geometry.angleForMinute(event.startMinute.toDouble());
    final sweep = geometry.angleForMinute(event.endMinute.toDouble()) - start;
    final path = Path()
      ..addArc(Rect.fromCircle(center: geometry.center, radius: radius), start, sweep);
    return path.getBounds().inflate(geometry.ringWidth / 2);
  }

  @override
  Widget build(BuildContext context) {
    final ordered = [...events]
      ..sort((a, b) {
        final byStart = a.startMinute.compareTo(b.startMinute);
        return byStart != 0 ? byStart : a.id.compareTo(b.id);
      });

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: Strings.dialSemanticsLabel,
      child: Stack(
        children: [
          for (final event in ordered)
            if (ringByEventId[event.id] case final ring?)
              Positioned.fromRect(
                rect: _arcBounds(event, ring),
                child: Semantics(
                  container: true,
                  button: true,
                  label: Strings.eventSemantics(
                    event.title,
                    event.tone.label,
                    formatMinuteOfDay(event.startMinute),
                    formatMinuteOfDay(event.endMinute),
                    spokenDurationMinutes(event.range.durationMinutes),
                  ),
                  onTap: onOpen == null ? null : () => onOpen!(event),
                  customSemanticsActions: {
                    if (!readOnly && onEdit != null)
                      editAction: () => onEdit!(event),
                    if (!readOnly && onDelete != null)
                      deleteAction: () => onDelete!(event),
                  },
                  child: const SizedBox.expand(),
                ),
              ),
        ],
      ),
    );
  }
}
```

**Replace `lib/features/clock/widgets/dial_view.dart`**

```dart
import 'dart:async';
import 'dart:math' as math;

import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/app_typography.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/geometry/dial_geometry.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/geometry/ring_layout.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/active_event.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/dial_hit_test.dart';
import 'package:energy_clock/features/clock/widgets/dial_painter.dart';
import 'package:energy_clock/features/clock/widgets/dial_semantics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The tone a freshly dragged event previews as before the user picks one.
const Tone defaultDraftTone = Tone.focus;

/// The span the empty-day hint arc points at.
const MinuteRange _hintRange = MinuteRange(540, 600);

const int _maxStagger = 5;
const int _staggerMs = 40;
const int _popMs = 250;
const Duration _resizeDuration = Duration(milliseconds: 350);

class DialView extends ConsumerStatefulWidget {
  const DialView({
    required this.events,
    required this.day,
    required this.readOnly,
    this.maxRadius,
    this.onCreateRequested,
    this.onEventTapped,
    this.onMoveRequested,
    this.onEditRequested,
    this.onDeleteRequested,
    super.key,
  });

  final List<CalendarEvent> events;
  final DateTime day;
  final bool readOnly;

  /// Caps the dial's outer radius on very large windows.
  final double? maxRadius;

  final void Function(MinuteRange range)? onCreateRequested;
  final void Function(CalendarEvent event)? onEventTapped;
  final void Function(CalendarEvent event, MinuteRange range)? onMoveRequested;

  /// Screen-reader actions on an event. Offered on editable days only.
  final void Function(CalendarEvent event)? onEditRequested;
  final void Function(CalendarEvent event)? onDeleteRequested;

  @override
  ConsumerState<DialView> createState() => _DialViewState();
}

class _DialViewState extends ConsumerState<DialView>
    with TickerProviderStateMixin {
  // Drag state. Held in minutes, not pixels, so a rotation or resize mid-drag
  // simply continues against the new geometry.
  MinuteRange? _ghostRange;
  int? _anchorMinute;
  double _continuousMinute = 0;
  int? _lastHapticMinute;
  CalendarEvent? _draggingEvent;
  ArcGrabKind? _grabKind;
  MinuteRange? _originalRange;
  MinuteRange? _draftRange;

  // Arrival animation: arcs sweep in on a new day and pop in when created.
  late final AnimationController _arrival = AnimationController(vsync: this)
    ..addStatusListener(_onArrivalStatus);
  Set<int> _knownIds = const {};
  Set<int> _animatingIds = const {};
  bool _staggered = true;
  bool _started = false;
  DateTime? _shownDay;

  // The pulsing hint arc on an empty day.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!_started) {
      _started = true;
      _shownDay = widget.day;
      _knownIds = {for (final event in widget.events) event.id};
      _startArrival(_knownIds, staggered: true);
    }
    _syncPulse();
  }

  @override
  void didUpdateWidget(DialView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = {for (final event in widget.events) event.id};
    if (widget.day != _shownDay) {
      _shownDay = widget.day;
      _knownIds = ids;
      _startArrival(ids, staggered: true);
    } else {
      final created = ids.difference(_knownIds);
      _knownIds = ids;
      if (created.isNotEmpty) _startArrival(created, staggered: false);
    }
    _syncPulse();
  }

  @override
  void dispose() {
    _arrival.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onArrivalStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _animatingIds = const {});
    }
  }

  void _startArrival(Set<int> ids, {required bool staggered}) {
    if (ids.isEmpty || _reduceMotion) {
      _animatingIds = const {};
      _arrival.value = 1;
      return;
    }
    _animatingIds = ids;
    _staggered = staggered;
    final count = math.min(ids.length, _maxStagger);
    final totalMs = staggered
        ? AppMotion.slow.inMilliseconds + (count - 1) * _staggerMs
        : _popMs;
    _arrival
      ..duration = Duration(milliseconds: totalMs)
      ..forward(from: 0);
  }

  bool get _showHint => widget.events.isEmpty && !widget.readOnly;

  void _syncPulse() {
    if (_showHint && !_reduceMotion) {
      if (!_pulse.isAnimating) unawaited(_pulse.repeat(reverse: true));
    } else {
      _pulse.stop();
    }
  }

  /// Progress of each animating arc, 0 to 1 (a little over 1 for the pop).
  Map<int, double> _arcProgress() {
    if (_animatingIds.isEmpty || _arrival.isCompleted) return const {};
    final elapsedMs = _arrival.value * (_arrival.duration?.inMilliseconds ?? 1);
    final perArcMs = _staggered ? AppMotion.slow.inMilliseconds : _popMs;
    final curve = _staggered ? AppMotion.standard : AppMotion.pop;
    final progress = <int, double>{};
    var order = 0;
    for (final event in widget.events) {
      if (!_animatingIds.contains(event.id)) continue;
      final startMs = _staggered
          ? math.min(order, _maxStagger - 1) * _staggerMs
          : 0;
      final t = ((elapsedMs - startMs) / perArcMs).clamp(0.0, 1.0);
      progress[event.id] = curve.transform(t);
      order++;
    }
    return progress;
  }

  RingAssignment get _assignment => assignRings([
    for (final event in widget.events) RingCandidate(event.id, event.range),
  ]);

  int _ringCountFor(RingAssignment assignment) =>
      assignment.ringByEventId.isEmpty
      ? 1
      : assignment.ringByEventId.values.reduce(math.max) + 1;

  /// The geometry for a (possibly fractional) ring count. Between two whole
  /// counts it blends them, so the face resizes smoothly.
  DialGeometry _geometryFor(Size size, double ringCount) {
    final clamped = ringCount
        .clamp(1.0, DialGeometry.maxRings.toDouble())
        .toDouble();
    final low = clamped.floor();
    final high = clamped.ceil();
    final a = DialGeometry.fitted(
      size,
      ringCount: low,
      maxRadius: widget.maxRadius,
    );
    if (low == high) return a;
    final b = DialGeometry.fitted(
      size,
      ringCount: high,
      maxRadius: widget.maxRadius,
    );
    return DialGeometry.lerp(a, b, clamped - low);
  }

  void _onPanStart(DragStartDetails details, DialGeometry geometry) {
    if (widget.readOnly) return;
    if (!geometry.isInOrbitBand(details.localPosition)) return;

    final minute = geometry.minuteAtPoint(details.localPosition);
    final hit = eventAtPoint(
      point: details.localPosition,
      geometry: geometry,
      events: widget.events,
      ringByEventId: _assignment.ringByEventId,
    );

    if (hit != null) {
      setState(() {
        _draggingEvent = hit;
        _originalRange = hit.range;
        _draftRange = hit.range;
        _grabKind = grabKindFor(range: hit.range, touchMinute: minute);
        _anchorMinute = minute;
        _continuousMinute = minute.toDouble();
      });
      return;
    }

    setState(() {
      _anchorMinute = minute;
      _continuousMinute = minute.toDouble();
      _ghostRange = rangeFromDrag(
        anchorMinute: minute,
        currentMinute: minute.toDouble(),
      );
      _lastHapticMinute = _ghostRange!.end;
    });
  }

  void _onPanUpdate(DragUpdateDetails details, DialGeometry geometry) {
    final anchor = _anchorMinute;
    if (anchor == null) return;

    final sampled = geometry.minuteAtPoint(details.localPosition);
    _continuousMinute = unwrapMinute(_continuousMinute, sampled);

    final dragging = _draggingEvent;
    if (dragging != null) {
      final original = _originalRange!;
      final delta = (_continuousMinute - anchor).round();
      final updated = switch (_grabKind!) {
        ArcGrabKind.move => moveRange(original, delta),
        ArcGrabKind.resizeStart => resizeRangeStart(
          original,
          _continuousMinute.round(),
        ),
        ArcGrabKind.resizeEnd => resizeRangeEnd(
          original,
          _continuousMinute.round(),
        ),
      };
      if (updated.start != _draftRange?.start ||
          updated.end != _draftRange?.end) {
        unawaited(HapticFeedback.selectionClick());
      }
      setState(() => _draftRange = updated);
      return;
    }

    final range = rangeFromDrag(
      anchorMinute: anchor,
      currentMinute: _continuousMinute,
    );
    if (range.end != _lastHapticMinute || range.start != _ghostRange?.start) {
      unawaited(HapticFeedback.selectionClick());
      _lastHapticMinute = range.end;
    }
    setState(() => _ghostRange = range);
  }

  void _resetDrag() {
    setState(() {
      _ghostRange = null;
      _anchorMinute = null;
      _lastHapticMinute = null;
      _draggingEvent = null;
      _grabKind = null;
      _originalRange = null;
      _draftRange = null;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final dragging = _draggingEvent;
    final draft = _draftRange;
    final created = _ghostRange;

    _resetDrag();

    if (dragging != null && draft != null) {
      if (draft.start != dragging.range.start ||
          draft.end != dragging.range.end) {
        widget.onMoveRequested?.call(dragging, draft);
      }
      return;
    }
    if (created != null) widget.onCreateRequested?.call(created);
  }

  void _onTapUp(TapUpDetails details, DialGeometry geometry) {
    final hit = eventAtPoint(
      point: details.localPosition,
      geometry: geometry,
      events: widget.events,
      ringByEventId: _assignment.ringByEventId,
    );
    if (hit != null) widget.onEventTapped?.call(hit);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final toneColors = context.toneColors;
    final now = ref.watch(clockProvider);
    final assignment = _assignment;
    final ringCount = _ringCountFor(assignment);
    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.2);
    final isToday = widget.day == startOfDay(now);
    final minute = minuteOfDay(now);
    final activeTone = isToday
        ? activeEventsAt(widget.events, minute).firstOrNull?.tone
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        // Hit testing always uses the target geometry, never a mid-animation
        // one, so the touch zones do not move under a finger.
        final target = _geometryFor(size, ringCount.toDouble());

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(end: ringCount.toDouble()),
          duration: _reduceMotion ? Duration.zero : _resizeDuration,
          curve: AppMotion.pop,
          builder: (context, animatedCount, _) {
            final animated = _geometryFor(size, animatedCount);
            return GestureDetector(
              onPanStart: (details) => _onPanStart(details, target),
              onPanUpdate: (details) => _onPanUpdate(details, target),
              onPanEnd: _onPanEnd,
              onPanCancel: _resetDrag,
              onTapUp: (details) => _onTapUp(details, target),
              child: AnimatedBuilder(
                animation: Listenable.merge([_arrival, _pulse]),
                builder: (context, _) {
                  final ghost = _ghostRange;
                  final dragging = _draggingEvent;
                  final draft = _draftRange;
                  final paintedEvents = dragging == null || draft == null
                      ? widget.events
                      : [
                          for (final event in widget.events)
                            if (event.id == dragging.id)
                              CalendarEvent(
                                id: event.id,
                                seriesId: event.seriesId,
                                date: event.date,
                                title: event.title,
                                tone: event.tone,
                                range: draft,
                                status: event.status,
                              )
                            else
                              event,
                        ];

                  final hintOpacity = _showHint && ghost == null
                      ? (_reduceMotion
                            ? 0.35
                            : 0.2 + 0.3 * AppMotion.standard.transform(_pulse.value))
                      : null;

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: size,
                        painter: DialPainter(
                          geometry: animated,
                          events: paintedEvents,
                          ringByEventId: assignment.ringByEventId,
                          toneColors: toneColors,
                          style: DialStyle.fromColors(colors),
                          nowMinute: isToday ? minute : null,
                          markerTone: activeTone,
                          arcProgress: _arcProgress(),
                          popStyle: !_staggered,
                          ghostRange:
                              ghost ?? (hintOpacity == null ? null : _hintRange),
                          ghostTone: ghost != null
                              ? defaultDraftTone
                              : (hintOpacity == null ? null : Tone.focus),
                          ghostOpacity: ghost != null ? 0.55 : hintOpacity ?? 0.55,
                          textScaler: textScaler,
                        ),
                      ),
                      Positioned.fill(
                        child: DialSemantics(
                          geometry: target,
                          events: widget.events,
                          ringByEventId: assignment.ringByEventId,
                          readOnly: widget.readOnly,
                          onOpen: widget.onEventTapped,
                          onEdit: widget.onEditRequested,
                          onDelete: widget.onDeleteRequested,
                        ),
                      ),
                      _DialCentre(
                        faceRadius: animated.faceRadius,
                        primary: ghost != null
                            ? formatMinuteRange(ghost.start, ghost.end)
                            : formatMinuteOfDay(minute),
                        secondary: ghost != null
                            ? formatDurationMinutes(ghost.durationMinutes)
                            : activeTone?.label,
                        secondaryColor: ghost != null
                            ? colors.muted
                            : (activeTone == null
                                  ? null
                                  : toneColors.deepFor(activeTone)),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

/// The text in the middle of the face: the time (or the range being dragged)
/// and, under it, the active tone (or the duration being dragged). Scaled down
/// to fit inside the inner 55% of the face so it never touches the numerals or
/// the rim marker.
class _DialCentre extends StatelessWidget {
  const _DialCentre({
    required this.faceRadius,
    required this.primary,
    this.secondary,
    this.secondaryColor,
  });

  final double faceRadius;
  final String primary;
  final String? secondary;
  final Color? secondaryColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return SizedBox(
      width: faceRadius * 1.1,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              primary,
              style: AppTypography.displayTime(
                faceRadius,
              ).copyWith(color: colors.ink),
            ),
            if (secondary != null)
              Text(
                secondary!,
                style: theme.textTheme.labelLarge!.copyWith(
                  color: secondaryColor ?? colors.muted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

**Edit `test/support/dial_pump.dart`** — the dial no longer has a periodic timer; what keeps it from settling now is the hint arc.

Replace:

```dart
/// Any tree containing a [DialView] never settles: its periodic clock timer
/// schedules a frame every 20 seconds, so `pumpAndSettle` spins until the test
/// harness gives up. These pumps total 100ms of fake time — enough for the
/// events stream to deliver and for tap handlers to rebuild, and far short of
/// the timer's first tick.
```

With:

```dart
/// A [DialView] on an empty, editable day never settles: its hint arc pulses
/// forever (unless the test turns reduced motion on), so `pumpAndSettle` spins
/// until the test harness gives up. These pumps total 100ms of fake time —
/// enough for the events stream to deliver and for tap handlers to rebuild.
```

**Edit `test/features/clock/dial_golden_test.dart`** — the dial animates now, so goldens must be taken with animations off, or the arcs are caught half-drawn. Task 14 replaces this file with the final set.

Replace:

```dart
  return ProviderScope(
    child: MaterialApp(
      theme: theme,
      home: Scaffold(
```

With:

```dart
  return ProviderScope(
    child: MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(
```

- [ ] **Step 4: Run the tests, regenerate the goldens, run everything**

```bash
# expect: PASS
flutter test test/features/clock/dial_view_test.dart test/features/clock/dial_semantics_test.dart test/features/clock/delete_event_test.dart
```

```bash
# expect: UPDATE
flutter test --update-goldens test/features/clock/dial_golden_test.dart
```

The goldens are taken with animations off, so every arc is fully drawn. They now show the large one-ring face and the centre text block (still boxes until Task 14); on the empty dial the hint arc is drawn at its static opacity. Open `dial_empty_light.png` and `dial_tones_light.png` and confirm the face is clearly bigger than before, the arcs are thick, and the centre text block sits inside the face. Then:

```bash
# expect: PASS
flutter analyze && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/clock/widgets test/features/clock test/support/dial_pump.dart
git commit -m "feat: dial view with ring-count resize, arrival animation, hint, and VoiceOver nodes

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 14: Real text in every test, and dial goldens that show it

Flutter's test font draws every glyph as a box, so until now tests had unrealistic text widths and goldens could not show numerals or labels. This task loads the bundled Nunito for every test, and replaces the four old goldens with a set that shows numerals, arc labels, the centre text and the rim marker. They can then catch a label drawn upside down or a centre that collides with the marker. The goldens use a fixed clock and no animation, so they never change with the time of day.

Loading the font is deliberately done here, not earlier: with a real font the dial's centre text shows the actual time, so a golden taken without a fixed clock fails a minute later. The dial reads `clockProvider` since Task 13, which makes the fixed clock possible.

**Files:**
- Create: `test/flutter_test_config.dart`
- Test: `test/app/font_loading_test.dart`
- Replace: `test/features/clock/dial_golden_test.dart`
- Delete: `test/features/clock/goldens/dial_tones_light.png`, `dial_tones_dark.png`, `dial_overlaps_light.png`
- Regenerate: `test/features/clock/goldens/dial_empty_light.png` and the new files

**Interfaces:**
- Produces: every test in the package runs with Nunito loaded as the `Nunito` family.
- Consumes: `DialView`, `FakeClock`, `AppTheme`. Produces: eight golden images.

- [ ] **Step 1: Write the font loader, its test, and the golden tests**

**Create `test/flutter_test_config.dart`**

```dart
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the bundled Nunito font for every test in this package. Without it,
/// Flutter's test environment draws every glyph as a solid box: text has
/// unrealistic widths and goldens show black rectangles instead of letters.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final loader = FontLoader('Nunito');
  for (final weight in const ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
    loader.addFont(rootBundle.load('assets/fonts/Nunito-$weight.ttf'));
  }
  await loader.load();
  await testMain();
}
```

**Create `test/app/font_loading_test.dart`**

```dart
import 'package:energy_clock/app/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the bundled Nunito font is loaded in tests', (tester) async {
    final painter = TextPainter(
      text: TextSpan(
        text: 'Hello',
        style: AppTypography.displayTime(100).copyWith(fontSize: 20),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // Flutter's test fallback font draws every glyph as a 1-em box (5 × 20 = 100).
    expect(painter.width, isNot(100));
  });
}
```

**Replace `test/features/clock/dial_golden_test.dart`**

```dart
// Golden tests for [DialView]. Each PNG is captured from a [RepaintBoundary]
// tightly wrapping a 390x390 dial, so the image pins geometry, colour, ring
// layout and text for the face, ticks, numerals, event arcs, centre text and
// rim marker.
//
// `test/flutter_test_config.dart` loads the bundled Nunito font for every
// test, so numerals and curved arc labels render as real text and a golden can
// show whether labels read the right way up. The clock is fixed at 10:30 on
// 23 August 2026 and animations are off, so every image is deterministic.
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/dial_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';

CalendarEvent event(int id, MinuteRange range, Tone tone, String title) {
  return CalendarEvent(
    id: id,
    seriesId: null,
    date: DateTime(2026, 8, 23),
    title: title,
    tone: tone,
    range: range,
    status: EventStatus.planned,
  );
}

/// Key on the [RepaintBoundary] the goldens are captured from, so
/// `matchesGoldenFile` grabs a tight 390x390 image of the dial itself
/// instead of the entire (much larger) test window.
const dialGoldenKey = ValueKey('dial-golden');

Widget harness({
  required List<CalendarEvent> events,
  required ThemeData theme,
  DateTime? day,
  bool readOnly = false,
}) {
  return ProviderScope(
    overrides: [
      clockProvider.overrideWith(() => FakeClock(DateTime(2026, 8, 23, 10, 30))),
    ],
    child: MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: dialGoldenKey,
            child: SizedBox(
              width: 390,
              height: 390,
              child: DialView(
                events: events,
                day: day ?? DateTime(2026, 8, 23),
                readOnly: readOnly,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  // One ring: nothing overlaps. Deep work is running at 10:30.
  final separate = [
    event(1, const MinuteRange(540, 720), Tone.focus, 'Deep work'),
    event(2, const MinuteRange(780, 840), Tone.life, 'Lunch'),
    event(3, const MinuteRange(1020, 1080), Tone.inbox, 'Email'),
  ];

  // Two rings.
  final twoLevels = [
    event(1, const MinuteRange(540, 720), Tone.focus, 'Deep work'),
    event(2, const MinuteRange(600, 660), Tone.life, 'Walk'),
  ];

  // Three rings.
  final threeLevels = [
    event(1, const MinuteRange(540, 720), Tone.focus, 'Deep work'),
    event(2, const MinuteRange(600, 660), Tone.life, 'Walk'),
    event(3, const MinuteRange(610, 630), Tone.inbox, 'Call'),
  ];

  Future<void> check(WidgetTester tester, Widget app, String file) async {
    await tester.pumpWidget(app);
    await tester.pump();
    await expectLater(
      find.byKey(dialGoldenKey),
      matchesGoldenFile('goldens/$file'),
    );
  }

  testWidgets('empty day, light: the hint arc and the face at full size', (
    tester,
  ) async {
    await check(
      tester,
      harness(events: const [], theme: AppTheme.light),
      'dial_empty_light.png',
    );
  });

  testWidgets('one ring, light: arcs, labels, rim marker, centre text', (
    tester,
  ) async {
    await check(
      tester,
      harness(events: separate, theme: AppTheme.light),
      'dial_one_ring_light.png',
    );
  });

  testWidgets('one ring, dark', (tester) async {
    await check(
      tester,
      harness(events: separate, theme: AppTheme.dark),
      'dial_one_ring_dark.png',
    );
  });

  testWidgets('two rings, light: the face shrinks to make room', (
    tester,
  ) async {
    await check(
      tester,
      harness(events: twoLevels, theme: AppTheme.light),
      'dial_two_rings_light.png',
    );
  });

  testWidgets('three rings, light: today\'s size, the smallest face', (
    tester,
  ) async {
    await check(
      tester,
      harness(events: threeLevels, theme: AppTheme.light),
      'dial_three_rings_light.png',
    );
  });

  testWidgets('three rings, dark', (tester) async {
    await check(
      tester,
      harness(events: threeLevels, theme: AppTheme.dark),
      'dial_three_rings_dark.png',
    );
  });

  testWidgets('a past day, light: no marker and no hint', (tester) async {
    await check(
      tester,
      harness(
        events: separate,
        theme: AppTheme.light,
        day: DateTime(2026, 8, 22),
        readOnly: true,
      ),
      'dial_past_day_light.png',
    );
  });

  testWidgets('an empty past day, light: just the face', (tester) async {
    await check(
      tester,
      harness(
        events: const [],
        theme: AppTheme.light,
        day: DateTime(2026, 8, 22),
        readOnly: true,
      ),
      'dial_past_empty_light.png',
    );
  });
}
```

**Delete `test/features/clock/goldens/dial_tones_light.png`**

**Delete `test/features/clock/goldens/dial_tones_dark.png`**

**Delete `test/features/clock/goldens/dial_overlaps_light.png`**

- [ ] **Step 2: Check the font loads, then generate the goldens**

```bash
# expect: PASS
flutter test test/app/font_loading_test.dart
```

```bash
# expect: UPDATE
flutter test --update-goldens test/features/clock/dial_golden_test.dart
```

- [ ] **Step 3: Look at every image and check it**

Open each file in `test/features/clock/goldens/` and confirm:

- `dial_empty_light.png`: a large raised face; a faint pale-purple hint arc at the 09:00–10:00 position on the ring; a thick marker on the rim at 10:30 in ink; "10:30" centred with nothing under it.
- `dial_one_ring_light.png`: arcs about a third thicker than before; "Deep work" curved along its arc in white; "Lunch" and "Email" in near-black on green and orange; the marker in purple (Deep work is running); "10:30" with "Focus" under it in a deep purple.
- `dial_two_rings_light.png`, `dial_three_rings_light.png`: the face is visibly smaller as rings are added; three rings matches the old size.
- `dial_*_dark.png`: near-black page, a lighter face with a hairline border, brighter arcs with near-black labels.
- `dial_past_day_light.png`, `dial_past_empty_light.png`: no marker, no hint.
- Everywhere: numerals are real digits; no label is upside down on the bottom half; the centre text never touches the marker or the numerals.

If a label is mirrored or a collision is visible, fix the painter or the view (not the golden) and regenerate.

- [ ] **Step 4: Run the whole suite — this is the end of Stage 2**

```bash
# expect: PASS
flutter analyze && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add test/flutter_test_config.dart test/app/font_loading_test.dart test/features/clock
git commit -m "test: load Nunito for every test; dial goldens with real text and a fixed clock

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Stage 3 — Clock screen (narrow and medium layouts)

### Task 15: Now-card state

A pure function turns the day's events, the selected day and the current time into what the Now card should say. It uses the shared active-event rule from Task 11, so the card and the dial always agree.

**Files:**
- Create: `lib/features/clock/model/now_status.dart`
- Test: `test/features/clock/now_status_test.dart`

**Interfaces:**
- Produces: `sealed class NowStatus` with `NowActive({required CalendarEvent event, required int minutesLeft, required double progress, required int overlappingCount})`, `NowNext({required CalendarEvent event, required int minutesUntil})`, `NowFree()`, `NowDone({required int eventCount, required int plannedMinutes})`, `DaySummary({required int eventCount, required int plannedMinutes, required bool isPast})`; `computeNowStatus({required List<CalendarEvent> events, required DateTime selectedDay, required DateTime now})` → `NowStatus`.
- Consumes: `activeEventsAt` (Task 11), `startOfDay`, `minuteOfDay`.

- [ ] **Step 1: Write the failing test**

**Create `test/features/clock/now_status_test.dart`**

```dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:energy_clock/features/clock/model/now_status.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime today = DateTime(2026, 10, 7);

DateTime at(int hour, int minute) => DateTime(2026, 10, 7, hour, minute);

CalendarEvent event(int id, int start, int end, {Tone tone = Tone.focus}) =>
    CalendarEvent(
      id: id,
      seriesId: null,
      date: today,
      title: 'Event $id',
      tone: tone,
      range: MinuteRange(start, end),
      status: EventStatus.planned,
    );

NowStatus status(
  List<CalendarEvent> events, {
  DateTime? day,
  DateTime? now,
}) => computeNowStatus(
  events: events,
  selectedDay: day ?? today,
  now: now ?? at(10, 30),
);

void main() {
  group('today', () {
    test('no events is free', () {
      expect(status(const []), isA<NowFree>());
    });

    test('an event running now is active, with time left and progress', () {
      final result = status([event(1, 540, 720)]); // 09:00-12:00 at 10:30
      expect(result, isA<NowActive>());
      final active = result as NowActive;
      expect(active.event.id, 1);
      expect(active.minutesLeft, 90);
      expect(active.progress, closeTo(0.5, 1e-9));
      expect(active.overlappingCount, 0);
    });

    test('an event is active at its start minute, with no progress yet', () {
      final active = status([event(1, 630, 690)]) as NowActive; // starts 10:30
      expect(active.minutesLeft, 60);
      expect(active.progress, 0);
    });

    test('an event is not active at its end minute', () {
      final result = status([event(1, 540, 630)]); // ends 10:30
      expect(result, isA<NowDone>());
    });

    test('overlapping events show the latest-started with a count', () {
      final active =
          status([event(1, 540, 720), event(2, 600, 660), event(3, 700, 760)])
              as NowActive;
      expect(active.event.id, 2);
      expect(active.overlappingCount, 1);
    });

    test('three overlapping events count two others', () {
      final active =
          status([event(1, 540, 720), event(2, 600, 700), event(3, 620, 680)])
              as NowActive;
      expect(active.event.id, 3);
      expect(active.overlappingCount, 2);
    });

    test('nothing running but something later is next', () {
      final result = status([event(1, 540, 600), event(2, 750, 810)]);
      expect(result, isA<NowNext>());
      final next = result as NowNext;
      expect(next.event.id, 2);
      expect(next.minutesUntil, 120);
    });

    test('next is the earliest upcoming event', () {
      final next =
          status([event(2, 900, 960), event(1, 750, 810), event(3, 780, 800)])
              as NowNext;
      expect(next.event.id, 1);
    });

    test('events that start together: the lower id is next', () {
      final next = status([event(2, 750, 810), event(1, 750, 800)]) as NowNext;
      expect(next.event.id, 1);
    });

    test('everything finished is done, with a count and the planned minutes', () {
      final result = status([event(1, 540, 600), event(2, 600, 630)]);
      expect(result, isA<NowDone>());
      final done = result as NowDone;
      expect(done.eventCount, 2);
      expect(done.plannedMinutes, 90);
    });

    test('planned minutes count overlapping events twice', () {
      final done =
          status([event(1, 60, 120), event(2, 60, 120)], now: at(20, 0))
              as NowDone;
      expect(done.plannedMinutes, 120);
    });

    test('the time of day on the selected day is ignored', () {
      final result = status([event(1, 540, 720)], day: DateTime(2026, 10, 7, 23, 59));
      expect(result, isA<NowActive>());
    });
  });

  group('other days', () {
    test('a future day with events is a summary', () {
      final result = status(
        [event(1, 540, 720), event(2, 780, 840)],
        day: DateTime(2026, 10, 8),
      );
      expect(result, isA<DaySummary>());
      final summary = result as DaySummary;
      expect(summary.eventCount, 2);
      expect(summary.plannedMinutes, 240);
      expect(summary.isPast, isFalse);
    });

    test('an empty future day is free', () {
      expect(status(const [], day: DateTime(2026, 10, 8)), isA<NowFree>());
    });

    test('a future day never shows an active event, whatever the time', () {
      final result = status([event(1, 540, 720)], day: DateTime(2026, 10, 8));
      expect(result, isA<DaySummary>());
    });

    test('a past day with events is a past summary', () {
      final summary =
          status([event(1, 540, 720)], day: DateTime(2026, 10, 6)) as DaySummary;
      expect(summary.isPast, isTrue);
      expect(summary.eventCount, 1);
      expect(summary.plannedMinutes, 180);
    });

    test('an empty past day is a past summary with nothing in it', () {
      final summary =
          status(const [], day: DateTime(2026, 10, 6)) as DaySummary;
      expect(summary.isPast, isTrue);
      expect(summary.eventCount, 0);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
# expect: FAIL — "Target of URI doesn't exist: 'package:energy_clock/features/clock/model/now_status.dart'"
flutter test test/features/clock/now_status_test.dart
```

- [ ] **Step 3: Write the function**

**Create `lib/features/clock/model/now_status.dart`**

```dart
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/features/clock/model/active_event.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';

/// What the Now card says. Pure data; the card decides how to draw it.
sealed class NowStatus {
  const NowStatus();
}

/// An event is running now (today only).
final class NowActive extends NowStatus {
  const NowActive({
    required this.event,
    required this.minutesLeft,
    required this.progress,
    required this.overlappingCount,
  });

  final CalendarEvent event;

  /// Minutes until the event's end minute.
  final int minutesLeft;

  /// How much of the event has passed, 0 to 1.
  final double progress;

  /// How many other events are running at the same moment.
  final int overlappingCount;
}

/// Nothing is running, but a later event is planned today.
final class NowNext extends NowStatus {
  const NowNext({required this.event, required this.minutesUntil});

  final CalendarEvent event;
  final int minutesUntil;
}

/// Nothing is planned: today with no events, or a future day with none.
final class NowFree extends NowStatus {
  const NowFree();
}

/// Today has events and every one has finished.
final class NowDone extends NowStatus {
  const NowDone({required this.eventCount, required this.plannedMinutes});

  final int eventCount;
  final int plannedMinutes;
}

/// A future day with events, or any past day.
final class DaySummary extends NowStatus {
  const DaySummary({
    required this.eventCount,
    required this.plannedMinutes,
    required this.isPast,
  });

  final int eventCount;
  final int plannedMinutes;
  final bool isPast;
}

/// Decides what the Now card shows for [selectedDay] at [now].
///
/// An event's end minute is exclusive, so an event is not active at its end
/// minute. Planned minutes sum every event's duration, so overlapping events
/// count twice: overlap is extra load.
NowStatus computeNowStatus({
  required List<CalendarEvent> events,
  required DateTime selectedDay,
  required DateTime now,
}) {
  final today = startOfDay(now);
  final day = startOfDay(selectedDay);
  final plannedMinutes = events.fold<int>(
    0,
    (sum, event) => sum + event.range.durationMinutes,
  );

  if (day.isBefore(today)) {
    return DaySummary(
      eventCount: events.length,
      plannedMinutes: plannedMinutes,
      isPast: true,
    );
  }
  if (day.isAfter(today)) {
    if (events.isEmpty) return const NowFree();
    return DaySummary(
      eventCount: events.length,
      plannedMinutes: plannedMinutes,
      isPast: false,
    );
  }

  if (events.isEmpty) return const NowFree();

  final minute = minuteOfDay(now);
  final active = activeEventsAt(events, minute);
  if (active.isNotEmpty) {
    final event = active.first;
    final elapsed = minute - event.startMinute;
    return NowActive(
      event: event,
      minutesLeft: event.endMinute - minute,
      progress: elapsed / event.range.durationMinutes,
      overlappingCount: active.length - 1,
    );
  }

  final upcoming = [
    for (final event in events)
      if (event.startMinute > minute) event,
  ]..sort((a, b) {
      final byStart = a.startMinute.compareTo(b.startMinute);
      return byStart != 0 ? byStart : a.id.compareTo(b.id);
    });
  if (upcoming.isNotEmpty) {
    return NowNext(
      event: upcoming.first,
      minutesUntil: upcoming.first.startMinute - minute,
    );
  }

  return NowDone(eventCount: events.length, plannedMinutes: plannedMinutes);
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
# expect: PASS
flutter test test/features/clock/now_status_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/clock/model/now_status.dart test/features/clock/now_status_test.dart
git commit -m "feat: pure Now-card state from events, day and time

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 16: Day load and segment widths

How much of the day is each tone: minutes summed per tone (overlap counts twice, because overlap is extra load), and a pure helper that turns those minutes into bar-segment widths with a minimum visible width.

**Files:**
- Create: `lib/features/clock/model/day_load.dart`
- Test: `test/features/clock/day_load_test.dart`

**Interfaces:**
- Produces: `DayLoad(Map<Tone,int>)` with `minutesFor(Tone)`, `totalMinutes`, `isEmpty`, `tones` (tones with time, in `Tone.values` order); `computeDayLoad(List<CalendarEvent>)` → `DayLoad`; `segmentWidths(List<int> minutes, double available, {double minWidth = 8})` → `List<double>` (same length; zero minutes get width 0).
- Consumes: `CalendarEvent`, `Tone`.

- [ ] **Step 1: Write the failing test**

**Create `test/features/clock/day_load_test.dart`**

```dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:energy_clock/features/clock/model/day_load.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent event(int id, int start, int end, Tone tone) => CalendarEvent(
  id: id,
  seriesId: null,
  date: DateTime(2026, 10, 7),
  title: 'Event $id',
  tone: tone,
  range: MinuteRange(start, end),
  status: EventStatus.planned,
);

void main() {
  group('computeDayLoad', () {
    test('no events is empty', () {
      final load = computeDayLoad(const []);
      expect(load.isEmpty, isTrue);
      expect(load.totalMinutes, 0);
      expect(load.tones, isEmpty);
    });

    test('sums minutes per tone', () {
      final load = computeDayLoad([
        event(1, 540, 660, Tone.focus), // 120
        event(2, 780, 840, Tone.life), // 60
        event(3, 900, 1020, Tone.focus), // 120
      ]);
      expect(load.minutesFor(Tone.focus), 240);
      expect(load.minutesFor(Tone.life), 60);
      expect(load.minutesFor(Tone.inbox), 0);
      expect(load.totalMinutes, 300);
      expect(load.isEmpty, isFalse);
    });

    test('overlapping events count twice, because overlap is extra load', () {
      final load = computeDayLoad([
        event(1, 540, 600, Tone.focus),
        event(2, 540, 600, Tone.life),
      ]);
      expect(load.totalMinutes, 120);
    });

    test('lists only tones with time, in the fixed tone order', () {
      final load = computeDayLoad([
        event(1, 60, 120, Tone.inbox),
        event(2, 180, 240, Tone.focus),
      ]);
      expect(load.tones, [Tone.focus, Tone.inbox]);
    });
  });

  group('segmentWidths', () {
    test('widths are proportional to minutes and fill the space', () {
      final widths = segmentWidths([240, 120, 60], 420);
      expect(widths[0], closeTo(240, 1e-9));
      expect(widths[1], closeTo(120, 1e-9));
      expect(widths[2], closeTo(60, 1e-9));
      expect(widths.reduce((a, b) => a + b), closeTo(420, 1e-9));
    });

    test('a tone with no minutes gets no width', () {
      final widths = segmentWidths([100, 0, 100], 200);
      expect(widths, [100, 0, 100]);
    });

    test('a tiny segment is held at the minimum and the rest give way', () {
      final widths = segmentWidths([1000, 10], 300);
      expect(widths[1], 8);
      expect(widths[0], closeTo(292, 1e-9));
      expect(widths.reduce((a, b) => a + b), closeTo(300, 1e-9));
    });

    test('several tiny segments are all held at the minimum', () {
      final widths = segmentWidths([5000, 10, 12], 300);
      expect(widths[1], 8);
      expect(widths[2], 8);
      expect(widths[0], closeTo(284, 1e-9));
    });

    test('a single segment takes everything', () {
      expect(segmentWidths([0, 45, 0], 250), [0, 250, 0]);
    });

    test('nothing planned or no space gives zeros', () {
      expect(segmentWidths([0, 0, 0], 250), [0, 0, 0]);
      expect(segmentWidths([10, 20, 30], 0), [0, 0, 0]);
    });

    test('a segment that only just clears the minimum is not shrunk below it', () {
      // 100 of 2000 minutes in 120 px is 6 px, so it is pinned at 8 and the
      // other segment takes the remaining 112 px.
      final widths = segmentWidths([1900, 100], 120);
      expect(widths[1], 8);
      expect(widths[0], closeTo(112, 1e-9));
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
# expect: FAIL — "Target of URI doesn't exist: 'package:energy_clock/features/clock/model/day_load.dart'"
flutter test test/features/clock/day_load_test.dart
```

- [ ] **Step 3: Write the model**

**Create `lib/features/clock/model/day_load.dart`**

```dart
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';

/// Planned minutes per tone for one day.
class DayLoad {
  const DayLoad(this.minutesByTone);

  final Map<Tone, int> minutesByTone;

  int minutesFor(Tone tone) => minutesByTone[tone] ?? 0;

  int get totalMinutes =>
      minutesByTone.values.fold<int>(0, (sum, minutes) => sum + minutes);

  bool get isEmpty => totalMinutes == 0;

  /// The tones that have planned time, in the fixed tone order.
  List<Tone> get tones => [
    for (final tone in Tone.values)
      if (minutesFor(tone) > 0) tone,
  ];
}

/// Sums each event's duration per tone. Overlapping events count twice,
/// because overlap is extra load.
DayLoad computeDayLoad(List<CalendarEvent> events) {
  final minutes = <Tone, int>{};
  for (final event in events) {
    minutes[event.tone] =
        (minutes[event.tone] ?? 0) + event.range.durationMinutes;
  }
  return DayLoad(minutes);
}

/// Widths for the segments of the day-load bar. Each segment is proportional
/// to its [minutes], except that any non-zero segment is at least [minWidth] so
/// it stays visible; the others give way so the widths still add up to
/// [available]. A zero-minute segment gets width 0.
List<double> segmentWidths(
  List<int> minutes,
  double available, {
  double minWidth = 8,
}) {
  final widths = List<double>.filled(minutes.length, 0);
  final active = [
    for (var i = 0; i < minutes.length; i++)
      if (minutes[i] > 0) i,
  ];
  if (active.isEmpty || available <= 0) return widths;

  final pinned = <int>{};
  while (true) {
    final free = [
      for (final i in active)
        if (!pinned.contains(i)) i,
    ];
    final remaining = available - pinned.length * minWidth;
    final freeTotal = free.fold<int>(0, (sum, i) => sum + minutes[i]);
    if (free.isEmpty || remaining <= 0 || freeTotal == 0) break;

    final tooSmall = [
      for (final i in free)
        if (remaining * minutes[i] / freeTotal < minWidth) i,
    ];
    if (tooSmall.isEmpty) {
      for (final i in free) {
        widths[i] = remaining * minutes[i] / freeTotal;
      }
      break;
    }
    pinned.addAll(tooSmall);
  }
  for (final i in pinned) {
    widths[i] = minWidth;
  }
  return widths;
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
# expect: PASS
flutter test test/features/clock/day_load_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/clock/model/day_load.dart test/features/clock/day_load_test.dart
git commit -m "feat: per-tone day load and day-load bar segment widths

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 17: Week data

The week strip's dots need to know which tones are planned on each day of a week. One new read-only query (distinct date and tone), exposed through the repository interface, the Drift implementation, the in-memory fake, and a provider keyed by a week's Monday.

**Files:**
- Edit: `lib/data/daos/event_dao.dart`, `lib/features/clock/data/event_repository.dart`, `lib/features/clock/providers.dart`, `test/support/fake_event_repository.dart`
- Test: `test/data/event_dao_tones_test.dart`, `test/features/clock/week_tones_test.dart`

**Interfaces:**
- Produces: `EventDao.watchToneDays(DateTime from, DateTime toExclusive)` → `Stream<List<({DateTime date, int toneIndex})>>`; `EventRepository.watchTonesByDay(DateTime from, DateTime toExclusive)` → `Stream<Map<DateTime, Set<Tone>>>` (days with no events are absent); `weekTonesProvider` (`StreamProvider.family<Map<DateTime, Set<Tone>>, DateTime>`, keyed by a week's Monday).
- Consumes: `startOfDay`, `Tone`.

- [ ] **Step 1: Write the failing tests**

**Create `test/data/event_dao_tones_test.dart`**

```dart
import 'package:drift/native.dart';
import 'package:energy_clock/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 10, 3);

  EventsCompanion entry(DateTime date, int toneIndex, int start) {
    return EventsCompanion.insert(
      date: date,
      title: 'Event',
      toneIndex: toneIndex,
      startMinute: start,
      endMinute: start + 30,
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('returns each distinct date and tone once, inside the range only', () async {
    await db.eventDao.insertEvent(entry(DateTime(2026, 10, 5), 0, 60));
    await db.eventDao.insertEvent(entry(DateTime(2026, 10, 5), 0, 120));
    await db.eventDao.insertEvent(entry(DateTime(2026, 10, 5), 2, 180));
    await db.eventDao.insertEvent(entry(DateTime(2026, 10, 6), 1, 60));
    await db.eventDao.insertEvent(entry(DateTime(2026, 10, 12), 1, 60));
    await db.eventDao.insertEvent(entry(DateTime(2026, 10, 4), 1, 60));

    final rows = await db.eventDao
        .watchToneDays(DateTime(2026, 10, 5), DateTime(2026, 10, 12))
        .first;

    final pairs = rows.map((r) => '${r.date.day}:${r.toneIndex}').toSet();
    expect(pairs, {'5:0', '5:2', '6:1'});
    expect(rows, hasLength(3));
  });

  test('an empty range is an empty list', () async {
    final rows = await db.eventDao
        .watchToneDays(DateTime(2026, 10, 5), DateTime(2026, 10, 12))
        .first;
    expect(rows, isEmpty);
  });

  test('emits again when an event is added', () async {
    await db.eventDao.insertEvent(entry(DateTime(2026, 10, 5), 0, 60));
    final counts = <int>[];
    final subscription = db.eventDao
        .watchToneDays(DateTime(2026, 10, 5), DateTime(2026, 10, 12))
        .listen((rows) => counts.add(rows.length));
    addTearDown(subscription.cancel);

    await Future<void>.delayed(const Duration(milliseconds: 50));
    await db.eventDao.insertEvent(entry(DateTime(2026, 10, 6), 1, 60));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(counts, [1, 2]);
  });
}
```

**Create `test/features/clock/week_tones_test.dart`**

```dart
import 'package:drift/native.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_event_repository.dart';

void main() {
  final monday = DateTime(2026, 10, 5);
  final nextMonday = DateTime(2026, 10, 12);

  group('DriftEventRepository.watchTonesByDay', () {
    late AppDatabase db;
    late DriftEventRepository repository;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = DriftEventRepository(db.eventDao);
    });

    tearDown(() async {
      await db.close();
    });

    test('groups the tones by local day and leaves empty days out', () async {
      await repository.createEvent(
        day: DateTime(2026, 10, 5),
        title: 'A',
        tone: Tone.focus,
        range: const MinuteRange(60, 120),
      );
      await repository.createEvent(
        day: DateTime(2026, 10, 5),
        title: 'B',
        tone: Tone.life,
        range: const MinuteRange(180, 240),
      );
      await repository.createEvent(
        day: DateTime(2026, 10, 7),
        title: 'C',
        tone: Tone.inbox,
        range: const MinuteRange(60, 120),
      );
      await repository.createEvent(
        day: nextMonday,
        title: 'Next week',
        tone: Tone.focus,
        range: const MinuteRange(60, 120),
      );

      final byDay = await repository.watchTonesByDay(monday, nextMonday).first;

      expect(byDay.keys.toSet(), {DateTime(2026, 10, 5), DateTime(2026, 10, 7)});
      expect(byDay[DateTime(2026, 10, 5)], {Tone.focus, Tone.life});
      expect(byDay[DateTime(2026, 10, 7)], {Tone.inbox});
    });
  });

  group('weekTonesProvider', () {
    late FakeEventRepository repository;

    setUp(() {
      repository = FakeEventRepository();
    });

    tearDown(() {
      repository.dispose();
    });

    test('covers Monday to Sunday of the keyed week', () async {
      await repository.createEvent(
        day: DateTime(2026, 10, 11), // Sunday, last day of the week
        title: 'Sunday',
        tone: Tone.life,
        range: const MinuteRange(60, 120),
      );
      await repository.createEvent(
        day: nextMonday, // belongs to the next week
        title: 'Monday',
        tone: Tone.focus,
        range: const MinuteRange(60, 120),
      );
      final container = ProviderContainer(
        overrides: [eventRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final byDay = await container.read(weekTonesProvider(monday).future);
      expect(byDay.keys.toSet(), {DateTime(2026, 10, 11)});
      expect(byDay[DateTime(2026, 10, 11)], {Tone.life});
    });

    test('different weeks are different providers', () async {
      await repository.createEvent(
        day: nextMonday,
        title: 'Monday',
        tone: Tone.focus,
        range: const MinuteRange(60, 120),
      );
      final container = ProviderContainer(
        overrides: [eventRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      expect(await container.read(weekTonesProvider(monday).future), isEmpty);
      expect(
        (await container.read(weekTonesProvider(nextMonday).future)).keys,
        [nextMonday],
      );
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL — 'watchToneDays', 'watchTonesByDay' and 'weekTonesProvider' do not exist
flutter test test/data/event_dao_tones_test.dart test/features/clock/week_tones_test.dart
```

- [ ] **Step 3: Add the query, the repository method, the fake, and the provider**

**Edit `lib/data/daos/event_dao.dart`**

Replace:

```dart
  Future<void> deleteById(int id) =>
      (delete(events)..where((row) => row.id.equals(id))).go();
}
```

With:

```dart
  Future<void> deleteById(int id) =>
      (delete(events)..where((row) => row.id.equals(id))).go();

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
            events.date.isSmallerThanValue(toExclusive),
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
}
```

**Edit `lib/features/clock/data/event_repository.dart`**

Replace:

```dart
  Stream<List<CalendarEvent>> watchDay(DateTime day);
  Future<List<CalendarEvent>> eventsForDay(DateTime day);
```

With:

```dart
  Stream<List<CalendarEvent>> watchDay(DateTime day);
  Future<List<CalendarEvent>> eventsForDay(DateTime day);

  /// The tones planned on each day from [from] (inclusive) to [toExclusive],
  /// for the week strip's dots. Days with no events are absent from the map.
  Stream<Map<DateTime, Set<Tone>>> watchTonesByDay(
    DateTime from,
    DateTime toExclusive,
  );
```

**Edit `lib/features/clock/data/event_repository.dart`** — the implementation.

Replace:

```dart
  @override
  Future<List<CalendarEvent>> eventsForDay(DateTime day) async {
    final rows = await _dao.eventsForDay(startOfDay(day));
    return rows.map(CalendarEvent.fromRow).toList();
  }
```

With:

```dart
  @override
  Future<List<CalendarEvent>> eventsForDay(DateTime day) async {
    final rows = await _dao.eventsForDay(startOfDay(day));
    return rows.map(CalendarEvent.fromRow).toList();
  }

  @override
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

**Edit `test/support/fake_event_repository.dart`**

Replace:

```dart
  @override
  Future<List<CalendarEvent>> eventsForDay(DateTime day) async => _forDay(day);
```

With:

```dart
  @override
  Future<List<CalendarEvent>> eventsForDay(DateTime day) async => _forDay(day);

  Map<DateTime, Set<Tone>> _tonesBetween(DateTime from, DateTime toExclusive) {
    final start = startOfDay(from);
    final end = startOfDay(toExclusive);
    final byDay = <DateTime, Set<Tone>>{};
    for (final event in _events) {
      if (event.date.isBefore(start) || !event.date.isBefore(end)) continue;
      byDay.putIfAbsent(event.date, () => <Tone>{}).add(event.tone);
    }
    return byDay;
  }

  @override
  Stream<Map<DateTime, Set<Tone>>> watchTonesByDay(
    DateTime from,
    DateTime toExclusive,
  ) async* {
    yield _tonesBetween(from, toExclusive);
    yield* _changes.stream.map((_) => _tonesBetween(from, toExclusive));
  }
```

**Edit `lib/features/clock/providers.dart`**

Replace:

```dart
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/providers.dart';
```

With:

```dart
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/providers.dart';
```

**Edit `lib/features/clock/providers.dart`** — the provider itself.

Replace:

```dart
final clockProvider = NotifierProvider<ClockNotifier, DateTime>(
  ClockNotifier.new,
);
```

With:

```dart
final clockProvider = NotifierProvider<ClockNotifier, DateTime>(
  ClockNotifier.new,
);

/// The tones planned on each day of the week that starts at the keyed Monday,
/// for the week strip's dots. Each page of the strip watches its own week.
final weekTonesProvider =
    StreamProvider.family<Map<DateTime, Set<Tone>>, DateTime>((ref, weekStart) {
      final end = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
      return ref.watch(eventRepositoryProvider).watchTonesByDay(weekStart, end);
    });
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
# expect: PASS
flutter test test/data test/features/clock/week_tones_test.dart && flutter analyze
```

- [ ] **Step 5: Commit**

```bash
git add lib/data/daos/event_dao.dart lib/features/clock/data/event_repository.dart lib/features/clock/providers.dart test/support/fake_event_repository.dart test/data/event_dao_tones_test.dart test/features/clock/week_tones_test.dart
git commit -m "feat: watch the tones planned on each day of a week

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 18: Clock header and week strip

The header shows the day name and date, a Today pill when you are on another day, a "Read-only" chip on past days, and the round **+** button. The week strip replaces the old `<` `>` arrows: seven day pills, each with up to three tone dots; tapping selects a day, and swiping moves the selected day by seven days so the header, dial and strip always agree. The old `DayHeader` stays until Task 21 removes its last user.

**Files:**
- Create: `lib/features/clock/widgets/clock_header.dart`, `lib/features/clock/widgets/week_strip.dart`, `test/support/clock_harness.dart`
- Test: `test/features/clock/clock_header_test.dart`, `test/features/clock/week_strip_test.dart`

**Interfaces:**
- Produces: `ClockHeader({required VoidCallback onAdd, bool showDate = true})` with `ClockHeader.height` (48) and `ClockHeader.heightFor(double textScale, {required bool showDate})`; `WeekStrip({bool showDots = true})` with `WeekStrip.heightFor(double textScale)`; day-pill dots are keyed `ValueKey('dot-yyyy-MM-dd-<tone name>')`.
- Produces (test helper): `ClockHarness({DateTime? now, DateTime? selected, List<Override> overrides = const []})` with `clock`, `repository`, `container`, `app(Widget, {double textScale, bool reduceMotion, ThemeData? theme})`, `dispose()`. Default clock is Wednesday 7 October 2026, 10:30; `overrides` adds provider overrides (Plan 1B uses it for fake settings).
- Consumes: `selectedDateProvider`, `clockProvider`, `weekTonesProvider`; `startOfWeek`, `daysOfWeek`; `Strings`; `PressScale`, `AppColors`, `ToneColors`, `AppMotion`.

- [ ] **Step 1: Write the harness and the failing tests**

**Create `test/support/clock_harness.dart`**

```dart
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fake_clock.dart';
import 'fake_event_repository.dart';

/// A provider container with a fake clock and an in-memory event repository,
/// plus helpers to mount a widget under it. The default clock is Wednesday
/// 7 October 2026, 10:30, and that day is selected. [overrides] adds more
/// provider overrides (for example fake settings).
class ClockHarness {
  ClockHarness({
    DateTime? now,
    DateTime? selected,
    List<Override> overrides = const [],
  }) : clock = FakeClock(now ?? DateTime(2026, 10, 7, 10, 30)),
       repository = FakeEventRepository() {
    container = ProviderContainer(
      overrides: [
        clockProvider.overrideWith(() => clock),
        eventRepositoryProvider.overrideWithValue(repository),
        ...overrides,
      ],
    );
    if (selected != null) {
      container.read(selectedDateProvider.notifier).select(selected);
    }
  }

  final FakeClock clock;
  final FakeEventRepository repository;
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
    repository.dispose();
  }
}
```

**Create `test/features/clock/clock_header_test.dart`**

```dart
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/clock_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

Finder addButton() => find.byWidgetPredicate(
  (widget) => widget is IconButton && widget.tooltip == Strings.addEvent,
);

void main() {
  late ClockHarness harness;

  tearDown(() {
    harness.dispose();
  });

  testWidgets('shows the day name and the date', (tester) async {
    harness = ClockHarness(); // Wednesday 7 October 2026
    await tester.pumpWidget(harness.app(ClockHeader(onAdd: () {})));

    expect(find.text('Wednesday'), findsOneWidget);
    expect(find.text('7 October 2026'), findsOneWidget);
  });

  testWidgets('the date line can be dropped on a very short screen', (
    tester,
  ) async {
    harness = ClockHarness();
    await tester.pumpWidget(
      harness.app(ClockHeader(onAdd: () {}, showDate: false)),
    );
    expect(find.text('Wednesday'), findsOneWidget);
    expect(find.text('7 October 2026'), findsNothing);
  });

  testWidgets('hides the Today pill on today and shows it elsewhere', (
    tester,
  ) async {
    harness = ClockHarness();
    await tester.pumpWidget(harness.app(ClockHeader(onAdd: () {})));
    expect(find.text(Strings.today), findsNothing);

    harness.container
        .read(selectedDateProvider.notifier)
        .select(DateTime(2026, 10, 9));
    await tester.pump();
    expect(find.text(Strings.today), findsOneWidget);
  });

  testWidgets('tapping Today returns to the clock\'s today', (tester) async {
    harness = ClockHarness(selected: DateTime(2026, 12, 25));
    await tester.pumpWidget(harness.app(ClockHeader(onAdd: () {})));

    await tester.tap(find.text(Strings.today));
    await tester.pump();

    expect(
      harness.container.read(selectedDateProvider),
      DateTime(2026, 10, 7),
    );
    expect(find.text(Strings.today), findsNothing);
  });

  testWidgets('the + button calls onAdd on an editable day', (tester) async {
    harness = ClockHarness();
    var adds = 0;
    await tester.pumpWidget(harness.app(ClockHeader(onAdd: () => adds++)));

    await tester.tap(addButton());
    expect(adds, 1);
  });

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

  testWidgets('an editable day has no Read-only chip', (tester) async {
    harness = ClockHarness();
    await tester.pumpWidget(harness.app(ClockHeader(onAdd: () {})));
    expect(find.text(Strings.readOnlyChip), findsNothing);
  });

  testWidgets('the + button is at least 44 x 44', (tester) async {
    harness = ClockHarness();
    await tester.pumpWidget(harness.app(ClockHeader(onAdd: () {})));
    final size = tester.getSize(addButton());
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('a long day name at double text size does not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    harness = ClockHarness(selected: DateTime(2026, 10, 7));
    await tester.pumpWidget(
      harness.app(ClockHeader(onAdd: () {}), textScale: 2),
    );
    harness.container
        .read(selectedDateProvider.notifier)
        .select(DateTime(2026, 10, 9));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('height budgets', () {
    expect(ClockHeader.height, 48);
    expect(ClockHeader.heightFor(1, showDate: true), 48);
    expect(ClockHeader.heightFor(1, showDate: false), 34);
    expect(ClockHeader.heightFor(2, showDate: true), 92);
  });
}
```

**Create `test/features/clock/week_strip_test.dart`**

```dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/week_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;

  setUp(() {
    // Wednesday 7 October 2026: its week runs Monday 5 to Sunday 11.
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> addEvent(DateTime day, Tone tone, int start) =>
      harness.repository.createEvent(
        day: day,
        title: 'Event',
        tone: tone,
        range: MinuteRange(start, start + 60),
      );

  testWidgets('shows the seven days of the selected week, Monday first', (
    tester,
  ) async {
    await tester.pumpWidget(harness.app(const WeekStrip()));
    await tester.pumpAndSettle();

    for (final label in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
      expect(find.text(label), findsOneWidget);
    }
    for (final date in ['5', '6', '7', '8', '9', '10', '11']) {
      expect(find.text(date), findsOneWidget);
    }
  });

  testWidgets('the selected day reads as selected, and today is announced', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(harness.app(const WeekStrip()));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.bySemanticsLabel('Wednesday 7 October, today'),
      ),
      matchesSemantics(
        label: 'Wednesday 7 October, today',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    expect(
      find.semantics.byLabel('Thursday 8 October'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('tapping a day selects it', (tester) async {
    await tester.pumpWidget(harness.app(const WeekStrip()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('9'));
    await tester.pump();

    expect(
      harness.container.read(selectedDateProvider),
      DateTime(2026, 10, 9),
    );
  });

  testWidgets('past days can be selected too', (tester) async {
    await tester.pumpWidget(harness.app(const WeekStrip()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('5'));
    await tester.pump();
    expect(
      harness.container.read(selectedDateProvider),
      DateTime(2026, 10, 5),
    );
  });

  testWidgets('shows a dot for each tone planned that day', (tester) async {
    await addEvent(DateTime(2026, 10, 7), Tone.focus, 60);
    await addEvent(DateTime(2026, 10, 7), Tone.life, 180);
    await addEvent(DateTime(2026, 10, 7), Tone.focus, 300);
    await tester.pumpWidget(harness.app(const WeekStrip()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('dot-2026-10-07-focus')), findsOneWidget);
    expect(find.byKey(const ValueKey('dot-2026-10-07-life')), findsOneWidget);
    expect(find.byKey(const ValueKey('dot-2026-10-07-inbox')), findsNothing);
    expect(find.byKey(const ValueKey('dot-2026-10-08-focus')), findsNothing);
  });

  testWidgets('the planned tones are part of the spoken label', (tester) async {
    final handle = tester.ensureSemantics();
    await addEvent(DateTime(2026, 10, 8), Tone.focus, 60);
    await addEvent(DateTime(2026, 10, 8), Tone.life, 180);
    await tester.pumpWidget(harness.app(const WeekStrip()));
    await tester.pumpAndSettle();

    expect(
      find.semantics.byLabel('Thursday 8 October, Focus and Life planned'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('a new event adds its dot straight away', (tester) async {
    await tester.pumpWidget(harness.app(const WeekStrip()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dot-2026-10-09-inbox')), findsNothing);

    await addEvent(DateTime(2026, 10, 9), Tone.inbox, 60);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dot-2026-10-09-inbox')), findsOneWidget);
  });

  testWidgets('dots are hidden when showDots is false', (tester) async {
    await addEvent(DateTime(2026, 10, 7), Tone.focus, 60);
    await tester.pumpWidget(harness.app(const WeekStrip(showDots: false)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dot-2026-10-07-focus')), findsNothing);
  });

  testWidgets('dots are hidden at large text sizes', (tester) async {
    await addEvent(DateTime(2026, 10, 7), Tone.focus, 60);
    await tester.pumpWidget(harness.app(const WeekStrip(), textScale: 2));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dot-2026-10-07-focus')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('if the week cannot be read the strip still works, without dots', (
    tester,
  ) async {
    harness.dispose();
    harness = ClockHarness(
      overrides: [
        weekTonesProvider.overrideWith(
          (ref, weekStart) => Stream<Map<DateTime, Set<Tone>>>.error(
            StateError('database closed'),
          ),
        ),
      ],
    );
    await addEvent(DateTime(2026, 10, 7), Tone.focus, 60);
    await tester.pumpWidget(harness.app(const WeekStrip()));
    await tester.pumpAndSettle();

    expect(find.text('Wed'), findsOneWidget);
    expect(find.byKey(const ValueKey('dot-2026-10-07-focus')), findsNothing);

    await tester.tap(find.text('8'));
    await tester.pumpAndSettle();
    expect(
      harness.container.read(selectedDateProvider),
      DateTime(2026, 10, 8),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('swiping to the next week moves the selected day by seven days', (
    tester,
  ) async {
    await tester.pumpWidget(harness.app(const WeekStrip()));
    await tester.pumpAndSettle();

    await tester.fling(find.byType(PageView), const Offset(-500, 0), 1500);
    await tester.pumpAndSettle();

    expect(
      harness.container.read(selectedDateProvider),
      DateTime(2026, 10, 14),
    );
    expect(find.text('12'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
  });

  testWidgets('swiping back moves the selected day back by seven days', (
    tester,
  ) async {
    await tester.pumpWidget(harness.app(const WeekStrip()));
    await tester.pumpAndSettle();

    await tester.fling(find.byType(PageView), const Offset(500, 0), 1500);
    await tester.pumpAndSettle();

    expect(
      harness.container.read(selectedDateProvider),
      DateTime(2026, 9, 30),
    );
  });

  testWidgets('selecting a date elsewhere moves the strip to its week', (
    tester,
  ) async {
    await tester.pumpWidget(harness.app(const WeekStrip()));
    await tester.pumpAndSettle();

    harness.container
        .read(selectedDateProvider.notifier)
        .select(DateTime(2026, 10, 21));
    await tester.pumpAndSettle();

    expect(find.text('19'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(
      harness.container.read(selectedDateProvider),
      DateTime(2026, 10, 21),
    );
  });

  testWidgets('with reduced motion the strip jumps instead of sliding', (
    tester,
  ) async {
    await tester.pumpWidget(harness.app(const WeekStrip(), reduceMotion: true));
    await tester.pumpAndSettle();

    harness.container
        .read(selectedDateProvider.notifier)
        .select(DateTime(2026, 11, 4));
    await tester.pump();
    expect(find.text('2'), findsOneWidget); // Monday 2 November
  });

  testWidgets('every pill is at least 44 pt wide on a 375 pt phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness.app(const WeekStrip()));
    await tester.pumpAndSettle();

    for (final date in ['5', '6', '7', '8', '9', '10', '11']) {
      final pill = find.ancestor(
        of: find.text(date),
        matching: find.byType(GestureDetector),
      );
      expect(tester.getSize(pill.first).width, greaterThanOrEqualTo(44));
    }
  });

  test('height budget', () {
    expect(WeekStrip.heightFor(1), 60);
    expect(WeekStrip.heightFor(2), 92);
    expect(WeekStrip.heightFor(3), 92); // clamped at 2
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL — 'package:energy_clock/features/clock/widgets/clock_header.dart' and 'week_strip.dart' do not exist
flutter test test/features/clock/clock_header_test.dart test/features/clock/week_strip_test.dart
```

- [ ] **Step 3: Write the header and the strip**

**Create `lib/features/clock/widgets/clock_header.dart`**

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
/// on another day, a "Read-only" chip on past days, and the round + button.
class ClockHeader extends ConsumerWidget {
  const ClockHeader({required this.onAdd, this.showDate = true, super.key});

  /// Height at normal text size, with the date line.
  static const double height = 48;

  /// The height to budget at [textScale], with or without the date line.
  static double heightFor(double textScale, {required bool showDate}) =>
      (showDate ? 44 : 30) * textScale + 4;

  final VoidCallback onAdd;

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
              DecoratedBox(
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
              const SizedBox(width: AppSpacing.sm),
            ],
            if (!isToday) ...[
              TextButton(
                onPressed: ref.read(selectedDateProvider.notifier).today,
                style: TextButton.styleFrom(
                  foregroundColor: colors.ink,
                  backgroundColor: colors.ink.withValues(alpha: 0.08),
                  shape: const StadiumBorder(),
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                ),
                child: const Text(Strings.today),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            IconButton.filled(
              icon: const Icon(Icons.add),
              tooltip: Strings.addEvent,
              onPressed: readOnly ? null : onAdd,
              style: IconButton.styleFrom(
                backgroundColor: colors.ink,
                foregroundColor: colors.onInk,
                disabledBackgroundColor: colors.ink.withValues(alpha: 0.12),
                disabledForegroundColor: colors.ink.withValues(alpha: 0.38),
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
```

**Create `lib/features/clock/widgets/week_strip.dart`**

```dart
import 'dart:async';
import 'dart:math' as math;

import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/shared/widgets/press_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Seven day pills for the week containing the selected day, Monday first.
/// Each pill shows the date and a dot for every tone planned that day. Tapping
/// selects a day. Swiping moves the selected day by seven days (same weekday),
/// so the header, the dial and the strip always agree.
class WeekStrip extends ConsumerStatefulWidget {
  const WeekStrip({this.showDots = true, super.key});

  /// The height to budget at [textScale].
  static double heightFor(double textScale) =>
      math.max(60.0, 32 * textScale.clamp(1.0, 2.0) + 28);

  final bool showDots;

  @override
  ConsumerState<WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends ConsumerState<WeekStrip> {
  /// The strip is an unbounded page view. This page shows [_anchorWeek], the
  /// week that was selected when the strip was built.
  static const int _centerPage = 5000;

  late final DateTime _anchorWeek;
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _anchorWeek = startOfWeek(ref.read(selectedDateProvider));
    _controller = PageController(initialPage: _centerPage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  DateTime _weekForPage(int page) => DateTime(
    _anchorWeek.year,
    _anchorWeek.month,
    _anchorWeek.day + 7 * (page - _centerPage),
  );

  int _pageForWeek(DateTime weekStart) =>
      _centerPage + _daysBetween(_anchorWeek, weekStart) ~/ 7;

  /// The user swiped to another week: keep the same weekday in that week.
  void _onPageChanged(int page) {
    final weekStart = _weekForPage(page);
    final selected = ref.read(selectedDateProvider);
    final selectedWeek = startOfWeek(selected);
    if (selectedWeek == weekStart) return;
    final shift = _daysBetween(selectedWeek, weekStart);
    ref
        .read(selectedDateProvider.notifier)
        .select(DateTime(selected.year, selected.month, selected.day + shift));
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final showDots = widget.showDots && textScale <= 1.3;

    // The date changed somewhere else (for example the Today button): bring
    // its week into view.
    ref.listen(selectedDateProvider, (previous, next) {
      final page = _pageForWeek(startOfWeek(next));
      if (!_controller.hasClients || _controller.page?.round() == page) return;
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
    });

    return SizedBox(
      height: WeekStrip.heightFor(textScale),
      child: PageView.builder(
        controller: _controller,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, page) =>
            _WeekRow(weekStart: _weekForPage(page), showDots: showDots),
      ),
    );
  }
}

class _WeekRow extends ConsumerWidget {
  const _WeekRow({required this.weekStart, required this.showDots});

  final DateTime weekStart;
  final bool showDots;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDateProvider);
    final today = startOfDay(ref.watch(clockProvider));
    final tones =
        ref.watch(weekTonesProvider(weekStart)).valueOrNull ??
        const <DateTime, Set<Tone>>{};

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg - 2,
        vertical: 2,
      ),
      child: Row(
        children: [
          for (final day in daysOfWeek(weekStart))
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _DayPill(
                  day: day,
                  isSelected: day == selected,
                  isToday: day == today,
                  tones: tones[day] ?? const <Tone>{},
                  showDots: showDots,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayPill extends ConsumerWidget {
  const _DayPill({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.tones,
    required this.showDots,
  });

  final DateTime day;
  final bool isSelected;
  final bool isToday;
  final Set<Tone> tones;
  final bool showDots;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final toneColors = context.toneColors;
    final theme = Theme.of(context);
    final ordered = [
      for (final tone in Tone.values)
        if (tones.contains(tone)) tone,
    ];
    final dayKey = DateFormat('yyyy-MM-dd').format(day);

    void select() {
      unawaited(HapticFeedback.selectionClick());
      ref.read(selectedDateProvider.notifier).select(day);
    }

    return Semantics(
      button: true,
      selected: isSelected,
      label: Strings.weekDaySemantics(
        DateFormat('EEEE d MMMM').format(day),
        tones: Strings.joinWords([for (final tone in ordered) tone.label]),
        isToday: isToday,
      ),
      excludeSemantics: true,
      onTap: select,
      child: PressScale(
        onTap: select,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isSelected ? colors.ink : AppColors.transparent,
            border: !isSelected && isToday
                ? Border.all(color: colors.ink, width: 1.5)
                : null,
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    DateFormat('E').format(day),
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: isSelected
                          ? colors.onInk.withValues(alpha: 0.7)
                          : colors.muted,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${day.day}',
                    style: theme.textTheme.labelLarge!.copyWith(
                      color: isSelected ? colors.onInk : colors.ink,
                    ),
                  ),
                ),
                SizedBox(
                  height: 6,
                  child: showDots
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final tone in ordered)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1.5,
                                ),
                                child: DecoratedBox(
                                  key: ValueKey('dot-$dayKey-${tone.name}'),
                                  decoration: BoxDecoration(
                                    color: toneColors.fillFor(tone),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const SizedBox.square(dimension: 6),
                                ),
                              ),
                          ],
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
# expect: PASS
flutter test test/features/clock/clock_header_test.dart test/features/clock/week_strip_test.dart && flutter analyze
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/clock/widgets/clock_header.dart lib/features/clock/widgets/week_strip.dart test/support/clock_harness.dart test/features/clock/clock_header_test.dart test/features/clock/week_strip_test.dart
git commit -m "feat: clock header and week strip with tone dots

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 19: Now card

A big rounded card under the dial. Running event: filled with the tone's colour, with the title, time left and a progress bar. Otherwise a neutral card: what is next, an invitation to plan, "all done", or a summary of another day. Tapping the card opens the active or next event.

**Files:**
- Create: `lib/features/clock/widgets/now_card.dart`
- Test: `test/features/clock/now_card_test.dart`, `test/features/clock/now_card_golden_test.dart`
- Create: `test/features/clock/goldens/now_card_*.png`

**Interfaces:**
- Produces: `NowCard({required void Function(CalendarEvent) onOpenEvent, bool compact = false})` with `NowCard.height` (96), `NowCard.heightFor(double textScale)` (`max(96, 36 + 56 × scale)`, the full card's budget) and `NowCard.compactHeightFor(double textScale)` (`24 + 28 × scale`).
- Consumes: `computeNowStatus` (Task 15), `selectedDateProvider`, `dayEventsProvider`, `clockProvider`, `AppCard`, `ToneColors`, `Strings`, `formatDurationMinutes`, `formatMinuteOfDay`, `spokenDurationMinutes`.

- [ ] **Step 1: Write the failing test**

**Create `test/features/clock/now_card_test.dart`**

```dart
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:energy_clock/features/clock/widgets/now_card.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;
  CalendarEvent? opened;

  setUp(() {
    opened = null;
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> add(
    String title,
    Tone tone,
    int start,
    int end, {
    DateTime? day,
  }) => harness.repository.createEvent(
    day: day ?? DateTime(2026, 10, 7),
    title: title,
    tone: tone,
    range: MinuteRange(start, end),
  );

  Future<void> show(
    WidgetTester tester, {
    bool compact = false,
    double textScale = 1,
  }) async {
    // Tight in width and unbounded in height, as in the Clock column, so the
    // card takes its natural height instead of filling the screen.
    await tester.pumpWidget(
      harness.app(
        UnconstrainedBox(
          constrainedAxis: Axis.horizontal,
          alignment: Alignment.topCenter,
          child: NowCard(onOpenEvent: (e) => opened = e, compact: compact),
        ),
        textScale: textScale,
      ),
    );
    await tester.pump();
  }

  Color? cardFill(WidgetTester tester) {
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(AppCard),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    return (box.decoration as ShapeDecoration).color;
  }

  group('today', () {
    testWidgets('free: invites you to plan', (tester) async {
      harness = ClockHarness();
      await show(tester);
      expect(find.text(Strings.emptyDayTitle), findsOneWidget);
      expect(find.text(Strings.emptyDayHint), findsOneWidget);
    });

    testWidgets('active: filled with the tone colour, with time left', (
      tester,
    ) async {
      harness = ClockHarness(); // 10:30
      await add('Deep work', Tone.focus, 540, 720); // 09:00-12:00
      await show(tester);

      expect(find.text('Deep work'), findsOneWidget);
      expect(find.text('Focus'), findsOneWidget);
      expect(find.text('1h 30m left · until 12:00'), findsOneWidget);
      expect(cardFill(tester), ToneColors.light.fillFor(Tone.focus));
      final title = tester.widget<Text>(find.text('Deep work'));
      expect(title.style!.color, ToneColors.light.labelFor(Tone.focus));
    });

    testWidgets('active on Life uses near-black text on the green card', (
      tester,
    ) async {
      harness = ClockHarness();
      await add('Walk', Tone.life, 600, 660);
      await show(tester);
      expect(cardFill(tester), ToneColors.light.fillFor(Tone.life));
      expect(
        tester.widget<Text>(find.text('Walk')).style!.color,
        ToneColors.light.labelFor(Tone.life),
      );
    });

    testWidgets('active with overlaps shows the latest-started and a count', (
      tester,
    ) async {
      harness = ClockHarness();
      await add('Deep work', Tone.focus, 540, 720);
      await add('Call', Tone.inbox, 600, 660);
      await show(tester);

      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Inbox · +1 overlapping'), findsOneWidget);
      expect(cardFill(tester), ToneColors.light.fillFor(Tone.inbox));
    });

    testWidgets('next: a neutral card says when it starts', (tester) async {
      harness = ClockHarness();
      await add('Lunch', Tone.life, 750, 795); // 12:30
      await show(tester);

      expect(find.text(Strings.nowNextUp), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('Starts at 12:30 · in 2h'), findsOneWidget);
      expect(cardFill(tester), isNot(ToneColors.light.fillFor(Tone.life)));
    });

    testWidgets('done: everything has finished', (tester) async {
      harness = ClockHarness(now: DateTime(2026, 10, 7, 20, 0));
      await add('Deep work', Tone.focus, 540, 720);
      await show(tester);

      expect(find.text(Strings.nowDoneTitle), findsOneWidget);
      expect(find.text('1 event · 3h planned'), findsOneWidget);
    });

    testWidgets('moves on by itself when the clock ticks', (tester) async {
      harness = ClockHarness(now: DateTime(2026, 10, 7, 11, 59));
      await add('Deep work', Tone.focus, 540, 720);
      await show(tester);
      expect(find.text('1m left · until 12:00'), findsOneWidget);

      harness.clock.set(DateTime(2026, 10, 7, 12, 0));
      await tester.pump();
      expect(find.text(Strings.nowDoneTitle), findsOneWidget);
    });
  });

  group('other days', () {
    testWidgets('a future day with events is summarised', (tester) async {
      harness = ClockHarness(selected: DateTime(2026, 10, 8)); // Thursday
      await add('A', Tone.focus, 540, 720, day: DateTime(2026, 10, 8));
      await add('B', Tone.life, 780, 825, day: DateTime(2026, 10, 8));
      await show(tester);

      expect(find.text('Thursday · 2 events'), findsOneWidget);
      expect(find.text('3h 45m planned'), findsOneWidget);
    });

    testWidgets('an empty future day invites you to plan', (tester) async {
      harness = ClockHarness(selected: DateTime(2026, 10, 8));
      await show(tester);
      expect(find.text(Strings.emptyDayTitle), findsOneWidget);
    });

    testWidgets('a past day says it is read-only', (tester) async {
      harness = ClockHarness(selected: DateTime(2026, 10, 6));
      await add('A', Tone.focus, 540, 720, day: DateTime(2026, 10, 6));
      await show(tester);

      expect(find.text(Strings.readOnlyChip), findsOneWidget);
      expect(find.text('1 event · 3h'), findsOneWidget);
    });

    testWidgets('an empty past day says nothing was planned', (tester) async {
      harness = ClockHarness(selected: DateTime(2026, 10, 6));
      await show(tester);
      expect(find.text(Strings.pastNothingPlanned), findsOneWidget);
    });
  });

  group('tapping', () {
    testWidgets('opens the running event', (tester) async {
      harness = ClockHarness();
      await add('Deep work', Tone.focus, 540, 720);
      await show(tester);

      await tester.tap(find.byType(NowCard));
      expect(opened?.title, 'Deep work');
    });

    testWidgets('opens the next event', (tester) async {
      harness = ClockHarness();
      await add('Lunch', Tone.life, 750, 795);
      await show(tester);

      await tester.tap(find.byType(NowCard));
      expect(opened?.title, 'Lunch');
    });

    testWidgets('does nothing when there is no event to open', (tester) async {
      harness = ClockHarness();
      await show(tester);
      await tester.tap(find.byType(NowCard));
      expect(opened, isNull);
    });
  });

  group('compact', () {
    testWidgets('is shorter and shows only the title and time left', (
      tester,
    ) async {
      harness = ClockHarness();
      await add('Deep work', Tone.focus, 540, 720);
      await show(tester, compact: true);

      expect(find.text('Deep work'), findsOneWidget);
      expect(find.text('1h 30m left'), findsOneWidget);
      expect(find.text('Focus'), findsNothing);
      expect(
        tester.getSize(find.byType(NowCard)).height,
        lessThan(NowCard.height),
      );
    });

    testWidgets('a free day is one line', (tester) async {
      harness = ClockHarness();
      await show(tester, compact: true);
      expect(find.text(Strings.emptyDayTitle), findsOneWidget);
      expect(find.text(Strings.emptyDayHint), findsNothing);
    });

    testWidgets('does not overflow at double text size', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      harness = ClockHarness();
      await add('A rather long event title for a narrow screen', Tone.focus, 540, 720);
      await show(tester, compact: true, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('semantics', () {
    testWidgets('a running event reads as one sentence', (tester) async {
      final handle = tester.ensureSemantics();
      harness = ClockHarness();
      await add('Deep work', Tone.focus, 540, 720);
      await show(tester);

      expect(
        tester.getSemantics(find.bySemanticsLabel('Now: Deep work, Focus, 1 hour 30 minutes left'),
        ),
        matchesSemantics(
          label: 'Now: Deep work, Focus, 1 hour 30 minutes left',
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('the next event reads as one sentence', (tester) async {
      final handle = tester.ensureSemantics();
      harness = ClockHarness();
      await add('Lunch', Tone.life, 750, 795);
      await show(tester);

      expect(
        find.semantics.byLabel('Next up: Lunch, Life, starts in 2 hours'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('height budgets', () {
    test('the constants', () {
      expect(NowCard.height, 96);
      expect(NowCard.heightFor(1), 96);
      expect(NowCard.heightFor(0.9), 96);
      expect(NowCard.heightFor(1.3), closeTo(108.8, 0.001));
      expect(NowCard.compactHeightFor(1), 52);
      expect(NowCard.compactHeightFor(2), 80);
    });

    // The tallest content: a running event with caption, title, time left and
    // progress bar.
    for (final scale in [1.0, 1.15, 1.3]) {
      testWidgets('the full card fits its budget at $scale', (tester) async {
        harness = ClockHarness();
        await add('Deep work', Tone.focus, 540, 720);
        await show(tester, textScale: scale);
        expect(
          tester.getSize(find.byType(NowCard)).height,
          lessThanOrEqualTo(NowCard.heightFor(scale)),
        );
      });
    }

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('the compact card fits its budget at $scale', (tester) async {
        harness = ClockHarness();
        await add('Deep work', Tone.focus, 540, 720);
        await show(tester, compact: true, textScale: scale);
        expect(
          tester.getSize(find.byType(NowCard)).height,
          lessThanOrEqualTo(NowCard.compactHeightFor(scale)),
        );
      });
    }
  });
}
```

**Create `test/features/clock/now_card_golden_test.dart`**

```dart
// Golden images of the Now card's states. The clock is fixed at Wednesday
// 7 October 2026, 10:30, animations are off, and `test/flutter_test_config.dart`
// loads Nunito, so every image is deterministic and shows real text.
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/widgets/now_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

const cardKey = ValueKey('now-card-golden');

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> add(String title, Tone tone, int start, int end) =>
      harness.repository.createEvent(
        day: DateTime(2026, 10, 7),
        title: title,
        tone: tone,
        range: MinuteRange(start, end),
      );

  Future<void> check(WidgetTester tester, ThemeData theme, String file) async {
    await tester.pumpWidget(
      harness.app(
        RepaintBoundary(
          key: cardKey,
          child: Builder(
            builder: (context) => ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: 358,
                  child: NowCard(onOpenEvent: (_) {}),
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

  testWidgets('a running Focus event, light', (tester) async {
    await add('Deep work', Tone.focus, 540, 720);
    await check(tester, AppTheme.light, 'now_card_active_focus_light.png');
  });

  testWidgets('a running Life event, dark', (tester) async {
    await add('Lunch walk', Tone.life, 600, 660);
    await check(tester, AppTheme.dark, 'now_card_active_life_dark.png');
  });

  testWidgets('overlapping events, light', (tester) async {
    await add('Deep work', Tone.focus, 540, 720);
    await add('Call', Tone.inbox, 600, 660);
    await check(tester, AppTheme.light, 'now_card_overlap_light.png');
  });

  testWidgets('the next event, light', (tester) async {
    await add('Lunch', Tone.life, 750, 795);
    await check(tester, AppTheme.light, 'now_card_next_light.png');
  });

  testWidgets('a free day, light', (tester) async {
    await check(tester, AppTheme.light, 'now_card_free_light.png');
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL — "Target of URI doesn't exist: 'package:energy_clock/features/clock/widgets/now_card.dart'"
flutter test test/features/clock/now_card_test.dart test/features/clock/now_card_golden_test.dart
```

- [ ] **Step 3: Write the card**

**Create `lib/features/clock/widgets/now_card.dart`**

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
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The card under the dial. A running event fills it with the tone's colour;
/// otherwise it is neutral and says what is next, invites you to plan, or
/// summarises another day. Tapping opens the running or next event.
class NowCard extends ConsumerWidget {
  const NowCard({required this.onOpenEvent, this.compact = false, super.key});

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
                    color: view.foreground?.withValues(alpha: 0.85) ?? colors.muted,
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

    final card = AppCard(
      color: view.fill,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      onTap: view.event == null ? null : () => onOpenEvent(view.event!),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: compact ? 0 : height - 24),
        child: Align(alignment: Alignment.centerLeft, child: body),
      ),
    );

    if (view.semanticsLabel == null) return MergeSemantics(child: card);
    return Semantics(
      button: true,
      label: view.semanticsLabel,
      excludeSemantics: true,
      onTap: view.event == null ? null : () => onOpenEvent(view.event!),
      child: card,
    );
  }

  _NowView _describe(BuildContext context, NowStatus status, DateTime selected) {
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
          compactDetail: Strings.nowTimeLeft(formatDurationMinutes(minutesLeft)),
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

- [ ] **Step 4: Run the tests, then generate and check the goldens**

```bash
# expect: PASS
flutter test test/features/clock/now_card_test.dart && flutter analyze
```

```bash
# expect: UPDATE
flutter test --update-goldens test/features/clock/now_card_golden_test.dart
```

Open each `test/features/clock/goldens/now_card_*.png` and check: the running cards are filled with the tone colour (purple with white text; green with near-black text in dark mode), show the tone name, title, "1h 30m left · until 12:00" (or the Walk's time) and a thin progress bar; the overlap card says "Inbox · +1 overlapping" and is orange; the next and free cards are neutral; nothing is clipped.

```bash
# expect: PASS
flutter test test/features/clock/now_card_golden_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/clock/widgets/now_card.dart test/features/clock/now_card_test.dart test/features/clock/now_card_golden_test.dart test/features/clock/goldens
git commit -m "feat: tone-coloured Now card with running, next, free, done and summary states

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 20: Day-load bar

One rounded bar split into tone segments in proportion to planned minutes, with a legend ("Focus 4h", "Life 2h") and the total. Hidden when the day has no events.

**Files:**
- Create: `lib/features/clock/widgets/day_load_bar.dart`
- Test: `test/features/clock/day_load_bar_test.dart`

**Interfaces:**
- Produces: `DayLoadBar()` with `DayLoadBar.height` (68); segments are keyed `ValueKey('load-<tone name>')`.
- Consumes: `computeDayLoad`, `segmentWidths` (Task 16), `dayEventsProvider`, `AppCard`, `ToneColors`, `Strings`, `formatDurationMinutes`, `spokenDurationMinutes`.

- [ ] **Step 1: Write the failing test**

**Create `test/features/clock/day_load_bar_test.dart`**

```dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/widgets/day_load_bar.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
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

  Future<void> add(Tone tone, int start, int end) =>
      harness.repository.createEvent(
        day: DateTime(2026, 10, 7),
        title: 'Event',
        tone: tone,
        range: MinuteRange(start, end),
      );

  Future<void> show(WidgetTester tester, {double textScale = 1}) async {
    await tester.pumpWidget(
      harness.app(const DayLoadBar(), textScale: textScale),
    );
    await tester.pump();
  }

  testWidgets('is hidden when the day has no events', (tester) async {
    await show(tester);
    expect(find.byType(AppCard), findsNothing);
  });

  testWidgets('lists each tone with its time, and the total', (tester) async {
    await add(Tone.focus, 540, 660); // 2h
    await add(Tone.life, 720, 780); // 1h
    await add(Tone.focus, 900, 1020); // 2h
    await show(tester);

    expect(find.text('Focus 4h'), findsOneWidget);
    expect(find.text('Life 1h'), findsOneWidget);
    expect(find.text('Inbox 0m'), findsNothing);
    expect(find.textContaining('Inbox'), findsNothing);
    expect(find.text('5h planned'), findsOneWidget);
  });

  testWidgets('the segments are proportional to the planned time', (
    tester,
  ) async {
    await add(Tone.focus, 0, 240); // 4h
    await add(Tone.life, 300, 360); // 1h
    await show(tester);

    final focus = tester.getSize(find.byKey(const ValueKey('load-focus'))).width;
    final life = tester.getSize(find.byKey(const ValueKey('load-life'))).width;
    expect(focus / life, closeTo(4, 0.1));
    expect(find.byKey(const ValueKey('load-inbox')), findsNothing);
  });

  testWidgets('a tiny segment stays visible', (tester) async {
    await add(Tone.focus, 0, 720); // 12h
    await add(Tone.inbox, 800, 815); // 15m
    await show(tester);

    expect(
      tester.getSize(find.byKey(const ValueKey('load-inbox'))).width,
      greaterThanOrEqualTo(8),
    );
  });

  testWidgets('overlapping events count twice', (tester) async {
    await add(Tone.focus, 540, 600);
    await add(Tone.life, 540, 600);
    await show(tester);
    expect(find.text('2h planned'), findsOneWidget);
  });

  testWidgets('reads as one sentence for a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await add(Tone.focus, 540, 780); // 4h
    await add(Tone.life, 800, 860); // 1h
    await show(tester);

    expect(
      find.semantics.byLabel('Planned load: Focus 4 hours, Life 1 hour'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('does not overflow on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await add(Tone.focus, 0, 240);
    await add(Tone.life, 300, 360);
    await add(Tone.inbox, 400, 460);
    await show(tester);
    expect(tester.takeException(), isNull);
  });

  test('height budget', () {
    expect(DayLoadBar.height, 68);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
# expect: FAIL — "Target of URI doesn't exist: 'package:energy_clock/features/clock/widgets/day_load_bar.dart'"
flutter test test/features/clock/day_load_bar_test.dart
```

- [ ] **Step 3: Write the bar**

**Create `lib/features/clock/widgets/day_load_bar.dart`**

```dart
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:energy_clock/features/clock/model/day_load.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One rounded bar split into tone segments in proportion to the day's planned
/// minutes, with a legend and the total. Overlapping events count twice,
/// because overlap is extra load. Draws nothing when the day has no events.
class DayLoadBar extends ConsumerWidget {
  const DayLoadBar({super.key});

  /// Height at normal text size.
  static const double height = 68;

  static const double _gap = 2;
  static const double _barHeight = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events =
        ref.watch(dayEventsProvider).valueOrNull ?? const <CalendarEvent>[];
    final load = computeDayLoad(events);
    if (load.isEmpty) return const SizedBox.shrink();

    final toneColors = context.toneColors;
    final theme = Theme.of(context);
    final tones = load.tones;

    final spoken = [
      for (final tone in tones)
        '${tone.label} ${spokenDurationMinutes(load.minutesFor(tone))}',
    ];

    return Semantics(
      label: Strings.dayLoadSemantics(spoken.join(', ')),
      excludeSemantics: true,
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final widths = segmentWidths(
                  [for (final tone in Tone.values) load.minutesFor(tone)],
                  constraints.maxWidth - _gap * (tones.length - 1),
                );
                final children = <Widget>[];
                for (final tone in Tone.values) {
                  final width = widths[tone.index];
                  if (width <= 0) continue;
                  if (children.isNotEmpty) {
                    children.add(const SizedBox(width: _gap));
                  }
                  children.add(
                    SizedBox(
                      key: ValueKey('load-${tone.name}'),
                      width: width,
                      height: _barHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: toneColors.fillFor(tone),
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                      ),
                    ),
                  );
                }
                return Row(children: children);
              },
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: AppSpacing.md,
                    children: [
                      for (final tone in tones)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: toneColors.fillFor(tone),
                                shape: BoxShape.circle,
                              ),
                              child: const SizedBox.square(dimension: 8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${tone.label} '
                              '${formatDurationMinutes(load.minutesFor(tone))}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Text(
                  Strings.plannedDuration(
                    formatDurationMinutes(load.totalMinutes),
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

`tone.index` is the enum's declaration index (focus 0, life 1, inbox 2) which matches `Tone.values` order and the `segmentWidths` input order. ✔

- [ ] **Step 4: Run the test to verify it passes**

```bash
# expect: PASS
flutter test test/features/clock/day_load_bar_test.dart && flutter analyze
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/clock/widgets/day_load_bar.dart test/features/clock/day_load_bar_test.dart
git commit -m "feat: day-load bar showing how much of the day is each tone

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 21: The Clock screen

Composes the header, the week strip, the dial, the Now card and the day-load bar. The page never scrolls (a vertical scroll would compete with the dial's drag gestures), so a pure layout plan decides which optional pieces fit, dropping them in a fixed order. This task also removes the old `DayHeader` and its test, whose last user is the old screen.

**Files:**
- Create: `lib/features/clock/clock_layout.dart`
- Replace: `lib/features/clock/clock_screen.dart`, `test/features/clock/clock_screen_test.dart`
- Delete: `lib/features/clock/widgets/day_header.dart`, `test/features/clock/day_header_test.dart`
- Test: `test/features/clock/clock_layout_test.dart`

**Interfaces:**
- Produces: `ClockLayoutPlan` (`showDayLoad`, `compactNowCard`, `showHeaderDate`, `showWeekDots`, `dialHeight`) with `ClockLayoutPlan.forHeight(double available, {double textScale = 1, bool hasDayLoad = true})` and constants `gap` (8), `smallDial` (300), `tinyDial` (260), `minDial` (240), `largeTextScale` (1.3); `ClockScreen()`.
- Consumes: everything from Tasks 13–20; `TabBarInset`, `ContentWidth`, `windowClass`; `EventSheet`, `EventDetailSheet` (unchanged until Stage 4); `confirmAndDeleteEvent` (Task 13).

- [ ] **Step 1: Write the failing tests**

**Create `test/features/clock/clock_layout_test.dart`**

```dart
import 'package:energy_clock/features/clock/clock_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a tall phone shows everything', () {
    test('iPhone 17 Pro: 697 pt of content height', () {
      final plan = ClockLayoutPlan.forHeight(697);
      expect(plan.showDayLoad, isTrue);
      expect(plan.compactNowCard, isFalse);
      expect(plan.showHeaderDate, isTrue);
      expect(plan.showWeekDots, isTrue);
      // 697 - header 48 - strip 60 - three 8 pt gaps - Now card 96 - bar 68.
      expect(plan.dialHeight, closeTo(401, 1e-9));
    });
  });

  group('a short phone gives way in a fixed order', () {
    test('iPhone SE: the day-load bar goes first', () {
      final plan = ClockLayoutPlan.forHeight(563);
      expect(plan.showDayLoad, isFalse);
      expect(plan.compactNowCard, isFalse);
      expect(plan.showHeaderDate, isTrue);
      // 563 - 48 - 60 - two gaps - 96.
      expect(plan.dialHeight, closeTo(343, 1e-9));
    });

    test('shorter still: the Now card becomes one row', () {
      final plan = ClockLayoutPlan.forHeight(470);
      expect(plan.showDayLoad, isFalse);
      expect(plan.compactNowCard, isTrue);
      expect(plan.showHeaderDate, isTrue);
    });

    test('the card is one row exactly when the dial would be under 260', () {
      // Without the bar: height - 48 - 60 - two gaps - 96 = height - 220.
      expect(
        ClockLayoutPlan.forHeight(480, hasDayLoad: false).compactNowCard,
        isFalse,
      );
      expect(
        ClockLayoutPlan.forHeight(479, hasDayLoad: false).compactNowCard,
        isTrue,
      );
    });

    test('shorter again: the header loses its date line', () {
      final plan = ClockLayoutPlan.forHeight(400);
      expect(plan.showDayLoad, isFalse);
      expect(plan.compactNowCard, isTrue);
      expect(plan.showHeaderDate, isFalse);
    });

    test('a day with no events never reserves room for the bar', () {
      final plan = ClockLayoutPlan.forHeight(697, hasDayLoad: false);
      expect(plan.showDayLoad, isFalse);
      // 697 - 48 - 60 - two gaps - 96.
      expect(plan.dialHeight, closeTo(477, 1e-9));
    });

    test('the bar is dropped exactly when the dial would be under 300', () {
      // With the bar: height - 48 - 60 - 24 - 96 - 68 = height - 296.
      expect(ClockLayoutPlan.forHeight(596).showDayLoad, isTrue);
      expect(ClockLayoutPlan.forHeight(595).showDayLoad, isFalse);
    });
  });

  group('large text', () {
    test('above 130% the bar and the dots go and the card is one row', () {
      final plan = ClockLayoutPlan.forHeight(900, textScale: 1.5);
      expect(plan.showDayLoad, isFalse);
      expect(plan.showWeekDots, isFalse);
      expect(plan.compactNowCard, isTrue);
    });

    test('exactly 130% is still normal', () {
      final plan = ClockLayoutPlan.forHeight(900, textScale: 1.3);
      expect(plan.showWeekDots, isTrue);
    });

    test('at 200% on an iPhone SE the dial still has room', () {
      final plan = ClockLayoutPlan.forHeight(563, textScale: 2);
      expect(plan.dialHeight, greaterThanOrEqualTo(ClockLayoutPlan.minDial));
      expect(plan.showHeaderDate, isTrue);
    });

    test('a text scale beyond 200% is treated as 200%', () {
      final a = ClockLayoutPlan.forHeight(700, textScale: 2);
      final b = ClockLayoutPlan.forHeight(700, textScale: 3.1);
      expect(b.dialHeight, a.dialHeight);
    });
  });

  test('the thresholds', () {
    expect(ClockLayoutPlan.gap, 8);
    expect(ClockLayoutPlan.smallDial, 300);
    expect(ClockLayoutPlan.tinyDial, 260);
    expect(ClockLayoutPlan.minDial, 240);
    expect(ClockLayoutPlan.largeTextScale, 1.3);
  });
}
```

**Replace `test/features/clock/clock_screen_test.dart`**

```dart
import 'package:energy_clock/app/navigation/tab_bar_inset.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/clock_screen.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/clock_header.dart';
import 'package:energy_clock/features/clock/widgets/day_load_bar.dart';
import 'package:energy_clock/features/clock/widgets/dial_view.dart';
import 'package:energy_clock/features/clock/widgets/event_detail_sheet.dart';
import 'package:energy_clock/features/clock/widgets/now_card.dart';
import 'package:energy_clock/features/clock/widgets/week_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';
import '../../support/dial_pump.dart';

/// What the tab shell reserves for the floating bar on a phone with no home
/// indicator: 64 bar + 12 margin + 8 gap.
const double shellInset = 84;

Widget screen() => const TabBarInset(height: shellInset, child: ClockScreen());

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness(); // Wednesday 7 October 2026, 10:30
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> add(
    String title,
    Tone tone,
    int start,
    int end, {
    DateTime? day,
  }) => harness.repository.createEvent(
    day: day ?? DateTime(2026, 10, 7),
    title: title,
    tone: tone,
    range: MinuteRange(start, end),
  );

  void setWindow(WidgetTester tester, double width, double height) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('an empty day shows the invitation', (tester) async {
    setWindow(tester, 402, 874);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);
    expect(find.text(Strings.emptyDayTitle), findsOneWidget);
  });

  testWidgets('a day with events hides the invitation', (tester) async {
    setWindow(tester, 402, 874);
    await add('Deep work', Tone.focus, 540, 720);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);
    expect(find.text(Strings.emptyDayTitle), findsNothing);
  });

  testWidgets('a tall phone shows every piece', (tester) async {
    setWindow(tester, 402, 874);
    await add('Deep work', Tone.focus, 540, 720);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);

    expect(find.byType(ClockHeader), findsOneWidget);
    expect(find.byType(WeekStrip), findsOneWidget);
    expect(find.byType(DialView), findsOneWidget);
    expect(find.byType(NowCard), findsOneWidget);
    expect(find.byType(DayLoadBar), findsOneWidget);
  });

  testWidgets('on a short phone the day-load bar is dropped', (tester) async {
    setWindow(tester, 375, 667);
    await add('Deep work', Tone.focus, 540, 720);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);

    expect(find.byType(NowCard), findsOneWidget);
    expect(find.byType(DayLoadBar), findsNothing);
  });

  testWidgets('the + button opens the new-event sheet', (tester) async {
    setWindow(tester, 402, 874);
    // Reduced motion: on an empty day the dial's hint arc pulses forever, and
    // pumpAndSettle below would never return.
    await tester.pumpWidget(harness.app(screen(), reduceMotion: true));
    await pumpDial(tester);

    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == Strings.addEvent,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(Strings.newEvent), findsOneWidget);
  });

  testWidgets('tapping the Now card opens the running event', (tester) async {
    setWindow(tester, 402, 874);
    await add('Deep work', Tone.focus, 540, 720);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);

    await tester.tap(find.byType(NowCard));
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailSheet), findsOneWidget);
  });

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

  testWidgets('changing day through the strip updates the Now card', (
    tester,
  ) async {
    setWindow(tester, 402, 874);
    await add('Thursday plan', Tone.life, 540, 600, day: DateTime(2026, 10, 8));
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);
    expect(find.text('Thursday · 1 event'), findsNothing);

    await tester.tap(find.text('8'));
    await pumpDial(tester);
    expect(find.text('Thursday · 1 event'), findsOneWidget);
  });

  testWidgets('a medium window is a centred column', (tester) async {
    setWindow(tester, 834, 1194);
    await add('Deep work', Tone.focus, 540, 720);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);

    final width = tester.getSize(find.byType(NowCard)).width;
    expect(width, lessThanOrEqualTo(560));
    expect(tester.getCenter(find.byType(NowCard)).dx, closeTo(417, 1));
  });

  group('layout matrix, narrow and medium windows', () {
    const sizes = {
      'iPhone SE': Size(375, 667),
      'iPhone 17 Pro': Size(402, 874),
      'iPad mini portrait': Size(744, 1133),
      'iPad 11" portrait': Size(834, 1194),
      'narrow Split View': Size(320, 1000),
    };

    for (final entry in sizes.entries) {
      for (final textScale in const [1.0, 1.3, 2.0]) {
        for (final withEvents in const [false, true]) {
          testWidgets(
            '${entry.key}, text ${textScale * 100}%, '
            '${withEvents ? 'with' : 'without'} events',
            (tester) async {
              setWindow(tester, entry.value.width, entry.value.height);
              if (withEvents) {
                await add('Deep work', Tone.focus, 540, 720);
                await add('Walk', Tone.life, 600, 660);
                await add('A call with a long title', Tone.inbox, 610, 630);
              }
              await tester.pumpWidget(harness.app(screen(), textScale: textScale));
              await pumpDial(tester);

              expect(tester.takeException(), isNull);
              final dial = tester.getSize(find.byType(DialView));
              expect(
                dial.shortestSide,
                greaterThanOrEqualTo(240),
                reason: 'the dial area is ${dial.width} x ${dial.height}',
              );
            },
          );
        }
      }
    }
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL — 'package:energy_clock/features/clock/clock_layout.dart' does not exist and the old screen has no header or strip
flutter test test/features/clock/clock_layout_test.dart test/features/clock/clock_screen_test.dart
```

- [ ] **Step 3: Write the layout plan and the screen**

**Create `lib/features/clock/clock_layout.dart`**

```dart
import 'package:energy_clock/features/clock/widgets/clock_header.dart';
import 'package:energy_clock/features/clock/widgets/day_load_bar.dart';
import 'package:energy_clock/features/clock/widgets/now_card.dart';
import 'package:energy_clock/features/clock/widgets/week_strip.dart';

/// Which optional pieces of the Clock screen fit, decided from the height left
/// for them and the text size.
///
/// The page never scrolls (a vertical scroll would compete with the dial's drag
/// gestures), so instead it gives way in a fixed order:
///
/// 1. At text sizes above 130%: no day-load bar, no week dots, one-row Now card.
/// 2. Otherwise, if the dial would be under 300 pt: drop the day-load bar.
/// 3. If it would still be under 260 pt: make the Now card one row.
/// 4. If it would still be under 240 pt: drop the header's date line.
class ClockLayoutPlan {
  const ClockLayoutPlan({
    required this.showDayLoad,
    required this.compactNowCard,
    required this.showHeaderDate,
    required this.showWeekDots,
    required this.dialHeight,
  });

  final bool showDayLoad;
  final bool compactNowCard;
  final bool showHeaderDate;
  final bool showWeekDots;

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
  /// and so reserves no room.
  static ClockLayoutPlan forHeight(
    double available, {
    double textScale = 1,
    bool hasDayLoad = true,
  }) {
    final scale = textScale.clamp(1.0, 2.0);
    final largeText = scale > largeTextScale;

    double dialFor({
      required bool dayLoad,
      required bool compact,
      required bool date,
    }) {
      final header = ClockHeader.heightFor(scale, showDate: date);
      final strip = WeekStrip.heightFor(scale);
      final now = compact
          ? NowCard.compactHeightFor(scale)
          : NowCard.heightFor(scale);
      final bar = dayLoad ? gap + DayLoadBar.height : 0;
      // A gap under the strip and another above the Now card.
      return available - header - strip - gap - gap - now - bar;
    }

    var dayLoad = hasDayLoad && !largeText;
    var compact = largeText;
    var date = true;
    var dial = dialFor(dayLoad: dayLoad, compact: compact, date: date);

    if (dayLoad && dial < smallDial) {
      dayLoad = false;
      dial = dialFor(dayLoad: dayLoad, compact: compact, date: date);
    }
    if (!compact && dial < tinyDial) {
      compact = true;
      dial = dialFor(dayLoad: dayLoad, compact: compact, date: date);
    }
    if (date && dial < minDial) {
      date = false;
      dial = dialFor(dayLoad: dayLoad, compact: compact, date: date);
    }

    return ClockLayoutPlan(
      showDayLoad: dayLoad,
      compactNowCard: compact,
      showHeaderDate: date,
      showWeekDots: !largeText,
      dialHeight: dial,
    );
  }
}
```

**Replace `lib/features/clock/clock_screen.dart`**

```dart
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
import 'package:energy_clock/features/clock/widgets/week_strip.dart';
import 'package:energy_clock/shared/layout/content_width.dart';
import 'package:energy_clock/shared/layout/window_class.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Clock tab: header, week strip, the dial, the Now card, and the day-load
/// bar, stacked in one non-scrolling column. A medium window centres the
/// column at 560 pt. (Plan 1B adds the wide two-pane layout.)
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

    void openCreate(MinuteRange range) =>
        EventSheet.show(context, day: selected, initialRange: range);

    void openDetail(CalendarEvent event) =>
        EventDetailSheet.show(context, event: event, readOnly: readOnly);

    void openEdit(CalendarEvent event) => EventSheet.show(
      context,
      day: event.date,
      initialRange: event.range,
      existing: event,
    );

    return ContentWidth(
      maxWidth: windowClass == WindowClass.narrow
          ? double.infinity
          : ContentWidths.column,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hasEvents = events.valueOrNull?.isNotEmpty ?? false;
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
                Expanded(
                  child: events.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) =>
                        const Center(child: Text(Strings.loadFailed)),
                    data: (dayEvents) => DialView(
                      events: dayEvents,
                      day: selected,
                      readOnly: readOnly,
                      onCreateRequested: openCreate,
                      onEventTapped: openDetail,
                      onEditRequested: openEdit,
                      onDeleteRequested: (event) =>
                          confirmAndDeleteEvent(context, ref, event),
                      onMoveRequested: (event, range) async {
                        try {
                          await ref
                              .read(eventRepositoryProvider)
                              .moveEvent(
                                id: event.id,
                                day: selected,
                                range: range,
                              );
                        } on RingOverflowException {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(Strings.ringOverflow),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: ClockLayoutPlan.gap),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: NowCard(
                    compact: plan.compactNowCard,
                    onOpenEvent: openDetail,
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

**Delete `lib/features/clock/widgets/day_header.dart`**

**Delete `test/features/clock/day_header_test.dart`**

- [ ] **Step 4: Run the tests to verify they pass**

```bash
# expect: PASS
flutter test test/features/clock/clock_layout_test.dart test/features/clock/clock_screen_test.dart
```

If a matrix case reports an overflow or a dial under 240 pt, fix it by tightening the layout (for example, a smaller padding or hiding the header date earlier), keep the rules in `ClockLayoutPlan`'s doc comment true, and add a `clock_layout_test.dart` case for the new rule.

- [ ] **Step 5: Run the whole suite and the analyzer — this is the end of Stage 3**

```bash
# expect: PASS
flutter analyze && flutter test
```

- [ ] **Step 6: Commit**

```bash
git add -A lib/features/clock test/features/clock
git commit -m "feat: Clock screen with header, week strip, Now card, day-load bar and layout rules

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Stage 4 — Event sheets

### Task 22: New and Edit sheet

The same fields and rules as today, restyled: a filled title field, three big tone tiles (a selected tile gets a 3 pt ink outline and a check), Start and End rows with round 44 pt stepper buttons and the time in large type, a duration chip, and a full-width Save button. The sheet scrolls, so large text or the keyboard can never overflow it, and it asks for the drag handle itself.

The existing `event_sheet_test.dart` must keep passing unchanged. It finds the tone tiles by their visible text, taps `IconButton`s by tooltip, and reads the `TextField`, so the new tiles keep their visible labels and the steppers stay `IconButton`s with the same tooltips.

**Files:**
- Replace: `lib/features/clock/widgets/event_sheet.dart`
- Test: `test/features/clock/event_sheet_style_test.dart` (the existing `event_sheet_test.dart` is unchanged)

**Interfaces:**
- Produces: `EventSheet.show(BuildContext, {required DateTime day, required MinuteRange initialRange, CalendarEvent? existing})` — unchanged signature; the sheet now sets `showDragHandle: true`.
- Consumes: `AppButton`, `PressScale`, `AppColors`, `ToneColors`, `AppSpacing`, `AppRadii`, `Strings`, `formatMinuteOfDay`, `formatDurationMinutes`; the repository and `RingOverflowException` as before.

- [ ] **Step 1: Write the failing test**

**Create `test/features/clock/event_sheet_style_test.dart`**

```dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/event_sheet.dart';
import 'package:energy_clock/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_event_repository.dart';

void main() {
  late FakeEventRepository repository;
  final day = DateTime(2026, 8, 23);

  setUp(() {
    repository = FakeEventRepository();
  });

  tearDown(() {
    repository.dispose();
  });

  Future<void> openSheet(
    WidgetTester tester, {
    MinuteRange range = const MinuteRange(540, 720),
    double textScale = 1,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [eventRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () =>
                    EventSheet.show(context, day: day, initialRange: range),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('has a drag handle and is capped at 560 pt wide', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openSheet(tester);
    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.showDragHandle, isTrue);
    // The BottomSheet widget fills the width; the surface inside it is capped.
    final surface = find
        .descendant(of: find.byType(BottomSheet), matching: find.byType(Material))
        .first;
    expect(tester.getSize(surface).width, 560);
  });

  testWidgets('shows the start and end times and the duration', (tester) async {
    await openSheet(tester);
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
    expect(find.text('3h'), findsOneWidget);
  });

  testWidgets('the tone tiles are at least 72 pt tall, in their tone colours', (
    tester,
  ) async {
    await openSheet(tester);
    for (final tone in Tone.values) {
      final tile = find.ancestor(
        of: find.text(tone.label),
        matching: find.byWidgetPredicate(
          (w) => w is DecoratedBox && w.decoration is BoxDecoration,
        ),
      );
      expect(tester.getSize(tile.first).height, greaterThanOrEqualTo(72));
      final decoration =
          tester.widget<DecoratedBox>(tile.first).decoration as BoxDecoration;
      expect(decoration.color, ToneColors.light.fillFor(tone));
    }
  });

  testWidgets('the selected tone has an ink outline and a check', (
    tester,
  ) async {
    await openSheet(tester);
    BoxDecoration decorationFor(Tone tone) {
      final tile = find.ancestor(
        of: find.text(tone.label),
        matching: find.byWidgetPredicate(
          (w) => w is DecoratedBox && w.decoration is BoxDecoration,
        ),
      );
      return tester.widget<DecoratedBox>(tile.first).decoration as BoxDecoration;
    }

    // Focus is selected by default.
    expect(decorationFor(Tone.focus).border!.top.color, AppColors.light.ink);
    expect(decorationFor(Tone.focus).border!.top.width, 3);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.tap(find.text(Tone.life.label));
    await tester.pump();
    expect(decorationFor(Tone.life).border!.top.color, AppColors.light.ink);
    expect(decorationFor(Tone.focus).border!.top.color, isNot(AppColors.light.ink));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('tone tiles read as selectable buttons', (tester) async {
    final handle = tester.ensureSemantics();
    await openSheet(tester);

    expect(
      tester.getSemantics(find.bySemanticsLabel(Tone.focus.label)),
      matchesSemantics(
        label: Tone.focus.label,
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel(Tone.life.label)),
      matchesSemantics(
        label: Tone.life.label,
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('the stepper buttons are at least 44 x 44', (tester) async {
    await openSheet(tester);
    for (final label in [Strings.startLabel, Strings.endLabel]) {
      for (final tooltip in [
        Strings.stepperDecrease(label),
        Strings.stepperIncrease(label),
      ]) {
        final button = find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == tooltip,
        );
        final size = tester.getSize(button);
        expect(size.width, greaterThanOrEqualTo(44), reason: tooltip);
        expect(size.height, greaterThanOrEqualTo(44), reason: tooltip);
      }
    }
  });

  testWidgets('a stepper moves the time by five minutes', (tester) async {
    await openSheet(tester);
    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is IconButton &&
            w.tooltip == Strings.stepperIncrease(Strings.startLabel),
      ),
    );
    await tester.pump();
    expect(find.text('09:05'), findsOneWidget);
    expect(find.text('2h 55m'), findsOneWidget);
  });

  testWidgets('Save is a full-width primary button', (tester) async {
    await openSheet(tester);
    final button = find.widgetWithText(AppButton, Strings.save);
    expect(button, findsOneWidget);
    expect(tester.widget<AppButton>(button).variant, AppButtonVariant.primary);
  });

  testWidgets('edit mode is titled and prefilled', (tester) async {
    await repository.createEvent(
      day: day,
      title: 'Deep work',
      tone: Tone.inbox,
      range: const MinuteRange(540, 720),
    );
    final existing = (await repository.eventsForDay(day)).single;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [eventRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => EventSheet.show(
                  context,
                  day: day,
                  initialRange: existing.range,
                  existing: existing,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(Strings.editEvent), findsOneWidget);
    // Not find.text: the field's hint is also 'Deep work' and stays in the tree.
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'Deep work',
    );
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('scrolls instead of overflowing on a short window at double '
      'text size', (tester) async {
    tester.view.physicalSize = const Size(375, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openSheet(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });

  testWidgets('works in dark mode', (tester) async {
    await openSheet(tester, theme: AppTheme.dark);
    expect(tester.takeException(), isNull);
    expect(find.text(Strings.save), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the new test to verify it fails**

```bash
# expect: FAIL — the old sheet has no drag handle, 3 pt outline, check icon, or time in large type
flutter test test/features/clock/event_sheet_style_test.dart
```

- [ ] **Step 3: Restyle the sheet**

**Replace `lib/features/clock/widgets/event_sheet.dart`**

```dart
import 'dart:async';

import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/shared/widgets/app_button.dart';
import 'package:energy_clock/shared/widgets/press_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EventSheet extends ConsumerStatefulWidget {
  const EventSheet({
    required this.day,
    required this.initialRange,
    this.existing,
    super.key,
  });

  final DateTime day;
  final MinuteRange initialRange;

  /// Non-null puts the sheet in edit mode.
  final CalendarEvent? existing;

  static Future<void> show(
    BuildContext context, {
    required DateTime day,
    required MinuteRange initialRange,
    CalendarEvent? existing,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          EventSheet(day: day, initialRange: initialRange, existing: existing),
    );
  }

  @override
  ConsumerState<EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends ConsumerState<EventSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late Tone _tone = widget.existing?.tone ?? Tone.focus;
  late MinuteRange _range = widget.initialRange;

  String? _titleError;
  String? _saveError;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _nudgeStart(int delta) {
    final start = snapMinute(
      _range.start + delta,
    ).clamp(0, _range.end - minEventMinutes);
    setState(() => _range = MinuteRange(start, _range.end));
  }

  void _nudgeEnd(int delta) {
    final end = snapMinute(
      _range.end + delta,
    ).clamp(_range.start + minEventMinutes, minutesPerDay);
    setState(() => _range = MinuteRange(_range.start, end));
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = Strings.titleRequired);
      return;
    }
    setState(() {
      _titleError = null;
      _saveError = null;
    });

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xs,
        AppSpacing.xl,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? Strings.newEvent : Strings.editEvent,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            style: theme.textTheme.titleMedium,
            decoration: InputDecoration(
              filled: true,
              fillColor: colors.page,
              labelText: Strings.titleLabel,
              hintText: Strings.titleHint,
              errorText: _titleError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.control),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(Strings.toneLabel, style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (final tone in Tone.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _ToneTile(
                      tone: tone,
                      selected: tone == _tone,
                      onTap: () => setState(() => _tone = tone),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _TimeRow(
            label: Strings.startLabel,
            minute: _range.start,
            onDecrease: () => _nudgeStart(-snapStepMinutes),
            onIncrease: () => _nudgeStart(snapStepMinutes),
          ),
          const SizedBox(height: AppSpacing.sm),
          _TimeRow(
            label: Strings.endLabel,
            minute: _range.end,
            onDecrease: () => _nudgeEnd(-snapStepMinutes),
            onIncrease: () => _nudgeEnd(snapStepMinutes),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.page,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 6,
                ),
                child: Text(
                  formatDurationMinutes(_range.durationMinutes),
                  style: theme.textTheme.labelLarge,
                ),
              ),
            ),
          ),
          if (_saveError != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _saveError!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.danger,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton(label: Strings.save, onPressed: _save),
        ],
      ),
    );
  }
}

/// One of the three tone choices: the tone's colour, its name, and, when
/// selected, a 3 pt ink outline and a check.
class _ToneTile extends StatelessWidget {
  const _ToneTile({
    required this.tone,
    required this.selected,
    required this.onTap,
  });

  final Tone tone;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.toneColors.paletteFor(tone);
    final colors = context.appColors;

    return Semantics(
      button: true,
      selected: selected,
      label: tone.label,
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        onTap: () {
          if (!selected) unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.solid,
            borderRadius: BorderRadius.circular(AppRadii.control),
            border: Border.all(
              color: selected ? colors.ink : AppColors.transparent,
              width: 3,
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tone.label,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall!.copyWith(color: palette.onSolid),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: palette.onSolid,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A label, the time in large type, and round minus and plus buttons.
class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.minute,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String label;
  final int minute;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
        _StepperButton(
          icon: Icons.remove,
          tooltip: Strings.stepperDecrease(label),
          onPressed: onDecrease,
        ),
        SizedBox(
          width: 96,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatMinuteOfDay(minute),
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall,
            ),
          ),
        ),
        _StepperButton(
          icon: Icons.add,
          tooltip: Strings.stepperIncrease(label),
          onPressed: onIncrease,
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
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
      icon: Icon(icon),
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

- [ ] **Step 4: Run the new tests and the existing sheet tests**

```bash
# expect: PASS
flutter test test/features/clock/event_sheet_style_test.dart test/features/clock/event_sheet_test.dart
```

- [ ] **Step 5: Run the whole suite and the analyzer**

```bash
# expect: PASS
flutter analyze && flutter test
```

- [ ] **Step 6: Commit**

```bash
git add lib/features/clock/widgets/event_sheet.dart test/features/clock/event_sheet_style_test.dart
git commit -m "feat: restyle the new and edit event sheet

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 23: Event detail sheet

The detail sheet gets a tone chip, a large title, the time range and duration, a secondary Edit button and a destructive Delete button. Delete uses the shared confirm-and-delete helper, which shows the native alert on iOS. The sheet scrolls and asks for the drag handle. Step 2 will add **Start session** above Edit.

The existing `event_detail_sheet_test.dart` must keep passing unchanged: it finds the tone by its visible text, taps the Delete button by text and then the dialog's `TextButton`, and expects the editor to open prefilled.

**Files:**
- Replace: `lib/features/clock/widgets/event_detail_sheet.dart`
- Test: `test/features/clock/event_detail_sheet_style_test.dart` (the existing `event_detail_sheet_test.dart` is unchanged)

**Interfaces:**
- Produces: `EventDetailSheet.show(BuildContext, {required CalendarEvent event, required bool readOnly})` — unchanged signature.
- Consumes: `ToneChip`, `AppButton`, `confirmAndDeleteEvent` (Task 13), `EventSheet.show` (Task 22), `Strings`, `formatMinuteRange`, `formatDurationMinutes`.

- [ ] **Step 1: Write the failing test**

**Create `test/features/clock/event_detail_sheet_style_test.dart`**

```dart
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/event_detail_sheet.dart';
import 'package:energy_clock/shared/widgets/app_button.dart';
import 'package:energy_clock/shared/widgets/tone_chip.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_event_repository.dart';

void main() {
  late FakeEventRepository repository;
  final day = DateTime(2026, 8, 23);

  setUp(() {
    repository = FakeEventRepository();
  });

  tearDown(() {
    repository.dispose();
  });

  Future<CalendarEvent> seed() async {
    await repository.createEvent(
      day: day,
      title: 'Deep work',
      tone: Tone.focus,
      range: const MinuteRange(540, 720),
    );
    return (await repository.eventsForDay(day)).single;
  }

  Future<void> openSheet(
    WidgetTester tester,
    CalendarEvent event, {
    bool readOnly = false,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [eventRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => EventDetailSheet.show(
                  context,
                  event: event,
                  readOnly: readOnly,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows a tone chip, the title, the range and the duration', (
    tester,
  ) async {
    await openSheet(tester, await seed());

    expect(find.byType(ToneChip), findsOneWidget);
    expect(find.text('Deep work'), findsOneWidget);
    expect(find.text('09:00 – 12:00'), findsOneWidget);
    expect(find.text('3h'), findsOneWidget);
  });

  testWidgets('has a drag handle and is capped at 560 pt wide', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openSheet(tester, await seed());
    expect(
      tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle,
      isTrue,
    );
    // The BottomSheet widget fills the width; the surface inside it is capped.
    final surface = find
        .descendant(of: find.byType(BottomSheet), matching: find.byType(Material))
        .first;
    expect(tester.getSize(surface).width, 560);
  });

  testWidgets('Edit is a secondary button and Delete is destructive', (
    tester,
  ) async {
    await openSheet(tester, await seed());

    expect(
      tester
          .widget<AppButton>(find.widgetWithText(AppButton, Strings.edit))
          .variant,
      AppButtonVariant.secondary,
    );
    expect(
      tester
          .widget<AppButton>(find.widgetWithText(AppButton, Strings.delete))
          .variant,
      AppButtonVariant.destructive,
    );
  });

  testWidgets('a read-only day shows the details but no buttons', (
    tester,
  ) async {
    await openSheet(tester, await seed(), readOnly: true);
    expect(find.text('Deep work'), findsOneWidget);
    expect(find.byType(AppButton), findsNothing);
  });

  testWidgets('deleting closes the sheet and removes the event', (
    tester,
  ) async {
    await openSheet(tester, await seed());

    await tester.tap(find.text(Strings.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, Strings.delete));
    await tester.pumpAndSettle();

    expect(await repository.eventsForDay(day), isEmpty);
    expect(find.byType(EventDetailSheet), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('on iOS the delete confirmation is the native alert', (
    tester,
  ) async {
    await openSheet(tester, await seed());

    await tester.tap(find.text(Strings.delete));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.widgetWithText(CupertinoDialogAction, Strings.delete));
    await tester.pumpAndSettle();
    expect(await repository.eventsForDay(day), isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Edit closes the sheet and opens the editor for the same event', (
    tester,
  ) async {
    await openSheet(tester, await seed());

    await tester.tap(find.text(Strings.edit));
    await tester.pumpAndSettle();

    expect(find.byType(EventDetailSheet), findsNothing);
    expect(find.text(Strings.editEvent), findsOneWidget);
    // Not find.text: the field's hint is also 'Deep work' and stays in the tree.
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'Deep work',
    );
  });

  testWidgets('scrolls instead of overflowing on a short window at double '
      'text size', (tester) async {
    tester.view.physicalSize = const Size(375, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openSheet(tester, await seed(), textScale: 2);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run the new test to verify it fails**

```bash
# expect: FAIL — the old sheet has no ToneChip, AppButtons, or drag handle
flutter test test/features/clock/event_detail_sheet_style_test.dart
```

- [ ] **Step 3: Restyle the sheet**

**Replace `lib/features/clock/widgets/event_detail_sheet.dart`**

```dart
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:energy_clock/features/clock/widgets/delete_event.dart';
import 'package:energy_clock/features/clock/widgets/event_sheet.dart';
import 'package:energy_clock/shared/widgets/app_button.dart';
import 'package:energy_clock/shared/widgets/tone_chip.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

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
          if (!readOnly) ...[
            const SizedBox(height: AppSpacing.xxl),
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

- [ ] **Step 4: Run the new tests and the existing detail-sheet tests**

```bash
# expect: PASS
flutter test test/features/clock/event_detail_sheet_style_test.dart test/features/clock/event_detail_sheet_test.dart
```

- [ ] **Step 5: Run the whole suite and the analyzer — this is the end of Plan 1A**

```bash
# expect: PASS
flutter analyze && flutter test
```

- [ ] **Step 6: Manual check on the simulator**

Run the app (`flutter run -d "iPhone 17 Pro"`), and confirm by eye, in light and dark mode:

- the Clock tab shows the header, week strip, a big dial, the Now card and the day-load bar, with the floating tab bar underneath;
- dragging on the ring still creates, moves and resizes events; the face grows and shrinks smoothly as overlaps appear and disappear;
- the New, Edit and Detail sheets open with a drag handle and scroll with the keyboard up;
- the Calendar, Stats and Profile tabs still say "coming soon" (they are replaced in later steps).

Take screenshots with the simulator tool and keep them for the Plan 1B screenshot review.

- [ ] **Step 7: Commit**

```bash
git add lib/features/clock/widgets/event_detail_sheet.dart test/features/clock/event_detail_sheet_style_test.dart
git commit -m "feat: restyle the event detail sheet

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## End of Plan 1A

When every task above is done and green, the app has the new look on iPhone and on medium-width windows. **Do not submit this build:** Calendar, Stats and Profile are still placeholders. Continue with `docs/superpowers/plans/2026-10-04-step-1b-ipad-brand-onboarding.md`.
