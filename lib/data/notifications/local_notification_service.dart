import 'package:altidial/data/notifications/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// [NotificationService] over `flutter_local_notifications`, for iOS.
///
/// The plugin starts on first use, with its own permission requests switched
/// off: the app asks when a person first starts a session, not at launch.
class LocalNotificationService implements NotificationService {
  LocalNotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<bool?>? _started;

  static const NotificationDetails _details = NotificationDetails(
    iOS: DarwinNotificationDetails(presentSound: true),
  );

  Future<void> _start() {
    return _started ??= _plugin.initialize(
      settings: const InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );
  }

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> areEnabled() async {
    await _start();
    final options = await _ios?.checkPermissions();
    return options?.isEnabled ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    await _start();
    return await _ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  /// [at] is an absolute instant, so it is sent in UTC: the system fires it at
  /// that moment whatever the time zone or daylight-saving rules are when it
  /// comes due.
  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    await _start();
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(at, tz.UTC),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _start();
    await _plugin.cancel(id: id);
  }

  @override
  Future<void> openSettings() async {
    await _start();
    await _ios?.openAppNotificationSettings();
  }
}
