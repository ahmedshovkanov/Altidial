import 'dart:async';

import 'package:energy_clock/data/repositories/settings_repository.dart';

/// In-memory [SettingsRepository] for widget tests. Booleans are stored
/// as-is, integers as decimal strings — the same shapes the Drift repository
/// writes.
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({Map<String, Object>? values}) : values = {...?values};

  /// The stored settings; tests read and seed it directly. Booleans are stored
  /// as-is, integers as strings — the same shapes the Drift repository writes.
  final Map<String, Object> values;

  /// Makes every read throw, as an unreadable database would.
  bool failReads = false;

  /// Makes every write throw.
  bool failWrites = false;

  /// While non-null, reads wait for it to complete.
  Completer<bool>? gate;

  Future<void> _read() async {
    if (failReads) throw StateError('settings are unreadable');
    final held = gate;
    if (held != null) await held.future;
  }

  @override
  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    await _read();
    return values[key] == true ? true : values[key] is bool ? values[key] as bool : defaultValue;
  }

  @override
  Future<void> setBool(String key, bool value) async {
    if (failWrites) throw StateError('settings are unwritable');
    values[key] = value;
  }

  @override
  Future<String?> getString(String key) async {
    if (failReads) throw StateError('settings are unreadable');
    final held = gate;
    if (held != null) await held.future;
    return values[key] is String ? values[key] as String : null;
  }

  @override
  Future<void> setString(String key, String value) async {
    if (failWrites) throw StateError('settings are unwritable');
    values[key] = value;
  }

  @override
  Future<int?> getInt(String key) async {
    final stored = await getString(key);
    return stored == null ? null : int.tryParse(stored);
  }

  @override
  Future<void> setInt(String key, int value) => setString(key, '$value');
}