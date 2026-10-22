import 'package:energy_clock/features/clock/widgets/clock_header.dart';
import 'package:energy_clock/features/clock/widgets/day_load_bar.dart';
import 'package:energy_clock/features/clock/widgets/now_card.dart';
import 'package:energy_clock/features/clock/widgets/reuse_row.dart';
import 'package:energy_clock/features/clock/widgets/week_strip.dart';

/// Which optional pieces of the Clock screen fit, decided from the height left
/// for them and the text size.
///
/// The page never scrolls (a vertical scroll would compete with the dial's drag
/// gestures), so instead it gives way in a fixed order:
///
/// 1. At text sizes above 130%: no day-load bar, no reuse row, no week dots,
///    one-row Now card.
/// 2. Otherwise, if the dial would be under 300 pt: drop the day-load bar and
///    the reuse row (an empty day has the row where a day with events has the
///    bar; the overflow menu keeps the same actions).
/// 3. If it would still be under 260 pt: make the Now card one row.
/// 4. If it would still be under 240 pt: drop the header's date line.
class ClockLayoutPlan {
  const ClockLayoutPlan({
    required this.showDayLoad,
    required this.compactNowCard,
    required this.showHeaderDate,
    required this.showWeekDots,
    required this.dialHeight,
    this.showReuseTools = false,
  });

  final bool showDayLoad;
  final bool compactNowCard;
  final bool showHeaderDate;
  final bool showWeekDots;

  /// Whether the Copy yesterday / Apply template row has room.
  final bool showReuseTools;

  /// The height the dial area is left with under this plan.
  final double dialHeight;

  /// Space between the stacked pieces.
  static const double gap = 8;

  static const double smallDial = 300;
  static const double tinyDial = 260;
  static const double minDial = 240;
  static const double largeTextScale = 1.3;

  /// Plans the screen for [available] pt of height, after the floating tab bar.
  /// [hasDayLoad] is false on a day with no events, when the bar draws nothing
  /// and so reserves no room. [hasReuseTools] is true on an empty editable day,
  /// which wants the reuse row in the bar's place.
  static ClockLayoutPlan forHeight(
    double available, {
    double textScale = 1,
    bool hasDayLoad = true,
    bool hasReuseTools = false,
  }) {
    final scale = textScale.clamp(1.0, 2.0);
    final largeText = scale > largeTextScale;

    double dialFor({
      required bool dayLoad,
      required bool reuse,
      required bool compact,
      required bool date,
    }) {
      final header = ClockHeader.heightFor(scale, showDate: date);
      final strip = WeekStrip.heightFor(scale);
      final now = compact
          ? NowCard.compactHeightFor(scale)
          : NowCard.heightFor(scale);
      final bar = dayLoad ? gap + DayLoadBar.height : 0;
      final tools = reuse ? gap + ReuseRow.height : 0;
      // A gap under the strip and another above the Now card.
      return available - header - strip - gap - gap - now - bar - tools;
    }

    var dayLoad = hasDayLoad && !largeText;
    var reuse = hasReuseTools && !largeText;
    var compact = largeText;
    var date = true;
    var dial = dialFor(
      dayLoad: dayLoad,
      reuse: reuse,
      compact: compact,
      date: date,
    );

    if (dayLoad && dial < smallDial) {
      dayLoad = false;
      dial = dialFor(
        dayLoad: dayLoad,
        reuse: reuse,
        compact: compact,
        date: date,
      );
    }
    if (reuse && dial < smallDial) {
      reuse = false;
      dial = dialFor(
        dayLoad: dayLoad,
        reuse: reuse,
        compact: compact,
        date: date,
      );
    }
    if (!compact && dial < tinyDial) {
      compact = true;
      dial = dialFor(
        dayLoad: dayLoad,
        reuse: reuse,
        compact: compact,
        date: date,
      );
    }
    if (date && dial < minDial) {
      date = false;
      dial = dialFor(
        dayLoad: dayLoad,
        reuse: reuse,
        compact: compact,
        date: date,
      );
    }

    return ClockLayoutPlan(
      showDayLoad: dayLoad,
      showReuseTools: reuse,
      compactNowCard: compact,
      showHeaderDate: date,
      showWeekDots: !largeText,
      dialHeight: dial,
    );
  }
}
