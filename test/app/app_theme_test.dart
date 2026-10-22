import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/app_theme.dart';
import 'package:altidial/app/theme/app_typography.dart';
import 'package:altidial/app/theme/tone_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final entry in {
    'light': (AppTheme.light, AppColors.light, ToneColors.light),
    'dark': (AppTheme.dark, AppColors.dark, ToneColors.dark),
  }.entries) {
    group(entry.key, () {
      final (theme, colors, tones) = entry.value;

      test('carries the app colour extensions', () {
        expect(theme.extension<AppColors>(), colors);
        expect(theme.extension<ToneColors>(), tones);
      });

      test('ink is the primary colour and the page is the background', () {
        expect(theme.colorScheme.primary, colors.ink);
        expect(theme.colorScheme.onPrimary, colors.onInk);
        expect(theme.colorScheme.error, colors.danger);
        expect(theme.scaffoldBackgroundColor, colors.page);
        expect(theme.colorScheme.brightness, colors.brightness);
      });

      test('text uses Nunito at the specified sizes and weights', () {
        final text = theme.textTheme;
        expect(text.titleLarge!.fontFamily, AppTypography.fontFamily);
        expect(text.titleLarge!.fontSize, 28);
        expect(text.titleLarge!.fontWeight, FontWeight.w800);
        expect(text.titleMedium!.fontSize, 20);
        expect(text.titleMedium!.fontWeight, FontWeight.w700);
        expect(text.bodyMedium!.fontSize, 16);
        expect(text.bodyMedium!.fontWeight, FontWeight.w400);
        expect(text.labelLarge!.fontSize, 14);
        expect(text.bodySmall!.fontSize, 12);
        expect(text.titleLarge!.color, colors.ink);
        expect(text.bodySmall!.color, colors.muted);
      });

      test('modal bottom sheets are capped at 560 pt wide', () {
        expect(theme.bottomSheetTheme.constraints?.maxWidth, 560);
        expect(theme.bottomSheetTheme.backgroundColor, colors.surface);
      });
    });
  }

  group('dial text styles scale with the dial', () {
    test('the centre time is clamped between 22 and 44', () {
      expect(AppTypography.displayTime(50).fontSize, 22);
      expect(AppTypography.displayTime(100).fontSize, closeTo(22, 0.001));
      expect(AppTypography.displayTime(150).fontSize, closeTo(33, 0.001));
      expect(AppTypography.displayTime(400).fontSize, 44);
    });

    test('numerals are at least 11 and arc labels at least 10', () {
      expect(AppTypography.dialNumeral(40).fontSize, 11);
      expect(AppTypography.dialNumeral(150).fontSize, closeTo(19.5, 0.001));
      expect(AppTypography.arcLabel(10).fontSize, 10);
      expect(AppTypography.arcLabel(30).fontSize, 15);
    });

    test('times use tabular figures', () {
      expect(
        AppTypography.displayTime(100).fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });
  });
}
