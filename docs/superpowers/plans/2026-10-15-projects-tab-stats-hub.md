# Projects Tab + Stats Hub Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Promote Projects to the 2nd tab and move Stats into Profile as a pushed hub, keeping 5 tabs total.

**Architecture:** Swap `AppTabBar` labels/icons and `TabScaffold` screen mapping; convert `ProjectsScreen` hub body into a tab root (no nested Scaffold/AppBar); wrap existing `StatsScreen` body in a pushed `StatsHub` Scaffold; replace Profile `ProjectsCard` with `StatsCard`.

**Tech Stack:** Flutter 3.x, Riverpod 2.x, Drift, CupertinoIcons for tab icons, existing theme tokens + `Strings`.

## Global Constraints

- Tab count stays 5: Clock, Projects, Calendar, Profile, Deck in that order.
- Features never import each other; features import only `data/`, `core/`, `app/`, `shared/`.
- All user copy in `lib/core/strings.dart`; no hardcoded copy in widgets.
- All colors via theme tokens; the no-hardcoded-colour test must keep passing.
- `flutter analyze` and `flutter test` must pass; golden regen only after deliberate visual change + image review.
- Drift codegen with the Flutter SDK's `dart`: `"$(dirname "$(which flutter)")/dart" run build_runner build --delete-conflicting-outputs`.

---

### Task 1: Tab bar + scaffold swap

**Files:**
- Modify: `lib/app/navigation/app_tab_bar.dart`
- Modify: `lib/app/navigation/tab_scaffold.dart`
- Test: `test/app/tab_scaffold_test.dart` (create if missing; check `test/` for existing tab tests first)

**Interfaces:**
- Consumes: existing `ClockTab`, `CalendarTab`, `ProfileScreen`, `FlightDeckScreen`, new `ProjectsTabBody` from Task 2 (`ProjectsTabBody({required ValueChanged<DateTime> onOpenDay})`).
- Produces: `AppTabBar.tabCount == 5`, `AppTabBar` labels `[Clock, Projects, Calendar, Profile, Deck]`, `TabScaffold._screen(1)` returns Projects tab root.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:energy_clock/app/navigation/app_tab_bar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tab bar stays at five with Projects second', () {
    expect(AppTabBar.tabCount, 5);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/app/tab_scaffold_test.dart -v`
Expected: FAIL if file missing, or PASS on count but labels still old — extend test to pump `AppTabBar` and expect `Projects` second:

```dart
await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AppTabBar(selectedIndex: 1, onSelected: (_) {}))));
expect(find.text('Projects'), findsOneWidget);
expect(find.text('Stats'), findsNothing);
```

Run again, expect FAIL with "Stats still present / Projects missing".

- [ ] **Step 3: Write minimal implementation**

In `lib/app/navigation/app_tab_bar.dart`, replace `_labels`:

```dart
static const List<String> _labels = [
  Strings.tabClock,
  Strings.projectsTitle,
  Strings.tabCalendar,
  Strings.tabProfile,
  Strings.tabDeck,
];
```

Replace `_icon`:

```dart
Widget _icon(int index, bool selected, Color color) => switch (index) {
  0 => TabDialIcon(selected: selected, color: color),
  1 => Icon(selected ? CupertinoIcons.folder_fill : CupertinoIcons.folder, color: color, size: 24),
  2 => Icon(CupertinoIcons.calendar, color: color, size: 24),
  3 => Icon(selected ? CupertinoIcons.person_fill : CupertinoIcons.person, color: color, size: 24),
  _ => Icon(CupertinoIcons.airplane, color: color, size: 24),
};
```

Add to `lib/core/strings.dart` if missing:

```dart
static const String tabDeck = 'Deck';
```

(`tabDeck` already exists; `projectsTitle` already exists — reuse, do not duplicate.)

In `lib/app/navigation/tab_scaffold.dart`, update `_screen`:

```dart
Widget _screen(int index) => switch (index) {
  0 => const ClockTab(),
  1 => ProjectsTabBody(onOpenDay: _openDay),
  2 => CalendarTab(onOpenDay: _openDay),
  3 => const ProfileScreen(),
  _ => FlightDeckScreen(onOpenDay: _openDay),
};
```

Note: `ProjectsTabBody` is created in Task 2. For this task to compile, create the empty `ProjectsTabBody` stub in this task at `lib/features/projects/projects_screen.dart` with a `Center(child: Text(Strings.projectsTitle))` body — Task 2 replaces the stub body with the full implementation.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter analyze`
Expected: PASS with no new lints.

Run: `flutter test test/app/tab_scaffold_test.dart -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/app/navigation/app_tab_bar.dart lib/app/navigation/tab_scaffold.dart test/app/tab_scaffold_test.dart
git commit -m "feat: swap tab bar to Clock Projects Calendar Profile Deck"
```

### Task 2: Projects tab root body

**Files:**
- Modify: `lib/features/projects/projects_screen.dart`
- Test: `test/features/projects/projects_tab_test.dart`

**Interfaces:**
- Consumes: `projectListProvider`, `projectDetailProvider(id)` from `lib/features/projects/providers.dart`; `selectedDateProvider` from `lib/features/clock/providers.dart`; `showCreateProjectDialog` (same file).
- Produces: `ProjectsTabBody({required ValueChanged<DateTime> onOpenDay})` — tab-safe body (no `Scaffold`/`AppBar`), used by `TabScaffold._screen(1)`. `ProjectDetailView` push path unchanged.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:energy_clock/features/projects/projects_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('projects tab renders without nested AppBar', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: ProjectsTabBody(onOpenDay: _noop))));
    await tester.pump();
    expect(find.text('Projects'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
  });
}

void _noop(DateTime _) {}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/projects/projects_tab_test.dart -v`
Expected: FAIL with "ProjectsTabBody not defined".

- [ ] **Step 3: Write minimal implementation**

In `lib/features/projects/projects_screen.dart`, extract the existing `_HubBody` into a public tab body. Keep `ProjectsScreen` (pushed hub with `Scaffold`/`AppBar`) for backward compat during migration, then repoint `TabScaffold` to the new body:

```dart
class ProjectsTabBody extends ConsumerWidget {
  const ProjectsTabBody({required this.onOpenDay, super.key});
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectListProvider);
    return projects.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      skipError: true,
      data: (rows) => _HubBody(rows: rows, onOpenDay: onOpenDay),
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(Strings.projectsLoadError, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => ref.invalidate(projectListProvider),
                child: const Text(Strings.deckRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Add header row inside `_HubBody` top (title + New button):

```dart
Row(
  children: [
    Expanded(child: Text(Strings.projectsTitle, style: Theme.of(context).textTheme.titleLarge)),
    TextButton(
      onPressed: () => showCreateProjectDialog(context, ref),
      child: const Text(Strings.projectNew),
    ),
  ],
),
```

`_HubBody` keeps `SingleChildScrollView` with `TabBarInset.of(context) + AppSpacing.xl` bottom padding (resolves correctly inside tab shell; 0 when pushed).

Update `TabScaffold._openDay` usage: `ProjectsTabBody(onOpenDay: _openDay)` where `_openDay` already does `ref.read(selectedDateProvider.notifier).select(day); _select(0);`. Remove the old `popUntil(first)` closure from `ProjectsCard` path (Task 3).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/projects/projects_tab_test.dart test/features/projects/projects_screen_test.dart -v` (second file if exists; otherwise first only)
Expected: PASS.

Run: `flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/projects/projects_screen.dart test/features/projects/projects_tab_test.dart
git commit -m "feat: add ProjectsTabBody tab root without nested AppBar"
```

### Task 3: Profile StatsCard + StatsHub push

**Files:**
- Create: `lib/features/stats/stats_hub.dart`
- Create: `lib/features/progress/widgets/stats_card.dart`
- Modify: `lib/features/progress/profile_screen.dart`
- Test: `test/features/progress/profile_stats_card_test.dart`

**Interfaces:**
- Consumes: `StatsScreen` body from `lib/features/stats/stats_screen.dart`; `Strings.statsCardTitle`, `Strings.statsCardHint` (add in this task if missing).
- Produces: `StatsHub()` widget (`Scaffold` + `AppBar` + `StatsScreen`); `StatsCard()` widget pushing `StatsHub`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:energy_clock/features/progress/widgets/stats_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('profile shows Stats card pushing hub', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: Scaffold(body: StatsCard()))));
    await tester.pump();
    expect(find.text('Stats'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/progress/profile_stats_card_test.dart -v`
Expected: FAIL with "StatsCard not defined".

- [ ] **Step 3: Write minimal implementation**

`lib/features/stats/stats_hub.dart`:

```dart
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/stats/stats_screen.dart';
import 'package:flutter/material.dart';

class StatsHub extends StatelessWidget {
  const StatsHub({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: null,
      body: _HubScaffold(),
    );
  }
}

class _HubScaffold extends StatelessWidget {
  const _HubScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.tabStats)),
      body: const StatsScreen(),
    );
  }
}
```

Simplify to single Scaffold (remove nesting — keep one `Scaffold` with `AppBar` + `StatsScreen` body).

`lib/features/progress/widgets/stats_card.dart`:

```dart
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/stats/stats_hub.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';

class StatsCard extends StatelessWidget {
  const StatsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsHub()));
      },
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(Strings.tabStats, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(Strings.statsCardHint, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
```

In `lib/core/strings.dart` add:

```dart
static const String tabStats = 'Stats';
static const String statsCardHint = 'Tone balance, planned vs actual, focus depth.';
```

(`tabStats` already exists — reuse it, do not duplicate. Add only `statsCardHint`.)

In `lib/features/progress/profile_screen.dart`: remove `import 'package:energy_clock/features/progress/widgets/projects_card.dart';`, add `import 'package:energy_clock/features/progress/widgets/stats_card.dart';`, replace `const ProjectsCard(),` with `const StatsCard(),`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/progress/profile_stats_card_test.dart -v`
Expected: PASS.

Run: `flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/stats/stats_hub.dart lib/features/progress/widgets/stats_card.dart lib/features/progress/profile_screen.dart lib/core/strings.dart test/features/progress/profile_stats_card_test.dart
git commit -m "feat: move Stats into Profile hub with StatsCard"
```

### Task 4: Tab indices, goldens, regression

**Files:**
- Modify: any test referencing tab indices 1-4 (`grep -rn "tab-" test/`, `AppTabBar.tabCount`, `_screen`)
- Test: existing `test/` suite + goldens in `test/features/clock/goldens`

**Interfaces:**
- Consumes: Tasks 1-3 outputs.
- Produces: Full `flutter analyze` + `flutter test` green; tab-bar goldens regenerated only if pixels changed.

- [ ] **Step 1: Write the failing check**

Run: `flutter test -v 2>&1 | tail -20`
Expected: FAIL in tests asserting old order (e.g. `tab-2` is Stats, Profile `ProjectsCard` exists).

- [ ] **Step 2: Fix callers**

Search and update:

```bash
rg -n "tab-2|tab-3|ProjectsCard|StatsScreen\(\)" test/ lib/
```

Update each: tab-1 now Projects, tab-2 Calendar, tab-3 Profile; Profile tests expect `StatsCard`, not `ProjectsCard`; `StatsScreen` tab tests now pump `StatsHub`.

- [ ] **Step 3: Run full suite**

Run: `flutter analyze`
Expected: PASS.

Run: `flutter test -v`
Expected: PASS. If tab-bar goldens fail, review images then:

Run: `flutter test --update-goldens test/features/clock/dial_golden_test.dart`
Expected: PASS, then `git diff --stat` shows only intended tab-bar pixels.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "test: update tab indices for Projects second, Stats hub"
```
