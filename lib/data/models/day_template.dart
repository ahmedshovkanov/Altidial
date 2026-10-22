import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/tone.dart';

/// One event of a saved template.
class TemplateItem {
  const TemplateItem({
    required this.title,
    required this.tone,
    required this.range,
  });

  final String title;
  final Tone tone;
  final MinuteRange range;
}

/// A saved day plan: a name and the events it puts on a day.
class DayTemplate {
  const DayTemplate({
    required this.id,
    required this.name,
    required this.items,
  });

  final int id;
  final String name;

  /// In start order.
  final List<TemplateItem> items;

  int get eventCount => items.length;

  /// Overlapping events count twice, as in the day-load bar.
  int get totalMinutes =>
      items.fold<int>(0, (sum, item) => sum + item.range.durationMinutes);

  /// The tones the template uses, in the fixed tone order.
  List<Tone> get tones => [
    for (final tone in Tone.values)
      if (items.any((item) => item.tone == tone)) tone,
  ];
}
