import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart';

/// One event of the sample day.
class SampleEvent {
  const SampleEvent(this.title, this.tone, this.range);

  final String title;
  final Tone tone;
  final MinuteRange range;
}

/// A realistic day that touches every tone, none of it overlapping.
const List<SampleEvent> sampleDay = [
  SampleEvent(Strings.sampleDeepWork, Tone.focus, MinuteRange(540, 660)),
  SampleEvent(Strings.sampleEmailCalls, Tone.inbox, MinuteRange(660, 705)),
  SampleEvent(Strings.sampleLunchWalk, Tone.life, MinuteRange(750, 795)),
  SampleEvent(Strings.sampleWriting, Tone.focus, MinuteRange(840, 960)),
];

/// Adds the sample events to [day] as ordinary events. An event that would
/// need a fourth ring on a day that already has overlapping events is skipped
/// on purpose. Returns false only if some other error stopped an event from
/// being added; the rest are still created.
Future<bool> createSampleDay(
  EventRepository repository, {
  required DateTime day,
}) async {
  var complete = true;
  for (final sample in sampleDay) {
    try {
      await repository.createEvent(
        day: day,
        title: sample.title,
        tone: sample.tone,
        range: sample.range,
      );
    } on RingOverflowException {
      // Skipped by design: the day is already full at that time.
    } on Object {
      complete = false;
    }
  }
  return complete;
}
