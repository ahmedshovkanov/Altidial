import 'dart:async';

import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/notifications/notification_permission.dart';
import 'package:energy_clock/data/notifications/notification_service.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/session_repository.dart';
import 'package:energy_clock/features/session/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The id of the one "time is up" notification. There is only ever one,
/// because only one session runs at a time.
const int sessionEndNotificationId = 1001;

/// Set once the person has dismissed the "alerts are off" banner.
const String notificationBannerSeenKey = 'notification_banner_seen';

/// What the app knows about notification permission.
enum AlertsStatus {
  /// Not looked at yet, because no session has been started.
  unknown,
  granted,
  denied,
}

/// Keeps the "time is up" notification in line with the running session
/// (spec §6.2): scheduled for the planned end while the session runs, removed
/// while it is paused or once it has ended, and moved when it is extended. It
/// reacts to the session itself, so every way of changing a session, and a
/// session found after a relaunch, is handled in one place.
///
/// Permission is requested here, the first time a session needs an alert, not
/// at launch. A refused permission never stops a session; the screen shows a
/// one-time banner instead.
class SessionAlertsNotifier extends Notifier<AlertsStatus> {
  Future<void> _tail = Future<void>.value();

  @override
  AlertsStatus build() => AlertsStatus.unknown;

  /// Brings the pending notification in line with [session]. Calls are carried
  /// out one after another, in order, so a quick pause and resume cannot leave
  /// a stale notification behind.
  Future<void> sync(RunningSession? session) {
    final run = _tail.then((_) => _sync(session));
    _tail = run;
    return run;
  }

  Future<void> _sync(RunningSession? session) async {
    try {
      final service = ref.read(notificationServiceProvider);
      if (!await ref
          .read(settingsRepositoryProvider)
          .getBool(notifySessionEndKey, defaultValue: true)) {
        await service.cancel(sessionEndNotificationId);
        return;
      }
      final now = ref.read(sessionNowSourceProvider)();
      final timing = session?.timing;
      if (session == null ||
          timing!.isPaused ||
          !timing.plannedEnd.isAfter(now)) {
        await service.cancel(sessionEndNotificationId);
        return;
      }
      if (!await _permitted(service)) {
        await service.cancel(sessionEndNotificationId);
        return;
      }
      await service.schedule(
        id: sessionEndNotificationId,
        at: timing.plannedEnd,
        title: Strings.sessionEndedTitle,
        body: Strings.sessionEndedBody(session.eventTitle),
      );
    } catch (error) {
      // The alert is a convenience; it must never break the session.
      debugPrint('Could not update the session alert: $error');
    }
  }

  Future<bool> _permitted(NotificationService service) async {
    final granted = await ensureNotificationPermission(
      service: service,
      settings: ref.read(settingsRepositoryProvider),
    );
    state = granted ? AlertsStatus.granted : AlertsStatus.denied;
    return granted;
  }
}

final sessionAlertsProvider =
    NotifierProvider<SessionAlertsNotifier, AlertsStatus>(
      SessionAlertsNotifier.new,
    );

/// Keeps [sessionAlertsProvider] in step with the running session. Watch it
/// from a widget that lives as long as the app does. Also re-checks when the
/// app returns to the foreground, so turning notifications on in Settings
/// takes effect for the session in progress.
final sessionAlertsSyncProvider = Provider<void>((ref) {
  var first = true;
  RunningSession? synced;

  void sync(RunningSession? session) {
    unawaited(ref.read(sessionAlertsProvider.notifier).sync(session));
  }

  ref.listen<AsyncValue<RunningSession?>>(runningSessionProvider, (
    previous,
    next,
  ) {
    if (!next.hasValue) return;
    final session = next.value;
    // The stream also re-emits when unrelated events change; only a change to
    // the session itself needs the notification redone.
    if (!first && session == synced) return;
    first = false;
    synced = session;
    sync(session);
  }, fireImmediately: true);

  final lifecycle = AppLifecycleListener(
    onResume: () => sync(ref.read(runningSessionProvider).valueOrNull),
  );
  ref.onDispose(lifecycle.dispose);
});

/// Whether to show the one-time "alerts are off" banner: permission was
/// refused and the person has not dismissed the banner yet.
final notificationBannerVisibleProvider = FutureProvider<bool>((ref) async {
  if (ref.watch(sessionAlertsProvider) != AlertsStatus.denied) return false;
  final seen = await ref
      .watch(settingsRepositoryProvider)
      .getBool(notificationBannerSeenKey);
  return !seen;
});

/// Hides the banner for good.
Future<void> dismissNotificationBanner(WidgetRef ref) async {
  await ref
      .read(settingsRepositoryProvider)
      .setBool(notificationBannerSeenKey, true);
  ref.invalidate(notificationBannerVisibleProvider);
}
