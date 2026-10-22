import 'package:energy_clock/core/geometry/dial_geometry.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';

/// An event reduced to what ring assignment needs.
class RingCandidate {
  const RingCandidate(this.id, this.range);

  final int id;
  final MinuteRange range;
}

/// The result of laying out one day's events across the rings.
class RingAssignment {
  const RingAssignment(this.ringByEventId, this.overflowEventIds);

  /// Event id to ring index, counting outward from 0.
  final Map<int, int> ringByEventId;

  /// Events that would have needed a ring beyond [DialGeometry.maxRings].
  /// These are not drawn.
  final List<int> overflowEventIds;
}

/// Assigns each event the innermost ring free at its start time. Ring
/// assignment is always computed, never stored — storing it would let the
/// database drift out of sync with what is actually drawable.
RingAssignment assignRings(List<RingCandidate> candidates) {
  final sorted = [...candidates]
    ..sort((a, b) {
      final byStart = a.range.start.compareTo(b.range.start);
      return byStart != 0 ? byStart : a.id.compareTo(b.id);
    });

  // Last occupied minute per ring; -1 means the ring has never been used.
  final ringEnd = List<int>.filled(DialGeometry.maxRings, -1);
  final ringByEventId = <int, int>{};
  final overflow = <int>[];

  for (final candidate in sorted) {
    var placed = false;
    for (var ring = 0; ring < DialGeometry.maxRings; ring++) {
      if (ringEnd[ring] <= candidate.range.start) {
        ringByEventId[candidate.id] = ring;
        ringEnd[ring] = candidate.range.end;
        placed = true;
        break;
      }
    }
    if (!placed) overflow.add(candidate.id);
  }

  return RingAssignment(ringByEventId, overflow);
}

/// Thrown when a write would require a fourth overlapping ring.
class RingOverflowException implements Exception {
  const RingOverflowException();
}

/// True when adding [candidate] to [existing] would require a fourth ring.
/// Checked before writing, so the refusal happens at drag release rather than
/// silently dropping the event at render time.
bool wouldOverflowRings({
  required List<MinuteRange> existing,
  required MinuteRange candidate,
}) {
  final candidates = <RingCandidate>[
    for (var index = 0; index < existing.length; index++)
      RingCandidate(index, existing[index]),
    RingCandidate(existing.length, candidate),
  ];
  return assignRings(candidates).overflowEventIds.isNotEmpty;
}
