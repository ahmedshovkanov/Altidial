/// How a session ended. Persisted as [dbIndex] in `sessions.outcome`; never
/// reorder or reuse these numbers.
enum SessionOutcome {
  /// Still going. At most one session is in this state.
  running(0),

  /// Ran to its planned end or beyond.
  completed(1),

  /// Finished before the planned end.
  finishedEarly(2),

  /// Given up. Recorded, but not a completion.
  abandoned(3);

  const SessionOutcome(this.dbIndex);

  final int dbIndex;

  /// True for the two outcomes that count as having done the work.
  bool get countsAsDone =>
      this == SessionOutcome.completed || this == SessionOutcome.finishedEarly;

  static SessionOutcome fromDbIndex(int index) {
    for (final outcome in SessionOutcome.values) {
      if (outcome.dbIndex == index) return outcome;
    }
    throw ArgumentError.value(index, 'index', 'Unknown session outcome');
  }
}
