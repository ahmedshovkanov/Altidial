import 'package:drift/native.dart';
import 'package:energy_clock/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('intent round-trips and overwrites same date', () async {
    final day = DateTime(2026, 10, 12);
    await db.coachDao.upsertIntent(date: day, focusGoal: 'Ship coach spec');
    expect((await db.coachDao.intentFor(day))?.focusGoal, 'Ship coach spec');
    await db.coachDao.upsertIntent(date: day, focusGoal: 'Second save wins');
    expect((await db.coachDao.intentFor(day))?.focusGoal, 'Second save wins');
  });

  test('review round-trips energy + win text', () async {
    final day = DateTime(2026, 10, 12);
    await db.coachDao.upsertReview(date: day, energy: 4, winText: 'Peak morning');
    final row = await db.coachDao.reviewFor(day);
    expect(row?.energy, 4);
    expect(row?.winText, 'Peak morning');
  });

  test('insights freeze per ISO week', () async {
    await db.coachDao.insertInsight(
      isoYear: 2026,
      isoWeek: 42,
      kind: 'peak-hours',
      payloadJson: '{"title":"Peak holds"}',
    );
    final rows = await db.coachDao.insightsForWeek(2026, 42);
    expect(rows.length, 1);
    expect(rows.single.kind, 'peak-hours');
  });

  test('intent round-trips predicted energy', () async {
    final day = DateTime(2026, 10, 12);
    await db.coachDao.upsertIntent(date: day, focusGoal: 'Ship ritual', predictedEnergy: 4);
    expect((await db.coachDao.intentFor(day))?.predictedEnergy, 4);
    await db.coachDao.upsertIntent(date: day, focusGoal: 'Second save wins', predictedEnergy: null);
    expect((await db.coachDao.intentFor(day))?.predictedEnergy, isNull);
  });
}
