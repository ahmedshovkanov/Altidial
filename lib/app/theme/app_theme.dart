import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/app_typography.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(AppColors.light, ToneColors.light);
  static ThemeData get dark => _build(AppColors.dark, ToneColors.dark);

  static ThemeData _build(AppColors colors, ToneColors toneColors) {
    final scheme = ColorScheme(
      brightness: colors.brightness,
      primary: colors.ink,
      onPrimary: colors.onInk,
      secondary: colors.ink,
      onSecondary: colors.onInk,
      error: colors.danger,
      onError: colors.onInk,
      surface: colors.surface,
      onSurface: colors.ink,
      onSurfaceVariant: colors.muted,
      outline: colors.outline,
      outlineVariant: colors.outline,
      surfaceContainerLowest: colors.surface,
      surfaceContainerLow: colors.surface,
      surfaceContainer: colors.surface,
      surfaceContainerHigh: colors.surface,
      surfaceContainerHighest: colors.page,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.page,
      fontFamily: AppTypography.fontFamily,
      textTheme: AppTypography.textTheme(ink: colors.ink, muted: colors.muted),
      splashFactory: NoSplash.splashFactory,
      dividerColor: colors.outline,
      // Each sheet asks for the drag handle itself (`showDragHandle: true`)
      // once it scrolls, so a short window can never overflow it.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        modalBackgroundColor: colors.surface,
        dragHandleColor: colors.muted.withValues(alpha: 0.4),
        constraints: const BoxConstraints(maxWidth: 560),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
      ),
      extensions: <ThemeExtension<Object?>>[colors, toneColors],
    );
  }
}
