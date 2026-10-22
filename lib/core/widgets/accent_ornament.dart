import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_space.dart';

/// Four accent L-brackets just inside a panel's border.
///
/// Reserved for "moment" panels — run result, level-up, daily reward.
/// Bracketing every surface is what made the old design read as
/// undifferentiated: when everything is decorated, nothing is special.
/// See the accent-discipline rule on [AppColors].
class AccentCorners extends StatelessWidget {
  const AccentCorners({super.key, required this.child, this.size = 14});

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _CornerPainter(size),
      child: child,
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter(this.arm);

  final double arm;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentLight
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    const inset = 6.0;
    final w = size.width;
    final h = size.height;

    void corner(Offset origin, double dx, double dy) {
      canvas.drawLine(origin, origin.translate(arm * dx, 0), paint);
      canvas.drawLine(origin, origin.translate(0, arm * dy), paint);
    }

    corner(const Offset(inset, inset), 1, 1);
    corner(Offset(w - inset, inset), -1, 1);
    corner(Offset(inset, h - inset), 1, -1);
    corner(Offset(w - inset, h - inset), -1, -1);
  }

  @override
  bool shouldRepaint(_CornerPainter oldDelegate) => oldDelegate.arm != arm;
}

/// Thin rule separating panel sections.
///
/// Ambient by default — a flat [AppColors.edge] hairline. [emphasis] opts
/// into the accent gradient, and belongs only on moment panels.
class RuleDivider extends StatelessWidget {
  const RuleDivider({super.key, this.height = 1, this.emphasis = false});

  final double height;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      decoration: emphasis
          ? const BoxDecoration(
              gradient: LinearGradient(colors: [
                Color(0x00E1A937),
                AppColors.accent,
                Color(0x00E1A937),
              ]),
            )
          : const BoxDecoration(color: AppColors.edge),
    );
  }
}
