import 'dart:async';

import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/session_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the session feature reads the time. Tests replace it with a source
/// they move by hand.
final sessionNowSourceProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// The running session, or null. Emits again whenever it changes.
final runningSessionProvider = StreamProvider<RunningSession?>((ref) {
  return ref.watch(sessionRepositoryProvider).watchRunning();
});

/// How long until the next whole second.
Duration untilNextSecond(DateTime now) => Duration(
  microseconds:
      Duration.microsecondsPerSecond -
      now.microsecondsSinceEpoch % Duration.microsecondsPerSecond,
);

/// The current time, refreshed on every whole second while something watches
/// it, and straight away when the app returns to the foreground. The session
/// screen is the only watcher, so nothing ticks when no session is on screen.
///
/// Remaining time is always worked out from this clock (spec §6.2), never
/// counted down, so a tick that arrives late shows the right number.
class SessionNowNotifier extends AutoDisposeNotifier<DateTime>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  DateTime build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _timer?.cancel();
    });
    final now = ref.read(sessionNowSourceProvider)();
    _schedule(now);
    return now;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _tick();
  }

  void _schedule(DateTime now) {
    _timer?.cancel();
    _timer = Timer(untilNextSecond(now), _tick);
  }

  void _tick() {
    final now = ref.read(sessionNowSourceProvider)();
    state = now;
    _schedule(now);
  }
}

final sessionNowProvider =
    NotifierProvider.autoDispose<SessionNowNotifier, DateTime>(
      SessionNowNotifier.new,
    );

/// The id of a session that was already running when the app started, which
/// means the app was killed during it, or null. The session screen offers to
/// resume it or close it out (spec §6.5) until [resolve] is called. It is read
/// once at launch, so a session started later never counts as a recovery.
class SessionRecoveryNotifier extends AsyncNotifier<int?> {
  @override
  Future<int?> build() async {
    final session = await ref.read(sessionRepositoryProvider).runningSession();
    return session?.id;
  }

  void resolve() => state = const AsyncData(null);
}

final sessionRecoveryProvider =
    AsyncNotifierProvider<SessionRecoveryNotifier, int?>(
      SessionRecoveryNotifier.new,
    );
