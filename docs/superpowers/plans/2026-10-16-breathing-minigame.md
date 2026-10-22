# Breathing Minigame Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the primitive inline Flight Deck breathing timer with an interactive full-screen breathing minigame opened from a new launcher at the top of the deck.

**Architecture:** A pure `BreathingCycle` state machine (inhale 4s ↔ exhale 6s, 8 breaths) drives a `BreathingScreen` via one `AnimationController`; a full-screen `Listener` tracks the press/release gesture and gives gentle visual/haptic correction. The screen is pushed with `Navigator.push(MaterialPageRoute(...))`, the app's standard non-tab hub pattern. Nothing is persisted.

**Tech Stack:** Flutter (SDK ^3.12.2), Material 3, Nunito, `flutter_test`. No new dependencies.

## Global Constraints

- Flutter SDK floor: `^3.12.2`; Material 3; theme font family `Nunito`.
- No new packages: `pubspec.yaml` dependencies stay exactly as they are.
- All user-facing copy lives in `lib/core/strings.dart` — no string literals in feature code.
- Feature code never hard-codes a colour (`test/architecture/no_hardcoded_colors_test.dart` rejects `Color(0x` and `Colors.`). Use `context.appColors`, `context.toneColors`, or `AppColors.transparent`.
- Reduced motion is honoured via `MediaQuery.disableAnimationsOf(context)`.
- Features import only from `data/`, `core/`, `app/`, `shared/`.
- Gates for every task: `flutter analyze` (clean) and `flutter test`.
- Copy values (exact): `deckBreatheTitle` = `Take a breath`; `deckBreatheHint` = `4 in · 6 out · guided`; `breatheScreenTitle` = `Slow breathing`; `breatheInhale` = `Breathe in`; `breatheExhale` = `Breathe out`; `breathePress` = `Press and hold`; `breatheRelease` = `Let go`; `breatheDoneTitle` = `You're here`; `breatheAgain` = `Again`; `breatheFinish` = `Done`; `breatheClose` = `Close`.
- Pattern constants (exact): inhale `Duration(seconds: 4)`, exhale `Duration(seconds: 6)`, `totalBreaths` = `8`.

---

## File Structure

- **Create** `lib/features/flight_deck/breathing/breathing_cycle.dart` — pure phase/breath state machine, no Flutter imports beyond none.
- **Create** `lib/features/flight_deck/breathing/widgets/breathing_orb.dart` — the scaling orb + progress ring visual, plus its private ring painter.
- **Create** `lib/features/flight_deck/breathing/breathing_screen.dart` — the full-screen minigame (timer, gesture, finish overlay).
- **Create** `lib/features/flight_deck/widgets/breathing_launcher.dart` — the top-of-deck entry card.
- **Modify** `lib/core/strings.dart` — add the new copy (Task 2); remove the retired copy (Task 5).
- **Modify** `lib/features/flight_deck/flight_deck_screen.dart` — swap the inline timer for the launcher.
- **Delete** `lib/features/flight_deck/widgets/breathing_timer.dart` — retired.
- **Create** `test/features/flight_deck/breathing/breathing_cycle_test.dart`
- **Create** `test/features/flight_deck/breathing/breathing_orb_test.dart`
- **Create** `test/features/flight_deck/breathing/breathing_screen_test.dart`
- **Create** `test/features/flight_deck/breathing/breathing_launcher_test.dart`
- **Modify** `test/features/flight_deck/calm_widgets_test.dart` — drop the retired timer test.
- **Modify** `test/features/flight_deck/flight_deck_screen_test.dart` — assert the launcher renders.

---

### Task 1: Breathing cycle logic

**Files:**
- Create: `lib/features/flight_deck/breathing/breathing_cycle.dart`
- Test: `test/features/flight_deck/breathing/breathing_cycle_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum BreathPhase { inhale, exhale }`
  - `class BreathingCycle { BreathingCycle({int totalBreaths = 8}); static const Duration inhaleDuration; static const Duration exhaleDuration; final int totalBreaths; BreathPhase phase; int breathsTaken; bool done; Duration get phaseDuration; double fractionFor(Duration elapsed); int secondsLeft(Duration elapsed); BreathPhase advance(); void reset(); }`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/flight_deck/breathing/breathing_cycle_test.dart
import 'package:energy_clock/features/flight_deck/breathing/breathing_cycle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts on the first inhale', () {
    final cycle = BreathingCycle();
    expect(cycle.phase, BreathPhase.inhale);
    expect(cycle.breathsTaken, 0);
    expect(cycle.done, isFalse);
    expect(cycle.phaseDuration, const Duration(seconds: 4));
  });

  test('inhale is followed by exhale and back', () {
    final cycle = BreathingCycle();
    expect(cycle.advance(), BreathPhase.exhale);
    expect(cycle.phaseDuration, const Duration(seconds: 6));
    expect(cycle.advance(), BreathPhase.inhale);
  });

  test('a breath counts only after the exhale', () {
    final cycle = BreathingCycle();
    cycle.advance(); // -> exhale
    expect(cycle.breathsTaken, 0);
    cycle.advance(); // -> inhale, one breath done
    expect(cycle.breathsTaken, 1);
  });

  test('done fires exactly at totalBreaths', () {
    final cycle = BreathingCycle(totalBreaths: 2);
    for (var i = 0; i < 4; i++) {
      cycle.advance();
    }
    expect(cycle.breathsTaken, 2);
    expect(cycle.done, isTrue);
  });

  test('advance is a no-op once done', () {
    final cycle = BreathingCycle(totalBreaths: 1);
    cycle.advance();
    cycle.advance();
    expect(cycle.done, isTrue);
    final phase = cycle.phase;
    expect(cycle.advance(), phase);
  });

  test('fractionFor maps elapsed time to 0..1', () {
    final cycle = BreathingCycle();
    expect(cycle.fractionFor(Duration.zero), 0);
    expect(cycle.fractionFor(const Duration(seconds: 2)), 0.5);
    expect(cycle.fractionFor(const Duration(seconds: 4)), 1);
    expect(cycle.fractionFor(const Duration(seconds: 9)), 1);
  });

  test('secondsLeft counts down within the phase', () {
    final cycle = BreathingCycle();
    expect(cycle.secondsLeft(Duration.zero), 4);
    expect(cycle.secondsLeft(const Duration(seconds: 3, milliseconds: 100)), 1);
    expect(cycle.secondsLeft(const Duration(seconds: 4)), 0);
  });

  test('reset returns to the first inhale', () {
    final cycle = BreathingCycle();
    cycle.advance();
    cycle.advance();
    cycle.reset();
    expect(cycle.phase, BreathPhase.inhale);
    expect(cycle.breathsTaken, 0);
    expect(cycle.done, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/flight_deck/breathing/breathing_cycle_test.dart`
Expected: FAIL — `Target of URI doesn't exist` / `BreathingCycle isn't defined`.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/flight_deck/breathing/breathing_cycle.dart

/// The two phases of the guided breath. There is no hold: the user presses
/// while inhaling and releases while exhaling.
enum BreathPhase { inhale, exhale }

/// The pure logic of one breathing session: which phase is active, how many
/// breaths are done, and the progress inside the current phase. It owns no
/// timers and no widgets, so it is unit-tested on its own. The screen drives it
/// from an `AnimationController`; tests drive it directly.
class BreathingCycle {
  BreathingCycle({this.totalBreaths = 8});

  static const Duration inhaleDuration = Duration(seconds: 4);
  static const Duration exhaleDuration = Duration(seconds: 6);

  /// How many full in-and-out breaths make up one session.
  final int totalBreaths;

  BreathPhase phase = BreathPhase.inhale;

  /// Completed breaths (an inhale followed by its exhale).
  int breathsTaken = 0;

  /// True once the last exhale has finished.
  bool done = false;

  /// How long the current phase lasts.
  Duration get phaseDuration =>
      phase == BreathPhase.inhale ? inhaleDuration : exhaleDuration;

  /// Progress through the current phase: 0 at its start, 1 at its end.
  double fractionFor(Duration elapsed) {
    final total = phaseDuration.inMilliseconds;
    if (total <= 0) return 1;
    return (elapsed.inMilliseconds / total).clamp(0.0, 1.0);
  }

  /// Whole seconds left in the current phase, for the countdown label.
  int secondsLeft(Duration elapsed) {
    final remaining = phaseDuration - elapsed;
    if (remaining.isNegative) return 0;
    return (remaining.inMilliseconds / 1000).ceil();
  }

  /// Moves on when the current phase finishes. Returns the new phase, or the
  /// same phase once [done]. Called once per phase completion.
  BreathPhase advance() {
    if (done) return phase;
    if (phase == BreathPhase.inhale) {
      phase = BreathPhase.exhale;
      return phase;
    }
    breathsTaken++;
    if (breathsTaken >= totalBreaths) {
      done = true;
      return phase;
    }
    phase = BreathPhase.inhale;
    return phase;
  }

  /// Returns to the first inhale with no breaths taken.
  void reset() {
    phase = BreathPhase.inhale;
    breathsTaken = 0;
    done = false;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/flight_deck/breathing/breathing_cycle_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/flight_deck/breathing/breathing_cycle.dart test/features/flight_deck/breathing/breathing_cycle_test.dart
git commit -m "feat: breathing cycle state machine"
```

---

### Task 2: Breathing copy in Strings

**Files:**
- Modify: `lib/core/strings.dart` (after the existing `deckSavedEmptyHint` line, inside the Flight Deck block)
- Test: `test/core/strings_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces (all `static const String` unless noted): `deckBreatheTitle`, `deckBreatheHint`, `breatheScreenTitle`, `breatheInhale`, `breatheExhale`, `breathePress`, `breatheRelease`, `breatheDoneTitle`, `breatheAgain`, `breatheFinish`, `breatheClose`, and `static String breatheCount(int current, int total)`, `static String breatheDoneBody(int breaths)`.

Note: this task only **adds** copy. The retired `deckBreathing*` strings stay until Task 5 deletes the widget that uses them, so every task stays green.

- [ ] **Step 1: Write the failing test**

Add to `test/core/strings_test.dart` inside `void main()`:

```dart
  test('breathing copy formats its numbers', () {
    expect(Strings.breatheCount(3, 8), 'Breath 3 of 8');
    expect(Strings.breatheDoneBody(1), '1 calm breath.');
    expect(Strings.breatheDoneBody(8), '8 calm breaths.');
    expect(Strings.deckBreatheTitle, 'Take a breath');
    expect(Strings.breatheDoneTitle, "You're here");
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/strings_test.dart`
Expected: FAIL — `The getter 'breatheCount' isn't defined`.

- [ ] **Step 3: Add the copy**

Find the Flight Deck block and locate these existing lines:

```dart
  static const String deckSavedEmptyTitle = 'Nothing saved yet';
  static const String deckSavedEmptyHint = 'Star a card to keep it here.';
```

Insert directly after `deckSavedEmptyHint`:

```dart
  static const String deckBreatheTitle = 'Take a breath';
  static const String deckBreatheHint = '4 in · 6 out · guided';
  static const String breatheScreenTitle = 'Slow breathing';
  static const String breatheInhale = 'Breathe in';
  static const String breatheExhale = 'Breathe out';
  static const String breathePress = 'Press and hold';
  static const String breatheRelease = 'Let go';
  static const String breatheClose = 'Close';
  static const String breatheDoneTitle = "You're here";
  static const String breatheAgain = 'Again';
  static const String breatheFinish = 'Done';
  static String breatheCount(int current, int total) =>
      'Breath $current of $total';
  static String breatheDoneBody(int breaths) =>
      breaths == 1 ? '1 calm breath.' : '$breaths calm breaths.';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/strings_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/strings.dart test/core/strings_test.dart
git commit -m "feat: breathing minigame copy"
```

---

### Task 3: Breathing orb widget

**Files:**
- Create: `lib/features/flight_deck/breathing/widgets/breathing_orb.dart`
- Test: `test/features/flight_deck/breathing/breathing_orb_test.dart`

**Interfaces:**
- Consumes: `BreathPhase` from `breathing_cycle.dart`.
- Produces:
  - `class BreathingOrb extends StatelessWidget { const BreathingOrb({required double diameter, required BreathPhase phase, required double fraction, required int secondsLeft, required String label, required bool inSync, required bool reduceMotion, super.key}); }`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/flight_deck/breathing/breathing_orb_test.dart
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/features/flight_deck/breathing/breathing_cycle.dart';
import 'package:energy_clock/features/flight_deck/breathing/widgets/breathing_orb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('shows the phase label and the countdown', (tester) async {
    await tester.pumpWidget(host(const BreathingOrb(
      diameter: 300,
      phase: BreathPhase.inhale,
      fraction: 0.5,
      secondsLeft: 2,
      label: 'Breathe in',
      inSync: true,
      reduceMotion: false,
    )));
    expect(find.text('Breathe in'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('renders on the exhale too', (tester) async {
    await tester.pumpWidget(host(const BreathingOrb(
      diameter: 240,
      phase: BreathPhase.exhale,
      fraction: 0.25,
      secondsLeft: 5,
      label: 'Breathe out',
      inSync: false,
      reduceMotion: true,
    )));
    expect(find.text('Breathe out'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/flight_deck/breathing/breathing_orb_test.dart`
Expected: FAIL — `Target of URI doesn't exist`.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/flight_deck/breathing/widgets/breathing_orb.dart
import 'dart:math' as math;

import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/app_typography.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/features/flight_deck/breathing/breathing_cycle.dart';
import 'package:flutter/material.dart';

/// Paints the outer progress ring: an arc from the top that fills on the
/// inhale and empties on the exhale. A [fraction] of 1 is a full circle.
class _OrbRingPainter extends CustomPainter {
  const _OrbRingPainter({
    required this.fraction,
    required this.thickness,
    required this.color,
    required this.trackColor,
  });

  final double fraction;
  final double thickness;
  final Color color;
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
  bool shouldRepaint(_OrbRingPainter old) =>
      old.fraction != fraction ||
      old.thickness != thickness ||
      old.color != color ||
      old.trackColor != trackColor;
}

/// The breathing guide: a scaling orb inside a progress ring. [fraction] is the
/// progress through the current phase, so the orb grows through an inhale and
/// shrinks through an exhale. When [inSync] is false the accent dims to signal
/// a gentle correction; under [reduceMotion] the scale tween and glow are
/// dropped while the ring still shows progress.
class BreathingOrb extends StatelessWidget {
  const BreathingOrb({
    required this.diameter,
    required this.phase,
    required this.fraction,
    required this.secondsLeft,
    required this.label,
    required this.inSync,
    required this.reduceMotion,
    super.key,
  });

  final double diameter;
  final BreathPhase phase;
  final double fraction;
  final int secondsLeft;
  final String label;
  final bool inSync;
  final bool reduceMotion;

  static const double _minScale = 0.55;
  static const double _maxScale = 1.0;

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tone = context.toneColors.focus;

    final ringFraction = phase == BreathPhase.inhale
        ? fraction
        : 1 - fraction;
    final scale = reduceMotion
        ? (phase == BreathPhase.inhale ? _maxScale : _minScale)
        : (phase == BreathPhase.inhale
              ? _lerp(_minScale, _maxScale, fraction)
              : _lerp(_maxScale, _minScale, fraction));

    final accent = inSync ? tone.solid : colors.muted;
    final orbSize = diameter * 0.6 * scale;
    final glow = !reduceMotion && inSync
        ? <BoxShadow>[
            BoxShadow(
              color: tone.solid.withValues(alpha: 0.32 * scale),
              blurRadius: 40 * scale,
              spreadRadius: 4 * scale,
            ),
          ]
        : const <BoxShadow>[];

    return SizedBox.square(
      dimension: diameter,
      child: CustomPaint(
        painter: _OrbRingPainter(
          fraction: ringFraction,
          thickness: diameter * 0.045,
          color: accent,
          trackColor: colors.outline,
        ),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: orbSize,
                height: orbSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: inSync ? tone.soft : colors.page,
                  border: Border.all(color: accent, width: 3),
                  boxShadow: glow,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge!
                        .copyWith(color: colors.muted),
                  ),
                  Text(
                    '$secondsLeft',
                    style: AppTypography.sessionTime(diameter * 0.15)
                        .copyWith(color: accent),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/flight_deck/breathing/breathing_orb_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/flight_deck/breathing/widgets/breathing_orb.dart test/features/flight_deck/breathing/breathing_orb_test.dart
git commit -m "feat: breathing orb widget"
```

---

### Task 4: Full-screen breathing screen

**Files:**
- Create: `lib/features/flight_deck/breathing/breathing_screen.dart`
- Test: `test/features/flight_deck/breathing/breathing_screen_test.dart`

**Interfaces:**
- Consumes: `BreathingCycle`, `BreathPhase` (Task 1), `BreathingOrb` (Task 3), the `breathe*`/`breatheCount`/`breatheDoneBody` copy (Task 2).
- Produces: `class BreathingScreen extends StatefulWidget { const BreathingScreen({super.key}); }`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/flight_deck/breathing/breathing_screen_test.dart
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/flight_deck/breathing/breathing_cycle.dart';
import 'package:energy_clock/features/flight_deck/breathing/breathing_screen.dart';
import 'package:energy_clock/features/flight_deck/breathing/widgets/breathing_orb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

/// Pumps one whole phase and settles the frame that draws the next one.
Future<void> finishPhase(WidgetTester tester, Duration phase) async {
  await tester.pump(phase);
  await tester.pump();
}

/// Takes [breaths] complete in-and-out breaths.
Future<void> breathe(WidgetTester tester, {int breaths = 8}) async {
  for (var i = 0; i < breaths; i++) {
    await finishPhase(tester, BreathingCycle.inhaleDuration);
    await finishPhase(tester, BreathingCycle.exhaleDuration);
  }
}

void main() {
  testWidgets('opens on the first inhale with the press prompt', (tester) async {
    await tester.pumpWidget(host(const BreathingScreen()));
    expect(find.text(Strings.breatheInhale), findsOneWidget);
    expect(find.text(Strings.breathePress), findsOneWidget);
    expect(find.text(Strings.breatheCount(1, 8)), findsOneWidget);
  });

  testWidgets('advances to the exhale after the inhale', (tester) async {
    await tester.pumpWidget(host(const BreathingScreen()));
    await finishPhase(tester, BreathingCycle.inhaleDuration);
    expect(find.text(Strings.breatheExhale), findsOneWidget);
    expect(find.text(Strings.breathePress), findsNothing);
  });

  testWidgets('pressing clears the prompt; releasing brings it back',
      (tester) async {
    await tester.pumpWidget(host(const BreathingScreen()));
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(BreathingOrb)));
    await tester.pump();
    expect(find.text(Strings.breathePress), findsNothing);
    await gesture.up();
    await tester.pump();
    expect(find.text(Strings.breathePress), findsOneWidget);
  });

  testWidgets('holding during the exhale shows the let-go prompt',
      (tester) async {
    await tester.pumpWidget(host(const BreathingScreen()));
    await finishPhase(tester, BreathingCycle.inhaleDuration);
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(BreathingOrb)));
    await tester.pump();
    expect(find.text(Strings.breatheRelease), findsOneWidget);
    await gesture.up();
  });

  testWidgets('finishes after eight breaths', (tester) async {
    await tester.pumpWidget(host(const BreathingScreen()));
    await breathe(tester);
    expect(find.text(Strings.breatheDoneTitle), findsOneWidget);
    expect(find.text(Strings.breatheDoneBody(8)), findsOneWidget);
  });

  testWidgets('Again restarts from the first inhale', (tester) async {
    await tester.pumpWidget(host(const BreathingScreen()));
    await breathe(tester);
    await tester.tap(find.byKey(const ValueKey('breathe-again')));
    await tester.pump();
    expect(find.text(Strings.breatheDoneTitle), findsNothing);
    expect(find.text(Strings.breatheInhale), findsOneWidget);
  });

  testWidgets('Done closes the screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BreathingScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await breathe(tester);
    await tester.tap(find.byKey(const ValueKey('breathe-done')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(BreathingScreen), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/flight_deck/breathing/breathing_screen_test.dart`
Expected: FAIL — `Target of URI doesn't exist`.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/flight_deck/breathing/breathing_screen.dart
import 'dart:async';

import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/flight_deck/breathing/breathing_cycle.dart';
import 'package:energy_clock/features/flight_deck/breathing/widgets/breathing_orb.dart';
import 'package:energy_clock/shared/layout/content_width.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The full-screen guided-breathing minigame. Inhale for four seconds while
/// pressing and holding anywhere on the screen, then exhale for six with the
/// finger off. Eight breaths, then a finish card. It keeps nothing outside the
/// route and never writes to storage.
class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen>
    with SingleTickerProviderStateMixin {
  final BreathingCycle _cycle = BreathingCycle();
  late final AnimationController _controller;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _cycle.phaseDuration,
    )..addStatusListener(_onPhaseFinished);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPhaseFinished(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _cycle.advance();
    setState(() {});
    if (_cycle.done) {
      unawaited(HapticFeedback.mediumImpact());
      return;
    }
    _controller.duration = _cycle.phaseDuration;
    _controller.forward(from: 0);
    unawaited(HapticFeedback.selectionClick());
  }

  void _restart() {
    setState(() {
      _cycle.reset();
      _pressed = false;
    });
    _controller.duration = _cycle.phaseDuration;
    _controller.forward(from: 0);
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
    if (_cycle.done || !_inSync) return;
    unawaited(HapticFeedback.lightImpact());
  }

  bool get _inSync =>
      _cycle.phase == BreathPhase.inhale ? _pressed : !_pressed;

  String get _phaseLabel => _cycle.phase == BreathPhase.inhale
      ? Strings.breatheInhale
      : Strings.breatheExhale;

  /// The gentle correction, shown only while the finger is out of step.
  String? get _prompt {
    if (_cycle.done || _inSync) return null;
    return _cycle.phase == BreathPhase.inhale
        ? Strings.breathePress
        : Strings.breatheRelease;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: colors.page,
      body: SafeArea(
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _setPressed(true),
          onPointerUp: (_) => _setPressed(false),
          onPointerCancel: (_) => _setPressed(false),
          child: Stack(
            children: [
              Positioned.fill(child: _body(colors, reduceMotion)),
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: IconButton(
                  key: const ValueKey('breathe-close'),
                  tooltip: Strings.breatheClose,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              if (_cycle.done)
                Positioned.fill(child: _finish(colors)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(AppColors colors, bool reduceMotion) {
    final theme = Theme.of(context);
    return Center(
      child: ContentWidth(
        maxWidth: ContentWidths.column,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final smallest = constraints.maxWidth < constraints.maxHeight
                  ? constraints.maxWidth
                  : constraints.maxHeight;
              final diameter = (smallest * 0.72).clamp(180.0, 360.0);
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final fraction = _controller.value;
                  final breathNumber = (_cycle.breathsTaken + 1)
                      .clamp(1, _cycle.totalBreaths);
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(Strings.breatheScreenTitle,
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        Strings.breatheCount(breathNumber, _cycle.totalBreaths),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      BreathingOrb(
                        diameter: diameter,
                        phase: _cycle.phase,
                        fraction: fraction,
                        secondsLeft: _cycle.secondsLeft(
                          _cycle.phaseDuration * fraction,
                        ),
                        label: _phaseLabel,
                        inSync: _inSync,
                        reduceMotion: reduceMotion,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      SizedBox(
                        height: 24,
                        child: Text(
                          _prompt ?? '',
                          key: const ValueKey('breathe-prompt'),
                          style: theme.textTheme.titleSmall!
                              .copyWith(color: colors.muted),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _finish(AppColors colors) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: colors.page.withValues(alpha: 0.92),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(Strings.breatheDoneTitle,
                  style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                Strings.breatheDoneBody(_cycle.totalBreaths),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium!.copyWith(color: colors.muted),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.tonal(
                    key: const ValueKey('breathe-again'),
                    onPressed: _restart,
                    child: const Text(Strings.breatheAgain),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    key: const ValueKey('breathe-done'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text(Strings.breatheFinish),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/flight_deck/breathing/breathing_screen_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/flight_deck/breathing/breathing_screen.dart test/features/flight_deck/breathing/breathing_screen_test.dart
git commit -m "feat: full-screen breathing minigame"
```

---

### Task 5: Deck launcher, retire the inline timer

**Files:**
- Create: `lib/features/flight_deck/widgets/breathing_launcher.dart`
- Modify: `lib/features/flight_deck/flight_deck_screen.dart` (import + first child + remove inline timer)
- Modify: `lib/core/strings.dart` (remove the retired `deckBreathing*` block)
- Delete: `lib/features/flight_deck/widgets/breathing_timer.dart`
- Test: `test/features/flight_deck/breathing/breathing_launcher_test.dart`
- Modify: `test/features/flight_deck/calm_widgets_test.dart`, `test/features/flight_deck/flight_deck_screen_test.dart`

**Interfaces:**
- Consumes: `BreathingScreen` (Task 4), `deckBreatheTitle` / `deckBreatheHint` (Task 2).
- Produces: `class BreathingLauncher extends StatelessWidget { const BreathingLauncher({super.key}); }`

- [ ] **Step 1: Write the failing launcher test**

```dart
// test/features/flight_deck/breathing/breathing_launcher_test.dart
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/flight_deck/breathing/breathing_screen.dart';
import 'package:energy_clock/features/flight_deck/widgets/breathing_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('launcher pushes the breathing screen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: BreathingLauncher()),
    ));
    expect(find.text(Strings.deckBreatheTitle), findsOneWidget);
    await tester.tap(find.text(Strings.deckBreatheTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(BreathingScreen), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/flight_deck/breathing/breathing_launcher_test.dart`
Expected: FAIL — `Target of URI doesn't exist`.

- [ ] **Step 3: Write the launcher**

```dart
// lib/features/flight_deck/widgets/breathing_launcher.dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/flight_deck/breathing/breathing_screen.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';

/// The Flight Deck's top entry point into the full-screen breathing minigame.
/// It follows the hub-card pattern: an `AppCard` that pushes a route.
class BreathingLauncher extends StatelessWidget {
  const BreathingLauncher({super.key});

  void _open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BreathingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: Strings.deckBreatheTitle,
      excludeSemantics: true,
      onTap: () => _open(context),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        onTap: () => _open(context),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.page,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.air, color: colors.ink),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(Strings.deckBreatheTitle,
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(Strings.deckBreatheHint,
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.muted),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Replace the inline timer with the launcher**

In `lib/features/flight_deck/flight_deck_screen.dart`:

1. Replace the import line:

```dart
import 'package:energy_clock/features/flight_deck/widgets/breathing_timer.dart';
```

with:

```dart
import 'package:energy_clock/features/flight_deck/widgets/breathing_launcher.dart';
```

2. In `_DeckBody.build`, make the launcher the first child of the column. Find:

```dart
          children: [
            if (next != null) ...[
```

and insert the launcher above it:

```dart
          children: [
            const BreathingLauncher(),
            gap(),
            if (next != null) ...[
```

3. Remove the inline timer. Find:

```dart
            gap(),
            const BreathingTimer(),
            gap(),
            const GroundingSteps(),
```

and replace with:

```dart
            gap(),
            const GroundingSteps(),
```

- [ ] **Step 5: Retire the old widget and its copy**

Delete `lib/features/flight_deck/widgets/breathing_timer.dart`.

In `lib/core/strings.dart`, delete the now-unused block:

```dart
  static const String deckBreathingTitle = 'Slow breathing';
  static const String deckBreathingHint = 'In 4 · hold 4 · out 6';
  static const String deckBreathingStart = 'Start';
  static const String deckBreathingPause = 'Pause';
  static const String deckBreathingReset = 'Reset';
```

- [ ] **Step 6: Update the two existing test files**

In `test/features/flight_deck/calm_widgets_test.dart`, delete the import line:

```dart
import 'package:energy_clock/features/flight_deck/widgets/breathing_timer.dart';
```

and delete this whole test:

```dart
  testWidgets('breathing timer starts and pauses', (tester) async {
    await tester.pumpWidget(host(const BreathingTimer()));
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Start'), findsNothing);
    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(find.text('Start'), findsOneWidget);
  });
```

In `test/features/flight_deck/flight_deck_screen_test.dart`, add this test inside `void main()`:

```dart
  testWidgets('shows the breathing launcher at the top', (tester) async {
    final events = FakeEventRepository();
    addTearDown(events.dispose);
    await tester.pumpWidget(host(events: events, onOpenDay: (_) {}));
    await tester.pumpAndSettle();
    expect(find.text(Strings.deckBreatheTitle), findsOneWidget);
  });
```

- [ ] **Step 7: Run the tests and analyze**

Run: `flutter test test/features/flight_deck`
Expected: PASS — the launcher tests, the flight-deck screen tests, and all breathing tests.

Run: `flutter analyze`
Expected: `No issues found!` (no dangling references to `BreathingTimer` or `deckBreathing*`).

- [ ] **Step 8: Commit**

```bash
git add lib/features/flight_deck/widgets/breathing_launcher.dart lib/features/flight_deck/flight_deck_screen.dart lib/core/strings.dart test/features/flight_deck/breathing/breathing_launcher_test.dart test/features/flight_deck/calm_widgets_test.dart test/features/flight_deck/flight_deck_screen_test.dart
git rm lib/features/flight_deck/widgets/breathing_timer.dart
git commit -m "feat: deck breathing launcher, drop inline timer"
```

---

## Final verification

- [ ] Run the full suite: `flutter test`
  Expected: all tests pass, including `test/architecture/no_hardcoded_colors_test.dart`.
- [ ] Run: `flutter analyze`
  Expected: `No issues found!`.

## Self-Review notes

- **Spec coverage:** launcher at top of deck (Task 5), full-screen route (Task 4), two-phase inhale/exhale, 8 breaths (Task 1), fixed pace + gentle correction (Task 4), scaling orb + progress ring with Focus accent (Task 3), finish screen with Again/Done (Task 4), no persistence (nothing writes), reduced motion (Task 3 + Task 4), old widget retired (Task 5), copy centralised (Task 2).
- **Type consistency:** `BreathingCycle` members (`phase`, `breathsTaken`, `done`, `phaseDuration`, `fractionFor`, `secondsLeft`, `advance`, `reset`, `inhaleDuration`, `exhaleDuration`, `totalBreaths`) match every call site in Task 4. `BreathingOrb` constructor parameters match the call in Task 4 and the test in Task 3. `Strings.breatheCount` / `breatheDoneBody` signatures match their uses.
- **Placeholders:** none.
