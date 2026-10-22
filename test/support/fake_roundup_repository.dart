import 'dart:async';

import 'package:energy_clock/core/roundup/roundup_payload.dart';
import 'package:energy_clock/data/repositories/roundup_repository.dart';

export 'package:energy_clock/data/repositories/roundup_repository.dart'
    show RoundupSummary;

/// In-memory [RoundupRepository] for widget tests. Tests seed [summaries] and
/// [payloads] and read [ensureCurrentCalls].
class FakeRoundupRepository implements RoundupRepository {
  FakeRoundupRepository({
    List<RoundupSummary>? summaries,
    Map<(int, int), RoundupPayload>? payloads,
  }) : summaries = summaries ?? [],
       payloads = payloads ?? {};

  final List<RoundupSummary> summaries;
  final Map<(int, int), RoundupPayload> payloads;

  int ensureCurrentCalls = 0;

  final _updates = StreamController<List<RoundupSummary>>.broadcast();

  @override
  Stream<List<RoundupSummary>> watchArchive() async* {
    yield summaries;
    yield* _updates.stream;
  }

  @override
  Future<RoundupPayload?> payload(int isoYear, int isoWeek) async =>
      payloads[(isoYear, isoWeek)];

  @override
  Future<void> ensureCurrent() async {
    ensureCurrentCalls++;
  }

  void setArchive(List<RoundupSummary> rows) {
    summaries
      ..clear()
      ..addAll(rows);
    _updates.add(summaries);
  }

  void dispose() => _updates.close();
}
