import 'dart:async';

import 'package:altidial/app/navigation/app_tab_bar.dart';
import 'package:altidial/app/navigation/calendar_tab.dart';
import 'package:altidial/app/navigation/clock_tab.dart';
import 'package:altidial/app/navigation/tab_bar_inset.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/debug/debug_actions.dart';
import 'package:altidial/features/clock/providers.dart';
import 'package:altidial/features/flight_deck/flight_deck_screen.dart';
import 'package:altidial/features/progress/profile_screen.dart';
import 'package:altidial/features/projects/projects_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hosts the five tabs behind a floating bar. Each tab is built the first time
/// it is selected and then kept alive, so switching back keeps its state.
class TabScaffold extends ConsumerStatefulWidget {
  const TabScaffold({super.key});

  @override
  ConsumerState<TabScaffold> createState() => _TabScaffoldState();
}

class _TabScaffoldState extends ConsumerState<TabScaffold> {
  int _index = 0;
  final Set<int> _visited = {0};

  Widget _screen(int index) => switch (index) {
    0 => const ClockTab(),
    1 => ProjectsTabBody(onOpenDay: _openDay),
    2 => CalendarTab(onOpenDay: _openDay),
    3 => const ProfileScreen(),
    _ => FlightDeckScreen(onOpenDay: _openDay),
  };

  void _select(int index) {
    setState(() {
      _index = index;
      _visited.add(index);
    });
  }

  /// A day was tapped in the Calendar: show it on the Clock tab. The Clock's
  /// selected date is the only state involved, so a past day opens read-only
  /// and a future day editable, as everywhere else.
  void _openDay(DateTime day) {
    ref.read(selectedDateProvider.notifier).select(day);
    _select(0);
  }

  void _onProfileHold() {
    unawaited(activateDebug(context, ref));
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final inset =
        AppTabBar.height + AppTabBar.bottomMargin + bottomSafe + AppSpacing.sm;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: TabBarInset(
                height: inset,
                child: IndexedStack(
                  index: _index,
                  children: [
                    for (var i = 0; i < AppTabBar.tabCount; i++)
                      _visited.contains(i)
                          ? _screen(i)
                          : const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomSafe + AppTabBar.bottomMargin,
            child: AppTabBar(
              selectedIndex: _index,
              onSelected: _select,
              onProfileHold: _onProfileHold,
            ),
          ),
        ],
      ),
    );
  }
}
