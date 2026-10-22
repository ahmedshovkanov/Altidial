import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/shared/widgets/press_scale.dart';
import 'package:flutter/material.dart';

/// A rounded card on the `surface` colour. Light mode lifts it with a soft
/// shadow; dark mode draws a hairline border instead.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Overrides the fill, for example with a tone colour on the Now card.
  final Color? color;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
      side: colors.isDark ? BorderSide(color: colors.outline) : BorderSide.none,
    );
    final card = DecoratedBox(
      decoration: ShapeDecoration(
        color: color ?? colors.surface,
        shape: shape,
        shadows: colors.cardShadow,
      ),
      child: Padding(padding: padding, child: child),
    );
    return onTap == null ? card : PressScale(onTap: onTap, child: card);
  }
}
