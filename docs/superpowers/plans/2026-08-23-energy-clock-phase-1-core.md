# Energy Clock — Phase 1 (Core) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a working visual day planner — a 24-hour dial where the user drags out event sectors, assigns each a tone, edits them, and switches days, with everything persisted locally.

**Architecture:** Feature-first Flutter app. All polar math lives in a pure-Dart `DialGeometry` class with no rendering dependency, which is where the tests concentrate; `DialPainter` is a thin renderer over it. Persistence is Drift (typed SQLite) behind an `EventRepository` interface, exposed to widgets through Riverpod providers. Overlap ring assignment is computed at render time, never stored.

**Tech Stack:** Flutter 3.44.7, Dart 3.12.2, `flutter_riverpod`, `drift` + `drift_flutter`, `drift_dev` + `build_runner` (dev), `intl`.

**Spec:** `docs/superpowers/specs/2026-08-23-energy-clock-design.md`

## Global Constraints

These apply to every task. Copied verbatim from the spec.

- **Platform:** iOS only, iPhone, portrait, iOS 15+. No Android, iPad, macOS, or web targets.
- **Language:** English-only. All user-facing copy in English, defined in `lib/core/strings.dart`. No localisation framework.
- **Tones are fixed:** exactly three — Focus (purple), Life (green), Inbox (orange). Not addable, removable, renameable, or recolourable.
- **Boundary rule:** no file under `features/<a>/` may import from `features/<b>/`. Cross-feature communication goes through repositories exposed as Riverpod providers.
- **No hard-coded colours in feature code.** Every colour comes from the theme's `ToneColors` extension or `Theme.of(context).colorScheme`.
- **Minute domain:** `startMinute` is 0–1439, `endMinute` is 1–1440 and exclusive. `endMinute` never exceeds 1440 — cross-midnight events are not allowed.
- **Drag rules:** snap to 5-minute increments; minimum event duration 15 minutes; a drag past the end of day clamps at `endMinute` 1440.
- **Overlaps:** allowed, up to 3 rings. A fourth simultaneous event is refused with the message "Up to three overlapping events."
- **Ring assignment is computed at render time, never stored.**
- **Editability:** past days are read-only. Today and future days are editable.
- **Schema migrations** are versioned from v1. Every later schema change ships with a migration step and a migration test.
- **No charting library, no HTTP client, no analytics or crash-reporting SDK.**
- **Commit messages** end with a trailing blank line then `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.

## Out of scope for Phase 1

Do not build these — they are later phases. If a task seems to need one, stop and ask.

- Session timer, session controls, notifications (Phase 2)
- Recurrence expansion, day templates, copy-yesterday (Phase 3) — the `event_series` table is created in Phase 1 but nothing reads it
- Calendar month grid, statistics, gamification, Weekly Roundup (Phases 3–5)
- The Calendar / Stats / Profile tabs are placeholder screens in Phase 1

---

## File Structure

**Created in this phase:**

| File | Responsibility |
|---|---|
| `lib/main.dart` | Entry point; wraps app in `ProviderScope` |
| `lib/app/app.dart` | Root `MaterialApp`, theme mode wiring |
| `lib/app/theme/tone_colors.dart` | `ToneColors` theme extension — per-tone fill and label colours |
| `lib/app/theme/app_theme.dart` | Light and dark `ThemeData` |
| `lib/app/navigation/tab_scaffold.dart` | Four-tab bottom navigation shell |
| `lib/core/strings.dart` | All user-facing copy |
| `lib/core/tone.dart` | `Tone` enum with stable db indices |
| `lib/core/time/day_time.dart` | Day boundaries, minute-of-day helpers, formatting |
| `lib/core/geometry/dial_geometry.dart` | Polar math, hit testing, ring radii |
| `lib/core/geometry/minute_range.dart` | `MinuteRange`, drag snapping, clamping, angle unwrapping |
| `lib/core/geometry/ring_layout.dart` | Innermost-free-ring assignment and overflow detection |
| `lib/data/tables/events_table.dart` | `Events` Drift table |
| `lib/data/tables/event_series_table.dart` | `EventSeries` Drift table (schema only this phase) |
| `lib/data/tables/settings_table.dart` | `AppSettings` key/value Drift table |
| `lib/data/database.dart` | `AppDatabase`, schema version 1 |
| `lib/data/daos/event_dao.dart` | Queries against `Events` |
| `lib/features/clock/model/calendar_event.dart` | Domain model, independent of Drift row types |
| `lib/features/clock/data/event_repository.dart` | `EventRepository` interface + Drift implementation |
| `lib/features/clock/providers.dart` | Riverpod providers for db, repository, selected date, day events |
| `lib/features/clock/widgets/dial_painter.dart` | Renders face, ticks, numerals, now-hand, arcs, curved labels |
| `lib/features/clock/widgets/dial_view.dart` | Gesture handling over the painter |
| `lib/features/clock/widgets/event_sheet.dart` | Create/edit modal sheet |
| `lib/features/clock/widgets/event_detail_sheet.dart` | Tap-an-arc detail sheet |
| `lib/features/clock/widgets/day_header.dart` | Date display with prev/next/today controls |
| `lib/features/clock/clock_screen.dart` | Assembles header, dial, empty state |
| `lib/features/calendar/calendar_screen.dart` | Placeholder |
| `lib/features/stats/stats_screen.dart` | Placeholder |
| `lib/features/progress/profile_screen.dart` | Placeholder |

---

### Task 1: Project scaffold and iOS configuration

**Files:**
- Create: `pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart`, `ios/` (generated)
- Delete: `test/widget_test.dart` (generated placeholder)
- Modify: `ios/Runner/Info.plist`, `ios/Podfile`

**Interfaces:**
- Consumes: nothing — this is the first task.
- Produces: a Flutter project named `energy_clock` that builds for iOS and runs `flutter test` and `flutter analyze` cleanly. Package imports take the form `package:energy_clock/...`.

- [ ] **Step 1: Generate the Flutter project into the existing repo**

The repo already contains `e`, `image.png`, and `docs/`. `flutter create` works in a non-empty directory.

```bash
flutter create --org com.selfloop --project-name energy_clock --platforms=ios .
```

- [ ] **Step 2: Add runtime and dev dependencies**

```bash
flutter pub add flutter_riverpod drift drift_flutter intl
flutter pub add --dev drift_dev build_runner
```

- [ ] **Step 3: Replace `analysis_options.yaml`**

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
  errors:
    invalid_annotation_target: ignore

linter:
  rules:
    - always_declare_return_types
    - prefer_final_locals
    - prefer_single_quotes
    - unawaited_futures
    - avoid_print
```

- [ ] **Step 4: Lock the app to portrait and set the display name**

In `ios/Runner/Info.plist`, replace the `UISupportedInterfaceOrientations` array with portrait only, and set the display name:

```xml
<key>CFBundleDisplayName</key>
<string>Energy Clock</string>
<key>UISupportedInterfaceOrientations</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
</array>
```

- [ ] **Step 5: Set the iOS deployment target to 15.0**

In `ios/Podfile`, uncomment and set the first line:

```ruby
platform :ios, '15.0'
```

- [ ] **Step 6: Replace `lib/main.dart` with a Riverpod-wrapped stub**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: EnergyClockApp()));
}

class EnergyClockApp extends StatelessWidget {
  const EnergyClockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Energy Clock',
      home: Scaffold(body: Center(child: Text('Energy Clock'))),
    );
  }
}
```

- [ ] **Step 7: Delete the generated placeholder test**

```bash
rm test/widget_test.dart
```

- [ ] **Step 8: Verify the project analyses and builds**

```bash
flutter analyze
```
Expected: "No issues found!"

```bash
flutter build ios --simulator --debug
```
Expected: build succeeds.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
chore: scaffold Energy Clock Flutter project

Flutter project targeting iOS only, portrait-locked, deployment target
15.0. Adds Riverpod, Drift, and intl.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Tone enum and strings

**Files:**
- Create: `lib/core/tone.dart`, `lib/core/strings.dart`
- Test: `test/core/tone_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum Tone { focus, life, inbox }` with `int get dbIndex`, `String get label`, and `static Tone fromDbIndex(int index)` which throws `ArgumentError` on an unknown index.
  - `abstract final class Strings` with static `const String` members. Every later task adds its copy here rather than inlining literals.

- [ ] **Step 1: Write the failing test**

`test/core/tone_test.dart`:

```dart
import 'package:energy_clock/core/tone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('db indices are stable', () {
    expect(Tone.focus.dbIndex, 0);
    expect(Tone.life.dbIndex, 1);
    expect(Tone.inbox.dbIndex, 2);
  });

  test('labels are the English tone names', () {
    expect(Tone.focus.label, 'Focus');
    expect(Tone.life.label, 'Life');
    expect(Tone.inbox.label, 'Inbox');
  });

  test('fromDbIndex round-trips every tone', () {
    for (final tone in Tone.values) {
      expect(Tone.fromDbIndex(tone.dbIndex), tone);
    }
  });

  test('fromDbIndex rejects an unknown index', () {
    expect(() => Tone.fromDbIndex(7), throwsArgumentError);
  });

  test('there are exactly three tones', () {
    expect(Tone.values.length, 3);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/tone_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:energy_clock/core/tone.dart'`

- [ ] **Step 3: Write minimal implementation**

`lib/core/tone.dart`:

```dart
/// The three fixed tones. This set never changes — it is a product decision,
/// and statistics, scoring, and badges all depend on it being closed.
enum Tone {
  focus(0, 'Focus'),
  life(1, 'Life'),
  inbox(2, 'Inbox');

  const Tone(this.dbIndex, this.label);

  /// Stable integer persisted in the database. Never reorder these.
  final int dbIndex;

  /// English display name.
  final String label;

  static Tone fromDbIndex(int index) {
    for (final tone in Tone.values) {
      if (tone.dbIndex == index) return tone;
    }
    throw ArgumentError.value(index, 'index', 'Unknown tone index');
  }
}
```

`lib/core/strings.dart`:

```dart
/// All user-facing copy. English-only by design; centralised so that
/// localisation stays possible later without hunting through widgets.
abstract final class Strings {
  static const String appTitle = 'Energy Clock';

  static const String tabClock = 'Clock';
  static const String tabCalendar = 'Calendar';
  static const String tabStats = 'Stats';
  static const String tabProfile = 'Profile';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/tone_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/tone.dart lib/core/strings.dart test/core/tone_test.dart
git commit -m "feat: add fixed Tone enum and central strings file"
```

---

### Task 3: Time helpers

**Files:**
- Create: `lib/core/time/day_time.dart`
- Test: `test/core/time/day_time_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces (all top-level, in `lib/core/time/day_time.dart`):
  - `const int minutesPerDay = 1440;`
  - `const int minEventMinutes = 15;`
  - `const int snapStepMinutes = 5;`
  - `DateTime startOfDay(DateTime dateTime)` — local midnight of that date.
  - `int minuteOfDay(DateTime dateTime)` — 0–1439 in local time.
  - `String formatMinuteOfDay(int minute)` — `'HH:mm'`; 1440 renders as `'24:00'`.
  - `String formatMinuteRange(int startMinute, int endMinute)` — `'09:00 – 12:00'` using an en dash.
  - `String formatDurationMinutes(int minutes)` — `'1h 30m'`, `'45m'`, `'2h'`.
  - `bool isPastDay(DateTime day, {DateTime? now})` — true when `day` is strictly before today.

- [ ] **Step 1: Write the failing test**

`test/core/time/day_time_test.dart`:

```dart
import 'package:energy_clock/core/time/day_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startOfDay strips the time component', () {
    final result = startOfDay(DateTime(2026, 8, 23, 14, 37, 12));
    expect(result, DateTime(2026, 8, 23));
  });

  test('minuteOfDay counts minutes since local midnight', () {
    expect(minuteOfDay(DateTime(2026, 8, 23, 0, 0)), 0);
    expect(minuteOfDay(DateTime(2026, 8, 23, 9, 30)), 570);
    expect(minuteOfDay(DateTime(2026, 8, 23, 23, 59)), 1439);
  });

  test('formatMinuteOfDay zero-pads and renders end-of-day as 24:00', () {
    expect(formatMinuteOfDay(0), '00:00');
    expect(formatMinuteOfDay(540), '09:00');
    expect(formatMinuteOfDay(1439), '23:59');
    expect(formatMinuteOfDay(1440), '24:00');
  });

  test('formatMinuteRange joins with an en dash', () {
    expect(formatMinuteRange(540, 720), '09:00 – 12:00');
  });

  test('formatDurationMinutes drops empty units', () {
    expect(formatDurationMinutes(45), '45m');
    expect(formatDurationMinutes(90), '1h 30m');
    expect(formatDurationMinutes(120), '2h');
  });

  test('isPastDay is false for today and true for yesterday', () {
    final now = DateTime(2026, 8, 23, 10, 0);
    expect(isPastDay(DateTime(2026, 8, 23), now: now), isFalse);
    expect(isPastDay(DateTime(2026, 8, 24), now: now), isFalse);
    expect(isPastDay(DateTime(2026, 8, 22), now: now), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/time/day_time_test.dart`
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Write minimal implementation**

`lib/core/time/day_time.dart`:

```dart
/// Minutes in one day. One full rotation of the dial.
const int minutesPerDay = 1440;

/// Shortest event the dial allows.
const int minEventMinutes = 15;

/// Drag snapping granularity.
const int snapStepMinutes = 5;

/// Local midnight of [dateTime]'s calendar date.
DateTime startOfDay(DateTime dateTime) =>
    DateTime(dateTime.year, dateTime.month, dateTime.day);

/// Minutes elapsed since local midnight, 0–1439.
int minuteOfDay(DateTime dateTime) => dateTime.hour * 60 + dateTime.minute;

/// Formats a minute-of-day as `HH:mm`. The exclusive end-of-day value 1440
/// renders as `24:00` rather than wrapping to `00:00`.
String formatMinuteOfDay(int minute) {
  final hour = minute ~/ 60;
  final minutes = minute % 60;
  return '${hour.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}';
}

String formatMinuteRange(int startMinute, int endMinute) =>
    '${formatMinuteOfDay(startMinute)} – ${formatMinuteOfDay(endMinute)}';

String formatDurationMinutes(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0) return '${remainder}m';
  if (remainder == 0) return '${hours}h';
  return '${hours}h ${remainder}m';
}

/// True when [day] falls strictly before today. Past days are read-only.
bool isPastDay(DateTime day, {DateTime? now}) {
  final today = startOfDay(now ?? DateTime.now());
  return startOfDay(day).isBefore(today);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/time/day_time_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/time/day_time.dart test/core/time/day_time_test.dart
git commit -m "feat: add day and minute-of-day time helpers"
```

---

### Task 4: DialGeometry — angles and minutes

**Files:**
- Create: `lib/core/geometry/dial_geometry.dart`
- Test: `test/core/geometry/dial_geometry_test.dart`

**Interfaces:**
- Consumes: `minutesPerDay` from `lib/core/time/day_time.dart`.
- Produces: `class DialGeometry` with a const constructor taking named `Offset center`, `double faceRadius`, `double firstRingInset`, `double ringWidth`, `double ringGap`. Methods added here:
  - `double angleForMinute(double minute)` — radians, minute 0 at `-pi/2`, increasing clockwise.
  - `int minuteForAngle(double angle)` — inverse, normalised into 0–1439.
  - `int minuteAtPoint(Offset point)` — 0–1439.
  - `double radiusAtPoint(Offset point)` — distance from `center`.
  - `static const int maxRings = 3;`

- [ ] **Step 1: Write the failing test**

`test/core/geometry/dial_geometry_test.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:energy_clock/core/geometry/dial_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

const geometry = DialGeometry(
  center: Offset(100, 100),
  faceRadius: 100,
  firstRingInset: 8,
  ringWidth: 20,
  ringGap: 4,
);

void main() {
  test('midnight points straight up', () {
    expect(geometry.angleForMinute(0), closeTo(-math.pi / 2, 1e-9));
  });

  test('angles advance clockwise through the day', () {
    expect(geometry.angleForMinute(360), closeTo(0, 1e-9));
    expect(geometry.angleForMinute(720), closeTo(math.pi / 2, 1e-9));
    expect(geometry.angleForMinute(1080), closeTo(math.pi, 1e-9));
  });

  test('minuteForAngle inverts angleForMinute', () {
    for (final minute in [0, 5, 375, 720, 1080, 1435]) {
      final angle = geometry.angleForMinute(minute.toDouble());
      expect(geometry.minuteForAngle(angle), minute);
    }
  });

  test('minuteForAngle normalises angles outside one rotation', () {
    final wrapped = geometry.angleForMinute(360) + 2 * math.pi;
    expect(geometry.minuteForAngle(wrapped), 360);
  });

  test('minuteAtPoint reads the compass points of the dial', () {
    expect(geometry.minuteAtPoint(const Offset(100, 0)), 0);
    expect(geometry.minuteAtPoint(const Offset(200, 100)), 360);
    expect(geometry.minuteAtPoint(const Offset(100, 200)), 720);
    expect(geometry.minuteAtPoint(const Offset(0, 100)), 1080);
  });

  test('radiusAtPoint measures distance from the centre', () {
    expect(geometry.radiusAtPoint(const Offset(100, 100)), 0);
    expect(geometry.radiusAtPoint(const Offset(160, 180)), closeTo(100, 1e-9));
  });

  test('there are at most three rings', () {
    expect(DialGeometry.maxRings, 3);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/geometry/dial_geometry_test.dart`
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Write minimal implementation**

`lib/core/geometry/dial_geometry.dart`:

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
  });

  /// Overlapping events beyond this many rings are refused.
  static const int maxRings = 3;

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
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/geometry/dial_geometry_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/geometry/dial_geometry.dart test/core/geometry/dial_geometry_test.dart
git commit -m "feat: add dial angle and minute conversion math"
```

---

### Task 5: DialGeometry — ring radii and hit testing

**Files:**
- Modify: `lib/core/geometry/dial_geometry.dart`
- Modify: `test/core/geometry/dial_geometry_test.dart`

**Interfaces:**
- Consumes: `DialGeometry` from Task 4.
- Produces, added to `DialGeometry`:
  - `double ringCenterRadius(int index)` — centreline radius of ring `index`.
  - `double get orbitInnerRadius` — inner edge of ring 0.
  - `double get orbitOuterRadius` — outer edge of the last ring.
  - `int? ringAtPoint(Offset point)` — ring index containing the point, or null when the point falls in a gap or outside every ring.
  - `bool isInOrbitBand(Offset point)` — true anywhere between the face edge and the outer edge, gaps included. This is the drag-to-create target area.

With the test geometry (face 100, inset 8, width 20, gap 4): ring centres are 118, 142, 166; `orbitInnerRadius` is 108; `orbitOuterRadius` is 176.

- [ ] **Step 1: Write the failing test**

Append to `test/core/geometry/dial_geometry_test.dart`, inside `main()`:

```dart
  test('ring centres step outward by width plus gap', () {
    expect(geometry.ringCenterRadius(0), 118);
    expect(geometry.ringCenterRadius(1), 142);
    expect(geometry.ringCenterRadius(2), 166);
  });

  test('orbit band spans the face edge to the outer ring edge', () {
    expect(geometry.orbitInnerRadius, 108);
    expect(geometry.orbitOuterRadius, 176);
  });

  test('ringAtPoint finds the ring under a point', () {
    expect(geometry.ringAtPoint(const Offset(100, 100 - 118)), 0);
    expect(geometry.ringAtPoint(const Offset(100, 100 - 142)), 1);
    expect(geometry.ringAtPoint(const Offset(100, 100 - 166)), 2);
  });

  test('ringAtPoint returns null in gaps and outside the band', () {
    expect(geometry.ringAtPoint(const Offset(100, 100 - 130)), isNull);
    expect(geometry.ringAtPoint(const Offset(100, 100 - 50)), isNull);
    expect(geometry.ringAtPoint(const Offset(100, 100 - 200)), isNull);
  });

  test('isInOrbitBand includes gaps but excludes face and beyond', () {
    expect(geometry.isInOrbitBand(const Offset(100, 100 - 130)), isTrue);
    expect(geometry.isInOrbitBand(const Offset(100, 100 - 108)), isTrue);
    expect(geometry.isInOrbitBand(const Offset(100, 100 - 176)), isTrue);
    expect(geometry.isInOrbitBand(const Offset(100, 100 - 90)), isFalse);
    expect(geometry.isInOrbitBand(const Offset(100, 100 - 200)), isFalse);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/geometry/dial_geometry_test.dart`
Expected: FAIL — `The method 'ringCenterRadius' isn't defined for the type 'DialGeometry'`

- [ ] **Step 3: Write minimal implementation**

Add to `DialGeometry` in `lib/core/geometry/dial_geometry.dart`:

```dart
  /// Inner edge of ring 0.
  double get orbitInnerRadius => faceRadius + firstRingInset;

  /// Outer edge of the outermost ring.
  double get orbitOuterRadius =>
      ringCenterRadius(maxRings - 1) + ringWidth / 2;

  /// Centreline radius of ring [index], counting outward from 0.
  double ringCenterRadius(int index) =>
      orbitInnerRadius + ringWidth / 2 + index * (ringWidth + ringGap);

  /// The ring containing [point], or null when it falls in a gap between
  /// rings or outside the band entirely.
  int? ringAtPoint(Offset point) {
    final radius = radiusAtPoint(point);
    for (var index = 0; index < maxRings; index++) {
      if ((radius - ringCenterRadius(index)).abs() <= ringWidth / 2) {
        return index;
      }
    }
    return null;
  }

  /// True anywhere in the orbit band, gaps included. This is the area that
  /// accepts a drag-to-create gesture.
  bool isInOrbitBand(Offset point) {
    final radius = radiusAtPoint(point);
    return radius >= orbitInnerRadius && radius <= orbitOuterRadius;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/geometry/dial_geometry_test.dart`
Expected: PASS, 12 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/geometry/dial_geometry.dart test/core/geometry/dial_geometry_test.dart
git commit -m "feat: add ring radii and orbit hit testing to DialGeometry"
```

---

### Task 6: Minute ranges, drag snapping, and grab kinds

**Files:**
- Create: `lib/core/geometry/minute_range.dart`
- Test: `test/core/geometry/minute_range_test.dart`

**Interfaces:**
- Consumes: `minutesPerDay`, `minEventMinutes`, `snapStepMinutes` from `lib/core/time/day_time.dart`.
- Produces:
  - `class MinuteRange` — immutable, `final int start`, `final int end`, `int get durationMinutes`, `bool overlaps(MinuteRange other)`, value equality and `toString`.
  - `int snapMinute(int minute)` — nearest 5-minute boundary, clamped 0–1440.
  - `double unwrapMinute(double previousContinuous, int wrappedMinute)` — lifts a wrapped 0–1439 sample onto the continuous line nearest the previous sample, so a drag near midnight does not jump a whole day.
  - `MinuteRange rangeFromDrag({required int anchorMinute, required double currentMinute})` — snaps, orders, enforces the 15-minute minimum, and clamps at 1440.
  - `enum ArcGrabKind { move, resizeStart, resizeEnd }`
  - `ArcGrabKind grabKindFor({required MinuteRange range, required int touchMinute, int edgeMinutes = 10})`

**Why unwrapping exists:** a raw `minuteAtPoint` sample is always 0–1439, so dragging clockwise from 23:00 past the top of the dial would report minute 10 and turn a 90-minute drag into a 22-hour one. Tracking the continuous value lets the clamp at 1440 do the right thing.

- [ ] **Step 1: Write the failing test**

`test/core/geometry/minute_range_test.dart`:

```dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MinuteRange', () {
    test('duration is end minus start', () {
      expect(const MinuteRange(540, 720).durationMinutes, 180);
    });

    test('touching ranges do not overlap because end is exclusive', () {
      expect(
        const MinuteRange(540, 600).overlaps(const MinuteRange(600, 660)),
        isFalse,
      );
    });

    test('ranges sharing any interior minute overlap', () {
      expect(
        const MinuteRange(540, 720).overlaps(const MinuteRange(600, 660)),
        isTrue,
      );
    });

    test('equal ranges compare equal', () {
      expect(const MinuteRange(540, 720), const MinuteRange(540, 720));
    });
  });

  group('snapMinute', () {
    test('rounds to the nearest five minutes', () {
      expect(snapMinute(542), 540);
      expect(snapMinute(543), 545);
    });

    test('clamps to the day', () {
      expect(snapMinute(-10), 0);
      expect(snapMinute(1500), 1440);
    });
  });

  group('unwrapMinute', () {
    test('keeps a nearby sample untouched', () {
      expect(unwrapMinute(540, 545), 545);
    });

    test('lifts a sample that wrapped past midnight', () {
      expect(unwrapMinute(1430, 10), 1450);
    });

    test('drops a sample that wrapped backwards past midnight', () {
      expect(unwrapMinute(10, 1430), -10);
    });
  });

  group('rangeFromDrag', () {
    test('snaps both ends to five minutes', () {
      expect(
        rangeFromDrag(anchorMinute: 541, currentMinute: 722),
        const MinuteRange(540, 720),
      );
    });

    test('handles a backwards drag by ordering the ends', () {
      expect(
        rangeFromDrag(anchorMinute: 720, currentMinute: 600),
        const MinuteRange(600, 720),
      );
    });

    test('enforces the fifteen minute minimum', () {
      expect(
        rangeFromDrag(anchorMinute: 540, currentMinute: 543),
        const MinuteRange(540, 555),
      );
    });

    test('clamps at end of day and backs the start off to fit', () {
      expect(
        rangeFromDrag(anchorMinute: 1430, currentMinute: 1500),
        const MinuteRange(1425, 1440),
      );
    });

    test('a drag wrapping past midnight clamps rather than inverting', () {
      expect(
        rangeFromDrag(anchorMinute: 1380, currentMinute: 1450),
        const MinuteRange(1380, 1440),
      );
    });
  });

  group('grabKindFor', () {
    const range = MinuteRange(540, 720);

    test('near the start edge resizes the start', () {
      expect(
        grabKindFor(range: range, touchMinute: 545),
        ArcGrabKind.resizeStart,
      );
    });

    test('near the end edge resizes the end', () {
      expect(
        grabKindFor(range: range, touchMinute: 715),
        ArcGrabKind.resizeEnd,
      );
    });

    test('in the middle moves the whole event', () {
      expect(grabKindFor(range: range, touchMinute: 620), ArcGrabKind.move);
    });

    test('a short event always moves rather than resizes', () {
      expect(
        grabKindFor(range: const MinuteRange(540, 555), touchMinute: 541),
        ArcGrabKind.move,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/geometry/minute_range_test.dart`
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Write minimal implementation**

`lib/core/geometry/minute_range.dart`:

```dart
import 'dart:math' as math;

import 'package:energy_clock/core/time/day_time.dart';

/// A half-open span of minutes within a single day: [start, end).
class MinuteRange {
  const MinuteRange(this.start, this.end);

  final int start;
  final int end;

  int get durationMinutes => end - start;

  /// True when the two ranges share at least one interior minute. Ranges that
  /// merely touch — one ending exactly where the next begins — do not overlap.
  bool overlaps(MinuteRange other) => start < other.end && other.start < end;

  @override
  bool operator ==(Object other) =>
      other is MinuteRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'MinuteRange($start, $end)';
}

/// Rounds to the nearest snap step and clamps into the day.
int snapMinute(int minute) {
  final snapped = (minute / snapStepMinutes).round() * snapStepMinutes;
  return snapped.clamp(0, minutesPerDay);
}

/// Lifts a wrapped 0–1439 sample onto the continuous minute line closest to
/// [previousContinuous], so a gesture crossing the top of the dial reads as a
/// small step rather than a jump of nearly a full day.
double unwrapMinute(double previousContinuous, int wrappedMinute) {
  var best = wrappedMinute.toDouble();
  var bestDistance = (best - previousContinuous).abs();
  for (final shift in const [-minutesPerDay, minutesPerDay]) {
    final candidate = wrappedMinute + shift.toDouble();
    final distance = (candidate - previousContinuous).abs();
    if (distance < bestDistance) {
      best = candidate;
      bestDistance = distance;
    }
  }
  return best;
}

/// Builds a valid event range from a drag. Snaps both ends, orders them so a
/// backwards drag still produces a forward range, enforces the minimum
/// duration, and clamps at the end of the day — cross-midnight events are not
/// allowed.
MinuteRange rangeFromDrag({
  required int anchorMinute,
  required double currentMinute,
}) {
  final anchor = snapMinute(anchorMinute);
  final current = snapMinute(currentMinute.round());

  var start = math.min(anchor, current);
  var end = math.max(anchor, current);

  if (end - start < minEventMinutes) {
    end = start + minEventMinutes;
  }
  if (end > minutesPerDay) {
    end = minutesPerDay;
    start = math.min(start, minutesPerDay - minEventMinutes);
  }
  return MinuteRange(start, end);
}

/// Which part of an existing arc a touch grabs.
enum ArcGrabKind { move, resizeStart, resizeEnd }

/// Classifies a touch on an arc. Touches within [edgeMinutes] of either end
/// resize that end; anything else moves the whole event. Events too short to
/// have a distinct middle always move, so a small arc never becomes
/// impossible to drag.
ArcGrabKind grabKindFor({
  required MinuteRange range,
  required int touchMinute,
  int edgeMinutes = 10,
}) {
  if (range.durationMinutes < edgeMinutes * 2) return ArcGrabKind.move;
  if (touchMinute - range.start <= edgeMinutes) return ArcGrabKind.resizeStart;
  if (range.end - touchMinute <= edgeMinutes) return ArcGrabKind.resizeEnd;
  return ArcGrabKind.move;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/geometry/minute_range_test.dart`
Expected: PASS, 17 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/geometry/minute_range.dart test/core/geometry/minute_range_test.dart
git commit -m "feat: add minute ranges, drag snapping, and arc grab classification"
```

---

### Task 7: Ring layout assignment

**Files:**
- Create: `lib/core/geometry/ring_layout.dart`
- Test: `test/core/geometry/ring_layout_test.dart`

**Interfaces:**
- Consumes: `DialGeometry.maxRings`, `MinuteRange`.
- Produces:
  - `class RingCandidate` — `final int id`, `final MinuteRange range`, const constructor `RingCandidate(this.id, this.range)`.
  - `class RingAssignment` — `final Map<int, int> ringByEventId`, `final List<int> overflowEventIds`.
  - `RingAssignment assignRings(List<RingCandidate> candidates)` — greedy innermost-free-ring assignment, processing candidates in ascending start order with id as tiebreak.
  - `bool wouldOverflowRings({required List<MinuteRange> existing, required MinuteRange candidate})` — used to refuse a fourth overlapping event before it is written.

- [ ] **Step 1: Write the failing test**

`test/core/geometry/ring_layout_test.dart`:

```dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/geometry/ring_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('non-overlapping events all sit on the innermost ring', () {
    final result = assignRings(const [
      RingCandidate(1, MinuteRange(540, 600)),
      RingCandidate(2, MinuteRange(600, 660)),
    ]);
    expect(result.ringByEventId, {1: 0, 2: 0});
    expect(result.overflowEventIds, isEmpty);
  });

  test('each overlap pushes one ring outward', () {
    final result = assignRings(const [
      RingCandidate(1, MinuteRange(540, 720)),
      RingCandidate(2, MinuteRange(600, 660)),
      RingCandidate(3, MinuteRange(610, 620)),
    ]);
    expect(result.ringByEventId, {1: 0, 2: 1, 3: 2});
    expect(result.overflowEventIds, isEmpty);
  });

  test('a fourth simultaneous event overflows', () {
    final result = assignRings(const [
      RingCandidate(1, MinuteRange(540, 720)),
      RingCandidate(2, MinuteRange(600, 660)),
      RingCandidate(3, MinuteRange(610, 620)),
      RingCandidate(4, MinuteRange(615, 618)),
    ]);
    expect(result.ringByEventId[4], isNull);
    expect(result.overflowEventIds, [4]);
  });

  test('a freed ring is reused by a later event', () {
    final result = assignRings(const [
      RingCandidate(1, MinuteRange(540, 720)),
      RingCandidate(2, MinuteRange(600, 660)),
      RingCandidate(3, MinuteRange(660, 700)),
    ]);
    expect(result.ringByEventId, {1: 0, 2: 1, 3: 1});
  });

  test('input order does not affect the result', () {
    final result = assignRings(const [
      RingCandidate(3, MinuteRange(610, 620)),
      RingCandidate(1, MinuteRange(540, 720)),
      RingCandidate(2, MinuteRange(600, 660)),
    ]);
    expect(result.ringByEventId, {1: 0, 2: 1, 3: 2});
  });

  test('wouldOverflowRings refuses a fourth overlapping event', () {
    expect(
      wouldOverflowRings(
        existing: const [
          MinuteRange(540, 720),
          MinuteRange(600, 660),
          MinuteRange(610, 620),
        ],
        candidate: const MinuteRange(615, 618),
      ),
      isTrue,
    );
  });

  test('wouldOverflowRings allows a third overlapping event', () {
    expect(
      wouldOverflowRings(
        existing: const [MinuteRange(540, 720), MinuteRange(600, 660)],
        candidate: const MinuteRange(610, 620),
      ),
      isFalse,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/geometry/ring_layout_test.dart`
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Write minimal implementation**

`lib/core/geometry/ring_layout.dart`:

```dart
import 'package:energy_clock/core/geometry/dial_geometry.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';

/// An event reduced to what ring assignment needs.
class RingCandidate {
  const RingCandidate(this.id, this.range);

  final int id;
  final MinuteRange range;
}

/// The result of laying out one day's events across the rings.
class RingAssignment {
  const RingAssignment(this.ringByEventId, this.overflowEventIds);

  /// Event id to ring index, counting outward from 0.
  final Map<int, int> ringByEventId;

  /// Events that would have needed a ring beyond [DialGeometry.maxRings].
  /// These are not drawn.
  final List<int> overflowEventIds;
}

/// Assigns each event the innermost ring free at its start time. Ring
/// assignment is always computed, never stored — storing it would let the
/// database drift out of sync with what is actually drawable.
RingAssignment assignRings(List<RingCandidate> candidates) {
  final sorted = [...candidates]..sort((a, b) {
      final byStart = a.range.start.compareTo(b.range.start);
      return byStart != 0 ? byStart : a.id.compareTo(b.id);
    });

  // Last occupied minute per ring; -1 means the ring has never been used.
  final ringEnd = List<int>.filled(DialGeometry.maxRings, -1);
  final ringByEventId = <int, int>{};
  final overflow = <int>[];

  for (final candidate in sorted) {
    var placed = false;
    for (var ring = 0; ring < DialGeometry.maxRings; ring++) {
      if (ringEnd[ring] <= candidate.range.start) {
        ringByEventId[candidate.id] = ring;
        ringEnd[ring] = candidate.range.end;
        placed = true;
        break;
      }
    }
    if (!placed) overflow.add(candidate.id);
  }

  return RingAssignment(ringByEventId, overflow);
}

/// True when adding [candidate] to [existing] would require a fourth ring.
/// Checked before writing, so the refusal happens at drag release rather than
/// silently dropping the event at render time.
bool wouldOverflowRings({
  required List<MinuteRange> existing,
  required MinuteRange candidate,
}) {
  final candidates = <RingCandidate>[
    for (var index = 0; index < existing.length; index++)
      RingCandidate(index, existing[index]),
    RingCandidate(existing.length, candidate),
  ];
  return assignRings(candidates).overflowEventIds.isNotEmpty;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/geometry/ring_layout_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/geometry/ring_layout.dart test/core/geometry/ring_layout_test.dart
git commit -m "feat: add innermost-free-ring layout with overflow detection"
```

---

### Task 8: Drift schema and event DAO

**Files:**
- Create: `lib/data/tables/events_table.dart`, `lib/data/tables/event_series_table.dart`, `lib/data/tables/settings_table.dart`, `lib/data/database.dart`, `lib/data/daos/event_dao.dart`
- Test: `test/data/event_dao_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - Drift row classes `EventRow`, `EventSeriesRow`, `SettingRow`, and companions `EventsCompanion`, `EventSeriesCompanion`, `AppSettingsCompanion`.
  - `class AppDatabase` with `AppDatabase()` (on-device) and `AppDatabase.forTesting(QueryExecutor executor)`, `int get schemaVersion => 1`, and `EventDao get eventDao`.
  - `class EventDao` with:
    - `Stream<List<EventRow>> watchDay(DateTime day)`
    - `Future<List<EventRow>> eventsForDay(DateTime day)`
    - `Future<int> insertEvent(EventsCompanion entry)`
    - `Future<void> updateTimes({required int id, required int startMinute, required int endMinute, required DateTime updatedAt})`
    - `Future<void> updateDetails({required int id, required String title, required int toneIndex, required DateTime updatedAt})`
    - `Future<void> deleteById(int id)`

`EventSeries` and `AppSettings` are created now so schema v1 is complete, but nothing reads them in Phase 1.

- [ ] **Step 1: Write the table definitions**

`lib/data/tables/events_table.dart`:

```dart
import 'package:drift/drift.dart';

/// Concrete event occurrences. One row per event per date. Recurring series
/// are materialised into rows here, so nothing downstream contains
/// recurrence logic.
@DataClassName('EventRow')
class Events extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Null for one-off events; set when materialised from an [EventSeries].
  IntColumn get seriesId => integer().nullable()();

  /// Local midnight of the day this event belongs to.
  DateTimeColumn get date => dateTime()();

  TextColumn get title => text().withLength(min: 1, max: 120)();

  IntColumn get toneIndex => integer()();

  /// 0–1439.
  IntColumn get startMinute => integer()();

  /// 1–1440, exclusive. Never crosses midnight.
  IntColumn get endMinute => integer()();

  /// 0 planned, 1 completed, 2 skipped.
  IntColumn get status => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
```

`lib/data/tables/event_series_table.dart`:

```dart
import 'package:drift/drift.dart';

/// Recurrence rules. Written in Phase 3; the table exists from schema v1 so
/// that adding recurrence later needs no migration.
@DataClassName('EventSeriesRow')
class EventSeries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  IntColumn get toneIndex => integer()();
  IntColumn get startMinute => integer()();
  IntColumn get endMinute => integer()();

  /// 0 none, 1 daily, 2 weekdays, 3 custom mask.
  IntColumn get recurrenceKind => integer()();

  /// Seven-bit mask, Monday is bit 0.
  IntColumn get weekdayMask => integer().withDefault(const Constant(0))();

  DateTimeColumn get validFrom => dateTime()();
  DateTimeColumn get validUntil => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}
```

`lib/data/tables/settings_table.dart`:

```dart
import 'package:drift/drift.dart';

/// Key/value user settings.
@DataClassName('SettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
```

- [ ] **Step 2: Write the database and DAO**

`lib/data/database.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:energy_clock/data/daos/event_dao.dart';
import 'package:energy_clock/data/tables/event_series_table.dart';
import 'package:energy_clock/data/tables/events_table.dart';
import 'package:energy_clock/data/tables/settings_table.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Events, EventSeries, AppSettings], daos: [EventDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'energy_clock'));

  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;
}
```

`lib/data/daos/event_dao.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/tables/events_table.dart';

part 'event_dao.g.dart';

@DriftAccessor(tables: [Events])
class EventDao extends DatabaseAccessor<AppDatabase> with _$EventDaoMixin {
  EventDao(super.attachedDatabase);

  SimpleSelectStatement<$EventsTable, EventRow> _dayQuery(DateTime day) =>
      select(events)
        ..where((row) => row.date.equals(day))
        ..orderBy([
          (row) => OrderingTerm(expression: row.startMinute),
          (row) => OrderingTerm(expression: row.id),
        ]);

  Stream<List<EventRow>> watchDay(DateTime day) => _dayQuery(day).watch();

  Future<List<EventRow>> eventsForDay(DateTime day) => _dayQuery(day).get();

  Future<int> insertEvent(EventsCompanion entry) =>
      into(events).insert(entry);

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

  Future<void> deleteById(int id) =>
      (delete(events)..where((row) => row.id.equals(id))).go();
}
```

- [ ] **Step 3: Generate the Drift code**

```bash
dart run build_runner build --delete-conflicting-outputs
```
Expected: `database.g.dart` and `event_dao.g.dart` are written with no errors.

- [ ] **Step 4: Write the failing test**

`test/data/event_dao_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:energy_clock/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  final day = DateTime(2026, 8, 23);
  final otherDay = DateTime(2026, 8, 24);
  final now = DateTime(2026, 8, 23, 9, 0);

  EventsCompanion entry({
    required DateTime date,
    required String title,
    required int startMinute,
    required int endMinute,
    int toneIndex = 0,
  }) {
    return EventsCompanion.insert(
      date: date,
      title: title,
      toneIndex: toneIndex,
      startMinute: startMinute,
      endMinute: endMinute,
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

  test('inserted events come back for their own day only', () async {
    await db.eventDao.insertEvent(
      entry(date: day, title: 'Deep work', startMinute: 540, endMinute: 720),
    );
    await db.eventDao.insertEvent(
      entry(date: otherDay, title: 'Gym', startMinute: 400, endMinute: 460),
    );

    final result = await db.eventDao.eventsForDay(day);
    expect(result, hasLength(1));
    expect(result.single.title, 'Deep work');
  });

  test('events for a day are ordered by start minute', () async {
    await db.eventDao.insertEvent(
      entry(date: day, title: 'Lunch', startMinute: 780, endMinute: 840),
    );
    await db.eventDao.insertEvent(
      entry(date: day, title: 'Deep work', startMinute: 540, endMinute: 720),
    );

    final result = await db.eventDao.eventsForDay(day);
    expect(result.map((row) => row.title), ['Deep work', 'Lunch']);
  });

  test('status defaults to planned', () async {
    await db.eventDao.insertEvent(
      entry(date: day, title: 'Deep work', startMinute: 540, endMinute: 720),
    );
    final result = await db.eventDao.eventsForDay(day);
    expect(result.single.status, 0);
  });

  test('updateTimes moves an event', () async {
    final id = await db.eventDao.insertEvent(
      entry(date: day, title: 'Deep work', startMinute: 540, endMinute: 720),
    );
    await db.eventDao.updateTimes(
      id: id,
      startMinute: 600,
      endMinute: 780,
      updatedAt: DateTime(2026, 8, 23, 10, 0),
    );

    final row = (await db.eventDao.eventsForDay(day)).single;
    expect(row.startMinute, 600);
    expect(row.endMinute, 780);
  });

  test('updateDetails changes title and tone', () async {
    final id = await db.eventDao.insertEvent(
      entry(date: day, title: 'Deep work', startMinute: 540, endMinute: 720),
    );
    await db.eventDao.updateDetails(
      id: id,
      title: 'Email',
      toneIndex: 2,
      updatedAt: DateTime(2026, 8, 23, 10, 0),
    );

    final row = (await db.eventDao.eventsForDay(day)).single;
    expect(row.title, 'Email');
    expect(row.toneIndex, 2);
  });

  test('deleteById removes the event', () async {
    final id = await db.eventDao.insertEvent(
      entry(date: day, title: 'Deep work', startMinute: 540, endMinute: 720),
    );
    await db.eventDao.deleteById(id);
    expect(await db.eventDao.eventsForDay(day), isEmpty);
  });

  test('watchDay emits again when the day changes', () async {
    final emissions = db.eventDao.watchDay(day);
    final future = emissions.take(2).toList();

    await db.eventDao.insertEvent(
      entry(date: day, title: 'Deep work', startMinute: 540, endMinute: 720),
    );

    final batches = await future;
    expect(batches.first, isEmpty);
    expect(batches.last, hasLength(1));
  });
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/data/event_dao_test.dart`
Expected: PASS, 7 tests.

If `NativeDatabase.memory()` cannot find sqlite3, add the dependency explicitly and re-run:

```bash
flutter pub add sqlite3
```

- [ ] **Step 6: Commit**

```bash
git add lib/data test/data/event_dao_test.dart pubspec.yaml pubspec.lock
git commit -m "feat: add Drift schema v1 and event DAO"
```

---

### Task 9: Event model, repository, and providers

**Files:**
- Create: `lib/features/clock/model/calendar_event.dart`, `lib/features/clock/data/event_repository.dart`, `lib/features/clock/providers.dart`
- Test: `test/features/clock/event_repository_test.dart`

**Interfaces:**
- Consumes: `EventDao`, `EventRow`, `EventsCompanion`, `AppDatabase` (Task 8); `Tone` (Task 2); `MinuteRange` (Task 6); `wouldOverflowRings` (Task 7); `startOfDay` (Task 3).
- Produces:
  - `enum EventStatus { planned, completed, skipped }` with `int get dbIndex` and `static EventStatus fromDbIndex(int)`.
  - `class CalendarEvent` — `int id`, `int? seriesId`, `DateTime date`, `String title`, `Tone tone`, `MinuteRange range`, `EventStatus status`; `int get startMinute`, `int get endMinute`; `static CalendarEvent fromRow(EventRow row)`.
  - `class RingOverflowException implements Exception` — thrown when a write would need a fourth ring.
  - `abstract interface class EventRepository` with `Stream<List<CalendarEvent>> watchDay(DateTime day)`, `Future<List<CalendarEvent>> eventsForDay(DateTime day)`, `Future<int> createEvent({required DateTime day, required String title, required Tone tone, required MinuteRange range})`, `Future<void> moveEvent({required int id, required DateTime day, required MinuteRange range})`, `Future<void> updateDetails({required int id, required String title, required Tone tone})`, `Future<void> deleteEvent(int id)`.
  - `class DriftEventRepository implements EventRepository` — constructor `DriftEventRepository(this._dao, {DateTime Function()? clock})`.
  - Providers in `lib/features/clock/providers.dart`: `appDatabaseProvider`, `eventRepositoryProvider`, `selectedDateProvider` (a `NotifierProvider<SelectedDateNotifier, DateTime>` with `next()`, `previous()`, `today()`, `select(DateTime)`), `dayEventsProvider` (a `StreamProvider<List<CalendarEvent>>`).

- [ ] **Step 1: Write the failing test**

`test/features/clock/event_repository_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late EventRepository repository;

  final day = DateTime(2026, 8, 23);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftEventRepository(
      db.eventDao,
      clock: () => DateTime(2026, 8, 23, 9, 0),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('creating an event returns it as a domain object', () async {
    await repository.createEvent(
      day: day,
      title: 'Deep work',
      tone: Tone.focus,
      range: const MinuteRange(540, 720),
    );

    final events = await repository.eventsForDay(day);
    expect(events.single.title, 'Deep work');
    expect(events.single.tone, Tone.focus);
    expect(events.single.range, const MinuteRange(540, 720));
    expect(events.single.status, EventStatus.planned);
  });

  test('the day is normalised to local midnight', () async {
    await repository.createEvent(
      day: DateTime(2026, 8, 23, 17, 42),
      title: 'Deep work',
      tone: Tone.focus,
      range: const MinuteRange(540, 720),
    );
    expect(await repository.eventsForDay(day), hasLength(1));
  });

  test('three overlapping events are allowed', () async {
    await repository.createEvent(
      day: day,
      title: 'A',
      tone: Tone.focus,
      range: const MinuteRange(540, 720),
    );
    await repository.createEvent(
      day: day,
      title: 'B',
      tone: Tone.life,
      range: const MinuteRange(600, 660),
    );
    await repository.createEvent(
      day: day,
      title: 'C',
      tone: Tone.inbox,
      range: const MinuteRange(610, 620),
    );
    expect(await repository.eventsForDay(day), hasLength(3));
  });

  test('a fourth overlapping event is refused', () async {
    for (final range in const [
      MinuteRange(540, 720),
      MinuteRange(600, 660),
      MinuteRange(610, 620),
    ]) {
      await repository.createEvent(
        day: day,
        title: 'Event',
        tone: Tone.focus,
        range: range,
      );
    }

    expect(
      () => repository.createEvent(
        day: day,
        title: 'Fourth',
        tone: Tone.focus,
        range: const MinuteRange(615, 618),
      ),
      throwsA(isA<RingOverflowException>()),
    );
  });

  test('moving an event ignores its own old position when checking rings',
      () async {
    final id = await repository.createEvent(
      day: day,
      title: 'A',
      tone: Tone.focus,
      range: const MinuteRange(540, 600),
    );
    await repository.moveEvent(
      id: id,
      day: day,
      range: const MinuteRange(600, 660),
    );

    final event = (await repository.eventsForDay(day)).single;
    expect(event.range, const MinuteRange(600, 660));
  });

  test('updateDetails changes title and tone', () async {
    final id = await repository.createEvent(
      day: day,
      title: 'A',
      tone: Tone.focus,
      range: const MinuteRange(540, 600),
    );
    await repository.updateDetails(id: id, title: 'Email', tone: Tone.inbox);

    final event = (await repository.eventsForDay(day)).single;
    expect(event.title, 'Email');
    expect(event.tone, Tone.inbox);
  });

  test('deleting removes the event', () async {
    final id = await repository.createEvent(
      day: day,
      title: 'A',
      tone: Tone.focus,
      range: const MinuteRange(540, 600),
    );
    await repository.deleteEvent(id);
    expect(await repository.eventsForDay(day), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/clock/event_repository_test.dart`
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Write the domain model**

`lib/features/clock/model/calendar_event.dart`:

```dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';

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
}
```

- [ ] **Step 4: Write the repository**

`lib/features/clock/data/event_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/geometry/ring_layout.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/daos/event_dao.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';

export 'package:energy_clock/features/clock/model/calendar_event.dart';

/// Thrown when a write would require a fourth overlapping ring.
class RingOverflowException implements Exception {
  const RingOverflowException();
}

abstract interface class EventRepository {
  Stream<List<CalendarEvent>> watchDay(DateTime day);
  Future<List<CalendarEvent>> eventsForDay(DateTime day);

  /// Throws [RingOverflowException] if the new event would need a fourth ring.
  Future<int> createEvent({
    required DateTime day,
    required String title,
    required Tone tone,
    required MinuteRange range,
  });

  /// Throws [RingOverflowException] if the new position would need a fourth
  /// ring. The event's own current position is excluded from the check.
  Future<void> moveEvent({
    required int id,
    required DateTime day,
    required MinuteRange range,
  });

  Future<void> updateDetails({
    required int id,
    required String title,
    required Tone tone,
  });

  Future<void> deleteEvent(int id);
}

class DriftEventRepository implements EventRepository {
  DriftEventRepository(this._dao, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final EventDao _dao;
  final DateTime Function() _clock;

  @override
  Stream<List<CalendarEvent>> watchDay(DateTime day) => _dao
      .watchDay(startOfDay(day))
      .map((rows) => rows.map(CalendarEvent.fromRow).toList());

  @override
  Future<List<CalendarEvent>> eventsForDay(DateTime day) async {
    final rows = await _dao.eventsForDay(startOfDay(day));
    return rows.map(CalendarEvent.fromRow).toList();
  }

  @override
  Future<int> createEvent({
    required DateTime day,
    required String title,
    required Tone tone,
    required MinuteRange range,
  }) async {
    final normalisedDay = startOfDay(day);
    await _guardRings(day: normalisedDay, range: range);

    final now = _clock();
    return _dao.insertEvent(
      EventsCompanion.insert(
        date: normalisedDay,
        title: title,
        toneIndex: tone.dbIndex,
        startMinute: range.start,
        endMinute: range.end,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<void> moveEvent({
    required int id,
    required DateTime day,
    required MinuteRange range,
  }) async {
    final normalisedDay = startOfDay(day);
    await _guardRings(day: normalisedDay, range: range, excludingId: id);

    await _dao.updateTimes(
      id: id,
      startMinute: range.start,
      endMinute: range.end,
      updatedAt: _clock(),
    );
  }

  @override
  Future<void> updateDetails({
    required int id,
    required String title,
    required Tone tone,
  }) {
    return _dao.updateDetails(
      id: id,
      title: title,
      toneIndex: tone.dbIndex,
      updatedAt: _clock(),
    );
  }

  @override
  Future<void> deleteEvent(int id) => _dao.deleteById(id);

  Future<void> _guardRings({
    required DateTime day,
    required MinuteRange range,
    int? excludingId,
  }) async {
    final existing = await eventsForDay(day);
    final ranges = [
      for (final event in existing)
        if (event.id != excludingId) event.range,
    ];
    if (wouldOverflowRings(existing: ranges, candidate: range)) {
      throw const RingOverflowException();
    }
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/clock/event_repository_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 6: Write the providers**

`lib/features/clock/providers.dart`:

```dart
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return DriftEventRepository(ref.watch(appDatabaseProvider).eventDao);
});

/// The day the Clock tab is showing. Always local midnight.
class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => startOfDay(DateTime.now());

  void select(DateTime day) => state = startOfDay(day);
  void next() => state = state.add(const Duration(days: 1));
  void previous() => state = state.subtract(const Duration(days: 1));
  void today() => state = startOfDay(DateTime.now());
}

final selectedDateProvider =
    NotifierProvider<SelectedDateNotifier, DateTime>(SelectedDateNotifier.new);

final dayEventsProvider = StreamProvider<List<CalendarEvent>>((ref) {
  return ref
      .watch(eventRepositoryProvider)
      .watchDay(ref.watch(selectedDateProvider));
});
```

- [ ] **Step 7: Verify analysis is clean**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 8: Commit**

```bash
git add lib/features/clock test/features/clock
git commit -m "feat: add event domain model, repository, and Riverpod providers"
```

---

### Task 10: Theme, tone palette, and tab shell

**Files:**
- Create: `lib/app/theme/tone_colors.dart`, `lib/app/theme/app_theme.dart`, `lib/app/navigation/tab_scaffold.dart`, `lib/app/app.dart`, `lib/features/calendar/calendar_screen.dart`, `lib/features/stats/stats_screen.dart`, `lib/features/progress/profile_screen.dart`
- Modify: `lib/main.dart`, `lib/core/strings.dart`
- Test: `test/app/tone_colors_test.dart`, `test/app/tab_scaffold_test.dart`

**Interfaces:**
- Consumes: `Tone` (Task 2), `Strings` (Task 2).
- Produces:
  - `class ToneColors extends ThemeExtension<ToneColors>` — `Color fillFor(Tone tone)`, `Color labelFor(Tone tone)`, plus `ToneColors.light` and `ToneColors.dark` statics.
  - `extension ToneColorsContext on BuildContext` — `ToneColors get toneColors`, which throws a `StateError` with a clear message if the extension is missing.
  - `abstract final class AppTheme` — `static ThemeData get light`, `static ThemeData get dark`.
  - `class TabScaffold extends StatefulWidget` — the four-tab shell.
  - `class EnergyClockApp extends StatelessWidget` in `lib/app/app.dart`.

Palette follows the reference image: pastel arc fills with a dark same-family label colour.

| Tone | Light fill | Light label | Dark fill | Dark label |
|---|---|---|---|---|
| Focus | `#D8D2FF` | `#4B3FA8` | `#4A3F8F` | `#E4DEFF` |
| Life | `#C9EBD5` | `#1F6B3F` | `#24603D` | `#CDEBD9` |
| Inbox | `#FBE0B8` | `#8A5308` | `#7A4E10` | `#FBE4BC` |

- [ ] **Step 1: Write the failing tests**

`test/app/tone_colors_test.dart`:

```dart
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every tone has a distinct fill in both themes', () {
    for (final palette in [ToneColors.light, ToneColors.dark]) {
      final fills = Tone.values.map(palette.fillFor).toSet();
      expect(fills, hasLength(Tone.values.length));
    }
  });

  test('light and dark fills differ for every tone', () {
    for (final tone in Tone.values) {
      expect(ToneColors.light.fillFor(tone),
          isNot(ToneColors.dark.fillFor(tone)));
    }
  });

  test('focus fill matches the specified light palette value', () {
    expect(ToneColors.light.fillFor(Tone.focus), const Color(0xFFD8D2FF));
  });

  test('lerp returns a ToneColors', () {
    final result = ToneColors.light.lerp(ToneColors.dark, 0.5);
    expect(result, isA<ToneColors>());
  });
}
```

`test/app/tab_scaffold_test.dart`:

```dart
import 'package:energy_clock/app/app.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows four tabs and starts on Clock', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: EnergyClockApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text(Strings.tabClock), findsOneWidget);
    expect(find.text(Strings.tabCalendar), findsOneWidget);
    expect(find.text(Strings.tabStats), findsOneWidget);
    expect(find.text(Strings.tabProfile), findsOneWidget);

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 0);
  });

  testWidgets('tapping a tab switches the body', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: EnergyClockApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(Strings.tabStats));
    await tester.pumpAndSettle();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 2);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/app`
Expected: FAIL — URIs do not exist.

- [ ] **Step 3: Write the tone palette**

`lib/app/theme/tone_colors.dart`:

```dart
import 'package:energy_clock/core/tone.dart';
import 'package:flutter/material.dart';

/// Per-tone arc colours. Held in a theme extension rather than on [Tone]
/// itself so that light and dark palettes can differ while the tone identity
/// stays a pure domain concept.
@immutable
class ToneColors extends ThemeExtension<ToneColors> {
  const ToneColors({
    required this.focusFill,
    required this.focusLabel,
    required this.lifeFill,
    required this.lifeLabel,
    required this.inboxFill,
    required this.inboxLabel,
  });

  static const ToneColors light = ToneColors(
    focusFill: Color(0xFFD8D2FF),
    focusLabel: Color(0xFF4B3FA8),
    lifeFill: Color(0xFFC9EBD5),
    lifeLabel: Color(0xFF1F6B3F),
    inboxFill: Color(0xFFFBE0B8),
    inboxLabel: Color(0xFF8A5308),
  );

  static const ToneColors dark = ToneColors(
    focusFill: Color(0xFF4A3F8F),
    focusLabel: Color(0xFFE4DEFF),
    lifeFill: Color(0xFF24603D),
    lifeLabel: Color(0xFFCDEBD9),
    inboxFill: Color(0xFF7A4E10),
    inboxLabel: Color(0xFFFBE4BC),
  );

  final Color focusFill;
  final Color focusLabel;
  final Color lifeFill;
  final Color lifeLabel;
  final Color inboxFill;
  final Color inboxLabel;

  Color fillFor(Tone tone) => switch (tone) {
        Tone.focus => focusFill,
        Tone.life => lifeFill,
        Tone.inbox => inboxFill,
      };

  Color labelFor(Tone tone) => switch (tone) {
        Tone.focus => focusLabel,
        Tone.life => lifeLabel,
        Tone.inbox => inboxLabel,
      };

  @override
  ToneColors copyWith({
    Color? focusFill,
    Color? focusLabel,
    Color? lifeFill,
    Color? lifeLabel,
    Color? inboxFill,
    Color? inboxLabel,
  }) {
    return ToneColors(
      focusFill: focusFill ?? this.focusFill,
      focusLabel: focusLabel ?? this.focusLabel,
      lifeFill: lifeFill ?? this.lifeFill,
      lifeLabel: lifeLabel ?? this.lifeLabel,
      inboxFill: inboxFill ?? this.inboxFill,
      inboxLabel: inboxLabel ?? this.inboxLabel,
    );
  }

  @override
  ToneColors lerp(ThemeExtension<ToneColors>? other, double t) {
    if (other is! ToneColors) return this;
    return ToneColors(
      focusFill: Color.lerp(focusFill, other.focusFill, t)!,
      focusLabel: Color.lerp(focusLabel, other.focusLabel, t)!,
      lifeFill: Color.lerp(lifeFill, other.lifeFill, t)!,
      lifeLabel: Color.lerp(lifeLabel, other.lifeLabel, t)!,
      inboxFill: Color.lerp(inboxFill, other.inboxFill, t)!,
      inboxLabel: Color.lerp(inboxLabel, other.inboxLabel, t)!,
    );
  }
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

- [ ] **Step 4: Write the themes**

`lib/app/theme/app_theme.dart`:

```dart
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const Color _seed = Color(0xFF6C5CE7);

  static ThemeData get light => _build(Brightness.light, ToneColors.light);
  static ThemeData get dark => _build(Brightness.dark, ToneColors.dark);

  static ThemeData _build(Brightness brightness, ToneColors toneColors) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      extensions: <ThemeExtension<Object?>>[toneColors],
    );
  }
}
```

- [ ] **Step 5: Write the placeholder screens**

`lib/features/calendar/calendar_screen.dart`:

```dart
import 'package:energy_clock/core/strings.dart';
import 'package:flutter/material.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(Strings.comingSoon(Strings.tabCalendar)));
  }
}
```

`lib/features/stats/stats_screen.dart`:

```dart
import 'package:energy_clock/core/strings.dart';
import 'package:flutter/material.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(Strings.comingSoon(Strings.tabStats)));
  }
}
```

`lib/features/progress/profile_screen.dart`:

```dart
import 'package:energy_clock/core/strings.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(Strings.comingSoon(Strings.tabProfile)));
  }
}
```

- [ ] **Step 6: Add the new copy to `lib/core/strings.dart`**

Add inside `abstract final class Strings`:

```dart
  static String comingSoon(String feature) => '$feature is coming soon';
```

- [ ] **Step 7: Write the tab shell and app root**

`TabScaffold` imports `ClockScreen`, which does not exist yet — write the stub from Step 8 first if your editor complains, then come back here.

`lib/app/navigation/tab_scaffold.dart`:

```dart
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/calendar/calendar_screen.dart';
import 'package:energy_clock/features/clock/clock_screen.dart';
import 'package:energy_clock/features/progress/profile_screen.dart';
import 'package:energy_clock/features/stats/stats_screen.dart';
import 'package:flutter/material.dart';

class TabScaffold extends StatefulWidget {
  const TabScaffold({super.key});

  @override
  State<TabScaffold> createState() => _TabScaffoldState();
}

class _TabScaffoldState extends State<TabScaffold> {
  int _index = 0;

  static const List<Widget> _screens = [
    ClockScreen(),
    CalendarScreen(),
    StatsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _screens[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule),
            label: Strings.tabClock,
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: Strings.tabCalendar,
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: Strings.tabStats,
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: Strings.tabProfile,
          ),
        ],
      ),
    );
  }
}
```

`lib/app/app.dart`:

```dart
import 'package:energy_clock/app/navigation/tab_scaffold.dart';
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:flutter/material.dart';

class EnergyClockApp extends StatelessWidget {
  const EnergyClockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Strings.appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const TabScaffold(),
    );
  }
}
```

`lib/main.dart`:

```dart
import 'package:energy_clock/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: EnergyClockApp()));
}
```

- [ ] **Step 8: Add a temporary ClockScreen stub so the shell compiles**

`lib/features/clock/clock_screen.dart` — replaced in full in Task 13:

```dart
import 'package:flutter/material.dart';

class ClockScreen extends StatelessWidget {
  const ClockScreen({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
```

- [ ] **Step 9: Run tests to verify they pass**

Run: `flutter test test/app`
Expected: PASS, 6 tests.

- [ ] **Step 10: Commit**

```bash
git add lib/app lib/main.dart lib/core/strings.dart lib/features test/app
git commit -m "feat: add tone palette, light and dark themes, and tab shell"
```

---

### Task 11: Fitted geometry and the dial face painter

**Files:**
- Modify: `lib/core/geometry/dial_geometry.dart`
- Create: `lib/features/clock/widgets/dial_painter.dart`
- Modify: `test/core/geometry/dial_geometry_test.dart`
- Test: `test/features/clock/dial_painter_test.dart`

**Interfaces:**
- Consumes: `DialGeometry` (Tasks 4–5), `ToneColors` (Task 10), `CalendarEvent` (Task 9).
- Produces:
  - `static DialGeometry fitted(Size size)` on `DialGeometry` — derives every radius from the available box, so the dial scales across iPhone sizes with one source of truth.
  - `class DialPainter extends CustomPainter` with named parameters `geometry`, `events`, `ringByEventId`, `toneColors`, `faceColor`, `faceBorderColor`, `tickColor`, `numeralStyle`, `handColor`, `nowMinute` (nullable — the hand is only drawn on today), `ghostRange` (nullable `MinuteRange`), `ghostTone` (nullable `Tone`). This task paints face, ticks, and numerals; Task 12 adds arcs, labels, and the hand.

- [ ] **Step 1: Write the failing geometry test**

Append to `test/core/geometry/dial_geometry_test.dart`, inside `main()`:

```dart
  group('fitted', () {
    test('fits entirely inside the given box', () {
      const size = Size(390, 500);
      final fitted = DialGeometry.fitted(size);
      expect(fitted.center, const Offset(195, 250));
      expect(fitted.orbitOuterRadius, lessThanOrEqualTo(195));
      expect(fitted.faceRadius, greaterThan(0));
    });

    test('scales with the shorter side', () {
      final small = DialGeometry.fitted(const Size(320, 800));
      final large = DialGeometry.fitted(const Size(430, 800));
      expect(large.faceRadius, greaterThan(small.faceRadius));
    });

    test('leaves the face larger than the whole orbit band', () {
      final fitted = DialGeometry.fitted(const Size(390, 500));
      final bandWidth = fitted.orbitOuterRadius - fitted.orbitInnerRadius;
      expect(fitted.faceRadius, greaterThan(bandWidth));
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/geometry/dial_geometry_test.dart`
Expected: FAIL — `The method 'fitted' isn't defined for the type 'DialGeometry'`

- [ ] **Step 3: Add `fitted` to `DialGeometry`**

Add inside the `DialGeometry` class in `lib/core/geometry/dial_geometry.dart`:

```dart
  /// Derives every radius from the available box so the dial scales across
  /// iPhone sizes from one source of truth. Proportions are tuned so the face
  /// dominates and the orbit band stays a slim collar around it.
  static DialGeometry fitted(Size size) {
    final outerRadius = size.shortestSide / 2 - 8;
    final ringWidth = outerRadius * 0.11;
    final ringGap = outerRadius * 0.018;
    final firstRingInset = outerRadius * 0.045;
    final faceRadius = outerRadius -
        firstRingInset -
        maxRings * ringWidth -
        (maxRings - 1) * ringGap;

    return DialGeometry(
      center: Offset(size.width / 2, size.height / 2),
      faceRadius: faceRadius,
      firstRingInset: firstRingInset,
      ringWidth: ringWidth,
      ringGap: ringGap,
    );
  }
```

`fitted` needs `Size`, which comes from `dart:ui` — already imported.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/geometry/dial_geometry_test.dart`
Expected: PASS, 15 tests.

- [ ] **Step 5: Write the failing painter test**

`test/features/clock/dial_painter_test.dart`:

```dart
import 'dart:ui' as ui;

import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/geometry/dial_geometry.dart';
import 'package:energy_clock/features/clock/widgets/dial_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const size = Size(390, 390);

DialPainter buildPainter({int? nowMinute}) {
  return DialPainter(
    geometry: DialGeometry.fitted(size),
    events: const [],
    ringByEventId: const {},
    toneColors: ToneColors.light,
    faceColor: const Color(0xFFFFFFFF),
    faceBorderColor: const Color(0xFFE3E3E0),
    tickColor: const Color(0xFFB4B2A9),
    numeralStyle: const TextStyle(fontSize: 14, color: Color(0xFF2C2C2A)),
    handColor: const Color(0xFF2C2C2A),
    nowMinute: nowMinute,
  );
}

void paint(DialPainter painter) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, size);
  recorder.endRecording().dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('paints an empty dial without throwing', () {
    expect(() => paint(buildPainter()), returnsNormally);
  });

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
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `flutter test test/features/clock/dial_painter_test.dart`
Expected: FAIL — URI does not exist.

- [ ] **Step 7: Write the painter's face, ticks, and numerals**

`lib/features/clock/widgets/dial_painter.dart`:

```dart
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/geometry/dial_geometry.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:flutter/material.dart';

/// Renders the 24-hour dial: face, ticks, numerals, event arcs with curved
/// labels, and the now-hand. All positioning comes from [DialGeometry] — this
/// class owns no math of its own.
class DialPainter extends CustomPainter {
  const DialPainter({
    required this.geometry,
    required this.events,
    required this.ringByEventId,
    required this.toneColors,
    required this.faceColor,
    required this.faceBorderColor,
    required this.tickColor,
    required this.numeralStyle,
    required this.handColor,
    required this.nowMinute,
    this.ghostRange,
    this.ghostTone,
  });

  final DialGeometry geometry;
  final List<CalendarEvent> events;
  final Map<int, int> ringByEventId;
  final ToneColors toneColors;
  final Color faceColor;
  final Color faceBorderColor;
  final Color tickColor;
  final TextStyle numeralStyle;
  final Color handColor;

  /// Null on any day that is not today — the hand is only meaningful there.
  final int? nowMinute;

  /// Live preview while the user drags out a new event.
  final MinuteRange? ghostRange;
  final Tone? ghostTone;

  @override
  void paint(Canvas canvas, Size size) {
    _paintFace(canvas);
    _paintTicks(canvas);
    _paintNumerals(canvas);
  }

  void _paintFace(Canvas canvas) {
    canvas.drawCircle(
      geometry.center,
      geometry.faceRadius,
      Paint()..color = faceColor,
    );
    canvas.drawCircle(
      geometry.center,
      geometry.faceRadius,
      Paint()
        ..color = faceBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _paintTicks(Canvas canvas) {
    final paint = Paint()..color = tickColor;
    for (var hour = 0; hour < 24; hour++) {
      final isMajor = hour % 3 == 0;
      final length = geometry.faceRadius * (isMajor ? 0.075 : 0.04);
      paint.strokeWidth = isMajor ? 1.6 : 0.8;

      final angle = geometry.angleForMinute(hour * 60.0);
      final outer = _pointAt(geometry.faceRadius - 2, angle);
      final inner = _pointAt(geometry.faceRadius - 2 - length, angle);
      canvas.drawLine(inner, outer, paint);
    }
  }

  void _paintNumerals(Canvas canvas) {
    final radius = geometry.faceRadius * 0.72;
    for (var hour = 0; hour < 24; hour += 3) {
      final painter = TextPainter(
        text: TextSpan(text: '$hour', style: numeralStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      final angle = geometry.angleForMinute(hour * 60.0);
      final position = _pointAt(radius, angle);
      painter.paint(
        canvas,
        position - Offset(painter.width / 2, painter.height / 2),
      );
      painter.dispose();
    }
  }

  Offset _pointAt(double radius, double angle) => Offset(
        geometry.center.dx + radius * math.cos(angle),
        geometry.center.dy + radius * math.sin(angle),
      );

  @override
  bool shouldRepaint(DialPainter oldDelegate) {
    return oldDelegate.geometry.center != geometry.center ||
        oldDelegate.geometry.faceRadius != geometry.faceRadius ||
        oldDelegate.events != events ||
        oldDelegate.ringByEventId != ringByEventId ||
        oldDelegate.toneColors != toneColors ||
        oldDelegate.nowMinute != nowMinute ||
        oldDelegate.ghostRange != ghostRange ||
        oldDelegate.ghostTone != ghostTone;
  }
}
```

Add `import 'dart:math' as math;` as the first import.

`ToneColors` needs value equality for `shouldRepaint` to behave. Add to `lib/app/theme/tone_colors.dart`:

```dart
  @override
  bool operator ==(Object other) =>
      other is ToneColors &&
      other.focusFill == focusFill &&
      other.focusLabel == focusLabel &&
      other.lifeFill == lifeFill &&
      other.lifeLabel == lifeLabel &&
      other.inboxFill == inboxFill &&
      other.inboxLabel == inboxLabel;

  @override
  int get hashCode => Object.hash(
        focusFill,
        focusLabel,
        lifeFill,
        lifeLabel,
        inboxFill,
        inboxLabel,
      );
```

- [ ] **Step 8: Run test to verify it passes**

Run: `flutter test test/features/clock/dial_painter_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 9: Commit**

```bash
git add lib/core/geometry/dial_geometry.dart lib/features/clock/widgets/dial_painter.dart lib/app/theme/tone_colors.dart test/core/geometry/dial_geometry_test.dart test/features/clock/dial_painter_test.dart
git commit -m "feat: add fitted dial geometry and face, tick, numeral painting"
```

---

### Task 12: Event arcs, curved labels, and the now-hand

**Files:**
- Modify: `lib/features/clock/widgets/dial_painter.dart`
- Modify: `test/features/clock/dial_painter_test.dart`

**Interfaces:**
- Consumes: `DialPainter` (Task 11), `assignRings` (Task 7), `ToneColors.fillFor` / `labelFor` (Task 10).
- Produces: no new public API — `DialPainter.paint` now also draws arcs, curved labels, the ghost arc, and the now-hand.

**Curved label rule, from the spec:** label text follows the arc; when the arc is too short to fit the title, the label is omitted and the event is identified by tap instead.

- [ ] **Step 1: Write the failing test**

Replace the contents of `test/features/clock/dial_painter_test.dart` with a version that also covers arcs. Keep the existing helpers and add events:

```dart
import 'dart:ui' as ui;

import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/geometry/dial_geometry.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:energy_clock/features/clock/widgets/dial_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const size = Size(390, 390);

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

DialPainter buildPainter({
  int? nowMinute,
  List<CalendarEvent> events = const [],
  Map<int, int> rings = const {},
  MinuteRange? ghostRange,
  Tone? ghostTone,
}) {
  return DialPainter(
    geometry: DialGeometry.fitted(size),
    events: events,
    ringByEventId: rings,
    toneColors: ToneColors.light,
    faceColor: const Color(0xFFFFFFFF),
    faceBorderColor: const Color(0xFFE3E3E0),
    tickColor: const Color(0xFFB4B2A9),
    numeralStyle: const TextStyle(fontSize: 14, color: Color(0xFF2C2C2A)),
    handColor: const Color(0xFF2C2C2A),
    nowMinute: nowMinute,
    ghostRange: ghostRange,
    ghostTone: ghostTone,
  );
}

void paint(DialPainter painter) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, size);
  recorder.endRecording().dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('paints an empty dial without throwing', () {
    expect(() => paint(buildPainter()), returnsNormally);
  });

  test('paints events across all three rings without throwing', () {
    final events = [
      event(1, const MinuteRange(540, 720), Tone.focus, 'Deep work'),
      event(2, const MinuteRange(600, 660), Tone.life, 'Lunch'),
      event(3, const MinuteRange(610, 620), Tone.inbox, 'Email'),
    ];
    expect(
      () => paint(buildPainter(
        events: events,
        rings: const {1: 0, 2: 1, 3: 2},
      )),
      returnsNormally,
    );
  });

  test('skips an event that has no ring assigned', () {
    final events = [
      event(1, const MinuteRange(540, 720), Tone.focus, 'Deep work'),
      event(2, const MinuteRange(600, 660), Tone.life, 'Overflowed'),
    ];
    expect(
      () => paint(buildPainter(events: events, rings: const {1: 0})),
      returnsNormally,
    );
  });

  test('paints a very short arc with no room for its label', () {
    final events = [
      event(1, const MinuteRange(540, 555), Tone.focus,
          'A very long event title that cannot possibly fit'),
    ];
    expect(
      () => paint(buildPainter(events: events, rings: const {1: 0})),
      returnsNormally,
    );
  });

  test('paints the ghost arc during a drag', () {
    expect(
      () => paint(buildPainter(
        ghostRange: const MinuteRange(540, 720),
        ghostTone: Tone.focus,
      )),
      returnsNormally,
    );
  });

  test('paints the now-hand when a now minute is given', () {
    expect(() => paint(buildPainter(nowMinute: 630)), returnsNormally);
  });

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
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/clock/dial_painter_test.dart`
Expected: FAIL — `'characters' isn't defined` or the arc tests error, because `paint` still only draws face, ticks, and numerals. The ghost and hand tests will pass trivially at this point since nothing is drawn for them yet; that is expected, and Step 3 is what makes them meaningful.

- [ ] **Step 3: Add arcs, labels, ghost, and hand to `paint`**

Replace `DialPainter.paint` and add the new private methods:

```dart
  @override
  void paint(Canvas canvas, Size size) {
    _paintFace(canvas);
    _paintTicks(canvas);
    _paintNumerals(canvas);
    _paintEvents(canvas);
    _paintGhost(canvas);
    _paintHand(canvas);
  }

  void _paintEvents(Canvas canvas) {
    for (final calendarEvent in events) {
      final ring = ringByEventId[calendarEvent.id];
      if (ring == null) continue;

      final radius = geometry.ringCenterRadius(ring);
      _paintArc(
        canvas,
        radius: radius,
        range: calendarEvent.range,
        color: toneColors.fillFor(calendarEvent.tone),
      );
      _paintCurvedLabel(
        canvas,
        text: calendarEvent.title,
        radius: radius,
        range: calendarEvent.range,
        color: toneColors.labelFor(calendarEvent.tone),
      );
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
      color: toneColors.fillFor(tone).withValues(alpha: 0.55),
    );
  }

  void _paintArc(
    Canvas canvas, {
    required double radius,
    required MinuteRange range,
    required Color color,
  }) {
    final startAngle = geometry.angleForMinute(range.start.toDouble());
    final sweep = geometry.angleForMinute(range.end.toDouble()) - startAngle;

    canvas.drawArc(
      Rect.fromCircle(center: geometry.center, radius: radius),
      startAngle,
      sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = geometry.ringWidth
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

    final style = numeralStyle.copyWith(
      color: color,
      fontSize: geometry.ringWidth * 0.52,
      fontWeight: FontWeight.w500,
    );

    final measure = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final totalWidth = measure.width;
    measure.dispose();

    final startAngle = geometry.angleForMinute(range.start.toDouble());
    final sweep = geometry.angleForMinute(range.end.toDouble()) - startAngle;
    final availableWidth = sweep * radius;
    if (totalWidth > availableWidth * 0.88) return;

    var angle = startAngle + (sweep - totalWidth / radius) / 2;

    for (final glyph in text.characters) {
      final painter = TextPainter(
        text: TextSpan(text: glyph, style: style),
        textDirection: TextDirection.ltr,
      )..layout();

      final glyphAngle = angle + (painter.width / 2) / radius;

      canvas.save();
      canvas.translate(geometry.center.dx, geometry.center.dy);
      canvas.rotate(glyphAngle + math.pi / 2);
      canvas.translate(0, -radius);
      painter.paint(
        canvas,
        Offset(-painter.width / 2, -painter.height / 2),
      );
      canvas.restore();

      angle += painter.width / radius;
      painter.dispose();
    }
  }

  void _paintHand(Canvas canvas) {
    final minute = nowMinute;
    if (minute == null) return;

    final angle = geometry.angleForMinute(minute.toDouble());
    canvas.drawLine(
      geometry.center,
      _pointAt(geometry.faceRadius * 0.82, angle),
      Paint()
        ..color = handColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      geometry.center,
      geometry.faceRadius * 0.045,
      Paint()..color = handColor,
    );
  }
```

Add `import 'package:characters/characters.dart';` for `.characters`. It ships with Flutter, so no pubspec change is needed.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/clock/dial_painter_test.dart`
Expected: PASS, 8 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/features/clock/widgets/dial_painter.dart test/features/clock/dial_painter_test.dart
git commit -m "feat: paint event arcs, curved labels, ghost preview, and now-hand"
```

---

### Task 13: Day header and clock screen

**Files:**
- Create: `lib/features/clock/widgets/day_header.dart`
- Replace: `lib/features/clock/clock_screen.dart` (the Task 10 stub)
- Modify: `lib/core/strings.dart`
- Test: `test/features/clock/day_header_test.dart`, `test/features/clock/clock_screen_test.dart`

**Interfaces:**
- Consumes: `selectedDateProvider`, `dayEventsProvider`, `eventRepositoryProvider` (Task 9); `isPastDay` (Task 3); `Strings` (Task 2).
- Produces:
  - `class DayHeader extends ConsumerWidget` — prev/next chevrons, the formatted date, a "Today" button shown only when the selected day is not today, and the `+` add button (disabled on past days).
  - `class ClockScreen extends ConsumerWidget` — header, dial, and empty state.

**Deviation from the spec, deliberate:** the spec says the `+` button lives "in the nav bar". The tab shell has no app bar, so `+` lives at the trailing edge of the day header row instead. Same affordance, one less chrome layer.

- [ ] **Step 1: Add the new copy to `lib/core/strings.dart`**

Add inside `abstract final class Strings`:

```dart
  static const String today = 'Today';
  static const String addEvent = 'Add event';
  static const String previousDay = 'Previous day';
  static const String nextDay = 'Next day';
  static const String emptyDayTitle = 'Nothing planned yet';
  static const String emptyDayHint =
      'Drag around the ring to block out your first event.';
  static const String pastDayNotice = 'Past days are read-only';
  static const String loadFailed = "Couldn't load this day. Pull to retry.";
```

- [ ] **Step 2: Write the failing tests**

`test/features/clock/day_header_test.dart`:

```dart
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/day_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget harness() {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(body: DayHeader(onAdd: () {})),
    ),
  );
}

void main() {
  testWidgets('hides the Today button when already on today', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.text(Strings.today), findsNothing);
  });

  testWidgets('next day shows the Today button and moves the date',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel(Strings.nextDay));
    await tester.pumpAndSettle();

    expect(find.text(Strings.today), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DayHeader)),
    );
    expect(
      container.read(selectedDateProvider),
      startOfDay(DateTime.now()).add(const Duration(days: 1)),
    );
  });

  testWidgets('Today returns to today', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel(Strings.previousDay));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.today));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DayHeader)),
    );
    expect(container.read(selectedDateProvider), startOfDay(DateTime.now()));
  });

  testWidgets('the add button is disabled on a past day', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel(Strings.previousDay));
    await tester.pumpAndSettle();

    final button = tester.widget<IconButton>(
      find.bySemanticsLabel(Strings.addEvent),
    );
    expect(button.onPressed, isNull);
  });
}
```

`test/features/clock/clock_screen_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/features/clock/clock_screen.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late EventRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftEventRepository(db.eventDao);
  });

  tearDown(() async {
    await db.close();
  });

  Widget harness() {
    return ProviderScope(
      overrides: [eventRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: Scaffold(body: ClockScreen())),
    );
  }

  testWidgets('an empty day shows the invitation', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.text(Strings.emptyDayTitle), findsOneWidget);
  });

  testWidgets('a day with events hides the invitation', (tester) async {
    await repository.createEvent(
      day: DateTime.now(),
      title: 'Deep work',
      tone: Tone.focus,
      range: const MinuteRange(540, 720),
    );

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.text(Strings.emptyDayTitle), findsNothing);
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/clock/day_header_test.dart test/features/clock/clock_screen_test.dart`
Expected: FAIL — `day_header.dart` does not exist and `ClockScreen` has no such content.

- [ ] **Step 4: Write the day header**

`lib/features/clock/widgets/day_header.dart`:

```dart
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class DayHeader extends ConsumerWidget {
  const DayHeader({required this.onAdd, super.key});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDateProvider);
    final notifier = ref.read(selectedDateProvider.notifier);
    final isToday = selected == startOfDay(DateTime.now());
    final readOnly = isPastDay(selected);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: Strings.previousDay,
            onPressed: notifier.previous,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  DateFormat('EEEE').format(selected),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  DateFormat('d MMMM y').format(selected),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: Strings.nextDay,
            onPressed: notifier.next,
          ),
          if (!isToday)
            TextButton(
              onPressed: notifier.today,
              child: const Text(Strings.today),
            ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: Strings.addEvent,
            onPressed: readOnly ? null : onAdd,
          ),
        ],
      ),
    );
  }
}
```

`IconButton`'s `tooltip` is what `find.bySemanticsLabel` matches, so the tests above resolve against these strings.

- [ ] **Step 5: Write the clock screen**

Replace `lib/features/clock/clock_screen.dart` entirely:

```dart
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/day_header.dart';
import 'package:energy_clock/features/clock/widgets/dial_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ClockScreen extends ConsumerWidget {
  const ClockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDateProvider);
    final events = ref.watch(dayEventsProvider);
    final readOnly = isPastDay(selected);

    return Column(
      children: [
        DayHeader(onAdd: () {}),
        if (readOnly)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              Strings.pastDayNotice,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: events.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => const Center(
              child: Text(Strings.loadFailed),
            ),
            data: (dayEvents) => Column(
              children: [
                Expanded(
                  child: DialView(
                    events: dayEvents,
                    day: selected,
                    readOnly: readOnly,
                  ),
                ),
                if (dayEvents.isEmpty && !readOnly)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
                    child: Column(
                      children: [
                        Text(
                          Strings.emptyDayTitle,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Strings.emptyDayHint,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
```

The `onAdd` callback stays empty until Task 15 wires the sheet.

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/clock`
Expected: PASS. `clock_screen_test.dart` will not compile until `DialView` exists — implement Task 14 first if you are executing strictly in order, or add a minimal `DialView` stub now and complete it in Task 14.

- [ ] **Step 7: Commit**

```bash
git add lib/features/clock lib/core/strings.dart test/features/clock
git commit -m "feat: add day header with day switching and the clock screen shell"
```

---

### Task 14: Dial hit testing and drag-to-create

**Files:**
- Create: `lib/features/clock/widgets/dial_hit_test.dart`, `lib/features/clock/widgets/dial_view.dart`
- Test: `test/features/clock/dial_hit_test_test.dart`

**Interfaces:**
- Consumes: `DialGeometry` (Tasks 4, 5, 11), `MinuteRange` / `rangeFromDrag` / `unwrapMinute` (Task 6), `assignRings` (Task 7), `DialPainter` (Tasks 11–12), `CalendarEvent` (Task 9).
- Produces:
  - `CalendarEvent? eventAtPoint({required Offset point, required DialGeometry geometry, required List<CalendarEvent> events, required Map<int, int> ringByEventId})` in `dial_hit_test.dart`.
  - `class DialView extends ConsumerStatefulWidget` — named `events`, `day`, `readOnly`, and optional `onCreateRequested` (`void Function(MinuteRange range)`) and `onEventTapped` (`void Function(CalendarEvent event)`).

- [ ] **Step 1: Write the failing hit-test test**

`test/features/clock/dial_hit_test_test.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:energy_clock/core/geometry/dial_geometry.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:energy_clock/features/clock/widgets/dial_hit_test.dart';
import 'package:flutter_test/flutter_test.dart';

const geometry = DialGeometry(
  center: Offset(100, 100),
  faceRadius: 100,
  firstRingInset: 8,
  ringWidth: 20,
  ringGap: 4,
);

CalendarEvent event(int id, MinuteRange range) => CalendarEvent(
      id: id,
      seriesId: null,
      date: DateTime(2026, 8, 23),
      title: 'Event $id',
      tone: Tone.focus,
      range: range,
      status: EventStatus.planned,
    );

/// A point on the centreline of [ring] at [minute].
Offset pointAt(int minute, int ring) {
  final angle = geometry.angleForMinute(minute.toDouble());
  final radius = geometry.ringCenterRadius(ring);
  return Offset(
    geometry.center.dx + radius * math.cos(angle),
    geometry.center.dy + radius * math.sin(angle),
  );
}

void main() {
  final events = [
    event(1, const MinuteRange(540, 720)),
    event(2, const MinuteRange(600, 660)),
  ];
  const rings = {1: 0, 2: 1};

  test('finds the event under a point on its ring', () {
    final hit = eventAtPoint(
      point: pointAt(600, 0),
      geometry: geometry,
      events: events,
      ringByEventId: rings,
    );
    expect(hit?.id, 1);
  });

  test('distinguishes rings at the same minute', () {
    final hit = eventAtPoint(
      point: pointAt(620, 1),
      geometry: geometry,
      events: events,
      ringByEventId: rings,
    );
    expect(hit?.id, 2);
  });

  test('returns null outside every event', () {
    final hit = eventAtPoint(
      point: pointAt(200, 0),
      geometry: geometry,
      events: events,
      ringByEventId: rings,
    );
    expect(hit, isNull);
  });

  test('returns null on the face itself', () {
    final hit = eventAtPoint(
      point: const Offset(100, 100),
      geometry: geometry,
      events: events,
      ringByEventId: rings,
    );
    expect(hit, isNull);
  });

  test('the exclusive end minute is not a hit', () {
    final hit = eventAtPoint(
      point: pointAt(720, 0),
      geometry: geometry,
      events: events,
      ringByEventId: rings,
    );
    expect(hit, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/clock/dial_hit_test_test.dart`
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Write the hit test**

`lib/features/clock/widgets/dial_hit_test.dart`:

```dart
import 'dart:ui';

import 'package:energy_clock/core/geometry/dial_geometry.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';

/// The event drawn under [point], or null. Matches on both ring and minute,
/// so overlapping events on different rings are distinguishable.
CalendarEvent? eventAtPoint({
  required Offset point,
  required DialGeometry geometry,
  required List<CalendarEvent> events,
  required Map<int, int> ringByEventId,
}) {
  final ring = geometry.ringAtPoint(point);
  if (ring == null) return null;

  final minute = geometry.minuteAtPoint(point);
  for (final event in events) {
    if (ringByEventId[event.id] != ring) continue;
    if (minute >= event.startMinute && minute < event.endMinute) return event;
  }
  return null;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/clock/dial_hit_test_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Write the dial view**

`lib/features/clock/widgets/dial_view.dart`:

```dart
import 'dart:async';

import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/geometry/dial_geometry.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/geometry/ring_layout.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:energy_clock/features/clock/widgets/dial_hit_test.dart';
import 'package:energy_clock/features/clock/widgets/dial_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The tone a freshly dragged event previews as before the user picks one.
const Tone defaultDraftTone = Tone.focus;

class DialView extends ConsumerStatefulWidget {
  const DialView({
    required this.events,
    required this.day,
    required this.readOnly,
    this.onCreateRequested,
    this.onEventTapped,
    super.key,
  });

  final List<CalendarEvent> events;
  final DateTime day;
  final bool readOnly;
  final void Function(MinuteRange range)? onCreateRequested;
  final void Function(CalendarEvent event)? onEventTapped;

  @override
  ConsumerState<DialView> createState() => _DialViewState();
}

class _DialViewState extends ConsumerState<DialView> {
  MinuteRange? _ghostRange;
  int? _anchorMinute;
  double _continuousMinute = 0;
  int? _lastHapticMinute;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  bool get _isToday => widget.day == startOfDay(_now);

  /// The tone in effect right now, shown under the clock in the dial centre.
  /// Null when the selected day is not today or nothing is scheduled.
  Tone? get _currentTone {
    if (!_isToday) return null;
    final minute = minuteOfDay(_now);
    for (final event in widget.events) {
      if (minute >= event.startMinute && minute < event.endMinute) {
        return event.tone;
      }
    }
    return null;
  }

  RingAssignment get _assignment => assignRings([
        for (final event in widget.events) RingCandidate(event.id, event.range),
      ]);

  void _onPanStart(DragStartDetails details, DialGeometry geometry) {
    if (widget.readOnly) return;
    if (!geometry.isInOrbitBand(details.localPosition)) return;

    final minute = geometry.minuteAtPoint(details.localPosition);
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

  void _onPanEnd(DragEndDetails details) {
    final range = _ghostRange;
    setState(() {
      _ghostRange = null;
      _anchorMinute = null;
      _lastHapticMinute = null;
    });
    if (range != null) widget.onCreateRequested?.call(range);
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
    final theme = Theme.of(context);
    final toneColors = context.toneColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final geometry = DialGeometry.fitted(size);
        final ghost = _ghostRange;

        return GestureDetector(
          onPanStart: (details) => _onPanStart(details, geometry),
          onPanUpdate: (details) => _onPanUpdate(details, geometry),
          onPanEnd: _onPanEnd,
          onTapUp: (details) => _onTapUp(details, geometry),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: size,
                painter: DialPainter(
                  geometry: geometry,
                  events: widget.events,
                  ringByEventId: _assignment.ringByEventId,
                  toneColors: toneColors,
                  faceColor: theme.colorScheme.surface,
                  faceBorderColor: theme.colorScheme.outlineVariant,
                  tickColor: theme.colorScheme.outline,
                  numeralStyle: theme.textTheme.titleMedium ??
                      const TextStyle(fontSize: 16),
                  handColor: theme.colorScheme.onSurface,
                  nowMinute: _isToday ? minuteOfDay(_now) : null,
                  ghostRange: ghost,
                  ghostTone: ghost == null ? null : defaultDraftTone,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ghost != null
                        ? formatMinuteRange(ghost.start, ghost.end)
                        : formatMinuteOfDay(minuteOfDay(_now)),
                    style: theme.textTheme.titleLarge,
                  ),
                  if (ghost == null && _currentTone != null)
                    Text(
                      _currentTone!.label,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: toneColors.labelFor(_currentTone!)),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 6: Verify the whole suite and analysis**

Run: `flutter test`
Expected: PASS, all tests.

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 7: Commit**

```bash
git add lib/features/clock/widgets test/features/clock/dial_hit_test_test.dart
git commit -m "feat: add dial hit testing and drag-to-create with haptic snapping"
```

---

### Task 15: Event sheet — create and edit

**Files:**
- Create: `lib/features/clock/widgets/event_sheet.dart`
- Modify: `lib/features/clock/clock_screen.dart`, `lib/core/strings.dart`
- Test: `test/features/clock/event_sheet_test.dart`

**Interfaces:**
- Consumes: `eventRepositoryProvider`, `RingOverflowException`, `CalendarEvent` (Task 9); `MinuteRange`, `snapMinute` (Task 6); `Tone` (Task 2); `formatMinuteOfDay` (Task 3).
- Produces:
  - `class EventSheet extends ConsumerStatefulWidget` with `static Future<void> show(BuildContext context, {required DateTime day, required MinuteRange initialRange, CalendarEvent? existing})`. Passing `existing` puts the sheet in edit mode.

**Deferred from the spec:** spec 5.2 lists "a repeat option" in this sheet. Recurrence is Phase 3, so the sheet has no repeat control yet — do not stub one.

**Behaviour:** title is required; the three tone buttons are the only tone control; start and end steppers move in 5-minute increments and can never produce an event shorter than 15 minutes or an end past 1440. Saving an event that would need a fourth ring shows the refusal message and leaves the sheet open.

- [ ] **Step 1: Add the new copy to `lib/core/strings.dart`**

```dart
  static const String newEvent = 'New event';
  static const String editEvent = 'Edit event';
  static const String titleLabel = 'Title';
  static const String titleHint = 'Deep work';
  static const String titleRequired = 'Enter a title';
  static const String toneLabel = 'Tone';
  static const String startLabel = 'Start';
  static const String endLabel = 'End';
  static const String save = 'Save';
  static const String cancel = 'Cancel';
  static const String ringOverflow = 'Up to three overlapping events.';
```

- [ ] **Step 2: Write the failing test**

`test/features/clock/event_sheet_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/event_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late EventRepository repository;

  final day = DateTime(2026, 8, 23);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftEventRepository(db.eventDao);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> openSheet(WidgetTester tester) async {
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
                  initialRange: const MinuteRange(540, 720),
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

  testWidgets('saving without a title shows an error and writes nothing',
      (tester) async {
    await openSheet(tester);

    await tester.tap(find.text(Strings.save));
    await tester.pumpAndSettle();

    expect(find.text(Strings.titleRequired), findsOneWidget);
    expect(await repository.eventsForDay(day), isEmpty);
  });

  testWidgets('saving with a title and tone creates the event',
      (tester) async {
    await openSheet(tester);

    await tester.enterText(find.byType(TextField), 'Deep work');
    await tester.tap(find.text(Tone.life.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.save));
    await tester.pumpAndSettle();

    final events = await repository.eventsForDay(day);
    expect(events.single.title, 'Deep work');
    expect(events.single.tone, Tone.life);
    expect(events.single.range, const MinuteRange(540, 720));
  });

  testWidgets('the end stepper never drops below the minimum duration',
      (tester) async {
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), 'Deep work');

    // 720 down to 540 would be 36 taps; 40 taps must still leave 15 minutes.
    for (var i = 0; i < 40; i++) {
      await tester.tap(find.bySemanticsLabel('${Strings.endLabel} minus'));
      await tester.pump();
    }
    await tester.tap(find.text(Strings.save));
    await tester.pumpAndSettle();

    final events = await repository.eventsForDay(day);
    expect(events.single.range, const MinuteRange(540, 555));
  });

  testWidgets('a fourth overlapping event is refused with a message',
      (tester) async {
    for (final range in const [
      MinuteRange(540, 720),
      MinuteRange(600, 660),
      MinuteRange(610, 620),
    ]) {
      await repository.createEvent(
        day: day,
        title: 'Existing',
        tone: Tone.focus,
        range: range,
      );
    }

    await openSheet(tester);
    await tester.enterText(find.byType(TextField), 'Fourth');
    await tester.tap(find.text(Strings.save));
    await tester.pumpAndSettle();

    expect(find.text(Strings.ringOverflow), findsOneWidget);
    expect(await repository.eventsForDay(day), hasLength(3));
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/clock/event_sheet_test.dart`
Expected: FAIL — URI does not exist.

- [ ] **Step 4: Write the sheet**

`lib/features/clock/widgets/event_sheet.dart`:

```dart
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:flutter/material.dart';
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
      builder: (_) => EventSheet(
        day: day,
        initialRange: initialRange,
        existing: existing,
      ),
    );
  }

  @override
  ConsumerState<EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends ConsumerState<EventSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.existing?.title ?? '');
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
    final start = snapMinute(_range.start + delta)
        .clamp(0, _range.end - minEventMinutes);
    setState(() => _range = MinuteRange(start, _range.end));
  }

  void _nudgeEnd(int delta) {
    final end = snapMinute(_range.end + delta)
        .clamp(_range.start + minEventMinutes, minutesPerDay);
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
    final toneColors = context.toneColors;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? Strings.newEvent : Strings.editEvent,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: Strings.titleLabel,
              hintText: Strings.titleHint,
              errorText: _titleError,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text(Strings.toneLabel, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final tone in Tone.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _ToneButton(
                      tone: tone,
                      selected: tone == _tone,
                      fill: toneColors.fillFor(tone),
                      label: toneColors.labelFor(tone),
                      onTap: () => setState(() => _tone = tone),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _MinuteStepper(
            label: Strings.startLabel,
            minute: _range.start,
            onDecrease: () => _nudgeStart(-snapStepMinutes),
            onIncrease: () => _nudgeStart(snapStepMinutes),
          ),
          _MinuteStepper(
            label: Strings.endLabel,
            minute: _range.end,
            onDecrease: () => _nudgeEnd(-snapStepMinutes),
            onIncrease: () => _nudgeEnd(snapStepMinutes),
          ),
          const SizedBox(height: 8),
          Text(
            formatDurationMinutes(_range.durationMinutes),
            style: theme.textTheme.bodySmall,
          ),
          if (_saveError != null) ...[
            const SizedBox(height: 12),
            Text(
              _saveError!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            child: const Text(Strings.save),
          ),
        ],
      ),
    );
  }
}

class _ToneButton extends StatelessWidget {
  const _ToneButton({
    required this.tone,
    required this.selected,
    required this.fill,
    required this.label,
    required this.onTap,
  });

  final Tone tone;
  final bool selected;
  final Color fill;
  final Color label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? label : Colors.transparent,
              width: 2,
            ),
          ),
          child: Text(
            tone.label,
            style: TextStyle(
              color: label,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _MinuteStepper extends StatelessWidget {
  const _MinuteStepper({
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
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          icon: const Icon(Icons.remove),
          tooltip: '$label minus',
          onPressed: onDecrease,
        ),
        SizedBox(
          width: 64,
          child: Text(
            formatMinuteOfDay(minute),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: '$label plus',
          onPressed: onIncrease,
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/clock/event_sheet_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 6: Wire the sheet into the clock screen**

In `lib/features/clock/clock_screen.dart`, replace `DayHeader(onAdd: () {})` and add the create callback on `DialView`. Add these imports:

```dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/features/clock/widgets/event_sheet.dart';
```

Replace the header line with:

```dart
        DayHeader(
          onAdd: () => EventSheet.show(
            context,
            day: selected,
            initialRange: const MinuteRange(540, 600),
          ),
        ),
```

And give `DialView` its callback:

```dart
                  child: DialView(
                    events: dayEvents,
                    day: selected,
                    readOnly: readOnly,
                    onCreateRequested: (range) => EventSheet.show(
                      context,
                      day: selected,
                      initialRange: range,
                    ),
                  ),
```

- [ ] **Step 7: Verify the suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/clock lib/core/strings.dart test/features/clock/event_sheet_test.dart
git commit -m "feat: add event sheet for creating and editing events"
```

---

### Task 16: Event detail sheet and deletion

**Files:**
- Create: `lib/features/clock/widgets/event_detail_sheet.dart`
- Modify: `lib/features/clock/clock_screen.dart`, `lib/core/strings.dart`
- Test: `test/features/clock/event_detail_sheet_test.dart`

**Interfaces:**
- Consumes: `CalendarEvent`, `eventRepositoryProvider` (Task 9); `EventSheet.show` (Task 15).
- Produces: `class EventDetailSheet extends ConsumerWidget` with `static Future<void> show(BuildContext context, {required CalendarEvent event, required bool readOnly})`.

**Note:** the spec's detail sheet has three actions — Start session, Edit, Delete. Start session belongs to Phase 2 and is deliberately absent here rather than stubbed as a dead control.

- [ ] **Step 1: Add the new copy**

```dart
  static const String edit = 'Edit';
  static const String delete = 'Delete';
  static const String deleteConfirmTitle = 'Delete this event?';
  static const String deleteConfirmBody = "This can't be undone.";
```

- [ ] **Step 2: Write the failing test**

`test/features/clock/event_detail_sheet_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/event_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late EventRepository repository;

  final day = DateTime(2026, 8, 23);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftEventRepository(db.eventDao);
  });

  tearDown(() async {
    await db.close();
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
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [eventRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light,
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

  testWidgets('shows the title, range, and tone', (tester) async {
    await openSheet(tester, await seed());

    expect(find.text('Deep work'), findsOneWidget);
    expect(find.text('09:00 – 12:00'), findsOneWidget);
    expect(find.text(Tone.focus.label), findsOneWidget);
  });

  testWidgets('deleting asks for confirmation and then removes the event',
      (tester) async {
    await openSheet(tester, await seed());

    await tester.tap(find.text(Strings.delete));
    await tester.pumpAndSettle();
    expect(find.text(Strings.deleteConfirmTitle), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, Strings.delete));
    await tester.pumpAndSettle();

    expect(await repository.eventsForDay(day), isEmpty);
  });

  testWidgets('cancelling the confirmation keeps the event', (tester) async {
    await openSheet(tester, await seed());

    await tester.tap(find.text(Strings.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.cancel));
    await tester.pumpAndSettle();

    expect(await repository.eventsForDay(day), hasLength(1));
  });

  testWidgets('a read-only day hides edit and delete', (tester) async {
    await openSheet(tester, await seed(), readOnly: true);

    expect(find.text(Strings.edit), findsNothing);
    expect(find.text(Strings.delete), findsNothing);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/clock/event_detail_sheet_test.dart`
Expected: FAIL — URI does not exist.

- [ ] **Step 4: Write the detail sheet**

`lib/features/clock/widgets/event_detail_sheet.dart`:

```dart
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/event_sheet.dart';
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
      useSafeArea: true,
      builder: (_) => EventDetailSheet(event: event, readOnly: readOnly),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(Strings.deleteConfirmTitle),
        content: const Text(Strings.deleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(Strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(Strings.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(eventRepositoryProvider).deleteEvent(event.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final toneColors = context.toneColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(event.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            formatMinuteRange(event.startMinute, event.endMinute),
            style: theme.textTheme.bodyLarge,
          ),
          Text(
            formatDurationMinutes(event.range.durationMinutes),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: toneColors.fillFor(event.tone),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                event.tone.label,
                style: TextStyle(color: toneColors.labelFor(event.tone)),
              ),
            ),
          ),
          if (!readOnly) ...[
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () {
                Navigator.of(context).pop();
                EventSheet.show(
                  context,
                  day: event.date,
                  initialRange: event.range,
                  existing: event,
                );
              },
              child: const Text(Strings.edit),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _confirmDelete(context, ref),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Text(Strings.delete),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/clock/event_detail_sheet_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 6: Wire the detail sheet into the clock screen**

Add the import and the `onEventTapped` callback on `DialView` in `lib/features/clock/clock_screen.dart`:

```dart
import 'package:energy_clock/features/clock/widgets/event_detail_sheet.dart';
```

```dart
                    onEventTapped: (event) => EventDetailSheet.show(
                      context,
                      event: event,
                      readOnly: readOnly,
                    ),
```

- [ ] **Step 7: Commit**

```bash
git add lib/features/clock lib/core/strings.dart test/features/clock/event_detail_sheet_test.dart
git commit -m "feat: add event detail sheet with edit and confirmed delete"
```

---

### Task 17: Moving and resizing arcs by drag

**Files:**
- Modify: `lib/core/geometry/minute_range.dart`, `lib/features/clock/widgets/dial_view.dart`, `lib/features/clock/clock_screen.dart`
- Modify: `test/core/geometry/minute_range_test.dart`

**Interfaces:**
- Consumes: `grabKindFor`, `MinuteRange`, `snapMinute` (Task 6); `eventAtPoint` (Task 14); `EventRepository.moveEvent` (Task 9).
- Produces:
  - `MinuteRange moveRange(MinuteRange range, int deltaMinutes)` — translates, clamping both ends inside the day and preserving duration.
  - `MinuteRange resizeRangeStart(MinuteRange range, int newStart)` — clamps so the event keeps at least `minEventMinutes`.
  - `MinuteRange resizeRangeEnd(MinuteRange range, int newEnd)` — same, and never past 1440.
  - `DialView` gains `onMoveRequested` (`void Function(CalendarEvent event, MinuteRange range)`).

- [ ] **Step 1: Write the failing tests**

Append to `test/core/geometry/minute_range_test.dart`, inside `main()`:

```dart
  group('moveRange', () {
    test('translates and preserves duration', () {
      expect(
        moveRange(const MinuteRange(540, 720), 60),
        const MinuteRange(600, 780),
      );
    });

    test('clamps at the start of the day without shrinking', () {
      expect(
        moveRange(const MinuteRange(30, 90), -60),
        const MinuteRange(0, 60),
      );
    });

    test('clamps at the end of the day without shrinking', () {
      expect(
        moveRange(const MinuteRange(1350, 1410), 120),
        const MinuteRange(1380, 1440),
      );
    });
  });

  group('resizeRange', () {
    test('resizing the start moves only the start', () {
      expect(
        resizeRangeStart(const MinuteRange(540, 720), 600),
        const MinuteRange(600, 720),
      );
    });

    test('the start cannot cross the minimum duration', () {
      expect(
        resizeRangeStart(const MinuteRange(540, 720), 719),
        const MinuteRange(705, 720),
      );
    });

    test('the end cannot cross the minimum duration', () {
      expect(
        resizeRangeEnd(const MinuteRange(540, 720), 541),
        const MinuteRange(540, 555),
      );
    });

    test('the end clamps at the end of the day', () {
      expect(
        resizeRangeEnd(const MinuteRange(1380, 1410), 1500),
        const MinuteRange(1380, 1440),
      );
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/geometry/minute_range_test.dart`
Expected: FAIL — `moveRange` is not defined.

- [ ] **Step 3: Add the range transforms**

Append to `lib/core/geometry/minute_range.dart`:

```dart
/// Translates a range by [deltaMinutes], clamping inside the day. The
/// duration is preserved — hitting a boundary stops the event rather than
/// squashing it.
MinuteRange moveRange(MinuteRange range, int deltaMinutes) {
  final duration = range.durationMinutes;
  var start = snapMinute(range.start + deltaMinutes);
  if (start + duration > minutesPerDay) start = minutesPerDay - duration;
  if (start < 0) start = 0;
  return MinuteRange(start, start + duration);
}

/// Moves the start edge, keeping at least [minEventMinutes].
MinuteRange resizeRangeStart(MinuteRange range, int newStart) {
  final start =
      snapMinute(newStart).clamp(0, range.end - minEventMinutes);
  return MinuteRange(start, range.end);
}

/// Moves the end edge, keeping at least [minEventMinutes] and never passing
/// the end of the day.
MinuteRange resizeRangeEnd(MinuteRange range, int newEnd) {
  final end = snapMinute(newEnd)
      .clamp(range.start + minEventMinutes, minutesPerDay);
  return MinuteRange(range.start, end);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/geometry/minute_range_test.dart`
Expected: PASS, 24 tests.

- [ ] **Step 5: Add the edit-drag branch to `DialView`**

In `lib/features/clock/widgets/dial_view.dart`, add the callback to the widget:

```dart
  final void Function(CalendarEvent event, MinuteRange range)? onMoveRequested;
```

Add it to the constructor as `this.onMoveRequested,`.

Add these fields to `_DialViewState`:

```dart
  CalendarEvent? _draggingEvent;
  ArcGrabKind? _grabKind;
  MinuteRange? _originalRange;
  MinuteRange? _draftRange;
```

Replace `_onPanStart` so that grabbing an existing arc edits it instead of creating:

```dart
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
```

Replace `_onPanUpdate` to branch on whether an event is being edited:

```dart
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
        ArcGrabKind.resizeStart =>
          resizeRangeStart(original, _continuousMinute.round()),
        ArcGrabKind.resizeEnd =>
          resizeRangeEnd(original, _continuousMinute.round()),
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
```

Replace `_onPanEnd`:

```dart
  void _onPanEnd(DragEndDetails details) {
    final dragging = _draggingEvent;
    final draft = _draftRange;
    final created = _ghostRange;

    setState(() {
      _ghostRange = null;
      _anchorMinute = null;
      _lastHapticMinute = null;
      _draggingEvent = null;
      _grabKind = null;
      _originalRange = null;
      _draftRange = null;
    });

    if (dragging != null && draft != null) {
      if (draft.start != dragging.range.start ||
          draft.end != dragging.range.end) {
        widget.onMoveRequested?.call(dragging, draft);
      }
      return;
    }
    if (created != null) widget.onCreateRequested?.call(created);
  }
```

Finally, render the in-progress edit by substituting the draft range into the painted events. In `build`, before constructing the painter:

```dart
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
```

Pass `paintedEvents` to `DialPainter(events: ...)` instead of `widget.events`.

Add the needed imports: `grabKindFor`, `moveRange`, `resizeRangeStart`, and `resizeRangeEnd` all come from the already-imported `minute_range.dart`.

- [ ] **Step 6: Wire the move callback in the clock screen**

In `lib/features/clock/clock_screen.dart`, add the import that `RingOverflowException` comes from:

```dart
import 'package:energy_clock/features/clock/data/event_repository.dart';
```

Then add to `DialView`:

```dart
                    onMoveRequested: (event, range) async {
                      try {
                        await ref.read(eventRepositoryProvider).moveEvent(
                              id: event.id,
                              day: selected,
                              range: range,
                            );
                      } on RingOverflowException {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text(Strings.ringOverflow)),
                        );
                      }
                    },
```

- [ ] **Step 7: Verify the suite and analysis**

Run: `flutter test`
Expected: PASS.

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 8: Commit**

```bash
git add lib/core/geometry/minute_range.dart lib/features/clock test/core/geometry/minute_range_test.dart
git commit -m "feat: move and resize events by dragging their arcs"
```

---

### Task 18: Golden tests and simulator verification

**Files:**
- Test: `test/features/clock/dial_golden_test.dart`
- Create: `test/features/clock/goldens/` (generated images)

**Interfaces:**
- Consumes: everything built in Tasks 1–17.
- Produces: golden images pinning the dial's rendering, and a verified build running on the iPhone 17 Pro simulator.

Golden images are generated on this machine and are not portable across platforms. They exist to catch unintended visual regressions locally, not to gate CI.

- [ ] **Step 1: Write the golden test**

`test/features/clock/dial_golden_test.dart`:

```dart
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:energy_clock/features/clock/widgets/dial_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

Widget harness({
  required List<CalendarEvent> events,
  required ThemeData theme,
}) {
  return ProviderScope(
    child: MaterialApp(
      theme: theme,
      home: Scaffold(
        body: SizedBox(
          width: 390,
          height: 390,
          child: DialView(
            events: events,
            day: DateTime(2026, 8, 23),
            readOnly: false,
          ),
        ),
      ),
    ),
  );
}

void main() {
  final events = [
    event(1, const MinuteRange(540, 720), Tone.focus, 'Deep work'),
    event(2, const MinuteRange(780, 840), Tone.life, 'Lunch'),
    event(3, const MinuteRange(1020, 1080), Tone.inbox, 'Email'),
  ];

  testWidgets('empty dial, light theme', (tester) async {
    await tester.pumpWidget(harness(events: const [], theme: AppTheme.light));
    await tester.pump();
    await expectLater(
      find.byType(DialView),
      matchesGoldenFile('goldens/dial_empty_light.png'),
    );
  });

  testWidgets('three tones, light theme', (tester) async {
    await tester.pumpWidget(harness(events: events, theme: AppTheme.light));
    await tester.pump();
    await expectLater(
      find.byType(DialView),
      matchesGoldenFile('goldens/dial_tones_light.png'),
    );
  });

  testWidgets('three tones, dark theme', (tester) async {
    await tester.pumpWidget(harness(events: events, theme: AppTheme.dark));
    await tester.pump();
    await expectLater(
      find.byType(DialView),
      matchesGoldenFile('goldens/dial_tones_dark.png'),
    );
  });

  testWidgets('overlapping events across three rings', (tester) async {
    await tester.pumpWidget(
      harness(
        events: [
          event(1, const MinuteRange(540, 720), Tone.focus, 'Deep work'),
          event(2, const MinuteRange(600, 660), Tone.life, 'Walk'),
          event(3, const MinuteRange(610, 630), Tone.inbox, 'Call'),
        ],
        theme: AppTheme.light,
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(DialView),
      matchesGoldenFile('goldens/dial_overlaps_light.png'),
    );
  });
}
```

- [ ] **Step 2: Generate the golden images**

```bash
flutter test --update-goldens test/features/clock/dial_golden_test.dart
```
Expected: four PNGs written under `test/features/clock/goldens/`.

- [ ] **Step 3: Open each golden and check it actually looks right**

Read the four PNGs. Confirm: numerals sit at 0/3/6/9/12/15/18/21 with 0 at the top; arcs are outside the face; labels curve along their arcs and are legible; the three overlapping events sit on three distinct rings; the dark golden is legible, not muddy.

If any of them look wrong, fix the painter and regenerate — a golden that pins a bug is worse than no golden.

- [ ] **Step 4: Re-run the goldens as real assertions**

```bash
flutter test test/features/clock/dial_golden_test.dart
```
Expected: PASS, 4 tests.

- [ ] **Step 5: Run the whole suite and analysis**

```bash
flutter test
```
Expected: PASS, all tests.

```bash
flutter analyze
```
Expected: "No issues found!"

- [ ] **Step 6: Run on the iPhone 17 Pro simulator**

Open the live simulator panel first, then launch:

```bash
flutter run -d "iPhone 17 Pro"
```

Walk through every Phase 1 behaviour by hand, because no test establishes whether the dial *looks* right:

1. The dial renders with 0 at the top and the now-hand pointing at the current time.
2. Drag around the orbit — a ghost arc follows, snapping in 5-minute steps, with haptic ticks; the centre shows the swept range.
3. Release — the sheet opens; pick a tone, type a title, save; the arc appears.
4. Drag a second event overlapping the first — it lands on ring 1.
5. Drag a third overlapping — ring 2. A fourth is refused with "Up to three overlapping events."
6. Tap an arc — the detail sheet opens; edit the title; delete with confirmation.
7. Drag an arc's middle to move it; drag an end to resize it.
8. Step to yesterday — the day is read-only, `+` is disabled, and the notice shows.
9. Step to tomorrow, then tap Today.
10. Switch the simulator to dark mode (Settings → Developer → Dark Appearance) and confirm the whole screen is legible.
11. Force-quit and relaunch — events persist.

- [ ] **Step 7: Capture screenshots for review**

Take simulator screenshots of the light dial with events, the dark dial, the event sheet, and the detail sheet. Share them before declaring the phase complete.

- [ ] **Step 8: Commit**

```bash
git add test/features/clock/dial_golden_test.dart test/features/clock/goldens
git commit -m "test: pin dial rendering with golden images"
```

---

## Phase 1 done when

- `flutter test` passes with every test above.
- `flutter analyze` reports no issues.
- The app runs on the iPhone 17 Pro simulator and every step of Task 18 Step 6 behaves as described.
- Screenshots have been shared and accepted.

Phase 2 (session timer, controls, notifications, crash recovery) gets its own plan.
