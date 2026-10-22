import 'package:altidial/core/strings.dart';
import 'package:altidial/core/tone.dart';

/// Fixed tag set v1. No custom tags. The ids here are domain data; the labels
/// that go with them are copy, and live in [Strings.tagLabels].
abstract final class ReflectionTags {
  static const List<String> allIds = [
    'flow',
    'clear-goal',
    'interruptions',
    'noisy',
    'tired',
    'time-pressure',
    'context-switch',
    'low-energy',
  ];

  static const int maxTags = 4;
  static const int maxNoteLength = 140;

  /// Keeps first-seen order, drops unknown ids and duplicates, caps at 4.
  static List<String> sanitizeTags(List<String> tags) {
    final seen = <String>[];
    for (final tag in tags) {
      if (!allIds.contains(tag)) continue;
      if (seen.contains(tag)) continue;
      seen.add(tag);
      if (seen.length >= maxTags) break;
    }
    return seen;
  }

  static String? validateNote(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (value.trim().length > maxNoteLength) {
      return Strings.debriefNoteOver;
    }
    return null;
  }

  static String encodeTags(List<String> tags) => sanitizeTags(tags).join(',');

  static List<String> decodeTags(String? csv) {
    if (csv == null || csv.trim().isEmpty) return const [];
    return sanitizeTags(csv.split(',').map((s) => s.trim()).toList());
  }
}

/// Whether a session counts as reflected. Any part of the debrief counts — a
/// rating, a tag or a note — so the journal row and the profile teaser agree
/// that a partially filled reflection is a reflection.
bool isReflected({
  int? energyRating,
  int? focusRating,
  List<String> tags = const [],
  String? note,
}) =>
    energyRating != null ||
    focusRating != null ||
    tags.isNotEmpty ||
    (note != null && note.isNotEmpty);

typedef PatternInput = ({
  Tone tone,
  int energyRating,
  int focusRating,
  List<String> tags,
  int startHour,
  bool isPostLife,
});

typedef PatternCard = ({
  String title,
  String detail,
  double delta,
  int sampleSize,
});

/// Pure recomputation over reflected sessions. Returns [] when n < 5.
/// Completed + finishedEarly inputs only — callers must filter abandoned/running.
abstract final class ReflectionPatterns {
  static const int minSample = 5;

  static List<PatternCard> compute(List<PatternInput> inputs) {
    if (inputs.length < minSample) return const [];
    final cards = <PatternCard>[];
    final withClear = inputs.where((i) => i.tags.contains('clear-goal')).toList();
    final withoutClear = inputs.where((i) => !i.tags.contains('clear-goal')).toList();
    if (withClear.length >= minSample && withoutClear.isNotEmpty) {
      final a = _avgFocus(withClear);
      final b = _avgFocus(withoutClear);
      final delta = a - b;
      if (delta >= 0.5) {
        cards.add((
          title: Strings.patternsClearGoalTitle(delta.toStringAsFixed(1)),
          detail: Strings.patternsClearGoalDetail(a.toStringAsFixed(1), b.toStringAsFixed(1), inputs.length),
          delta: delta,
          sampleSize: inputs.length,
        ));
      }
    }
    final lateInbox = inputs.where((i) => i.tone == Tone.inbox && i.startHour >= 21).toList();
    final rest = inputs.where((i) => !(i.tone == Tone.inbox && i.startHour >= 21)).toList();
    if (lateInbox.length >= minSample && rest.isNotEmpty) {
      final a = _avgEnergy(rest);
      final b = _avgEnergy(lateInbox);
      final drain = a - b;
      if (drain >= 0.5) {
        cards.add((
          title: Strings.patternsLateInboxTitle(drain.toStringAsFixed(1)),
          detail: Strings.patternsLateInboxDetail(b.toStringAsFixed(1), a.toStringAsFixed(1), inputs.length),
          delta: -drain,
          sampleSize: inputs.length,
        ));
      }
    }
    final postLife = inputs.where((i) => i.isPostLife && i.tone == Tone.focus).toList();
    final otherFocus = inputs.where((i) => !(i.isPostLife && i.tone == Tone.focus) && i.tone == Tone.focus).toList();
    if (postLife.length >= 3 && otherFocus.length >= 3 && inputs.length >= minSample) {
      final a = _avgEnergy(postLife);
      final b = _avgEnergy(otherFocus);
      final lift = a - b;
      if (lift >= 0.5) {
        cards.add((
          title: Strings.patternsPostLifeTitle(lift.toStringAsFixed(1)),
          detail: Strings.patternsPostLifeDetail(a.toStringAsFixed(1), b.toStringAsFixed(1), inputs.length),
          delta: lift,
          sampleSize: inputs.length,
        ));
      }
    }
    return cards;
  }

  static double _avgFocus(List<PatternInput> list) {
    if (list.isEmpty) return 0;
    var sum = 0;
    for (final i in list) sum += i.focusRating;
    return sum / list.length;
  }

  static double _avgEnergy(List<PatternInput> list) {
    if (list.isEmpty) return 0;
    var sum = 0;
    for (final i in list) sum += i.energyRating;
    return sum / list.length;
  }
}
