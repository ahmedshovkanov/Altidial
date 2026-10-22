/// The three fixed tones. This set never changes — it is a product decision,
/// and statistics, scoring, and badges all depend on it being closed.
enum Tone {
  focus(0, 'Focus'),
  life(1, 'Life'),
  inbox(2, 'Inbox');

  const Tone(this.dbIndex, this.label);

  /// Stable integer persisted in the database. Never reorder these.
  final int dbIndex;

  /// English display name.
  final String label;

  static Tone fromDbIndex(int index) {
    for (final tone in Tone.values) {
      if (tone.dbIndex == index) return tone;
    }
    throw ArgumentError.value(index, 'index', 'Unknown tone index');
  }
}
