import 'package:altidial/core/event_status.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/database.dart';

export 'package:altidial/core/event_status.dart';

/// An event as the rest of the app sees it. Kept separate from the Drift row
/// so that widgets never depend on the persistence layer's generated types.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.seriesId,
    required this.date,
    required this.title,
    required this.tone,
    required this.range,
    required this.status,
    this.isFlight = false,
    this.flightNumber,
    this.fromCode,
    this.toCode,
    this.projectId,
  });

  final int id;
  final int? seriesId;
  final DateTime date;
  final String title;
  final Tone tone;
  final MinuteRange range;
  final EventStatus status;
  final bool isFlight;
  final String? flightNumber;
  final String? fromCode;
  final String? toCode;
  final int? projectId;

  int get startMinute => range.start;
  int get endMinute => range.end;

  static CalendarEvent fromRow(EventRow row) => CalendarEvent(
    id: row.id,
    seriesId: row.seriesId,
    date: row.date,
    title: row.title,
    tone: Tone.fromDbIndex(row.toneIndex),
    range: MinuteRange(row.startMinute, row.endMinute),
    status: EventStatus.fromDbIndex(row.status),
    isFlight: row.isFlight,
    flightNumber: row.flightNumber,
    fromCode: row.fromCode,
    toCode: row.toCode,
    projectId: row.projectId,
  );

  @override
  bool operator ==(Object other) =>
      other is CalendarEvent &&
      other.id == id &&
      other.seriesId == seriesId &&
      other.date == date &&
      other.title == title &&
      other.tone == tone &&
      other.range == range &&
      other.status == status &&
      other.isFlight == isFlight &&
      other.flightNumber == flightNumber &&
      other.fromCode == fromCode &&
      other.toCode == toCode &&
      other.projectId == projectId;

  @override
  int get hashCode => Object.hash(
    id,
    seriesId,
    date,
    title,
    tone,
    range,
    status,
    isFlight,
    flightNumber,
    fromCode,
    toCode,
    projectId,
  );
}
