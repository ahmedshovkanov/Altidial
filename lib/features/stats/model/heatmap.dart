import 'package:altidial/data/repositories/stats_repository.dart'
    show FocusInstant;

/// The 7×24 focus matrix: seven rows starting on [firstWeekday], each with 24
/// hour cells of whole minutes. Bucketing happens in Dart because the database
/// stores instants as epoch seconds, which SQLite cannot bucket into local
/// weekdays without mis-bucketing across timezones and DST. Seconds are summed
/// per cell, then truncated.
List<List<int>> buildHeatmap(
  List<FocusInstant> instants, {
  int firstWeekday = DateTime.monday,
}) {
  final secondsByCell = List.generate(7, (_) => List.filled(24, 0));
  for (final instant in instants) {
    final row = (instant.startedAt.weekday - firstWeekday + 7) % 7;
    secondsByCell[row][instant.startedAt.hour] += instant.activeSeconds;
  }
  return [
    for (final row in secondsByCell) [for (final seconds in row) seconds ~/ 60],
  ];
}
