import 'dart:async';

import 'package:altidial/data/repositories/stats_repository.dart';

/// In-memory [StatsRepository] for widget tests. Tests seed [snapshot] (or
/// call [emit]) and read [requests] to assert which window was asked for.
class FakeStatsRepository implements StatsRepository {
  FakeStatsRepository({StatsSnapshot? snapshot})
    : snapshot = snapshot ?? const StatsSnapshot.empty();

  StatsSnapshot snapshot;

  /// Every `(from, toExclusive)` the repository was asked to watch.
  final List<({DateTime from, DateTime to})> requests = [];

  final _updates = StreamController<StatsSnapshot>.broadcast();

  @override
  Stream<StatsSnapshot> watchWindow(
    DateTime from,
    DateTime toExclusive,
  ) async* {
    requests.add((from: from, to: toExclusive));
    yield snapshot;
    yield* _updates.stream;
  }

  /// Replaces the snapshot and re-emits to every watcher.
  void emit(StatsSnapshot next) {
    snapshot = next;
    _updates.add(next);
  }

  void dispose() => _updates.close();
}
