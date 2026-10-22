import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Maximum content widths, in logical pixels.
abstract final class ContentWidths {
  /// The single-column Clock layout on medium windows.
  static const double column = 560;

  /// The Calendar's month card.
  static const double calendar = 640;

  /// Stats and Profile: a two-column spread on medium windows and up.
  static const double stats = 800;

  /// Modal sheets and dialogs.
  static const double sheet = 560;

  static const double onboarding = 480;
  static const double tabBar = 480;
}

/// Centres [child] horizontally at the smaller of [maxWidth] and the available
/// width. The child is given exactly that width (not a loose maximum), so it
/// fills it: on a window narrower than [maxWidth] it fills the whole window.
class ContentWidth extends StatelessWidget {
  const ContentWidth({required this.maxWidth, required this.child, super.key});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? math.min(maxWidth, constraints.maxWidth)
            : maxWidth;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: width, child: child),
        );
      },
    );
  }
}
