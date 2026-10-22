import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/shared/widgets/press_scale.dart';
import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary, destructive }

/// A tall, full-width button. Primary is `ink` with `onInk` text, secondary is
/// a faint ink fill, destructive is text in the `danger` colour.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.semanticsLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;

  /// What a screen reader says when it differs from [label], for example "Add
  /// 5 minutes" for a button that reads "+5m".
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final enabled = onPressed != null;
    final (fill, foreground) = switch (variant) {
      AppButtonVariant.primary => (colors.ink, colors.onInk),
      AppButtonVariant.secondary => (
        colors.ink.withValues(alpha: 0.08),
        colors.ink,
      ),
      AppButtonVariant.destructive => (AppColors.transparent, colors.danger),
    };

    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: semanticsLabel ?? label,
        excludeSemantics: true,
        onTap: onPressed,
        child: PressScale(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall!.copyWith(color: foreground),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
