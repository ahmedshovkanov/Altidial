import 'package:altidial/data/providers.dart';
import 'package:altidial/debug/debug_constants.dart';
import 'package:altidial/debug/debug_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_settings_repository.dart';

void main() {
  test('debug mode defaults to off and persists when set', () async {
    final settings = FakeSettingsRepository();
    final container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
    );
    addTearDown(container.dispose);

    expect(await container.read(debugModeProvider.future), isFalse);
    await container.read(debugModeProvider.notifier).set(true);
    expect(container.read(debugModeProvider).valueOrNull, isTrue);
    expect(settings.values[debugModeKey], isTrue);

    await container.read(debugModeProvider.notifier).set(false);
    expect(settings.values[debugModeKey], isFalse);
  });
}
