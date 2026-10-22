import 'dart:convert';

import 'package:energy_clock/app/navigation/tab_bar_inset.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/coach/insights_rules.dart';
import 'package:energy_clock/core/coach/planner.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/coach/providers.dart';
import 'package:energy_clock/features/coach/widgets/insight_card.dart';
import 'package:energy_clock/features/coach/widgets/intent_sheet.dart';
import 'package:energy_clock/features/coach/widgets/plan_sheet.dart';
import 'package:energy_clock/features/coach/widgets/review_sheet.dart';
import 'package:energy_clock/shared/layout/content_width.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Coach hub: Intent (today) / Suggestions (today) / Insights (this
/// week). Opened from the Clock card and the Profile teaser via
/// `Navigator.push(MaterialPageRoute(...))`; the tab count stays five.
/// Insight rows parse `payloadJson` via `CoachInsight.fromJson` in try/catch:
/// a corrupt row is skipped and never crashes the hub.
class CoachScreen extends ConsumerWidget {
  const CoachScreen({super.key});

  void _invalidateAll(WidgetRef ref) {
    ref.invalidate(todayIntentProvider);
    ref.invalidate(todayReviewProvider);
    ref.invalidate(suggestionsProvider);
    ref.invalidate(weekInsightsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intent = ref.watch(todayIntentProvider);
    final review = ref.watch(todayReviewProvider);
    final suggestions = ref.watch(suggestionsProvider);
    final insights = ref.watch(weekInsightsProvider);

    if (intent.isLoading ||
        review.isLoading ||
        suggestions.isLoading ||
        insights.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text(Strings.coachTitle)),
        body: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    if (intent.hasError ||
        review.hasError ||
        suggestions.hasError ||
        insights.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text(Strings.coachTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  Strings.coachLoadError,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () => _invalidateAll(ref),
                  child: const Text(Strings.deckRetry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final day = ref.watch(selectedDateProvider);
    final parsed = <CoachInsight>[
      for (final row in insights.valueOrNull ?? const <CoachInsightRow>[])
        ..._parseRow(row),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.coachTitle)),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          TabBarInset.of(context) + AppSpacing.xl,
        ),
        child: ContentWidth(
          maxWidth: ContentWidths.stats,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                Strings.coachSetIntent,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              _IntentSection(
                intent: intent.valueOrNull,
                review: review.valueOrNull,
                day: day,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                Strings.coachPlanDay,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              _SuggestionsSection(
                suggestions:
                    suggestions.valueOrNull ?? const <SwapSuggestion>[],
                day: day,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                Strings.coachTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (parsed.isEmpty)
                const Text(Strings.coachInsightsEmpty)
              else
                for (final insight in parsed) ...[
                  InsightCard(insight: insight),
                  const SizedBox(height: AppSpacing.sm),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Parses one frozen row; corrupt JSON is skipped, never throws.
Iterable<CoachInsight> _parseRow(CoachInsightRow row) sync* {
  try {
    final decoded = jsonDecode(row.payloadJson);
    if (decoded is! Map<String, Object?>) return;
    yield CoachInsight.fromJson(decoded);
  } on Object {
    return;
  }
}

class _IntentSection extends StatelessWidget {
  const _IntentSection({required this.intent, required this.review, required this.day});

  final CoachIntentRow? intent;
  final CoachReviewRow? review;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final current = intent;
    final currentReview = review;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (current == null)
          FilledButton(
            onPressed: () => IntentSheet.show(context, day: day),
            child: const Text(Strings.coachSetIntent),
          )
        else
          Text(current.focusGoal),
        if (current?.predictedEnergy != null)
          Text(
            '${Strings.predictedEnergyLabel} ${current!.predictedEnergy}/5',
          ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          Strings.coachReviewTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (currentReview == null)
          FilledButton(
            onPressed: () => ReviewSheet.show(context, day: day),
            child: const Text(Strings.coachReviewTitle),
          )
        else
          Text(
            'Energy ${currentReview.energy}/5'
            '${currentReview.winText != null && currentReview.winText!.isNotEmpty ? ' — ${currentReview.winText}' : ''}',
          ),
        const SizedBox(height: AppSpacing.sm),
        const _ReflectionLine(),
      ],
    );
  }
}

/// Today's live reflection aggregates under the review block. Empty while
/// loading or on error; copy comes from [Strings] only.
class _ReflectionLine extends ConsumerWidget {
  const _ReflectionLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(todayReflectionSummaryProvider);
    return summary.when(
      data: (s) => s.count == 0 || s.avgEnergy == null || s.avgFocus == null
          ? const Text(Strings.reflectionsTodayEmpty)
          : Text(
              Strings.reflectionsTodayLine(
                s.count,
                s.avgEnergy!.toStringAsFixed(1),
                s.avgFocus!.toStringAsFixed(1),
                s.topTags.map(Strings.tagLabel).join(', '),
              ),
            ),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _SuggestionsSection extends StatelessWidget {
  const _SuggestionsSection({required this.suggestions, required this.day});

  final List<SwapSuggestion> suggestions;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(Strings.coachSuggestionsEmpty),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: () => PlanSheet.show(context, day: day),
            child: const Text(Strings.coachPlanDay),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final suggestion in suggestions.take(3))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${formatMinuteOfDay(suggestion.fromStartMinute)} → '
                  '${formatMinuteOfDay(suggestion.toStartMinute)}',
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Chip(
                      label: Text(
                        suggestionReasonLabel(suggestion.reason),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(suggestion.evidence)),
                  ],
                ),
              ],
            ),
          ),
        FilledButton(
          onPressed: () => PlanSheet.show(context, day: day),
          child: const Text(Strings.coachPlanDay),
        ),
      ],
    );
  }
}
