import 'package:drift/drift.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/tables/settings_table.dart';

part 'settings_dao.g.dart';

/// Reads and writes the key/value `settings` table.
@DriftAccessor(tables: [AppSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.attachedDatabase);

  /// The stored value for [key], or null when it has never been set.
  Future<String?> valueFor(String key) async {
    final row = await (select(
      appSettings,
    )..where((row) => row.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  /// Stores [value] under [key], replacing any earlier value.
  Future<void> setValue(String key, String value) {
    return into(
      appSettings,
    ).insertOnConflictUpdate(SettingRow(key: key, value: value));
  }
}
