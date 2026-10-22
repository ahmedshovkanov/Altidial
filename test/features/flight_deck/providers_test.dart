// test/features/flight_deck/providers_test.dart
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/flight_deck/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_event_repository.dart';
import '../../support/fake_settings_repository.dart';

Future<int> addFlight(FakeEventRepository repo, DateTime day, int start) =>
    repo.createEvent(
      day: day,
      title: 'LH715',
      tone: Tone.inbox,
      range: MinuteRange(start, start + 120),
      isFlight: true,
      flightNumber: 'LH715',
      fromCode: 'SOF',
      toCode: 'BER',
    );

void main() {
  test('deckFlights splits upcoming and past around now', () async {
    final events = FakeEventRepository();
    addTearDown(events.dispose);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await addFlight(events, today.subtract(const Duration(days: 30)), 600);
    await addFlight(events, today.add(const Duration(days: 30)), 600);
    final container = ProviderContainer(
      overrides: [
        eventRepositoryProvider.overrideWithValue(events),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
      ],
    );
    addTearDown(container.dispose);
    final split = await container.read(deckFlightsProvider.future);
    expect(split.past, hasLength(1));
    expect(split.upcoming, hasLength(1));
    expect(split.next?.flightNumber, 'LH715');
  });

  test('favorites toggle persists and reverts on write failure', () async {
    final settings = FakeSettingsRepository();
    final container = ProviderContainer(
      overrides: [
        eventRepositoryProvider.overrideWithValue(FakeEventRepository()),
        settingsRepositoryProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(container.dispose);
    await container.read(flightDeckFavoritesProvider.future);
    await container
        .read(flightDeckFavoritesProvider.notifier)
        .toggle('fact-odds');
    expect(
      container.read(flightDeckFavoritesProvider).value,
      {'fact-odds'},
    );
    expect(settings.values['flight_deck_favs'], 'fact-odds');
    settings.failWrites = true;
    await container
        .read(flightDeckFavoritesProvider.notifier)
        .toggle('fact-turbulence');
    expect(
      container.read(flightDeckFavoritesProvider).value,
      {'fact-odds'},
    );
  });

  testWidgets('deckNow ticks on consecutive minute boundaries', (
    tester,
  ) async {
    // The test binding fakes timers but not DateTime.now(), so where the
    // first tick lands depends on the wall-clock second the test runs in.
    // What always holds: every 61-second window contains at least one minute
    // boundary, so three windows prove the ticker reschedules itself.
    var changes = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            ref.listen(deckNowProvider, (_, _) => changes++);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(changes, 0);

    for (var tick = 1; tick <= 3; tick++) {
      await tester.pump(const Duration(seconds: 61));
      expect(changes, greaterThanOrEqualTo(tick));
    }
  });
}
