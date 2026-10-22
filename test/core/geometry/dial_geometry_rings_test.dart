import 'dart:ui';

import 'package:altidial/core/geometry/dial_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A 400-wide box leaves an outer radius of 192.
  const box = Size(400, 400);
  const outer = 192.0;

  group('fitted for each ring count', () {
    test('the face fills 0.805, 0.677 and 0.589 of the outer radius', () {
      expect(
        DialGeometry.fitted(box, ringCount: 1).faceRadius,
        closeTo(outer * 0.805, 1e-9),
      );
      expect(
        DialGeometry.fitted(box, ringCount: 2).faceRadius,
        closeTo(outer * 0.677, 1e-9),
      );
      expect(
        DialGeometry.fitted(box, ringCount: 3).faceRadius,
        closeTo(outer * 0.589, 1e-9),
      );
    });

    test('three rings is the default and matches the original geometry', () {
      final geometry = DialGeometry.fitted(box);
      expect(geometry.ringCount, 3);
      expect(geometry.ringWidth, closeTo(outer * 0.11, 1e-9));
      expect(geometry.ringGap, closeTo(outer * 0.018, 1e-9));
      expect(geometry.firstRingInset, closeTo(outer * 0.045, 1e-9));
      expect(geometry.faceRadius, closeTo(outer * 0.589, 1e-9));
    });

    test('fewer rings give a bigger face and thicker arcs', () {
      final one = DialGeometry.fitted(box, ringCount: 1);
      final two = DialGeometry.fitted(box, ringCount: 2);
      final three = DialGeometry.fitted(box, ringCount: 3);
      expect(one.faceRadius, greaterThan(two.faceRadius));
      expect(two.faceRadius, greaterThan(three.faceRadius));
      expect(one.ringWidth, greaterThan(two.ringWidth));
      expect(two.ringWidth, greaterThan(three.ringWidth));
    });

    test('the outermost ring always ends at the outer radius', () {
      for (var count = 1; count <= 3; count++) {
        final geometry = DialGeometry.fitted(box, ringCount: count);
        expect(
          geometry.orbitOuterRadius,
          closeTo(outer, 1e-9),
          reason: '$count rings',
        );
        expect(geometry.ringCount, count);
      }
    });

    test('maxRadius caps the dial and keeps it centred in the box', () {
      final geometry = DialGeometry.fitted(
        const Size(1000, 800),
        ringCount: 1,
        maxRadius: 340,
      );
      expect(geometry.orbitOuterRadius, closeTo(340, 1e-9));
      expect(geometry.center, const Offset(500, 400));
    });

    test('a roomy box is limited by its shorter side', () {
      final geometry = DialGeometry.fitted(const Size(800, 400), ringCount: 1);
      expect(geometry.orbitOuterRadius, closeTo(192, 1e-9));
    });

    test('rejects a ring count outside 1 to 3', () {
      expect(
        () => DialGeometry.fitted(box, ringCount: 0),
        throwsAssertionError,
      );
      expect(
        () => DialGeometry.fitted(box, ringCount: 4),
        throwsAssertionError,
      );
    });

    test('the hit slop defaults to 12', () {
      expect(DialGeometry.fitted(box).hitSlop, DialGeometry.defaultHitSlop);
      expect(DialGeometry.defaultHitSlop, 12);
    });
  });

  group('touch targets', () {
    test('a one-ring dial on a small phone still has 44 pt targets', () {
      // iPhone SE: about 330 pt of dial box, so an outer radius near 157.
      final geometry = DialGeometry.fitted(const Size(330, 330), ringCount: 1);
      final band =
          geometry.orbitOuterRadius -
          geometry.orbitInnerRadius +
          2 * geometry.hitSlop;
      final ring = geometry.ringWidth + 2 * geometry.hitSlop;
      expect(band, greaterThanOrEqualTo(44));
      expect(ring, greaterThanOrEqualTo(44));
    });
  });

  group('hit testing with slop', () {
    // Rings centred at 118, 142 and 166 from the centre, each 20 thick.
    const geometry = DialGeometry(
      center: Offset(200, 200),
      faceRadius: 100,
      firstRingInset: 8,
      ringWidth: 20,
      ringGap: 4,
      hitSlop: 6,
    );

    Offset at(double radius) => Offset(200 + radius, 200);

    test('a point inside a ring still maps to it', () {
      expect(geometry.ringAtPoint(at(118)), 0);
      expect(geometry.ringAtPoint(at(142)), 1);
      expect(geometry.ringAtPoint(at(166)), 2);
    });

    test('a point in the gap goes to the nearer ring centre', () {
      // Radius 131 is 13 from ring 0 and 11 from ring 1; both are in reach.
      expect(geometry.ringAtPoint(at(131)), 1);
      expect(geometry.ringAtPoint(at(129)), 0);
    });

    test('a point just off the outer ring still counts', () {
      expect(geometry.ringAtPoint(at(180)), 2);
      expect(geometry.ringAtPoint(at(183)), isNull);
    });

    test('a point just inside the orbit still counts for ring 0', () {
      expect(geometry.ringAtPoint(at(103)), 0);
      expect(geometry.ringAtPoint(at(100)), isNull);
    });

    test('with no slop a gap is a miss, as before', () {
      const strict = DialGeometry(
        center: Offset(200, 200),
        faceRadius: 100,
        firstRingInset: 8,
        ringWidth: 20,
        ringGap: 4,
      );
      expect(strict.ringAtPoint(at(130)), isNull);
      expect(strict.ringAtPoint(at(127.5)), 0);
    });

    test('the creation band is widened by the slop on both sides', () {
      // Orbit runs 108 to 176; with slop 6 the band is 102 to 182.
      expect(geometry.isInOrbitBand(at(101)), isFalse);
      expect(geometry.isInOrbitBand(at(103)), isTrue);
      expect(geometry.isInOrbitBand(at(181)), isTrue);
      expect(geometry.isInOrbitBand(at(183)), isFalse);
    });

    test('a one-ring geometry has no ring 1 or 2 to hit', () {
      const one = DialGeometry(
        center: Offset(200, 200),
        faceRadius: 100,
        firstRingInset: 8,
        ringWidth: 20,
        ringGap: 4,
        ringCount: 1,
      );
      expect(one.ringAtPoint(at(118)), 0);
      expect(one.ringAtPoint(at(142)), isNull);
      expect(one.orbitOuterRadius, 128);
    });
  });

  group('lerp', () {
    test('returns the end sizes at t = 0 and t = 1', () {
      final a = DialGeometry.fitted(box, ringCount: 1);
      final b = DialGeometry.fitted(box, ringCount: 3);
      // The ring count of the result is always the target's, so at t = 0 only
      // the sizes match the start.
      final start = DialGeometry.lerp(a, b, 0);
      expect(start.faceRadius, a.faceRadius);
      expect(start.ringWidth, a.ringWidth);
      expect(start.ringGap, a.ringGap);
      expect(start.firstRingInset, a.firstRingInset);
      expect(DialGeometry.lerp(a, b, 1), b);
    });

    test('blends the sizes halfway at t = 0.5', () {
      final a = DialGeometry.fitted(box, ringCount: 1);
      final b = DialGeometry.fitted(box, ringCount: 3);
      final mid = DialGeometry.lerp(a, b, 0.5);
      expect(mid.faceRadius, closeTo((a.faceRadius + b.faceRadius) / 2, 1e-9));
      expect(mid.ringWidth, closeTo((a.ringWidth + b.ringWidth) / 2, 1e-9));
      expect(mid.center, a.center);
    });

    test('keeps the target ring count for hit testing', () {
      final a = DialGeometry.fitted(box, ringCount: 1);
      final b = DialGeometry.fitted(box, ringCount: 3);
      expect(DialGeometry.lerp(a, b, 0.3).ringCount, 3);
    });
  });

  test('equality and hashCode include the new fields', () {
    final a = DialGeometry.fitted(box, ringCount: 2);
    final b = DialGeometry.fitted(box, ringCount: 2);
    final c = DialGeometry.fitted(box, ringCount: 3);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
    expect(a, isNot(DialGeometry.fitted(box, ringCount: 2, hitSlop: 0)));
  });
}
