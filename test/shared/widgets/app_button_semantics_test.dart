import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> show(WidgetTester tester, {String? semanticsLabel}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppButton(
            label: '+5m',
            semanticsLabel: semanticsLabel,
            onPressed: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('a screen reader says the label by default', (tester) async {
    final handle = tester.ensureSemantics();
    await show(tester);

    expect(find.bySemanticsLabel('+5m'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a semantics label replaces it for screen readers only', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await show(tester, semanticsLabel: 'Add 5 minutes');

    expect(find.bySemanticsLabel('Add 5 minutes'), findsOneWidget);
    expect(find.bySemanticsLabel('+5m'), findsNothing);
    expect(find.text('+5m'), findsOneWidget);
    handle.dispose();
  });
}
