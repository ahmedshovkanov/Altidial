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
