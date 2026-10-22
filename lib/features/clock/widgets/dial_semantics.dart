import 'package:altidial/core/geometry/dial_geometry.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/features/clock/model/calendar_event.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

/// Screen-reader nodes laid over the dial: the dial as a labelled group and
/// one node per event, in chronological order, each placed over its arc.
///
/// The nodes sit over an empty box, which is already transparent to touches.
/// They must not be wrapped in `IgnorePointer`: that also blocks their
/// semantic actions.
class DialSemantics extends StatelessWidget {
  const DialSemantics({
    required this.geometry,
    required this.events,
    required this.ringByEventId,
    required this.readOnly,
    this.onOpen,
    this.onEdit,
    this.onDelete,
    super.key,
  });

  static const CustomSemanticsAction editAction = CustomSemanticsAction(
    label: Strings.edit,
  );
  static const CustomSemanticsAction deleteAction = CustomSemanticsAction(
    label: Strings.delete,
  );

  final DialGeometry geometry;
  final List<CalendarEvent> events;
  final Map<int, int> ringByEventId;

  /// A read-only day offers "open" only.
  final bool readOnly;

  final void Function(CalendarEvent event)? onOpen;
  final void Function(CalendarEvent event)? onEdit;
  final void Function(CalendarEvent event)? onDelete;

  Rect _arcBounds(CalendarEvent event, int ring) {
    final radius = geometry.ringCenterRadius(ring);
    final start = geometry.angleForMinute(event.startMinute.toDouble());
    final sweep = geometry.angleForMinute(event.endMinute.toDouble()) - start;
    final path = Path()
      ..addArc(
        Rect.fromCircle(center: geometry.center, radius: radius),
        start,
        sweep,
      );
    return path.getBounds().inflate(geometry.ringWidth / 2);
  }

  @override
  Widget build(BuildContext context) {
    final ordered = [...events]
      ..sort((a, b) {
        final byStart = a.startMinute.compareTo(b.startMinute);
        return byStart != 0 ? byStart : a.id.compareTo(b.id);
      });

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: Strings.dialSemanticsLabel,
      child: Stack(
        children: [
          for (final event in ordered)
            if (ringByEventId[event.id] case final ring?)
              Positioned.fromRect(
                rect: _arcBounds(event, ring),
                child: Semantics(
                  container: true,
                  button: true,
                  label:
                      event.isFlight &&
                          event.fromCode != null &&
                          event.toCode != null
                      ? Strings.flightSemantics(
                          event.title.isEmpty
                              ? (event.flightNumber ?? '')
                              : event.title,
                          Strings.flightRoute(event.fromCode!, event.toCode!),
                          formatMinuteOfDay(event.startMinute),
                          formatMinuteOfDay(event.endMinute),
                        )
                      : Strings.eventSemantics(
                          event.title,
                          event.tone.label,
                          formatMinuteOfDay(event.startMinute),
                          formatMinuteOfDay(event.endMinute),
                          spokenDurationMinutes(event.range.durationMinutes),
                        ),
                  onTap: onOpen == null ? null : () => onOpen!(event),
                  customSemanticsActions: {
                    if (!readOnly && onEdit != null)
                      editAction: () => onEdit!(event),
                    if (!readOnly && onDelete != null)
                      deleteAction: () => onDelete!(event),
                  },
                  child: const SizedBox.expand(),
                ),
              ),
        ],
      ),
    );
  }
}
