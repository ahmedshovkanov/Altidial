import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/reflections/providers.dart';
import 'package:energy_clock/features/reflections/widgets/reflection_row.dart';
import 'package:energy_clock/features/session/widgets/debrief_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReflectionsScreen extends ConsumerWidget {
  const ReflectionsScreen({super.key});

  /// Calendar-day difference between [date] and [now], DST-safe: both dates are
  /// built as UTC so a 23-hour or 25-hour local day cannot round the count the
  /// wrong way. Local midnights differenced directly would report yesterday's
  /// sessions as "Today" on the spring-forward day.
  int _daysAgo(DateTime date, DateTime now) {
    final a = DateTime.utc(now.year, now.month, now.day);
    final b = DateTime.utc(date.year, date.month, date.day);
    return a.difference(b).inDays;
  }

  String _groupOf(DateTime date, DateTime now) {
    final diff = _daysAgo(date, now);
    if (diff <= 0) return Strings.reflectionsToday;
    if (diff < 7) return Strings.reflectionsWeek;
    return Strings.reflectionsEarlier;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = ref.watch(reflectionsTimelineProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.reflectionsTitle)),
      body: timeline.when(
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(Strings.reflectionsEmptyTitle, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(Strings.reflectionsEmptyHint, textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }
          final now = DateTime.now();
          // Section headers must be a pure function of the index: ListView
          // builders are lazy, so a `lastGroup` local would be reset by
          // scrolling and rows would lose or repeat their header.
          final groups = [
            for (final row in rows) _groupOf(row.eventDate, now),
          ];
          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final item = rows[i];
              final group = groups[i];
              final showHeader = i == 0 || group != groups[i - 1];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showHeader)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                      child: Text(group, style: Theme.of(context).textTheme.labelLarge),
                    ),
                  ReflectionRowTile(
                    item: item,
                    onTap: () async {
                      final minutes = (item.session.activeSeconds / 60).round().clamp(1, 100000);
                      final saved = await showDebriefSheet(
                        context,
                        ref,
                        sessionId: item.session.id,
                        eventTitle: item.eventTitle,
                        activeMinutes: minutes,
                        // Reopening a reflection must edit it, not replace it
                        // with an empty one.
                        initialEnergy: item.session.energyRating,
                        initialFocus: item.session.focusRating,
                        initialTags: item.session.tags,
                        initialNote: item.session.note,
                      );
                      if (saved && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text(Strings.debriefSaved)),
                        );
                      }
                    },
                  ),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(Strings.reflectionsLoadError, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  onPressed: () => ref.invalidate(reflectionsTimelineProvider),
                  child: const Text(Strings.patternsRetry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}