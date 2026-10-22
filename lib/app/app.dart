import 'package:energy_clock/app/navigation/tab_scaffold.dart';
import 'package:energy_clock/app/onboarding/onboarding_flow.dart';
import 'package:energy_clock/app/onboarding/onboarding_providers.dart';
import 'package:energy_clock/app/settings/settings_providers.dart';
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EnergyClockApp extends ConsumerWidget {
  const EnergyClockApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingDoneProvider);

    return MaterialApp(
      title: Strings.appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // While the stored choice is still loading, follow the system.
      themeMode: ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: onboarding.when(
        data: (done) => done ? const TabScaffold() : const OnboardingFlow(),
        // A launch where the flag cannot be read must never be blocked by
        // onboarding.
        error: (error, stack) => const TabScaffold(),
        loading: () => const _Splash(),
      ),
    );
  }
}

/// A blank page in the app background, shown for the instant the flag loads.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: Theme.of(context).scaffoldBackgroundColor);
  }
}
