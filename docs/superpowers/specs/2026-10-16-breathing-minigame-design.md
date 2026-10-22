# Energy Clock — Breathing Minigame — Design

**Date:** 2026-10-16
**Scope:** Replace the primitive inline Flight Deck breathing timer with an interactive, full-screen breathing minigame opened from a new launcher at the top of the deck. Offline-only, no backend, no persistence.
**Approach:** A — full-screen route + `AnimationController` + pointer `Listener`, with a pure `BreathingCycle` logic unit (approved). No new dependencies.
**User decisions:** "new window" = full-screen immersive page → two-phase inhale/exhale only (no holds) → fixed pace with gentle correction (no hard fail) → fixed breath count with a finish screen → scaling orb + progress ring with the Focus tone accent → replace the inline timer with the top button → no tracking/persistence.

## 1. Architecture & data model

New sub-module `lib/features/flight_deck/breathing/` plus one widget under `features/flight_deck/widgets/`. No Drift table, no schema bump, no provider, no settings key.

- **Launcher:** `widgets/breathing_launcher.dart` — a prominent button placed as the first item in the Flight Deck body column (`flight_deck_screen.dart`), above the next-flight hero. Tapping does `Navigator.push(MaterialPageRoute(builder: (_) => const BreathingScreen()))` — the same non-tab hub pattern as `stats_card.dart:14` and `coach_card.dart:21`.
- **Screen:** `breathing/breathing_screen.dart` — a `StatefulWidget` with its own `Scaffold` (immersive, no tab bar), a close affordance, and no Riverpod dependency. Owns the `AnimationController`, the pointer state, and the phase machine driver.
- **Logic unit:** `breathing/breathing_cycle.dart` — a pure, widget-free state machine: given a phase and elapsed time it reports the phase fraction, the next phase, and whether a breath has completed. Holds the pattern constants (inhale 4s, exhale 6s, 8 breaths). Fully unit-testable with plain Dart.
- **Visual:** `breathing/widgets/breathing_orb.dart` — a stateless widget that renders the scaling orb + outer progress ring for a given scale, fraction, phase label, and pressed state.
- **Removed:** `widgets/breathing_timer.dart` is deleted; its references in `flight_deck_screen.dart` and `strings.dart` are updated.
- **Rules:** copy lives in `lib/core/strings.dart`; colors come only from theme tokens (`tone_colors.dart` / `tokens.dart` / `app_colors.dart`) so the no-hardcoded-colour test keeps passing; the Flight Deck feature imports only `data/`, `core/`, `app/`, `shared/`.

## 2. Components (UI)

- **Launcher button (top of deck):** a full-width raised control with a calm icon (`CupertinoIcons.wind` or `self_improvement`), a title ("Take a breath"), and a hint ("4 in · 6 out · guided"). Visually a first-class entry point, not a card in the calm list. It replaces the inline timer at `flight_deck_screen.dart:151`.
- **Breathing screen shell:** `Scaffold` with `surface`/`page` background, a close "X" (and swipe-back) to exit at any time, safe-area padding, and a centered column: the orb+ring on top, a phase word + countdown beneath it, and a short prompt line.
- **Orb + ring (`BreathingOrb`):**
  - The orb is a circle filled with the Focus tone (`toneColors.focus`), scaling small→large through inhale and large→small through exhale.
  - The outer ring is an arc whose fraction equals the current phase progress (fills on inhale, empties on exhale), drawn in the Focus `solid` color.
  - Center overlay shows the phase word ("Breathe in" / "Breathe out") and the integer seconds left in the phase.
  - A soft outer glow scales with the orb for depth; disabled under reduced motion.
- **Interaction feedback:**
  - A full-screen `Listener` (`onPointerDown` / `onPointerUp` / `onPointerCancel`) tracks whether a finger is down.
  - *Inhale, finger up:* a gentle "Press and hold" prompt shows and the orb/ring dim to `muted`. *Pressed:* the prompt clears, the accent returns to Focus, and a light haptic fires.
  - *Exhale, finger down:* a gentle "Let go" prompt shows and the orb dims. *Released:* the prompt clears, light haptic.
  - The prompt is shown only while the finger is out of step, so "in sync" is a clean, testable state. Mismatch never stops or restarts the clock — correction is purely visual/haptic.
- **Finish overlay:** after the final exhale, the orb settles and an overlay fades in inside the same screen: the completion line plus **Again** (restarts the cycle) and **Done** (pops the route). Nothing is written anywhere.

## 3. Data flow

- **Phase clock:** `BreathingCycle` advances on the `AnimationController`: when the controller completes the current phase it calls `next()` on the cycle, which returns the next phase (inhale↔exhale) and, after each complete inhale+exhale, increments the breath count. At `totalBreaths` the cycle reports `done`.
- **Visuals:** the controller value (0→1) is the single source for both orb scale and ring fraction, keeping orb and ring in exact lockstep. Controller duration is set to the phase length (4s or 6s) at each transition.
- **Pointer state:** a local `bool _pressed` updated by the `Listener`; combined with the current phase to decide which prompt (if any) to show and which haptic to fire.
- **Lifecycle:** the controller is disposed with the screen; leaving via Done/X cancels everything. No timer outlives the route, so no runaway animation.
- **Reduced motion:** when `MediaQuery.disableAnimationsOf` is true, the scale tween, pulse, and glow are dropped; the orb snaps to its target size and the ring still renders phase progress from a lightweight ticker so the drill remains usable.

## 4. Error handling & edge cases

- **No error states of substance** — fully offline, no I/O, no provider, nothing to fail; no new load/error copy needed.
- **Interruptions:** app backgrounded or route popped mid-cycle disposes the controller and pointer state cleanly; returning to the deck shows only the launcher (no stale timer).
- **Missed input:** pressing through a whole session with no finger movement still completes all breaths; the prompts simply stay visible. There is no dead-end.
- **Rapid taps:** pointer down/up toggling many times per second is safe; prompts recompute per frame and haptics are debounced to phase edges, not taps.
- **Small / large windows:** the orb diameters derive from available space (via `LayoutBuilder`) so it scales on narrow phones and iPad windows alike.
- **Accessibility:** the phase word and countdown are exposed to screen readers via a semantics label per phase; text respects the app's clamped text scaling; reduced motion is honored.
- **Out of scope (explicit non-goals):** configurable patterns/durations, selectable presets (box, 4-7-8), session persistence or stats, audio/voice guidance, background-continuation timers, streaks/badges.

## 5. Testing

Repo gates: `flutter analyze`, `flutter test`. No golden regen expected (new route only).

- **Pure unit tests (`breathing_cycle_test.dart`):** phase progression inhale→exhale, breath count increments only after a full inhale+exhale, `done` fires exactly at `totalBreaths`, fraction is correct at phase start/end, re-init resets to the first inhale.
- **Widget tests (`breathing_screen_test.dart`):** initial state shows the first inhale prompt; pumping past the inhale duration advances to exhale; pumping a full cycle advances the breath counter; pressing during inhale clears the "Press and hold" prompt and releasing during exhale clears "Let go"; pumping all breaths reveals the finish overlay; **Again** restarts and **Done** pops the route.
- **Launcher test:** the Flight Deck renders the "Take a breath" launcher and tapping it pushes `BreathingScreen`; the deleted `BreathingTimer` no longer appears (updates `calm_widgets_test.dart`).
- **Regression:** no-hardcoded-colour test passes; existing Flight Deck calm-kit tests untouched; grounding stepper test unaffected.
