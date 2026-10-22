/// A generated Weekly Roundup, frozen as JSON in `weekly_roundups` (spec
/// §9.6). Hand-written codec: every field is read with an explicit cast, and
/// anything off-shape throws [FormatException].
class RoundupPayload {
  const RoundupPayload({
    required this.isoYear,
    required this.isoWeek,
    required this.weekStart,
    required this.adherencePercent,
    required this.plannedMinutes,
    required this.completedMinutes,
    required this.totalMinutes,
    required this.focusMinutes,
    required this.lifeMinutes,
    required this.inboxMinutes,
    required this.bestFocusDay,
    required this.bestFocusMinutes,
    required this.currentStreak,
    required this.longestStreak,
    required this.badgesUnlocked,
    required this.xpEarned,
    required this.previousAdherencePercent,
  });

  final int isoYear;
  final int isoWeek;

  /// The week's Monday, local midnight.
  final DateTime weekStart;

  /// Rounded percent, or null when nothing was planned that week.
  final int? adherencePercent;
  final int plannedMinutes;
  final int completedMinutes;

  /// Completed minutes over every tone.
  final int totalMinutes;

  /// Completed minutes per tone: the roundup's tone balance.
  final int focusMinutes;
  final int lifeMinutes;
  final int inboxMinutes;

  /// The week's highest focus-minutes day, or null when there was none.
  final DateTime? bestFocusDay;
  final int bestFocusMinutes;
  final int currentStreak;
  final int longestStreak;

  /// Stable badge ids unlocked during the week.
  final List<String> badgesUnlocked;
  final int xpEarned;

  /// The previous finished week's adherence, or null when there is none.
  final int? previousAdherencePercent;

  static String _date(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  static DateTime _day(String value) {
    final parsed = DateTime.tryParse(value);
    final midnight = parsed == null
        ? null
        : DateTime(parsed.year, parsed.month, parsed.day);
    if (midnight == null ||
        _date(midnight) != value ||
        parsed!.hour != 0 ||
        parsed.minute != 0) {
      throw FormatException('Not a yyyy-MM-dd date', value);
    }
    return midnight;
  }

  Map<String, Object?> toJson() => {
    'isoYear': isoYear,
    'isoWeek': isoWeek,
    'weekStart': _date(weekStart),
    'adherencePercent': adherencePercent,
    'plannedMinutes': plannedMinutes,
    'completedMinutes': completedMinutes,
    'totalMinutes': totalMinutes,
    'focusMinutes': focusMinutes,
    'lifeMinutes': lifeMinutes,
    'inboxMinutes': inboxMinutes,
    'bestFocusDay': bestFocusDay == null ? null : _date(bestFocusDay!),
    'bestFocusMinutes': bestFocusMinutes,
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'badgesUnlocked': [...badgesUnlocked],
    'xpEarned': xpEarned,
    'previousAdherencePercent': previousAdherencePercent,
  };

  factory RoundupPayload.fromJson(Map<String, Object?> json) {
    int field(String key) {
      final value = json[key];
      if (value is! int) throw FormatException('Missing int $key', json);
      return value;
    }

    int? optionalInt(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! int) throw FormatException('Bad int $key', json);
      return value;
    }

    final weekStartValue = json['weekStart'];
    if (weekStartValue is! String) {
      throw FormatException('Missing weekStart', json);
    }
    final bestDayValue = json['bestFocusDay'];
    if (bestDayValue != null && bestDayValue is! String) {
      throw FormatException('Bad bestFocusDay', json);
    }
    final badgesValue = json['badgesUnlocked'];
    if (badgesValue is! List || badgesValue.any((badge) => badge is! String)) {
      throw FormatException('Bad badgesUnlocked', json);
    }
    return RoundupPayload(
      isoYear: field('isoYear'),
      isoWeek: field('isoWeek'),
      weekStart: _day(weekStartValue),
      adherencePercent: optionalInt('adherencePercent'),
      plannedMinutes: field('plannedMinutes'),
      completedMinutes: field('completedMinutes'),
      totalMinutes: field('totalMinutes'),
      focusMinutes: field('focusMinutes'),
      lifeMinutes: field('lifeMinutes'),
      inboxMinutes: field('inboxMinutes'),
      bestFocusDay: bestDayValue == null ? null : _day(bestDayValue as String),
      bestFocusMinutes: field('bestFocusMinutes'),
      currentStreak: field('currentStreak'),
      longestStreak: field('longestStreak'),
      badgesUnlocked: [for (final badge in badgesValue) badge as String],
      xpEarned: field('xpEarned'),
      previousAdherencePercent: optionalInt('previousAdherencePercent'),
    );
  }
}
