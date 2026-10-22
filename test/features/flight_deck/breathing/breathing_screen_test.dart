import 'package:altidial/app/theme/app_theme.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/features/flight_deck/breathing/breathing_cycle.dart';
import 'package:altidial/features/flight_deck/breathing/breathing_screen.dart';
import 'package:altidial/features/flight_deck/breathing/widgets/breathing_orb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

/// Pumps one whole phase and settles the frame that draws the next one.
Future<void> finishPhase(WidgetTester tester, Duration phase) async {
  await tester.pump(phase);
  await tester.pump();
}

/// Takes [breaths] complete in-and-out breaths.
Future<void> breathe(WidgetTester tester, {int breaths = 8}) async {
  for (var i = 0; i < breaths; i++) {
    await finishPhase(tester, BreathingCycle.inhaleDuration);
    await finishPhase(tester, BreathingCycle.exhaleDuration);
  }
}

void main() {
  testWidgets('opens on the first inhale with the press prompt', (tester) async {
    await tester.pumpWidget(host(const BreathingScreen()));
    expect(find.text(Strings.breatheInhale), findsOneWidget);
    expect(find.text(Strings.breathePress), findsOneWidget);
    expect(find.text(Strings.breatheCount(1, 8)), findsOneWidget);
  });

  testWidgets('advances to the exhale after the inhale', (tester) async {
    await tester.pumpWidget(host(const BreathingScreen()));
    await finishPhase(tester, BreathingCycle.inhaleDuration);
    expect(find.text(Strings.breatheExhale), findsOneWidget);
    expect(find.text(Strings.breathePress), findsNothing);
  });

  testWidgets('announces the phase and seconds left as one label',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(const BreathingScreen()));
    expect(
      find.bySemanticsLabel(
        Strings.breathePhaseSemantics(Strings.breatheInhale, 4),
      ),
      findsOneWidget,
    );
    await finishPhase(tester, BreathingCycle.inhaleDuration);
    expect(
      find.bySemanticsLabel(
        Strings.breathePhaseSemantics(Strings.breatheExhale, 6),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('pressing clears the prompt; releasing brings it back',
      (tester) async {
    await tester.pumpWidget(host(const BreathingScreen()));
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(BreathingOrb)));
    await tester.pump();
    expect(find.text(Strings.breathePress), findsNothing);
    await gesture.up();
    await tester.pump();
    expect(find.text(Strings.breathePress), findsOneWidget);
  });

  testWidgets('holding during the exhale shows the let-go prompt',
      (tester) async {
    await tester.pumpWidget(host(const BreathingScreen()));
    await finishPhase(tester, BreathingCycle.inhaleDuration);
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(BreathingOrb)));
    await tester.pump();
    expect(find.text(Strings.breatheRelease), findsOneWidget);
    await gesture.up();
  });

  testWidgets('finishes after eight breaths', (tester) async {
    await tester.pumpWidget(host(const BreathingScreen()));
    await breathe(tester);
    expect(find.text(Strings.breatheDoneTitle), findsOneWidget);
    expect(find.text(Strings.breatheDoneBody(8)), findsOneWidget);
  });

  testWidgets('Again restarts from the first inhale', (tester) async {
    await tester.pumpWidget(host(const BreathingScreen()));
    await breathe(tester);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('breathe-again')));
    await tester.pump();
    expect(find.text(Strings.breatheDoneTitle), findsNothing);
    expect(find.text(Strings.breatheInhale), findsOneWidget);
  });

  testWidgets('Done closes the screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BreathingScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await breathe(tester);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('breathe-done')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(BreathingScreen), findsNothing);
  });
}
