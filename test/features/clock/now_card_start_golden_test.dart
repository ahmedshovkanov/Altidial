// Golden images of the Now card with its Start button, and with Done in its
// place. The clock is fixed at Wednesday 7 October 2026, 10:30, animations are
// off, and `test/flutter_test_config.dart` loads Nunito.
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/event_status.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/widgets/now_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

const cardKey = ValueKey('now-card-start-golden');

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Future<int> add(String title, Tone tone, int start, int end) =>
      harness.repository.createEvent(
        day: DateTime(2026, 10, 7),
        title: title,
        tone: tone,
        range: MinuteRange(start, end),
      );

  Future<void> check(WidgetTester tester, ThemeData theme, String file) async {
    await tester.pumpWidget(
      harness.app(
        // Loose and top-left, with the card on unbounded height, so the image
        // is as tall as the card and no taller.
        Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: cardKey,
            child: Builder(
              builder: (context) => ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: 358,
                    child: UnconstrainedBox(
                      constrainedAxis: Axis.horizontal,
                      child: NowCard(
                        onOpenEvent: (_) {},
                        onStartSession: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        theme: theme,
        reduceMotion: true,
      ),
    );
    await tester.pump();
    await expectLater(find.byKey(cardKey), matchesGoldenFile('goldens/$file'));
  }

  testWidgets('a running Inbox event with Start, light', (tester) async {
    await add('Email and calls', Tone.inbox, 600, 660);
    await check(tester, AppTheme.light, 'now_card_start_inbox_light.png');
  });

  testWidgets('the next event with Start, dark', (tester) async {
    await add('Lunch walk', Tone.life, 750, 795);
    await check(tester, AppTheme.dark, 'now_card_start_next_dark.png');
  });

  testWidgets('a finished event says Done, light', (tester) async {
    final id = await add('Deep work', Tone.focus, 540, 720);
    harness.repository.setStatus(id, EventStatus.completed);
    await check(tester, AppTheme.light, 'now_card_done_light.png');
  });
}
