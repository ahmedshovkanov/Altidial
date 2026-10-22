import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/app/theme/tone_colors.dart';
import 'package:altidial/core/progress/badges.dart';
import 'package:altidial/core/roundup/iso_week.dart';
import 'package:altidial/core/roundup/roundup_payload.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/repositories/roundup_repository.dart';
import 'package:altidial/features/progress/providers.dart';
import 'package:altidial/features/progress/widgets/profile_section.dart';
import 'package:altidial/shared/charts/donut_painter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The archived weeks, newest first; tapping one opens its frozen snapshot
/// inline.
class RoundupArchive extends ConsumerStatefulWidget {
  const RoundupArchive({required this.summaries, super.key});

  final List<RoundupSummary> summaries;

  @override
  ConsumerState<RoundupArchive> createState() => _RoundupArchiveState();
}

class _RoundupArchiveState extends ConsumerState<RoundupArchive> {
  ({int year, int week})? _open;

  @override
  Widget build(BuildContext context) {
    return ProfileSection(
      title: Strings.profileArchiveTitle,
      empty: widget.summaries.isEmpty,
      emptyMessage: Strings.profileEmptyArchive,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final summary in widget.summaries) ...[
            _Row(
              summary: summary,
              open: _open == (year: summary.isoYear, week: summary.isoWeek),
              onTap: () {
                final key = (year: summary.isoYear, week: summary.isoWeek);
                setState(() => _open = _open == key ? null : key);
              },
            ),
            if (_open == (year: summary.isoYear, week: summary.isoWeek))
              _SnapshotCard(summary: summary),
          ],
        ],
      ),
    );
  }
}

String _rangeLabel(DateTime start) {
  final end = DateTime(start.year, start.month, start.day + 6);
  final endText = DateFormat('d MMM y').format(end);
  if (start.year == end.year && start.month == end.month) {
    return "${DateFormat('d').format(start)} – $endText";
  }
  if (start.year == end.year) {
    return "${DateFormat('d MMM').format(start)} – $endText";
  }
  return "${DateFormat('d MMM y').format(start)} – $endText";
}

class _Row extends StatelessWidget {
  const _Row({required this.summary, required this.open, required this.onTap});

  final RoundupSummary summary;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.control),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Strings.roundupWeek(summary.isoWeek),
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    _rangeLabel(isoWeekStart(summary.isoYear, summary.isoWeek)),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(
              open ? CupertinoIcons.chevron_down : CupertinoIcons.chevron_right,
            ),
          ],
        ),
      ),
    );
  }
}

class _SnapshotCard extends ConsumerWidget {
  const _SnapshotCard({required this.summary});

  final RoundupSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payload = ref.watch(
      roundupPayloadProvider((year: summary.isoYear, week: summary.isoWeek)),
    );
    return payload.when(
      data: (roundup) => roundup == null
          ? Text(
              Strings.roundupUnavailable,
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : _SnapshotBody(roundup: roundup),
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: CircularProgressIndicator.adaptive(),
        ),
      ),
      error: (error, stack) => Text(
        Strings.roundupUnavailable,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _SnapshotBody extends StatelessWidget {
  const _SnapshotBody({required this.roundup});

  final RoundupPayload roundup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toneColors = context.toneColors;
    final adherence = roundup.adherencePercent;
    final badgeTitles = {
      for (final badge in badgeDefinitions) badge.id: badge.title,
    };
    final badgeNames = [
      for (final id in roundup.badgesUnlocked) badgeTitles[id] ?? id,
    ];

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (roundup.totalMinutes > 0)
            SizedBox(
              height: 120,
              child: CustomPaint(
                painter: DonutPainter(
                  segments: [
                    (tone: Tone.focus, minutes: roundup.focusMinutes),
                    (tone: Tone.life, minutes: roundup.lifeMinutes),
                    (tone: Tone.inbox, minutes: roundup.inboxMinutes),
                  ],
                  colors: {
                    for (final tone in Tone.values)
                      tone: toneColors.fillFor(tone),
                  },
                  trackColor: theme.dividerColor,
                ),
              ),
            ),
          row(
            Strings.statsPlannedActual,
            adherence == null
                ? Strings.roundupNothingPlanned
                : Strings.statsAdherence(adherence),
          ),
          row(
            Strings.statsTotalFocus,
            formatDurationMinutes(roundup.totalMinutes),
          ),
          if (roundup.bestFocusDay != null)
            row(
              Strings.statsFocusDepth,
              Strings.roundupBestFocusDay(
                DateFormat('EEE d MMM').format(roundup.bestFocusDay!),
                formatDurationMinutes(roundup.bestFocusMinutes),
              ),
            ),
          row(
            Strings.profileStreakLabel,
            Strings.profileStreak(roundup.currentStreak),
          ),
          if (badgeNames.isNotEmpty)
            row(Strings.profileBadgesTitle, Strings.joinWords(badgeNames)),
          row(Strings.profileXpLabel, Strings.roundupXp(roundup.xpEarned)),
          if (roundup.previousAdherencePercent != null)
            Text(
              Strings.roundupPreviousAdherence(
                roundup.previousAdherencePercent!,
              ),
              style: theme.textTheme.bodyMedium,
            ),
        ],
      ),
    );
  }
}
