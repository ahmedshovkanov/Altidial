import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/reflections/providers.dart';
import 'package:energy_clock/features/stats/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EnergyPatternsCard extends ConsumerWidget {
  const EnergyPatternsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patterns = ref.watch(reflectionPatternsProvider);
    return patterns.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      data: (cards) {
        final empty = cards.isEmpty;
        return StatsSectionCard(
          title: Strings.patternsTitle,
          empty: empty,
          emptyMessage: Strings.patternsEmpty,
          semanticsLabel: empty
              ? Strings.patternsEmpty
              : Strings.patternsSemantics([for (final c in cards) c.title]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final card in cards) ...[
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: card.delta >= 0
                            ? context.toneColors.paletteFor(Tone.life).solid
                            : context.appColors.danger,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(card.title, style: Theme.of(context).textTheme.titleSmall),
                          Text(
                            card.detail,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.appColors.muted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      Strings.patternsSampleSize(card.sampleSize),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.appColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        );
      },
      loading: () => const StatsSectionCard(
        title: Strings.patternsTitle,
        empty: true,
        emptyMessage: Strings.patternsEmpty,
        semanticsLabel: Strings.patternsEmpty,
        child: SizedBox.shrink(),
      ),
      error: (e, st) => StatsSectionCard(
        title: Strings.patternsTitle,
        empty: true,
        emptyMessage: Strings.reflectionsLoadError,
        semanticsLabel: Strings.reflectionsLoadError,
        child: const SizedBox.shrink(),
      ),
    );
  }
}