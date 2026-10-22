import 'package:drift/native.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/data/repositories/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('SettingsDao', () {
    test('a key that was never set reads as null', () async {
      expect(await db.settingsDao.valueFor('missing'), isNull);
    });

    test('a stored value reads back', () async {
      await db.settingsDao.setValue('theme', 'dark');
      expect(await db.settingsDao.valueFor('theme'), 'dark');
    });

    test('storing a key again replaces its value', () async {
      await db.settingsDao.setValue('theme', 'dark');
      await db.settingsDao.setValue('theme', 'light');
      expect(await db.settingsDao.valueFor('theme'), 'light');
    });

    test('keys are independent', () async {
      await db.settingsDao.setValue('a', '1');
      await db.settingsDao.setValue('b', '2');
      expect(await db.settingsDao.valueFor('a'), '1');
      expect(await db.settingsDao.valueFor('b'), '2');
    });
  });

  group('DriftSettingsRepository', () {
    late DriftSettingsRepository repository;

    setUp(() {
      repository = DriftSettingsRepository(db.settingsDao);
    });

    test(
      'a missing key gives false, or the default when one is given',
      () async {
        expect(await repository.getBool('flag'), isFalse);
        expect(await repository.getBool('flag', defaultValue: true), isTrue);
      },
    );

    test('a stored true and a stored false both read back', () async {
      await repository.setBool('on', true);
      await repository.setBool('off', false);
      expect(await repository.getBool('on'), isTrue);
      // A stored false beats a true default.
      expect(await repository.getBool('off', defaultValue: true), isFalse);
    });

    test('a later write wins', () async {
      await repository.setBool('flag', true);
      await repository.setBool('flag', false);
      expect(await repository.getBool('flag'), isFalse);
    });

    test(
      'a key that was never set reads as null for strings and ints',
      () async {
        expect(await repository.getString('missing'), isNull);
        expect(await repository.getInt('missing'), isNull);
      },
    );

    test('a stored string reads back, and a later write wins', () async {
      await repository.setString('theme', 'dark');
      expect(await repository.getString('theme'), 'dark');
      await repository.setString('theme', 'light');
      expect(await repository.getString('theme'), 'light');
    });

    test('an integer round-trips through its stored string form', () async {
      expect(await repository.getInt('missing'), isNull);
      await repository.setInt('morning', 480);
      expect(await repository.getInt('morning'), 480);
      await db.settingsDao.setValue('morning', 'nope');
      expect(await repository.getInt('morning'), isNull);
    });

    test('a stored value that is not an integer reads as null', () async {
      await db.settingsDao.setValue('weird', 'nope');
      expect(await repository.getInt('weird'), isNull);
    });

    test('a stored integer survives a later unrelated write', () async {
      await repository.setInt('first_day_of_week', 7);
      await repository.setBool('flag', true);
      expect(await repository.getInt('first_day_of_week'), 7);
    });

    test('an integer round-trips through its stored string form (daily focus target)', () async {
      await repository.setInt('daily_focus_target', 240);
      expect(await repository.getInt('daily_focus_target'), 240);
      expect(await db.settingsDao.valueFor('daily_focus_target'), '240');
    });
  });

  test('settingsRepositoryProvider is built on the shared database', () {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(settingsRepositoryProvider),
      isA<DriftSettingsRepository>(),
    );
  });
}
