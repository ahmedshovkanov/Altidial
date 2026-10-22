import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/reflections/model/reflection.dart';
import 'package:energy_clock/features/reflections/providers.dart';
import 'package:energy_clock/features/reflections/reflections_screen.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Profile teaser for Reflections: the reflected count and the top pattern,
/// tapping through to the Journal. Hidden while loading or on error, so a
/// reflections hiccup never breaks the Profile tab.
class ReflectionsCard extends ConsumerWidget {
  const ReflectionsCard({super.key});

  void _openJournal(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReflectionsScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = ref.watch(reflectionsTimelineProvider);
    final patterns = ref.watch(reflectionPatternsProvider);
    return timeline.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      skipError: true,
      data: (rows) {
        final reflected = rows
            .where(
              (r) => isReflected(
                energyRating: r.session.energyRating,
                focusRating: r.session.focusRating,
                tags: r.session.tags,
                note: r.session.note,
              ),
            )
            .length;
        final cards = patterns.valueOrNull;
        final top = cards?.isNotEmpty == true ? cards!.first.title : null;
        return AppCard(
          onTap: () => _openJournal(context),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                Strings.reflectionsTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (reflected == 0)
                Text(
                  Strings.reflectionsEmptyHint,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.appColors.muted,
                  ),
                )
              else ...[
                Text(
                  Strings.reflectionsCount(reflected),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (top != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    top,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.appColors.muted,
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}
