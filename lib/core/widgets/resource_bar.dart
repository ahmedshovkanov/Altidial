import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../theme/app_text_styles.dart';
import '../theme/responsive.dart';

/// A labelled bar for a run resource, like cargo or XP.
///
/// The fill eases toward its target. Incrementing [jolt] shakes the bar and
/// flashes it gold, which is how a cargo hit is made to feel like damage.
class ResourceBar extends StatefulWidget {
  const ResourceBar({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.fillColor,
    this.jolt = 0,
    this.compact = false,
    this.valueLabel,
    this.duration = const Duration(milliseconds: 420),
  });

  final String label;
  final double value;
  final double max;
  final Color fillColor;

  /// Increment this to play the damage animation.
  final int jolt;

  /// Shrinks the label and the bar so two of these fit side by side in the
  /// run's resources band without eating the screen.
  final bool compact;

  /// Replaces the percentage on the right. An XP bar wants `340 / 900 XP`,
  /// not `38%`.
  final String? valueLabel;

  final Duration duration;

  @override
  State<ResourceBar> createState() => _ResourceBarState();
}

class _ResourceBarState extends State<ResourceBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _jolter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void didUpdateWidget(ResourceBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.jolt != oldWidget.jolt) {
      _jolter.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _jolter.dispose();
    super.dispose();
  }

  double get _fraction =>
      widget.max <= 0 ? 0 : (widget.value / widget.max).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _jolter,
      builder: (context, child) {
        // Decaying shake, so the bar settles instead of ringing.
        final decay = 1 - _jolter.value;
        final dx = math.sin(_jolter.value * math.pi * 6) * 6 * decay;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Column(
        // Sizes to its content so the band can sit two of these in a Row
        // without either one stretching to the available height.
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                // Compact bars share the band's width with a second bar and
                // the two tiles, so the label scales down rather than
                // ellipsing to "CAR...".
                child: widget.compact
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          softWrap: false,
                          style: _labelStyle(context),
                        ),
                      )
                    : Text(
                        widget.label,
                        style: _labelStyle(context),
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    widget.valueLabel ?? '${(_fraction * 100).round()}%',
                    maxLines: 1,
                    softWrap: false,
                    style: AppTextStyles.numeric(_labelStyle(context)),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: widget.compact ? 3 : 4),
          AnimatedBuilder(
            animation: _jolter,
            builder: (context, _) {
              final flash = (1 - _jolter.value).clamp(0.0, 1.0);
              return Container(
                height: widget.compact ? 10 : 18,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVoid,
                  borderRadius: BorderRadius.circular(
                    widget.compact ? 5 : 9,
                  ),
                  border: Border.all(
                    // Rests at the neutral rim, not accent — accent marks
                    // special or active elements only, and this bar is
                    // always on screen. The jolt lerps toward accentLight
                    // and decays back here, so accent only ever flashes.
                    color: Color.lerp(
                      AppColors.edge,
                      AppColors.accentLight,
                      _jolter.isAnimating ? flash : 0,
                    )!,
                    width: _jolter.isAnimating ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    widget.compact ? 4 : 8,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: _fraction, end: _fraction),
                      duration: widget.duration,
                      curve: Curves.easeOutCubic,
                      builder: (context, fraction, _) {
                        return FractionallySizedBox(
                          key: const ValueKey('resource-bar-fill'),
                          widthFactor: fraction,
                          heightFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  widget.fillColor,
                                  Color.lerp(
                                    widget.fillColor,
                                    AppColors.textPrimary,
                                    0.35,
                                  )!,
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  TextStyle _labelStyle(BuildContext context) => TextStyle(
    fontFamily: AppFonts.displayFamily,
    fontSize: (widget.compact ? 16 : 20) * Responsive.scaleOf(context),
    fontWeight: FontWeight.w800,
    letterSpacing: widget.compact ? 0.6 : 1.1,
    color: AppColors.textPrimary,
  );
}
