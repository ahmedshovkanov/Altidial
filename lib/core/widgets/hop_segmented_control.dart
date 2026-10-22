import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../theme/app_space.dart';
import '../theme/app_theme.dart';

/// A row of equal-width segments, one per value, with the selected one
/// filled gold.
///
/// Display and selection only: a caller that locks the control is reflecting
/// state it owns (the run engine locks difficulty at the first GO), not
/// deciding it here.
class HopSegmentedControl<T> extends StatelessWidget {
  const HopSegmentedControl({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelect,
    this.locked = false,
    this.fontSize = 24,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final void Function(T) onSelect;

  /// When true, tapping a segment does nothing and the row dims.
  final bool locked;

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final value in values)
          Expanded(
            child: _Segment(
              label: labelOf(value),
              selected: value == selected,
              locked: locked,
              fontSize: fontSize,
              onTap: () => onSelect(value),
            ),
          ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.locked,
    required this.fontSize,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool locked;
  final double fontSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpace.xs),
      child: Opacity(
        opacity: locked ? 0.55 : 1,
        child: Material(
          // Gold marks the active segment only; resting segments sit on blue
          // with a muted edge. See the gold-discipline rule.
          color: selected ? AppColors.accentDeep : AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            onTap: locked ? null : onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              constraints: const BoxConstraints(
                minHeight: AppTheme.minTapTarget,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: selected ? AppColors.accentLight : AppColors.edge,
                  width: selected ? 2 : 1,
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppFonts.displayFamily,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w400,
                    color: selected
                        ? AppColors.accentLight
                        : AppColors.textPrimary,
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
