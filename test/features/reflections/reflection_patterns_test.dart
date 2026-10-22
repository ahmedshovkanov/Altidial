import 'package:altidial/core/strings.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/features/reflections/model/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

PatternInput input({
  required Tone tone,
  required int energy,
  required int focus,
  List<String> tags = const [],
  int hour = 10,
  bool postLife = false,
}) => (tone: tone, energyRating: energy, focusRating: focus, tags: tags, startHour: hour, isPostLife: postLife);

void main() {
  test('fewer than 5 reflected sessions yields no cards', () {
    final inputs = [for (var i = 0; i < 4; i++) input(tone: Tone.focus, energy: 5, focus: 5)];
    expect(ReflectionPatterns.compute(inputs), isEmpty);
  });

  test('sanitizeTags keeps max 4 known ids in order', () {
    expect(
      ReflectionTags.sanitizeTags(['flow', 'bogus', 'clear-goal', 'tired', 'noisy', 'flow']),
      ['flow', 'clear-goal', 'tired', 'noisy'],
    );
  });

  test('validateNote rejects over 140 chars, accepts null and empty', () {
    expect(ReflectionTags.validateNote(null), isNull);
    expect(ReflectionTags.validateNote(''), isNull);
    expect(ReflectionTags.validateNote('a' * 140), isNull);
    expect(ReflectionTags.validateNote('a' * 141), isNotNull);
  });

  test('encode/decode tags round-trip, unknown ids dropped on decode', () {
    expect(ReflectionTags.decodeTags(null), isEmpty);
    expect(ReflectionTags.decodeTags(''), isEmpty);
    const csv = 'flow,clear-goal';
    expect(ReflectionTags.decodeTags(csv), ['flow', 'clear-goal']);
    expect(ReflectionTags.encodeTags(['flow', 'clear-goal']), csv);
  });

  test('tag labels live with the copy and fall back to the id', () {
    expect(Strings.tagLabel('flow'), 'Flow');
    expect(Strings.tagLabel('clear-goal'), 'Clear goal');
    expect(Strings.tagLabel('no-such-tag'), 'no-such-tag');
    for (final id in ReflectionTags.allIds) {
      expect(Strings.tagLabel(id), isNot(id));
    }
  });

  test('clear-goal tag lifts focus card appears with n>=5', () {
    final inputs = <PatternInput>[
      for (var i = 0; i < 6; i++) input(tone: Tone.focus, energy: 4, focus: 5, tags: ['clear-goal']),
      for (var i = 0; i < 6; i++) input(tone: Tone.focus, energy: 3, focus: 2),
    ];
    final cards = ReflectionPatterns.compute(inputs);
    expect(cards.any((c) => c.title.contains('Clear goal')), isTrue);
    final card = cards.firstWhere((c) => c.title.contains('Clear goal'));
    expect(card.sampleSize, 12);
    expect(card.delta, greaterThan(1.0));
  });

  test('late inbox drain card appears for hour>=21 inbox with low energy', () {
    final inputs = <PatternInput>[
      for (var i = 0; i < 6; i++) input(tone: Tone.inbox, energy: 2, focus: 2, hour: 22),
      for (var i = 0; i < 6; i++) input(tone: Tone.focus, energy: 4, focus: 4, hour: 10),
    ];
    final cards = ReflectionPatterns.compute(inputs);
    expect(cards.any((c) => c.title.contains('after 21:00')), isTrue);
  });

  test('post-Life focus lift card appears once each group has n>=3', () {
    final inputs = <PatternInput>[
      for (var i = 0; i < 3; i++) input(tone: Tone.focus, energy: 5, focus: 4, hour: 11, postLife: true),
      for (var i = 0; i < 4; i++) input(tone: Tone.focus, energy: 2, focus: 3, hour: 14),
    ];
    final cards = ReflectionPatterns.compute(inputs);
    expect(cards.any((c) => c.title.contains('Focus after Life')), isTrue);
    final card = cards.firstWhere((c) => c.title.contains('Focus after Life'));
    expect(card.sampleSize, 7);
    expect(card.delta, closeTo(3.0, 0.001));
  });

  test('post-Life focus lift card stays hidden while either group is under 3', () {
    final inputs = <PatternInput>[
      for (var i = 0; i < 3; i++) input(tone: Tone.focus, energy: 5, focus: 4, hour: 11, postLife: true),
      for (var i = 0; i < 2; i++) input(tone: Tone.focus, energy: 2, focus: 3, hour: 14),
    ];
    expect(ReflectionPatterns.compute(inputs), isEmpty);
  });
}
