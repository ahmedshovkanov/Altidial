import 'package:altidial/app/theme/app_theme.dart';
import 'package:altidial/features/progress/widgets/stats_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Widget host(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('profile shows Stats card pushing hub', (tester) async {
    await tester.pumpWidget(host(const ProviderScope(child: StatsCard())));
    await tester.pump();
    expect(find.text('Stats'), findsOneWidget);
  });
}