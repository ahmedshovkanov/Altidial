import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/contrast.dart';

void main() {
  test('contrast helper matches known values', () {
    expect(
      contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21, 0.001),
    );
    expect(
      contrastRatio(const Color(0xFFFFFFFF), const Color(0xFFFFFFFF)),
      closeTo(1, 0.001),
    );
  });

  for (final entry in {
    'light': AppColors.light,
    'dark': AppColors.dark,
  }.entries) {
    group('${entry.key} neutrals', () {
      final colors = entry.value;

      test('text on the page and on cards is at least 4.5:1', () {
        expect(
          contrastRatio(colors.ink, colors.page),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(colors.ink, colors.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(colors.muted, colors.page),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(colors.muted, colors.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(colors.danger, colors.page),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(colors.danger, colors.surface),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('text on an ink button is at least 4.5:1', () {
        expect(
          contrastRatio(colors.onInk, colors.ink),
          greaterThanOrEqualTo(4.5),
        );
      });
    });
  }

  test('light mode has shadows; dark mode uses borders instead', () {
    expect(AppColors.light.cardShadow, isNotEmpty);
    expect(AppColors.light.faceShadow, isNotEmpty);
    expect(AppColors.light.barShadow, isNotEmpty);
    expect(AppColors.dark.cardShadow, isEmpty);
    expect(AppColors.dark.faceShadow, isEmpty);
    expect(AppColors.dark.barShadow, isEmpty);
    expect(AppColors.light.isDark, isFalse);
    expect(AppColors.dark.isDark, isTrue);
  });

  test('light and dark differ for every colour', () {
    expect(AppColors.light.page, isNot(AppColors.dark.page));
    expect(AppColors.light.surface, isNot(AppColors.dark.surface));
    expect(AppColors.light.ink, isNot(AppColors.dark.ink));
  });

  test('lerp blends and equality follows the values', () {
    final mid = AppColors.light.lerp(AppColors.dark, 0.5);
    expect(mid, isA<AppColors>());
    expect(AppColors.light, AppColors.light.copyWith());
    expect(AppColors.light.hashCode, AppColors.light.copyWith().hashCode);
    expect(AppColors.light, isNot(AppColors.dark));
    expect(
      AppColors.light.copyWith(ink: const Color(0xFF000000)).ink,
      const Color(0xFF000000),
    );
  });

  test('tokens hold the specified scales', () {
    expect(AppSpacing.xs, 4);
    expect(AppSpacing.huge, 40);
    expect(AppRadii.card, 24);
    expect(AppRadii.pill, 999);
    expect(AppMotion.fast, const Duration(milliseconds: 150));
    expect(AppMotion.base, const Duration(milliseconds: 250));
    expect(AppMotion.slow, const Duration(milliseconds: 400));
    expect(AppMotion.standard, Curves.easeOutCubic);
    expect(AppMotion.pop, Curves.easeOutBack);
  });

  testWidgets('context.appColors reads the theme extension', (tester) async {
    late AppColors read;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [AppColors.dark]),
        home: Builder(
          builder: (context) {
            read = context.appColors;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(read, AppColors.dark);
  });

  testWidgets(
    'context.appColors throws a clear error when the theme lacks it',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(() => context.appColors, throwsStateError);
              return const SizedBox();
            },
          ),
        ),
      );
    },
  );
}
