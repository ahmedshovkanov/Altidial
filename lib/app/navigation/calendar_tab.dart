import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/features/calendar/calendar_screen.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Calendar tab. It lives in the app layer because it uses the shared
/// clock, which the Clock feature owns, and one feature may not import
/// another.
class CalendarTab extends ConsumerWidget {
  const CalendarTab({required this.onOpenDay, super.key});

  /// Called with the day the person tapped.
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CalendarScreen(
      today: startOfDay(ref.watch(clockProvider)),
      onOpenDay: onOpenDay,
    );
  }
}
