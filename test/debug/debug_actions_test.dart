import 'package:altidial/app/onboarding/onboarding_providers.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/debug/debug_actions.dart';
import 'package:altidial/debug/debug_constants.dart';
import 'package:altidial/debug/debug_providers.dart';
import 'package:altidial/debug/demo_seeder.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_progress_repository.dart';
import '../support/fake_roundup_repository.dart';
import '../support/fake_settings_repository.dart';

void main() {
  late FakeSettingsRepository settings;
  late _FakeSeeder seeder;
  late AppDatabase db;

  setUp(() {
    settings = FakeSettingsRepository();
    seeder = _FakeSeeder();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  Widget host(Widget child, {List<Override> extra = const []}) {
    return ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        appDatabaseProvider.overrideWithValue(db),
        demoSeederProvider.overrideWithValue(seeder),
        progressRepositoryProvider.overrideWithValue(FakeProgressRepository()),
        roundupRepositoryProvider.overrideWithValue(FakeRoundupRepository()),
        ...extra,
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('activate confirms, seeds and turns debug mode on', (
    tester,
  ) async {
    late WidgetRef ref;
    await tester.pumpWidget(
      host(
        Consumer(
          builder: (context, r, _) {
            ref = r;
            return TextButton(
              onPressed: () => activateDebug(context, r),
              child: const Text('activate'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('activate'));
    await tester.pumpAndSettle();
    expect(find.text('Load demo data?'), findsOneWidget);

    await tester.tap(find.text('Load demo data'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(seeder.calls, 1);
    expect(settings.values[debugModeKey], isTrue);
    expect(settings.values[onboardingDoneKey], isTrue);
    expect(ref.read(debugModeProvider).valueOrNull, isTrue);
  });

  testWidgets('regenerate seeds again and keeps debug mode on', (tester) async {
    settings.values[debugModeKey] = true;
    await tester.pumpWidget(
      host(
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => regenerateDemo(context, ref),
            child: const Text('regenerate'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('regenerate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Regenerate'));
    await tester.pumpAndSettle();

    expect(seeder.calls, 1);
    expect(settings.values[debugModeKey], isTrue);
  });

  testWidgets('exit wipes every table and returns to onboarding', (
    tester,
  ) async {
    settings.values[debugModeKey] = true;
    settings.values[onboardingDoneKey] = true;
    await db.eventDao.insertEvent(
      EventsCompanion.insert(
        date: DateTime(2026, 10, 21),
        title: 'Delete me',
        toneIndex: 0,
        startMinute: 540,
        endMinute: 600,
        createdAt: DateTime(2026, 10, 21),
        updatedAt: DateTime(2026, 10, 21),
      ),
    );

    late WidgetRef ref;
    await tester.pumpWidget(
      host(
        Consumer(
          builder: (context, r, _) {
            ref = r;
            return TextButton(
              onPressed: () => exitDebug(context, r),
              child: const Text('exit'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('exit'));
    await tester.pumpAndSettle();
    expect(find.text('Exit debug mode?'), findsOneWidget);

    await tester.tap(find.text('Exit and erase'));
    await tester.pumpAndSettle();

    expect(
      await db.eventDao.eventsBetween(DateTime(2020), DateTime(2030)),
      isEmpty,
    );
    expect(await ref.read(debugModeProvider.future), isFalse);
    expect(await ref.read(onboardingDoneProvider.future), isFalse);
  });

  testWidgets('activate does nothing when debug mode is already on', (
    tester,
  ) async {
    settings.values[debugModeKey] = true;
    await tester.pumpWidget(
      host(
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => activateDebug(context, ref),
            child: const Text('activate'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('activate'));
    await tester.pumpAndSettle();

    expect(find.text('Demo mode is already on.'), findsOneWidget);
    expect(seeder.calls, 0);
  });
}

class _FakeSeeder implements DemoSeeder {
  int calls = 0;

  @override
  Future<void> seed() async {
    calls++;
  }
}
