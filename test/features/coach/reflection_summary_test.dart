import 'package:altidial/core/coach/reflection_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('summary averages rated sessions, ignores unrated', () {
    final summary = summarizeReflections([
      (energy: 4, focus: 5, tags: ['flow']),
      (energy: 2, focus: 3, tags: ['flow', 'tired']),
      (energy: null, focus: null, tags: []),
    ]);
    expect(summary.count, 3);
    expect(summary.avgEnergy, closeTo(3.0, 0.01));
    expect(summary.avgFocus, closeTo(4.0, 0.01));
    expect(summary.topTags, ['flow', 'tired']);
  });
}
