import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A vertically flowing animated gradient used as a screen background.
///
/// The gradient continuously flows in a single direction (never reverses)
/// while keeping a vertical orientation ([begin] = topCenter-ish,
/// [end] = bottomCenter-ish). The color list loops back on itself (its last
/// stop matches its first color) and is tiled with [TileMode.repeat], so the
/// flow never has to reverse direction — unlike mirror tiling, this avoids
/// the hard "crease" a color ramp shows at each turnaround point. A soft
/// radial glow drifts gently on top of the base gradient to add depth.
class AnimatedGradientBackground extends StatefulWidget {
  const AnimatedGradientBackground({
    super.key,
    required this.colors,
    this.duration = const Duration(seconds: 30),
    this.child,
  });

  /// Gradient colors ordered from top to bottom.
  final List<Color> colors;

  /// Duration of a single, seamless flow cycle.
  final Duration duration;

  /// Optional content layered on top of the gradient.
  final Widget? child;

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;

        // Close the palette into a loop so the ramp never has to reverse
        // direction: it always flows color 0 -> 1 -> 2 -> 0 -> 1 -> ...
        final colors = [...widget.colors, widget.colors.first];
        final stops = [
          for (var i = 0; i < colors.length; i++) i / (colors.length - 1),
        ];

        // The gradient spans a fixed interval (begin.y to end.y); a larger
        // span stretches each color band taller. TileMode.repeat's true
        // period equals that span exactly, so shifting by one span per
        // cycle lands back on an identical frame — a seamless,
        // one-directional flow with no fold artifact. Anchoring begin.y at
        // the screen's top edge (rather than centering the span) means the
        // first color sits exactly at the top when the animation starts.
        const span = 8.0;
        final shift = t * span;
        final begin = Alignment(0, -1 - shift);
        final end = Alignment(0, -1 + span - shift);

        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: begin,
              end: end,
              colors: colors,
              stops: stops,
              tileMode: TileMode.repeated,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, math.sin(t * 2 * math.pi) * 0.5),
                radius: 0.9,
                colors: [
                  Colors.white.withValues(alpha: 0.12),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
