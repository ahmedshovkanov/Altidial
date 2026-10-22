import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:flutter/material.dart';

/// A pill naming a tone: its `soft` fill, a `solid` dot, and `deep` text.
class ToneChip extends StatelessWidget {
  const ToneChip({required this.tone, super.key});

  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.toneColors.paletteFor(tone);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.soft,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: palette.solid,
                shape: BoxShape.circle,
              ),
              child: const SizedBox.square(dimension: 8),
            ),
            const SizedBox(width: 6),
            Text(
              tone.label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge!.copyWith(color: palette.deep),
            ),
          ],
        ),
      ),
    );
  }
}
