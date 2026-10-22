import 'package:altidial/core/progress/score.dart';
import 'package:altidial/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:altidial/core/progress/score.dart'
    show defaultDailyFocusTargetMinutes;

/// The `settings` keys this file owns.
const String themeModeKey = 'theme_mode';
const String dailyFocusTargetKey = 'daily_focus_target';
const String firstDayOfWeekKey = 'first_day_of_week';

/// Light, dark, or following the system. A stored value that is not
/// 'light' or 'dark' reads as system, so a corrupt key never blocks the app.
final themeModeProvider = AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final stored = await ref
        .watch(settingsRepositoryProvider)
        .getString(themeModeKey);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode mode) async {
    final name = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await ref.read(settingsRepositoryProvider).setString(themeModeKey, name);
    state = AsyncData(mode);
  }
}

/// The daily focus target in minutes. The settings card offers whole hours and
/// half hours; anything stored reads as-is once it parses.
final focusTargetProvider = AsyncNotifierProvider<FocusTargetNotifier, int>(
  FocusTargetNotifier.new,
);

class FocusTargetNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final stored = await ref
        .watch(settingsRepositoryProvider)
        .getInt(dailyFocusTargetKey);
    return stored ?? defaultDailyFocusTargetMinutes;
  }

  Future<void> set(int minutes) async {
    await ref
        .read(settingsRepositoryProvider)
        .setInt(dailyFocusTargetKey, minutes);
    state = AsyncData(minutes);
  }
}

/// The first day of the week: `DateTime.monday` (1) or `DateTime.sunday` (7).
/// Anything else reads as Monday, so a corrupt key cannot scramble calendars.
final firstDayOfWeekProvider =
    AsyncNotifierProvider<FirstDayOfWeekNotifier, int>(
      FirstDayOfWeekNotifier.new,
    );

class FirstDayOfWeekNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final stored = await ref
        .watch(settingsRepositoryProvider)
        .getInt(firstDayOfWeekKey);
    return stored == DateTime.sunday ? DateTime.sunday : DateTime.monday;
  }

  Future<void> set(int weekday) async {
    assert(weekday == DateTime.monday || weekday == DateTime.sunday);
    await ref
        .read(settingsRepositoryProvider)
        .setInt(firstDayOfWeekKey, weekday);
    state = AsyncData(weekday);
  }
}
