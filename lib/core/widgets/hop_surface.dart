import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_space.dart';
import 'accent_ornament.dart';

/// How high a surface sits. Depth is expressed by moving up the surface
/// ladder, never by changing hue — see [AppColors].
enum Elevation {
  /// Cards, list rows and inline groups sitting on the page ground.
  raised,

  /// Overlay panels — the top of the stack.
  panel,
}

/// The app's one framed-surface recipe.
///
/// This deliberately exposes an elevation *level* rather than the five
/// independent knobs it used to (`showCorners`, `shadow`, `borderColor`,
/// `borderWidth`, `radius`). Fewer knobs is the enforcement mechanism:
/// screens cannot drift apart if there is nothing to drift with.
///
/// [HopPanel] is this plus a title, a rule and actions. Inline cards use
/// it directly, so there is exactly one recipe rather than two that
/// gradually disagree.
class HopSurface extends StatelessWidget {
  const HopSurface({
    super.key,
    required this.child,
    this.elevation = Elevation.raised,
    this.isMoment = false,
    this.padding = const EdgeInsets.all(AppSpace.lg),
  });

  final Widget child;
  final Elevation elevation;

  /// Marks a surface as a moment — run result, level-up, daily reward.
  /// Moments are the only surfaces that earn an accent rim and brackets.
  final bool isMoment;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final (fill, radius) = switch (elevation) {
      Elevation.raised => (AppColors.surfaceRaised, AppRadius.md),
      Elevation.panel => (AppColors.surfacePanel, AppRadius.lg),
    };

    final surface = Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isMoment ? AppColors.accent : AppColors.edge,
          width: 1,
        ),
        boxShadow: elevation == Elevation.panel
            ? const [
                BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 28,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      padding: padding,
      child: child,
    );

    return isMoment && elevation == Elevation.panel
        ? AccentCorners(child: surface)
        : surface;
  }
}
