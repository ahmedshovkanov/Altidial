import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/coach/planner.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/coach/coach_screen.dart';
import 'package:energy_clock/features/coach/providers.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The contextual Clock entry point for Coach. Watches intent, review,
/// suggestions, insights and the shared clock hour, maps them through
/// [coachCardKind] to a single CTA row. Tapping anywhere opens the hub via
/// `Navigator.push(MaterialPageRoute(...))`, the same non-tab hub pattern as
/// the Projects detail. Styling follows `NowCard`: `AppCard` + `AppSpacing`
/// padding, theme tokens only.
class CoachCard extends ConsumerWidget {
  const CoachCard({super.key});

  void _openHub(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CoachScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intent = ref.watch(todayIntentProvider);
    final review = ref.watch(todayReviewProvider);
    final suggestions = ref.watch(suggestionsProvider);
    final insights = ref.watch(weekInsightsProvider);
    final now = ref.watch(clockProvider);

    if (intent.isLoading ||
        review.isLoading ||
        suggestions.isLoading ||
        insights.isLoading) {
      return const SizedBox.shrink();
    }
    if (intent.hasError ||
        review.hasError ||
        suggestions.hasError ||
        insights.hasError) {
      return const SizedBox.shrink();
    }

    final kind = coachCardKind(
      hasIntent: intent.valueOrNull != null,
      hasSuggestions: (suggestions.valueOrNull ?? const []).isNotEmpty,
      hasReview: review.valueOrNull != null,
      hasNewInsights: (insights.valueOrNull ?? const []).isNotEmpty,
      hour: now.hour,
    );

    final String title;
    final String? action;
    final String semanticsLabel;
    switch (kind) {
      case CoachCardKind.setIntent:
        title = Strings.coachTitle;
        action = Strings.coachSetIntent;
        semanticsLabel = Strings.coachSetIntent;
      case CoachCardKind.suggestionsReady:
        title = Strings.coachTitle;
        action = Strings.coachPlanDay;
        semanticsLabel = Strings.coachPlanDay;
      case CoachCardKind.reviewDue:
        title = Strings.coachTitle;
        action = Strings.coachReviewTitle;
        semanticsLabel = Strings.coachReviewTitle;
      case CoachCardKind.insightsNew:
        title = Strings.coachTitle;
        action = Strings.coachViewInsights;
        semanticsLabel = Strings.coachViewInsights;
      case CoachCardKind.quiet:
        title = '';
        action = null;
        semanticsLabel = Strings.coachSuggestionsEmpty;
    }

    final Widget body;
    if (kind == CoachCardKind.quiet) {
      body = AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        onTap: () => _openHub(context),
        child: const Text(Strings.coachSuggestionsEmpty),
      );
    } else {
      body = AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        onTap: () => _openHub(context),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            FilledButton(
              onPressed: () => _openHub(context),
              child: Text(action!),
            ),
          ],
        ),
      );
    }

    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      onTap: () => _openHub(context),
      child: body,
    );
  }
}
