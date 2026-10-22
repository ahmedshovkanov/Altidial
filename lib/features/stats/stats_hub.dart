import 'package:altidial/core/strings.dart';
import 'package:altidial/features/stats/stats_screen.dart';
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