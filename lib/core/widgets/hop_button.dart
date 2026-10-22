import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_space.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';

/// The three button roles.
///
/// At most one [accent] button belongs on a screen — it is the reserved
/// style, and it marks the one action the screen exists for.
enum HopButtonStyle { primary, secondary, accent }

/// The only button in the app.
class HopButton extends StatelessWidget {
  const HopButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = HopButtonStyle.primary,
    this.isActive = false,
    this.expand = false,
    this.labelScale = 1.0,
  });

  final String label;
  final VoidCallback? onPressed;
  final HopButtonStyle style;

  /// Lights an otherwise plain button — a selected difficulty, an equipped
  /// skill. Active is a state, not a style, so it borrows the accent rim
  /// without becoming an accent button.
  final bool isActive;

  final bool expand;
  final double labelScale;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final highlighted = isActive || style == HopButtonStyle.accent;

    // Secondary is a true ghost: no fill at all. The old implementation
    // gave it a blue fill, which made it compete with primary rather than
    // recede behind it.
    final fill = switch (style) {
      HopButtonStyle.primary => AppColors.brand,
      HopButtonStyle.secondary => Colors.transparent,
      HopButtonStyle.accent => AppColors.accentDeep,
    };

    final labelColor = switch (style) {
      _ when !enabled => AppColors.textMuted,
      HopButtonStyle.accent => AppColors.accentLight,
      HopButtonStyle.secondary =>
        isActive ? AppColors.accentLight : AppColors.textMuted,
      HopButtonStyle.primary =>
        isActive ? AppColors.accentLight : AppColors.textPrimary,
    };

    final rimColor = switch (enabled) {
      false => AppColors.edge,
      true when highlighted => AppColors.accent,
      _ => AppColors.edge,
    };

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: enabled ? fill : AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.md),
          splashColor: AppColors.brandLift.withValues(alpha: 0.4),
          highlightColor: AppColors.brandLift.withValues(alpha: 0.25),
          child: Container(
            width: expand ? double.infinity : null,
            constraints: const BoxConstraints(
              minHeight: AppTheme.minTapTarget,
              minWidth: AppTheme.minTapTarget,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg,
              vertical: AppSpace.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: rimColor,
                width: highlighted && enabled ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyStrong(context).copyWith(
                  fontSize: AppTextStyles.bodyStrongSize *
                      Responsive.scaleOf(context) *
                      labelScale,
                  color: labelColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
