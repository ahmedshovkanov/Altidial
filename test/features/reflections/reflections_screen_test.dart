import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/session/session_outcome.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/reflections_repository.dart';
import 'package:energy_clock/data/repositories/session_repository.dart';
import 'package:energy_clock/features/reflections/providers.dart';
import 'package:energy_clock/features/reflections/reflections_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ReflectedSession _row({required String title, int? energy, List<String> tags = const [], String? note}) {
  final now = DateTime(2026, 10, 15, 10, 0);
  return (
    session: SessionRecord(
      id: 1, eventId: 1, startedAt: now, endedAt: now,
      plannedSeconds: 3600, pausedSeconds: 0, pauseStartedAt: null,
      activeSeconds: 3000, overtimeSeconds: 0, outcome: SessionOutcome.completed,
      energyRating: energy, focusRating: energy == null ? null : 4, tags: tags, note: note,
    ),
    eventTitle: title, tone: Tone.focus, eventDate: DateTime(2026, 10, 15), startHour: 9, isPostLife: false,
  );
}

/// Records what the debrief sheet writes, so a test can prove an edit did not
/// blank the fields.
class _RecordingSessionRepo implements SessionRepository {
  int? lastEnergy;
  int? lastFocus;
  List<String> lastTags = const [];
  String? lastNote;

  @override
  Stream<RunningSession?> watchRunning() => const Stream.empty();
  @override
  Future<RunningSession?> runningSession() async => null;
  @override
  Future<int> start({required int eventId}) async => 1;
  @override
  Future<void> pause(int sessionId) async {}
  @override
  Future<void> resume(int sessionId) async {}
  @override
  Future<void> extend(int sessionId, {required int seconds}) async {}
  @override
  Future<SessionRecord?> finish(int sessionId) async => null;
  @override
  Future<SessionRecord?> abandon(int sessionId) async => null;
  @override
  Future<SessionRecord?> closeOut(int sessionId) async => null;
  @override
  Future<void> saveReflection({required int sessionId, int? energyRating, int? focusRating, List<String> tags = const [], String? note}) async {
    lastEnergy = energyRating;
    lastFocus = focusRating;
    lastTags = tags;
    lastNote = note;
  }
}

void main() {
  testWidgets('empty timeline shows empty hint', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reflectionsTimelineProvider.overrideWith((ref) => Stream.value(const []))],
        child: MaterialApp(theme: AppTheme.light, home: const ReflectionsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No reflections yet'), findsOneWidget);
  });

  testWidgets('rows render title tags and note', (tester) async {
    final rows = [_row(title: 'Deep work', energy: 4, tags: ['flow'], note: 'Great hour')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reflectionsTimelineProvider.overrideWith((ref) => Stream.value(rows))],
        child: MaterialApp(theme: AppTheme.light, home: const ReflectionsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Deep work'), findsOneWidget);
    expect(find.text('Flow'), findsOneWidget);
    expect(find.text('Great hour'), findsOneWidget);
  });

  testWidgets('tapping a row reopens its reflection instead of blanking it', (tester) async {
    final rows = [_row(title: 'Deep work', energy: 4, tags: ['flow'], note: 'Great hour')];
    final repo = _RecordingSessionRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reflectionsTimelineProvider.overrideWith((ref) => Stream.value(rows)),
          sessionRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const ReflectionsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Deep work'));
    await tester.pumpAndSettle();

    expect(find.text(Strings.debriefTitle), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('debrief-note')))
          .controller!
          .text,
      'Great hour',
    );
    final flowChip = tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Flow'));
    expect(flowChip.selected, isTrue);

    await tester.tap(find.text(Strings.debriefSave));
    await tester.pumpAndSettle();

    expect(repo.lastEnergy, 4);
    expect(repo.lastFocus, 4);
    expect(repo.lastTags, ['flow']);
    expect(repo.lastNote, 'Great hour');
    expect(find.text(Strings.debriefSaved), findsOneWidget);
  });

  testWidgets('a reflection with only tags and a note reads as reflected', (tester) async {
    final rows = [_row(title: 'Deep work', energy: null, tags: ['flow'], note: 'Great hour')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reflectionsTimelineProvider.overrideWith((ref) => Stream.value(rows))],
        child: MaterialApp(theme: AppTheme.light, home: const ReflectionsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(Strings.reflectionsNotReflected), findsNothing);
    expect(find.text('Flow'), findsOneWidget);
  });
}