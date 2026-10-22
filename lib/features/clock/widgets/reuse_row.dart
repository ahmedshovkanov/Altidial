import 'dart:async';

import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/shared/widgets/press_scale.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The two ways to fill an empty day from another: Copy yesterday and Apply
/// template (spec §5.4). Two faint-ink pills side by side, 44 pt tall.
///
/// [onCopyYesterday] is null when yesterday has no events, and the button is
/// then left out. The label text scales down to fit rather than wrapping.
class ReuseRow extends StatelessWidget {
  const ReuseRow({
    required this.onCopyYesterday,
    required this.onApplyTemplate,
    super.key,
  });

  /// The row's height.
  static const double height = 44;

  final VoidCallback? onCopyYesterday;
  final VoidCallback onApplyTemplate;

  @override
  Widget build(BuildContext context) {
    final copy = onCopyYesterday;

    return SizedBox(
      height: height,
      child: Row(
        children: [
          if (copy != null) ...[
            Expanded(
              child: _ReuseButton(
                label: Strings.copyYesterday,
                icon: CupertinoIcons.doc_on_doc,
                onTap: copy,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: _ReuseButton(
              label: Strings.applyTemplate,
              icon: CupertinoIcons.rectangle_grid_2x2,
              onTap: onApplyTemplate,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReuseButton extends StatelessWidget {
  const _ReuseButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.ink.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: colors.ink),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      label,
                      maxLines: 1,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge!.copyWith(color: colors.ink),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
