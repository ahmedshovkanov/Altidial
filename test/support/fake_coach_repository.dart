import 'dart:async';

import 'package:altidial/data/database.dart';
import 'package:altidial/data/repositories/coach_repository.dart';

/// In-memory [CoachRepository] for widget tests. Tests seed [intent],
/// [review] and [insights] (or leave them empty) and read the `last*`
/// fields after saves.
class FakeCoachRepository implements CoachRepository {
  FakeCoachRepository({
    this.intent,
    this.review,
    List<CoachInsightRow>? insights,
  }) : insights = insights ?? [];

  CoachIntentRow? intent;
  CoachReviewRow? review;
  final List<CoachInsightRow> insights;

  DateTime? lastIntentDay;
  String? lastFocusGoal;
  int? lastPredictedEnergy;
  DateTime? lastReviewDay;
  int? lastEnergy;
  String? lastWinText;
  int ensureWeekCalls = 0;

  final _updates = StreamController<void>.broadcast();

  @override
  Stream<CoachIntentRow?> watchIntent(DateTime day) async* {
    yield intent;
    await for (final _ in _updates.stream) {
      yield intent;
    }
  }

  @override
  Future<void> saveIntent({
    required DateTime day,
    required String focusGoal,
    int? predictedEnergy,
  }) async {
    lastIntentDay = day;
    lastFocusGoal = focusGoal;
    lastPredictedEnergy = predictedEnergy;
    intent = CoachIntentRow(
      date: day,
      focusGoal: focusGoal,
      predictedEnergy: predictedEnergy,
      createdAt: day,
    );
    _updates.add(null);
  }

  @override
  Stream<CoachReviewRow?> watchReview(DateTime day) async* {
    yield review;
    await for (final _ in _updates.stream) {
      yield review;
    }
  }

  @override
  Future<void> saveReview({
    required DateTime day,
    required int energy,
    String? winText,
  }) async {
    lastReviewDay = day;
    lastEnergy = energy;
    lastWinText = winText;
    review = CoachReviewRow(
      date: day,
      energy: energy,
      winText: winText,
      createdAt: day,
    );
    _updates.add(null);
  }

  @override
  Stream<List<CoachInsightRow>> watchWeekInsights(
    int isoYear,
    int isoWeek,
  ) async* {
    yield insights;
    await for (final _ in _updates.stream) {
      yield insights;
    }
  }

  @override
  Future<void> ensureWeek(int isoYear, int isoWeek) async {
    ensureWeekCalls++;
  }

  void dispose() => _updates.close();
}
