import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/features/progress/widgets/profile_section.dart';
import 'package:flutter/material.dart';

/// Today's energy score, always with its three parts showing.
class ScoreCard extends StatelessWidget {
  const ScoreCard({required this.score, super.key});

  final DayScoreRow? score;

  @override
  Widget build(BuildContext context) {
    final row = score;
    if (row == null) {
      return ProfileSection(
        title: Strings.profileScoreTitle,
        empty: true,
        emptyMessage: Strings.profileScoreEmpty,
        child: const SizedBox.shrink(),
      );
    }
    return ProfileSection(
      title: Strings.profileScoreTitle,
      empty: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${row.energyScore}',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          _Points(
            label: Strings.profileScoreAdherence,
            earned: row.adherencePoints,
            total: 50,
          ),
          _Points(
            label: Strings.profileScoreFocus,
            earned: row.focusPoints,
            total: 30,
          ),
          _Points(
            label: Strings.profileScoreBalance,
            earned: row.balancePoints,
            total: 20,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            Strings.profileScoreCaption,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Points extends StatelessWidget {
  const _Points({
    required this.label,
    required this.earned,
    required this.total,
  });

  final String label;
  final int earned;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            Strings.profilePoints(earned, total),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
