import 'package:altidial/data/providers.dart';
import 'package:altidial/features/clock/clock_screen.dart';
import 'package:altidial/features/session/providers.dart';
import 'package:altidial/features/session/session_alerts.dart';
import 'package:altidial/features/session/session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Clock tab. While a session is running its screen takes the place of the
/// day (spec §6.1); otherwise the day is shown. The other tabs stay reachable.
///
/// This lives in the app layer because it composes two features, and one
/// feature may not import the other.
class ClockTab extends ConsumerWidget {
  const ClockTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the "time is up" notification in step with the session for as long
    // as the app lives.
    ref.watch(sessionAlertsSyncProvider);
    ref.watch(foregroundRefreshProvider);

    final running = ref.watch(runningSessionProvider);
    // Read at launch: a session already running then was left by a killed app.
    final recovery = ref.watch(sessionRecoveryProvider);

    // Wait for both, so a session left running shows its recovery card from
    // the first frame instead of flashing the controls or the day.
    if (running.isLoading || recovery.isLoading) {
      return ColoredBox(color: Theme.of(context).scaffoldBackgroundColor);
    }

    // If the session cannot be read, show the day: a broken read must never
    // lock the person out of the app.
    final session = running.valueOrNull;
    if (session == null) return const ClockScreen();
    return SessionScreen(session: session);
  }
}
