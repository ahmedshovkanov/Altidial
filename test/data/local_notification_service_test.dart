import 'package:energy_clock/data/notifications/local_notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs the real plugin's Dart code against a pretend iOS side, to check what
/// the app asks iOS to do. What iOS then does (showing the permission prompt,
/// firing the notification) is checked by hand on the simulator.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  late List<MethodCall> calls;
  late Map<String, Object?> replies;
  late LocalNotificationService service;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    calls = [];
    replies = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return replies[call.method];
        });
    service = LocalNotificationService();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  List<String> methods() => [for (final call in calls) call.method];

  test('starts the plugin once, without asking for permission', () async {
    await service.areEnabled();
    await service.cancel(7);

    expect(methods().where((m) => m == 'initialize'), hasLength(1));
    final init = calls.firstWhere((c) => c.method == 'initialize');
    final arguments = init.arguments as Map<Object?, Object?>;
    expect(arguments['requestAlertPermission'], isFalse);
    expect(arguments['requestSoundPermission'], isFalse);
    expect(arguments['requestBadgePermission'], isFalse);
  });

  test('areEnabled reflects what iOS reports', () async {
    replies['checkPermissions'] = {'isEnabled': true};
    expect(await service.areEnabled(), isTrue);

    replies['checkPermissions'] = {'isEnabled': false};
    expect(await service.areEnabled(), isFalse);
  });

  test('requestPermission asks for alerts and sound only', () async {
    replies['requestPermissions'] = true;

    expect(await service.requestPermission(), isTrue);

    final call = calls.firstWhere((c) => c.method == 'requestPermissions');
    final arguments = call.arguments as Map<Object?, Object?>;
    expect(arguments['alert'], isTrue);
    expect(arguments['sound'], isTrue);
    expect(arguments['badge'], isFalse);
  });

  test('a refused request is false', () async {
    replies['requestPermissions'] = false;
    expect(await service.requestPermission(), isFalse);
  });

  test('schedule sends the instant in UTC', () async {
    final at = DateTime.utc(2099, 3, 28, 1, 30, 15);

    await service.schedule(id: 1001, at: at, title: 'Time is up', body: 'Body');

    final call = calls.firstWhere((c) => c.method == 'zonedSchedule');
    final arguments = call.arguments as Map<Object?, Object?>;
    expect(arguments['id'], 1001);
    expect(arguments['title'], 'Time is up');
    expect(arguments['body'], 'Body');
    // The timezone package names its built-in UTC zone `Etc/UTC`, a name
    // Foundation's NSTimeZone knows.
    expect(arguments['timeZoneName'], 'Etc/UTC');
    expect(arguments['scheduledDateTime'], '2099-03-28T01:30:15');
  });

  test('a local instant is converted to the same moment in UTC', () async {
    final local = DateTime(2099, 7, 1, 12, 0, 0);

    await service.schedule(id: 1, at: local, title: 't', body: 'b');

    final call = calls.firstWhere((c) => c.method == 'zonedSchedule');
    final arguments = call.arguments as Map<Object?, Object?>;
    final utc = local.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    expect(
      arguments['scheduledDateTime'],
      '${utc.year}-${two(utc.month)}-${two(utc.day)}'
      'T${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}',
    );
  });

  test('cancel removes the notification by id', () async {
    await service.cancel(1001);

    final call = calls.firstWhere((c) => c.method == 'cancel');
    expect(call.arguments, 1001);
  });

  test('openSettings asks iOS to open the notification settings', () async {
    await service.openSettings();

    expect(methods(), contains('openAppNotificationSettings'));
  });
}
