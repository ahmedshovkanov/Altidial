import 'package:energy_clock/app/navigation/clock_tab.dart';
import 'package:energy_clock/app/navigation/tab_bar_inset.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/session/session_alerts.dart';
import 'package:energy_clock/features/session/session_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';
import '../../support/dial_pump.dart';

/// The window sizes the Clock screen is tested at, and so the session screen,
/// which takes the same tab's place. The flag says whether it is a wide window,
/// which gets two panes.
const sizes = <String, (Size, bool)>{
  'iPhone SE': (Size(375, 667), false),
  'iPhone 17 Pro': (Size(402, 874), false),
  'iPad mini portrait': (Size(744, 1133), false),
  'iPad 11" portrait': (Size(834, 1194), false),
  'iPad 11" landscape': (Size(1194, 834), true),
  'iPad 13" portrait': (Size(1032, 1376), true),
  'iPad 13" landscape': (Size(1376, 1032), true),
  'narrow Split View': (Size(320, 1000), false),
};

/// What the screen is showing. Each changes the height of the content.
enum _State { running, overtime, recovering, alertsOffBanner }

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness(); // Wednesday 7 October 2026, 10:30
  });

  tearDown(() {
    harness.dispose();
  });

  /// Opens the app with a session left running, as a killed app would. Unless
  /// the state is [_State.recovering], the recovery card is then resumed so the
  /// ordinary controls show.
  Future<void> open(WidgetTester tester, _State state, double textScale) async {
    final eventId = await harness.repository.createEvent(
      day: DateTime(2026, 10, 7),
      title: 'A deep work session with a rather long title',
      tone: Tone.focus,
      range: const MinuteRange(600, 660),
    );
    harness.sessions.seedRunning(
      eventId: eventId,
      // Started at 09:00 it is long past its end at 10:30: overtime.
      startedAt: state == _State.overtime
          ? DateTime(2026, 10, 7, 9, 0)
          : DateTime(2026, 10, 7, 10, 20),
    );
    if (state == _State.alertsOffBanner) {
      harness.notifications
        ..enabled = false
        ..grantsRequest = false;
    }

    await tester.pumpWidget(
      harness.app(
        const TabBarInset(height: 84, child: ClockTab()),
        textScale: textScale,
      ),
    );
    await pumpDial(tester);

    if (state != _State.recovering) {
      final resume = find.byKey(const ValueKey('recovery-resume'));
      await tester.ensureVisible(resume);
      await tester.tap(resume);
      await pumpDial(tester);
    }
    if (state == _State.alertsOffBanner) {
      // The banner shows once an alert has been tried and refused.
      await harness.container
          .read(sessionAlertsProvider.notifier)
          .sync(harness.sessions.running);
      await pumpDial(tester);
    }
  }

  for (final entry in sizes.entries) {
    final (size, wide) = entry.value;
    // 3.12 is Dynamic Type's largest accessibility size on iOS.
    for (final textScale in const [1.0, 1.3, 2.0, 3.12]) {
      for (final state in _State.values) {
        testWidgets(
          '${entry.key} (${size.width.toInt()} x ${size.height.toInt()}), '
          'text ${(textScale * 100).toInt()}%, ${state.name}',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);

            await open(tester, state, textScale);

            expect(tester.takeException(), isNull);

            final ring = tester.getRect(
              find.byKey(const ValueKey('session-ring')),
            );
            expect(
              ring.shortestSide,
              greaterThanOrEqualTo(SessionLayoutPlan.minRing),
              reason: 'the ring is never smaller than its minimum',
            );
            expect(ring.left, greaterThanOrEqualTo(0));
            expect(ring.right, lessThanOrEqualTo(size.width));
            expect(
              ring.shortestSide,
              lessThanOrEqualTo(
                wide
                    ? SessionLayoutPlan.maxWideRing
                    : SessionLayoutPlan.maxRing,
              ),
            );

            // Every button can be reached by scrolling.
            final reachable = state == _State.recovering
                ? const ['recovery-resume', 'recovery-close-out']
                : const [
                    'session-pause',
                    'session-add-5',
                    'session-add-15',
                    'session-finish',
                    'session-abandon',
                  ];
            for (final key in reachable) {
              final finder = find.byKey(ValueKey(key));
              expect(finder, findsOneWidget, reason: key);
              await tester.ensureVisible(finder);
              await tester.pump();
              expect(tester.takeException(), isNull);
            }
          },
        );
      }
    }
  }

  group('without scrolling at normal text size', () {
    for (final entry in sizes.entries) {
      final (size, wide) = entry.value;
      testWidgets('${entry.key}: the whole screen fits', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await open(tester, _State.running, 1);

        final abandon = tester.getRect(
          find.byKey(const ValueKey('session-abandon')),
        );
        final pause = tester.getRect(
          find.byKey(const ValueKey('session-pause')),
        );
        final title = tester.getRect(
          find.byKey(const ValueKey('session-title')),
        );
        // The floating tab bar covers the bottom 84 points.
        expect(abandon.bottom, lessThanOrEqualTo(size.height - 84));
        expect(title.top, greaterThanOrEqualTo(0));
        if (wide) {
          final ring = tester.getRect(
            find.byKey(const ValueKey('session-ring')),
          );
          expect(pause.left, greaterThan(ring.right));
        }
      });
    }
  });
}
