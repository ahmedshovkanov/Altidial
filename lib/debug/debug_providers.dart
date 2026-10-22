import 'package:altidial/data/providers.dart';
import 'package:altidial/debug/debug_constants.dart';
import 'package:altidial/debug/demo_generator.dart';
import 'package:altidial/debug/demo_seeder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final debugModeProvider = AsyncNotifierProvider<DebugModeNotifier, bool>(
  DebugModeNotifier.new,
);

class DebugModeNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() =>
      ref.watch(settingsRepositoryProvider).getBool(debugModeKey);

  Future<void> set(bool value) async {
    await ref.read(settingsRepositoryProvider).setBool(debugModeKey, value);
    state = AsyncData(value);
  }
}

final demoGeneratorProvider = Provider<DemoGenerator>((ref) {
  return DemoGenerator();
});

final demoSeederProvider = Provider<DemoSeeder>((ref) {
  return DriftDemoSeeder(
    ref.watch(appDatabaseProvider),
    ref.watch(demoGeneratorProvider),
    ref.watch(settingsRepositoryProvider),
    ref.watch(progressRepositoryProvider),
    ref.watch(roundupRepositoryProvider),
  );
});
