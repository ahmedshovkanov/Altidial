/// Where an event stands. Persisted as [dbIndex] in `events.status`; never
/// reorder or reuse these numbers.
enum EventStatus {
  planned(0),
  completed(1),
  skipped(2);

  const EventStatus(this.dbIndex);

  final int dbIndex;

  static EventStatus fromDbIndex(int index) {
    for (final status in EventStatus.values) {
      if (status.dbIndex == index) return status;
    }
    throw ArgumentError.value(index, 'index', 'Unknown event status');
  }
}
