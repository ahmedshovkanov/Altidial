# Energy Clock — Step 1B: iPad, Brand and Onboarding — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Clock tab a proper iPad screen (a two-pane layout with a Today's plan list on wide windows, and all four iPad orientations), give the app a real icon and launch screen, add a three-screen onboarding with an optional sample day, and finish with the full verification pass.

**Architecture:** The wide layout reuses every widget from Plan 1A and only recomposes them: the dial in a left pane, the header, week strip, Now card, day-load bar and a new Today's plan list in a right pane. Window class (narrow, medium, wide) comes from the window width, so Split View and resizable windows work. The first reader of the existing `settings` table stores the "onboarding seen" flag. The app icon and launch logo are generated in code from the same `RingMark` painter as the Clock tab icon, then resized into the asset catalog.

**Tech Stack:** Flutter 3.44.7, Dart 3.12.2, `flutter_riverpod` 2.6, `drift` + `drift_flutter` (+ `drift_dev`, `build_runner` for one new DAO), `intl`. macOS `sips` for icon resizing. No new packages.

**Spec:** `docs/superpowers/specs/2026-10-03-step-1-foundation-design.md`. This plan implements §5 (wide windows), §8.8, §10, the settings part of §11, and §§13–15 for the pieces it adds. **It must run after Plan 1A** (`docs/superpowers/plans/2026-10-04-step-1a-foundation-dial-clock.md`), which creates the design foundation, the dial, the Clock screen and the sheets this plan builds on.

## Global Constraints

These apply to every task. Copied from the spec and the Phase 1 plan.

- **Platform:** iOS 15+. iPhone in portrait; iPad in all four orientations with resizable windows. Flutter 3.44.7 / Dart 3.12.2.
- **Language:** English-only. All user-facing copy lives in `lib/core/strings.dart`. No localisation framework.
- **Tones are fixed:** exactly three — Focus (purple), Life (green), Inbox (orange). Not addable, removable, renameable, or recolourable.
- **Colour only ever encodes a tone.** UI accent (buttons, selected tab) is near-black in light mode and near-white in dark mode, never purple.
- **No hard-coded colours in feature code.** Nothing under `lib/features/` may contain `Color(0x` or `Colors.`. Every colour comes from `context.appColors`, `context.toneColors`, `AppColors.transparent`, or `Theme.of(context).colorScheme`. Enforced by `test/architecture/no_hardcoded_colors_test.dart`.
- **Boundary rule:** no file under `lib/features/<a>/` may import from `lib/features/<b>/`. `lib/app/` composes features and may import them. Cross-feature communication goes through repositories exposed as Riverpod providers.
- **Minute domain:** `startMinute` is 0–1439, `endMinute` is 1–1440 and exclusive, and never exceeds 1440. Cross-midnight events are not allowed.
- **Drag rules:** snap to 5-minute increments; minimum event duration 15 minutes; a drag past the end of day clamps at `endMinute` 1440.
- **Overlaps:** allowed, up to 3 rings. A fourth simultaneous event is refused with "Up to three overlapping events." Ring assignment is computed at render time, never stored.
- **Editability:** past days are read-only. Today and future days are editable.
- **Window classes:** narrow under 600 pt, medium 600–899 pt, wide 900 pt and up. Layout follows the app window width, not the device name.
- **Tap targets** are at least 44 pt. **Contrast:** text pairs at least 4.5:1, arcs against the face at least 3:1.
- **No new runtime packages.** No charting library, HTTP client, or analytics SDK.
- **Schema:** no schema change, so no migration. The new DAO only reads and writes the existing `settings` table.
- **Tooling:** run Dart commands, including `build_runner`, with the Flutter SDK's `dart` (`"$(dirname "$(which flutter)")/dart"`). The first `dart` on this machine's PATH is 3.10 and fails on this project.
- **Style:** `flutter analyze` must stay clean; the repo follows `dart format` and the lints in `analysis_options.yaml` (single quotes, `unawaited_futures`, `prefer_final_locals`, `always_declare_return_types`).
- **Commit messages** use the repo's conventional prefixes (`feat:`, `fix:`, `test:`, `refactor:`, `docs:`, `chore:`) and end with a blank line and the trailer `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## How to read the steps

- **Create / Replace / Edit / Delete** blocks give the exact file change. A **Replace** block is the whole new file. An **Edit** block shows the exact text to find (`Replace:`) and what to put there (`With:`); the find text appears exactly once.
- A bash block whose first line is `# expect: PASS` must succeed; `# expect: FAIL` must fail for the stated reason; `# expect: RUN` and `# expect: UPDATE` are setup commands that must succeed; `# expect: MANUAL` is done by a person or the controller.
- If a snippet does not compile against Flutter 3.44.7, fix the API usage minimally, keep the behaviour and the tests' intent, and say so in your report.

## What Plan 1A leaves for this plan

- `ClockScreen` lays every window out as one column (a medium window centres it at 560 pt). A wide window does the same until Task 24.
- `DialView` already takes a `maxRadius` and honours a window of any size.
- The `settings` table exists but nothing reads it.
- The Flutter template's app icon and white launch screen are still in place.

## File Structure

**Created:**

| File | Responsibility |
|---|---|
| `lib/features/clock/widgets/todays_plan_list.dart` | The day's events as a list, wide windows only |
| `lib/data/daos/settings_dao.dart` | Reads and writes the `settings` table |
| `lib/data/repositories/settings_repository.dart` | `SettingsRepository`: typed bool settings over the DAO |
| `lib/app/onboarding/sample_day.dart` | The four sample events and `createSampleDay` |
| `lib/app/onboarding/onboarding_providers.dart` | `onboardingDoneProvider` |
| `lib/app/onboarding/onboarding_flow.dart` | The three-screen first-run flow |
| `tool/brand/generate_brand_assets.dart` | Renders the icon master and the launch logo from `RingMark` |
| `tool/brand/make_icons.py` | Resizes the master into every icon size and strips alpha |
| `ios/Runner/Assets.xcassets/LaunchBackground.colorset/Contents.json` | Light and dark launch background |
| `test/support/fake_settings_repository.dart` | In-memory settings for tests |

**Modified:** `lib/features/clock/clock_screen.dart`, `lib/core/strings.dart`, `lib/data/database.dart` (+ regenerated `.g.dart`), `lib/data/providers.dart`, `lib/app/app.dart`, `ios/Runner/Info.plist`, `ios/Runner/Base.lproj/LaunchScreen.storyboard`, the generated app-icon and launch-image PNGs, `pubspec.yaml`, `README.md`.

---

## Stage 5 — iPad

### Task 24: Today's plan list and the wide Clock layout

On a wide window (900 pt and up: iPad 13" in portrait, any iPad in full-screen landscape) the Clock tab becomes two panes. The dial fills the left pane, capped at a 340 pt radius so the arcs never become huge. The right pane, between 340 and 440 pt wide, stacks the header, week strip, Now card, day-load bar, and a new **Today's plan** list. The list shows each event as a row (tone bar, title, time range and duration); the running event's row is tinted; a tap opens the details. It exists because the room is there, and because a list is also easy for VoiceOver to read.

**Files:**
- Create: `lib/features/clock/widgets/todays_plan_list.dart`
- Replace: `lib/features/clock/clock_screen.dart`
- Test: `test/features/clock/todays_plan_list_test.dart`, `test/features/clock/clock_screen_wide_test.dart`

**Interfaces:**
- Produces: `TodaysPlanList({required void Function(CalendarEvent) onOpenEvent})`, rows keyed `ValueKey('plan-<event id>')`; the list draws nothing when the day has no events.
- Consumes: `dayEventsProvider`, `selectedDateProvider`, `clockProvider`, `activeEventsAt`, `AppCard`, `SectionHeader`, `ToneColors`, `Strings.planTitleToday`, `Strings.planTitleFor`, `Strings.eventSemantics`, `windowClass`, `ClockLayoutPlan`, and every Clock widget from Plan 1A.

- [ ] **Step 1: Write the failing tests**

**Create `test/features/clock/todays_plan_list_test.dart`**

```dart
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:energy_clock/features/clock/widgets/todays_plan_list.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;
  CalendarEvent? opened;

  setUp(() {
    harness = ClockHarness(); // Wednesday 7 October 2026, 10:30
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

  Future<void> show(WidgetTester tester, {double height = 600}) async {
    await tester.pumpWidget(
      harness.app(
        SizedBox(
          width: 400,
          height: height,
          child: TodaysPlanList(onOpenEvent: (e) => opened = e),
        ),
      ),
    );
    await tester.pump();
  }

  Color? rowFill(WidgetTester tester, int id) {
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byKey(ValueKey('plan-$id')),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    return (box.decoration as ShapeDecoration).color;
  }

  testWidgets('draws nothing when the day has no events', (tester) async {
    await show(tester);
    expect(find.byType(AppCard), findsNothing);
    expect(find.text("Today's plan"), findsNothing);
  });

  testWidgets('lists the events in start order with their time and duration', (
    tester,
  ) async {
    await add('Lunch', Tone.life, 750, 795); // 12:30
    await add('Deep work', Tone.focus, 540, 720); // 09:00
    await show(tester);

    expect(find.text("Today's plan"), findsOneWidget);
    expect(find.text('Deep work'), findsOneWidget);
    expect(find.text('09:00 – 12:00 · 3h'), findsOneWidget);
    expect(find.text('12:30 – 13:15 · 45m'), findsOneWidget);

    final first = tester.getTopLeft(find.text('Deep work')).dy;
    final second = tester.getTopLeft(find.text('Lunch')).dy;
    expect(first, lessThan(second));
  });

  testWidgets('another day is titled with its weekday', (tester) async {
    harness = ClockHarness(selected: DateTime(2026, 10, 8));
    await add('Plan', Tone.focus, 540, 600, day: DateTime(2026, 10, 8));
    await show(tester);
    expect(find.text("Thursday's plan"), findsOneWidget);
    expect(find.text("Today's plan"), findsNothing);
  });

  testWidgets('the running event is tinted, the others are not', (
    tester,
  ) async {
    await add('Deep work', Tone.focus, 540, 720); // running at 10:30
    await add('Lunch', Tone.life, 750, 795);
    await show(tester);

    final events = await harness.repository.eventsForDay(DateTime(2026, 10, 7));
    final running = events.firstWhere((e) => e.title == 'Deep work').id;
    final later = events.firstWhere((e) => e.title == 'Lunch').id;

    expect(rowFill(tester, running), ToneColors.light.softFor(Tone.focus));
    expect(rowFill(tester, later), isNot(ToneColors.light.softFor(Tone.life)));
  });

  testWidgets('only the latest-started of several running events is tinted', (
    tester,
  ) async {
    await add('Long', Tone.focus, 540, 720);
    await add('Call', Tone.inbox, 600, 660);
    await show(tester);

    final events = await harness.repository.eventsForDay(DateTime(2026, 10, 7));
    final long = events.firstWhere((e) => e.title == 'Long').id;
    final call = events.firstWhere((e) => e.title == 'Call').id;
    expect(rowFill(tester, call), ToneColors.light.softFor(Tone.inbox));
    expect(rowFill(tester, long), isNot(ToneColors.light.softFor(Tone.focus)));
  });

  testWidgets('tapping a row opens that event', (tester) async {
    await add('Deep work', Tone.focus, 540, 720);
    await add('Lunch', Tone.life, 750, 795);
    await show(tester);

    await tester.tap(find.text('Lunch'));
    expect(opened?.title, 'Lunch');
  });

  testWidgets('a row reads as one sentence', (tester) async {
    final handle = tester.ensureSemantics();
    await add('Deep work', Tone.focus, 540, 720);
    await show(tester);

    expect(
      tester.getSemantics(find.bySemanticsLabel('Deep work, Focus, 09:00 to 12:00, 3 hours'),
      ),
      matchesSemantics(
        label: 'Deep work, Focus, 09:00 to 12:00, 3 hours',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('a long day scrolls inside its pane', (tester) async {
    for (var i = 0; i < 12; i++) {
      await add('Event $i', Tone.focus, i * 60, i * 60 + 30);
    }
    await show(tester, height: 300);

    expect(tester.takeException(), isNull);
    expect(find.byType(ListView), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
```

**Create `test/features/clock/clock_screen_wide_test.dart`**

```dart
import 'package:energy_clock/app/navigation/tab_bar_inset.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/clock_screen.dart';
import 'package:energy_clock/features/clock/widgets/clock_header.dart';
import 'package:energy_clock/features/clock/widgets/day_load_bar.dart';
import 'package:energy_clock/features/clock/widgets/dial_view.dart';
import 'package:energy_clock/features/clock/widgets/event_detail_sheet.dart';
import 'package:energy_clock/features/clock/widgets/now_card.dart';
import 'package:energy_clock/features/clock/widgets/todays_plan_list.dart';
import 'package:energy_clock/features/clock/widgets/week_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';
import '../../support/dial_pump.dart';

Widget screen() => const TabBarInset(height: 84, child: ClockScreen());

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness(); // Wednesday 7 October 2026, 10:30
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

  void setWindow(WidgetTester tester, double width, double height) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('a wide window shows two panes: the dial, then the rest', (
    tester,
  ) async {
    setWindow(tester, 1194, 834); // iPad 11" landscape
    await add('Deep work', Tone.focus, 540, 720);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);

    expect(find.byType(ClockHeader), findsOneWidget);
    expect(find.byType(WeekStrip), findsOneWidget);
    expect(find.byType(DialView), findsOneWidget);
    expect(find.byType(NowCard), findsOneWidget);
    expect(find.byType(DayLoadBar), findsOneWidget);
    expect(find.byType(TodaysPlanList), findsOneWidget);

    final dialRight = tester.getTopRight(find.byType(DialView)).dx;
    final cardLeft = tester.getTopLeft(find.byType(NowCard)).dx;
    expect(dialRight, lessThanOrEqualTo(cardLeft));
  });

  testWidgets('the dial radius is capped at 340', (tester) async {
    setWindow(tester, 1376, 1032); // iPad 13" landscape
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);
    expect(tester.widget<DialView>(find.byType(DialView)).maxRadius, 340);
  });

  testWidgets('the right pane is 36% of the window, between 340 and 440', (
    tester,
  ) async {
    setWindow(tester, 1194, 834);
    await add('Deep work', Tone.focus, 540, 720);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);
    // 0.36 * 1194 = 429.8, less 16 pt of padding on each side of the card.
    expect(
      tester.getSize(find.byType(NowCard)).width,
      closeTo(0.36 * 1194 - 32, 1),
    );

    setWindow(tester, 900, 800);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);
    // 0.36 * 900 = 324, which is below the 340 minimum.
    expect(tester.getSize(find.byType(NowCard)).width, closeTo(340 - 32, 1));

    setWindow(tester, 1376, 1032);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);
    // 0.36 * 1376 = 495, which is above the 440 maximum.
    expect(tester.getSize(find.byType(NowCard)).width, closeTo(440 - 32, 1));
  });

  testWidgets('a medium window keeps the single column and has no plan list', (
    tester,
  ) async {
    setWindow(tester, 834, 1194); // iPad 11" portrait
    await add('Deep work', Tone.focus, 540, 720);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);

    expect(find.byType(TodaysPlanList), findsNothing);
    expect(tester.widget<DialView>(find.byType(DialView)).maxRadius, isNull);
  });

  testWidgets('a narrow window keeps the single column too', (tester) async {
    setWindow(tester, 402, 874);
    await add('Deep work', Tone.focus, 540, 720);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);
    expect(find.byType(TodaysPlanList), findsNothing);
  });

  testWidgets('iPad 13" in portrait is wide too', (tester) async {
    setWindow(tester, 1032, 1376);
    await add('Deep work', Tone.focus, 540, 720);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);
    expect(find.byType(TodaysPlanList), findsOneWidget);
  });

  testWidgets('tapping a row in the plan list opens its details', (
    tester,
  ) async {
    setWindow(tester, 1194, 834);
    await add('Deep work', Tone.focus, 540, 720);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(TodaysPlanList),
        matching: find.text('Deep work'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailSheet), findsOneWidget);
  });

  testWidgets('the window can change class while the screen is open', (
    tester,
  ) async {
    setWindow(tester, 1194, 834);
    await add('Deep work', Tone.focus, 540, 720);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);
    expect(find.byType(TodaysPlanList), findsOneWidget);

    // Split View: the window shrinks to a phone-sized width.
    tester.view.physicalSize = const Size(400, 834);
    await pumpDial(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(TodaysPlanList), findsNothing);
    expect(find.byType(DialView), findsOneWidget);
  });

  testWidgets('large text on a wide window drops the bar and the dots', (
    tester,
  ) async {
    setWindow(tester, 1194, 834);
    await add('Deep work', Tone.focus, 540, 720);
    await tester.pumpWidget(harness.app(screen(), textScale: 2));
    await pumpDial(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(DayLoadBar), findsNothing);
    expect(find.byType(TodaysPlanList), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL — 'package:energy_clock/features/clock/widgets/todays_plan_list.dart' does not exist and the screen has no wide layout
flutter test test/features/clock/todays_plan_list_test.dart test/features/clock/clock_screen_wide_test.dart
```

- [ ] **Step 3: Write the list and the two-pane screen**

**Create `lib/features/clock/widgets/todays_plan_list.dart`**

```dart
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/features/clock/model/active_event.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:energy_clock/shared/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The selected day's events as a list, in start order. Shown in the right pane
/// of a wide window, where there is room for it. The running event's row is
/// tinted; tapping a row opens that event. Draws nothing on an empty day.
///
/// It scrolls inside its own pane, so it never competes with the dial's drag
/// gestures. It must sit where it gets a bounded height.
class TodaysPlanList extends ConsumerWidget {
  const TodaysPlanList({required this.onOpenEvent, super.key});

  final void Function(CalendarEvent event) onOpenEvent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDateProvider);
    final now = ref.watch(clockProvider);
    final events =
        ref.watch(dayEventsProvider).valueOrNull ?? const <CalendarEvent>[];
    if (events.isEmpty) return const SizedBox.shrink();

    final isToday = selected == startOfDay(now);
    final runningId = isToday
        ? activeEventsAt(events, minuteOfDay(now)).firstOrNull?.id
        : null;
    final title = isToday
        ? Strings.planTitleToday
        : Strings.planTitleFor(DateFormat('EEEE').format(selected));
    final toneColors = context.toneColors;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            itemCount: events.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final event = events[index];
              final palette = toneColors.paletteFor(event.tone);
              return Semantics(
                button: true,
                label: Strings.eventSemantics(
                  event.title,
                  event.tone.label,
                  formatMinuteOfDay(event.startMinute),
                  formatMinuteOfDay(event.endMinute),
                  spokenDurationMinutes(event.range.durationMinutes),
                ),
                excludeSemantics: true,
                onTap: () => onOpenEvent(event),
                child: AppCard(
                  key: ValueKey('plan-${event.id}'),
                  color: event.id == runningId ? palette.soft : null,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  onTap: () => onOpenEvent(event),
                  child: Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: palette.solid,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: const SizedBox(width: 6, height: 40),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              event.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(
                              '${formatMinuteRange(event.startMinute, event.endMinute)}'
                              ' · ${formatDurationMinutes(event.range.durationMinutes)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text(Strings.ringOverflow)),
            );
          }
        },
      ),
    );

    if (windowClass == WindowClass.wide) {
      final width = MediaQuery.sizeOf(context).width;
      final paneWidth = (width * 0.36).clamp(340.0, 440.0).toDouble();
      final largeText = textScale > ClockLayoutPlan.largeTextScale;

      return Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          0,
          AppSpacing.xxl,
          inset,
        ),
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
                    child: NowCard(compact: largeText, onOpenEvent: openDetail),
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

- [ ] **Step 4: Run the tests to verify they pass**

```bash
# expect: PASS
flutter test test/features/clock/todays_plan_list_test.dart test/features/clock/clock_screen_wide_test.dart test/features/clock/clock_screen_test.dart
```

- [ ] **Step 5: Run the whole suite and the analyzer**

```bash
# expect: PASS
flutter analyze && flutter test
```

- [ ] **Step 6: Commit**

```bash
git add lib/features/clock test/features/clock
git commit -m "feat: two-pane Clock layout with a Today's plan list on wide windows

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 25: iPad orientations and the layout matrix

App Store Connect rejects an iPad build that does not list all four orientations (error ITMS-90474): `UISupportedInterfaceOrientations~ipad` currently lists only portrait. This task fixes the plist, adds a test that keeps it fixed, and adds the full layout matrix: the Clock screen at eight window sizes and three text sizes (100%, 130% and 200%), with and without events.

**Files:**
- Edit: `ios/Runner/Info.plist` (by script, to be safe with its tab indentation)
- Test: `test/ios/info_plist_test.dart`, `test/features/clock/clock_layout_matrix_test.dart`, `test/features/clock/clock_screen_golden_test.dart`
- Create: `test/features/clock/goldens/clock_*.png`

**Interfaces:**
- Produces: an iPad orientation list with all four values; iPhone stays portrait-only; `UIRequiresFullScreen` stays unset; every build configuration keeps `TARGETED_DEVICE_FAMILY = "1,2"`.
- Consumes: `ClockScreen`, `TabBarInset`, `ClockHarness`.

- [ ] **Step 1: Write the failing tests**

**Create `test/ios/info_plist_test.dart`**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The `<string>` values inside the array that follows [key].
List<String> stringsIn(String plist, String key) {
  final match = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<array>(.*?)</array>',
    dotAll: true,
  ).firstMatch(plist);
  if (match == null) fail('Info.plist has no $key array');
  return [
    for (final m in RegExp(r'<string>(.*?)</string>').allMatches(match.group(1)!))
      m.group(1)!,
  ];
}

void main() {
  final plist = File('ios/Runner/Info.plist').readAsStringSync();

  test('the iPad lists all four orientations, which App Store Connect '
      'requires for multitasking (ITMS-90474)', () {
    expect(
      stringsIn(plist, 'UISupportedInterfaceOrientations~ipad').toSet(),
      {
        'UIInterfaceOrientationPortrait',
        'UIInterfaceOrientationPortraitUpsideDown',
        'UIInterfaceOrientationLandscapeLeft',
        'UIInterfaceOrientationLandscapeRight',
      },
    );
  });

  test('the iPhone stays portrait-only', () {
    expect(stringsIn(plist, 'UISupportedInterfaceOrientations'), [
      'UIInterfaceOrientationPortrait',
    ]);
  });

  test('the app is not forced to full screen, so multitasking stays on', () {
    expect(plist.contains('UIRequiresFullScreen'), isFalse);
  });

  test('every build configuration targets both iPhone and iPad', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final families = RegExp(
      r'TARGETED_DEVICE_FAMILY = "([^"]*)";',
    ).allMatches(project).map((m) => m.group(1)).toList();
    expect(families, isNotEmpty);
    expect(families.toSet(), {'1,2'});
  });
}
```

**Create `test/features/clock/clock_layout_matrix_test.dart`**

```dart
import 'package:energy_clock/app/navigation/tab_bar_inset.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/clock_screen.dart';
import 'package:energy_clock/features/clock/widgets/dial_view.dart';
import 'package:energy_clock/features/clock/widgets/now_card.dart';
import 'package:energy_clock/features/clock/widgets/todays_plan_list.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';
import '../../support/dial_pump.dart';

/// Every window size the Clock screen must work at, from the smallest iPhone to
/// the largest iPad, in the orientations and Split View widths it can be given.
/// The expected layout is the window class: wide windows get the two-pane
/// layout and the Today's plan list.
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

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness(); // Wednesday 7 October 2026, 10:30
  });

  tearDown(() {
    harness.dispose();
  });

  for (final entry in sizes.entries) {
    final (size, wide) = entry.value;
    for (final textScale in const [1.0, 1.3, 2.0]) {
      for (final withEvents in const [false, true]) {
        testWidgets(
          '${entry.key} (${size.width.toInt()} x ${size.height.toInt()}), '
          'text ${(textScale * 100).toInt()}%, '
          '${withEvents ? 'with' : 'without'} events',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);

            if (withEvents) {
              for (final (title, tone, start, end) in [
                ('Deep work', Tone.focus, 540, 720),
                ('Walk', Tone.life, 600, 660),
                ('A call with a long title', Tone.inbox, 610, 630),
              ]) {
                await harness.repository.createEvent(
                  day: DateTime(2026, 10, 7),
                  title: title,
                  tone: tone,
                  range: MinuteRange(start, end),
                );
              }
            }

            await tester.pumpWidget(
              harness.app(
                const TabBarInset(height: 84, child: ClockScreen()),
                textScale: textScale,
              ),
            );
            await pumpDial(tester);

            expect(tester.takeException(), isNull);
            expect(
              tester.getSize(find.byType(DialView)).shortestSide,
              greaterThanOrEqualTo(240),
            );
            // The list draws nothing on an empty day, so look for its rows.
            expect(
              find
                  .descendant(
                    of: find.byType(TodaysPlanList),
                    matching: find.byType(AppCard),
                  )
                  .evaluate()
                  .isNotEmpty,
              wide && withEvents,
              reason: wide
                  ? 'a wide window with events shows the plan list'
                  : 'only wide windows show the plan list',
            );
            expect(find.byType(NowCard), findsOneWidget);
            expect(
              tester.widget<DialView>(find.byType(DialView)).maxRadius,
              wide ? 340 : isNull,
            );
          },
        );
      }
    }
  }
}
```

**Create `test/features/clock/clock_screen_golden_test.dart`**

```dart
// Golden images of the whole Clock tab, with the floating tab bar, at the three
// window classes: an iPhone in light and dark mode, an iPad in portrait
// (medium, one column) and an iPad in landscape (wide, two panes). The clock is
// fixed at Wednesday 7 October 2026, 10:30, animations are off, and
// `test/flutter_test_config.dart` loads Nunito, so every image is
// deterministic and shows real text.
import 'package:energy_clock/app/navigation/tab_scaffold.dart';
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';
import '../../support/dial_pump.dart';

const screenKey = ValueKey('clock-screen-golden');

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> seed() async {
    for (final (title, tone, start, end) in [
      ('Deep work', Tone.focus, 540, 720),
      ('Walk', Tone.life, 600, 660),
      ('Lunch', Tone.life, 750, 795),
      ('Email and calls', Tone.inbox, 840, 900),
      ('Writing', Tone.focus, 960, 1080),
    ]) {
      await harness.repository.createEvent(
        day: DateTime(2026, 10, 7),
        title: title,
        tone: tone,
        range: MinuteRange(start, end),
      );
    }
    // A planned tone on another day, so the week strip shows a dot there too.
    await harness.repository.createEvent(
      day: DateTime(2026, 10, 8),
      title: 'Plan',
      tone: Tone.inbox,
      range: const MinuteRange(540, 600),
    );
  }

  Future<void> check(
    WidgetTester tester, {
    required Size size,
    required ThemeData theme,
    required String file,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await seed();

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

  testWidgets('iPhone 17 Pro, light', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.light,
      file: 'clock_iphone_light.png',
    );
  });

  testWidgets('iPhone 17 Pro, dark', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.dark,
      file: 'clock_iphone_dark.png',
    );
  });

  testWidgets('iPad 11" portrait (medium), light', (tester) async {
    await check(
      tester,
      size: const Size(834, 1194),
      theme: AppTheme.light,
      file: 'clock_ipad_portrait_light.png',
    );
  });

  testWidgets('iPad 11" landscape (wide, two panes), light', (tester) async {
    await check(
      tester,
      size: const Size(1194, 834),
      theme: AppTheme.light,
      file: 'clock_ipad_landscape_light.png',
    );
  });
}
```

- [ ] **Step 2: Run the tests to verify the plist test fails**

```bash
# expect: FAIL — the iPad orientation list holds only UIInterfaceOrientationPortrait
flutter test test/ios/info_plist_test.dart
```

- [ ] **Step 3: Fix the plist**

The file is indented with tabs, so this uses a script rather than a text edit. It replaces the iPad orientation array with all four values and fails loudly if it does not find exactly one such array.

```bash
# expect: RUN
python3 - <<'PY'
import re

path = 'ios/Runner/Info.plist'
text = open(path).read()
pattern = re.compile(
    r'(<key>UISupportedInterfaceOrientations~ipad</key>\s*<array>)(.*?)(</array>)',
    re.S,
)
orientations = [
    'UIInterfaceOrientationPortrait',
    'UIInterfaceOrientationPortraitUpsideDown',
    'UIInterfaceOrientationLandscapeLeft',
    'UIInterfaceOrientationLandscapeRight',
]
body = ''.join(f'\n\t\t<string>{o}</string>' for o in orientations) + '\n\t'
new, count = pattern.subn(lambda m: m.group(1) + body + m.group(3), text)
assert count == 1, 'expected exactly one iPad orientations array'
open(path, 'w').write(new)
print('iPad orientations updated')
PY
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
# expect: PASS
flutter test test/ios/info_plist_test.dart test/features/clock/clock_layout_matrix_test.dart
```

If a matrix case reports an overflow or a dial under 240 pt, fix the layout (not the test): tighten a padding, or hide a piece earlier, keep the rules in `ClockLayoutPlan`'s doc comment true, and add a `clock_layout_test.dart` case for any new rule.

Now generate the whole-tab goldens and look at them.

```bash
# expect: UPDATE
flutter test --update-goldens test/features/clock/clock_screen_golden_test.dart
```

Open `test/features/clock/goldens/clock_iphone_light.png`, `clock_iphone_dark.png`, `clock_ipad_portrait_light.png` and `clock_ipad_landscape_light.png` and check:

- **iPhone:** the day name and date with the round + button; the week strip with Wednesday selected in ink and tone dots under Wednesday and Thursday; a large raised dial with thick arcs, readable curved labels and a tone-coloured rim marker; the Now card in the running event's tone colour; the day-load bar; the floating tab bar with Clock selected. Nothing is clipped or overlapping.
- **iPad portrait:** the same single column, centred and about 560 pt wide, with the tab bar centred.
- **iPad landscape:** two panes: the dial on the left; the header, week strip, Now card, day-load bar and the Today's plan list (five rows, the running one tinted) on the right.
- **Dark:** near-black page, lighter cards and face with hairline borders, brighter arcs with near-black labels.

```bash
# expect: PASS
flutter test test/features/clock/clock_screen_golden_test.dart
```

- [ ] **Step 5: Run the whole suite and the analyzer — this is the end of Stage 5**

```bash
# expect: PASS
flutter analyze && flutter test
```

- [ ] **Step 6: Commit**

```bash
git add ios/Runner/Info.plist test/ios test/features/clock/clock_layout_matrix_test.dart test/features/clock/clock_screen_golden_test.dart test/features/clock/goldens
git commit -m "feat: iPad in all four orientations, with a layout matrix test

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Stage 6 — Brand and first run

### Task 26: Settings storage

Onboarding needs to remember that it has been seen. The `settings` key/value table has existed since the first schema but nothing reads it. This task adds a DAO over it, a small typed `SettingsRepository`, and a provider. No schema change, so no migration; Drift's generated code is regenerated and committed, like the existing `.g.dart` files.

**Files:**
- Create: `lib/data/daos/settings_dao.dart`, `lib/data/repositories/settings_repository.dart`, `test/support/fake_settings_repository.dart`
- Edit: `lib/data/database.dart`
- Replace: `lib/data/providers.dart`
- Test: `test/data/settings_test.dart`
- Regenerate: `lib/data/database.g.dart`, `lib/data/daos/settings_dao.g.dart`

**Interfaces:**
- Produces: `SettingsDao.valueFor(String key)` → `Future<String?>`; `SettingsDao.setValue(String key, String value)`; `abstract interface class SettingsRepository { Future<bool> getBool(String key, {bool defaultValue = false}); Future<void> setBool(String key, bool value); }`; `DriftSettingsRepository(SettingsDao)`; `settingsRepositoryProvider` (`Provider<SettingsRepository>`) in `lib/data/providers.dart`; `AppDatabase.settingsDao`.
- Produces (test helper): `FakeSettingsRepository({Map<String,bool>? values})` with `values`, `failReads`, `failWrites`, and a `gate` (`Completer<bool>?`) that holds reads open.
- Consumes: the existing `AppSettings` table and `SettingRow`; `appDatabaseProvider`.

- [ ] **Step 1: Write the failing test and the fake**

**Create `test/data/settings_test.dart`**

```dart
import 'package:drift/native.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('SettingsDao', () {
    test('a key that was never set reads as null', () async {
      expect(await db.settingsDao.valueFor('missing'), isNull);
    });

    test('a stored value reads back', () async {
      await db.settingsDao.setValue('theme', 'dark');
      expect(await db.settingsDao.valueFor('theme'), 'dark');
    });

    test('storing a key again replaces its value', () async {
      await db.settingsDao.setValue('theme', 'dark');
      await db.settingsDao.setValue('theme', 'light');
      expect(await db.settingsDao.valueFor('theme'), 'light');
    });

    test('keys are independent', () async {
      await db.settingsDao.setValue('a', '1');
      await db.settingsDao.setValue('b', '2');
      expect(await db.settingsDao.valueFor('a'), '1');
      expect(await db.settingsDao.valueFor('b'), '2');
    });
  });

  group('DriftSettingsRepository', () {
    late DriftSettingsRepository repository;

    setUp(() {
      repository = DriftSettingsRepository(db.settingsDao);
    });

    test('a missing key gives false, or the default when one is given', () async {
      expect(await repository.getBool('flag'), isFalse);
      expect(await repository.getBool('flag', defaultValue: true), isTrue);
    });

    test('a stored true and a stored false both read back', () async {
      await repository.setBool('on', true);
      await repository.setBool('off', false);
      expect(await repository.getBool('on'), isTrue);
      // A stored false beats a true default.
      expect(await repository.getBool('off', defaultValue: true), isFalse);
    });

    test('a later write wins', () async {
      await repository.setBool('flag', true);
      await repository.setBool('flag', false);
      expect(await repository.getBool('flag'), isFalse);
    });
  });

  test('settingsRepositoryProvider is built on the shared database', () {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(settingsRepositoryProvider),
      isA<DriftSettingsRepository>(),
    );
  });
}
```

**Create `test/support/fake_settings_repository.dart`**

```dart
import 'dart:async';

import 'package:energy_clock/data/repositories/settings_repository.dart';

/// In-memory [SettingsRepository] for widget tests.
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({Map<String, bool>? values})
    : values = {...?values};

  /// The stored settings; tests read and seed it directly.
  final Map<String, bool> values;

  /// Makes every read throw, as an unreadable database would.
  bool failReads = false;

  /// Makes every write throw.
  bool failWrites = false;

  /// While non-null, reads wait for it to complete.
  Completer<bool>? gate;

  @override
  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    if (failReads) throw StateError('settings are unreadable');
    final held = gate;
    if (held != null) await held.future;
    return values[key] ?? defaultValue;
  }

  @override
  Future<void> setBool(String key, bool value) async {
    if (failWrites) throw StateError('settings are unwritable');
    values[key] = value;
  }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
# expect: FAIL — 'settingsDao', 'DriftSettingsRepository' and 'settingsRepositoryProvider' do not exist
flutter test test/data/settings_test.dart
```

- [ ] **Step 3: Add the DAO, the repository and the provider, then regenerate**

**Create `lib/data/daos/settings_dao.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/tables/settings_table.dart';

part 'settings_dao.g.dart';

/// Reads and writes the key/value `settings` table.
@DriftAccessor(tables: [AppSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.attachedDatabase);

  /// The stored value for [key], or null when it has never been set.
  Future<String?> valueFor(String key) async {
    final row = await (select(
      appSettings,
    )..where((row) => row.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  /// Stores [value] under [key], replacing any earlier value.
  Future<void> setValue(String key, String value) {
    return into(
      appSettings,
    ).insertOnConflictUpdate(SettingRow(key: key, value: value));
  }
}
```

**Create `lib/data/repositories/settings_repository.dart`**

```dart
import 'package:energy_clock/data/daos/settings_dao.dart';

/// Typed access to the app's settings. Booleans are stored as '1' and '0'.
abstract interface class SettingsRepository {
  Future<bool> getBool(String key, {bool defaultValue = false});
  Future<void> setBool(String key, bool value);
}

class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._dao);

  final SettingsDao _dao;

  @override
  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final stored = await _dao.valueFor(key);
    return stored == null ? defaultValue : stored == '1';
  }

  @override
  Future<void> setBool(String key, bool value) =>
      _dao.setValue(key, value ? '1' : '0');
}
```

**Edit `lib/data/database.dart`**

Replace:

```dart
import 'package:energy_clock/data/daos/event_dao.dart';
```

With:

```dart
import 'package:energy_clock/data/daos/event_dao.dart';
import 'package:energy_clock/data/daos/settings_dao.dart';
```

**Edit `lib/data/database.dart`** — register the DAO.

Replace:

```dart
@DriftDatabase(tables: [Events, EventSeries, AppSettings], daos: [EventDao])
```

With:

```dart
@DriftDatabase(
  tables: [Events, EventSeries, AppSettings],
  daos: [EventDao, SettingsDao],
)
```

**Replace `lib/data/providers.dart`**

```dart
import 'package:energy_clock/data/database.dart';
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
```

Regenerate Drift's code, using the Flutter SDK's `dart`:

```bash
# expect: RUN
"$(dirname "$(which flutter)")/dart" run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
# expect: PASS
flutter test test/data && flutter analyze
```

- [ ] **Step 5: Run the whole suite**

```bash
# expect: PASS
flutter test
```

- [ ] **Step 6: Commit** (the generated files are committed, like the existing ones)

```bash
git add lib/data test/data/settings_test.dart test/support/fake_settings_repository.dart
git commit -m "feat: settings storage over the existing key/value table

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 27: App icon and launch screen

The app still wears the Flutter template's icon and a blank white launch screen. This task replaces both with the brand ring: three thick rounded arcs in the light-mode tone colours. The icon is a near-black square carrying the ring; the launch screen is the ring, small and centred, on a background that follows light and dark mode.

The artwork is drawn in code, by the same `RingMark` painter as the Clock tab icon, so it can never drift from the app. A generator script renders a 1024 px master and the launch logo; a second script resizes the master into every size the asset catalog asks for. The App Store rejects an icon with an alpha channel and Flutter always writes one, so the script flattens the master first. The generated PNGs are committed, so the scripts only need to run again to change the artwork.

A test reads the committed PNG headers and pixels, so the icon cannot silently go back to the default.

**Files:**
- Create: `tool/brand/generate_brand_assets.dart`, `tool/brand/make_icons.py`, `ios/Runner/Assets.xcassets/LaunchBackground.colorset/Contents.json`
- Edit: `ios/Runner/Base.lproj/LaunchScreen.storyboard`
- Regenerate: every PNG in `ios/Runner/Assets.xcassets/AppIcon.appiconset/` and `LaunchImage.imageset/`
- Test: `test/ios/brand_assets_test.dart`

**Interfaces:**
- Consumes: `RingMark` (Plan 1A, Task 7), `ToneColors.light`. Requires macOS `sips`.
- Produces: opaque icons at every size in `AppIcon.appiconset/Contents.json`; `LaunchImage.png` / `@2x` / `@3x` at 120 / 240 / 360 px with a transparent background; a `LaunchBackground` colour set with light and dark values.

- [ ] **Step 1: Write the failing test**

**Create `test/ios/brand_assets_test.dart`**

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const iconDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const launchDir = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';

/// Width, height and PNG colour type from the IHDR chunk. Colour type 2 is RGB
/// (no alpha channel); 6 is RGBA.
({int width, int height, int colorType}) header(String path) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  return (
    width: data.getUint32(16),
    height: data.getUint32(20),
    colorType: bytes[25],
  );
}

Future<ByteData> pixels(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  final frame = await codec.getNextFrame();
  final bytes = (await frame.image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!;
  frame.image.dispose();
  codec.dispose();
  return bytes;
}

/// Whether the pixel at ([x], [y]) is within [tolerance] of [rgb] per channel.
bool near(ByteData data, int width, int x, int y, int rgb, {int tolerance = 6}) {
  final i = (y * width + x) * 4;
  return (data.getUint8(i) - ((rgb >> 16) & 0xFF)).abs() <= tolerance &&
      (data.getUint8(i + 1) - ((rgb >> 8) & 0xFF)).abs() <= tolerance &&
      (data.getUint8(i + 2) - (rgb & 0xFF)).abs() <= tolerance;
}

void main() {
  final contents =
      jsonDecode(File('$iconDir/Contents.json').readAsStringSync())
          as Map<String, dynamic>;
  final images = (contents['images'] as List).cast<Map<String, dynamic>>();

  double pixelSide(Map<String, dynamic> image) =>
      double.parse((image['size'] as String).split('x').first) *
      int.parse((image['scale'] as String).replaceAll('x', ''));

  test('every icon in the catalog exists at the size the catalog asks for', () {
    expect(images, isNotEmpty);
    for (final image in images) {
      final file = '$iconDir/${image['filename']}';
      expect(File(file).existsSync(), isTrue, reason: file);
      final h = header(file);
      expect(h.width, pixelSide(image).round(), reason: file);
      expect(h.height, pixelSide(image).round(), reason: file);
    }
  });

  test('no icon has an alpha channel, which the App Store rejects', () {
    for (final image in images) {
      final file = '$iconDir/${image['filename']}';
      expect(header(file).colorType, 2, reason: '$file must be RGB, not RGBA');
    }
  });

  test('the marketing icon is the brand ring on near-black, not the default', () async {
    final data = await pixels('$iconDir/Icon-App-1024x1024@1x.png');
    expect(near(data, 1024, 8, 8, 0x17141F), isTrue, reason: 'corner');
    expect(near(data, 1024, 761, 368, 0x6D4AFF), isTrue, reason: 'Focus arc');
    expect(near(data, 1024, 512, 800, 0x14A85A), isTrue, reason: 'Life arc');
    expect(near(data, 1024, 263, 368, 0xF26B00), isTrue, reason: 'Inbox arc');
  });

  test('the launch logo exists at 1x, 2x and 3x with a transparent background', () {
    for (final (file, side) in [
      ('LaunchImage.png', 120),
      ('LaunchImage@2x.png', 240),
      ('LaunchImage@3x.png', 360),
    ]) {
      final h = header('$launchDir/$file');
      expect(h.width, side, reason: file);
      expect(h.height, side, reason: file);
      expect(h.colorType, 6, reason: '$file keeps its alpha channel');
    }
  });

  test('the launch background has a light and a dark colour', () {
    final colorset =
        jsonDecode(
              File(
                'ios/Runner/Assets.xcassets/LaunchBackground.colorset/Contents.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final colors = (colorset['colors'] as List).cast<Map<String, dynamic>>();
    expect(colors, hasLength(2));
    expect(colors.where((c) => c['appearances'] != null), hasLength(1));
  });

  test('the launch storyboard uses the named background and the 120 pt logo', () {
    final storyboard = File(
      'ios/Runner/Base.lproj/LaunchScreen.storyboard',
    ).readAsStringSync();
    expect(storyboard, contains('name="LaunchBackground"'));
    expect(
      storyboard,
      contains('<image name="LaunchImage" width="120" height="120"/>'),
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
# expect: FAIL — the icon is still the Flutter default, and there is no LaunchBackground colour set
flutter test test/ios/brand_assets_test.dart
```

- [ ] **Step 3: Write the generator, the resizer, the colour set and the storyboard changes**

**Create `tool/brand/generate_brand_assets.dart`**

```dart
// Renders the app icon master and the launch logo from the same RingMark
// painter the Clock tab icon uses.
//
// Run from the repository root:
//
//     flutter test tool/brand/generate_brand_assets.dart
//     python3 tool/brand/make_icons.py
//
// It writes `build/brand/icon-master-rgba.png` (1024 x 1024) and
// `build/brand/launch-logo-{1,2,3}x.png`. `make_icons.py` then resizes them
// into the asset catalog. (Running it under `flutter test` is only a way to get
// `dart:ui` rendering; this is a generator, not a test.)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/shared/widgets/ring_mark.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The near-black of the icon square (the light theme's `ink`).
const Color _iconBackground = Color(0xFF17141F);

Future<void> _render(
  WidgetTester tester, {
  required Widget child,
  required double logicalSize,
  required int pixels,
  required String path,
}) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(width: logicalSize, height: logicalSize, child: child),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixels / logicalSize);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote $path (${image.width} x ${image.height})');
  });
}

void main() {
  testWidgets('generate the brand assets', (tester) async {
    final tones = ToneColors.light;
    final arcs = [tones.focus.solid, tones.life.solid, tones.inbox.solid];

    // The icon: a near-black square with the ring at 70% of its width. The
    // master is 1024 px; the alpha channel is removed by make_icons.py.
    await _render(
      tester,
      logicalSize: 512,
      pixels: 1024,
      path: 'build/brand/icon-master-rgba.png',
      child: ColoredBox(
        color: _iconBackground,
        child: Center(
          child: RingMark(colors: arcs, size: 360, strokeFraction: 0.2),
        ),
      ),
    );

    // The launch logo: the ring alone, 120 pt, with a transparent background
    // so it sits on the light or dark launch colour.
    for (final scale in [1, 2, 3]) {
      await _render(
        tester,
        logicalSize: 120,
        pixels: 120 * scale,
        path: 'build/brand/launch-logo-${scale}x.png',
        child: RingMark(colors: arcs, size: 120, strokeFraction: 0.2),
      );
    }
  });
}
```

**Create `tool/brand/make_icons.py`**

```python
#!/usr/bin/env python3
"""Resizes the generated icon master into every size the asset catalog asks for,
and copies the launch logo into the launch image set.

The App Store rejects an app icon with an alpha channel, and Flutter always
writes one, so the master is flattened first by a lossless-enough round trip
through JPEG at maximum quality.

Run from the repository root, after
`flutter test tool/brand/generate_brand_assets.dart`. Needs macOS `sips`.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

ICONS = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
LAUNCH = 'ios/Runner/Assets.xcassets/LaunchImage.imageset'
MASTER = 'build/brand/icon-master-rgba.png'


def sips(*args):
    subprocess.run(['sips', *args], check=True, capture_output=True)


def has_alpha(path):
    out = subprocess.run(
        ['sips', '-g', 'hasAlpha', path], check=True, capture_output=True, text=True
    ).stdout
    return 'hasAlpha: yes' in out


def main():
    if not os.path.exists(MASTER):
        sys.exit(f'missing {MASTER}: run the generator first')

    with tempfile.TemporaryDirectory() as tmp:
        jpeg = os.path.join(tmp, 'master.jpg')
        flat = os.path.join(tmp, 'master-flat.png')
        sips('-s', 'format', 'jpeg', '-s', 'formatOptions', '100', MASTER, '--out', jpeg)
        sips('-s', 'format', 'png', jpeg, '--out', flat)
        if has_alpha(flat):
            sys.exit('could not remove the alpha channel from the icon master')

        with open(f'{ICONS}/Contents.json') as f:
            contents = json.load(f)
        for image in contents['images']:
            side = float(image['size'].split('x')[0]) * int(image['scale'].rstrip('x'))
            pixels = round(side)
            out = os.path.join(ICONS, image['filename'])
            sips('-z', str(pixels), str(pixels), flat, '--out', out)
            if has_alpha(out):
                sys.exit(f'{out} still has an alpha channel')
            print(f'icon   {pixels:>4} px  {out}')

    for scale, name in ((1, 'LaunchImage.png'), (2, 'LaunchImage@2x.png'), (3, 'LaunchImage@3x.png')):
        source = f'build/brand/launch-logo-{scale}x.png'
        if not os.path.exists(source):
            sys.exit(f'missing {source}: run the generator first')
        shutil.copyfile(source, os.path.join(LAUNCH, name))
        print(f'launch {120 * scale:>4} px  {os.path.join(LAUNCH, name)}')


if __name__ == '__main__':
    main()
```

**Create `ios/Runner/Assets.xcassets/LaunchBackground.colorset/Contents.json`**

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.969",
          "green" : "0.961",
          "red" : "0.957"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.078",
          "green" : "0.059",
          "red" : "0.059"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

**Edit `ios/Runner/Base.lproj/LaunchScreen.storyboard`**

Replace:

```xml
<color key="backgroundColor" red="1" green="1" blue="1" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>
```

With:

```xml
<color key="backgroundColor" name="LaunchBackground"/>
```

**Edit `ios/Runner/Base.lproj/LaunchScreen.storyboard`** — the logo size and the named colour.

Replace:

```xml
<image name="LaunchImage" width="168" height="185"/>
```

With:

```xml
<image name="LaunchImage" width="120" height="120"/>
        <namedColor name="LaunchBackground">
            <color red="0.95686274509803926" green="0.96078431372549022" blue="0.96862745098039216" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>
        </namedColor>
```

- [ ] **Step 4: Generate the artwork**

```bash
# expect: RUN
flutter test tool/brand/generate_brand_assets.dart
```

```bash
# expect: RUN
python3 tool/brand/make_icons.py
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
# expect: PASS
flutter test test/ios/brand_assets_test.dart
```

- [ ] **Step 6: Check the storyboard compiles and look at the artwork**

```bash
# expect: RUN
xcrun ibtool --errors --warnings --notices --output-format human-readable-text --compile /tmp/LaunchScreen.storyboardc ios/Runner/Base.lproj/LaunchScreen.storyboard
```

Open `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png` and `LaunchImage@3x.png` and confirm: a near-black square with a ring of three thick rounded arcs (purple, green, orange) and small gaps; no Flutter logo anywhere; the launch logo is the ring alone on a transparent background.

The controller then builds and installs the app on a simulator to see the icon on the home screen and the launch screen in light and dark mode:

```bash
# expect: MANUAL — controller, with the simulator tool
flutter build ios --simulator --debug --no-codesign
```

- [ ] **Step 7: Commit** (the regenerated PNGs are included)

```bash
git add tool/brand ios/Runner/Assets.xcassets ios/Runner/Base.lproj/LaunchScreen.storyboard test/ios/brand_assets_test.dart
git commit -m "feat: brand app icon and launch screen drawn from the ring mark

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 28: Onboarding and the sample day

A first-run flow shown before the tab shell: three swipeable pages (what the app is, the three tones with examples, how to plan), a **Skip** button on the first two, and on the last page **Start with a sample day** or **Start empty**. The sample day adds four ordinary events to today, so a first-time user, or an App Review tester, sees a full dial straight away. "Seen" is stored in the `settings` table under `onboarding_done`. If the flag cannot be read, onboarding is skipped, so it can never block the app.

Onboarding lives in `lib/app/onboarding/` because it is an app-level flow shown before the tab shell. The app layer composes features, so it may use the Clock feature's public repository provider to create the sample events.

**Files:**
- Edit: `lib/core/strings.dart`
- Create: `lib/app/onboarding/sample_day.dart`, `lib/app/onboarding/onboarding_providers.dart`, `lib/app/onboarding/onboarding_flow.dart`
- Replace: `lib/app/app.dart`
- Test: `test/app/sample_day_test.dart`, `test/app/onboarding_test.dart`, `test/app/app_test.dart`

**Interfaces:**
- Produces: `sampleDay` (`List<SampleEvent>`: Deep work, Focus, 09:00–11:00; Email and calls, Inbox, 11:00–11:45; Lunch walk, Life, 12:30–13:15; Writing, Focus, 14:00–16:00); `createSampleDay(EventRepository, {required DateTime day})` → `Future<bool>` (false only if an unexpected error stopped an event; an event needing a fourth ring is skipped silently); `onboardingDoneKey` (`'onboarding_done'`); `onboardingDoneProvider` (`AsyncNotifierProvider<OnboardingDoneNotifier, bool>`) with `markDone()`; `OnboardingFlow()`; `EnergyClockApp` becomes a `ConsumerWidget` that shows `OnboardingFlow` until the flag is set.
- Consumes: `settingsRepositoryProvider` (Task 26), `eventRepositoryProvider`, `clockProvider`, `RingMark`, `ToneChip`, `AppButton`, `ContentWidth`, `ContentWidths.onboarding`, `AppMotion`.

- [ ] **Step 1: Write the failing tests**

**Create `test/app/sample_day_test.dart`**

```dart
import 'package:energy_clock/app/onboarding/sample_day.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_event_repository.dart';

/// Refuses one event by title, as a failing write would.
class _FlakyRepository extends FakeEventRepository {
  _FlakyRepository(this.failingTitle);

  final String failingTitle;

  @override
  Future<int> createEvent({
    required DateTime day,
    required String title,
    required Tone tone,
    required MinuteRange range,
  }) {
    if (title == failingTitle) throw StateError('disk full');
    return super.createEvent(day: day, title: title, tone: tone, range: range);
  }
}

void main() {
  final day = DateTime(2026, 10, 7);
  late FakeEventRepository repository;

  setUp(() {
    repository = FakeEventRepository();
  });

  tearDown(() {
    repository.dispose();
  });

  test('the sample day is the four specified events', () {
    expect(
      [for (final e in sampleDay) (e.title, e.tone, e.range)],
      [
        ('Deep work', Tone.focus, const MinuteRange(540, 660)),
        ('Email and calls', Tone.inbox, const MinuteRange(660, 705)),
        ('Lunch walk', Tone.life, const MinuteRange(750, 795)),
        ('Writing', Tone.focus, const MinuteRange(840, 960)),
      ],
    );
  });

  test('creates every event on the given day', () async {
    final complete = await createSampleDay(repository, day: day);

    expect(complete, isTrue);
    final events = await repository.eventsForDay(day);
    expect(events.map((e) => e.title), [
      'Deep work',
      'Email and calls',
      'Lunch walk',
      'Writing',
    ]);
    expect(events.map((e) => e.tone), [
      Tone.focus,
      Tone.inbox,
      Tone.life,
      Tone.focus,
    ]);
  });

  test('does not touch other days', () async {
    await createSampleDay(repository, day: day);
    expect(await repository.eventsForDay(DateTime(2026, 10, 8)), isEmpty);
  });

  test('skips an event that would need a fourth ring, and carries on', () async {
    // Three events overlapping 09:00-12:00 already fill every ring there.
    for (var i = 0; i < 3; i++) {
      await repository.createEvent(
        day: day,
        title: 'Busy $i',
        tone: Tone.life,
        range: const MinuteRange(540, 720),
      );
    }

    final complete = await createSampleDay(repository, day: day);

    expect(complete, isTrue, reason: 'a skipped event is not an error');
    final titles = (await repository.eventsForDay(day)).map((e) => e.title);
    expect(titles, isNot(contains('Deep work')));
    expect(titles, isNot(contains('Email and calls')));
    expect(titles, containsAll(['Lunch walk', 'Writing']));
  });

  test('an unexpected error is reported but the rest are still created', () async {
    final flaky = _FlakyRepository('Lunch walk');
    addTearDown(flaky.dispose);

    final complete = await createSampleDay(flaky, day: day);

    expect(complete, isFalse);
    final titles = (await flaky.eventsForDay(day)).map((e) => e.title);
    expect(titles, ['Deep work', 'Email and calls', 'Writing']);
  });
}
```

**Create `test/app/onboarding_test.dart`**

```dart
import 'package:energy_clock/app/onboarding/onboarding_flow.dart';
import 'package:energy_clock/app/onboarding/onboarding_providers.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/shared/widgets/tone_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/clock_harness.dart';
import '../support/fake_event_repository.dart';
import '../support/fake_settings_repository.dart';

class _FailingRepository extends FakeEventRepository {
  @override
  Future<int> createEvent({
    required DateTime day,
    required String title,
    required Tone tone,
    required MinuteRange range,
  }) => throw StateError('disk full');
}

void main() {
  late FakeSettingsRepository settings;
  late ClockHarness harness;

  setUp(() {
    settings = FakeSettingsRepository();
    harness = ClockHarness(
      overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
    );
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> show(
    WidgetTester tester, {
    double textScale = 1,
    bool reduceMotion = false,
  }) async {
    await tester.pumpWidget(
      harness.app(
        const OnboardingFlow(),
        textScale: textScale,
        reduceMotion: reduceMotion,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.text(Strings.onboardingNext));
    await tester.pumpAndSettle();
  }

  testWidgets('starts on the intro, with Skip and Next', (tester) async {
    await show(tester);
    expect(find.text(Strings.onboardingTitle1), findsOneWidget);
    expect(find.text(Strings.onboardingBody1), findsOneWidget);
    expect(find.text(Strings.onboardingSkip), findsOneWidget);
    expect(find.text(Strings.onboardingNext), findsOneWidget);
  });

  testWidgets('the second page shows the three tones with examples', (
    tester,
  ) async {
    await show(tester);
    await next(tester);

    expect(find.text(Strings.onboardingTitle2), findsOneWidget);
    expect(find.byType(ToneChip), findsNWidgets(3));
    expect(find.text(Strings.toneExampleFocus), findsOneWidget);
    expect(find.text(Strings.toneExampleLife), findsOneWidget);
    expect(find.text(Strings.toneExampleInbox), findsOneWidget);
    expect(find.text(Strings.onboardingSkip), findsOneWidget);
  });

  testWidgets('the last page offers a sample day or an empty start, and no Skip', (
    tester,
  ) async {
    await show(tester);
    await next(tester);
    await next(tester);

    expect(find.text(Strings.onboardingTitle3), findsOneWidget);
    expect(find.text(Strings.onboardingSampleDay), findsOneWidget);
    expect(find.text(Strings.onboardingStartEmpty), findsOneWidget);
    expect(find.text(Strings.onboardingNext), findsNothing);
    expect(find.text(Strings.onboardingSkip), findsNothing);
  });

  testWidgets('swiping moves between pages too', (tester) async {
    await show(tester);
    // A drag past the halfway point, not a fling: a fling carries on for a
    // second page.
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text(Strings.onboardingTitle2), findsOneWidget);
  });

  testWidgets('Skip finishes without creating anything', (tester) async {
    await show(tester);
    await tester.tap(find.text(Strings.onboardingSkip));
    await tester.pumpAndSettle();

    expect(settings.values[onboardingDoneKey], isTrue);
    expect(await harness.repository.eventsForDay(DateTime(2026, 10, 7)), isEmpty);
  });

  testWidgets('Start empty finishes without creating anything', (tester) async {
    await show(tester);
    await next(tester);
    await next(tester);
    await tester.tap(find.text(Strings.onboardingStartEmpty));
    await tester.pumpAndSettle();

    expect(settings.values[onboardingDoneKey], isTrue);
    expect(await harness.repository.eventsForDay(DateTime(2026, 10, 7)), isEmpty);
  });

  testWidgets('Start with a sample day adds four events to the clock\'s today', (
    tester,
  ) async {
    await show(tester);
    await next(tester);
    await next(tester);
    await tester.tap(find.text(Strings.onboardingSampleDay));
    await tester.pumpAndSettle();

    expect(settings.values[onboardingDoneKey], isTrue);
    final events = await harness.repository.eventsForDay(DateTime(2026, 10, 7));
    expect(events.map((e) => e.title), [
      'Deep work',
      'Email and calls',
      'Lunch walk',
      'Writing',
    ]);
  });

  testWidgets('a sample day that cannot be saved says so, and still finishes', (
    tester,
  ) async {
    final failing = _FailingRepository();
    addTearDown(failing.dispose);
    harness.dispose();
    harness = ClockHarness(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        eventRepositoryProvider.overrideWithValue(failing),
      ],
    );

    await show(tester);
    await next(tester);
    await next(tester);
    await tester.tap(find.text(Strings.onboardingSampleDay));
    await tester.pumpAndSettle();

    expect(find.text(Strings.sampleDayFailed), findsOneWidget);
    expect(settings.values[onboardingDoneKey], isTrue);
  });

  testWidgets('the buttons are disabled once one has been pressed', (
    tester,
  ) async {
    await show(tester);
    await next(tester);
    await next(tester);

    await tester.tap(find.text(Strings.onboardingSampleDay));
    await tester.pump(); // before the finish has completed
    await tester.tap(find.text(Strings.onboardingSampleDay), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(
      (await harness.repository.eventsForDay(DateTime(2026, 10, 7))).length,
      4,
      reason: 'a second tap must not add the sample day twice',
    );
  });

  testWidgets('with reduced motion Next jumps to the next page', (tester) async {
    await show(tester, reduceMotion: true);
    await tester.tap(find.text(Strings.onboardingNext));
    await tester.pump();
    expect(find.text(Strings.onboardingTitle2), findsOneWidget);
  });

  testWidgets('the page dots are announced', (tester) async {
    final handle = tester.ensureSemantics();
    await show(tester);
    expect(find.semantics.byLabel('Page 1 of 3'), findsOneWidget);
    await next(tester);
    expect(find.semantics.byLabel('Page 2 of 3'), findsOneWidget);
    handle.dispose();
  });

  for (final textScale in const [1.0, 2.0]) {
    testWidgets('no page overflows on a small phone at ${textScale * 100}% text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await show(tester, textScale: textScale);
      expect(tester.takeException(), isNull);
      await next(tester);
      expect(tester.takeException(), isNull);
      await next(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('on an iPad the flow is a centred column', (tester) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await show(tester);
    final width = tester.getSize(find.byType(PageView)).width;
    expect(width, 480);
  });
}
```

**Create `test/app/app_test.dart`**

```dart
import 'dart:async';

import 'package:energy_clock/app/app.dart';
import 'package:energy_clock/app/navigation/tab_scaffold.dart';
import 'package:energy_clock/app/onboarding/onboarding_flow.dart';
import 'package:energy_clock/app/onboarding/onboarding_providers.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/clock_harness.dart';
import '../support/dial_pump.dart';
import '../support/fake_settings_repository.dart';

void main() {
  late FakeSettingsRepository settings;
  late ClockHarness harness;

  setUp(() {
    settings = FakeSettingsRepository();
    harness = ClockHarness(
      overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
    );
  });

  tearDown(() {
    harness.dispose();
  });

  Widget app() => UncontrolledProviderScope(
    container: harness.container,
    child: const EnergyClockApp(),
  );

  testWidgets('first launch shows onboarding', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingFlow), findsOneWidget);
    expect(find.byType(TabScaffold), findsNothing);
  });

  testWidgets('once onboarding has been seen, the app opens on the tabs', (
    tester,
  ) async {
    settings.values[onboardingDoneKey] = true;
    await tester.pumpWidget(app());
    await pumpDial(tester);
    expect(find.byType(TabScaffold), findsOneWidget);
    expect(find.byType(OnboardingFlow), findsNothing);
  });

  testWidgets('if the flag cannot be read, onboarding is skipped', (
    tester,
  ) async {
    settings.failReads = true;
    await tester.pumpWidget(app());
    await pumpDial(tester);
    expect(find.byType(TabScaffold), findsOneWidget);
    expect(find.byType(OnboardingFlow), findsNothing);
  });

  testWidgets('while the flag loads, neither screen is shown', (tester) async {
    settings.gate = Completer<bool>();
    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.byType(OnboardingFlow), findsNothing);
    expect(find.byType(TabScaffold), findsNothing);

    settings.gate!.complete(true);
    settings.gate = null;
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingFlow), findsOneWidget);
  });

  testWidgets('finishing onboarding opens the tabs and remembers it', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text(Strings.onboardingSkip));
    await pumpDial(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(TabScaffold), findsOneWidget);
    expect(find.byType(OnboardingFlow), findsNothing);
    expect(settings.values[onboardingDoneKey], isTrue);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
# expect: FAIL — 'package:energy_clock/app/onboarding/...' does not exist and the onboarding strings are not defined
flutter test test/app/sample_day_test.dart test/app/onboarding_test.dart test/app/app_test.dart
```

- [ ] **Step 3: Add the copy, the sample day, the flow, and the app wiring**

**Edit `lib/core/strings.dart`**

Replace:

```dart
    return '$head and ${items.last}';
  }
}
```

With:

```dart
    return '$head and ${items.last}';
  }

  // Onboarding.
  static const String onboardingSkip = 'Skip';
  static const String onboardingNext = 'Next';
  static const String onboardingTitle1 = 'Plan your day by energy, not just time';
  static const String onboardingBody1 =
      'Energy Clock puts your day on a 24-hour dial, so you can see how heavy '
      'the day is before you start it.';
  static const String onboardingTitle2 = 'Three tones for every event';
  static const String toneExampleFocus =
      'Deep, demanding work: writing, design, thinking';
  static const String toneExampleLife = 'Body and rest: sport, a walk, lunch';
  static const String toneExampleInbox =
      'Routine and reactive: email, calls, admin';
  static const String onboardingTitle3 = 'Drag the ring to plan';
  static const String onboardingBody3 =
      'Press and drag on the ring around the clock to block out time. Tap an '
      'event to see details, or drag it to move or resize it.';
  static const String onboardingSampleDay = 'Start with a sample day';
  static const String onboardingStartEmpty = 'Start empty';
  static String onboardingPage(int page, int count) => 'Page $page of $count';

  // The sample day.
  static const String sampleDeepWork = 'Deep work';
  static const String sampleEmailCalls = 'Email and calls';
  static const String sampleLunchWalk = 'Lunch walk';
  static const String sampleWriting = 'Writing';
  static const String sampleDayFailed = "Couldn't add the sample day.";
}
```

**Create `lib/app/onboarding/sample_day.dart`**

```dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';

/// One event of the sample day.
class SampleEvent {
  const SampleEvent(this.title, this.tone, this.range);

  final String title;
  final Tone tone;
  final MinuteRange range;
}

/// A realistic day that touches every tone, none of it overlapping.
const List<SampleEvent> sampleDay = [
  SampleEvent(Strings.sampleDeepWork, Tone.focus, MinuteRange(540, 660)),
  SampleEvent(Strings.sampleEmailCalls, Tone.inbox, MinuteRange(660, 705)),
  SampleEvent(Strings.sampleLunchWalk, Tone.life, MinuteRange(750, 795)),
  SampleEvent(Strings.sampleWriting, Tone.focus, MinuteRange(840, 960)),
];

/// Adds the sample events to [day] as ordinary events. An event that would
/// need a fourth ring on a day that already has overlapping events is skipped
/// on purpose. Returns false only if some other error stopped an event from
/// being added; the rest are still created.
Future<bool> createSampleDay(
  EventRepository repository, {
  required DateTime day,
}) async {
  var complete = true;
  for (final sample in sampleDay) {
    try {
      await repository.createEvent(
        day: day,
        title: sample.title,
        tone: sample.tone,
        range: sample.range,
      );
    } on RingOverflowException {
      // Skipped by design: the day is already full at that time.
    } on Object {
      complete = false;
    }
  }
  return complete;
}
```

**Create `lib/app/onboarding/onboarding_providers.dart`**

```dart
import 'package:energy_clock/data/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The `settings` key that records that onboarding has been seen.
const String onboardingDoneKey = 'onboarding_done';

/// Whether onboarding has been seen. If the flag cannot be read the provider
/// is in an error state, and the app skips onboarding rather than blocking.
final onboardingDoneProvider =
    AsyncNotifierProvider<OnboardingDoneNotifier, bool>(
      OnboardingDoneNotifier.new,
    );

class OnboardingDoneNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() =>
      ref.watch(settingsRepositoryProvider).getBool(onboardingDoneKey);

  /// Remembers that onboarding has been seen and moves the app on.
  Future<void> markDone() async {
    await ref.read(settingsRepositoryProvider).setBool(onboardingDoneKey, true);
    state = const AsyncData(true);
  }
}
```

**Create `lib/app/onboarding/onboarding_flow.dart`**

```dart
import 'package:energy_clock/app/onboarding/onboarding_providers.dart';
import 'package:energy_clock/app/onboarding/sample_day.dart';
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/shared/layout/content_width.dart';
import 'package:energy_clock/shared/widgets/app_button.dart';
import 'package:energy_clock/shared/widgets/ring_mark.dart';
import 'package:energy_clock/shared/widgets/tone_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The first-run flow: three pages and a way out. It is shown before the tab
/// shell and replaced by it once finished.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  static const int _pageCount = 3;

  final PageController _controller = PageController();
  int _page = 0;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(_page + 1);
    } else {
      await _controller.nextPage(
        duration: AppMotion.base,
        curve: AppMotion.standard,
      );
    }
  }

  Future<void> _finish({required bool withSampleDay}) async {
    if (_busy) return;
    setState(() => _busy = true);

    // Taken before anything is awaited and before the flow is replaced, so the
    // message outlives it.
    final messenger = ScaffoldMessenger.of(context);

    var sampleFailed = false;
    if (withSampleDay) {
      sampleFailed = !await createSampleDay(
        ref.read(eventRepositoryProvider),
        day: startOfDay(ref.read(clockProvider)),
      );
    }
    await ref.read(onboardingDoneProvider.notifier).markDone();
    if (sampleFailed) {
      messenger.showSnackBar(
        const SnackBar(content: Text(Strings.sampleDayFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final onLastPage = _page == _pageCount - 1;

    return Scaffold(
      body: SafeArea(
        child: ContentWidth(
          maxWidth: ContentWidths.onboarding,
          child: Column(
            children: [
              SizedBox(
                height: 56,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: onLastPage
                      ? null
                      : Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                          ),
                          child: TextButton(
                            onPressed: _busy
                                ? null
                                : () => _finish(withSampleDay: false),
                            child: const Text(Strings.onboardingSkip),
                          ),
                        ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (page) => setState(() => _page = page),
                  children: const [_IntroPage(), _TonesPage(), _PlanPage()],
                ),
              ),
              _PageDots(index: _page, count: _pageCount),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: onLastPage
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppButton(
                            label: Strings.onboardingSampleDay,
                            onPressed: _busy
                                ? null
                                : () => _finish(withSampleDay: true),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppButton(
                            label: Strings.onboardingStartEmpty,
                            variant: AppButtonVariant.secondary,
                            onPressed: _busy
                                ? null
                                : () => _finish(withSampleDay: false),
                          ),
                        ],
                      )
                    : AppButton(
                        label: Strings.onboardingNext,
                        onPressed: _next,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A page's layout: an optional picture, a title and some text, scrollable so
/// large text never overflows.
class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.title, this.picture, this.body, this.child});

  final String title;
  final Widget? picture;
  final String? body;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (picture != null) ...[
              picture!,
              const SizedBox(height: AppSpacing.xxxl),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            if (body != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium!.copyWith(color: colors.muted),
              ),
            ],
            if (child != null) ...[
              const SizedBox(height: AppSpacing.xl),
              child!,
            ],
          ],
        ),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage();

  @override
  Widget build(BuildContext context) {
    final tones = context.toneColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _OnboardingPage(
      title: Strings.onboardingTitle1,
      body: Strings.onboardingBody1,
      picture: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: reduceMotion ? 1 : 0, end: 1),
        duration: reduceMotion ? Duration.zero : AppMotion.slow * 2,
        curve: AppMotion.standard,
        builder: (context, progress, _) => RingMark(
          colors: [tones.focus.solid, tones.life.solid, tones.inbox.solid],
          size: 180,
          progress: progress,
        ),
      ),
    );
  }
}

class _TonesPage extends StatelessWidget {
  const _TonesPage();

  static const Map<Tone, String> _examples = {
    Tone.focus: Strings.toneExampleFocus,
    Tone.life: Strings.toneExampleLife,
    Tone.inbox: Strings.toneExampleInbox,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _OnboardingPage(
      title: Strings.onboardingTitle2,
      child: Column(
        children: [
          for (final tone in Tone.values) ...[
            Align(alignment: Alignment.centerLeft, child: ToneChip(tone: tone)),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_examples[tone]!, style: theme.textTheme.bodyMedium),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }
}

class _PlanPage extends StatelessWidget {
  const _PlanPage();

  @override
  Widget build(BuildContext context) {
    final tones = context.toneColors;
    return _OnboardingPage(
      title: Strings.onboardingTitle3,
      body: Strings.onboardingBody3,
      picture: RingMark(
        colors: [tones.focus.solid, tones.life.solid, tones.inbox.solid],
        size: 96,
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: Strings.onboardingPage(index + 1, count),
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: reduceMotion ? Duration.zero : AppMotion.base,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index
                    ? colors.ink
                    : colors.ink.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
        ],
      ),
    );
  }
}
```

**Replace `lib/app/app.dart`**

```dart
import 'package:energy_clock/app/navigation/tab_scaffold.dart';
import 'package:energy_clock/app/onboarding/onboarding_flow.dart';
import 'package:energy_clock/app/onboarding/onboarding_providers.dart';
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EnergyClockApp extends ConsumerWidget {
  const EnergyClockApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingDoneProvider);

    return MaterialApp(
      title: Strings.appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: onboarding.when(
        data: (done) => done ? const TabScaffold() : const OnboardingFlow(),
        // A launch where the flag cannot be read must never be blocked by
        // onboarding.
        error: (error, stack) => const TabScaffold(),
        loading: () => const _Splash(),
      ),
    );
  }
}

/// A blank page in the app background, shown for the instant the flag loads.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: Theme.of(context).scaffoldBackgroundColor);
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
# expect: PASS
flutter test test/app/sample_day_test.dart test/app/onboarding_test.dart test/app/app_test.dart && flutter analyze
```

- [ ] **Step 5: Run the whole suite**

```bash
# expect: PASS
flutter test
```

- [ ] **Step 6: Commit**

```bash
git add lib/core/strings.dart lib/app test/app
git commit -m "feat: three-screen onboarding with an optional sample day

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Stage 7 — Final checks

### Task 29: Format, README, verification and screenshots

The last task makes the repository tidy, replaces the template README, and runs the verification the spec requires, including the manual checks that only a person and a simulator can do.

**Files:**
- Replace: `README.md`
- Edit: `pubspec.yaml` (description)
- Format: `lib`, `test`, `tool` (only if `dart format` finds changes)

**Interfaces:** consumes everything. Produces: a tidy tree, a real README, screenshots for review.

- [ ] **Step 1: Replace the README and the package description**

**Replace `README.md`**

````markdown
# Energy Clock

Plan your day by energy, not just time.

Energy Clock puts a day on a 24-hour dial. You drag out events around the ring and give each one a **tone**:

| Tone | Colour | Meaning |
|---|---|---|
| Focus | Purple | Deep, demanding work |
| Life | Green | Body and rest |
| Inbox | Orange | Routine and reactive work |

Reading the ring tells you what kind of day you have committed to before you read a single word. Everything stays on the device: no account, no backend.

## Run it

```bash
flutter pub get
flutter run
```

It runs on iPhone (portrait) and iPad (all orientations). The dial planner, the week strip, the Now card and the event sheets are done; the Calendar, Stats and Profile tabs are still placeholders.

## Test it

```bash
flutter analyze
flutter test
```

Dial goldens live in `test/features/clock/goldens`. After a deliberate visual change, regenerate them with `flutter test --update-goldens test/features/clock/dial_golden_test.dart` and look at the images.

Drift generates code for the database. After changing a table or DAO, run it with the Flutter SDK's `dart`:

```bash
"$(dirname "$(which flutter)")/dart" run build_runner build --delete-conflicting-outputs
```

## Project layout

```
lib/
  app/          app shell, theme tokens, tab bar, onboarding
  core/         pure logic: time, dial geometry, strings, tones
  data/         Drift database, DAOs, repositories
  features/     clock (calendar, stats and profile are placeholders)
  shared/       widgets and layout helpers used by every feature
tool/brand/     generates the app icon and launch logo
docs/superpowers/
  specs/        design specs
  plans/        implementation plans
```

Features never import each other; they share data through repositories exposed as Riverpod providers. Feature code never hard-codes a colour (a test enforces it).

## Design and plans

- `docs/superpowers/specs/2026-08-23-energy-clock-design.md`: the product spec (Phases 1–5).
- `docs/superpowers/specs/2026-10-03-step-1-foundation-design.md`: the Step 1 design (look, dial v2, Clock screen, iPad, brand, onboarding).
- `docs/superpowers/plans/`: the implementation plans.

## Fonts

The app bundles [Nunito](https://fonts.google.com/specimen/Nunito) under the SIL Open Font Licence (`assets/fonts/OFL.txt`).
````

**Edit `pubspec.yaml`**

Replace:

```yaml
description: "A new Flutter project."
```

With:

```yaml
description: "Plan your day by energy, not just time."
```

- [ ] **Step 2: Apply the repository's formatter**

```bash
# expect: RUN
"$(dirname "$(which flutter)")/dart" format lib test tool
git status --short
```

If `dart format` changed files, review that the diff is formatting only and commit it on its own:

```bash
git add -A lib test tool
git commit -m "style: apply dart format

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 3: Run the whole verification**

```bash
# expect: PASS
flutter analyze && flutter test
```

Expected: no analyzer issues, and every test passes, including the contrast tests, the no-hard-coded-colour test, the iPad plist test, the brand-asset test, and the layout matrix.

- [ ] **Step 4: Build for the simulator**

```bash
# expect: MANUAL — controller
flutter build ios --simulator --debug --no-codesign
```

- [ ] **Step 5: Manual verification, with screenshots** (the controller drives the simulators; screenshots are taken with `xcrun simctl io <device> screenshot <file>` or the simulator tool)

For each device below, install and launch the app, and check the list under it. Keep every screenshot for the review.

- **iPhone 17 Pro:** portrait, light and dark.
- **A small iPhone (iPhone SE size):** create one if the machine has none: `xcrun simctl create "iPhone SE (3rd generation)" "iPhone SE (3rd generation)" <an installed iOS runtime>`.
- **iPad Pro 13":** all four orientations; Split View at one third and one half; light and dark.

Check on each:

1. **First launch:** the three onboarding pages; "Start with a sample day" lands on a full dial with the Now card, week strip and day-load bar.
2. **Clock tab:** the dial is large; the face grows and shrinks smoothly as you add and remove overlapping events; the centre time never touches the rim marker; a drag on the ring creates, moves and resizes events; the week strip selects days and its dots match each day's tones.
3. **Text and motion:** at the largest text size (`xcrun simctl ui <device> content_size accessibility-extra-extra-extra-large`) nothing overflows and the dial stays usable; with Reduce Motion on, nothing sweeps, pops or pulses.
4. **VoiceOver spot check** (Accessibility Inspector): every event arc reads as one sentence with Open, Edit and Delete actions; the Now card, week pills, day-load bar and tabs read as clear sentences; the **+** button adds an event without dragging.
5. **Look:** colour appears only as tone colour; buttons and the selected tab are near-black (near-white in dark mode); the tab bar floats; sheets have a drag handle and scroll.
6. **Icon and launch screen:** the home-screen icon is the brand ring, not the Flutter logo; the launch screen shows the ring on the light or dark background.
7. **The centre time:** watch it change once. If the digits visibly jitter sideways (Nunito lacking tabular figures), set a fixed width for the time text in `_DialCentre` and re-check.

- [ ] **Step 6: Cross-check against the spec's acceptance criteria**

Tick each one, with the evidence:

| Criterion (spec §14) | Evidence |
|---|---|
| Everything in §§4–10 is implemented | The tasks above; the screenshots |
| `flutter analyze` clean and the full suite passes | Step 3 |
| Contrast tests, no-hard-coded-colour test, layout matrix pass | Step 3 |
| The user approves the phone and iPad screenshots | Step 5, reviewed with the user |
| iPad orientation settings match Apple's rule | `test/ios/info_plist_test.dart`; the real upload check belongs to Step 6 of the roadmap |
| No new runtime packages | `git diff main -- pubspec.yaml` shows only the description, fonts and the assets list |

- [ ] **Step 7: Commit**

```bash
git add README.md pubspec.yaml
git commit -m "docs: replace the template README and describe the package

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 8: Hand over for review**

Share the screenshots and the checklist results with the user. **Step 1 is complete and reviewed only when the user approves the screenshots.** Do not submit this build: Calendar, Stats and Profile are placeholders until Steps 3–5 of the roadmap.
