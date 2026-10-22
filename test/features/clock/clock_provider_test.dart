import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/features/clock/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';

void main() {
  group('untilNextMinute', () {
    test('a whole minute from a minute boundary', () {
      expect(
        untilNextMinute(DateTime(2026, 10, 3, 10, 30)),
        const Duration(minutes: 1),
      );
    });

    test('the rest of the minute otherwise', () {
      expect(
        untilNextMinute(DateTime(2026, 10, 3, 10, 30, 45, 500)),
        const Duration(seconds: 14, milliseconds: 500),
      );
    });

    test('crosses midnight', () {
      expect(
        untilNextMinute(DateTime(2026, 10, 3, 23, 59, 59)),
        const Duration(seconds: 1),
      );
    });
  });

  test('a fake clock is deterministic and can be moved', () {
    final fake = FakeClock(DateTime(2026, 10, 3, 10, 30));
    final container = ProviderContainer(
      overrides: [clockProvider.overrideWith(() => fake)],
    );
    addTearDown(container.dispose);

    expect(container.read(clockProvider), DateTime(2026, 10, 3, 10, 30));
    fake.set(DateTime(2026, 10, 3, 10, 31));
    expect(container.read(clockProvider), DateTime(2026, 10, 3, 10, 31));
  });

  test(
    'the selected day starts at the clock\'s today and Today returns to it',
    () {
      final fake = FakeClock(DateTime(2026, 10, 3, 10, 30));
      final container = ProviderContainer(
        overrides: [clockProvider.overrideWith(() => fake)],
      );
      addTearDown(container.dispose);

      expect(container.read(selectedDateProvider), DateTime(2026, 10, 3));
      container
          .read(selectedDateProvider.notifier)
          .select(DateTime(2026, 12, 25, 18));
      expect(container.read(selectedDateProvider), DateTime(2026, 12, 25));
      container.read(selectedDateProvider.notifier).today();
      expect(container.read(selectedDateProvider), DateTime(2026, 10, 3));
    },
  );

  test('the real clock starts at the current time', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final read = container.read(clockProvider);
    expect(DateTime.now().difference(read).inSeconds.abs(), lessThan(2));
  });

  testWidgets('the real clock ticks once a minute and reschedules itself', (
    tester,
  ) async {
    // The test binding fakes timers but not DateTime.now(), so where the first
    // tick lands depends on the wall-clock second the test runs in. What always
    // holds: every 61-second window contains at least one tick.
    var changes = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            ref.listen(clockProvider, (_, _) => changes++);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(changes, 0);

    await tester.pump(const Duration(seconds: 61));
    final afterFirstWindow = changes;
    expect(afterFirstWindow, greaterThanOrEqualTo(1));

    await tester.pump(const Duration(seconds: 61));
    expect(changes, greaterThan(afterFirstWindow));
  });

  testWidgets('disposing the scope cancels the timer', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            ref.watch(clockProvider);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    // The framework fails the test if a timer is still pending here.
  });
}
