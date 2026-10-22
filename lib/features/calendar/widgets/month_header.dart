import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/strings.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The Calendar's header: the month and year, a Today pill when another month
/// is showing, and previous and next buttons.
class MonthHeader extends StatelessWidget {
  const MonthHeader({
    required this.month,
    required this.isCurrentMonth,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    super.key,
  });

  /// The first of the month shown.
  final DateTime month;

  /// Whether [month] is the month of today; the Today pill is hidden then.
  final bool isCurrentMonth;

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  /// The pill's text stops growing here, as the Clock header's does.
  static const double _maxPillTextScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            // The month name is the one thing that must stay on one line, so
            // it shrinks rather than wraps at very large text sizes.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Semantics(
                header: true,
                child: Text(
                  DateFormat('MMMM y').format(month),
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ),
          ),
          if (!isCurrentMonth) ...[
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: _maxPillTextScale,
              child: TextButton(
                onPressed: onToday,
                style: TextButton.styleFrom(
                  foregroundColor: colors.ink,
                  backgroundColor: colors.ink.withValues(alpha: 0.08),
                  shape: const StadiumBorder(),
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                ),
                child: const Text(Strings.today),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          _ArrowButton(
            icon: CupertinoIcons.chevron_left,
            tooltip: Strings.previousMonth,
            onPressed: onPrevious,
          ),
          const SizedBox(width: AppSpacing.xs),
          _ArrowButton(
            icon: CupertinoIcons.chevron_right,
            tooltip: Strings.nextMonth,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: colors.ink.withValues(alpha: 0.08),
        foregroundColor: colors.ink,
        minimumSize: const Size(44, 44),
        shape: const CircleBorder(),
      ),
    );
  }
}
