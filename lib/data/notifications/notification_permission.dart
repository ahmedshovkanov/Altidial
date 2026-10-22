import 'package:altidial/data/notifications/notification_service.dart';
import 'package:altidial/data/repositories/settings_repository.dart';

/// Settings keys owned by notifications. Toggles default to true at the call
/// site (`getBool(key, defaultValue: true)`); they do nothing until the OS
/// permission exists.
const String notifySessionEndKey = 'notify_session_end';
const String notifyEventSoonKey = 'notify_event_soon';
const String notifyRoundupKey = 'notify_roundup';
const String notifyMorningKey = 'notify_morning';

/// Minutes since midnight for the daily reminder. Default 480 (08:00).
const String morningReminderMinutesKey = 'morning_reminder_minutes';
const int defaultMorningMinutes = 480;

/// Set once the system permission prompt has been shown, so the app never asks
/// twice. iOS cannot tell "never asked" from "refused", so the app remembers.
/// (Moved here from `session_alerts.dart`: the toggle flow needs the same key
/// and the data layer cannot import a feature.)
const String notificationsPromptedKey = 'notifications_prompted';

/// The shared first-use permission flow: an enabled system passes through, the
/// system prompt fires once and its answer sticks, and a refusal after
/// prompting returns false at once. Never throws — a failing plugin reads as
/// refused so callers degrade instead of crashing.
Future<bool> ensureNotificationPermission({
  required NotificationService service,
  required SettingsRepository settings,
}) async {
  try {
    if (await service.areEnabled()) return true;
    if (!await settings.getBool(notificationsPromptedKey)) {
      await settings.setBool(notificationsPromptedKey, true);
      return await service.requestPermission();
    }
    return false;
  } on Object {
    return false;
  }
}