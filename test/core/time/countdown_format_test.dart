import 'package:energy_clock/core/time/day_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatCountdown', () {
    test('shows minutes and seconds under an hour', () {
      expect(formatCountdown(0), '00:00');
      expect(formatCountdown(5), '00:05');
      expect(formatCountdown(65), '01:05');
      expect(formatCountdown(25 * 60), '25:00');
      expect(formatCountdown(3599), '59:59');
    });

    test('adds hours from one hour up', () {
      expect(formatCountdown(3600), '1:00:00');
      expect(formatCountdown(3723), '1:02:03');
      expect(formatCountdown(10 * 3600 + 59), '10:00:59');
    });

    test('shows a negative value as zero', () {
      expect(formatCountdown(-30), '00:00');
    });
  });

  group('spokenDurationSeconds', () {
    test('says every non-zero part in words', () {
      expect(spokenDurationSeconds(3723), '1 hour 2 minutes 3 seconds');
      expect(spokenDurationSeconds(7200), '2 hours');
      expect(spokenDurationSeconds(61), '1 minute 1 second');
      expect(spokenDurationSeconds(600), '10 minutes');
      expect(spokenDurationSeconds(45), '45 seconds');
    });

    test('zero is "0 seconds", never empty', () {
      expect(spokenDurationSeconds(0), '0 seconds');
      expect(spokenDurationSeconds(-5), '0 seconds');
    });
  });
}
