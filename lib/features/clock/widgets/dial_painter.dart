import 'dart:math' as math;

import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/app_typography.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/geometry/dial_geometry.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// How much wider than its arc the outline that separates neighbouring arcs is
/// painted, in the colour behind the arcs.
const double _arcOutlineExtra = 4;

/// The neutral colours the dial is drawn with. The caller resolves them from
/// the theme, so the painter never reads the theme itself.
@immutable
class DialStyle {
  const DialStyle({
    required this.page,
    required this.surface,
    required this.outline,
    required this.ink,
    required this.nightTint,
    required this.isDark,
    this.showNightTint = true,
  });

  factory DialStyle.fromColors(AppColors colors, {bool showNightTint = true}) {
    return DialStyle(
      page: colors.page,
      surface: colors.surface,
      outline: colors.outline,
      ink: colors.ink,
      nightTint: colors.nightTint,
      isDark: colors.isDark,
      showNightTint: showNightTint,
    );
  }

  /// What is behind the arcs; used for the thin outline that separates
  /// neighbouring arcs.
  final Color page;

  /// The face.
  final Color surface;

  /// Hairline around the face in dark mode.
  final Color outline;

  /// Ticks, numerals, and the marker when no event is active.
  final Color ink;

  /// The faint tint over night hours.
  final Color nightTint;

  final bool isDark;

  /// Lets the night tint be switched off if it looks busy.
  final bool showNightTint;

  @override
  bool operator ==(Object other) =>
      other is DialStyle &&
      other.page == page &&
      other.surface == surface &&
      other.outline == outline &&
      other.ink == ink &&
      other.nightTint == nightTint &&
      other.isDark == isDark &&
      other.showNightTint == showNightTint;

  @override
  int get hashCode => Object.hash(
    page,
    surface,
    outline,
    ink,
    nightTint,
    isDark,
    showNightTint,
  );
}

/// Short route label for the pinned flight overlay. Route when both codes
/// are present, otherwise the event title — never empty for a saved flight.
String flightOverlayLabel(CalendarEvent event) {
  if (event.fromCode != null && event.toCode != null) {
    return '✈ ${event.fromCode}→${event.toCode}';
  }
  return '✈ ${event.title}';
}

/// Renders the 24-hour dial: raised face, night tint, ticks, numerals, event
/// arcs with curved labels, the ghost arc, and the rim marker for "now". All
/// positioning comes from [DialGeometry] — this class owns no math of its own.
class DialPainter extends CustomPainter {
  const DialPainter({
    required this.geometry,
    required this.events,
    required this.ringByEventId,
    required this.toneColors,
    required this.style,
    this.nowMinute,
    this.markerTone,
    this.arcProgress = const {},
    this.popStyle = false,
    this.ghostRange,
    this.ghostTone,
    this.ghostOpacity = 0.55,
    this.textScaler = TextScaler.noScaling,
  });

  final DialGeometry geometry;
  final List<CalendarEvent> events;
  final Map<int, int> ringByEventId;
  final ToneColors toneColors;
  final DialStyle style;

  /// Null on any day that is not today — the marker is only meaningful there.
  final int? nowMinute;

  /// The tone of the event running now; the marker takes its colour. Null
  /// draws the marker in ink.
  final Tone? markerTone;

  /// How much of each arc is drawn, by event id, for the arrival animation. An
  /// id that is missing is fully drawn.
  final Map<int, double> arcProgress;

  /// When true, an animating arc also grows from 90% to 100% of its thickness.
  final bool popStyle;

  /// Live preview while the user drags out a new event, and the pulsing hint
  /// on an empty day.
  final MinuteRange? ghostRange;
  final Tone? ghostTone;
  final double ghostOpacity;

  /// Text drawn on the dial is geometry, so callers clamp this to 1.2.
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    _paintFace(canvas);
    if (style.showNightTint) _paintNightTint(canvas);
    _paintTicks(canvas);
    _paintNumerals(canvas);
    _paintEvents(canvas);
    _paintGhost(canvas);
    _paintMarker(canvas);
  }

  void _paintFace(Canvas canvas) {
    final center = geometry.center;
    final radius = geometry.faceRadius;
    if (!style.isDark) {
      canvas.drawCircle(
        center.translate(0, 6),
        radius,
        Paint()
          ..color = style.ink.withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
    canvas.drawCircle(center, radius, Paint()..color = style.surface);
    if (style.isDark) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = style.outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  /// Night runs 21:00 to 06:00 and wraps midnight; the edges fade over an hour.
  void _paintNightTint(Canvas canvas) {
    const hour = 1 / 24;
    final clear = style.nightTint.withValues(alpha: 0);
    final gradient = SweepGradient(
      transform: const GradientRotation(-math.pi / 2),
      colors: [
        style.nightTint,
        style.nightTint,
        clear,
        clear,
        style.nightTint,
        style.nightTint,
      ],
      stops: const [0, 5 * hour, 6 * hour, 20 * hour, 21 * hour, 1],
    );
    final rect = Rect.fromCircle(
      center: geometry.center,
      radius: geometry.faceRadius,
    );
    canvas.drawCircle(
      geometry.center,
      geometry.faceRadius - 0.5,
      Paint()..shader = gradient.createShader(rect),
    );
  }

  void _paintTicks(Canvas canvas) {
    final paint = Paint()
      ..color = style.ink.withValues(alpha: 0.4)
      ..strokeCap = StrokeCap.round;
    for (var hour = 0; hour < 24; hour++) {
      final isMajor = hour % 3 == 0;
      final length = geometry.faceRadius * (isMajor ? 0.085 : 0.045);
      paint.strokeWidth = isMajor ? 2.2 : 1.2;

      final angle = geometry.angleForMinute(hour * 60.0);
      final outer = geometry.pointOnCircle(geometry.faceRadius - 4, angle);
      final inner = geometry.pointOnCircle(
        geometry.faceRadius - 4 - length,
        angle,
      );
      canvas.drawLine(inner, outer, paint);
    }
  }

  void _paintNumerals(Canvas canvas) {
    final radius = geometry.faceRadius * 0.70;
    final numeral = AppTypography.dialNumeral(
      geometry.faceRadius,
    ).copyWith(color: style.ink);
    for (var hour = 0; hour < 24; hour += 3) {
      final painter = TextPainter(
        text: TextSpan(text: '$hour', style: numeral),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();

      final angle = geometry.angleForMinute(hour * 60.0);
      final position = geometry.pointOnCircle(radius, angle);
      painter.paint(
        canvas,
        position - Offset(painter.width / 2, painter.height / 2),
      );
      painter.dispose();
    }
  }

  void _paintEvents(Canvas canvas) {
    for (final calendarEvent in events) {
      final ring = ringByEventId[calendarEvent.id];
      if (ring == null) continue;

      final animating = arcProgress.containsKey(calendarEvent.id);
      final progress = arcProgress[calendarEvent.id] ?? 1.0;
      if (progress <= 0) continue;

      final radius = geometry.ringCenterRadius(ring);
      final thickness = popStyle && animating
          ? geometry.ringWidth * (0.9 + 0.1 * progress)
          : geometry.ringWidth;
      _paintArc(
        canvas,
        radius: radius,
        range: calendarEvent.range,
        color: toneColors.fillFor(calendarEvent.tone),
        thickness: thickness,
        progress: math.min(progress, 1),
        outline: style.page,
      );
      if (progress >= 1) {
        final room = labelRoom(calendarEvent);
        _paintCurvedLabel(
          canvas,
          text: calendarEvent.title,
          radius: radius,
          range: calendarEvent.range,
          offset: room.offset,
          sweep: room.sweep,
          color: toneColors.labelFor(calendarEvent.tone),
        );
      }
    }
    // Pinned flight overlay: flights already painted as normal Inbox arcs
    // above; this second pass draws a thicker arc on top so the block reads
    // as pinned. Same tone colour (no new palette), same geometry helpers.
    for (final flight in events.where((e) => e.isFlight)) {
      final ring = ringByEventId[flight.id];
      if (ring == null) continue;
      final progress = arcProgress[flight.id] ?? 1.0;
      if (progress <= 0) continue;
      final radius = geometry.ringCenterRadius(ring);
      _paintArc(
        canvas,
        radius: radius,
        range: flight.range,
        color: toneColors.fillFor(flight.tone),
        thickness: geometry.ringWidth * 1.3,
        progress: math.min(progress, 1),
        outline: style.page,
      );
      if (progress >= 1) {
        final room = labelRoom(flight);
        _paintCurvedLabel(
          canvas,
          text: flightOverlayLabel(flight),
          radius: radius,
          range: flight.range,
          offset: room.offset,
          sweep: room.sweep,
          color: toneColors.labelFor(flight.tone),
        );
      }
    }
  }

  /// Where along [event]'s arc its label can go, as angles from the start of
  /// the arc: `offset` is where the room begins and `sweep` how far it runs.
  ///
  /// The next arc painted on the same ring covers the end of this one: its
  /// round cap and its outline reach back past its own start. The label slides
  /// back to make room, into this arc's own rounded start, by up to a third of
  /// the ring width (the cap is half the ring width long, but it narrows to a
  /// point, so text of this height can use about 0.43 of it). Room is lost only
  /// beyond that. An arc that nothing covers keeps its whole range.
  @visibleForTesting
  ({double offset, double sweep}) labelRoom(CalendarEvent event) {
    final start = geometry.angleForMinute(event.range.start.toDouble());
    final end = geometry.angleForMinute(event.range.end.toDouble());
    final ring = ringByEventId[event.id];
    final index = events.indexOf(event);
    if (ring == null || index < 0) return (offset: 0, sweep: end - start);

    final radius = geometry.ringCenterRadius(ring);
    final reach = (geometry.ringWidth / 2 + _arcOutlineExtra / 2) / radius;
    var covered = 0.0;
    for (final later in events.skip(index + 1)) {
      if (ringByEventId[later.id] != ring) continue;
      final gap = geometry.angleForMinute(later.range.start.toDouble()) - end;
      covered = math.max(covered, reach - gap);
    }
    final slide = math.min(covered, geometry.ringWidth / 3 / radius);
    return (
      offset: -slide,
      sweep: math.max(0.0, end - start - covered + slide),
    );
  }

  void _paintGhost(Canvas canvas) {
    final range = ghostRange;
    final tone = ghostTone;
    if (range == null || tone == null) return;

    _paintArc(
      canvas,
      radius: geometry.ringCenterRadius(0),
      range: range,
      color: toneColors.fillFor(tone).withValues(alpha: ghostOpacity),
      thickness: geometry.ringWidth,
    );
  }

  void _paintArc(
    Canvas canvas, {
    required double radius,
    required MinuteRange range,
    required Color color,
    required double thickness,
    double progress = 1,
    Color? outline,
  }) {
    final startAngle = geometry.angleForMinute(range.start.toDouble());
    final fullSweep =
        geometry.angleForMinute(range.end.toDouble()) - startAngle;
    final sweep = fullSweep * progress;
    final rect = Rect.fromCircle(center: geometry.center, radius: radius);

    if (outline != null) {
      canvas.drawArc(
        rect,
        startAngle,
        sweep,
        false,
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness + _arcOutlineExtra
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawArc(
      rect,
      startAngle,
      sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Draws the title along the arc, one glyph at a time, inside the stretch of
  /// the arc that starts [offset] radians from its start and runs for [sweep]
  /// (see [labelRoom]). Omits the label entirely when that stretch is too short
  /// to hold it — a clipped or overlapping label is worse than none, and the
  /// event is still identifiable by tap.
  void _paintCurvedLabel(
    Canvas canvas, {
    required String text,
    required double radius,
    required MinuteRange range,
    required double offset,
    required double sweep,
    required Color color,
  }) {
    if (text.isEmpty) return;

    final labelStyle = AppTypography.arcLabel(
      geometry.ringWidth,
    ).copyWith(color: color);

    final measure = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    final totalWidth = measure.width;
    measure.dispose();

    final startAngle = geometry.angleForMinute(range.start.toDouble()) + offset;
    final availableWidth = sweep * radius;
    if (totalWidth > availableWidth * 0.88) return;

    final margin = (sweep - totalWidth / radius) / 2;
    final inverted = geometry.isLabelInverted(startAngle + sweep / 2);

    // The first glyph is always drawn first. On the lower half the loop walks
    // the arc anticlockwise, which is left to right on screen, so the text
    // already reads in order; reversing the glyphs as well would spell it
    // backwards.
    final glyphs = text.characters;
    var angle = inverted ? startAngle + sweep - margin : startAngle + margin;

    for (final glyph in glyphs) {
      final painter = TextPainter(
        text: TextSpan(text: glyph, style: labelStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();

      final glyphWidth = painter.width;
      final glyphAngle = inverted
          ? angle - (glyphWidth / 2) / radius
          : angle + (glyphWidth / 2) / radius;

      canvas.save();
      canvas.translate(geometry.center.dx, geometry.center.dy);
      canvas.rotate(
        inverted ? glyphAngle - math.pi / 2 : glyphAngle + math.pi / 2,
      );
      canvas.translate(0, inverted ? radius : -radius);
      painter.paint(canvas, Offset(-glyphWidth / 2, -painter.height / 2));
      canvas.restore();

      angle += inverted ? -glyphWidth / radius : glyphWidth / radius;
      painter.dispose();
    }
  }

  /// A thick capsule on the rim of the face marks the current minute. It
  /// stays clear of the numerals and of the centre text.
  void _paintMarker(Canvas canvas) {
    final minute = nowMinute;
    if (minute == null) return;

    final angle = geometry.angleForMinute(minute.toDouble());
    final inner = geometry.pointOnCircle(geometry.faceRadius * 0.80, angle);
    final outer = geometry.pointOnCircle(geometry.faceRadius * 0.96, angle);
    final thickness = math.max(6.0, 0.05 * geometry.faceRadius);
    final tone = markerTone;
    final color = tone == null ? style.ink : toneColors.fillFor(tone);

    canvas.drawLine(
      inner,
      outer,
      Paint()
        ..color = style.surface
        ..strokeWidth = thickness + 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      inner,
      outer,
      Paint()
        ..color = color
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(DialPainter oldDelegate) {
    return oldDelegate.geometry != geometry ||
        !listEquals(oldDelegate.events, events) ||
        !mapEquals(oldDelegate.ringByEventId, ringByEventId) ||
        oldDelegate.toneColors != toneColors ||
        oldDelegate.style != style ||
        oldDelegate.nowMinute != nowMinute ||
        oldDelegate.markerTone != markerTone ||
        !mapEquals(oldDelegate.arcProgress, arcProgress) ||
        oldDelegate.popStyle != popStyle ||
        oldDelegate.ghostRange != ghostRange ||
        oldDelegate.ghostTone != ghostTone ||
        oldDelegate.ghostOpacity != ghostOpacity ||
        oldDelegate.textScaler != textScaler;
  }
}
