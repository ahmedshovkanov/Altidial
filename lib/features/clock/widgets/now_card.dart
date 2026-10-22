import 'dart:math' as math;

import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/app/theme/tone_colors.dart';
import 'package:altidial/core/flight/flight_details.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/features/clock/model/calendar_event.dart';
import 'package:altidial/features/clock/model/now_status.dart';
import 'package:altidial/features/clock/providers.dart';
import 'package:altidial/features/clock/widgets/start_session.dart';
import 'package:altidial/shared/widgets/app_card.dart';
import 'package:altidial/shared/widgets/press_scale.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The card under the dial. A running event fills it with the tone's colour;
/// otherwise it is neutral and says what is next, invites you to plan, or
/// summarises another day. Tapping opens the running or next event.
class NowCard extends ConsumerWidget {
  const NowCard({
    required this.onOpenEvent,
    this.onStartSession,
    this.compact = false,
    super.key,
  });

  /// Height at normal text size.
  static const double height = 96;

  /// The height to budget for the full card at [textScale]. Its four lines of
  /// text (caption, title, time left, progress bar) outgrow [height] as soon as
  /// text is larger than normal: about 98 pt at 115% and 107 pt at 130%.
  static double heightFor(double textScale) =>
      math.max(height, 36 + 56 * textScale);

  /// The height to budget for the one-row variant at [textScale].
  static double compactHeightFor(double textScale) => 24 + 28 * textScale;

  final void Function(CalendarEvent event) onOpenEvent;

  /// Called when Start is pressed on the running or next event. Null leaves
  /// the Start button out. The one-row variant never has it: the card opens the
  /// detail sheet, which does.
  final void Function(CalendarEvent event)? onStartSession;

  /// One row: the title and, for a running or next event, a short time. Used
  /// on short screens and at large text sizes.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDateProvider);
    final now = ref.watch(clockProvider);
    final events =
        ref.watch(dayEventsProvider).valueOrNull ?? const <CalendarEvent>[];
    final status = computeNowStatus(
      events: events,
      selectedDay: selected,
      now: now,
    );
    final view = _describe(context, status, selected);
    final theme = Theme.of(context);
    final colors = context.appColors;

    final primary = view.foreground ?? colors.ink;
    final secondary = view.foreground ?? colors.muted;

    final body = compact
        ? Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      view.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall!.copyWith(
                        color: primary,
                      ),
                    ),
                    if (view.event?.isFlight == true)
                      Text(
                        flightSubtitle(
                          flightNumber: view.event!.flightNumber,
                          fromCode: view.event!.fromCode,
                          toCode: view.event!.toCode,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: secondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (view.compactDetail != null) ...[
                const SizedBox(width: AppSpacing.md),
                Text(
                  view.compactDetail!,
                  style: theme.textTheme.labelLarge!.copyWith(color: secondary),
                ),
              ],
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (view.caption != null)
                Text(
                  view.caption!,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color:
                        view.foreground?.withValues(alpha: 0.85) ??
                        colors.muted,
                  ),
                ),
              Text(
                view.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium!.copyWith(color: primary),
              ),
              if (view.event?.isFlight == true)
                Text(
                  flightSubtitle(
                    flightNumber: view.event!.flightNumber,
                    fromCode: view.event!.fromCode,
                    toCode: view.event!.toCode,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall!.copyWith(color: secondary),
                ),
              if (view.detail != null)
                Text(
                  view.detail!,
                  style: theme.textTheme.labelLarge!.copyWith(
                    color: view.foreground ?? colors.muted,
                  ),
                ),
              if (view.progress != null) ...[
                const SizedBox(height: 6),
                _ProgressBar(progress: view.progress!, color: primary),
              ],
            ],
          );

    final event = view.event;
    final canStart =
        !compact &&
        event != null &&
        onStartSession != null &&
        canStartSession(event, now);
    final isDone =
        !compact && event != null && event.status == EventStatus.completed;

    final Widget? trailing = canStart
        ? _StartButton(
            fill: view.foreground ?? colors.ink,
            foreground: view.fill ?? colors.onInk,
            onTap: () => onStartSession!(event),
          )
        : isDone
        ? _DoneLabel(color: primary)
        : null;

    final card = AppCard(
      color: view.fill,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      onTap: event == null ? null : () => onOpenEvent(event),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: compact ? 0 : height - 24),
        child: Align(
          alignment: Alignment.centerLeft,
          child: trailing == null
              ? body
              : Row(
                  children: [
                    Expanded(child: body),
                    const SizedBox(width: AppSpacing.md),
                    trailing,
                  ],
                ),
        ),
      ),
    );

    if (view.semanticsLabel == null) return MergeSemantics(child: card);
    return Semantics(
      button: true,
      label: isDone
          ? '${view.semanticsLabel}${Strings.nowCompletedSuffix}'
          : view.semanticsLabel,
      excludeSemantics: true,
      onTap: event == null ? null : () => onOpenEvent(event),
      customSemanticsActions: canStart
          ? {
              const CustomSemanticsAction(label: Strings.sessionStart): () =>
                  onStartSession!(event),
            }
          : null,
      child: card,
    );
  }

  _NowView _describe(
    BuildContext context,
    NowStatus status,
    DateTime selected,
  ) {
    final tones = context.toneColors;
    return switch (status) {
      NowActive(
        :final event,
        :final minutesLeft,
        :final progress,
        :final overlappingCount,
      ) =>
        _NowView(
          fill: tones.fillFor(event.tone),
          foreground: tones.labelFor(event.tone),
          caption: overlappingCount > 0
              ? '${event.tone.label} · ${Strings.nowOverlapping(overlappingCount)}'
              : event.tone.label,
          title: event.title,
          detail:
              '${Strings.nowTimeLeft(formatDurationMinutes(minutesLeft))} · '
              '${Strings.nowUntil(formatMinuteOfDay(event.endMinute))}',
          compactDetail: Strings.nowTimeLeft(
            formatDurationMinutes(minutesLeft),
          ),
          progress: progress,
          event: event,
          semanticsLabel: Strings.nowSemantics(
            event.title,
            event.tone.label,
            spokenDurationMinutes(minutesLeft),
          ),
        ),
      NowNext(:final event, :final minutesUntil) => _NowView(
        caption: Strings.nowNextUp,
        title: event.title,
        detail: Strings.nowStartsAt(
          formatMinuteOfDay(event.startMinute),
          formatDurationMinutes(minutesUntil),
        ),
        compactDetail: formatDurationMinutes(minutesUntil),
        event: event,
        semanticsLabel: Strings.nextSemantics(
          event.title,
          event.tone.label,
          spokenDurationMinutes(minutesUntil),
        ),
      ),
      NowFree() => const _NowView(
        title: Strings.emptyDayTitle,
        detail: Strings.emptyDayHint,
      ),
      NowDone(:final eventCount, :final plannedMinutes) => _NowView(
        title: Strings.nowDoneTitle,
        detail: Strings.plannedSummary(
          eventCount,
          formatDurationMinutes(plannedMinutes),
        ),
      ),
      DaySummary(:final eventCount, :final plannedMinutes, :final isPast) =>
        isPast
            ? _NowView(
                caption: Strings.readOnlyChip,
                title: eventCount == 0
                    ? Strings.pastNothingPlanned
                    : Strings.pastSummary(
                        eventCount,
                        formatDurationMinutes(plannedMinutes),
                      ),
              )
            : _NowView(
                title: Strings.dayCountTitle(
                  DateFormat('EEEE').format(selected),
                  eventCount,
                ),
                detail: Strings.plannedDuration(
                  formatDurationMinutes(plannedMinutes),
                ),
              ),
    };
  }
}

/// Everything the card needs to draw one state.
class _NowView {
  const _NowView({
    required this.title,
    this.caption,
    this.detail,
    this.compactDetail,
    this.fill,
    this.foreground,
    this.progress,
    this.event,
    this.semanticsLabel,
  });

  final String title;
  final String? caption;
  final String? detail;

  /// The short text beside the title in the one-row variant.
  final String? compactDetail;

  /// Null keeps the card neutral.
  final Color? fill;
  final Color? foreground;
  final double? progress;

  /// The event a tap opens, if any.
  final CalendarEvent? event;
  final String? semanticsLabel;
}

/// The pill on the card that starts a session. At least 44 pt tall.
class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.fill,
    required this.foreground,
    required this.onTap,
  });

  final Color fill;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.play_fill, size: 14, color: foreground),
                const SizedBox(width: 6),
                Text(
                  Strings.sessionStartShort,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge!.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stands where Start would, for an event whose session is finished.
class _DoneLabel extends StatelessWidget {
  const _DoneLabel({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(CupertinoIcons.checkmark_circle_fill, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          Strings.sessionDone,
          style: Theme.of(context).textTheme.labelLarge!.copyWith(color: color),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: SizedBox(
        height: 4,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: color.withValues(alpha: 0.25)),
            ),
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
