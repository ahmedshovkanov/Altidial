import 'dart:async';

import 'package:energy_clock/app/navigation/tab_bar_inset.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/time/month_time.dart';
import 'package:energy_clock/features/calendar/widgets/month_header.dart';
import 'package:energy_clock/features/calendar/widgets/month_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Calendar tab: the month header over a page view of months. Swipe or use
/// the arrows to move between months; the Today pill returns to the current
/// one. Tapping a day calls [onOpenDay] (spec §7).
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({
    required this.today,
    required this.onOpenDay,
    super.key,
  });

  /// Today at local midnight. It comes from the shared clock, so a tab left
  /// open across midnight moves its Today marker.
  final DateTime today;

  final ValueChanged<DateTime> onOpenDay;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  /// The page view is open-ended both ways. This page shows [_anchorMonth],
  /// the month that was current when the screen was built.
  static const int _centerPage = 1200;

  late final DateTime _anchorMonth;
  late final PageController _controller;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _anchorMonth = startOfMonth(widget.today);
    _visibleMonth = _anchorMonth;
    _controller = PageController(initialPage: _centerPage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DateTime _monthForPage(int page) =>
      addMonths(_anchorMonth, page - _centerPage);

  int _pageForMonth(DateTime month) =>
      _centerPage + monthsBetween(_anchorMonth, month);

  void _goToPage(int page) {
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
  }

  void _step(int delta) =>
      _goToPage((_controller.page ?? _centerPage).round() + delta);

  @override
  Widget build(BuildContext context) {
    final currentMonth = startOfMonth(widget.today);

    return Padding(
      padding: EdgeInsets.only(bottom: TabBarInset.of(context)),
      child: Column(
        children: [
          MonthHeader(
            month: _visibleMonth,
            isCurrentMonth: _visibleMonth == currentMonth,
            onPrevious: () => _step(-1),
            onNext: () => _step(1),
            onToday: () => _goToPage(_pageForMonth(currentMonth)),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (page) =>
                  setState(() => _visibleMonth = _monthForPage(page)),
              itemBuilder: (context, page) => MonthPage(
                month: _monthForPage(page),
                today: widget.today,
                onOpenDay: widget.onOpenDay,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
