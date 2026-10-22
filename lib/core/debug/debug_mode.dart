import 'package:flutter/foundation.dart';

/// Global debug flag. Activated by long-pressing the "Settings" title for 5s.
///
/// Exposed as a [ValueListenable] so widgets can react via
/// [ValueListenableBuilder] without rebuilding the whole tree.
class DebugMode extends ChangeNotifier implements ValueListenable<bool> {
  DebugMode._();

  static final DebugMode instance = DebugMode._();

  bool _enabled = false;

  bool get isEnabled => _enabled;

  @override
  bool get value => _enabled;

  void enable() {
    if (!_enabled) {
      _enabled = true;
      notifyListeners();
    }
  }

  void disable() {
    if (_enabled) {
      _enabled = false;
      notifyListeners();
    }
  }

  void toggle() {
    _enabled = !_enabled;
    notifyListeners();
  }

  @visibleForTesting
  void reset() {
    _enabled = false;
    notifyListeners();
  }
}

/// Global singleton — `debugMode.isEnabled` / `debugMode.value`.
final debugMode = DebugMode.instance;
