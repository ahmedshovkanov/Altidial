import 'dart:math';

import 'package:altidial/core/event_status.dart';
import 'package:altidial/core/progress/streak.dart';
import 'package:altidial/core/session/session_outcome.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/debug/debug_constants.dart';
import 'package:altidial/debug/demo_data.dart';
import 'package:drift/drift.dart';

class DemoDataset {
  const DemoDataset({
    required this.projects,
    required this.events,
    required this.sessions,
    required this.tasks,
    required this.templates,
    required this.templateItems,
    required this.intents,
    required this.reviews,
    required this.badgeUnlocks,
    required this.rangeStart,
    required this.rangeEnd,
  });

  final List<ProjectsCompanion> projects;
  final List<EventsCompanion> events;
  final List<SessionsCompanion> sessions;
  final List<TasksCompanion> tasks;
  final List<DayTemplatesCompanion> templates;
  final List<DayTemplateItemsCompanion> templateItems;
  final List<CoachIntentsCompanion> intents;
  final List<CoachReviewsCompanion> reviews;
  final List<BadgeUnlocksCompanion> badgeUnlocks;
  final DateTime rangeStart;
  final DateTime rangeEnd;
}

class DemoGenerator {
  DemoGenerator({DateTime Function()? now, this.seed = demoSeed})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final int seed;

  DemoDataset generate() {
    final random = Random(seed);
    final now = _now();
    final today = startOfDay(now);
    final first = DateTime(
      today.year,
      today.month,
      today.day - (demoDayCount - 1),
    );

    final projects = _buildProjects(first, today);
    final events = <EventsCompanion>[];
    final sessions = <SessionsCompanion>[];
    final tasks = <TasksCompanion>[];
    final templates = <DayTemplatesCompanion>[];
    final templateItems = <DayTemplateItemsCompanion>[];
    final intents = <CoachIntentsCompanion>[];
    final reviews = <CoachReviewsCompanion>[];
    final badgeUnlocks = <BadgeUnlocksCompanion>[];

    final qualifying = <DateTime>{};
    final endedDates = <DateTime>[];
    final endedByWeek = <DateTime, int>{};
    final abandonedByWeek = <DateTime, int>{};
    final tonesByWeek = <DateTime, Set<int>>{};
    final focusSecondsByDay = <DateTime, int>{};
    final unlocked = <String>{};
    DateTime? earlyFocusDate;

    var eventId = 1;
    var sessionId = 1;

    EventsCompanion makeEvent({
      required int id,
      required DateTime day,
      required String title,
      required int toneIndex,
      required int startMinute,
      required int endMinute,
      required int status,
      bool isFlight = false,
      String? flightNumber,
      String? fromCode,
      String? toCode,
      int? projectId,
    }) {
      return EventsCompanion(
        id: Value(id),
        date: Value(day),
        title: Value(title),
        toneIndex: Value(toneIndex),
        startMinute: Value(startMinute),
        endMinute: Value(endMinute),
        status: Value(status),
        isFlight: Value(isFlight),
        flightNumber: Value(flightNumber),
        fromCode: Value(fromCode),
        toCode: Value(toCode),
        projectId: Value(projectId),
        createdAt: Value(day),
        updatedAt: Value(now),
      );
    }

    SessionsCompanion makeSession({
      required int id,
      required int eventId,
      required DateTime startedAt,
      required int plannedSeconds,
      required int activeSeconds,
      required int pausedSeconds,
      required SessionOutcome outcome,
      required bool reflect,
    }) {
      final reflected = reflect && random.nextDouble() < 0.7;
      final energy = reflected ? 2 + random.nextInt(4) : null;
      final focus = reflected ? 2 + random.nextInt(4) : null;
      final tags = reflected
          ? DemoContent.reflectionTags[random.nextInt(
              DemoContent.reflectionTags.length,
            )]
          : null;
      final note = reflected && random.nextDouble() < 0.25
          ? DemoContent.reflectionNotes[random.nextInt(
              DemoContent.reflectionNotes.length,
            )]
          : null;

      return SessionsCompanion(
        id: Value(id),
        eventId: Value(eventId),
        startedAt: Value(startedAt),
        endedAt: Value(
          startedAt.add(Duration(seconds: activeSeconds + pausedSeconds)),
        ),
        plannedSeconds: Value(plannedSeconds),
        pausedSeconds: Value(pausedSeconds),
        activeSeconds: Value(activeSeconds),
        overtimeSeconds: Value(max(0, activeSeconds - plannedSeconds)),
        outcome: Value(outcome.dbIndex),
        energyRating: Value(energy),
        focusRating: Value(focus),
        tagsCsv: Value(tags?.join(',')),
        note: Value(note),
      );
    }

    void recordSession({
      required DateTime day,
      required Tone tone,
      required DateTime startedAt,
      required int activeSeconds,
      required SessionOutcome outcome,
    }) {
      endedDates.add(day);
      final week = startOfWeek(day);
      endedByWeek[week] = (endedByWeek[week] ?? 0) + 1;
      if (outcome == SessionOutcome.abandoned) {
        abandonedByWeek[week] = (abandonedByWeek[week] ?? 0) + 1;
      }
      if (!outcome.countsAsDone) return;

      tonesByWeek.putIfAbsent(week, () => <int>{}).add(tone.dbIndex);
      qualifying.add(day);
      if (tone == Tone.focus) {
        focusSecondsByDay[day] = (focusSecondsByDay[day] ?? 0) + activeSeconds;
        if (startedAt.hour < 8) earlyFocusDate ??= day;
      }
    }

    for (var offset = 0; offset < demoDayCount; offset++) {
      final day = DateTime(first.year, first.month, first.day + offset);
      final forceActive = offset >= 30 && offset <= 60;
      final isToday = day == today;

      if (!forceActive &&
          !isToday &&
          offset != 0 &&
          random.nextDouble() < 0.10) {
        continue;
      }

      final plan = _planFor(
        day,
        random,
        early: offset == 45,
        projectId: 1 + (offset % 5),
      );

      DateTime at(int minute) =>
          DateTime(day.year, day.month, day.day, minute ~/ 60, minute % 60);

      for (var index = 0; index < plan.length; index++) {
        final item = plan[index];
        final start = at(item.startMinute);
        final end = at(item.endMinute);
        final past = end.isBefore(now);
        final id = eventId++;

        SessionOutcome? outcome;
        if (past) {
          final forceDone =
              (forceActive && index < 3) || offset == 45 || (isToday && past);
          final roll = forceDone ? 0.0 : random.nextDouble();
          outcome = roll < 0.75
              ? SessionOutcome.completed
              : roll < 0.85
              ? SessionOutcome.finishedEarly
              : roll < 0.92
              ? SessionOutcome.abandoned
              : null;
        }

        var status = EventStatus.planned.dbIndex;
        if (outcome != null) {
          final plannedSeconds = (item.endMinute - item.startMinute) * 60;

          late final int activeSeconds;
          late final int pausedSeconds;
          late final DateTime startedAt;

          if (isToday) {
            startedAt = start;
            activeSeconds = plannedSeconds;
            pausedSeconds = 0;
          } else {
            startedAt = start.add(Duration(minutes: random.nextInt(6)));
            activeSeconds = switch (outcome) {
              SessionOutcome.completed =>
                plannedSeconds + random.nextInt(11) * 60,
              SessionOutcome.finishedEarly =>
                (plannedSeconds * (0.5 + random.nextDouble() * 0.35)).round(),
              SessionOutcome.abandoned =>
                (plannedSeconds * (0.1 + random.nextDouble() * 0.4)).round(),
              SessionOutcome.running => plannedSeconds,
            };
            pausedSeconds = random.nextDouble() < 0.2
                ? (random.nextInt(6) + 1) * 60
                : 0;
          }

          status = outcome.countsAsDone
              ? EventStatus.completed.dbIndex
              : EventStatus.planned.dbIndex;

          sessions.add(
            makeSession(
              id: sessionId++,
              eventId: id,
              startedAt: startedAt,
              plannedSeconds: plannedSeconds,
              activeSeconds: activeSeconds,
              pausedSeconds: pausedSeconds,
              outcome: outcome,
              reflect: outcome.countsAsDone,
            ),
          );
          recordSession(
            day: day,
            tone: item.tone,
            startedAt: startedAt,
            activeSeconds: activeSeconds,
            outcome: outcome,
          );
        }

        events.add(
          makeEvent(
            id: id,
            day: day,
            title: item.title,
            toneIndex: item.tone.dbIndex,
            startMinute: item.startMinute,
            endMinute: item.endMinute,
            status: status,
            projectId: item.projectId,
          ),
        );
      }
    }

    final flightDay = DateTime(first.year, first.month, first.day + 20);
    final flightId = eventId++;
    events.add(
      makeEvent(
        id: flightId,
        day: flightDay,
        title: 'Flight LH715',
        toneIndex: Tone.inbox.dbIndex,
        startMinute: 1080,
        endMinute: 1200,
        status: EventStatus.completed.dbIndex,
        isFlight: true,
        flightNumber: 'LH715',
        fromCode: 'SOF',
        toCode: 'FRA',
      ),
    );
    final flightStart = DateTime(
      flightDay.year,
      flightDay.month,
      flightDay.day,
      18,
    );
    sessions.add(
      makeSession(
        id: sessionId++,
        eventId: flightId,
        startedAt: flightStart,
        plannedSeconds: 7200,
        activeSeconds: 7200,
        pausedSeconds: 0,
        outcome: SessionOutcome.completed,
        reflect: true,
      ),
    );
    recordSession(
      day: flightDay,
      tone: Tone.inbox,
      startedAt: flightStart,
      activeSeconds: 7200,
      outcome: SessionOutcome.completed,
    );

    final upcomingFlights = [
      (offset: 12, title: 'Flight BA921', number: 'BA921', to: 'LHR'),
      (offset: 40, title: 'Flight AF1390', number: 'AF1390', to: 'CDG'),
    ];
    for (final flight in upcomingFlights) {
      final day = DateTime(today.year, today.month, today.day + flight.offset);
      events.add(
        makeEvent(
          id: eventId++,
          day: day,
          title: flight.title,
          toneIndex: Tone.inbox.dbIndex,
          startMinute: 1140,
          endMinute: 1260,
          status: EventStatus.planned.dbIndex,
          isFlight: true,
          flightNumber: flight.number,
          fromCode: 'SOF',
          toCode: flight.to,
        ),
      );
    }

    final sortOrders = <int, int>{};
    var taskId = 1;
    for (var project = 1; project <= 5; project++) {
      for (var index = 0; index < 5; index++) {
        final status = index;
        final key = project * 10 + status;
        final sortOrder = (sortOrders[key] ?? 0) + 1;
        sortOrders[key] = sortOrder;

        final dueOffset = switch (index % 3) {
          0 => -5,
          1 => 2,
          _ => 9,
        };
        final plannedOffset = status == 1 ? 0 : 1;

        tasks.add(
          TasksCompanion(
            id: Value(taskId++),
            projectId: Value(project),
            title: Value(
              DemoContent.taskTitles[(project * 5 + index) %
                  DemoContent.taskTitles.length],
            ),
            boardStatus: Value(status),
            priority: Value(index % 4),
            estimateMinutes: Value(30 + random.nextInt(8) * 15),
            dueDate: Value(
              DateTime(today.year, today.month, today.day + dueOffset),
            ),
            plannedDate: Value(
              status == 1 || status == 2
                  ? DateTime(today.year, today.month, today.day + plannedOffset)
                  : null,
            ),
            sortOrder: Value(sortOrder),
            blockedReason: Value(status == 3 ? 'Waiting on a reply' : null),
            createdAt: Value(DateTime(first.year, first.month, first.day - 10)),
            updatedAt: Value(now),
            completedAt: Value(
              status == 4
                  ? DateTime(today.year, today.month, today.day - 3)
                  : null,
            ),
          ),
        );
      }
    }

    templates.addAll([
      DayTemplatesCompanion(
        id: const Value(1),
        name: const Value('Workday'),
        createdAt: Value(first),
      ),
      DayTemplatesCompanion(
        id: const Value(2),
        name: const Value('Reset day'),
        createdAt: Value(first),
      ),
    ]);

    var templateItemId = 1;
    void addTemplateItem({
      required int templateId,
      required String title,
      required Tone tone,
      required int startMinute,
      required int endMinute,
    }) {
      templateItems.add(
        DayTemplateItemsCompanion(
          id: Value(templateItemId++),
          templateId: Value(templateId),
          title: Value(title),
          toneIndex: Value(tone.dbIndex),
          startMinute: Value(startMinute),
          endMinute: Value(endMinute),
        ),
      );
    }

    addTemplateItem(
      templateId: 1,
      title: 'Deep work',
      tone: Tone.focus,
      startMinute: 540,
      endMinute: 660,
    );
    addTemplateItem(
      templateId: 1,
      title: 'Email and admin',
      tone: Tone.inbox,
      startMinute: 660,
      endMinute: 705,
    );
    addTemplateItem(
      templateId: 1,
      title: 'Lunch walk',
      tone: Tone.life,
      startMinute: 750,
      endMinute: 795,
    );
    addTemplateItem(
      templateId: 2,
      title: 'Long walk',
      tone: Tone.life,
      startMinute: 600,
      endMinute: 690,
    );
    addTemplateItem(
      templateId: 2,
      title: 'Reading',
      tone: Tone.focus,
      startMinute: 780,
      endMinute: 840,
    );
    addTemplateItem(
      templateId: 2,
      title: 'Dinner prep',
      tone: Tone.life,
      startMinute: 1080,
      endMinute: 1140,
    );

    for (var offset = 60; offset < demoDayCount; offset++) {
      final day = DateTime(first.year, first.month, first.day + offset);
      final isToday = day == today;

      if (isToday || random.nextDouble() < 0.8) {
        intents.add(
          CoachIntentsCompanion(
            date: Value(day),
            focusGoal: Value(
              DemoContent.intentGoals[random.nextInt(
                DemoContent.intentGoals.length,
              )],
            ),
            predictedEnergy: Value(2 + random.nextInt(4)),
            createdAt: Value(day),
          ),
        );
      }

      if (!isToday && (offset == 88 || random.nextDouble() < 0.6)) {
        reviews.add(
          CoachReviewsCompanion(
            date: Value(day),
            energy: Value(2 + random.nextInt(4)),
            winText: Value(
              random.nextDouble() < 0.5
                  ? DemoContent.winTexts[random.nextInt(
                      DemoContent.winTexts.length,
                    )]
                  : null,
            ),
            createdAt: Value(day),
          ),
        );
      }
    }

    void unlock(String id, DateTime at) {
      if (!unlocked.add(id)) return;
      badgeUnlocks.add(
        BadgeUnlocksCompanion(badgeId: Value(id), unlockedAt: Value(at)),
      );
    }

    final sortedEnded = [...endedDates]..sort();
    const sessionBadges = [
      (index: 0, id: 'first_session'),
      (index: 9, id: 'sessions_10'),
      (index: 49, id: 'sessions_50'),
      (index: 99, id: 'sessions_100'),
    ];
    for (final badge in sessionBadges) {
      if (sortedEnded.length > badge.index) {
        unlock(badge.id, sortedEnded[badge.index]);
      }
    }

    final focusDays = focusSecondsByDay.keys.toList()..sort();
    for (final day in focusDays) {
      if (focusSecondsByDay[day]! >= 4 * 3600) {
        unlock('focus_day_4h', day);
        break;
      }
    }

    final toneWeeks = tonesByWeek.keys.toList()..sort();
    for (final week in toneWeeks) {
      if (tonesByWeek[week]!.length == 3) {
        final sunday = DateTime(week.year, week.month, week.day + 6);
        unlock('week_all_tones', sunday.isAfter(today) ? today : sunday);
        break;
      }
    }

    final endedWeeks = endedByWeek.keys.toList()..sort();
    for (final week in endedWeeks) {
      final sunday = DateTime(week.year, week.month, week.day + 6);
      if (sunday.isBefore(today) && (abandonedByWeek[week] ?? 0) == 0) {
        unlock('week_no_abandoned', sunday);
        break;
      }
    }

    if (earlyFocusDate != null) {
      unlock('early_bird', earlyFocusDate!);
    }

    final sortedQualifying = qualifying.toList()..sort();
    var run = 0;
    for (var index = 0; index < sortedQualifying.length; index++) {
      run =
          index == 0 ||
              isNextCalendarDay(
                sortedQualifying[index - 1],
                sortedQualifying[index],
              )
          ? run + 1
          : 1;
      if (run == 7) unlock('streak_7', sortedQualifying[index]);
      if (run == 30) unlock('streak_30', sortedQualifying[index]);
    }

    return DemoDataset(
      projects: projects,
      events: events,
      sessions: sessions,
      tasks: tasks,
      templates: templates,
      templateItems: templateItems,
      intents: intents,
      reviews: reviews,
      badgeUnlocks: badgeUnlocks,
      rangeStart: first,
      rangeEnd: today,
    );
  }

  List<ProjectsCompanion> _buildProjects(DateTime first, DateTime today) {
    final createdAt = DateTime(first.year, first.month, first.day - 30);
    return List.generate(5, (index) {
      final completed = index == 3;
      final archived = index == 4;
      return ProjectsCompanion(
        id: Value(index + 1),
        title: Value(DemoContent.projectTitles[index]),
        createdAt: Value(createdAt),
        deadline: Value(
          index < 3
              ? DateTime(today.year, today.month, today.day + 7 + index * 7)
              : DateTime(today.year, today.month, today.day - 10 - index),
        ),
        targetMinutes: Value(600 + index * 300),
        toneIndex: Value(index % 3),
        status: Value(
          completed
              ? 1
              : archived
              ? 2
              : 0,
        ),
        completedAt: Value(
          completed ? DateTime(today.year, today.month, today.day - 5) : null,
        ),
        notes: Value('Demo project ${index + 1}'),
        priority: Value(index % 4),
      );
    });
  }

  List<_PlanItem> _planFor(
    DateTime day,
    Random random, {
    required bool early,
    required int projectId,
  }) {
    final isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

    String pick(List<String> titles) => titles[random.nextInt(titles.length)];

    _PlanItem focus(int startMinute, int endMinute) => _PlanItem(
      title: pick(DemoContent.focusTitles),
      tone: Tone.focus,
      startMinute: startMinute,
      endMinute: endMinute,
      projectId: projectId,
    );

    _PlanItem inbox(int startMinute, int endMinute) => _PlanItem(
      title: pick(DemoContent.inboxTitles),
      tone: Tone.inbox,
      startMinute: startMinute,
      endMinute: endMinute,
    );

    _PlanItem life(int startMinute, int endMinute) => _PlanItem(
      title: pick(DemoContent.lifeTitles),
      tone: Tone.life,
      startMinute: startMinute,
      endMinute: endMinute,
    );

    if (isWeekend) {
      return [life(570, 630), focus(660, 720), inbox(1020, 1080)];
    }

    if (early) {
      return [
        focus(420, 510),
        focus(540, 660),
        inbox(675, 705),
        life(735, 780),
        focus(810, 930),
        inbox(960, 1020),
      ];
    }

    return [
      focus(540, 660),
      inbox(675, 705),
      life(735, 780),
      focus(840, 930),
      inbox(960, 1020),
    ];
  }
}

class _PlanItem {
  const _PlanItem({
    required this.title,
    required this.tone,
    required this.startMinute,
    required this.endMinute,
    this.projectId,
  });

  final String title;
  final Tone tone;
  final int startMinute;
  final int endMinute;
  final int? projectId;
}
