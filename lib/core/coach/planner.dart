// lib/core/coach/planner.dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/geometry/ring_layout.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/model/calendar_event.dart';

enum SwapReason { peak, balance, lateAvoid }
enum CoachCardKind { setIntent, suggestionsReady, reviewDue, insightsNew, quiet }

class SwapSuggestion {
  const SwapSuggestion({
    required this.eventId,
    required this.fromStartMinute,
    required this.toStartMinute,
    required this.durationMinutes,
    required this.reason,
    required this.evidence,
  });
  final int eventId;
  final int fromStartMinute;
  final int toStartMinute;
  final int durationMinutes;
  final SwapReason reason;
  final String evidence;
}

/// Pure, deterministic. Max 3 suggestions. Never moves flights, never crosses
/// midnight, never proposes a 4th-ring overlap (checked via wouldOverflowRings).
List<SwapSuggestion> suggestSwaps({
  required List<CalendarEvent> today,
  required List<int> peakHours,
  required int focusTargetMinutes,
}) {
  if (today.isEmpty || peakHours.isEmpty) return [];
  final peakStart = peakHours.first * 60;
  final out = <SwapSuggestion>[];
  for (final e in today) {
    if (out.length >= 3) break;
    if (e.isFlight) continue;
    final duration = e.endMinute - e.startMinute;
    if (duration <= 0) continue;
    // Focus outside peak → move into peak start (or next free peak hour).
    if (e.tone == Tone.focus && !_inPeak(e.startMinute, peakHours)) {
      final target = _freePeakStart(today, e, peakStart, duration);
      if (target != null && target != e.startMinute) {
        out.add(SwapSuggestion(
          eventId: e.id,
          fromStartMinute: e.startMinute,
          toStartMinute: target,
          durationMinutes: duration,
          reason: SwapReason.peak,
          evidence: 'Your peak: ${peakHours.first}:00',
        ));
      }
    }
    // Inbox sitting inside peak → push to 16:00+ when it fits.
    if (e.tone == Tone.inbox && _inPeak(e.startMinute, peakHours)) {
      const lateStart = 16 * 60;
      if (lateStart == e.startMinute) continue;
      final candidate = MinuteRange(lateStart, lateStart + duration);
      if (candidate.end <= 1440 && !_overflows(today, e.id, candidate)) {
        out.add(SwapSuggestion(
          eventId: e.id,
          fromStartMinute: e.startMinute,
          toStartMinute: lateStart,
          durationMinutes: duration,
          reason: SwapReason.lateAvoid,
          evidence: 'Protects your peak',
        ));
      }
    }
  }
  if (out.length < 3 && focusTargetMinutes > 0) {
    final focusMinutes = today
        .where((e) => e.tone == Tone.focus && !e.isFlight)
        .fold(0, (sum, e) => sum + (e.endMinute - e.startMinute));
    if (focusMinutes < focusTargetMinutes) {
      final inPeakLife = today
          .where(
            (e) =>
                e.tone == Tone.life &&
                !e.isFlight &&
                _inPeak(e.startMinute, peakHours),
          )
          .toList()
        ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
      if (inPeakLife.isNotEmpty) {
        final e = inPeakLife.first;
        final duration = e.endMinute - e.startMinute;
        if (duration > 0) {
          for (var start = 12 * 60; start + duration <= 1440; start += 60) {
            if (start == e.startMinute) continue;
            final candidate = MinuteRange(start, start + duration);
            if (!_overflows(today, e.id, candidate)) {
              out.add(SwapSuggestion(
                eventId: e.id,
                fromStartMinute: e.startMinute,
                toStartMinute: start,
                durationMinutes: duration,
                reason: SwapReason.balance,
                evidence: 'Frees your peak for focus',
              ));
              break;
            }
          }
        }
      }
    }
  }
  return out;
}

bool _inPeak(int startMinute, List<int> peakHours) =>
    peakHours.contains(startMinute ~/ 60);

int? _freePeakStart(List<CalendarEvent> today, CalendarEvent self, int peakStart, int duration) {
  for (var h = 0; h < 4; h++) {
    final start = peakStart + h * 60;
    final candidate = MinuteRange(start, start + duration);
    if (candidate.end > 1440) return null;
    if (!_overflows(today, self.id, candidate)) return start;
  }
  return null;
}

bool _overflows(List<CalendarEvent> today, int excludingId, MinuteRange candidate) {
  final existing = [
    for (final e in today)
      if (e.id != excludingId) e.range,
  ];
  return wouldOverflowRings(existing: existing, candidate: candidate);
}

CoachCardKind coachCardKind({
  required bool hasIntent,
  required bool hasSuggestions,
  required bool hasReview,
  required bool hasNewInsights,
  required int hour,
}) {
  if (hour < 11 && !hasIntent) return CoachCardKind.setIntent;
  if (hasSuggestions) return CoachCardKind.suggestionsReady;
  if (hour >= 18 && !hasReview) return CoachCardKind.reviewDue;
  if (hasNewInsights) return CoachCardKind.insightsNew;
  if (!hasIntent) return CoachCardKind.setIntent;
  return CoachCardKind.quiet;
}
