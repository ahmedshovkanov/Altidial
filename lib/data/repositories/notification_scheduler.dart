import 'package:energy_clock/core/notifications/schedule.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/notifications/notification_permission.dart';
import 'package:energy_clock/data/notifications/notification_service.dart';
import 'package:energy_clock/data/repositories/series_materialiser.dart';

/// Recomputes the full pending set and applies the difference (spec §10).
/// Passes serialize through a future chain; a pass never throws.
abstract interface class NotificationScheduler {
  Future<void> reconcile();
}

class DriftNotificationScheduler implements NotificationScheduler {
  DriftNotificationScheduler(
    this._db,
    this._service, {
    DateTime Function()? now,
    SeriesMaterialiser? materialiser,
  }) : _now = now ?? DateTime.now,
       _materialiser = materialiser;

  final AppDatabase _db;
  final NotificationService _service;
  final DateTime Function() _now;
  final SeriesMaterialiser? _materialiser;

  Future<void> _tail = Future<void>.value();
  List<DesiredNotification> _last = [];

  @override
  Future<void> reconcile() {
    final run = _tail.then((_) => _reconcile());
    _tail = run;
    return run;
  }

  Future<void> _reconcile() async {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final horizon = DateTime(today.year, today.month, today.day + 7);

    final materialiser = _materialiser;
    if (materialiser != null) {
      try {
        await materialiser.materialise(today, horizon);
      } on Object {
        // Schedule from stored events: a failed expansion must not silence
        // everything (the Calendar's rule).
      }
    }

    final settings = _db.settingsDao;
    final toggles = (
      eventSoon:
          (await settings.valueFor(notifyEventSoonKey)) != '0',
      roundup: (await settings.valueFor(notifyRoundupKey)) != '0',
      morning: (await settings.valueFor(notifyMorningKey)) != '0',
    );
    final morningMinutes =
        int.tryParse(
          await settings.valueFor(morningReminderMinutesKey) ?? '',
        ) ??
        defaultMorningMinutes;

    final rows = await _db.eventDao.eventsBetween(today, horizon);
    final events = <ScheduledEvent>[
      for (final row in rows)
        (
          id: row.id,
          startsAt: DateTime(
            row.date.year,
            row.date.month,
            row.date.day,
            row.startMinute ~/ 60,
            row.startMinute % 60,
          ),
          title: row.title,
          tone: Tone.fromDbIndex(row.toneIndex),
        ),
    ];

    // Active projects with a deadline. Completion, archive, delete and a
    // cleared deadline all drop the project from this set, so the existing
    // diff below cancels the reminder without any repository write hook.
    final projectRows = await _db.projectDao.activeProjectsWithDeadline();
    final projects = <ScheduledProject>[
      for (final row in projectRows)
        if (row.deadline != null) (id: row.id, deadline: row.deadline!),
    ];

    final desired = computeSchedule(
      events: events,
      projects: projects,
      now: now,
      eventSoon: toggles.eventSoon,
      roundup: toggles.roundup,
      morning: toggles.morning,
      morningMinutes: morningMinutes,
    );
    // Forced-all-on twin: anything it wants that the real set does not is an
    // orphan (toggled off, possibly before a restart) — cancel it.
    final allOn = computeSchedule(
      events: events,
      projects: projects,
      now: now,
      eventSoon: true,
      roundup: true,
      morning: true,
      morningMinutes: morningMinutes,
    );

    final wanted = {for (final item in desired) item.id};
    final before = {for (final item in _last) item.id: item};
    final failedSchedules = <int>{};
    final failedCancels = <DesiredNotification>[];
    for (final item in _last) {
      if (wanted.contains(item.id)) continue;
      try {
        await _service.cancel(item.id);
      } on Object {
        // A dead plugin entry must not block the rest of the pass.
        failedCancels.add(item);
      }
    }
    for (final item in allOn) {
      if (wanted.contains(item.id) || before.containsKey(item.id)) continue;
      try {
        await _service.cancel(item.id);
      } on Object {
        // Same rule.
        failedCancels.add(item);
      }
    }
    for (final item in desired) {
      final old = before[item.id];
      if (old != null &&
          old.at == item.at &&
          old.title == item.title &&
          old.body == item.body) {
        continue;
      }
      try {
        await _service.schedule(
          id: item.id,
          at: item.at,
          title: item.title,
          body: item.body,
        );
      } on Object {
        // One bad item never blocks the rest.
        failedSchedules.add(item.id);
      }
    }
    // Failed schedules stay out of `_last` so the next pass retries them;
    // failed cancels stay in so they are attempted again.
    _last = [
      for (final item in desired)
        if (!failedSchedules.contains(item.id)) item,
      ...failedCancels,
    ];
  }
}