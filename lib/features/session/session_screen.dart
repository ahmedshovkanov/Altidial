import 'dart:async';
import 'dart:math' as math;

import 'package:altidial/app/navigation/tab_bar_inset.dart';
import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/app_typography.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/app/theme/tone_colors.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/data/repositories/session_repository.dart';
import 'package:altidial/features/session/model/session_display.dart';
import 'package:altidial/features/session/providers.dart';
import 'package:altidial/features/session/session_alerts.dart';
import 'package:altidial/features/session/session_layout.dart';
import 'package:altidial/features/session/widgets/alerts_banner.dart';
import 'package:altidial/features/session/widgets/countdown_ring.dart';
import 'package:altidial/features/session/widgets/debrief_sheet.dart';
import 'package:altidial/features/session/widgets/recovery_card.dart';
import 'package:altidial/features/session/widgets/session_controls.dart';
import 'package:altidial/shared/layout/content_width.dart';
import 'package:altidial/shared/layout/window_class.dart';
import 'package:altidial/shared/widgets/adaptive_dialog.dart';
import 'package:altidial/shared/widgets/tone_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The session view (spec §6.1): the running event's title and tone, a big
/// countdown ring, and the controls. It takes the Clock tab's place while a
/// session runs. Everything it shows is worked out from the clock, so it is
/// right the moment the app comes back to the foreground.
class SessionScreen extends ConsumerWidget {
  const SessionScreen({required this.session, super.key});

  final RunningSession session;

  SessionRepository _repository(WidgetRef ref) =>
      ref.read(sessionRepositoryProvider);

  /// Advances scores, streaks, XP and badges after a session ends. A failure
  /// here must never break ending the session: the session writes already
  /// committed, and the caches self-heal on the next `ensureFresh()`.
  Future<void> _advanceProgress(WidgetRef ref) async {
    try {
      await ref
          .read(progressRepositoryProvider)
          .onSessionEnded(session.eventDate);
    } on Object catch (error) {
      debugPrint('Altidial: progress update failed: $error');
    }
  }

  void _announceLogged(ScaffoldMessengerState messenger, SessionRecord done) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          Strings.sessionLogged(
            session.eventTitle,
            formatDurationMinutes(
              math.max(1, (done.activeSeconds / 60).round()),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pauseOrResume(WidgetRef ref, SessionDisplay display) {
    unawaited(HapticFeedback.selectionClick());
    final repository = _repository(ref);
    return display.isPaused
        ? repository.resume(session.id)
        : repository.pause(session.id);
  }

  Future<void> _extend(WidgetRef ref, int seconds) {
    unawaited(HapticFeedback.selectionClick());
    return _repository(ref).extend(session.id, seconds: seconds);
  }

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    unawaited(HapticFeedback.mediumImpact());
    final done = await _repository(ref).finish(session.id);
    await _advanceProgress(ref);
    if (done != null) _announceLogged(messenger, done);
    if (done != null && context.mounted) {
      final minutes = (done.activeSeconds / 60).round().clamp(1, 100000);
      await showDebriefSheet(context, ref, sessionId: done.id, eventTitle: session.eventTitle, activeMinutes: minutes);
    }
  }

  Future<void> _abandon(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: Strings.sessionAbandonTitle,
      body: Strings.sessionAbandonBody,
      confirmLabel: Strings.sessionAbandon,
      cancelLabel: Strings.sessionKeepGoing,
    );
    if (!confirmed) return;
    final done = await _repository(ref).abandon(session.id);
    await _advanceProgress(ref);
    messenger.showSnackBar(
      const SnackBar(content: Text(Strings.sessionAbandoned)),
    );
    if (done != null && context.mounted) {
      final minutes = (done.activeSeconds / 60).round().clamp(1, 100000);
      await showDebriefSheet(context, ref, sessionId: done.id, eventTitle: session.eventTitle, activeMinutes: minutes);
    }
  }

  Future<void> _closeOut(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final done = await _repository(ref).closeOut(session.id);
    ref.read(sessionRecoveryProvider.notifier).resolve();
    await _advanceProgress(ref);
    if (done != null) _announceLogged(messenger, done);
    if (done != null && context.mounted) {
      final minutes = (done.activeSeconds / 60).round().clamp(1, 100000);
      await showDebriefSheet(context, ref, sessionId: done.id, eventTitle: session.eventTitle, activeMinutes: minutes);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(sessionNowProvider);
    final display = SessionDisplay.of(session, now);
    final recovering =
        ref.watch(sessionRecoveryProvider).valueOrNull == session.id;
    final bannerVisible =
        ref.watch(notificationBannerVisibleProvider).valueOrNull ?? false;

    // One firm tap when the planned time runs out while the screen is open.
    ref.listen<DateTime>(sessionNowProvider, (previous, next) {
      if (previous == null) return;
      final was = SessionDisplay.of(session, previous);
      final isNow = SessionDisplay.of(session, next);
      if (!was.isOvertime && isNow.isOvertime && !isNow.isPaused) {
        unawaited(HapticFeedback.heavyImpact());
      }
    });

    final colors = context.appColors;
    final tone = context.toneColors.paletteFor(session.eventTone);
    final theme = Theme.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final inset = TabBarInset.of(context);

    final ringColor = display.isOvertime ? colors.danger : tone.solid;
    final stateLabel = display.isPaused
        ? Strings.sessionPaused
        : display.isOvertime
        ? Strings.sessionOvertime
        : Strings.sessionRemaining;
    final stateColor = display.isOvertime && !display.isPaused
        ? colors.danger
        : colors.muted;
    final semanticsLabel = Strings.sessionRingSemantics(
      session.eventTitle,
      session.eventTone.label,
      display.spokenTime,
      display.isPaused
          ? Strings.sessionStatePaused
          : display.isOvertime
          ? Strings.sessionStateOvertime
          : '',
    );

    final plannedEndMinute =
        display.plannedEnd.hour * 60 + display.plannedEnd.minute;
    final footer = display.isOvertime
        ? '${Strings.sessionPlanned(display.plannedText)} · '
              '${Strings.sessionWasDueAt(formatMinuteOfDay(plannedEndMinute))}'
        : display.isPaused
        ? Strings.sessionPlanned(display.plannedText)
        : '${Strings.sessionPlanned(display.plannedText)} · '
              '${Strings.sessionEndsAt(formatMinuteOfDay(plannedEndMinute))}';

    final header = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ToneChip(tone: session.eventTone),
        const SizedBox(height: AppSpacing.md),
        Text(
          session.eventTitle,
          key: const ValueKey('session-title'),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          formatMinuteRange(session.eventRange.start, session.eventRange.end),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );

    Widget ring(double diameter) {
      final timeSize = diameter * 0.18;
      return CountdownRing(
        key: const ValueKey('session-ring'),
        diameter: diameter,
        fraction: display.isOvertime ? 1 : display.fractionRemaining,
        color: ringColor,
        semanticsLabel: semanticsLabel,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              math.min(1.2, MediaQuery.textScalerOf(context).scale(1)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  display.timeText,
                  key: const ValueKey('session-time'),
                  maxLines: 1,
                  style: AppTypography.sessionTime(timeSize).copyWith(
                    color: display.isOvertime ? colors.danger : colors.ink,
                  ),
                ),
              ),
              Text(
                stateLabel,
                key: const ValueKey('session-state'),
                style: theme.textTheme.labelLarge!.copyWith(color: stateColor),
              ),
            ],
          ),
        ),
      );
    }

    Widget controls(bool stacked) {
      if (recovering) {
        return RecoveryCard(
          title: session.eventTitle,
          elapsed: display.elapsedSeconds < 60
              ? Strings.recoveryUnderAMinute
              : formatDurationMinutes(display.elapsedSeconds ~/ 60),
          onResume: () => ref.read(sessionRecoveryProvider.notifier).resolve(),
          onCloseOut: () => _closeOut(context, ref),
        );
      }
      return SessionControls(
        display: display,
        stacked: stacked,
        onPauseResume: () => _pauseOrResume(ref, display),
        onExtend: (seconds) => _extend(ref, seconds),
        onFinish: () => _finish(context, ref),
        onAbandon: () => _abandon(context, ref),
      );
    }

    final banner = bannerVisible
        ? AlertsBanner(
            onOpenSettings: () {
              unawaited(ref.read(notificationServiceProvider).openSettings());
              unawaited(dismissNotificationBanner(ref));
            },
            onDismiss: () => unawaited(dismissNotificationBanner(ref)),
          )
        : null;

    final footerText = Text(
      footer,
      key: const ValueKey('session-footer'),
      textAlign: TextAlign.center,
      style: theme.textTheme.labelLarge!.copyWith(color: colors.muted),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final plan = SessionLayoutPlan.forSize(
          constraints.biggest,
          inset: inset,
          textScale: textScale,
          windowClass: context.windowClass,
          bannerVisible: bannerVisible,
          recovering: recovering,
        );

        final Widget content;
        if (plan.wide) {
          content = Row(
            children: [
              Expanded(child: Center(child: ring(plan.ringDiameter))),
              const SizedBox(width: AppSpacing.xxl),
              SizedBox(
                width: (constraints.maxWidth * 0.36).clamp(340.0, 440.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (banner != null) ...[
                      banner,
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    header,
                    const SizedBox(height: AppSpacing.lg),
                    footerText,
                    const SizedBox(height: AppSpacing.lg),
                    controls(plan.stackedControls),
                  ],
                ),
              ),
            ],
          );
        } else {
          content = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (banner != null) ...[
                banner,
                const SizedBox(height: AppSpacing.lg),
              ],
              header,
              const SizedBox(height: AppSpacing.lg),
              Center(child: ring(plan.ringDiameter)),
              const SizedBox(height: AppSpacing.lg),
              footerText,
              const SizedBox(height: AppSpacing.lg),
              controls(plan.stackedControls),
            ],
          );
        }

        final padding = EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.lg,
          AppSpacing.xxl,
          inset,
        );
        final body = SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - padding.vertical,
            ),
            child: Center(child: content),
          ),
        );
        return plan.wide
            ? body
            : ContentWidth(maxWidth: ContentWidths.column, child: body);
      },
    );
  }
}
