import 'package:altidial/core/tone.dart';
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
