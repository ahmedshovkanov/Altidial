import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/coach/planner.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/features/clock/data/event_repository.dart';
import 'package:altidial/features/clock/providers.dart';
import 'package:altidial/features/coach/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom sheet listing the day's swap suggestions (at most three) with a
/// per-row Accept / Dismiss. Accept moves the event via the normal edit path;
/// dismiss only hides the row for this session.
class PlanSheet extends ConsumerStatefulWidget {
  const PlanSheet({required this.day, super.key});
  final DateTime day;

  static Future<void> show(BuildContext context, {required DateTime day}) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => PlanSheet(day: day),
    );
  }

  @override
  ConsumerState<PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends ConsumerState<PlanSheet> {
  /// Suggestion event ids hidden this session (dismissed or accepted).
  final Set<int> _dismissed = {};

  Future<void> _accept(SwapSuggestion suggestion) async {
    try {
      await ref
          .read(eventRepositoryProvider)
          .moveEvent(
            id: suggestion.eventId,
            day: widget.day,
            range: MinuteRange(
              suggestion.toStartMinute,
              suggestion.toStartMinute + suggestion.durationMinutes,
            ),
          );
      if (!mounted) return;
      setState(() => _dismissed.add(suggestion.eventId));
    } on RingOverflowException {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(Strings.ringOverflow)));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(Strings.coachSaveFailed)));
    }
  }

  void _dismiss(SwapSuggestion suggestion) {
    setState(() => _dismissed.add(suggestion.eventId));
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = isPastDay(widget.day, now: ref.watch(clockProvider));
    final suggestions = ref.watch(suggestionsProvider);
    final events = ref.watch(dayEventsProvider).valueOrNull ?? const [];
    final titles = {for (final event in events) event.id: event.title};
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              Strings.coachPlanDay,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            suggestions.when(
              data: (list) {
                final visible = [
                  for (final suggestion in list.take(3))
                    if (!_dismissed.contains(suggestion.eventId)) suggestion,
                ];
                if (visible.isEmpty) {
                  return const Text(Strings.coachSuggestionsEmpty);
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final suggestion in visible)
                      _SuggestionRow(
                        suggestion: suggestion,
                        title:
                            titles[suggestion.eventId] ??
                            'Event ${suggestion.eventId}',
                        showAccept: !readOnly,
                        onAccept: () => _accept(suggestion),
                        onDismiss: () => _dismiss(suggestion),
                      ),
                  ],
                );
              },
              error: (error, _) => const Text(Strings.coachLoadError),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.suggestion,
    required this.title,
    required this.showAccept,
    required this.onAccept,
    required this.onDismiss,
  });

  final SwapSuggestion suggestion;
  final String title;
  final bool showAccept;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text(
                '${formatMinuteOfDay(suggestion.fromStartMinute)} → '
                '${formatMinuteOfDay(suggestion.toStartMinute)}',
              ),
              const SizedBox(width: AppSpacing.sm),
              Chip(label: Text(suggestionReasonLabel(suggestion.reason))),
            ],
          ),
          Row(
            children: [
              if (showAccept)
                TextButton(
                  onPressed: onAccept,
                  child: const Text(Strings.coachAccept),
                ),
              TextButton(
                onPressed: onDismiss,
                child: const Text(Strings.dismiss),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The reason chip text for a swap suggestion.
String suggestionReasonLabel(SwapReason reason) => switch (reason) {
  SwapReason.peak => Strings.coachReasonPeak,
  SwapReason.lateAvoid => Strings.coachReasonLate,
  SwapReason.balance => Strings.coachReasonBalance,
};
