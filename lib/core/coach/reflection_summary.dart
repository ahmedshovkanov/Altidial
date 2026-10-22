/// Pure aggregation over today's reflected sessions for the Coach review
/// block. No Flutter imports: unit-testable without a widget binding.
class ReflectionSummary {
  const ReflectionSummary({
    required this.count,
    required this.avgEnergy,
    required this.avgFocus,
    required this.topTags,
  });
  final int count;
  final double? avgEnergy;
  final double? avgFocus;
  final List<String> topTags;
}

ReflectionSummary summarizeReflections(
  List<({int? energy, int? focus, List<String> tags})> rows,
) {
  if (rows.isEmpty) {
    return const ReflectionSummary(
      count: 0,
      avgEnergy: null,
      avgFocus: null,
      topTags: [],
    );
  }
  final energies = [for (final r in rows) if (r.energy != null) r.energy!];
  final focuses = [for (final r in rows) if (r.focus != null) r.focus!];
  final tagCounts = <String, int>{};
  for (final r in rows) {
    for (final t in r.tags) {
      tagCounts[t] = (tagCounts[t] ?? 0) + 1;
    }
  }
  final top = tagCounts.entries.toList()
    ..sort(
      (a, b) => b.value.compareTo(a.value) != 0
          ? b.value.compareTo(a.value)
          : a.key.compareTo(b.key),
    );
  double? avg(List<int> xs) =>
      xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;
  return ReflectionSummary(
    count: rows.length,
    avgEnergy: avg(energies),
    avgFocus: avg(focuses),
    topTags: [for (final e in top.take(2)) e.key],
  );
}
