// lib/features/flight_deck/providers.dart
import 'dart:async';

import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/flight_deck/favorites_codec.dart';
import 'package:energy_clock/features/flight_deck/flight_sort.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Settings key holding the comma-joined ids of starred calm cards.
const String flightDeckFavoritesKey = 'flight_deck_favs';

/// Flight Deck's "now", ticking once a minute. Local to this feature so the
/// feature-import rule stays intact (the Clock tab has its own ticker).
final deckNowProvider = NotifierProvider<DeckNowNotifier, DateTime>(
  DeckNowNotifier.new,
);

class DeckNowNotifier extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    final now = DateTime.now();
    _schedule(now);
    ref.onDispose(() => _timer?.cancel());
    return now;
  }

  void _schedule(DateTime now) {
    _timer = Timer(untilNextMinute(now), () {
      final tick = DateTime.now();
      state = tick;
      _schedule(tick);
    });
  }
}

/// Every flight from a year ago to a year ahead, split at now.
final deckFlightsProvider = StreamProvider<FlightSplit>((ref) {
  final now = ref.watch(deckNowProvider);
  final from = startOfDay(now).subtract(const Duration(days: 365));
  final to = startOfDay(now).add(const Duration(days: 366));
  return ref
      .watch(eventRepositoryProvider)
      .watchFlights(from, to)
      .map((flights) => splitFlights(flights, now));
});

final flightDeckFavoritesProvider =
    AsyncNotifierProvider<FavoritesNotifier, Set<String>>(
      FavoritesNotifier.new,
    );

class FavoritesNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final stored = await ref
        .watch(settingsRepositoryProvider)
        .getString(flightDeckFavoritesKey);
    return decodeFavorites(stored);
  }

  /// Stars or unstars [id], persisting optimistically and reverting when the
  /// write fails so the UI never shows a star that isn't stored.
  Future<void> toggle(String id) async {
    final previous = state.valueOrNull ?? {};
    final next = {...previous};
    if (!next.remove(id)) next.add(id);
    state = AsyncData(next);
    try {
      await ref
          .read(settingsRepositoryProvider)
          .setString(flightDeckFavoritesKey, encodeFavorites(next));
    } on Object {
      state = AsyncData(previous);
    }
  }
}
