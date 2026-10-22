import 'package:altidial/features/flight_deck/breathing/breathing_cycle.dart';
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
