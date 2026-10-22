import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/progress/xp.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';

/// Level, the XP bar into the next level, and the streaks. A null row is a
/// brand-new user: level 1, no XP, and the invitation to start.
class LevelCard extends StatelessWidget {
  const LevelCard({required this.progress, super.key});

  final ProgressRow? progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final level = progress?.level ?? 1;
    final xp = progress?.xp ?? 0;
    final current = progress?.currentStreak ?? 0;
    final longest = progress?.longestStreak ?? 0;
    final position = xpIntoLevel(xp);
    final fraction = position.end == position.start
        ? 0.0
        : (position.current - position.start) / (position.end - position.start);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                Strings.profileLevel(level),
                style: theme.textTheme.titleLarge,
              ),
              const Spacer(),
              Text(
                Strings.profileXp(position.current, position.end),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.control),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: colors.outline,
              valueColor: AlwaysStoppedAnimation<Color>(colors.ink),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (progress == null)
            Text(Strings.profileEmptyHeader, style: theme.textTheme.bodyMedium)
          else
            Row(
              children: [
                Text(
                  Strings.profileStreak(current),
                  style: theme.textTheme.bodyMedium,
                ),
                const Spacer(),
                Text(
                  Strings.profileBestStreak(longest),
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: colors.muted,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
