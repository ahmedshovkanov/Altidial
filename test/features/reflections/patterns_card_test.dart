import 'package:altidial/app/theme/app_theme.dart';
import 'package:altidial/features/reflections/model/reflection.dart';
import 'package:altidial/features/reflections/providers.dart';
import 'package:altidial/features/reflections/widgets/patterns_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty patterns shows needs-5 message', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reflectionPatternsProvider.overrideWith((ref) => Stream.value(const []))],
        child: MaterialApp(theme: AppTheme.light, home: const Scaffold(body: EnergyPatternsCard())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reflect on 5 sessions to reveal your patterns.'), findsOneWidget);
  });

  testWidgets('cards render title and detail', (tester) async {
    const List<PatternCard> cards = [(title: 'Clear goal → +1.5 focus', detail: 'd', delta: 1.5, sampleSize: 12)];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reflectionPatternsProvider.overrideWith((ref) => Stream.value(cards))],
        child: MaterialApp(theme: AppTheme.light, home: const Scaffold(body: EnergyPatternsCard())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Clear goal → +1.5 focus'), findsOneWidget);
  });
}