import 'package:altidial/app/onboarding/onboarding_providers.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/repositories/progress_repository.dart';
import 'package:altidial/data/repositories/roundup_repository.dart';
import 'package:altidial/data/repositories/settings_repository.dart';
import 'package:altidial/debug/debug_constants.dart';
import 'package:altidial/debug/demo_generator.dart';
import 'package:flutter/foundation.dart';

abstract interface class DemoSeeder {
  Future<void> seed();
}

class DriftDemoSeeder implements DemoSeeder {
  DriftDemoSeeder(
    this._db,
    this._generator,
    this._settings,
    this._progress,
    this._roundups,
  );

  final AppDatabase _db;
  final DemoGenerator _generator;
  final SettingsRepository _settings;
  final ProgressRepository _progress;
  final RoundupRepository _roundups;

  @override
  Future<void> seed() async {
    final data = _generator.generate();

    await _db.transaction(() async {
      await _db.resetAll();
      await _db.batch((batch) {
        batch.insertAll(_db.projects, data.projects);
        batch.insertAll(_db.events, data.events);
        batch.insertAll(_db.sessions, data.sessions);
        batch.insertAll(_db.tasks, data.tasks);
        batch.insertAll(_db.dayTemplates, data.templates);
        batch.insertAll(_db.dayTemplateItems, data.templateItems);
        batch.insertAll(_db.coachIntents, data.intents);
        batch.insertAll(_db.coachReviews, data.reviews);
        batch.insertAll(_db.badgeUnlocks, data.badgeUnlocks);
      });
      await _settings.setBool(onboardingDoneKey, true);
      await _settings.setBool(debugModeKey, true);
    });

    try {
      await _progress.recalculateAll();
    } on Object catch (error) {
      debugPrint('Altidial: demo progress rebuild failed: $error');
    }
    try {
      await _roundups.ensureCurrent();
    } on Object catch (error) {
      debugPrint('Altidial: demo roundup rebuild failed: $error');
    }
  }
}
