import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/recurrence/recurrence_text.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/features/clock/data/event_repository.dart';
import 'package:altidial/features/clock/providers.dart';
import 'package:altidial/features/clock/widgets/delete_event.dart';
import 'package:altidial/features/clock/widgets/event_sheet.dart';
import 'package:altidial/features/clock/widgets/start_session.dart';
import 'package:altidial/shared/widgets/app_button.dart';
import 'package:altidial/shared/widgets/tone_chip.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EventDetailSheet extends ConsumerWidget {
  const EventDetailSheet({
    required this.event,
    required this.readOnly,
    super.key,
  });

  final CalendarEvent event;
  final bool readOnly;

  static Future<void> show(
    BuildContext context, {
    required CalendarEvent event,
    required bool readOnly,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => EventDetailSheet(event: event, readOnly: readOnly),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final deleted = await confirmAndDeleteEvent(context, ref, event);
    if (deleted && context.mounted) Navigator.of(context).pop();
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final started = await startSessionForEvent(context, ref, event);
    if (started) navigator.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final canStart =
        !readOnly && canStartSession(event, ref.watch(clockProvider));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xs,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ToneChip(tone: event.tone),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(event.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            formatMinuteRange(event.startMinute, event.endMinute),
            style: theme.textTheme.bodyLarge,
          ),
          Text(
            formatDurationMinutes(event.range.durationMinutes),
            style: theme.textTheme.bodySmall,
          ),
          if (event.seriesId != null) _RepeatLine(seriesId: event.seriesId!),
          if (event.status == EventStatus.completed) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  CupertinoIcons.checkmark_circle_fill,
                  size: 16,
                  color: colors.muted,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(Strings.eventCompleted, style: theme.textTheme.bodySmall),
              ],
            ),
          ],
          if (!readOnly) ...[
            const SizedBox(height: AppSpacing.xxl),
            if (canStart) ...[
              AppButton(
                key: const ValueKey('detail-start-session'),
                label: Strings.sessionStart,
                onPressed: () => _start(context, ref),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            AppButton(
              label: Strings.edit,
              variant: AppButtonVariant.secondary,
              onPressed: () {
                final navigator = Navigator.of(context);
                final target = event;
                navigator.pop();
                EventSheet.show(
                  navigator.context,
                  day: target.date,
                  initialRange: target.range,
                  existing: target,
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: Strings.delete,
              variant: AppButtonVariant.destructive,
              onPressed: () => _delete(context, ref),
            ),
          ],
        ],
      ),
    );
  }
}

/// How the event's series repeats, on one line with the repeat icon. Draws
/// nothing until the rule has loaded, or if the series is gone.
class _RepeatLine extends ConsumerWidget {
  const _RepeatLine({required this.seriesId});

  final int seriesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rule = ref.watch(seriesRuleProvider(seriesId)).valueOrNull;
    if (rule == null || !rule.repeats) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Icon(CupertinoIcons.repeat, size: 16, color: context.appColors.muted),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              describeRecurrence(rule),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
