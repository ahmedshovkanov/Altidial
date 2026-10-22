import 'package:altidial/app/navigation/tab_bar_inset.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/data/repositories/stats_repository.dart';
import 'package:altidial/features/reflections/reflections_screen.dart';
import 'package:altidial/features/reflections/widgets/patterns_card.dart';
import 'package:altidial/features/stats/providers.dart';
import 'package:altidial/features/stats/stats_layout.dart';
import 'package:altidial/features/stats/widgets/focus_depth_card.dart';
import 'package:altidial/features/stats/widgets/heatmap_card.dart';
import 'package:altidial/features/stats/widgets/period_header.dart';
import 'package:altidial/features/stats/widgets/planned_actual_card.dart';
import 'package:altidial/features/stats/widgets/tone_balance_card.dart';
import 'package:altidial/shared/layout/content_width.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Stats tab: a week or month of tone balance, planned-vs-actual, focus
/// depth and the focus heatmap.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(statsDataProvider);
    return data.when(
      data: (snapshot) => _StatsBody(snapshot: snapshot),
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(Strings.statsLoadError, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _StatsBody extends ConsumerWidget {
  const _StatsBody({required this.snapshot});

  final StatsSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(statsWindowProvider);
    final twoColumn = StatsLayout.of(context).twoColumn;
    final bottomInset = TabBarInset.of(context);

    Widget gap() => const SizedBox(height: AppSpacing.lg);
    final tone = ToneBalanceCard(
      key: const ValueKey('stats-tone-balance'),
      snapshot: snapshot,
      window: window,
    );
    final planned = PlannedActualCard(
      key: const ValueKey('stats-planned-actual'),
      snapshot: snapshot,
      window: window,
    );
    final depth = FocusDepthCard(
      key: const ValueKey('stats-focus-depth'),
      snapshot: snapshot,
      window: window,
    );
    final heatmap = HeatmapCard(
      key: const ValueKey('stats-heatmap'),
      snapshot: snapshot,
      window: window,
    );
    const patterns = EnergyPatternsCard(key: ValueKey('stats-patterns'));

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        bottomInset + AppSpacing.xl,
      ),
      child: ContentWidth(
        maxWidth: ContentWidths.stats,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: PeriodHeader()),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReflectionsScreen(),
                      ),
                    );
                  },
                  child: const Text(Strings.reflectionsTitle),
                ),
              ],
            ),
            gap(),
            if (twoColumn) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: tone),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: planned),
                ],
              ),
              gap(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: depth),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: heatmap),
                ],
              ),
              gap(),
              patterns,
            ] else ...[
              tone,
              gap(),
              planned,
              gap(),
              depth,
              gap(),
              heatmap,
              gap(),
              patterns,
            ],
          ],
        ),
      ),
    );
  }
}
