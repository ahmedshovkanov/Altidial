import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/repositories/reuse_repository.dart';
import 'package:energy_clock/features/clock/widgets/template_name_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Opens the dialog; [results] collects what it resolves to (null for a
  /// cancel).
  Future<void> open(WidgetTester tester, List<String?> results) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  results.add(await askTemplateName(context)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('returns the name, trimmed', (tester) async {
    final results = <String?>[];
    await open(tester, results);

    await tester.enterText(find.byType(TextField), '  Office day ');
    await tester.tap(find.text(Strings.save));
    await tester.pumpAndSettle();

    expect(results, ['Office day']);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('asks for a name and stays open when it is empty', (
    tester,
  ) async {
    final results = <String?>[];
    await open(tester, results);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text(Strings.save));
    await tester.pumpAndSettle();

    expect(find.text(Strings.templateNameRequired), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(results, isEmpty);
  });

  testWidgets('cancel returns null', (tester) async {
    final results = <String?>[];
    await open(tester, results);

    await tester.tap(find.text(Strings.cancel));
    await tester.pumpAndSettle();

    expect(results, [null]);
  });

  testWidgets('the name cannot be longer than a template allows', (
    tester,
  ) async {
    final results = <String?>[];
    await open(tester, results);

    await tester.enterText(find.byType(TextField), 'x' * 100);
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, hasLength(maxTemplateNameLength));
  });

  testWidgets('shows the title, label and hint', (tester) async {
    await open(tester, []);

    expect(find.text(Strings.templateNameTitle), findsOneWidget);
    expect(find.text(Strings.templateNameLabel), findsOneWidget);
  });
}
