import 'package:altidial/data/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The `settings` key that records that onboarding has been seen.
const String onboardingDoneKey = 'onboarding_done';

/// Whether onboarding has been seen. If the flag cannot be read the provider
/// is in an error state, and the app skips onboarding rather than blocking.
final onboardingDoneProvider =
    AsyncNotifierProvider<OnboardingDoneNotifier, bool>(
      OnboardingDoneNotifier.new,
    );

class OnboardingDoneNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() =>
      ref.watch(settingsRepositoryProvider).getBool(onboardingDoneKey);

  /// Remembers that onboarding has been seen and moves the app on.
  Future<void> markDone() async {
    await ref.read(settingsRepositoryProvider).setBool(onboardingDoneKey, true);
    state = const AsyncData(true);
  }
}
