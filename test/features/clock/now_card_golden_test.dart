// Golden images of the Now card's states. The clock is fixed at Wednesday
// 7 October 2026, 10:30, animations are off, and `test/flutter_test_config.dart`
// loads Nunito, so every image is deterministic and shows real text.
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/widgets/now_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

const cardKey = ValueKey('now-card-golden');

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> add(String title, Tone tone, int start, int end) =>
      harness.repository.createEvent(
        day: DateTime(2026, 10, 7),
        title: title,
        tone: tone,
        range: MinuteRange(start, end),
      );

  Future<void> check(WidgetTester tester, ThemeData theme, String file) async {
    await tester.pumpWidget(
      harness.app(
        RepaintBoundary(
          key: cardKey,
          child: Builder(
            builder: (context) => ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: 358,
                  child: NowCard(onOpenEvent: (_) {}),
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

  testWidgets('a running Focus event, light', (tester) async {
    await add('Deep work', Tone.focus, 540, 720);
    await check(tester, AppTheme.light, 'now_card_active_focus_light.png');
  });

  testWidgets('a running Life event, dark', (tester) async {
    await add('Lunch walk', Tone.life, 600, 660);
    await check(tester, AppTheme.dark, 'now_card_active_life_dark.png');
  });

  testWidgets('overlapping events, light', (tester) async {
    await add('Deep work', Tone.focus, 540, 720);
    await add('Call', Tone.inbox, 600, 660);
    await check(tester, AppTheme.light, 'now_card_overlap_light.png');
  });

  testWidgets('the next event, light', (tester) async {
    await add('Lunch', Tone.life, 750, 795);
    await check(tester, AppTheme.light, 'now_card_next_light.png');
  });

  testWidgets('a free day, light', (tester) async {
    await check(tester, AppTheme.light, 'now_card_free_light.png');
  });
}
