import 'dart:async';
import 'dart:math' as math;

import 'package:altidial/app/settings/settings_providers.dart';
import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/app/theme/tone_colors.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/features/clock/providers.dart';
import 'package:altidial/shared/widgets/press_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Seven day pills for the week containing the selected day, starting on the
/// first day of the week (the setting, Monday by default).
/// Each pill shows the date and a dot for every tone planned that day. Tapping
/// selects a day. Swiping moves the selected day by seven days (same weekday),
/// so the header, the dial and the strip always agree.
class WeekStrip extends ConsumerStatefulWidget {
  const WeekStrip({this.showDots = true, super.key});

  /// The text in the strip stops growing at this scale, and so does its height
  /// budget. Each pill is only a seventh of the width, so larger text could not
  /// be shown any bigger anyway.
  static const double _maxTextScale = 2;

  /// The height to budget at [textScale].
  static double heightFor(double textScale) =>
      math.max(60.0, 32 * textScale.clamp(1.0, _maxTextScale) + 28);

  final bool showDots;

  @override
  ConsumerState<WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends ConsumerState<WeekStrip> {
  /// The strip is an unbounded page view. This page shows [_anchorWeek], the
  /// week that was selected when the strip was built.
  static const int _centerPage = 5000;

  /// Mutable: the first-day-of-week setting may change after the strip was
  /// built, and the anchor is recomputed around the selected day then.
  late DateTime _anchorWeek;
  late final PageController _controller;

  int get _firstWeekday =>
      ref.read(firstDayOfWeekProvider).valueOrNull ?? DateTime.monday;

  @override
  void initState() {
    super.initState();
    _anchorWeek = startOfWeek(
      ref.read(selectedDateProvider),
      firstWeekday: _firstWeekday,
    );
    _controller = PageController(initialPage: _centerPage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  DateTime _weekForPage(int page) => DateTime(
    _anchorWeek.year,
    _anchorWeek.month,
    _anchorWeek.day + 7 * (page - _centerPage),
  );

  int _pageForWeek(DateTime weekStart) =>
      _centerPage + _daysBetween(_anchorWeek, weekStart) ~/ 7;

  /// The user swiped to another week: keep the same weekday in that week.
  void _onPageChanged(int page) {
    final weekStart = _weekForPage(page);
    final selected = ref.read(selectedDateProvider);
    final selectedWeek = startOfWeek(selected, firstWeekday: _firstWeekday);
    if (selectedWeek == weekStart) return;
    final shift = _daysBetween(selectedWeek, weekStart);
    ref
        .read(selectedDateProvider.notifier)
        .select(DateTime(selected.year, selected.month, selected.day + shift));
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final showDots = widget.showDots && textScale <= 1.3;

    // The date changed somewhere else (for example the Today button): bring
    // its week into view.
    final firstWeekday =
        ref.watch(firstDayOfWeekProvider).valueOrNull ?? DateTime.monday;

    ref.listen(selectedDateProvider, (previous, next) {
      final page = _pageForWeek(startOfWeek(next, firstWeekday: firstWeekday));
      if (!_controller.hasClients || _controller.page?.round() == page) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.jumpToPage(page);
      } else {
        unawaited(
          _controller.animateToPage(
            page,
            duration: AppMotion.base,
            curve: AppMotion.standard,
          ),
        );
      }
    });

    // The first-day-of-week setting changed: rebuild the anchor around the
    // selected day and snap the page view to its week.
    ref.listen(firstDayOfWeekProvider, (previous, next) {
      final weekday = next.valueOrNull;
      if (weekday == null) return;
      final anchor = startOfWeek(
        ref.read(selectedDateProvider),
        firstWeekday: weekday,
      );
      if (anchor == _anchorWeek) return;
      setState(() => _anchorWeek = anchor);
      if (!_controller.hasClients) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.jumpToPage(_centerPage);
      } else {
        unawaited(
          _controller.animateToPage(
            _centerPage,
            duration: AppMotion.base,
            curve: AppMotion.standard,
          ),
        );
      }
    });

    return SizedBox(
      height: WeekStrip.heightFor(textScale),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: WeekStrip._maxTextScale,
        child: PageView.builder(
          controller: _controller,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, page) => _WeekRow(
            weekStart: _weekForPage(page),
            showDots: showDots,
            firstWeekday: firstWeekday,
          ),
        ),
      ),
    );
  }
}

class _WeekRow extends ConsumerWidget {
  const _WeekRow({
    required this.weekStart,
    required this.showDots,
    required this.firstWeekday,
  });

  final DateTime weekStart;
  final bool showDots;
  final int firstWeekday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDateProvider);
    final today = startOfDay(ref.watch(clockProvider));
    final tones =
        ref.watch(weekTonesProvider(weekStart)).valueOrNull ??
        const <DateTime, Set<Tone>>{};

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg - 2,
        vertical: 2,
      ),
      child: Row(
        children: [
          for (final day in daysOfWeek(weekStart, firstWeekday: firstWeekday))
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _DayPill(
                  day: day,
                  isSelected: day == selected,
                  isToday: day == today,
                  tones: tones[day] ?? const <Tone>{},
                  showDots: showDots,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayPill extends ConsumerWidget {
  const _DayPill({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.tones,
    required this.showDots,
  });

  final DateTime day;
  final bool isSelected;
  final bool isToday;
  final Set<Tone> tones;
  final bool showDots;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final toneColors = context.toneColors;
    final theme = Theme.of(context);
    final ordered = [
      for (final tone in Tone.values)
        if (tones.contains(tone)) tone,
    ];
    final dayKey = DateFormat('yyyy-MM-dd').format(day);

    void select() {
      unawaited(HapticFeedback.selectionClick());
      ref.read(selectedDateProvider.notifier).select(day);
    }

    return Semantics(
      button: true,
      selected: isSelected,
      label: Strings.weekDaySemantics(
        DateFormat('EEEE d MMMM').format(day),
        tones: Strings.joinWords([for (final tone in ordered) tone.label]),
        isToday: isToday,
      ),
      excludeSemantics: true,
      onTap: select,
      child: PressScale(
        onTap: select,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isSelected ? colors.ink : AppColors.transparent,
            border: !isSelected && isToday
                ? Border.all(color: colors.ink, width: 1.5)
                : null,
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    DateFormat('E').format(day),
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: isSelected
                          ? colors.onInk.withValues(alpha: 0.7)
                          : colors.muted,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${day.day}',
                    style: theme.textTheme.labelLarge!.copyWith(
                      color: isSelected ? colors.onInk : colors.ink,
                    ),
                  ),
                ),
                SizedBox(
                  height: 6,
                  child: showDots
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final tone in ordered)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1.5,
                                ),
                                child: DecoratedBox(
                                  key: ValueKey('dot-$dayKey-${tone.name}'),
                                  decoration: BoxDecoration(
                                    color: toneColors.fillFor(tone),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const SizedBox.square(dimension: 6),
                                ),
                              ),
                          ],
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
