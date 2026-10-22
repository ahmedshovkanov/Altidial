import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/clock/widgets/edit_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Runs [ask] from a button. [onResult] receives what it resolved to.
  Future<void> open(
    WidgetTester tester,
    Future<EditScope?> Function(BuildContext) ask, {
    void Function(EditScope?)? onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final scope = await ask(context);
                onResult?.call(scope);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('an edit offers this event and this and all future', (
    tester,
  ) async {
    await open(tester, askEditScope);

    expect(find.text(Strings.editScopeTitle), findsOneWidget);
    expect(find.text(Strings.scopeThisEvent), findsOneWidget);
    expect(find.text(Strings.scopeThisAndFuture), findsOneWidget);
    expect(find.text(Strings.cancel), findsOneWidget);
  });

  testWidgets('choosing this event resolves to thisEvent', (tester) async {
    final results = <EditScope?>[];
    await open(tester, askEditScope, onResult: results.add);

    await tester.tap(find.text(Strings.scopeThisEvent));
    await tester.pumpAndSettle();

    expect(results, [EditScope.thisEvent]);
  });

  testWidgets('choosing this and all future resolves to thisAndFuture', (
    tester,
  ) async {
    final results = <EditScope?>[];
    await open(tester, askEditScope, onResult: results.add);

    await tester.tap(find.text(Strings.scopeThisAndFuture));
    await tester.pumpAndSettle();

    expect(results, [EditScope.thisAndFuture]);
  });

  testWidgets('cancelling resolves to null', (tester) async {
    final results = <EditScope?>[];
    await open(tester, askEditScope, onResult: results.add);

    await tester.tap(find.text(Strings.cancel));
    await tester.pumpAndSettle();

    expect(results, [null]);
  });

  testWidgets('changing how it repeats offers only this and all future', (
    tester,
  ) async {
    await open(tester, (context) => askEditScope(context, ruleChanged: true));

    expect(find.text(Strings.repeatChangeTitle), findsOneWidget);
    expect(find.text(Strings.repeatChangeBody), findsOneWidget);
    expect(find.text(Strings.scopeThisAndFuture), findsOneWidget);
    expect(find.text(Strings.scopeThisEvent), findsNothing);
  });

  testWidgets('deleting asks with the delete wording', (tester) async {
    await open(tester, askDeleteScope);

    expect(find.text(Strings.deleteScopeTitle), findsOneWidget);
    expect(find.text(Strings.scopeThisEvent), findsOneWidget);
    expect(find.text(Strings.scopeThisAndFuture), findsOneWidget);
  });
}
