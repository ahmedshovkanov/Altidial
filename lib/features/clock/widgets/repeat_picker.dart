import 'dart:async';

import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/recurrence/recurrence_rule.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/shared/widgets/press_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// How an event repeats: Never, Every day, Weekdays or Custom, with seven
/// weekday toggles for Custom and an optional end date once it repeats.
///
/// It holds no state. It shows [rule] and reports every change through
/// [onChanged], so the event sheet owns the value. [firstDay] is the event's
/// own day: Custom starts with its weekday selected, and the end date cannot
/// be earlier than it.
class RepeatPicker extends StatelessWidget {
  const RepeatPicker({
    required this.rule,
    required this.firstDay,
    required this.onChanged,
    super.key,
  });

  final RecurrenceRule rule;
  final DateTime firstDay;
  final ValueChanged<RecurrenceRule> onChanged;

  void _selectKind(RecurrenceKind kind) {
    final until = rule.until;
    onChanged(switch (kind) {
      RecurrenceKind.none => const RecurrenceRule.none(),
      RecurrenceKind.daily => RecurrenceRule.daily(until: until),
      RecurrenceKind.weekdays => RecurrenceRule.weekdays(until: until),
      RecurrenceKind.custom =>
        rule.kind == RecurrenceKind.custom
            ? rule
            : RecurrenceRule.custom({firstDay.weekday}, until: until),
    });
  }

  void _toggleDay(int weekday) {
    final days = {...rule.weekdays};
    if (!days.add(weekday)) {
      // At least one day always stays on.
      if (days.length == 1) return;
      days.remove(weekday);
    }
    onChanged(RecurrenceRule.custom(days, until: rule.until));
  }

  Future<void> _pickEndDate(BuildContext context) async {
    final first = startOfDay(firstDay);
    final suggested = DateTime(first.year, first.month + 1, first.day);
    final current = rule.until;
    final initial = current == null || current.isBefore(first)
        ? suggested
        : current;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(first.year + 10, first.month, first.day),
      helpText: Strings.repeatEndHelp,
    );
    if (picked != null) onChanged(rule.withUntil(picked));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final until = rule.until;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(Strings.repeatLabel, style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _Pill(
              label: Strings.repeatNever,
              selected: !rule.repeats,
              onTap: () => _selectKind(RecurrenceKind.none),
            ),
            _Pill(
              label: Strings.repeatDaily,
              selected: rule.kind == RecurrenceKind.daily,
              onTap: () => _selectKind(RecurrenceKind.daily),
            ),
            _Pill(
              label: Strings.repeatWeekdays,
              selected: rule.kind == RecurrenceKind.weekdays,
              onTap: () => _selectKind(RecurrenceKind.weekdays),
            ),
            _Pill(
              label: Strings.repeatCustom,
              selected: rule.kind == RecurrenceKind.custom,
              onTap: () => _selectKind(RecurrenceKind.custom),
            ),
          ],
        ),
        if (rule.kind == RecurrenceKind.custom) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _DayToggle(
                      key: ValueKey('repeat-day-${DateTime.monday + i}'),
                      initial: Strings.weekdayInitials[i],
                      name: Strings.weekdayLong[i],
                      selected: rule.occursOnWeekday(DateTime.monday + i),
                      onTap: () => _toggleDay(DateTime.monday + i),
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (rule.repeats) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(Strings.repeatEndsLabel, style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _Pill(
                label: Strings.repeatNoEnd,
                selected: until == null,
                onTap: () => onChanged(rule.withUntil(null)),
              ),
              _Pill(
                label: until == null
                    ? Strings.repeatEndsOnDate
                    : Strings.repeatEndsOn(DateFormat('d MMM y').format(until)),
                selected: until != null,
                onTap: () => unawaited(_pickEndDate(context)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A rounded choice: ink fill when selected, a faint ink fill otherwise.
class _Pill extends StatelessWidget {
  const _Pill({
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

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        onTap: () {
          if (!selected) unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? colors.ink : colors.ink.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                    color: selected ? colors.onInk : colors.ink,
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

/// One weekday of the custom picker: its initial, read aloud as the full name.
/// A seventh of the row wide and 48 pt tall.
class _DayToggle extends StatelessWidget {
  const _DayToggle({
    required this.initial,
    required this.name,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String initial;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? colors.ink : colors.ink.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          child: SizedBox(
            height: 48,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  initial,
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                    color: selected ? colors.onInk : colors.ink,
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
