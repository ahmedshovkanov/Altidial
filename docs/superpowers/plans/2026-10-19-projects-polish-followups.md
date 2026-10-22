# Projects Polish Follow-ups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the four issues found reviewing the drag/detail polish commits: a hover layout shift in the drop zone, a missing lift rotation, an unguarded velocity bar height, and a dead import.

**Architecture:** All changes are local to `lib/features/projects/`. The drop zone keeps its public API and only moves its border into a `foregroundDecoration` so hover never changes the child's padding. The velocity pixel math moves to a pure top-level function in the existing model file so it is unit-testable and can guard the all-zero week. No new providers, DAOs or repository methods.

**Tech Stack:** Flutter, Riverpod, `flutter_test`. Pure model math lives in `lib/features/projects/model/project_progress.dart`; widget behaviour in `lib/features/projects/widgets/`.

## Global Constraints

- Colour comes only from the theme. On-screen colour only ever means a *tone*; drop highlights stay neutral (`ink` / `outline` / `surface`). The `test/architecture/no_hardcoded_colors_test.dart` gate must keep passing — never write `Color(0x…)` or `Colors.…`.
- Features never import each other. All work stays inside `lib/features/projects/`.
- No new data model, DAO or repository methods.
- Reduced motion is honoured: collapse animations when `MediaQuery.disableAnimationsOf(context)` is true.
- Do not introduce new `flutter analyze` issues. The repo already reports 11 pre-existing issues (recursive-getter false positives in `lib/data/tables/coach_tables.dart`, two `unused_import` warnings in `lib/features/progress/widgets/notification_settings.dart:8` and `test/data/notification_permission_test.dart:2-3`, and six info-level lints); those are out of scope for this plan.

---

### Task 1: Stop the drop-zone border from shifting its content

**Files:**
- Modify: `lib/features/projects/widgets/task_drag.dart:76-108`
- Test: `test/features/projects/task_drag_test.dart`

**Interfaces:**
- Consumes: `TaskDropZone({ required ValueChanged<int> onAccept, required Widget child, Key? dropKey })`, `DraggableTaskCard({ required TaskRow task, required double cardWidth, VoidCallback? onTap })`, `taskDragDelay` — all existing.
- Produces: no API change. `TaskDropZone` still paints an ink border + faint fill on hover and still reports the dropped id via `onAccept`.

**Why:** `Container` folds a `decoration`'s border width into its padding, so animating the border from 1px to 2px grows the padding by 1px per side and nudges every card inside the column by a pixel on hover.

- [ ] **Step 1: Write the failing test**

Append this test to `test/features/projects/task_drag_test.dart` (inside `void main()`, after the existing test):

```dart
  testWidgets('hovering the drop zone does not shift its content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 240,
                child: DraggableTaskCard(task: _task(), cardWidth: 220),
              ),
              Expanded(
                child: TaskDropZone(
                  dropKey: const Key('zone'),
                  onAccept: (_) {},
                  child: Container(key: const Key('zone-body')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final before = tester.getRect(find.byKey(const Key('zone-body')));

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Ship v1')),
    );
    await tester.pump(taskDragDelay + const Duration(milliseconds: 50));
    await gesture.moveTo(tester.getCenter(find.byKey(const Key('zone'))));
    await tester.pump();
    // Let the highlight's AnimatedContainer settle so we measure the hover
    // layout, not a mid-animation frame.
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.getRect(find.byKey(const Key('zone-body'))), before);

    await gesture.up();
    await tester.pumpAndSettle();
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/projects/task_drag_test.dart --plain-name "hovering the drop zone does not shift its content"`
Expected: FAIL — the `Rect` differs because the hover border grew the padding (e.g. `Rect.fromLTRB(…, 322.0, …)` vs `Rect.fromLTRB(…, 321.0, …)`).

- [ ] **Step 3: Move the border into a foreground decoration**

In `lib/features/projects/widgets/task_drag.dart`, replace the `AnimatedContainer` block inside `TaskDropZone.build` (currently lines 81-92):

```dart
        return AnimatedContainer(
          duration: reduceMotion ? Duration.zero : AppMotion.fast,
          curve: AppMotion.standard,
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: active ? colors.surface : AppColors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(
              color: active ? colors.ink : colors.outline,
              width: active ? 2 : 1,
            ),
          ),
          child: Stack(
```

with:

```dart
        return AnimatedContainer(
          duration: reduceMotion ? Duration.zero : AppMotion.fast,
          curve: AppMotion.standard,
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: active ? colors.surface : AppColors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          // The border lives in the foreground decoration so growing it on
          // hover never changes the child's padding (and so never nudges the
          // cards by a pixel).
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(
              color: active ? colors.ink : colors.outline,
              width: active ? 2 : 1,
            ),
          ),
          child: Stack(
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/projects/task_drag_test.dart test/features/projects/task_board_test.dart test/features/projects/cross_project_board_test.dart`
Expected: PASS (all drop-zone/drag tests, including the new one).

- [ ] **Step 5: Commit**

```bash
git add lib/features/projects/widgets/task_drag.dart test/features/projects/task_drag_test.dart
git commit -m "fix: drop-zone border no longer shifts cards on hover"
```

---

### Task 2: Give the lifted card its spec rotation

**Files:**
- Modify: `lib/features/projects/widgets/task_drag.dart:34-48`
- Test: `test/features/projects/task_drag_test.dart`

**Interfaces:**
- Consumes: `DraggableTaskCard` (existing), `taskDragDelay` (existing).
- Produces: no API change. The drag feedback now carries a ~1° rotation in addition to the 1.03 scale.

**Why:** The design (`docs/superpowers/specs/2026-10-19-projects-polish-drag-design.md` §1) asks for "a slight scale (~1.03) **and rotation (~1deg)**". Only the scale was implemented.

- [ ] **Step 1: Write the failing test**

Add the import for `AppColors` at the top of `test/features/projects/task_drag_test.dart`:

```dart
import 'package:energy_clock/app/theme/app_colors.dart';
```

Append this test to `test/features/projects/task_drag_test.dart`:

```dart
  testWidgets('the lifted card rotates slightly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 240,
                child: DraggableTaskCard(task: _task(), cardWidth: 220),
              ),
              Expanded(
                child: TaskDropZone(
                  dropKey: const Key('zone'),
                  onAccept: (_) {},
                  child: Container(key: const Key('zone-body')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Ship v1')),
    );
    await tester.pump(taskDragDelay + const Duration(milliseconds: 50));
    await gesture.moveTo(tester.getCenter(find.byKey(const Key('zone'))));
    await tester.pump();

    // A rotation matrix has a non-zero off-diagonal term; a pure scale does
    // not.
    expect(
      find.byWidgetPredicate(
        (w) => w is Transform && w.transform.entry(1, 0) != 0,
      ),
      findsWidgets,
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/projects/task_drag_test.dart --plain-name "the lifted card rotates slightly"`
Expected: FAIL — `findsWidgets` matches zero widgets; only `Transform.scale` (diagonal matrix) exists.

- [ ] **Step 3: Add the rotation**

In `lib/features/projects/widgets/task_drag.dart`, replace the `feedback:` child inside `DraggableTaskCard.build` (currently lines 34-48):

```dart
      feedback: Material(
        color: AppColors.transparent,
        child: SizedBox(
          width: cardWidth,
          child: Transform.scale(
            scale: 1.03,
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 8,
              shadowColor: colors.ink,
              child: TaskCard(task: task),
            ),
          ),
        ),
      ),
```

with:

```dart
      feedback: Material(
        color: AppColors.transparent,
        child: SizedBox(
          width: cardWidth,
          child: Transform.rotate(
            angle: -0.0175,
            child: Transform.scale(
              scale: 1.03,
              child: Card(
                margin: EdgeInsets.zero,
                elevation: 8,
                shadowColor: colors.ink,
                child: TaskCard(task: task),
              ),
            ),
          ),
        ),
      ),
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/projects/task_drag_test.dart`
Expected: PASS (both drag tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/projects/widgets/task_drag.dart test/features/projects/task_drag_test.dart
git commit -m "feat: tilt the lifted task card while dragging"
```

---

### Task 3: Guard velocity bar heights against an all-zero week

**Files:**
- Modify: `lib/features/projects/model/project_progress.dart` (add `velocityBarHeight` after `velocityLast7Days`, currently ends line 98)
- Modify: `lib/features/projects/widgets/project_detail.dart` (inside `_VelocityBars.build`, currently lines 845-850)
- Test: `test/features/projects/project_progress_test.dart`

**Interfaces:**
- Consumes: existing `_VelocityBars({ required List<int> velocity })` and its `minBarHeight` (4.0) / `maxBarHeight` (64.0) locals.
- Produces: `double velocityBarHeight({ required int minutes, required int maxMinutes, double minHeight = 4, double maxHeight = 64 })` — pure, no NaN, used by `_VelocityBars`.

**Why:** `minutes / maxMinutes` is `0 / 0 = NaN` when the week is all zeros; `Container(height: NaN)` throws. It is currently only unreachable because the caller short-circuits the all-zero week, so the widget is not self-contained.

- [ ] **Step 1: Write the failing test**

Append this group to `test/features/projects/project_progress_test.dart`, inside `void main()` (a new top-level group, after the `velocityLast7Days` group):

```dart
  group('velocityBarHeight', () {
    test('scales minutes against the week max', () {
      expect(
        velocityBarHeight(minutes: 30, maxMinutes: 60),
        closeTo(34, 0.001), // 4 + (30 / 60) * (64 - 4)
      );
      expect(
        velocityBarHeight(minutes: 60, maxMinutes: 60),
        closeTo(64, 0.001),
      );
    });

    test('all-zero week stays finite at the minimum height', () {
      final height = velocityBarHeight(minutes: 0, maxMinutes: 0);
      expect(height.isFinite, isTrue);
      expect(height, closeTo(4, 0.001));
    });
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/projects/project_progress_test.dart --plain-name "velocityBarHeight"`
Expected: FAIL — `velocityBarHeight` is not defined (compile error).

- [ ] **Step 3: Add the pure helper**

In `lib/features/projects/model/project_progress.dart`, immediately after `velocityLast7Days` (line 98), add:

```dart
/// Pixel height for one velocity bar: [minutes] scaled against the week's
/// [maxMinutes], sitting at [minHeight] when the day is empty. Guards an
/// all-zero week (`maxMinutes == 0`) so the result is never NaN.
double velocityBarHeight({
  required int minutes,
  required int maxMinutes,
  double minHeight = 4,
  double maxHeight = 64,
}) {
  if (maxMinutes <= 0) return minHeight;
  final ratio = (minutes / maxMinutes).clamp(0.0, 1.0);
  return minHeight + ratio * (maxHeight - minHeight);
}
```

- [ ] **Step 4: Use the helper in the widget**

In `lib/features/projects/widgets/project_detail.dart`, inside `_VelocityBars.build`, replace the `Container` height expression (currently lines 845-850):

```dart
                    Container(
                      height:
                          (minBarHeight +
                              (minutes / maxMinutes) *
                                  (maxBarHeight - minBarHeight)) *
                          t,
```

with:

```dart
                    Container(
                      height:
                          velocityBarHeight(
                            minutes: minutes,
                            maxMinutes: maxMinutes,
                            minHeight: minBarHeight,
                            maxHeight: maxBarHeight,
                          ) *
                          t,
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/projects/project_progress_test.dart test/features/projects/project_detail_test.dart`
Expected: PASS — including the existing `velocity bars render when a session ran today` and `velocity empty week shows the empty copy`.

- [ ] **Step 6: Commit**

```bash
git add lib/features/projects/model/project_progress.dart lib/features/projects/widgets/project_detail.dart test/features/projects/project_progress_test.dart
git commit -m "fix: keep velocity bar height finite for an all-zero week"
```

---

### Task 4: Remove the dead `task_board.dart` import

**Files:**
- Modify: `lib/features/projects/widgets/cross_project_board.dart:1-18`

**Interfaces:**
- Consumes: nothing new.
- Produces: no API change. `cross_project_board.dart` no longer imports `widgets/task_board.dart`.

**Why:** After the `task_card.dart` → `task_drag.dart` swap, the widget file `widgets/task_board.dart` is referenced only by the doc comment on line 18, so `unused_import` is silently suppressed. The real dependency (`taskStatusLabel`, `groupByStatus`) comes from `model/task_board.dart`, which stays.

- [ ] **Step 1: Delete the import and de-link the doc reference**

In `lib/features/projects/widgets/cross_project_board.dart`:

- Delete line 9: `import 'package:energy_clock/features/projects/widgets/task_board.dart';`
- Change the doc comment on line 18 from:

```dart
/// [TaskBoard], but there is no inline add (a card has no single project here).
```

to:

```dart
/// TaskBoard, but there is no inline add (a card has no single project here).
```

- [ ] **Step 2: Verify the analyzer is clean for this file**

Run: `flutter analyze lib/features/projects/widgets/cross_project_board.dart`
Expected: `No issues found!` (and no `unused_import` / `undefined_identifier` for the file).

- [ ] **Step 3: Run the board tests**

Run: `flutter test test/features/projects/cross_project_board_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/projects/widgets/cross_project_board.dart
git commit -m "chore: drop unused task_board import from cross-project board"
```

---

## Deliberately not changed

- **Drag-feedback shadow.** The review noted the lifted card uses
  `Card(elevation: 8, shadowColor: colors.ink)` instead of the design's
  `AppColors.cardShadow`. `cardShadow` is unused anywhere in `lib/features`, and
  substituting its soft 8%-ink shadow would make the lifted card read *less*
  raised than the M3 default card below it. The explicit elevation-8 lift is
  kept. If the spec must be matched literally, that is a separate visual task,
  not a correctness fix.
- **Zero-day velocity bars** rendering both a 4px bar and the baseline tick is
  what design §6 asks for; left as-is.

---

### Task 5: Verify the whole surface

**Files:** none.

- [ ] **Step 1: Project area tests**

Run: `flutter test test/features/projects test/architecture`
Expected: PASS (including `no_hardcoded_colors_test.dart`).

- [ ] **Step 2: Confirm no new analyzer issues**

Run: `flutter analyze`
Expected: the same 11 pre-existing issues listed in Global Constraints — no new entries.

Note: The cited 11 includes two real `unused_import` warnings
(`lib/features/progress/widgets/notification_settings.dart:8`,
`test/data/notification_permission_test.dart:2-3`). Those are outside the
recent edits; if a fully green gate is wanted, remove them in a separate
commit and re-run `flutter analyze` to confirm the remaining nine are the
Drift recursive-getter false positives and info lints.
