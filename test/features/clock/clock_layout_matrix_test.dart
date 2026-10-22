import 'package:altidial/app/navigation/tab_bar_inset.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/features/clock/clock_screen.dart';
import 'package:altidial/features/clock/widgets/dial_view.dart';
import 'package:altidial/features/clock/widgets/now_card.dart';
import 'package:altidial/features/clock/widgets/todays_plan_list.dart';
import 'package:altidial/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';
import '../../support/dial_pump.dart';

/// Every window size the Clock screen must work at, from the smallest iPhone to
/// the largest iPad, in the orientations and Split View widths it can be given.
/// The expected layout is the window class: wide windows get the two-pane
/// layout and the Today's plan list.
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

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness(); // Wednesday 7 October 2026, 10:30
  });

  tearDown(() {
    harness.dispose();
  });

  for (final entry in sizes.entries) {
    final (size, wide) = entry.value;
    // 3.12 is Dynamic Type's largest accessibility size on iOS.
    for (final textScale in const [1.0, 1.3, 2.0, 3.12]) {
      for (final withEvents in const [false, true]) {
        testWidgets(
          '${entry.key} (${size.width.toInt()} x ${size.height.toInt()}), '
          'text ${(textScale * 100).toInt()}%, '
          '${withEvents ? 'with' : 'without'} events',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);

            if (withEvents) {
              for (final (title, tone, start, end) in [
                ('Deep work', Tone.focus, 540, 720),
                ('Walk', Tone.life, 600, 660),
                ('A call with a long title', Tone.inbox, 610, 630),
              ]) {
                await harness.repository.createEvent(
                  day: DateTime(2026, 10, 7),
                  title: title,
                  tone: tone,
                  range: MinuteRange(start, end),
                );
              }
            }

            await tester.pumpWidget(
              harness.app(
                const TabBarInset(height: 84, child: ClockScreen()),
                textScale: textScale,
              ),
            );
            await pumpDial(tester);

            expect(tester.takeException(), isNull);
            expect(
              tester.getSize(find.byType(DialView)).shortestSide,
              greaterThanOrEqualTo(240),
            );
            // The list draws nothing on an empty day, so look for its rows.
            expect(
              find
                  .descendant(
                    of: find.byType(TodaysPlanList),
                    matching: find.byType(AppCard),
                  )
                  .evaluate()
                  .isNotEmpty,
              wide && withEvents,
              reason: wide
                  ? 'a wide window with events shows the plan list'
                  : 'only wide windows show the plan list',
            );
            expect(find.byType(NowCard), findsOneWidget);
            expect(
              tester.widget<DialView>(find.byType(DialView)).maxRadius,
              wide ? 340 : isNull,
            );
          },
        );
      }
    }
  }
}
