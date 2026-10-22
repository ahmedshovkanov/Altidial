import 'dart:convert';
import 'dart:io';

import 'package:energy_clock/data/database.dart';
import 'package:share_plus/share_plus.dart';

/// The full-database JSON export (spec §9.7): every table's rows under their
/// own key, plus when the export was taken.
abstract interface class ExportRepository {
  Future<String> buildJson();

  /// Writes [contents] to a temp file and returns its path. The caller shares
  /// it, then deletes it.
  Future<String> writeTempFile(String contents);
}

class DriftExportRepository implements ExportRepository {
  DriftExportRepository(this._db);

  final AppDatabase _db;

  @override
  Future<String> buildJson() async {
    final settings = <String, String>{};
    for (final row in await _db.select(_db.appSettings).get()) {
      settings[row.key] = row.value;
    }
    return jsonEncode({
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': settings,
      'events': [
        for (final row in await _db.select(_db.events).get()) row.toJson(),
      ],
      'eventSeries': [
        for (final row in await _db.select(_db.eventSeries).get()) row.toJson(),
      ],
      'sessions': [
        for (final row in await _db.select(_db.sessions).get()) row.toJson(),
      ],
      'dayTemplates': [
        for (final row in await _db.select(_db.dayTemplates).get())
          row.toJson(),
      ],
      'dayScores': [
        for (final row in await _db.select(_db.dayScores).get()) row.toJson(),
      ],
      'progress': [
        for (final row in await _db.select(_db.progress).get()) row.toJson(),
      ],
      'badgeUnlocks': [
        for (final row in await _db.select(_db.badgeUnlocks).get())
          row.toJson(),
      ],
      'weeklyRoundups': [
        for (final row in await _db.select(_db.weeklyRoundups).get())
          row.toJson(),
      ],
    });
  }

  @override
  Future<String> writeTempFile(String contents) async {
    final file = File(
      '${Directory.systemTemp.path}/energy-clock-export-'
      '${DateTime.now().millisecondsSinceEpoch}.json',
    );
    await file.writeAsString(contents);
    return file.path;
  }
}

/// Opens the platform share sheet for one file. Faked in tests.
abstract interface class ShareService {
  Future<void> shareFile(String path, {String? subject});
}

class SharePlusService implements ShareService {
  @override
  Future<void> shareFile(String path, {String? subject}) => SharePlus.instance
      .share(ShareParams(files: [XFile(path)], subject: subject));
}
