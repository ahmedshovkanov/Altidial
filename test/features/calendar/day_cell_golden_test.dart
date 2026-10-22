// Golden images of the Calendar's day cell: an empty day, one tone, two tones,
// three tones, a sliver of one tone, today, and a past day, in light and dark.
// `test/flutter_test_config.dart` loads Nunito, so the numbers are real text.
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/calendar/widgets/day_cell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const goldenKey = ValueKey('day-cells-golden');

Widget cells(ThemeData theme) {
  Widget cell(
    int day,
    Map<Tone, int> minutes, {
    bool isToday = false,
    bool isPast = false,
    double size = 56,
  }) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: DayCell(
        day: DateTime(2026, 10, day),
        size: size,
        minutes: minutes,
        isToday: isToday,
        isPast: isPast,
        onTap: () {},
      ),
    );
  }

  return MaterialApp(
    theme: theme,
    debugShowCheckedModeBanner: false,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: Scaffold(
      body: Center(
        child: RepaintBoundary(
          key: goldenKey,
          child: ColoredBox(
            color: theme.scaffoldBackgroundColor,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Wrap(
                  spacing: 2,
                  runSpacing: 2,
                  children: [
                    cell(1, const {}, isPast: true),
                    cell(2, const {Tone.focus: 180}, isPast: true),
                    cell(3, const {
                      Tone.life: 120,
                      Tone.inbox: 60,
                    }, isPast: true),
                    cell(4, const {
                      Tone.focus: 240,
                      Tone.life: 90,
                      Tone.inbox: 60,
                    }),
                    cell(5, const {Tone.focus: 600, Tone.life: 5}),
                    cell(7, const {
                      Tone.focus: 180,
                      Tone.life: 60,
                      Tone.inbox: 90,
                    }, isToday: true),
                    cell(8, const {}),
                    cell(9, const {Tone.inbox: 45}, size: 44),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('day cells, light', (tester) async {
    tester.view.physicalSize = const Size(340, 260);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(cells(AppTheme.light));
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byKey(goldenKey),
      matchesGoldenFile('goldens/day_cells_light.png'),
    );
  });

  testWidgets('day cells, dark', (tester) async {
    tester.view.physicalSize = const Size(340, 260);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(cells(AppTheme.dark));
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byKey(goldenKey),
      matchesGoldenFile('goldens/day_cells_dark.png'),
    );
  });
}
