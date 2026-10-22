import 'dart:async';

import 'package:altidial/core/strings.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/data/repositories/session_repository.dart';
import 'package:altidial/features/clock/model/calendar_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether a session can be started on [event] at [now]: it still has to be
/// done, and it belongs to today. A past day is read-only, and a session is
/// for what you are doing now, not for a day that has not come yet.
bool canStartSession(CalendarEvent event, DateTime now) =>
    event.status == EventStatus.planned && event.date == startOfDay(now);

/// Starts a session on [event]. Returns true when it started; the session
/// screen then takes the Clock tab's place by itself. Used by the Now card and
/// the detail sheet.
Future<bool> startSessionForEvent(
  BuildContext context,
  WidgetRef ref,
  CalendarEvent event,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(sessionRepositoryProvider).start(eventId: event.id);
    unawaited(HapticFeedback.mediumImpact());
    return true;
  } on SessionAlreadyRunningException {
    messenger.showSnackBar(
      const SnackBar(content: Text(Strings.sessionAlreadyRunning)),
    );
  } on SessionEventMissingException {
    messenger.showSnackBar(
      const SnackBar(content: Text(Strings.sessionStartFailed)),
    );
  }
  return false;
}
