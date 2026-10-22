import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/shared/widgets/adaptive_choice.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens the chooser from a button and returns what it resolved to, once the
/// caller has driven it.
class ChooserResult {
  bool done = false;
  String? value;
}

Future<ChooserResult> openChooser(
  WidgetTester tester, {
  String? body = 'Which ones?',
  bool destructive = false,
}) async {
  final result = ChooserResult();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result.value = await chooseOne<String>(
                context,
                title: 'Edit repeating event',
                body: body,
                options: [
                  ChoiceOption(
                    label: 'This event',
                    value: 'one',
                    destructive: destructive,
                  ),
                  ChoiceOption(
                    label: 'This and all future events',
                    value: 'future',
                    destructive: destructive,
                  ),
                ],
                cancelLabel: 'Cancel',
              );
              result.done = true;
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
  group('Material', () {
    final android = TargetPlatformVariant.only(TargetPlatform.android);

    testWidgets('shows the title, the body and every option', (tester) async {
      await openChooser(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Edit repeating event'), findsOneWidget);
      expect(find.text('Which ones?'), findsOneWidget);
      expect(find.text('This event'), findsOneWidget);
      expect(find.text('This and all future events'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    }, variant: android);

    testWidgets('leaves the body out when there is none', (tester) async {
      await openChooser(tester, body: null);
      expect(find.text('Which ones?'), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
    }, variant: android);

    testWidgets('returns the chosen option', (tester) async {
      final result = await openChooser(tester);

      await tester.tap(find.text('This and all future events'));
      await tester.pumpAndSettle();

      expect(result.done, isTrue);
      expect(result.value, 'future');
      expect(find.byType(AlertDialog), findsNothing);
    }, variant: android);

    testWidgets('cancel returns null', (tester) async {
      final result = await openChooser(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result.done, isTrue);
      expect(result.value, isNull);
    }, variant: android);

    testWidgets('a destructive option uses the danger colour', (tester) async {
      await openChooser(tester, destructive: true);

      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'This event'),
      );
      expect(
        button.style!.foregroundColor!.resolve({}),
        AppColors.light.danger,
      );
      final cancel = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Cancel'),
      );
      expect(cancel.style, isNull);
    }, variant: android);

    testWidgets('tapping outside returns null', (tester) async {
      final result = await openChooser(tester);

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(result.done, isTrue);
      expect(result.value, isNull);
    }, variant: android);
  });

  group('iOS', () {
    final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

    testWidgets('shows a native action sheet', (tester) async {
      await openChooser(tester);

      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Edit repeating event'), findsOneWidget);
      expect(find.text('Which ones?'), findsOneWidget);
      expect(find.text('This event'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    }, variant: ios);

    testWidgets('returns the chosen option', (tester) async {
      final result = await openChooser(tester);

      await tester.tap(find.text('This event'));
      await tester.pumpAndSettle();

      expect(result.value, 'one');
      expect(find.byType(CupertinoActionSheet), findsNothing);
    }, variant: ios);

    testWidgets('cancel returns null', (tester) async {
      final result = await openChooser(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result.done, isTrue);
      expect(result.value, isNull);
    }, variant: ios);

    testWidgets('a destructive option is marked destructive', (tester) async {
      await openChooser(tester, destructive: true);

      final action = tester.widget<CupertinoActionSheetAction>(
        find.widgetWithText(CupertinoActionSheetAction, 'This event'),
      );
      expect(action.isDestructiveAction, isTrue);
    }, variant: ios);
  });
}
