import 'package:altidial/features/clock/providers.dart';
import 'package:altidial/features/session/providers.dart';

/// A [ClockNotifier] that never ticks by itself. Tests set the time directly:
///
///     clockProvider.overrideWith(() => FakeClock(DateTime(2026, 10, 3, 10, 30)))
///
/// [ClockHarness] also hands [current] to the session repository and the
/// session screen's clock, so one `set` moves every clock in the app.
class FakeClock extends ClockNotifier {
  FakeClock(DateTime initial) : _current = initial;

  DateTime _current;
  bool _built = false;
  final List<void Function(DateTime)> _followers = [];

  /// The time the fake clock currently reads.
  DateTime get current => _current;

  @override
  DateTime build() {
    _built = true;
    return _current;
  }

  /// Moves the fake clock, as a minute tick would.
  void set(DateTime time) {
    _current = time;
    if (_built) state = time;
    for (final follower in List.of(_followers)) {
      follower(time);
    }
  }

  void follow(void Function(DateTime) onChange) => _followers.add(onChange);

  void unfollow(void Function(DateTime) onChange) =>
      _followers.remove(onChange);
}

/// The session screen's clock, driven by a [FakeClock] instead of a timer: it
/// changes the moment the fake clock does. A real timer would still be pending
/// when `testWidgets` checks for stray timers, because the harness's provider
/// container outlives the widget tree. The real notifier has its own tests.
class FakeSessionNow extends SessionNowNotifier {
  FakeSessionNow(this._clock);

  final FakeClock _clock;

  @override
  DateTime build() {
    void onChange(DateTime time) => state = time;
    _clock.follow(onChange);
    ref.onDispose(() => _clock.unfollow(onChange));
    return _clock.current;
  }
}
