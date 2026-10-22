import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/calendar_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How each day of a month is planned, keyed by the first of the month. The
/// repository fills the month from its recurring series before reading it, so
/// repeating events show on every day they cover.
final monthLoadProvider =
    StreamProvider.family<Map<DateTime, ToneMinutes>, DateTime>((ref, month) {
      return ref.watch(calendarRepositoryProvider).watchMonth(month);
    });
