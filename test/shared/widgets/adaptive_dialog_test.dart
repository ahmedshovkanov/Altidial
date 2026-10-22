import 'package:energy_clock/shared/widgets/adaptive_dialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<bool?> openDialog(WidgetTester tester) async {
  bool? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await confirmDestructive(
                context,
                title: 'Delete this event?',
                body: "This can't be undone.",
                confirmLabel: 'Delete',
                cancelLabel: 'Cancel',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets(
    'Material: confirming returns true',
    (tester) async {
      await openDialog(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Delete this event?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Material: cancelling returns false',
    (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await confirmDestructive(
                    context,
                    title: 'Delete this event?',
                    body: 'Body',
                    confirmLabel: 'Delete',
                    cancelLabel: 'Cancel',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'iOS: renders the native alert with a destructive action',
    (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await confirmDestructive(
                    context,
                    title: 'Delete this event?',
                    body: 'Body',
                    confirmLabel: 'Delete',
                    cancelLabel: 'Cancel',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      final destructive = tester.widget<CupertinoDialogAction>(
        find.widgetWithText(CupertinoDialogAction, 'Delete'),
      );
      expect(destructive.isDestructiveAction, isTrue);

      await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Delete'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
