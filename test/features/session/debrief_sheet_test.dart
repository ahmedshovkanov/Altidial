import 'package:altidial/app/theme/app_theme.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/data/repositories/session_repository.dart';
import 'package:altidial/features/session/widgets/debrief_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSessionRepo implements SessionRepository {
  int? lastEnergy;
  int? lastFocus;
  List<String> lastTags = const [];
  String? lastNote;
  int saves = 0;

  /// Fails only once the sheet has had time to be taken away, so the error
  /// lands on a disposed state.
  bool failSave = false;

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
    saves++;
    if (failSave) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      throw StateError('write failed');
    }
  }
}

/// Whether the rating chip labelled [label] is selected. Energy and focus each
/// have a 1–5 row, so [first] picks which of the two the assertion is about.
bool _ratingSelected(WidgetTester tester, String label, {required bool first}) {
  final chips = find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip));
  return tester.widget<ChoiceChip>(first ? chips.first : chips.last).selected;
}

void main() {
  testWidgets('debrief sheet saves energy focus tags and shows counter', (tester) async {
    final fake = _FakeSessionRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionRepositoryProvider.overrideWithValue(fake)],
        child: MaterialApp(theme: AppTheme.light, home: const Scaffold(body: DebriefSheet(sessionId: 7, eventTitle: 'Deep work', activeMinutes: 50))),
      ),
    );
    expect(find.text(Strings.debriefTitle), findsOneWidget);
    await tester.tap(find.text('4').first);
    await tester.pump();
    await tester.tap(find.text('Clear goal'));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('debrief-note')), 'Great hour');
    await tester.pump();
    await tester.tap(find.text(Strings.debriefSave));
    await tester.pumpAndSettle();
    expect(fake.saves, 1);
    expect(fake.lastEnergy, 4);
    expect(fake.lastTags, ['clear-goal']);
    expect(fake.lastNote, 'Great hour');
  });

  testWidgets('skip returns false without saving', (tester) async {
    final fake = _FakeSessionRepo();
    bool? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionRepositoryProvider.overrideWithValue(fake)],
        child: MaterialApp(theme: AppTheme.light, home: Scaffold(body: Consumer(builder: (context, ref, _) {
          return TextButton(onPressed: () async {
            result = await showDebriefSheet(context, ref, sessionId: 7, eventTitle: 'x', activeMinutes: 10);
          }, child: const Text('open'));
        }))),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.debriefSkip));
    await tester.pumpAndSettle();
    expect(fake.saves, 0);
    expect(result, isFalse);
  });

  testWidgets('editing a reflection reopens with the saved values and keeps them on save', (tester) async {
    final fake = _FakeSessionRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionRepositoryProvider.overrideWithValue(fake)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: DebriefSheet(
              sessionId: 7,
              eventTitle: 'Deep work',
              activeMinutes: 50,
              initialEnergy: 4,
              initialFocus: 5,
              initialTags: ['clear-goal'],
              initialNote: 'Great hour',
            ),
          ),
        ),
      ),
    );

    expect(_ratingSelected(tester, '4', first: true), isTrue);
    expect(_ratingSelected(tester, '5', first: false), isTrue);
    expect(
      tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Clear goal')).selected,
      isTrue,
    );
    expect(find.text('Great hour'), findsOneWidget);

    await tester.tap(find.text(Strings.debriefSave));
    await tester.pumpAndSettle();

    expect(fake.saves, 1);
    expect(fake.lastEnergy, 4);
    expect(fake.lastFocus, 5);
    expect(fake.lastTags, ['clear-goal']);
    expect(fake.lastNote, 'Great hour');
  });

  testWidgets('skipping a seeded reflection writes nothing', (tester) async {
    final fake = _FakeSessionRepo();
    bool? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionRepositoryProvider.overrideWithValue(fake)],
        child: MaterialApp(theme: AppTheme.light, home: Scaffold(body: Consumer(builder: (context, ref, _) {
          return TextButton(onPressed: () async {
            result = await showDebriefSheet(
              context,
              ref,
              sessionId: 7,
              eventTitle: 'x',
              activeMinutes: 10,
              initialEnergy: 4,
              initialFocus: 5,
              initialTags: const ['clear-goal'],
              initialNote: 'Great hour',
            );
          }, child: const Text('open'));
        }))),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(_ratingSelected(tester, '4', first: true), isTrue);

    await tester.tap(find.text(Strings.debriefSkip));
    await tester.pumpAndSettle();

    expect(fake.saves, 0);
    expect(result, isFalse);
  });

  testWidgets('a save that fails after the sheet is gone stays quiet', (tester) async {
    final fake = _FakeSessionRepo()..failSave = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionRepositoryProvider.overrideWithValue(fake)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: DebriefSheet(sessionId: 7, eventTitle: 'Deep work', activeMinutes: 50)),
        ),
      ),
    );

    await tester.tap(find.text(Strings.debriefSave));
    await tester.pump();

    // The person leaves while the write is still in flight.
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('gone'))));
    await tester.pump(const Duration(milliseconds: 50));

    expect(fake.saves, 1);
    expect(tester.takeException(), isNull);
  });
}
