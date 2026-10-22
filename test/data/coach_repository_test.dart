import 'package:drift/native.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/repositories/coach_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftCoachRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftCoachRepository(db);
  });

  tearDown(() => db.close());

  test('save + watch intent', () async {
    final day = DateTime(2026, 10, 12);
    await repo.saveIntent(day: day, focusGoal: 'Write plan');
    expect(await repo.watchIntent(day).first, isNotNull);
  });

  test('invalid energy throws without writing', () async {
    expect(
      () => repo.saveReview(day: DateTime(2026, 10, 12), energy: 9),
      throwsArgumentError,
    );
  });

  test('saveIntent accepts null and 1-5, rejects 0 and 6', () async {
    final day = DateTime(2026, 10, 12);
    await repo.saveIntent(day: day, focusGoal: 'Goal', predictedEnergy: null);
    expect(
      (await db.coachDao.intentFor(startOfDay(day)))?.predictedEnergy,
      isNull,
    );
    await repo.saveIntent(day: day, focusGoal: 'Goal', predictedEnergy: 3);
    expect((await db.coachDao.intentFor(startOfDay(day)))?.predictedEnergy, 3);
    expect(
      () => repo.saveIntent(day: day, focusGoal: 'Goal', predictedEnergy: 0),
      throwsArgumentError,
    );
    expect(
      () => repo.saveIntent(day: day, focusGoal: 'Goal', predictedEnergy: 6),
      throwsArgumentError,
    );
  });
}
