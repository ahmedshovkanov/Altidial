# Altidial Rename and Hidden Demo Mode — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the app to Altidial end-to-end and add a hidden six-second-hold debug mode that replaces all data with a deterministic three-month demo dataset.

**Architecture:** The rename is mechanical: package, imports, bundle id, display name, strings, database filename and docs. Demo mode is an app-level `lib/debug/` layer: a pure generator builds deterministic Drift companions, a transactional seeder wipes and inserts them, existing progress/roundup pipelines rebuild caches, and a Profile section plus a tab-bar hold drive activation, regeneration and exit.

**Tech Stack:** Flutter, Dart, Riverpod, Drift, flutter_test, existing theme/Strings conventions.

## Global Constraints

- App display name is exactly `Altidial`; bundle id is `com.selfloop.altidial`; package name is `altidial`.
- Demo hold duration is exactly six seconds, only on the Profile tab (index 3).
- Demo mode is available in every build; the wipe is always behind a destructive confirmation.
- Demo data covers exactly 90 local days ending today, generated with `Random(0xA17D1A1)`.
- Demo mode persists in the settings key `debug_mode`; Exit wipes every table and returns to onboarding.
- All debug UI copy lives in `lib/core/strings.dart`; demo content lives in `lib/debug/demo_data.dart`.
- Every colour comes from existing theme tokens; `test/architecture/no_hardcoded_colors_test.dart` must pass.
- Features never import each other. `lib/debug/` is app-level and may import `core/`, `data/`, `app/`, `shared/`.
- No new dependencies.
- Commands: `flutter analyze`, `flutter test`, and the Flutter SDK's `dart` for build_runner if generated code changes.
- Commit after each task.

---

### Task 1: Rename the app end-to-end

**Files:**
- Modify: `pubspec.yaml`
- Rename: `energy_clock.iml` → `altidial.iml`
- Modify: every Dart file importing `package:energy_clock/` under `lib/`, `test/`, `tool/`
- Modify: `lib/app/app.dart`, `lib/main.dart`, `lib/core/strings.dart`
- Modify: `lib/data/database.dart`
- Modify: `lib/features/session/session_screen.dart`
- Modify: `ios/Runner/Info.plist`
- Modify: `ios/Runner.xcodeproj/project.pbxproj`
- Modify: `README.md`
- Test: `test/architecture/rename_test.dart` (create), `test/ios/info_plist_test.dart`, `test/core/strings_test.dart`
- Test: `test/app/app_test.dart`, `test/app/settings_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: package `altidial`; `AltidialApp`; `Strings.appTitle == 'Altidial'`; bundle id `com.selfloop.altidial`; database file `altidial`.

- [x] **Step 1: Write the failing rename tests**

Create `test/architecture/rename_test.dart`:

```dart
import 'dart:io';

import 'package:energy_clock/core/strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the Dart package is altidial', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains(RegExp(r'^name: altidial$', multiLine: true)));
  });

  test('no Dart source imports energy_clock', () {
    final offenders = <String>[];
    for (final root in ['lib', 'test', 'tool']) {
      for (final entity in Directory(root).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.readAsStringSync().contains('package:energy_clock/')) {
          offenders.add(entity.path);
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('the app title is Altidial', () {
    expect(Strings.appTitle, 'Altidial');
    expect(Strings.settingsExportSubject, 'Altidial export');
  });
}
```

Update `test/ios/info_plist_test.dart` by adding:

```dart
  test('the app is named Altidial and uses the Altidial bundle id', () {
    expect(plist, contains('<key>CFBundleDisplayName</key>\n\t<string>Altidial</string>'));
    expect(plist, contains('<key>CFBundleName</key>\n\t<string>Altidial</string>'));
    final project = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(project, contains('PRODUCT_BUNDLE_IDENTIFIER = com.selfloop.altidial;'));
    expect(project, contains('PRODUCT_BUNDLE_IDENTIFIER = com.selfloop.altidial.RunnerTests;'));
    expect(project, isNot(contains('com.selfloop.energyClock')));
  });
```

Update `test/core/strings_test.dart`:

```dart
    expect(Strings.settingsExportSubject, 'Altidial export');
```

- [x] **Step 2: Run the tests to verify they fail**

Run:

```bash
flutter test test/architecture/rename_test.dart test/ios/info_plist_test.dart test/core/strings_test.dart
```

Expected: FAIL because the package, strings, plist and bundle id still say Energy Clock.

- [x] **Step 3: Rename the Dart package and imports**

Run:

```bash
perl -pi -e 's/^name: energy_clock$/name: altidial/' pubspec.yaml
grep -rl 'package:energy_clock/' lib test tool | xargs perl -pi -e 's/package:energy_clock\//package:altidial\//g'
mv energy_clock.iml altidial.iml
```

Then run `flutter pub get`.

- [x] **Step 4: Rename the app class and database file**

In `lib/app/app.dart`, rename `EnergyClockApp` to `AltidialApp` (constructor too). Update `lib/main.dart` to `const ProviderScope(child: AltidialApp())`. In `test/app/app_test.dart` and `test/app/settings_test.dart`, replace `EnergyClockApp` with `AltidialApp`.

In `lib/data/database.dart`, change:

```dart
AppDatabase() : super(driftDatabase(name: 'altidial'));
```

In `lib/features/session/session_screen.dart`, change `debugPrint('EnergyClock: ...')` to `debugPrint('Altidial: ...')`.

- [x] **Step 5: Update user-facing copy**

In `lib/core/strings.dart`:

```dart
  static const String appTitle = 'Altidial';
```

and replace `Energy Clock` in the onboarding body, session-ended body and export subject with `Altidial`.

- [x] **Step 6: Update the iOS identity**

In `ios/Runner/Info.plist`, set `CFBundleDisplayName` and `CFBundleName` to `Altidial`.

In `ios/Runner.xcodeproj/project.pbxproj`, replace every `com.selfloop.energyClock` with `com.selfloop.altidial`.

- [x] **Step 7: Update the README**

Rename the title to `# Altidial`, keep the tagline, and replace product-name mentions with Altidial. Add a short `## Demo mode` section: hold the Profile tab for six seconds, confirm, and use Profile → Debug to regenerate or exit.

- [x] **Step 8: Run rename tests and analyze**

Run:

```bash
flutter analyze
flutter test test/architecture/rename_test.dart test/ios/info_plist_test.dart test/core/strings_test.dart test/app/app_test.dart test/app/settings_test.dart
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "refactor: rename app to Altidial"
```

---

### Task 2: Add debug mode state and copy

**Files:**
- Create: `lib/debug/debug_constants.dart`
- Create: `lib/debug/debug_providers.dart`
- Modify: `lib/core/strings.dart`
- Test: `test/debug/debug_mode_test.dart` (create)

**Interfaces:**
- Consumes: `settingsRepositoryProvider`, `SettingsRepository`.
- Produces: `debugModeKey`, `debugHoldDuration`, `demoSeed`, `demoDayCount`; `debugModeProvider` (`AsyncNotifierProvider<DebugModeNotifier, bool>`) with `set(bool)`.

- [x] **Step 1: Write the failing test**

Create `test/debug/debug_mode_test.dart`:

```dart
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/debug/debug_constants.dart';
import 'package:energy_clock/debug/debug_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_settings_repository.dart';

void main() {
  test('debug mode defaults to off and persists when set', () async {
    final settings = FakeSettingsRepository();
    final container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
    );
    addTearDown(container.dispose);

    expect(await container.read(debugModeProvider.future), isFalse);
    await container.read(debugModeProvider.notifier).set(true);
    expect(container.read(debugModeProvider).valueOrNull, isTrue);
    expect(settings.values[debugModeKey], isTrue);

    await container.read(debugModeProvider.notifier).set(false);
    expect(settings.values[debugModeKey], isFalse);
  });
}
```

- [x] **Step 2: Run it to verify it fails**

Run: `flutter test test/debug/debug_mode_test.dart`

Expected: FAIL because the files do not exist.

- [x] **Step 3: Create the constants**

`lib/debug/debug_constants.dart`:

```dart
const String debugModeKey = 'debug_mode';
const Duration debugHoldDuration = Duration(seconds: 6);
const int demoDayCount = 90;
const int demoSeed = 0xA17D1A1;
```

- [x] **Step 4: Create the provider**

`lib/debug/debug_providers.dart`:

```dart
import 'package:altidial/data/providers.dart';
import 'package:altidial/debug/debug_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final debugModeProvider =
    AsyncNotifierProvider<DebugModeNotifier, bool>(DebugModeNotifier.new);

class DebugModeNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() =>
      ref.watch(settingsRepositoryProvider).getBool(debugModeKey);

  Future<void> set(bool value) async {
    await ref
        .read(settingsRepositoryProvider)
        .setBool(debugModeKey, value);
    state = AsyncData(value);
  }
}
```

- [x] **Step 5: Add the debug copy**

Append to `lib/core/strings.dart` before the final closing brace:

```dart
  // Debug / demo mode.
  static const String debugTitle = 'Debug';
  static const String debugStatusActive = 'Demo data is active';
  static const String debugStatusHint =
      'Three months of sample events, sessions and projects are loaded.';
  static const String debugEnableTitle = 'Load demo data?';
  static const String debugEnableBody =
      'All events, sessions, projects, tasks, reflections, templates, badges '
      'and settings will be erased and replaced with three months of demo '
      'data. This cannot be undone.';
  static const String debugEnableConfirm = 'Load demo data';
  static const String debugLoaded = 'Demo data loaded.';
  static const String debugAlreadyOn = 'Demo mode is already on.';
  static const String debugFailed = "Couldn't load demo data.";
  static const String debugRegenerate = 'Regenerate demo data';
  static const String debugRegenerateTitle = 'Regenerate demo data?';
  static const String debugRegenerateBody =
      'Current demo data will be erased and replaced with a fresh three-month '
      'dataset. This cannot be undone.';
  static const String debugRegenerateConfirm = 'Regenerate';
  static const String debugRegenerated = 'Demo data regenerated.';
  static const String debugExit = 'Exit debug mode';
  static const String debugExitTitle = 'Exit debug mode?';
  static const String debugExitBody =
      'All demo data and settings will be erased. The app will return to '
      'onboarding. This cannot be undone.';
  static const String debugExitConfirm = 'Exit and erase';
  static const String debugExited = 'Demo data erased.';
```

- [x] **Step 6: Run the test and analyze**

Run:

```bash
flutter test test/debug/debug_mode_test.dart
flutter analyze
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/debug lib/core/strings.dart test/debug
git commit -m "feat: add debug mode state and copy"
```

---

### Task 3: Detect a six-second hold on the Profile tab

**Files:**
- Modify: `lib/app/navigation/app_tab_bar.dart`
- Modify: `test/app/app_tab_bar_test.dart`

**Interfaces:**
- Consumes: `debugHoldDuration`.
- Produces: `AppTabBar.onProfileHold` callback that fires once per six-second hold on tab index 3.

- [x] **Step 1: Extend the tab-bar test harness and write failing tests**

Update `host` in `test/app/app_tab_bar_test.dart` to accept `onProfileHold`:

```dart
Widget host({
  required int selected,
  required ValueChanged<int> onSelected,
  VoidCallback? onProfileHold,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: AppTabBar(
          selectedIndex: selected,
          onSelected: onSelected,
          onProfileHold: onProfileHold,
        ),
      ),
    ),
  );
}
```

Add tests:

```dart
  testWidgets('holding Profile for six seconds fires the debug callback', (
    tester,
  ) async {
    var holds = 0;
    await tester.pumpWidget(
      host(selected: 0, onSelected: (_) {}, onProfileHold: () => holds++),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('tab-3'))),
    );
    await tester.pump(const Duration(milliseconds: 5900));
    expect(holds, 0);

    await tester.pump(const Duration(milliseconds: 200));
    expect(holds, 1);

    await gesture.up();
    await tester.pump();
  });

  testWidgets('releasing early cancels the hold', (tester) async {
    var holds = 0;
    await tester.pumpWidget(
      host(selected: 0, onSelected: (_) {}, onProfileHold: () => holds++),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('tab-3'))),
    );
    await tester.pump(const Duration(milliseconds: 5000));
    await gesture.up();
    await tester.pump(const Duration(seconds: 2));
    expect(holds, 0);
  });

  testWidgets('other tabs do not fire the debug callback', (tester) async {
    var holds = 0;
    await tester.pumpWidget(
      host(selected: 0, onSelected: (_) {}, onProfileHold: () => holds++),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('tab-2'))),
    );
    await tester.pump(const Duration(seconds: 7));
    await gesture.up();
    await tester.pump();
    expect(holds, 0);
  });
```

- [x] **Step 2: Run to verify they fail**

Run: `flutter test test/app/app_tab_bar_test.dart`

Expected: FAIL because `AppTabBar` has no `onProfileHold`.

- [x] **Step 3: Implement the hold listener**

In `lib/app/navigation/app_tab_bar.dart`, import `package:altidial/debug/debug_constants.dart`.

Add to `AppTabBar`:

```dart
  const AppTabBar({
    required this.selectedIndex,
    required this.onSelected,
    this.onProfileHold,
    super.key,
  });
```

and the field:

```dart
  final VoidCallback? onProfileHold;
```

Pass it to the Profile tab:

```dart
child: _TabItem(
  key: ValueKey('tab-$i'),
  label: _labels[i],
  position: i + 1,
  selected: i == selectedIndex,
  icon: (color) => _icon(i, i == selectedIndex, color),
  onTap: () => onSelected(i),
  onHold: i == 3 ? onProfileHold : null,
),
```

Add `onHold` to `_TabItem`:

```dart
  const _TabItem({
    required this.label,
    required this.position,
    required this.selected,
    required this.icon,
    required this.onTap,
    this.onHold,
    super.key,
  });

  final VoidCallback? onHold;
```

and wrap its `PressScale` in a `_HoldDetector`:

```dart
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final foreground = selected ? colors.onInk : colors.muted;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final press = PressScale(
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
    );

    return Semantics(
      button: true,
      selected: selected,
      label: Strings.tabSemantics(label, position, AppTabBar.tabCount),
      excludeSemantics: true,
      onTap: onTap,
      child: onHold == null
          ? press
          : _HoldDetector(onHold: onHold!, child: press),
    );
  }
```

Add at the end of the file:

```dart
class _HoldDetector extends StatefulWidget {
  const _HoldDetector({required this.onHold, required this.child});

  final VoidCallback onHold;
  final Widget child;

  @override
  State<_HoldDetector> createState() => _HoldDetectorState();
}

class _HoldDetectorState extends State<_HoldDetector> {
  Timer? _timer;
  bool _fired = false;

  void _down(PointerDownEvent event) {
    _timer?.cancel();
    _fired = false;
    _timer = Timer(debugHoldDuration, () {
      if (!mounted || _fired) return;
      _fired = true;
      widget.onHold();
    });
  }

  void _up(PointerEvent event) {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: widget.child,
    );
  }
}
```

- [x] **Step 4: Run the tests**

Run: `flutter test test/app/app_tab_bar_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/app/navigation/app_tab_bar.dart test/app/app_tab_bar_test.dart
git commit -m "feat: detect six-second Profile tab hold"
```

---

### Task 4: Build the deterministic demo dataset generator

**Files:**
- Create: `lib/debug/demo_data.dart`
- Create: `lib/debug/demo_generator.dart`
- Test: `test/debug/demo_generator_test.dart` (create)

**Interfaces:**
- Consumes: `Tone`, `SessionOutcome`, `EventStatus`, `startOfDay`, `startOfWeek`, `isNextCalendarDay`, Drift companions.
- Produces: `DemoDataset` with public lists; `DemoGenerator({DateTime Function()? now, int seed})` and `DemoDataset generate()`.

- [x] **Step 1: Write the failing generator tests**

Create `test/debug/demo_generator_test.dart`:

```dart
import 'package:altidial/core/session/session_outcome.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/debug/demo_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 22, 15, 30);
  DemoDataset build() => DemoGenerator(now: () => now).generate();

  test('generates 90 days ending today with all areas populated', () {
    final data = build();
    final days = data.events.map((e) => e.date.value).toSet();

    expect(data.projects, hasLength(5));
    expect(data.events, isNotEmpty);
    expect(data.sessions, isNotEmpty);
    expect(data.tasks.length, greaterThanOrEqualTo(20));
    expect(data.templates, hasLength(2));
    expect(data.templateItems, isNotEmpty);
    expect(data.intents, isNotEmpty);
    expect(data.reviews, isNotEmpty);
    expect(data.badgeUnlocks, isNotEmpty);
    expect(days, contains(startOfDay(now)));
    expect(days, contains(DateTime(2026, 7, 25)));
    expect(data.events.map((e) => e.toneIndex.value).toSet(), {0, 1, 2});
  });

  test('is deterministic for the same seed and clock', () {
    final a = build();
    final b = build();

    expect(a.events.map((e) => e.title.value).toList(),
        b.events.map((e) => e.title.value).toList());
    expect(a.sessions.map((s) => s.activeSeconds.value).toList(),
        b.sessions.map((s) => s.activeSeconds.value).toList());
    expect(a.badgeUnlocks.map((b) => b.badgeId.value).toList(),
        b.badgeUnlocks.map((b) => b.badgeId.value).toList());
  });

  test('past events have sessions and future events do not', () {
    final data = build();
    final eventById = {for (final e in data.events) e.id.value: e};

    for (final session in data.sessions) {
      final event = eventById[session.eventId.value]!;
      expect(event.date.value.isBefore(startOfDay(now)), isTrue,
          reason: 'session on ${event.date.value}');
      expect(session.endedAt.value.isBefore(now), isTrue);
    }

    final future = data.events.where(
      (e) => e.date.value.isAfter(startOfDay(now)),
    );
    expect(future, isNotEmpty);
    final futureIds = future.map((e) => e.id.value).toSet();
    expect(
      data.sessions.where((s) => futureIds.contains(s.eventId.value)),
      isEmpty,
    );
  });

  test('session times and outcomes are internally consistent', () {
    final data = build();
    for (final session in data.sessions) {
      final outcome = SessionOutcome.fromDbIndex(session.outcome.value);
      expect(outcome, isNot(SessionOutcome.running));
      expect(session.plannedSeconds.value, greaterThan(0));
      expect(session.activeSeconds.value, greaterThan(0));
      expect(session.endedAt.value.isAfter(session.startedAt.value), isTrue);
      if (outcome == SessionOutcome.completed) {
        expect(session.activeSeconds.value,
            greaterThanOrEqualTo(session.plannedSeconds.value));
      }
      if (outcome == SessionOutcome.finishedEarly) {
        expect(session.activeSeconds.value,
            lessThan(session.plannedSeconds.value));
      }
    }
  });

  test('no day needs more than three overlapping rings', () {
    final data = build();
    final byDay = <DateTime, List<(int, int)>>{};
    for (final event in data.events) {
      byDay.putIfAbsent(event.date.value, () => []).add(
        (event.startMinute.value, event.endMinute.value),
      );
    }
    for (final ranges in byDay.values) {
      final points = <(int, int)>[];
      for (final range in ranges) {
        points.add((range.$1, 1));
        points.add((range.$2, -1));
      }
      points.sort((a, b) => a.$1 == b.$1 ? a.$2.compareTo(b.$2) : a.$1.compareTo(b.$1));
      var active = 0;
      for (final point in points) {
        active += point.$2;
        expect(active, lessThanOrEqualTo(3));
      }
    }
  });

  test('today has completed and planned events', () {
    final data = build();
    final today = startOfDay(now);
    final todays = data.events.where((e) => e.date.value == today).toList();
    expect(todays, isNotEmpty);
    expect(todays.any((e) => e.status.value == 1), isTrue);
    expect(todays.any((e) => e.status.value == 0), isTrue);
  });

  test('tone indexes are valid', () {
    for (final event in build().events) {
      expect(() => Tone.fromDbIndex(event.toneIndex.value), returnsNormally);
    }
  });
}
```

- [x] **Step 2: Run to verify it fails**

Run: `flutter test test/debug/demo_generator_test.dart`

Expected: FAIL because `demo_generator.dart` does not exist.

- [x] **Step 3: Create the demo content pool**

`lib/debug/demo_data.dart`:

```dart
abstract final class DemoContent {
  static const List<String> focusTitles = [
    'Deep work',
    'Portfolio draft',
    'Write the proposal',
    'Design review',
    'Prepare the talk',
  ];

  static const List<String> inboxTitles = [
    'Email and admin',
    'Team stand-up',
    'Client calls',
    'Inbox zero',
    'Planning catch-up',
  ];

  static const List<String> lifeTitles = [
    'Lunch walk',
    'Gym',
    'School run',
    'Dinner prep',
    'Evening stretch',
  ];

  static const List<String> projectTitles = [
    'Launch portfolio',
    'Ship the beta',
    'Run 10k',
    'Home studio',
    'Read 12 books',
  ];

  static const List<String> taskTitles = [
    'Draft the outline',
    'Review the brief',
    'Book the venue',
    'Write the first chapter',
    'Sort the equipment',
    'Plan the sprint',
    'Send the update',
    'Test the flow',
  ];

  static const List<String> intentGoals = [
    'Finish the portfolio draft',
    'Ship the smallest useful slice',
    'Protect two deep-work blocks',
    'Clear the inbox before lunch',
  ];

  static const List<String> winTexts = [
    'Shipped the first slice',
    'Kept the morning focused',
    'Walked before the first call',
    'Finished the review',
  ];

  static const List<String> reflectionNotes = [
    'Clear goal helped.',
    'Too many interruptions.',
    'Good energy after lunch.',
    'Started slow, finished strong.',
  ];

  static const List<List<String>> reflectionTags = [
    ['flow', 'clear-goal'],
    ['interruptions', 'noisy'],
    ['tired', 'low-energy'],
    ['clear-goal'],
  ];
}
```

- [x] **Step 4: Create the generator**

`lib/debug/demo_generator.dart` with the following public shape:

```dart
class DemoDataset {
  const DemoDataset({
    required this.projects,
    required this.events,
    required this.sessions,
    required this.tasks,
    required this.templates,
    required this.templateItems,
    required this.intents,
    required this.reviews,
    required this.badgeUnlocks,
    required this.rangeStart,
    required this.rangeEnd,
  });

  final List<ProjectsCompanion> projects;
  final List<EventsCompanion> events;
  final List<SessionsCompanion> sessions;
  final List<TasksCompanion> tasks;
  final List<DayTemplatesCompanion> templates;
  final List<DayTemplateItemsCompanion> templateItems;
  final List<CoachIntentsCompanion> intents;
  final List<CoachReviewsCompanion> reviews;
  final List<BadgeUnlocksCompanion> badgeUnlocks;
  final DateTime rangeStart;
  final DateTime rangeEnd;
}

class DemoGenerator {
  DemoGenerator({DateTime Function()? now, int seed = demoSeed})
      : _now = now ?? DateTime.now,
        _seed = seed;

  final DateTime Function() _now;
  final int _seed;

  DemoDataset generate() {
    // Implementation follows the numbered algorithm below exactly.
    throw UnimplementedError();
  }
}
```

Implement `generate()` with this exact algorithm:

1. `final random = Random(_seed); final now = _now(); final today = startOfDay(now); final first = DateTime(today.year, today.month, today.day - (demoDayCount - 1));`
2. Build five `ProjectsCompanion` rows with ids 1–5:
   - `id: Value(i + 1)`, `title: Value(DemoContent.projectTitles[i])`.
   - `createdAt: Value(DateTime(first.year, first.month, first.day - 30))`.
   - `deadline: Value(i < 3 ? DateTime(today.year, today.month, today.day + 7 + i * 7) : DateTime(today.year, today.month, today.day - 10 - i))`.
   - `targetMinutes: Value(600 + i * 300)`, `toneIndex: Value(i % 3)`, `priority: Value(i % 4)`.
   - `status: Value(i == 3 ? 1 : i == 4 ? 2 : 0)`, `completedAt: Value(i == 3 ? DateTime(today.year, today.month, today.day - 5) : null)`.
   - `notes: Value('Demo project ${i + 1}')`.
3. Maintain counters `eventId = 1`, `sessionId = 1`, `taskId = 1`, `templateItemId = 1`.
4. Track:
   - `qualifying = <DateTime>{}`
   - `endedDates = <DateTime>[]`
   - `endedByWeek = <DateTime, int>{}`
   - `abandonedByWeek = <DateTime, int>{}`
   - `tonesByWeek = <DateTime, Set<int>>{}`
   - `focusSecondsByDay = <DateTime, int>{}`
   - `unlocked = <String>{}`
   - `earlyFocusDate`
5. Loop `offset` from 0 to 89:
   - `day = DateTime(first.year, first.month, first.day + offset)`.
   - `forceActive = offset >= 30 && offset <= 60`.
   - `isToday = day == today`.
   - If `!forceActive && !isToday && random.nextDouble() < 0.10`, continue (rest day).
   - Choose a plan with `_planFor(day, random, forceActive: forceActive, early: offset == 45)`:
     - Weekday plan (non-overlapping): 07:00–07:45 Life (only on the early day), 09:00–11:00 Focus, 11:15–11:45 Inbox, 12:15–13:00 Life, 14:00–15:30 Focus, 16:00–17:00 Inbox.
     - Weekend plan: 09:30–10:30 Life, 11:00–12:00 Focus, 17:00–18:00 Inbox.
     - On `forceActive`, keep at least the first Focus, Inbox and Life item.
     - On `early`, force a 07:00–08:30 Focus item and keep the 09:00–11:00 and 13:30–15:30 Focus items so the day clears four focus hours.
     - Attach `projectId` to Focus items: `1 + (offset % 5)`.
    - For each plan item, compute `start`/`end` `DateTime`; `past = end.isBefore(now)`.
    - If `past`, roll once:
      - `forceDone = (forceActive && item is one of the first three kept items) || offset == 45 || (isToday && past)`.
     - `roll = forceDone ? 0.0 : random.nextDouble()`.
     - `outcome = roll < 0.75 ? completed : roll < 0.85 ? finishedEarly : roll < 0.92 ? abandoned : null`.
     - When `outcome != null`, build a `SessionsCompanion`:
       - `plannedSeconds = (endMinute - startMinute) * 60`.
       - `activeSeconds`: completed = planned + `random.nextInt(11) * 60`; finishedEarly = `(planned * (0.5 + random.nextDouble() * 0.35)).round()`; abandoned = `(planned * (0.1 + random.nextDouble() * 0.4)).round()`.
        - `pausedSeconds = random.nextDouble() < 0.2 ? (random.nextInt(6) + 1) * 60 : 0`.
        - `startedAt = start + random.nextInt(6) minutes`.
        - When `isToday`, use `startedAt = start`, `activeSeconds = plannedSeconds`, and `pausedSeconds = 0` instead, so the session ends at `end`, strictly before `now`.
        - `endedAt = startedAt + activeSeconds + pausedSeconds`.
        - `overtimeSeconds = max(0, activeSeconds - plannedSeconds)`.
       - `status = outcome.countsAsDone ? EventStatus.completed.dbIndex : EventStatus.planned.dbIndex`.
       - `energyRating`/`focusRating`/`tagsCsv`/`note`: set on `outcome.countsAsDone && random.nextDouble() < 0.7`; ratings are `2 + random.nextInt(4)`; tags come from `DemoContent.reflectionTags`; note appears 25% of reflected sessions.
       - Add `endedDates.add(day)`, increment `endedByWeek[startOfWeek(day)]`, increment `abandonedByWeek` for abandoned, add tone to `tonesByWeek[startOfWeek(day)]` only when `countsAsDone`, and add `activeSeconds` to `focusSecondsByDay[day]` when tone is Focus and counts as done.
       - On counts-as-done, add `day` to `qualifying`; record `earlyFocusDate ??= day` when tone is Focus and `startedAt.hour < 8`.
   - Append the event companion with `status`, `isFlight: false`, flight columns null, `createdAt: Value(day)`, `updatedAt: Value(now)`.
6. Add a past flight on offset 20: event title `Flight LH715`, tone Inbox, 18:00–20:00, `isFlight: true`, `flightNumber: 'LH715'`, `fromCode: 'SOF'`, `toCode: 'FRA'`, status completed, plus one completed session and a reflection. Add upcoming flights at `today + 12` and `today + 40`, 10:00–12:00, planned, `BA921`/`SOF→LHR` and `AF1390`/`SOF→CDG`.
7. Build tasks: for each project, create 4 tasks (20 total). Cycle board statuses `0,1,2,3,4`, set `sortOrder` per project/status, estimates `30 + random.nextInt(8) * 15`, `dueDate` relative to today (some past, some future), `plannedDate` for Todo/Doing tasks as today or tomorrow, `completedAt` for Done tasks, `blockedReason: 'Waiting on a reply'` for Blocked.
8. Build two templates with ids 1 and 2:
   - Workday: `Deep work` Focus 540–660, `Email and admin` Inbox 660–705, `Lunch walk` Life 750–795.
   - Reset day: `Long walk` Life 600–690, `Reading` Focus 780–840, `Dinner prep` Life 1080–1140.
9. Build coach rows for offsets 60–89:
   - Intent on ~80% of days (`random.nextDouble() < 0.8`), plus today always.
   - Review on ~60% of days before today, plus yesterday always.
   - `predictedEnergy` 2–5, `energy` 2–5.
10. After the loop, add badge unlocks:
    - `first_session`, `sessions_10`, `sessions_50`, `sessions_100` at the sorted `endedDates` indexes 0, 9, 49, 99 when present.
    - `focus_day_4h` at the first day where `focusSecondsByDay >= 4 * 3600`.
    - `week_all_tones` at the Sunday of the first week with all three tones, capped at today.
    - `week_no_abandoned` at the Sunday of the first finished week with ended sessions and zero abandoned.
    - `early_bird` at `earlyFocusDate`.
    - `streak_7` and `streak_30` by walking sorted `qualifying` with `isNextCalendarDay`; unlock at the day the run first reaches 7/30.
    - Only add each id once.
11. Return `DemoDataset(...)` with `rangeStart: first`, `rangeEnd: today`.

Add the private `_PlanItem` record/class:

```dart
class _PlanItem {
  const _PlanItem({
    required this.title,
    required this.tone,
    required this.startMinute,
    required this.endMinute,
    this.projectId,
  });

  final String title;
  final Tone tone;
  final int startMinute;
  final int endMinute;
  final int? projectId;
}
```

- [x] **Step 5: Run the generator tests**

Run: `flutter test test/debug/demo_generator_test.dart`

Expected: PASS. If the "today has completed and planned" test fails, adjust today's plan so the first item ends before `now` and the last item ends after `now`; the generator must not seed a session for an item that ends after `now`.

- [ ] **Step 6: Commit**

```bash
git add lib/debug/demo_data.dart lib/debug/demo_generator.dart test/debug/demo_generator_test.dart
git commit -m "feat: add deterministic demo data generator"
```

---

### Task 5: Add the transactional demo seeder and provider

**Files:**
- Create: `lib/debug/demo_seeder.dart`
- Modify: `lib/debug/debug_providers.dart`
- Test: `test/debug/demo_seeder_test.dart` (create)

**Interfaces:**
- Consumes: `AppDatabase`, `DemoGenerator`, `SettingsRepository`, `ProgressRepository`, `RoundupRepository`, `onboardingDoneKey`.
- Produces: `abstract interface class DemoSeeder { Future<void> seed(); }`; `DriftDemoSeeder`; `demoGeneratorProvider`; `demoSeederProvider`.

- [x] **Step 1: Write the failing seeder tests**

Create `test/debug/demo_seeder_test.dart`:

```dart
import 'package:altidial/app/onboarding/onboarding_providers.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/repositories/progress_repository.dart';
import 'package:altidial/data/repositories/roundup_repository.dart';
import 'package:altidial/data/repositories/settings_repository.dart';
import 'package:altidial/debug/debug_constants.dart';
import 'package:altidial/debug/demo_generator.dart';
import 'package:altidial/debug/demo_seeder.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftSettingsRepository settings;
  final now = DateTime(2026, 10, 22, 15, 30);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    settings = DriftSettingsRepository(db.settingsDao);
  });

  tearDown(() async => db.close());

  DriftDemoSeeder seeder() => DriftDemoSeeder(
    db,
    DemoGenerator(now: () => now),
    settings,
    DriftProgressRepository(db, now: () => now),
    DriftRoundupRepository(db, now: () => now),
  );

  test('wipes existing data and seeds every feature', () async {
    await db.eventDao.insertEvent(
      EventsCompanion.insert(
        date: DateTime(2026, 10, 21),
        title: 'Real event',
        toneIndex: 0,
        startMinute: 540,
        endMinute: 600,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await seeder().seed();

    final events = await db.eventDao.eventsBetween(
      DateTime(2020),
      DateTime(2030),
    );
    expect(events.where((e) => e.title == 'Real event'), isEmpty);
    expect(events, isNotEmpty);
    expect(await db.projectDao.allProjects(), hasLength(5));
    expect(await db.taskDao.watchAll().first, isNotEmpty);
    expect(await db.sessionDao.endedSessions(), isNotEmpty);
    expect(await db.coachDao.watchIntent(DateTime(2026, 10, 22)).first, isNotNull);
    expect(await db.coachDao.watchReview(DateTime(2026, 10, 21)).first, isNotNull);
    expect((await db.roundupDao.archive()), isNotEmpty);
    expect(await db.progressDao.progressRow(), isNotNull);
    expect(await settings.getBool(debugModeKey), isTrue);
    expect(await settings.getBool(onboardingDoneKey), isTrue);
  });

  test('rolls back when a raw insert fails and leaves previous data alone', () async {
    await db.eventDao.insertEvent(
      EventsCompanion.insert(
        date: DateTime(2026, 10, 21),
        title: 'Keep me',
        toneIndex: 0,
        startMinute: 540,
        endMinute: 600,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final failing = DriftDemoSeeder(
      db,
      _DuplicateIdGenerator(now),
      settings,
      DriftProgressRepository(db, now: () => now),
      DriftRoundupRepository(db, now: () => now),
    );

    await expectLater(failing.seed(), throwsA(anything));
    final events = await db.eventDao.eventsBetween(
      DateTime(2020),
      DateTime(2030),
    );
    expect(events.map((e) => e.title), contains('Keep me'));
    expect(await settings.getBool(debugModeKey), isFalse);
  });
}

class _DuplicateIdGenerator extends DemoGenerator {
  _DuplicateIdGenerator(DateTime now) : super(now: () => now);

  @override
  DemoDataset generate() {
    final data = super.generate();
    return DemoDataset(
      projects: [data.projects.first, data.projects.first],
      events: const [],
      sessions: const [],
      tasks: const [],
      templates: const [],
      templateItems: const [],
      intents: const [],
      reviews: const [],
      badgeUnlocks: const [],
      rangeStart: data.rangeStart,
      rangeEnd: data.rangeEnd,
    );
  }
}
```

- [x] **Step 2: Run to verify it fails**

Run: `flutter test test/debug/demo_seeder_test.dart`

Expected: FAIL because `demo_seeder.dart` does not exist.

- [x] **Step 3: Implement the seeder**

`lib/debug/demo_seeder.dart`:

```dart
import 'package:altidial/app/onboarding/onboarding_providers.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/repositories/progress_repository.dart';
import 'package:altidial/data/repositories/roundup_repository.dart';
import 'package:altidial/data/repositories/settings_repository.dart';
import 'package:altidial/debug/debug_constants.dart';
import 'package:altidial/debug/demo_generator.dart';
import 'package:flutter/foundation.dart';

abstract interface class DemoSeeder {
  Future<void> seed();
}

class DriftDemoSeeder implements DemoSeeder {
  DriftDemoSeeder(
    this._db,
    this._generator,
    this._settings,
    this._progress,
    this._roundups,
  );

  final AppDatabase _db;
  final DemoGenerator _generator;
  final SettingsRepository _settings;
  final ProgressRepository _progress;
  final RoundupRepository _roundups;

  @override
  Future<void> seed() async {
    final data = _generator.generate();

    await _db.transaction(() async {
      await _db.resetAll();
      await _db.batch((batch) {
        batch.insertAll(_db.projects, data.projects);
        batch.insertAll(_db.events, data.events);
        batch.insertAll(_db.sessions, data.sessions);
        batch.insertAll(_db.tasks, data.tasks);
        batch.insertAll(_db.dayTemplates, data.templates);
        batch.insertAll(_db.dayTemplateItems, data.templateItems);
        batch.insertAll(_db.coachIntents, data.intents);
        batch.insertAll(_db.coachReviews, data.reviews);
        batch.insertAll(_db.badgeUnlocks, data.badgeUnlocks);
      });
      await _settings.setBool(onboardingDoneKey, true);
      await _settings.setBool(debugModeKey, true);
    });

    try {
      await _progress.recalculateAll();
    } on Object catch (error) {
      debugPrint('Altidial: demo progress rebuild failed: $error');
    }
    try {
      await _roundups.ensureCurrent();
    } on Object catch (error) {
      debugPrint('Altidial: demo roundup rebuild failed: $error');
    }
  }
}
```

- [x] **Step 4: Add the providers**

Append to `lib/debug/debug_providers.dart`:

```dart
final demoGeneratorProvider = Provider<DemoGenerator>((ref) {
  return DemoGenerator();
});

final demoSeederProvider = Provider<DemoSeeder>((ref) {
  return DriftDemoSeeder(
    ref.watch(appDatabaseProvider),
    ref.watch(demoGeneratorProvider),
    ref.watch(settingsRepositoryProvider),
    ref.watch(progressRepositoryProvider),
    ref.watch(roundupRepositoryProvider),
  );
});
```

Add imports for `DemoGenerator`, `DemoSeeder` and `DriftDemoSeeder`.

- [x] **Step 5: Run the seeder tests**

Run: `flutter test test/debug/demo_seeder_test.dart`

Expected: PASS. If the duplicate-id generator does not fail, make `_DuplicateIdGenerator` return two project rows with the same `id` and assert the batch fails.

- [ ] **Step 6: Commit**

```bash
git add lib/debug/demo_seeder.dart lib/debug/debug_providers.dart test/debug/demo_seeder_test.dart
git commit -m "feat: add transactional demo seeder"
```

---

### Task 6: Add the debug actions, Debug section and tab wiring

**Files:**
- Create: `lib/debug/debug_actions.dart`
- Create: `lib/debug/widgets/debug_section.dart`
- Modify: `lib/app/navigation/tab_scaffold.dart`
- Modify: `lib/features/progress/profile_screen.dart`
- Test: `test/debug/debug_actions_test.dart` (create)
- Modify: `test/app/tab_scaffold_test.dart`

**Interfaces:**
- Consumes: `debugModeProvider`, `demoSeederProvider`, `debugModeKey`, `Strings`, `confirmDestructive`, `onboardingDoneProvider`, `appDatabaseProvider`.
- Produces: `activateDebug(BuildContext, WidgetRef)`, `regenerateDemo(BuildContext, WidgetRef)`, `exitDebug(BuildContext, WidgetRef)`; `DebugSection` widget; `TabScaffold` holds `AppTabBar.onProfileHold`.

- [x] **Step 1: Write the failing action tests**

Create `test/debug/debug_actions_test.dart`:

```dart
import 'dart:async';

import 'package:altidial/app/onboarding/onboarding_providers.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/data/repositories/progress_repository.dart';
import 'package:altidial/data/repositories/roundup_repository.dart';
import 'package:altidial/debug/debug_actions.dart';
import 'package:altidial/debug/debug_constants.dart';
import 'package:altidial/debug/debug_providers.dart';
import 'package:altidial/debug/demo_seeder.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_progress_repository.dart';
import '../support/fake_roundup_repository.dart';
import '../support/fake_settings_repository.dart';

void main() {
  late FakeSettingsRepository settings;
  late _FakeSeeder seeder;
  late AppDatabase db;

  setUp(() {
    settings = FakeSettingsRepository();
    seeder = _FakeSeeder();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  Widget host(Widget child, {List<Override> extra = const []}) {
    return ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        appDatabaseProvider.overrideWithValue(db),
        demoSeederProvider.overrideWithValue(seeder),
        progressRepositoryProvider.overrideWithValue(FakeProgressRepository()),
        roundupRepositoryProvider.overrideWithValue(FakeRoundupRepository()),
        ...extra,
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('activate confirms, seeds and turns debug mode on', (tester) async {
    late WidgetRef ref;
    await tester.pumpWidget(
      host(
        Consumer(
          builder: (context, r, _) {
            ref = r;
            return TextButton(
              onPressed: () => activateDebug(context, r),
              child: const Text('activate'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('activate'));
    await tester.pumpAndSettle();
    expect(find.text('Load demo data?'), findsOneWidget);

    await tester.tap(find.text('Load demo data'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(seeder.calls, 1);
    expect(settings.values[debugModeKey], isTrue);
    expect(settings.values[onboardingDoneKey], isTrue);
    expect(ref.read(debugModeProvider).valueOrNull, isTrue);
  });

  testWidgets('regenerate seeds again and keeps debug mode on', (tester) async {
    settings.values[debugModeKey] = true;
    await tester.pumpWidget(
      host(
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => regenerateDemo(context, ref),
            child: const Text('regenerate'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('regenerate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Regenerate'));
    await tester.pumpAndSettle();

    expect(seeder.calls, 1);
    expect(settings.values[debugModeKey], isTrue);
  });

  testWidgets('exit wipes every table and returns to onboarding', (tester) async {
    settings.values[debugModeKey] = true;
    settings.values[onboardingDoneKey] = true;
    await db.eventDao.insertEvent(
      EventsCompanion.insert(
        date: DateTime(2026, 10, 21),
        title: 'Delete me',
        toneIndex: 0,
        startMinute: 540,
        endMinute: 600,
        createdAt: DateTime(2026, 10, 21),
        updatedAt: DateTime(2026, 10, 21),
      ),
    );

    late WidgetRef ref;
    await tester.pumpWidget(
      host(
        Consumer(
          builder: (context, r, _) {
            ref = r;
            return TextButton(
              onPressed: () => exitDebug(context, r),
              child: const Text('exit'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('exit'));
    await tester.pumpAndSettle();
    expect(find.text('Exit debug mode?'), findsOneWidget);

    await tester.tap(find.text('Exit and erase'));
    await tester.pumpAndSettle();

    expect(await db.eventDao.eventsBetween(DateTime(2020), DateTime(2030)), isEmpty);
    expect(await ref.read(debugModeProvider.future), isFalse);
    expect(await ref.read(onboardingDoneProvider.future), isFalse);
  });
}

class _FakeSeeder implements DemoSeeder {
  int calls = 0;

  @override
  Future<void> seed() async {
    calls++;
  }
}
```

- [x] **Step 2: Run to verify it fails**

Run: `flutter test test/debug/debug_actions_test.dart`

Expected: FAIL because `debug_actions.dart` does not exist.

- [x] **Step 3: Implement the actions**

`lib/debug/debug_actions.dart`:

```dart
import 'dart:async';

import 'package:altidial/app/onboarding/onboarding_providers.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/debug/debug_constants.dart';
import 'package:altidial/debug/debug_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> activateDebug(BuildContext context, WidgetRef ref) async {
  final active = ref.read(debugModeProvider).valueOrNull ?? false;
  if (active) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(Strings.debugAlreadyOn)),
    );
    return;
  }
  final confirmed = await confirmDestructive(
    context,
    title: Strings.debugEnableTitle,
    body: Strings.debugEnableBody,
    confirmLabel: Strings.debugEnableConfirm,
    cancelLabel: Strings.cancel,
  );
  if (!confirmed || !context.mounted) return;
  await _seed(context, ref, Strings.debugLoaded);
}

Future<void> regenerateDemo(BuildContext context, WidgetRef ref) async {
  final confirmed = await confirmDestructive(
    context,
    title: Strings.debugRegenerateTitle,
    body: Strings.debugRegenerateBody,
    confirmLabel: Strings.debugRegenerateConfirm,
    cancelLabel: Strings.cancel,
  );
  if (!confirmed || !context.mounted) return;
  await _seed(context, ref, Strings.debugRegenerated);
}

Future<void> exitDebug(BuildContext context, WidgetRef ref) async {
  final confirmed = await confirmDestructive(
    context,
    title: Strings.debugExitTitle,
    body: Strings.debugExitBody,
    confirmLabel: Strings.debugExitConfirm,
    cancelLabel: Strings.cancel,
  );
  if (!confirmed || !context.mounted) return;

  await ref.read(appDatabaseProvider).resetAll();
  await ref.read(debugModeProvider.notifier).set(false);
  ref.invalidate(onboardingDoneProvider);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text(Strings.debugExited)),
  );
}

Future<void> _seed(BuildContext context, WidgetRef ref, String success) async {
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator.adaptive()),
    ),
  ));

  try {
    await ref.read(demoSeederProvider).seed();
    await ref.read(settingsRepositoryProvider).setBool(onboardingDoneKey, true);
    await ref.read(debugModeProvider.notifier).set(true);
    ref.invalidate(onboardingDoneProvider);
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success)),
    );
  } on Object {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(Strings.debugFailed)),
    );
  }
}
```

- [x] **Step 4: Implement the Debug section**

`lib/debug/widgets/debug_section.dart`:

```dart
import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/debug/debug_actions.dart';
import 'package:altidial/debug/debug_providers.dart';
import 'package:altidial/shared/widgets/app_card.dart';
import 'package:altidial/shared/widgets/section_header.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DebugSection extends ConsumerWidget {
  const DebugSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(debugModeProvider).valueOrNull ?? false;
    if (!active) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: Strings.debugTitle),
            const SizedBox(height: AppSpacing.sm),
            Text(
              Strings.debugStatusActive,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              Strings.debugStatusHint,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: colors.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _DebugRow(
              label: Strings.debugRegenerate,
              onTap: () => regenerateDemo(context, ref),
            ),
            _DebugRow(
              label: Strings.debugExit,
              destructive: true,
              onTap: () => exitDebug(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebugRow extends StatelessWidget {
  const _DebugRow({
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.control),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge!.copyWith(
                  color: destructive ? colors.danger : null,
                ),
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 18, color: colors.muted),
          ],
        ),
      ),
    );
  }
}
```

- [x] **Step 5: Wire the Profile screen**

In `lib/features/progress/profile_screen.dart`, import `package:altidial/debug/widgets/debug_section.dart` and add after `const SettingsCard(),`:

```dart
            const DebugSection(),
```

Do not add a `SizedBox` after it; `DebugSection` supplies its own top padding and returns zero when inactive.

- [x] **Step 6: Wire TabScaffold**

In `lib/app/navigation/tab_scaffold.dart`, import `dart:async`, `package:altidial/core/strings.dart`, `package:altidial/debug/debug_actions.dart` and `package:altidial/debug/debug_providers.dart`.

Add:

```dart
  void _onProfileHold() {
    final active = ref.read(debugModeProvider).valueOrNull ?? false;
    if (active) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(Strings.debugAlreadyOn)),
      );
      return;
    }
    unawaited(activateDebug(context, ref));
  }
```

Pass it to the bar:

```dart
            child: AppTabBar(
              selectedIndex: _index,
              onSelected: _select,
              onProfileHold: _onProfileHold,
            ),
```

- [x] **Step 7: Update tab-scaffold tests for the new callback**

In `test/app/tab_scaffold_test.dart`, add a test that uses `FakeSettingsRepository` values `{onboardingDoneKey: true}` and a `demoSeederProvider` override, holds `tab-3` for six seconds, taps `Strings.debugEnableConfirm`, and asserts the fake seeder ran and `debug_mode` is true. Also add a test that with `debug_mode: true` the Profile tab shows `Strings.debugTitle` and `Strings.debugExit`.

<original_code>
import 'package:altidial/app/onboarding/onboarding_providers.dart';
import 'package:altidial/debug/debug_constants.dart';
import 'package:altidial/debug/debug_providers.dart';
import 'package:altidial/debug/demo_seeder.dart';
</original_code>

Add a mutable settings fake and an optional seeder to the harness:

<original_code>
  late FakeSettingsRepository settings;

  setUp(() {
    settings = FakeSettingsRepository();
    repository = FakeEventRepository();
    sessions = FakeSessionRepository(events: repository, clock: DateTime.now);
  });

  Widget harness({DemoSeeder? seeder}) {
    return ProviderScope(
      overrides: [
        eventRepositoryProvider.overrideWithValue(repository),
        calendarRepositoryProvider.overrideWithValue(
          FakeCalendarRepository(repository),
        ),
        sessionRepositoryProvider.overrideWithValue(sessions),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        settingsRepositoryProvider.overrideWithValue(settings),
        statsRepositoryProvider.overrideWithValue(FakeStatsRepository()),
        progressRepositoryProvider.overrideWithValue(FakeProgressRepository()),
        roundupRepositoryProvider.overrideWithValue(FakeRoundupRepository()),
        if (seeder != null) demoSeederProvider.overrideWithValue(seeder),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const TabScaffold()),
    );
  }
</original_code>

Add the tests and the counting seeder:

<original_code>
  testWidgets('holding Profile for six seconds can load demo data', (
    tester,
  ) async {
    final seeder = _CountingSeeder();
    await tester.pumpWidget(harness(seeder: seeder));
    await pumpDial(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('tab-3'))),
    );
    await tester.pump(const Duration(seconds: 7));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text(Strings.debugEnableTitle), findsOneWidget);
    await tester.tap(find.text(Strings.debugEnableConfirm));
    await tester.pumpAndSettle();

    expect(seeder.calls, 1);
    expect(settings.values[debugModeKey], isTrue);
    expect(settings.values[onboardingDoneKey], isTrue);
  });

  testWidgets('debug mode shows the Debug section on Profile', (tester) async {
    settings.values[debugModeKey] = true;
    await tester.pumpWidget(harness());
    await pumpDial(tester);

    await tester.tap(find.byKey(const ValueKey('tab-3')));
    await pumpDial(tester);

    expect(find.text(Strings.debugTitle), findsOneWidget);
    expect(find.text(Strings.debugExit), findsOneWidget);
  });
}

class _CountingSeeder implements DemoSeeder {
  int calls = 0;

  @override
  Future<void> seed() async {
    calls++;
  }
}
</original_code>

- [x] **Step 8: Run the action and tab tests**

Run:

```bash
flutter test test/debug/debug_actions_test.dart test/app/tab_scaffold_test.dart
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/debug lib/features/progress/profile_screen.dart lib/app/navigation/tab_scaffold.dart test/debug test/app/tab_scaffold_test.dart
git commit -m "feat: wire hidden demo mode into Profile and tab bar"
```

---

### Task 7: Full regression, docs and manual verification

**Files:**
- Modify: `README.md` if not already complete
- Modify: any tests broken by the rename or new imports
- No production code changes expected beyond fixes found by the gates

**Interfaces:**
- Consumes: everything above.
- Produces: a green `flutter analyze` and `flutter test`, and a manual smoke checklist.

- [x] **Step 1: Run formatting and analysis**

Run:

```bash
dart format lib test tool
flutter analyze
```

Expected: no analyzer errors. Fix warnings introduced by the plan; do not suppress them globally.

- [x] **Step 2: Run the full test suite**

Run: `flutter test`

Expected: all tests pass. Goldens should be unchanged because the debug section is conditional and the tab bar has no new pixels. If a golden changes, inspect the failure images before considering `--update-goldens`; only regenerate for an intentional visual change.

- [x] **Step 3: Verify no stale names**

Run:

```bash
rg -n 'Energy Clock|EnergyClock|energy_clock' lib test tool ios README.md pubspec.yaml
```

Expected: no results in current source/config. Historical files under `docs/superpowers/specs/` and `plans/` may keep the old name on purpose.

- [ ] **Step 4: Manual simulator smoke test**

On a simulator:

1. Launch the app, reach Profile.
2. Hold the Profile tab for six seconds; confirm the dialog appears.
3. Confirm; verify the Clock, Calendar, Projects, Stats/Profile and Deck screens show three months of data.
4. Open Profile → Debug; tap Regenerate and confirm; verify data is still present.
5. Tap Exit; confirm the app returns to onboarding.
6. Skip onboarding; verify the app is empty and the Debug section is gone.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "test: verify Altidial rename and demo mode"
```

---

## Plan Self-Review

- **Spec coverage:** Rename (Task 1), debug state and copy (Task 2), six-second hold (Task 3), deterministic generator (Task 4), transactional seeder and derived caches (Task 5), confirmation/debug section/exit flow (Task 6), verification (Task 7). All spec sections map to a task.
- **Placeholder scan:** No TBD/TODO. The generator algorithm is described step by step with exact counts, times, ranges and thresholds; the seeder and UI code are provided.
- **Type consistency:** `DemoDataset`, `DemoGenerator.generate()`, `DemoSeeder.seed()`, `debugModeProvider`, `activateDebug`, `regenerateDemo`, `exitDebug`, and `AppTabBar.onProfileHold` are defined once and reused with the same signatures.
