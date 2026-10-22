import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// A label on the left, a value on the right. Used by the run result
/// overlay, Profile and Stats so a figure reads the same everywhere.
class LabelValueRow extends StatelessWidget {
  const LabelValueRow({
    super.key,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;

  /// Accent, for a figure that is news: a payout, a level, XP earned.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.body(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label, style: style, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                maxLines: 1,
                softWrap: false,
                style: AppTextStyles.numeric(
                  highlight ? style.copyWith(color: AppColors.accentLight) : style,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
