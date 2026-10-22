import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/features/flight_deck/breathing/breathing_cycle.dart';
import 'package:energy_clock/features/flight_deck/breathing/widgets/breathing_orb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('shows the phase label and the countdown', (tester) async {
    await tester.pumpWidget(host(const BreathingOrb(
      diameter: 300,
      phase: BreathPhase.inhale,
      fraction: 0.5,
      secondsLeft: 2,
      label: 'Breathe in',
      inSync: true,
      reduceMotion: false,
    )));
    expect(find.text('Breathe in'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('renders on the exhale too', (tester) async {
    await tester.pumpWidget(host(const BreathingOrb(
      diameter: 240,
      phase: BreathPhase.exhale,
      fraction: 0.25,
      secondsLeft: 5,
      label: 'Breathe out',
      inSync: false,
      reduceMotion: true,
    )));
    expect(find.text('Breathe out'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });
}
