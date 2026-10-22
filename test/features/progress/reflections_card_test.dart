import 'package:altidial/app/theme/app_theme.dart';
import 'package:altidial/core/session/session_outcome.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/models/session.dart';
import 'package:altidial/data/repositories/reflections_repository.dart';
import 'package:altidial/features/progress/widgets/reflections_card.dart';
import 'package:altidial/features/reflections/model/reflection.dart';
import 'package:altidial/features/reflections/providers.dart';
import 'package:altidial/features/reflections/reflections_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ReflectedSession _reflected({
  required int id,
  int? energyRating,
  int? focusRating,
  List<String> tags = const [],
  String? note,
}) => (
  session: SessionRecord(
    id: id,
    eventId: id,
    startedAt: DateTime(2026, 10, 5, 9),
    endedAt: DateTime(2026, 10, 5, 10),
    plannedSeconds: 3600,
    pausedSeconds: 0,
    pauseStartedAt: null,
    activeSeconds: 3600,
    overtimeSeconds: 0,
    outcome: SessionOutcome.completed,
    energyRating: energyRating,
    focusRating: focusRating,
    tags: tags,
    note: note,
  ),
  eventTitle: 'Deep work',
  tone: Tone.focus,
  eventDate: DateTime(2026, 10, 5),
  startHour: 9,
  isPostLife: false,
);

void main() {
  Future<void> mount(
    WidgetTester tester, {
    required List<ReflectedSession> timeline,
    required List<PatternCard> patterns,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reflectionsTimelineProvider.overrideWith(
            (ref) => Stream.value(timeline),
          ),
          reflectionPatternsProvider.overrideWith(
            (ref) => Stream.value(patterns),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: ReflectionsCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('reflections card opens journal', (tester) async {
    await mount(tester, timeline: const [], patterns: const []);

    expect(find.text(Strings.reflectionsTitle), findsOneWidget);

    await tester.tap(find.text(Strings.reflectionsTitle));
    await tester.pumpAndSettle();

    expect(find.byType(ReflectionsScreen), findsOneWidget);
  });

  testWidgets('counts reflected sessions and shows the top pattern', (
    tester,
  ) async {
    await mount(
      tester,
      timeline: [
        _reflected(id: 1, energyRating: 4, focusRating: 5),
        _reflected(id: 2, energyRating: 2, focusRating: 3),
      ],
      patterns: const [
        (title: 'Clear goal', detail: 'd', delta: 1.5, sampleSize: 12),
      ],
    );

    expect(find.text(Strings.reflectionsCount(2)), findsOneWidget);
    expect(find.text('Clear goal'), findsOneWidget);
  });

  testWidgets('nothing reflected yet shows the empty hint', (tester) async {
    await mount(tester, timeline: const [], patterns: const []);

    expect(find.text(Strings.reflectionsEmptyHint), findsOneWidget);
  });

  testWidgets('counts a reflection that has only tags and a note', (tester) async {
    await mount(
      tester,
      timeline: [
        _reflected(
          id: 1,
          tags: ['flow'],
          note: 'Great hour',
        ),
      ],
      patterns: const [],
    );

    expect(find.text(Strings.reflectionsCount(1)), findsOneWidget);
    expect(find.text(Strings.reflectionsEmptyHint), findsNothing);
  });
}
