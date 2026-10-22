import 'package:altidial/app/settings/settings_providers.dart';
import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/core/time/month_time.dart';
import 'package:altidial/features/stats/model/stats_period.dart';
import 'package:altidial/features/stats/providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The Stats header: week/month toggle, the range label, chevrons, and a jump
/// back to the current period. The forward chevron disables at the current
/// period; the range never reaches into the future.
class PeriodHeader extends ConsumerWidget {
  const PeriodHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(statsPeriodProvider);
    final notifier = ref.read(statsPeriodProvider.notifier);
    final firstWeekday =
        ref.watch(firstDayOfWeekProvider).valueOrNull ?? DateTime.monday;
    final isWeek = period.kind == StatsPeriodKind.week;
    final from = isWeek
        ? startOfWeek(period.anchor, firstWeekday: firstWeekday)
        : startOfMonth(period.anchor);
    final label = isWeek ? _weekLabel(from) : DateFormat('MMMM y').format(from);

    final now = startOfDay(DateTime.now());
    final atCurrent = isWeek
        ? startOfWeek(period.anchor, firstWeekday: firstWeekday) ==
              startOfWeek(now, firstWeekday: firstWeekday)
        : startOfMonth(period.anchor) == startOfMonth(now);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _Chevron(
              key: const ValueKey('stats-previous'),
              icon: CupertinoIcons.chevron_left,
              tooltip: isWeek
                  ? Strings.statsPreviousWeek
                  : Strings.statsPreviousMonth,
              onTap: notifier.previous,
            ),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            _Chevron(
              key: const ValueKey('stats-next'),
              icon: CupertinoIcons.chevron_right,
              tooltip: isWeek ? Strings.statsNextWeek : Strings.statsNextMonth,
              onTap: atCurrent ? null : notifier.next,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // A Wrap, not a Row: at very large text sizes the pills and the
        // jump-back button fold onto centred runs instead of overflowing a
        // narrow window.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _KindPill(
              label: Strings.statsPeriodWeek,
              selected: isWeek,
              onTap: () => notifier.setKind(StatsPeriodKind.week),
            ),
            _KindPill(
              label: Strings.statsPeriodMonth,
              selected: !isWeek,
              onTap: () => notifier.setKind(StatsPeriodKind.month),
            ),
            if (!atCurrent)
              TextButton(
                key: const ValueKey('stats-today'),
                onPressed: notifier.returnToNow,
                child: Text(
                  isWeek ? Strings.statsThisWeek : Strings.statsThisMonth,
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// '5 – 11 Oct 2026', widening the start only as far as it must differ.
  String _weekLabel(DateTime from) {
    final to = DateTime(from.year, from.month, from.day + 6);
    final end = DateFormat('d MMM y').format(to);
    if (from.year == to.year && from.month == to.month) {
      return "${DateFormat('d').format(from)} – $end";
    }
    if (from.year == to.year) {
      return "${DateFormat('d MMM').format(from)} – $end";
    }
    return "${DateFormat('d MMM y').format(from)} – $end";
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(icon: Icon(icon), tooltip: tooltip, onPressed: onTap);
  }
}

class _KindPill extends StatelessWidget {
  const _KindPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? colors.ink : AppColors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              label,
              style: theme.textTheme.labelLarge!.copyWith(
                color: selected ? colors.onInk : colors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
