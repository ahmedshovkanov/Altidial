// lib/features/flight_deck/flight_deck_screen.dart
import 'package:altidial/app/navigation/tab_bar_inset.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/features/flight_deck/calm_content.dart';
import 'package:altidial/features/flight_deck/providers.dart';
import 'package:altidial/features/flight_deck/widgets/breathing_launcher.dart';
import 'package:altidial/features/flight_deck/widgets/calm_card_view.dart';
import 'package:altidial/features/flight_deck/widgets/flights_list.dart';
import 'package:altidial/features/flight_deck/widgets/grounding_steps.dart';
import 'package:altidial/features/flight_deck/widgets/next_flight_hero.dart';
import 'package:altidial/shared/layout/content_width.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Flight Deck tab: flights hub on top, calm kit below.
class FlightDeckScreen extends ConsumerStatefulWidget {
  const FlightDeckScreen({required this.onOpenDay, super.key});

  final ValueChanged<DateTime> onOpenDay;

  @override
  ConsumerState<FlightDeckScreen> createState() => _FlightDeckScreenState();
}

class _FlightDeckScreenState extends ConsumerState<FlightDeckScreen> {
  CalmFilter _filter = CalmFilter.all;

  @override
  Widget build(BuildContext context) {
    final flights = ref.watch(deckFlightsProvider);
    return flights.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      skipError: true,
      data: (_) => _DeckBody(
        onOpenDay: widget.onOpenDay,
        filter: _filter,
        onFilter: (f) => setState(() => _filter = f),
      ),
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(Strings.deckFlightsLoadError,
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => ref.invalidate(deckFlightsProvider),
                child: const Text(Strings.deckRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeckBody extends ConsumerWidget {
  const _DeckBody({
    required this.onOpenDay,
    required this.filter,
    required this.onFilter,
  });

  final ValueChanged<DateTime> onOpenDay;
  final CalmFilter filter;
  final ValueChanged<CalmFilter> onFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final split = ref.watch(deckFlightsProvider).valueOrNull;
    if (split == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    final now = ref.watch(deckNowProvider);
    final favorites =
        ref.watch(flightDeckFavoritesProvider).valueOrNull ?? {};
    final bottomInset = TabBarInset.of(context);

    final List<CalmCard> filtered = switch (filter) {
      CalmFilter.all => calmCards,
      CalmFilter.facts => [
        for (final card in calmCards)
          if (card.kind == CalmKind.fact) card,
      ],
      CalmFilter.tips => [
        for (final card in calmCards)
          if (card.kind == CalmKind.tip) card,
      ],
      CalmFilter.saved => [
        for (final card in calmCards)
          if (favorites.contains(card.id)) card,
      ],
    };

    Widget gap() => const SizedBox(height: AppSpacing.lg);
    final next = split.next;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        bottomInset + AppSpacing.xl,
      ),
      child: ContentWidth(
        maxWidth: ContentWidths.stats,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BreathingLauncher(),
            gap(),
            if (next != null) ...[
              NextFlightHero(
                flight: next,
                now: now,
                onOpen: () => onOpenDay(next.date),
              ),
              gap(),
            ],
            FlightsList(split: split, onOpenDay: onOpenDay),
            gap(),
            Text(Strings.deckCalmTitle,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            CalmFilterChips(filter: filter, onChanged: onFilter),
            const SizedBox(height: AppSpacing.sm),
            if (filtered.isEmpty && filter == CalmFilter.saved) ...[
              Text(Strings.deckSavedEmptyTitle,
                  style: Theme.of(context).textTheme.titleSmall),
              Text(Strings.deckSavedEmptyHint,
                  style: Theme.of(context).textTheme.bodyMedium),
            ] else ...[
              for (final card in filtered)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: CalmCardView(
                    card: card,
                    starred: favorites.contains(card.id),
                    onStar: () => ref
                        .read(flightDeckFavoritesProvider.notifier)
                        .toggle(card.id),
                  ),
                ),
            ],
            gap(),
            const GroundingSteps(),
          ],
        ),
      ),
    );
  }
}
