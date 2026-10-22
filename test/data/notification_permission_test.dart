import 'package:altidial/data/notifications/notification_permission.dart';
import 'package:altidial/data/notifications/notification_service.dart';
import 'package:altidial/data/repositories/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_notification_service.dart';
import '../support/fake_settings_repository.dart';

void main() {
  late FakeNotificationService service;
  late FakeSettingsRepository settings;

  setUp(() {
    service = FakeNotificationService();
    settings = FakeSettingsRepository();
  });

  Future<bool> ensure() => ensureNotificationPermission(
    service: service,
    settings: settings,
  );

  test('an enabled system passes through without prompting', () async {
    expect(await ensure(), isTrue);
    expect(service.requests, 0);
    expect(settings.values, isEmpty);
  });

  test('the prompt fires once and a grant sticks', () async {
    service.enabled = false;

    expect(await ensure(), isTrue);
    expect(service.requests, 1);
    expect(settings.values['notifications_prompted'], isTrue);

    // Already prompted and granted: no second prompt.
    service.enabled = true;
    expect(await ensure(), isTrue);
    expect(service.requests, 1);
  });

  test('a refusal never prompts again and reads as denied', () async {
    service
      ..enabled = false
      ..grantsRequest = false;

    expect(await ensure(), isFalse);
    expect(await ensure(), isFalse);
    expect(service.requests, 1);
  });

  test('a failing plugin reads as refused', () async {
    service.enabled = false;
    settings.failReads = true;

    expect(await ensure(), isFalse);
  });
}