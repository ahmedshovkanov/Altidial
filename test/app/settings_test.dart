import 'package:energy_clock/app/navigation/tab_scaffold.dart';
import 'package:energy_clock/app/app.dart';
import 'package:energy_clock/app/onboarding/onboarding_providers.dart';
import 'package:energy_clock/app/settings/settings_providers.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_settings_repository.dart';

void main() {
  ProviderContainer containerWith(FakeSettingsRepository settings) {
    final container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('the theme falls back to following the system', () async {
    final container = containerWith(FakeSettingsRepository());
    expect(await container.read(themeModeProvider.future), ThemeMode.system);
  });

  test('a stored theme is read, and an unknown one reads as system', () async {
    final dark = containerWith(
      FakeSettingsRepository(values: {'theme_mode': 'dark'}),
    );
    expect(await dark.read(themeModeProvider.future), ThemeMode.dark);

    final bogus = containerWith(
      FakeSettingsRepository(values: {'theme_mode': 'chartreuse'}),
    );
    expect(await bogus.read(themeModeProvider.future), ThemeMode.system);
  });

  test('setting the theme stores its name', () async {
    final settings = FakeSettingsRepository();
    final container = containerWith(settings);
    await container.read(themeModeProvider.notifier).set(ThemeMode.light);
    expect(settings.values['theme_mode'], 'light');
    expect(container.read(themeModeProvider), const AsyncData(ThemeMode.light));
  });

  test(
    'the focus target defaults to 180 minutes and reads a stored one',
    () async {
      final fallback = containerWith(FakeSettingsRepository());
      expect(await fallback.read(focusTargetProvider.future), 180);

      final stored = containerWith(
        FakeSettingsRepository(values: {dailyFocusTargetKey: '240'}),
      );
      expect(await stored.read(focusTargetProvider.future), 240);
    },
  );

  test('setting the focus target stores its minutes', () async {
    final settings = FakeSettingsRepository();
    final container = containerWith(settings);
    await container.read(focusTargetProvider.notifier).set(300);
    expect(settings.values[dailyFocusTargetKey], '300');
    expect(await container.read(focusTargetProvider.future), 300);
  });

  test(
    'the first day of week defaults to Monday, accepts Sunday, rejects anything else',
    () async {
      final fallback = containerWith(FakeSettingsRepository());
      expect(
        await fallback.read(firstDayOfWeekProvider.future),
        DateTime.monday,
      );

      final sunday = containerWith(
        FakeSettingsRepository(values: {firstDayOfWeekKey: '7'}),
      );
      expect(await sunday.read(firstDayOfWeekProvider.future), DateTime.sunday);

      final bogus = containerWith(
        FakeSettingsRepository(values: {firstDayOfWeekKey: '3'}),
      );
      expect(await bogus.read(firstDayOfWeekProvider.future), DateTime.monday);
    },
  );

  test('setting the first day of week stores the weekday', () async {
    final settings = FakeSettingsRepository();
    final container = containerWith(settings);
    await container.read(firstDayOfWeekProvider.notifier).set(DateTime.sunday);
    expect(settings.values[firstDayOfWeekKey], '7');
  });

  test('unreadable settings leave every provider in error', () async {
    final settings = FakeSettingsRepository()..failReads = true;
    final container = containerWith(settings);
    expect(
      container.read(themeModeProvider.future),
      throwsA(isA<StateError>()),
    );
  });

  testWidgets('the app renders in dark mode when the setting says dark', (
    tester,
  ) async {
    final settings = FakeSettingsRepository(
      values: {onboardingDoneKey: true, 'theme_mode': 'dark'},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
        child: const EnergyClockApp(),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(TabScaffold));
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}
