import 'package:flutter/widgets.dart';

import 'app_colors.dart';
import 'app_fonts.dart';
import 'responsive.dart';

/// The app's complete type scale. Sizes are phone-first and multiply by
/// the responsive scale factor, so tablets scale up rather than spread out.
///
/// Two faces with a clean split: [title] and [display] are Jersey10 and
/// carry identity; everything else is Inter and carries information.
/// Neither display style requests a weight, because Jersey10 ships exactly
/// one — asking for another makes Flutter synthesize a fake bold.
abstract final class AppTextStyles {
  static const double captionSize = 12;
  static const double labelSize = 13;
  static const double bodySize = 15;
  static const double bodyStrongSize = 15;
  static const double headingSize = 20;
  static const double titleSize = 30;
  static const double displaySize = 40;

  static TextStyle body(BuildContext context) => TextStyle(
        fontFamily: AppFonts.bodyFamily,
        fontSize: bodySize * Responsive.scaleOf(context),
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: AppColors.textPrimary,
      );

  static TextStyle bodyStrong(BuildContext context) =>
      body(context).copyWith(fontWeight: FontWeight.w600);

  static TextStyle heading(BuildContext context) => TextStyle(
        fontFamily: AppFonts.bodyFamily,
        fontSize: headingSize * Responsive.scaleOf(context),
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: AppColors.textPrimary,
      );

  /// Short all-caps field labels — `COINS`, `XP`, stat names.
  static TextStyle label(BuildContext context) => TextStyle(
        fontFamily: AppFonts.bodyFamily,
        fontSize: labelSize * Responsive.scaleOf(context),
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.6,
        color: AppColors.textMuted,
      );

  static TextStyle caption(BuildContext context) => TextStyle(
        fontFamily: AppFonts.bodyFamily,
        fontSize: captionSize * Responsive.scaleOf(context),
        fontWeight: FontWeight.w400,
        height: 1.35,
        color: AppColors.textMuted,
      );

  static TextStyle title(BuildContext context) => TextStyle(
        fontFamily: AppFonts.displayFamily,
        fontSize: titleSize * Responsive.scaleOf(context),
        height: 1.2,
        letterSpacing: 0.5,
        color: AppColors.accent,
      );

  static TextStyle display(BuildContext context) => TextStyle(
        fontFamily: AppFonts.displayFamily,
        fontSize: displaySize * Responsive.scaleOf(context),
        height: 1.1,
        letterSpacing: 0.5,
        color: AppColors.accentLight,
      );

  /// Tabular-figure variant of [base], for any number that changes while
  /// on screen. Digits keep a fixed advance width, so a value ticking from
  /// 9% to 10% stops shifting its neighbours sideways.
  ///
  /// Size and colour come from [base]; only the face, weight and figure
  /// style are overridden. That is why this takes a style rather than a
  /// context — it composes onto whatever the surrounding text is.
  static TextStyle numeric(TextStyle base) => base.copyWith(
        fontFamily: AppFonts.bodyFamily,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
