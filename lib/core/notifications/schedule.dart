import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';

/// One planned event the scheduler knows about. `startsAt` is an absolute
/// instant; callers exclude deleted occurrences.
typedef ScheduledEvent = ({
  int id,
  DateTime startsAt,
  String title,
  Tone tone,
});

/// One active project the scheduler knows about: a deadline is required, and
/// null-deadline or non-active projects are simply not passed in.
typedef ScheduledProject = ({int id, DateTime deadline});

/// One pending notification the app wants: a stable id so rescheduling
/// replaces, and an absolute instant.
typedef DesiredNotification = ({int id, DateTime at, String title, String body});

/// Minutes before an event's start its reminder fires. Fixed (Step 5
/// decision); a parameter would be YAGNI.
const int eventLeadMinutes = 10;

/// At most this many event reminders stay pending: iOS keeps only 64 per app
/// and the other three types (project deadlines, empty mornings, the roundup)
/// need headroom.
const int maxEventReminders = 32;

/// At most this many project deadline reminders stay pending. The soonest
/// deadlines win; the cap keeps a large backlog of projects from crowding out
/// events, mornings, or the roundup within the same 64-pending budget.
const int maxProjectReminders = 16;

/// The one roundup id. There is only ever one upcoming Sunday.
const int roundupNotificationId = 30001;

/// `10000 + eventId`. Stable while the event exists.
int eventReminderId(int eventId) => 10000 + eventId;

/// `20000 + yyyymmdd` of the morning it wakes. Fits an int with room.
int morningReminderId(DateTime day) =>
    20000 + day.year * 10000 + day.month * 100 + day.day;

/// `40000 + projectId`. Stable while the project stays active with a deadline.
int projectDeadlineReminderId(int projectId) => 40000 + projectId;

/// A project deadline reminds at this hour, device-local, the day before.
const int projectDeadlineReminderHour = 9;

/// The absolute instant a project's deadline reminder fires: 09:00
/// device-local the day before [deadline].
DateTime projectDeadlineReminderAt(DateTime deadline) => DateTime(
  deadline.year,
  deadline.month,
  deadline.day - 1,
  projectDeadlineReminderHour,
);

/// The ISO week number of [date]'s week (Thursday rule). Calendar arithmetic —
/// a DST change inside the week cannot move the result.
int isoWeekNumber(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  final thursday = DateTime(
    day.year,
    day.month,
    day.day + (DateTime.thursday - day.weekday),
  );
  final jan4 = DateTime(thursday.year, 1, 4);
  final week1Monday = DateTime(
    jan4.year,
    jan4.month,
    jan4.day - (jan4.weekday - DateTime.monday),
  );
  return DateTime.utc(
        day.year,
        day.month,
        day.day,
      ).difference(DateTime.utc(
        week1Monday.year,
        week1Monday.month,
        week1Monday.day,
      )).inDays ~/
      7 +
      1;
}

/// The full pending set: event reminders, project deadline reminders, empty
/// mornings, and the Sunday roundup — each only when its toggle is on. Past
/// instants are never returned.
///
/// Project deadline reminders reuse the `eventSoon` gate: they share the
/// "something starting soon" channel (no extra permission or setting), so a
/// single toggle controls both types. The `projects` list only carries active
/// projects with a non-null deadline (see the scheduler's reconcile pass).
List<DesiredNotification> computeSchedule({
  required List<ScheduledEvent> events,
  required List<ScheduledProject> projects,
  required DateTime now,
  required bool eventSoon,
  required bool roundup,
  required bool morning,
  required int morningMinutes,
  int horizonDays = 7,
}) {
  final desired = <DesiredNotification>[];

  if (eventSoon) {
    final upcoming =
        events
            .where(
              (event) => event.startsAt
                  .subtract(const Duration(minutes: eventLeadMinutes))
                  .isAfter(now),
            )
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    for (final event in upcoming.take(maxEventReminders)) {
      desired.add((
        id: eventReminderId(event.id),
        at: event.startsAt.subtract(
          const Duration(minutes: eventLeadMinutes),
        ),
        title: event.title,
        body: Strings.eventReminderBody(event.tone.label),
      ));
    }

    // One reminder per project, 09:00 device-local the day before the
    // deadline. A day-before instant that is not strictly in the future (past
    // or today) is dropped, never fired late. Capped like events: the soonest
    // deadlines win, so a backlog cannot crowd out events, mornings, or the
    // roundup within the 64-pending budget.
    final upcomingProjects =
        [
          for (final project in projects)
            if (projectDeadlineReminderAt(
              project.deadline,
            ).isAfter(now))
              project,
        ]..sort((a, b) => a.deadline.compareTo(b.deadline));
    for (final project in upcomingProjects.take(maxProjectReminders)) {
      desired.add((
        id: projectDeadlineReminderId(project.id),
        at: projectDeadlineReminderAt(project.deadline),
        title: Strings.projectDeadlineReminderTitle,
        body: Strings.projectDeadlineReminderBody,
      ));
    }
  }

  if (morning) {
    final busy = {
      for (final event in events)
        DateTime(
          event.startsAt.year,
          event.startsAt.month,
          event.startsAt.day,
        ),
    };
    final today = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < horizonDays; i++) {
      final day = DateTime(today.year, today.month, today.day + i);
      if (busy.contains(day)) continue;
      final at = day.add(Duration(minutes: morningMinutes));
      if (!at.isAfter(now)) continue;
      desired.add((
        id: morningReminderId(day),
        at: at,
        title: Strings.morningReminderTitle,
        body: Strings.morningReminderBody,
      ));
    }
  }

  if (roundup) {
    var sunday = DateTime(now.year, now.month, now.day);
    while (sunday.weekday != DateTime.sunday) {
      sunday = DateTime(sunday.year, sunday.month, sunday.day + 1);
    }
    var at = DateTime(sunday.year, sunday.month, sunday.day, 20);
    if (!at.isAfter(now)) {
      at = DateTime(at.year, at.month, at.day + 7, 20);
    }
    desired.add((
      id: roundupNotificationId,
      at: at,
      title: Strings.roundupReadyTitle,
      body: Strings.roundupReadyBody(isoWeekNumber(at)),
    ));
  }

  return desired;
}