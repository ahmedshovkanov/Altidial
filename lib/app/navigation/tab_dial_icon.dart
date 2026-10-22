import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/tone_colors.dart';
import 'package:altidial/shared/widgets/ring_mark.dart';
import 'package:flutter/widgets.dart';

/// The Clock tab icon: a tiny three-arc ring. Unselected it is one flat
/// [color]. Selected, it sits on the ink pill, so it uses the opposite theme's
/// tone colours to stay vivid against it.
class TabDialIcon extends StatelessWidget {
  const TabDialIcon({
    required this.selected,
    required this.color,
    this.size = 24,
    super.key,
  });

  final bool selected;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tones = context.appColors.isDark ? ToneColors.light : ToneColors.dark;
    final arcs = selected
        ? [tones.focus.solid, tones.life.solid, tones.inbox.solid]
        : [color, color, color];
    return RingMark(colors: arcs, size: size, strokeFraction: 0.22);
  }
}
