import 'package:energy_clock/data/daos/settings_dao.dart';

/// Typed access to the app's settings. Booleans are stored as '1' and '0',
/// integers as their decimal string; the table holds only text.
abstract interface class SettingsRepository {
  Future<bool> getBool(String key, {bool defaultValue = false});
  Future<void> setBool(String key, bool value);

  /// The stored string, or null when the key was never set.
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);

  /// The stored integer, or null when the key was never set or does not parse.
  /// Stored as its decimal string; the table holds only text.
  Future<int?> getInt(String key);
  Future<void> setInt(String key, int value);
}

class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._dao);

  final SettingsDao _dao;

  @override
  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final stored = await _dao.valueFor(key);
    return stored == null ? defaultValue : stored == '1';
  }

  @override
  Future<void> setBool(String key, bool value) =>
      _dao.setValue(key, value ? '1' : '0');

  @override
  Future<String?> getString(String key) => _dao.valueFor(key);

  @override
  Future<void> setString(String key, String value) => _dao.setValue(key, value);

  @override
  Future<int?> getInt(String key) async =>
      int.tryParse(await _dao.valueFor(key) ?? '');

  @override
  Future<void> setInt(String key, int value) => _dao.setValue(key, '$value');
}
