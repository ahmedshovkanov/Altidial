import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/features/clock/providers.dart';
import 'package:altidial/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Watches the today's-intent shape via [coachRepositoryProvider] directly,
/// so this file (in the progress feature) never imports `features/coach/`.
final _teaserIntentProvider =
    StreamProvider.autoDispose<CoachIntentRow?>((ref) {
      final day = ref.watch(selectedDateProvider);
      return ref.watch(coachRepositoryProvider).watchIntent(day);
    });

/// The Profile entry point for Coach: today's intent status. Tapping opens
/// the hub via [onOpen], which `profile_screen.dart` wires to a
/// `Navigator.push(MaterialPageRoute(...))` exactly like `ProjectsCard` opens
/// the Projects hub — the teaser itself never imports the Coach screen.
class CoachTeaserCard extends ConsumerWidget {
  const CoachTeaserCard({required this.onOpen, super.key});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intent = ref.watch(_teaserIntentProvider);
    return intent.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      skipError: true,
      data: (row) {
        final goal = row?.focusGoal;
        return AppCard(
          onTap: onOpen,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                Strings.coachTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (goal == null)
                FilledButton(
                  onPressed: onOpen,
                  child: const Text(Strings.coachSetIntent),
                )
              else
                Text(goal),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}
