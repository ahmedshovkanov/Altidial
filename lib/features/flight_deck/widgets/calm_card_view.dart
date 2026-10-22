// lib/features/flight_deck/widgets/calm_card_view.dart
import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/features/flight_deck/calm_content.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum CalmFilter { all, facts, tips, saved }

/// One fact or tip with a star toggle. Colours come from theme tokens only.
class CalmCardView extends StatelessWidget {
  const CalmCardView({
    required this.card,
    required this.starred,
    required this.onStar,
    super.key,
  });

  final CalmCard card;
  final bool starred;
  final VoidCallback onStar;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Card(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    card.body,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: colors.muted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey('deck-star'),
              icon: Icon(
                starred ? CupertinoIcons.star_fill : CupertinoIcons.star,
                color: starred ? colors.ink : colors.muted,
              ),
              tooltip: starred ? Strings.deckStarRemove : Strings.deckStarAdd,
              onPressed: onStar,
            ),
          ],
        ),
      ),
    );
  }
}

/// Filter chips above the card list.
class CalmFilterChips extends StatelessWidget {
  const CalmFilterChips({
    required this.filter,
    required this.onChanged,
    super.key,
  });

  final CalmFilter filter;
  final ValueChanged<CalmFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    String label(CalmFilter f) => switch (f) {
      CalmFilter.all => Strings.deckAll,
      CalmFilter.facts => Strings.deckFacts,
      CalmFilter.tips => Strings.deckTips,
      CalmFilter.saved => Strings.deckSaved,
    };
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final f in CalmFilter.values)
          ChoiceChip(
            label: Text(label(f)),
            selected: f == filter,
            onSelected: (_) => onChanged(f),
          ),
      ],
    );
  }
}
