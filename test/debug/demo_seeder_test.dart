import 'package:altidial/app/onboarding/onboarding_providers.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/repositories/progress_repository.dart';
import 'package:altidial/data/repositories/roundup_repository.dart';
import 'package:altidial/data/repositories/settings_repository.dart';
import 'package:altidial/debug/debug_constants.dart';
import 'package:altidial/debug/demo_generator.dart';
import 'package:altidial/debug/demo_seeder.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftSettingsRepository settings;
  final now = DateTime(2026, 10, 22, 15, 30);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    settings = DriftSettingsRepository(db.settingsDao);
  });

  tearDown(() async => db.close());

  DriftDemoSeeder seeder() => DriftDemoSeeder(
    db,
    DemoGenerator(now: () => now),
    settings,
    DriftProgressRepository(db, now: () => now),
    DriftRoundupRepository(db, now: () => now),
  );

  test('wipes existing data and seeds every feature', () async {
    await db.eventDao.insertEvent(
      EventsCompanion.insert(
        date: DateTime(2026, 10, 21),
        title: 'Real event',
        toneIndex: 0,
        startMinute: 540,
        endMinute: 600,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await seeder().seed();

    final events = await db.eventDao.eventsBetween(
      DateTime(2020),
      DateTime(2030),
    );
    expect(events.where((event) => event.title == 'Real event'), isEmpty);
    expect(events, isNotEmpty);
    expect(await db.projectDao.allProjects(), hasLength(5));
    expect(await db.taskDao.watchAll().first, isNotEmpty);
    expect(await db.sessionDao.endedSessions(), isNotEmpty);
    expect(
      await db.coachDao.watchIntent(DateTime(2026, 10, 22)).first,
      isNotNull,
    );
    expect(
      await db.coachDao.watchReview(DateTime(2026, 10, 21)).first,
      isNotNull,
    );
    expect(await db.roundupDao.archive(), isNotEmpty);
    expect(await db.progressDao.progressRow(), isNotNull);
    expect(await settings.getBool(debugModeKey), isTrue);
    expect(await settings.getBool(onboardingDoneKey), isTrue);
  });

  test(
    'rolls back when an insert fails and leaves previous data alone',
    () async {
      await db.eventDao.insertEvent(
        EventsCompanion.insert(
          date: DateTime(2026, 10, 21),
          title: 'Keep me',
          toneIndex: 0,
          startMinute: 540,
          endMinute: 600,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final failing = DriftDemoSeeder(
        db,
        _DuplicateIdGenerator(now),
        settings,
        DriftProgressRepository(db, now: () => now),
        DriftRoundupRepository(db, now: () => now),
      );

      await expectLater(failing.seed(), throwsA(anything));
      final events = await db.eventDao.eventsBetween(
        DateTime(2020),
        DateTime(2030),
      );
      expect(events.map((event) => event.title), contains('Keep me'));
      expect(await settings.getBool(debugModeKey), isFalse);
    },
  );
}

class _DuplicateIdGenerator extends DemoGenerator {
  _DuplicateIdGenerator(DateTime now) : super(now: () => now);

  @override
  DemoDataset generate() {
    final data = super.generate();
    return DemoDataset(
      projects: [data.projects.first, data.projects.first],
      events: const [],
      sessions: const [],
      tasks: const [],
      templates: const [],
      templateItems: const [],
      intents: const [],
      reviews: const [],
      badgeUnlocks: const [],
      rangeStart: data.rangeStart,
      rangeEnd: data.rangeEnd,
    );
  }
}
