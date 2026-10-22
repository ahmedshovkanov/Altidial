import 'package:energy_clock/data/notifications/notification_service.dart';

/// A [NotificationService] that remembers what it was asked to do.
class FakeNotificationService implements NotificationService {
  FakeNotificationService({this.enabled = true, this.grantsRequest = true});

  /// Whether the system currently allows notifications.
  bool enabled;

  /// What the permission prompt answers.
  bool grantsRequest;

  /// Makes [schedule] throw, as a failing plugin would.
  bool failSchedule = false;

  /// How many times the permission prompt was shown.
  int requests = 0;

  /// How many times the settings page was opened.
  int settingsOpened = 0;

  /// The pending notifications, by id.
  final Map<int, ({DateTime at, String title, String body})> pending = {};

  /// Every call, in order: `schedule 1001`, `cancel 1001`, `request`.
  final List<String> log = [];

  @override
  Future<bool> areEnabled() async => enabled;

  @override
  Future<bool> requestPermission() async {
    requests++;
    log.add('request');
    if (grantsRequest) enabled = true;
    return grantsRequest;
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    log.add('schedule $id');
    if (failSchedule) throw StateError('the plugin failed');
    pending[id] = (at: at, title: title, body: body);
  }

  @override
  Future<void> cancel(int id) async {
    log.add('cancel $id');
    pending.remove(id);
  }

  @override
  Future<void> openSettings() async {
    settingsOpened++;
  }
}
