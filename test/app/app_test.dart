import 'dart:async';

import 'package:energy_clock/app/app.dart';
import 'package:energy_clock/app/navigation/tab_scaffold.dart';
import 'package:energy_clock/app/onboarding/onboarding_flow.dart';
import 'package:energy_clock/app/onboarding/onboarding_providers.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/clock_harness.dart';
import '../support/dial_pump.dart';
import '../support/fake_settings_repository.dart';

void main() {
  late FakeSettingsRepository settings;
  late ClockHarness harness;

  setUp(() {
    settings = FakeSettingsRepository();
    harness = ClockHarness(
      overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
    );
  });

  tearDown(() {
    harness.dispose();
  });

  Widget app() => UncontrolledProviderScope(
    container: harness.container,
    child: const EnergyClockApp(),
  );

  testWidgets('first launch shows onboarding', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingFlow), findsOneWidget);
    expect(find.byType(TabScaffold), findsNothing);
  });

  testWidgets('once onboarding has been seen, the app opens on the tabs', (
    tester,
  ) async {
    settings.values[onboardingDoneKey] = true;
    await tester.pumpWidget(app());
    await pumpDial(tester);
    expect(find.byType(TabScaffold), findsOneWidget);
    expect(find.byType(OnboardingFlow), findsNothing);
  });

  testWidgets('if the flag cannot be read, onboarding is skipped', (
    tester,
  ) async {
    settings.failReads = true;
    await tester.pumpWidget(app());
    await pumpDial(tester);
    expect(find.byType(TabScaffold), findsOneWidget);
    expect(find.byType(OnboardingFlow), findsNothing);
  });

  testWidgets('while the flag loads, neither screen is shown', (tester) async {
    settings.gate = Completer<bool>();
    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.byType(OnboardingFlow), findsNothing);
    expect(find.byType(TabScaffold), findsNothing);

    settings.gate!.complete(true);
    settings.gate = null;
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingFlow), findsOneWidget);
  });

  testWidgets('finishing onboarding opens the tabs and remembers it', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text(Strings.onboardingSkip));
    await pumpDial(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(TabScaffold), findsOneWidget);
    expect(find.byType(OnboardingFlow), findsNothing);
    expect(settings.values[onboardingDoneKey], isTrue);
  });
}
