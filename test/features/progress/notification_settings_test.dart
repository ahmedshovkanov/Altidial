import 'package:altidial/core/strings.dart';
import 'package:altidial/data/notifications/notification_permission.dart';
import 'package:altidial/features/progress/profile_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> mount(WidgetTester tester) async {
    // Use a larger surface size to accommodate the bottom sheet during testing.
    await tester.binding.setSurfaceSize(const Size(720, 1200));
    await tester.pumpWidget(harness.app(const ProfileScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> scrollToKey(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pumpAndSettle();
  }

  testWidgets('the four toggles default to on', (tester) async {
    await mount(tester);

    for (final key in [
      'settings-notify-session',
      'settings-notify-event',
      'settings-notify-roundup',
      'settings-notify-morning',
    ]) {
      await scrollToKey(tester, ValueKey(key));
      final switches = find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(CupertinoSwitch),
      );
      expect(switches, findsOneWidget);
      expect(tester.widget<CupertinoSwitch>(switches).value, isTrue);
    }
    await scrollToKey(tester, const ValueKey('settings-morning-time'));
    // The morning label uses 12-hour format (e.g., "8:00 AM")
    expect(find.text('8:00 AM'), findsOneWidget);
  });

  testWidgets('flipping a toggle persists it', (tester) async {
    await mount(tester);

    await scrollToKey(tester, const ValueKey('settings-notify-event'));
    await tester.tap(find.byKey(const ValueKey('settings-notify-event')));
    await tester.pumpAndSettle();

    expect(harness.settings.values[notifyEventSoonKey], isFalse);
  });

  testWidgets('a refused permission snaps the toggle back with guidance', (tester) async {
    // System permission is NOT granted (enabled = false), but user hasn't been prompted yet.
    // Toggles should be shown, and when user tries to enable, prompt appears and is refused.
    harness.notifications
      ..enabled = false
      ..grantsRequest = false;
    harness.settings.values[notifyRoundupKey] = false;
    await mount(tester);

    await scrollToKey(tester, const ValueKey('settings-notify-roundup'));
    await tester.tap(find.byKey(const ValueKey('settings-notify-roundup')));
    await tester.pumpAndSettle();

    // Toggle should snap back to off (not turn on).
    expect(harness.settings.values[notifyRoundupKey], isNot(isTrue));
    expect(find.text(Strings.notificationsDenied), findsOneWidget);
    await tester.tap(find.text(Strings.notificationsOpenSettings));
    expect(harness.notifications.settingsOpened, 1);
  });

  testWidgets('the morning row picks a time from the sheet', (tester) async {
    await mount(tester);

    await scrollToKey(tester, const ValueKey('settings-morning-time'));
    await tester.tap(find.byKey(const ValueKey('settings-morning-time')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('6:00 AM'));
    await tester.pumpAndSettle();

    expect(harness.settings.values[morningReminderMinutesKey], '360');
  });

  testWidgets('the morning row disables with its toggle off', (tester) async {
    harness.settings.values[notifyMorningKey] = false;
    await mount(tester);

    await scrollToKey(tester, const ValueKey('settings-morning-time'));
    await tester.tap(find.byKey(const ValueKey('settings-morning-time')));
    await tester.pumpAndSettle();

    // No sheet opens for a disabled row.
    expect(find.text('6:00 AM'), findsNothing);
  });

  testWidgets('an OS-level refusal shows the off-state row instead', (tester) async {
    harness.notifications.enabled = false;
    harness.settings.values['notifications_prompted'] = true;
    await mount(tester);

    await scrollToKey(tester, const ValueKey('settings-notifications-off'));
    expect(find.byKey(const ValueKey('settings-notifications-off')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-notify-session')), findsNothing);
  });
}