import 'dart:async';
import 'dart:math' as math;

import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/app_typography.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/geometry/dial_geometry.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/geometry/ring_layout.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/active_event.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/dial_hit_test.dart';
import 'package:energy_clock/features/clock/widgets/dial_painter.dart';
import 'package:energy_clock/features/clock/widgets/dial_semantics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The tone a freshly dragged event previews as before the user picks one.
const Tone defaultDraftTone = Tone.focus;

/// The span the empty-day hint arc points at.
const MinuteRange _hintRange = MinuteRange(540, 600);

const int _maxStagger = 5;
const int _staggerMs = 40;
const int _popMs = 250;
const Duration _resizeDuration = Duration(milliseconds: 350);

class DialView extends ConsumerStatefulWidget {
  const DialView({
    required this.events,
    required this.day,
    required this.readOnly,
    this.maxRadius,
    this.onCreateRequested,
    this.onEventTapped,
    this.onMoveRequested,
    this.onEditRequested,
    this.onDeleteRequested,
    super.key,
  });

  final List<CalendarEvent> events;
  final DateTime day;
  final bool readOnly;

  /// Caps the dial's outer radius on very large windows.
  final double? maxRadius;

  final void Function(MinuteRange range)? onCreateRequested;
  final void Function(CalendarEvent event)? onEventTapped;
  final void Function(CalendarEvent event, MinuteRange range)? onMoveRequested;

  /// Screen-reader actions on an event. Offered on editable days only.
  final void Function(CalendarEvent event)? onEditRequested;
  final void Function(CalendarEvent event)? onDeleteRequested;

  @override
  ConsumerState<DialView> createState() => _DialViewState();
}

class _DialViewState extends ConsumerState<DialView>
    with TickerProviderStateMixin {
  // Drag state. Held in minutes, not pixels, so a rotation or resize mid-drag
  // simply continues against the new geometry.
  MinuteRange? _ghostRange;
  int? _anchorMinute;
  double _continuousMinute = 0;
  int? _lastHapticMinute;
  CalendarEvent? _draggingEvent;
  ArcGrabKind? _grabKind;
  MinuteRange? _originalRange;
  MinuteRange? _draftRange;

  // Arrival animation: arcs sweep in on a new day and pop in when created.
  late final AnimationController _arrival = AnimationController(vsync: this)
    ..addStatusListener(_onArrivalStatus);
  Set<int> _knownIds = const {};
  Set<int> _animatingIds = const {};
  bool _staggered = true;
  bool _started = false;
  DateTime? _shownDay;

  // The pulsing hint arc on an empty day.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!_started) {
      _started = true;
      _shownDay = widget.day;
      _knownIds = {for (final event in widget.events) event.id};
      _startArrival(_knownIds, staggered: true);
    }
    _syncPulse();
  }

  @override
  void didUpdateWidget(DialView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = {for (final event in widget.events) event.id};
    if (widget.day != _shownDay) {
      _shownDay = widget.day;
      _knownIds = ids;
      _startArrival(ids, staggered: true);
    } else {
      final created = ids.difference(_knownIds);
      _knownIds = ids;
      if (created.isNotEmpty) _startArrival(created, staggered: false);
    }
    _syncPulse();
  }

  @override
  void dispose() {
    _arrival.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onArrivalStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _animatingIds = const {});
    }
  }

  void _startArrival(Set<int> ids, {required bool staggered}) {
    if (ids.isEmpty || _reduceMotion) {
      _animatingIds = const {};
      _arrival.value = 1;
      return;
    }
    _animatingIds = ids;
    _staggered = staggered;
    final count = math.min(ids.length, _maxStagger);
    final totalMs = staggered
        ? AppMotion.slow.inMilliseconds + (count - 1) * _staggerMs
        : _popMs;
    _arrival
      ..duration = Duration(milliseconds: totalMs)
      ..forward(from: 0);
  }

  bool get _showHint => widget.events.isEmpty && !widget.readOnly;

  void _syncPulse() {
    if (_showHint && !_reduceMotion) {
      if (!_pulse.isAnimating) unawaited(_pulse.repeat(reverse: true));
    } else {
      _pulse.stop();
    }
  }

  /// Progress of each animating arc, 0 to 1 (a little over 1 for the pop).
  Map<int, double> _arcProgress() {
    if (_animatingIds.isEmpty || _arrival.isCompleted) return const {};
    final elapsedMs = _arrival.value * (_arrival.duration?.inMilliseconds ?? 1);
    final perArcMs = _staggered ? AppMotion.slow.inMilliseconds : _popMs;
    final curve = _staggered ? AppMotion.standard : AppMotion.pop;
    final progress = <int, double>{};
    var order = 0;
    for (final event in widget.events) {
      if (!_animatingIds.contains(event.id)) continue;
      final startMs = _staggered
          ? math.min(order, _maxStagger - 1) * _staggerMs
          : 0;
      final t = ((elapsedMs - startMs) / perArcMs).clamp(0.0, 1.0);
      progress[event.id] = curve.transform(t);
      order++;
    }
    return progress;
  }

  RingAssignment get _assignment => assignRings([
    for (final event in widget.events) RingCandidate(event.id, event.range),
  ]);

  int _ringCountFor(RingAssignment assignment) =>
      assignment.ringByEventId.isEmpty
      ? 1
      : assignment.ringByEventId.values.reduce(math.max) + 1;

  /// The geometry for a (possibly fractional) ring count. Between two whole
  /// counts it blends them, so the face resizes smoothly.
  DialGeometry _geometryFor(Size size, double ringCount) {
    final clamped = ringCount
        .clamp(1.0, DialGeometry.maxRings.toDouble())
        .toDouble();
    final low = clamped.floor();
    final high = clamped.ceil();
    final a = DialGeometry.fitted(
      size,
      ringCount: low,
      maxRadius: widget.maxRadius,
    );
    if (low == high) return a;
    final b = DialGeometry.fitted(
      size,
      ringCount: high,
      maxRadius: widget.maxRadius,
    );
    return DialGeometry.lerp(a, b, clamped - low);
  }

  void _onPanStart(DragStartDetails details, DialGeometry geometry) {
    if (widget.readOnly) return;
    // Drags may start inside the face or in the orbit band. Only taps outside
    // the dial (the square's corners) are ignored. The new entry always paints
    // on the ring (the usual place); its angle follows where the user dragged.
    if (geometry.radiusAtPoint(details.localPosition) >
        geometry.orbitOuterRadius + geometry.hitSlop) {
      return;
    }

    final minute = geometry.minuteAtPoint(details.localPosition);
    final hit = eventAtPoint(
      point: details.localPosition,
      geometry: geometry,
      events: widget.events,
      ringByEventId: _assignment.ringByEventId,
    );

    if (hit != null) {
      setState(() {
        _draggingEvent = hit;
        _originalRange = hit.range;
        _draftRange = hit.range;
        _grabKind = grabKindFor(range: hit.range, touchMinute: minute);
        _anchorMinute = minute;
        _continuousMinute = minute.toDouble();
      });
      return;
    }

    setState(() {
      _anchorMinute = minute;
      _continuousMinute = minute.toDouble();
      _ghostRange = rangeFromDrag(
        anchorMinute: minute,
        currentMinute: minute.toDouble(),
      );
      _lastHapticMinute = _ghostRange!.end;
    });
  }

  void _onPanUpdate(DragUpdateDetails details, DialGeometry geometry) {
    final anchor = _anchorMinute;
    if (anchor == null) return;

    final sampled = geometry.minuteAtPoint(details.localPosition);
    _continuousMinute = unwrapMinute(_continuousMinute, sampled);

    final dragging = _draggingEvent;
    if (dragging != null) {
      final original = _originalRange!;
      final delta = (_continuousMinute - anchor).round();
      final updated = switch (_grabKind!) {
        ArcGrabKind.move => moveRange(original, delta),
        ArcGrabKind.resizeStart => resizeRangeStart(
          original,
          _continuousMinute.round(),
        ),
        ArcGrabKind.resizeEnd => resizeRangeEnd(
          original,
          _continuousMinute.round(),
        ),
      };
      if (updated.start != _draftRange?.start ||
          updated.end != _draftRange?.end) {
        unawaited(HapticFeedback.selectionClick());
      }
      setState(() => _draftRange = updated);
      return;
    }

    final range = rangeFromDrag(
      anchorMinute: anchor,
      currentMinute: _continuousMinute,
    );
    if (range.end != _lastHapticMinute || range.start != _ghostRange?.start) {
      unawaited(HapticFeedback.selectionClick());
      _lastHapticMinute = range.end;
    }
    setState(() => _ghostRange = range);
  }

  void _resetDrag() {
    setState(() {
      _ghostRange = null;
      _anchorMinute = null;
      _lastHapticMinute = null;
      _draggingEvent = null;
      _grabKind = null;
      _originalRange = null;
      _draftRange = null;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final dragging = _draggingEvent;
    final draft = _draftRange;
    final created = _ghostRange;

    _resetDrag();

    if (dragging != null && draft != null) {
      if (draft.start != dragging.range.start ||
          draft.end != dragging.range.end) {
        widget.onMoveRequested?.call(dragging, draft);
      }
      return;
    }
    if (created != null) widget.onCreateRequested?.call(created);
  }

  void _onTapUp(TapUpDetails details, DialGeometry geometry) {
    final hit = eventAtPoint(
      point: details.localPosition,
      geometry: geometry,
      events: widget.events,
      ringByEventId: _assignment.ringByEventId,
    );
    if (hit != null) {
      widget.onEventTapped?.call(hit);
      return;
    }
    if (widget.readOnly) return;
    // Taps outside the dial (the square's corners) are ignored. Anything
    // inside — the face or the orbit band — starts a new entry at the tapped
    // minute instead of the default 09:00 slot.
    if (geometry.radiusAtPoint(details.localPosition) >
        geometry.orbitOuterRadius + geometry.hitSlop) {
      return;
    }
    final minute = geometry.minuteAtPoint(details.localPosition);
    widget.onCreateRequested?.call(rangeFromTap(minute: minute));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final toneColors = context.toneColors;
    final now = ref.watch(clockProvider);
    final assignment = _assignment;
    final ringCount = _ringCountFor(assignment);
    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.2);
    final isToday = widget.day == startOfDay(now);
    final minute = minuteOfDay(now);
    final activeTone = isToday
        ? activeEventsAt(widget.events, minute).firstOrNull?.tone
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        // Hit testing always uses the target geometry, never a mid-animation
        // one, so the touch zones do not move under a finger.
        final target = _geometryFor(size, ringCount.toDouble());

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(end: ringCount.toDouble()),
          duration: _reduceMotion ? Duration.zero : _resizeDuration,
          curve: AppMotion.pop,
          builder: (context, animatedCount, _) {
            final animated = _geometryFor(size, animatedCount);
            return GestureDetector(
              onPanStart: (details) => _onPanStart(details, target),
              onPanUpdate: (details) => _onPanUpdate(details, target),
              onPanEnd: _onPanEnd,
              onPanCancel: _resetDrag,
              onTapUp: (details) => _onTapUp(details, target),
              child: AnimatedBuilder(
                animation: Listenable.merge([_arrival, _pulse]),
                builder: (context, _) {
                  final ghost = _ghostRange;
                  final dragging = _draggingEvent;
                  final draft = _draftRange;
                  final paintedEvents = dragging == null || draft == null
                      ? widget.events
                      : [
                          for (final event in widget.events)
                            if (event.id == dragging.id)
                              CalendarEvent(
                                id: event.id,
                                seriesId: event.seriesId,
                                date: event.date,
                                title: event.title,
                                tone: event.tone,
                                range: draft,
                                status: event.status,
                              )
                            else
                              event,
                        ];

                  final hintOpacity = _showHint && ghost == null
                      ? (_reduceMotion
                            ? 0.35
                            : 0.2 +
                                  0.3 *
                                      AppMotion.standard.transform(
                                        _pulse.value,
                                      ))
                      : null;

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: size,
                        painter: DialPainter(
                          geometry: animated,
                          events: paintedEvents,
                          ringByEventId: assignment.ringByEventId,
                          toneColors: toneColors,
                          style: DialStyle.fromColors(colors),
                          nowMinute: isToday ? minute : null,
                          markerTone: activeTone,
                          arcProgress: _arcProgress(),
                          popStyle: !_staggered,
                          ghostRange:
                              ghost ??
                              (hintOpacity == null ? null : _hintRange),
                          ghostTone: ghost != null
                              ? defaultDraftTone
                              : (hintOpacity == null ? null : Tone.focus),
                          ghostOpacity: ghost != null
                              ? 0.55
                              : hintOpacity ?? 0.55,
                          textScaler: textScaler,
                        ),
                      ),
                      Positioned.fill(
                        child: DialSemantics(
                          geometry: target,
                          events: widget.events,
                          ringByEventId: assignment.ringByEventId,
                          readOnly: widget.readOnly,
                          onOpen: widget.onEventTapped,
                          onEdit: widget.onEditRequested,
                          onDelete: widget.onDeleteRequested,
                        ),
                      ),
                      _DialCentre(
                        faceRadius: animated.faceRadius,
                        primary: ghost != null
                            ? formatMinuteRange(ghost.start, ghost.end)
                            : formatMinuteOfDay(minute),
                        secondary: ghost != null
                            ? formatDurationMinutes(ghost.durationMinutes)
                            : activeTone?.label,
                        secondaryColor: ghost != null
                            ? colors.muted
                            : (activeTone == null
                                  ? null
                                  : toneColors.deepFor(activeTone)),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

/// The text in the middle of the face: the time (or the range being dragged)
/// and, under it, the active tone (or the duration being dragged). Scaled down
/// to fit inside the inner 55% of the face so it never touches the numerals or
/// the rim marker.
class _DialCentre extends StatelessWidget {
  const _DialCentre({
    required this.faceRadius,
    required this.primary,
    this.secondary,
    this.secondaryColor,
  });

  final double faceRadius;
  final String primary;
  final String? secondary;
  final Color? secondaryColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return SizedBox(
      width: faceRadius * 1.1,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              primary,
              style: AppTypography.displayTime(
                faceRadius,
              ).copyWith(color: colors.ink),
            ),
            if (secondary != null)
              Text(
                secondary!,
                style: theme.textTheme.labelLarge!.copyWith(
                  color: secondaryColor ?? colors.muted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
