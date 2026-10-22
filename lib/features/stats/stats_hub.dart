import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/stats/stats_screen.dart';
import 'package:flutter/material.dart';

class StatsHub extends StatelessWidget {
  const StatsHub({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.tabStats)),
      body: const StatsScreen(),
    );
  }
}