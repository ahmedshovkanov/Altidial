import 'dart:math' as math;
import 'dart:ui';

import 'package:altidial/core/geometry/dial_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

const geometry = DialGeometry(
  center: Offset(100, 100),
  faceRadius: 100,
  firstRingInset: 8,
  ringWidth: 20,
  ringGap: 4,
);

void main() {
  test('midnight points straight up', () {
    expect(geometry.angleForMinute(0), closeTo(-math.pi / 2, 1e-9));
  });

  test('angles advance clockwise through the day', () {
    expect(geometry.angleForMinute(360), closeTo(0, 1e-9));
    expect(geometry.angleForMinute(720), closeTo(math.pi / 2, 1e-9));
    expect(geometry.angleForMinute(1080), closeTo(math.pi, 1e-9));
  });

  test('minuteForAngle inverts angleForMinute', () {
    for (final minute in [0, 5, 375, 720, 1080, 1435]) {
      final angle = geometry.angleForMinute(minute.toDouble());
      expect(geometry.minuteForAngle(angle), minute);
    }
  });

  test('minuteForAngle normalises angles outside one rotation', () {
    final wrapped = geometry.angleForMinute(360) + 2 * math.pi;
    expect(geometry.minuteForAngle(wrapped), 360);
  });

  test('minuteAtPoint reads the compass points of the dial', () {
    expect(geometry.minuteAtPoint(const Offset(100, 0)), 0);
    expect(geometry.minuteAtPoint(const Offset(200, 100)), 360);
    expect(geometry.minuteAtPoint(const Offset(100, 200)), 720);
    expect(geometry.minuteAtPoint(const Offset(0, 100)), 1080);
  });

  test('radiusAtPoint measures distance from the centre', () {
    expect(geometry.radiusAtPoint(const Offset(100, 100)), 0);
    expect(geometry.radiusAtPoint(const Offset(160, 180)), closeTo(100, 1e-9));
  });

  test('there are at most three rings', () {
    expect(DialGeometry.maxRings, 3);
  });

  test('ring centres step outward by width plus gap', () {
    expect(geometry.ringCenterRadius(0), 118);
    expect(geometry.ringCenterRadius(1), 142);
    expect(geometry.ringCenterRadius(2), 166);
  });

  test('orbit band spans the face edge to the outer ring edge', () {
    expect(geometry.orbitInnerRadius, 108);
    expect(geometry.orbitOuterRadius, 176);
  });

  test('ringAtPoint finds the ring under a point', () {
    expect(geometry.ringAtPoint(const Offset(100, 100 - 118)), 0);
    expect(geometry.ringAtPoint(const Offset(100, 100 - 142)), 1);
    expect(geometry.ringAtPoint(const Offset(100, 100 - 166)), 2);
  });

  test('ringAtPoint returns null in gaps and outside the band', () {
    expect(geometry.ringAtPoint(const Offset(100, 100 - 130)), isNull);
    expect(geometry.ringAtPoint(const Offset(100, 100 - 50)), isNull);
    expect(geometry.ringAtPoint(const Offset(100, 100 - 200)), isNull);
  });

  test('isInOrbitBand includes gaps but excludes face and beyond', () {
    expect(geometry.isInOrbitBand(const Offset(100, 100 - 130)), isTrue);
    expect(geometry.isInOrbitBand(const Offset(100, 100 - 108)), isTrue);
    expect(geometry.isInOrbitBand(const Offset(100, 100 - 176)), isTrue);
    expect(geometry.isInOrbitBand(const Offset(100, 100 - 90)), isFalse);
    expect(geometry.isInOrbitBand(const Offset(100, 100 - 200)), isFalse);
  });

  group('fitted', () {
    test('fits entirely inside the given box', () {
      const size = Size(390, 500);
      final fitted = DialGeometry.fitted(size);
      expect(fitted.center, const Offset(195, 250));
      expect(fitted.orbitOuterRadius, lessThanOrEqualTo(195));
      expect(fitted.faceRadius, greaterThan(0));
    });

    test('scales with the shorter side', () {
      final small = DialGeometry.fitted(const Size(320, 800));
      final large = DialGeometry.fitted(const Size(430, 800));
      expect(large.faceRadius, greaterThan(small.faceRadius));
    });

    test('leaves the face larger than the whole orbit band', () {
      final fitted = DialGeometry.fitted(const Size(390, 500));
      final bandWidth = fitted.orbitOuterRadius - fitted.orbitInnerRadius;
      expect(fitted.faceRadius, greaterThan(bandWidth));
    });
  });

  test('pointOnCircle lands on the compass points', () {
    expect(
      geometry.pointOnCircle(100, geometry.angleForMinute(0)).dy,
      closeTo(0, 1e-9),
    );
    expect(
      geometry.pointOnCircle(100, geometry.angleForMinute(360)).dx,
      closeTo(200, 1e-9),
    );
    expect(
      geometry.pointOnCircle(100, geometry.angleForMinute(720)).dy,
      closeTo(200, 1e-9),
    );
  });

  test('labels invert only below the dial centre', () {
    expect(geometry.isLabelInverted(geometry.angleForMinute(0)), isFalse);
    expect(geometry.isLabelInverted(geometry.angleForMinute(360)), isFalse);
    expect(geometry.isLabelInverted(geometry.angleForMinute(720)), isTrue);
    expect(geometry.isLabelInverted(geometry.angleForMinute(1080)), isFalse);
  });
}
