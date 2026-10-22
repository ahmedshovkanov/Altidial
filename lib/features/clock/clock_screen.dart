import 'dart:async';

import 'package:altidial/app/navigation/tab_bar_inset.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/features/clock/clock_layout.dart';
import 'package:altidial/features/clock/data/event_repository.dart';
import 'package:altidial/features/clock/providers.dart';
import 'package:altidial/features/clock/widgets/clock_header.dart';
import 'package:altidial/features/clock/widgets/day_load_bar.dart';
import 'package:altidial/features/clock/widgets/delete_event.dart';
import 'package:altidial/features/clock/widgets/dial_view.dart';
import 'package:altidial/features/clock/widgets/event_detail_sheet.dart';
import 'package:altidial/features/clock/widgets/event_sheet.dart';
import 'package:altidial/features/clock/widgets/now_card.dart';
import 'package:altidial/features/coach/widgets/coach_card.dart';
import 'package:altidial/features/clock/widgets/reuse_actions.dart';
import 'package:altidial/features/clock/widgets/reuse_row.dart';
import 'package:altidial/features/clock/widgets/start_session.dart';
import 'package:altidial/features/clock/widgets/template_picker_sheet.dart';
import 'package:altidial/features/clock/widgets/todays_plan_list.dart';
import 'package:altidial/features/clock/widgets/week_strip.dart';
import 'package:altidial/shared/layout/content_width.dart';
import 'package:altidial/shared/layout/window_class.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The largest outer radius the dial gets on a wide window.
const double _wideDialMaxRadius = 340;

/// The Clock tab. Narrow and medium windows stack everything in one
/// non-scrolling column (a medium window centres it at 560 pt). A wide window
/// uses two panes: the dial on the left; the header, week strip, Now card,
/// day-load bar and Today's plan list on the right.
class ClockScreen extends ConsumerWidget {
  const ClockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDateProvider);
    final now = ref.watch(clockProvider);
    final events = ref.watch(dayEventsProvider);
    final readOnly = isPastDay(selected, now: now);
    final inset = TabBarInset.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final windowClass = context.windowClass;
    final hasEvents = events.valueOrNull?.isNotEmpty ?? false;
    // An empty day that can still be edited: the reuse tools fill it.
    final canFill = !readOnly && events.hasValue && !hasEvents;
    final yesterdayHasEvents =
        ref.watch(previousDayEventsProvider).valueOrNull?.isNotEmpty ?? false;

    void openCreate(MinuteRange range) =>
        EventSheet.show(context, day: selected, initialRange: range);

    void openDetail(CalendarEvent event) =>
        EventDetailSheet.show(context, event: event, readOnly: readOnly);

    void startSession(CalendarEvent event) =>
        unawaited(startSessionForEvent(context, ref, event));

    void openEdit(CalendarEvent event) => EventSheet.show(
      context,
      day: event.date,
      initialRange: event.range,
      existing: event,
    );

    // The two ways to fill an empty day; null when they do not apply.
    final VoidCallback? copyYesterday = canFill && yesterdayHasEvents
        ? () => unawaited(copyPreviousDay(context, ref, selected))
        : null;
    final VoidCallback? applyTemplate = canFill
        ? () => unawaited(TemplatePickerSheet.show(context, day: selected))
        : null;

    Widget header({bool showDate = true}) => ClockHeader(
      showDate: showDate,
      onAdd: () => openCreate(const MinuteRange(540, 600)),
      onSaveTemplate: hasEvents
          ? () => unawaited(saveDayAsTemplate(context, ref, selected))
          : null,
      onCopyYesterday: copyYesterday,
      onApplyTemplate: applyTemplate,
    );

    final Widget? reuse = applyTemplate == null
        ? null
        : ReuseRow(
            onCopyYesterday: copyYesterday,
            onApplyTemplate: applyTemplate,
          );

    Widget dialArea({double? maxRadius}) => events.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => const Center(child: Text(Strings.loadFailed)),
      data: (dayEvents) => DialView(
        events: dayEvents,
        day: selected,
        readOnly: readOnly,
        maxRadius: maxRadius,
        onCreateRequested: openCreate,
        onEventTapped: openDetail,
        onEditRequested: openEdit,
        onDeleteRequested: (event) =>
            confirmAndDeleteEvent(context, ref, event),
        onMoveRequested: (event, range) async {
          try {
            await ref
                .read(eventRepositoryProvider)
                .moveEvent(id: event.id, day: selected, range: range);
          } on RingOverflowException {
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text(Strings.ringOverflow)));
          }
        },
      ),
    );

    if (windowClass == WindowClass.wide) {
      final width = MediaQuery.sizeOf(context).width;
      final paneWidth = (width * 0.36).clamp(340.0, 440.0).toDouble();
      final largeText = textScale > ClockLayoutPlan.largeTextScale;

      return Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.xxl, 0, AppSpacing.xxl, inset),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: dialArea(maxRadius: _wideDialMaxRadius)),
            const SizedBox(width: AppSpacing.xxl),
            SizedBox(
              width: paneWidth,
              child: Column(
                children: [
                  header(),
                  WeekStrip(showDots: !largeText),
                  const SizedBox(height: ClockLayoutPlan.gap),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const CoachCard(),
                        const SizedBox(height: AppSpacing.sm),
                        NowCard(
                          compact: largeText,
                          onOpenEvent: openDetail,
                          onStartSession: startSession,
                        ),
                      ],
                    ),
                  ),
                  if (hasEvents && !largeText) ...[
                    const SizedBox(height: ClockLayoutPlan.gap),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: DayLoadBar(),
                    ),
                  ],
                  if (reuse != null && !largeText) ...[
                    const SizedBox(height: ClockLayoutPlan.gap),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: reuse,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: TodaysPlanList(onOpenEvent: openDetail),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ContentWidth(
      maxWidth: windowClass == WindowClass.narrow
          ? double.infinity
          : ContentWidths.column,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final plan = ClockLayoutPlan.forHeight(
            constraints.maxHeight - inset,
            textScale: textScale,
            hasDayLoad: hasEvents,
            hasReuseTools: applyTemplate != null,
          );

          return Padding(
            padding: EdgeInsets.only(bottom: inset),
            child: Column(
              children: [
                header(showDate: plan.showHeaderDate),
                WeekStrip(showDots: plan.showWeekDots),
                const SizedBox(height: ClockLayoutPlan.gap),
                Expanded(child: dialArea()),
                const SizedBox(height: ClockLayoutPlan.gap),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CoachCard(),
                      const SizedBox(height: AppSpacing.sm),
                      NowCard(
                        compact: plan.compactNowCard,
                        onOpenEvent: openDetail,
                        onStartSession: startSession,
                      ),
                    ],
                  ),
                ),
                if (plan.showDayLoad) ...[
                  const SizedBox(height: ClockLayoutPlan.gap),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: DayLoadBar(),
                  ),
                ],
                if (plan.showReuseTools && reuse != null) ...[
                  const SizedBox(height: ClockLayoutPlan.gap),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: reuse,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
