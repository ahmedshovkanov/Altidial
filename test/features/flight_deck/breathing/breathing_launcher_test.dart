import 'package:altidial/app/theme/app_theme.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/features/flight_deck/breathing/breathing_screen.dart';
import 'package:altidial/features/flight_deck/widgets/breathing_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('launcher pushes the breathing screen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: BreathingLauncher()),
    ));
    expect(find.text(Strings.deckBreatheTitle), findsOneWidget);
    await tester.tap(find.text(Strings.deckBreatheTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(BreathingScreen), findsOneWidget);
  });
}
