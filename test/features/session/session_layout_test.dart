import 'package:energy_clock/features/session/session_layout.dart';
import 'package:energy_clock/shared/layout/window_class.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SessionLayoutPlan plan(
    Size size, {
    double inset = 84,
    double textScale = 1,
    WindowClass? windowClass,
    bool banner = false,
    bool recovering = false,
  }) => SessionLayoutPlan.forSize(
    size,
    inset: inset,
    textScale: textScale,
    windowClass: windowClass ?? windowClassFor(size.width),
    bannerVisible: banner,
    recovering: recovering,
  );

  group('on a phone', () {
    test('the ring fills the width on a tall phone, up to its maximum', () {
      final p = plan(const Size(402, 812), inset: 118);
      expect(p.wide, isFalse);
      expect(p.ringDiameter, 354); // 402 - 2 x 24
      expect(p.ringDiameter, lessThanOrEqualTo(SessionLayoutPlan.maxRing));
    });

    test('the ring shrinks to leave room on a short phone', () {
      final tall = plan(const Size(402, 812), inset: 118);
      final short = plan(const Size(375, 647));
      expect(short.ringDiameter, lessThan(tall.ringDiameter));
      expect(
        short.ringDiameter,
        greaterThanOrEqualTo(SessionLayoutPlan.minRing),
      );
    });

    test('the ring is never smaller than its minimum', () {
      final p = plan(const Size(320, 400), textScale: 2);
      expect(p.ringDiameter, SessionLayoutPlan.minRing);
    });

    test('a banner or the recovery card leaves less room for the ring', () {
      const size = Size(375, 647);
      final plain = plan(size).ringDiameter;
      expect(plan(size, banner: true).ringDiameter, lessThanOrEqualTo(plain));
      expect(
        plan(size, recovering: true).ringDiameter,
        lessThanOrEqualTo(plain),
      );
    });
  });

  group('the buttons', () {
    test('sit in two rows up to 115% text, then stack', () {
      expect(plan(const Size(402, 812)).stackedControls, isFalse);
      expect(
        plan(const Size(402, 812), textScale: 1.15).stackedControls,
        isFalse,
      );
      expect(
        plan(const Size(402, 812), textScale: 1.3).stackedControls,
        isTrue,
      );
    });
  });

  group('on a wide window', () {
    test('uses two panes and a large ring', () {
      final p = plan(const Size(1376, 1032), inset: 84);
      expect(p.wide, isTrue);
      expect(p.ringDiameter, greaterThan(SessionLayoutPlan.maxRing));
      expect(p.ringDiameter, lessThanOrEqualTo(SessionLayoutPlan.maxWideRing));
    });

    test('the ring is limited by the height of a landscape window', () {
      final p = plan(const Size(1194, 600), inset: 84);
      expect(p.ringDiameter, lessThanOrEqualTo(600 - 84));
    });

    test('a medium window is one column', () {
      final p = plan(const Size(744, 1133));
      expect(p.wide, isFalse);
      expect(p.ringDiameter, lessThanOrEqualTo(SessionLayoutPlan.maxRing));
    });
  });
}
