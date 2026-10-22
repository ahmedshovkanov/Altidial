import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/coach/insights_rules.dart';
import 'package:altidial/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';

/// A frozen weekly insight: title + one-line body + evidence line + kind
/// footer. Colours come from theme tokens only.
class InsightCard extends StatelessWidget {
  const InsightCard({required this.insight, super.key});

  final CoachInsight insight;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            insight.title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            insight.body,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            insight.evidence,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.muted,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            insight.kind,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
