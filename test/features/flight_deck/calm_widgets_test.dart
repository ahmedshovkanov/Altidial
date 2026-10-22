// test/features/flight_deck/calm_widgets_test.dart
import 'package:altidial/app/theme/app_theme.dart';
import 'package:altidial/features/flight_deck/calm_content.dart';
import 'package:altidial/features/flight_deck/widgets/calm_card_view.dart';
import 'package:altidial/features/flight_deck/widgets/grounding_steps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));

void main() {
  testWidgets('card shows title and toggles its star', (tester) async {
    var starred = false;
    await tester.pumpWidget(host(CalmCardView(
      card: calmCards.first,
      starred: starred,
      onStar: () => starred = !starred,
    )));
    expect(find.text(calmCards.first.title), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('deck-star')));
    expect(starred, isTrue);
  });

  testWidgets('grounding completes all five steps then restarts', (tester) async {
    await tester.pumpWidget(host(const GroundingSteps()));
    for (var i = 0; i < 15; i++) {
      await tester.tap(find.text('Notice one'));
      await tester.pump();
    }
    expect(find.text('Well done — you are here.'), findsOneWidget);
    await tester.tap(find.text('Start over'));
    await tester.pump();
    expect(find.text('Notice one'), findsOneWidget);
  });
}
