import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The Clock screen's header: the day name and date, a Today pill when you are
/// on another day, a "Read-only" chip on past days, an overflow menu, and the
/// round + button. A past day cannot be added to, so it has no + button; that
/// room goes to the chip and the menu.
class ClockHeader extends ConsumerWidget {
  const ClockHeader({
    required this.onAdd,
    this.onSaveTemplate,
    this.onCopyYesterday,
    this.onApplyTemplate,
    this.showDate = true,
    super.key,
  });

  /// Height at normal text size, with the date line.
  static const double height = 48;

  /// The height to budget at [textScale], with or without the date line.
  static double heightFor(double textScale, {required bool showDate}) =>
      (showDate ? 44 : 30) * textScale + 4;

  /// The Read-only chip and the Today pill are small labels in a row that also
  /// has to hold the title and the round buttons, so their text stops growing
  /// at this scale. Without it a past day overflowed a 320 pt window at large
  /// text sizes.
  static const double _maxPillTextScale = 1.3;

  final VoidCallback onAdd;

  /// The overflow menu's actions. An action is listed only when it has a
  /// callback, and the ⋯ button is left out when none has.
  final VoidCallback? onSaveTemplate;
  final VoidCallback? onCopyYesterday;
  final VoidCallback? onApplyTemplate;

  /// The date line under the day name; dropped on a very short screen.
  final bool showDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDateProvider);
    final now = ref.watch(clockProvider);
    final isToday = selected == startOfDay(now);
    final readOnly = isPastDay(selected, now: now);
    final colors = context.appColors;
    final theme = Theme.of(context);
    final hasMenu =
        onSaveTemplate != null ||
        onCopyYesterday != null ||
        onApplyTemplate != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        0,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: height - 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The day name is the one line that must stay on one line,
                  // so it shrinks rather than wraps at very large text sizes.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      DateFormat('EEEE').format(selected),
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  if (showDate)
                    Text(
                      DateFormat('d MMMM y').format(selected),
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (readOnly) ...[
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: _maxPillTextScale,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.outline),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 6,
                    ),
                    child: Text(
                      Strings.readOnlyChip,
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            if (!isToday) ...[
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: _maxPillTextScale,
                child: TextButton(
                  onPressed: ref.read(selectedDateProvider.notifier).today,
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
            if (hasMenu) ...[
              _MoreMenu(
                onSaveTemplate: onSaveTemplate,
                onCopyYesterday: onCopyYesterday,
                onApplyTemplate: onApplyTemplate,
              ),
              if (!readOnly) const SizedBox(width: AppSpacing.sm),
            ],
            if (!readOnly)
              IconButton.filled(
                icon: const Icon(Icons.add),
                tooltip: Strings.addEvent,
                onPressed: onAdd,
                style: IconButton.styleFrom(
                  backgroundColor: colors.ink,
                  foregroundColor: colors.onInk,
                  minimumSize: const Size(44, 44),
                  shape: const CircleBorder(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _MoreAction { saveTemplate, copyYesterday, applyTemplate }

/// The round ⋯ button and its menu. A faint ink circle, like the stepper
/// buttons, so the filled + stays the one primary control.
class _MoreMenu extends StatelessWidget {
  const _MoreMenu({
    required this.onSaveTemplate,
    required this.onCopyYesterday,
    required this.onApplyTemplate,
  });

  final VoidCallback? onSaveTemplate;
  final VoidCallback? onCopyYesterday;
  final VoidCallback? onApplyTemplate;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return PopupMenuButton<_MoreAction>(
      tooltip: Strings.moreActions,
      onSelected: (action) => switch (action) {
        _MoreAction.saveTemplate => onSaveTemplate?.call(),
        _MoreAction.copyYesterday => onCopyYesterday?.call(),
        _MoreAction.applyTemplate => onApplyTemplate?.call(),
      },
      itemBuilder: (context) => [
        if (onSaveTemplate != null)
          const PopupMenuItem(
            value: _MoreAction.saveTemplate,
            child: Text(Strings.saveAsTemplate),
          ),
        if (onCopyYesterday != null)
          const PopupMenuItem(
            value: _MoreAction.copyYesterday,
            child: Text(Strings.copyYesterday),
          ),
        if (onApplyTemplate != null)
          const PopupMenuItem(
            value: _MoreAction.applyTemplate,
            child: Text(Strings.applyTemplate),
          ),
      ],
      child: SizedBox.square(
        dimension: 44,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.ink.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.more_horiz, color: colors.ink),
        ),
      ),
    );
  }
}
