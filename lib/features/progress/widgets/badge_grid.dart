import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/progress/badges.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/features/progress/widgets/profile_section.dart';
import 'package:flutter/material.dart';

/// All ten badges: earned ones with their descriptions, the rest locked.
class BadgeGrid extends StatelessWidget {
  const BadgeGrid({required this.unlocked, super.key});

  final List<BadgeUnlockRow> unlocked;

  @override
  Widget build(BuildContext context) {
    final earned = {for (final row in unlocked) row.badgeId};
    final theme = Theme.of(context);
    return ProfileSection(
      title: Strings.profileBadgesTitle,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.7,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
        ),
        itemCount: badgeDefinitions.length,
        itemBuilder: (context, index) {
          final badge = badgeDefinitions[index];
          final has = earned.contains(badge.id);
          return DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(badge.title, style: theme.textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    has ? badge.description : Strings.profileBadgeLocked,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
