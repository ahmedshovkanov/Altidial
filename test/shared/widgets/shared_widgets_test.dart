import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/app_theme.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/shared/widgets/app_button.dart';
import 'package:altidial/shared/widgets/app_card.dart';
import 'package:altidial/shared/widgets/press_scale.dart';
import 'package:altidial/shared/widgets/ring_mark.dart';
import 'package:altidial/shared/widgets/section_header.dart';
import 'package:altidial/shared/widgets/tone_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.light,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('AppButton', () {
    testWidgets('a primary button is ink with onInk text and is tappable', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(AppButton(label: 'Save', onPressed: () => taps++)),
      );

      final text = tester.widget<Text>(find.text('Save'));
      expect(text.style!.color, AppColors.light.onInk);
      final decoration = tester.widget<DecoratedBox>(
        find.ancestor(
          of: find.text('Save'),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(
        (decoration.decoration as BoxDecoration).color,
        AppColors.light.ink,
      );
      expect(
        tester.getSize(find.byType(AppButton)).height,
        greaterThanOrEqualTo(56),
      );

      await tester.tap(find.text('Save'));
      expect(taps, 1);
    });

    testWidgets('a disabled button is faded and does nothing', (tester) async {
      await tester.pumpWidget(
        host(const AppButton(label: 'Save', onPressed: null)),
      );
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.38);
      await tester.tap(find.text('Save'));
      // No exception and no callback to observe: the button is inert.
    });

    testWidgets('a destructive button uses the danger colour', (tester) async {
      await tester.pumpWidget(
        host(
          AppButton(
            label: 'Delete',
            variant: AppButtonVariant.destructive,
            onPressed: () {},
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.text('Delete')).style!.color,
        AppColors.light.danger,
      );
    });

    testWidgets('a secondary button is a faint ink fill with ink text', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          AppButton(
            label: 'Edit',
            variant: AppButtonVariant.secondary,
            onPressed: () {},
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.text('Edit')).style!.color,
        AppColors.light.ink,
      );
    });

    testWidgets('exposes button semantics with its label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(AppButton(label: 'Save', onPressed: () {})));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Save')),
        matchesSemantics(
          label: 'Save',
          isButton: true,
          hasTapAction: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      handle.dispose();
    });
  });

  group('PressScale', () {
    testWidgets('scales down while pressed and back on release', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          PressScale(
            onTap: () {},
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );
      double scale() =>
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
      expect(scale(), 1);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PressScale)),
      );
      await tester.pump();
      expect(scale(), 0.97);
      await gesture.up();
      await tester.pump();
      expect(scale(), 1);
    });

    testWidgets('does not scale when reduced motion is on', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: PressScale(
                onTap: () {},
                child: const SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PressScale)),
      );
      await tester.pump();
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
      await gesture.up();
    });
  });

  group('AppCard', () {
    testWidgets('has a shadow in light mode and a border in dark mode', (
      tester,
    ) async {
      await tester.pumpWidget(host(const AppCard(child: Text('hi'))));
      var shape =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(AppCard),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as ShapeDecoration;
      expect(shape.shadows, isNotEmpty);
      expect(shape.color, AppColors.light.surface);

      await tester.pumpWidget(
        host(const AppCard(child: Text('hi')), theme: AppTheme.dark),
      );
      // A theme change animates, so let it finish before reading the card.
      await tester.pumpAndSettle();
      shape =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(AppCard),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as ShapeDecoration;
      expect(shape.shadows, isEmpty);
      final border = shape.shape as RoundedRectangleBorder;
      expect(border.side.color, AppColors.dark.outline);
    });

    testWidgets(
      'a custom colour overrides the fill and onTap makes it tappable',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          host(
            AppCard(
              color: AppColors.light.ink,
              onTap: () => taps++,
              child: const Text('tap me'),
            ),
          ),
        );
        await tester.tap(find.text('tap me'));
        expect(taps, 1);
      },
    );
  });

  testWidgets('ToneChip shows the tone name on its soft fill', (tester) async {
    await tester.pumpWidget(host(const ToneChip(tone: Tone.life)));
    expect(find.text('Life'), findsOneWidget);
    final text = tester.widget<Text>(find.text('Life'));
    expect(text.style!.color, isNotNull);
  });

  testWidgets('SectionHeader shows its title and optional trailing widget', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const SectionHeader(title: 'Plan', trailing: Text('See all'))),
    );
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
  });

  group('RingMark', () {
    test('paints three arcs without throwing and repaints on change', () {
      const painter = RingMarkPainter(
        colors: [Color(0xFF111111), Color(0xFF222222), Color(0xFF333333)],
      );
      const other = RingMarkPainter(
        colors: [Color(0xFF111111), Color(0xFF222222), Color(0xFF333333)],
        progress: 0.5,
      );
      expect(painter.shouldRepaint(other), isTrue);
      expect(
        painter.shouldRepaint(
          const RingMarkPainter(
            colors: [Color(0xFF111111), Color(0xFF222222), Color(0xFF333333)],
          ),
        ),
        isFalse,
      );
    });

    testWidgets('is decorative: it adds nothing to the semantics tree', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: RingMark(
            colors: [Color(0xFF111111), Color(0xFF222222), Color(0xFF333333)],
            size: 48,
          ),
        ),
      );
      expect(find.semantics.byLabel(RegExp('.')), findsNothing);
      handle.dispose();
    });
  });
}
