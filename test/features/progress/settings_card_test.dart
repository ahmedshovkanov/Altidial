import 'dart:io';

import 'package:drift/native.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/data/repositories/export_repository.dart';
import 'package:altidial/features/progress/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

/// Fake export repository that builds JSON but writes to a memory buffer instead of a file.
class FakeExportRepository implements ExportRepository {
  FakeExportRepository(this._db);

  final AppDatabase _db;

  @override
  Future<String> buildJson() async {
    final repository = DriftExportRepository(_db);
    return repository.buildJson();
  }

  @override
  Future<String> writeTempFile(String contents) async {
    // Return a fake path without actual file I/O.
    return '/fake/temp/energy-clock-export-${DateTime.now().millisecondsSinceEpoch}.json';
  }
}

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(harness.app(const ProfileScreen()));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -5000),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the stored settings', (tester) async {
    harness.settings.values['theme_mode'] = 'dark';
    harness.settings.values['daily_focus_target'] = '240';
    harness.settings.values['first_day_of_week'] = '7';
    await mount(tester);

    expect(find.text(Strings.themeDark), findsOneWidget);
    expect(find.text(formatDurationMinutes(240)), findsOneWidget);
    expect(find.text(Strings.weekdayLong[6]), findsOneWidget);
  });

  testWidgets('picking a theme stores it', (tester) async {
    await mount(tester);

    await tester.tap(find.byKey(const ValueKey('settings-theme')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.themeLight));
    await tester.pumpAndSettle();

    expect(harness.settings.values['theme_mode'], 'light');
    expect(find.text(Strings.themeLight), findsOneWidget);
  });

  testWidgets('picking a focus target stores its minutes', (tester) async {
    await mount(tester);

    await tester.tap(find.byKey(const ValueKey('settings-focus-target')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(formatDurationMinutes(300)));
    await tester.pumpAndSettle();

    expect(harness.settings.values['daily_focus_target'], '300');
  });

  testWidgets('picking Monday stores the first day', (tester) async {
    harness.settings.values['first_day_of_week'] = '7';
    await mount(tester);

    await tester.tap(find.byKey(const ValueKey('settings-first-day')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.weekdayLong[0]));
    await tester.pumpAndSettle();

    expect(harness.settings.values['first_day_of_week'], '1');
  });

  testWidgets('recalculating rebuilds every score', (tester) async {
    await mount(tester);

    await tester.tap(find.byKey(const ValueKey('settings-recalculate')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.settingsRecalculateConfirm));
    await tester.pumpAndSettle();

    expect(harness.progress.recalculateAllCalls, 1);
    expect(find.text(Strings.settingsRecalculated), findsOneWidget);
  });

  testWidgets('exporting shares a JSON file', (tester) async {
    // Export reads the database layer, so this test brings a memory database.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final exported = ClockHarness(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        exportRepositoryProvider.overrideWithValue(FakeExportRepository(db)),
      ],
    );
    addTearDown(exported.dispose);

    await tester.pumpWidget(exported.app(const ProfileScreen()));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -5000),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-export')));
    await tester.pumpAndSettle();

    expect(exported.share.sharedPaths, hasLength(1));
    final path = exported.share.sharedPaths.single;
    expect(path, endsWith('.json'));
    // The temp file is deleted once the sheet has it.
    expect(File(path).existsSync(), isFalse);
  });

  testWidgets('erasing wipes the database and returns to defaults', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final erased = ClockHarness(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(erased.dispose);
    await db.settingsDao.setValue('theme_mode', 'dark');

    await tester.pumpWidget(erased.app(const ProfileScreen()));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -5000),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-erase')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.settingsEraseConfirm));
    await tester.pumpAndSettle();

    expect(await db.settingsDao.valueFor('theme_mode'), isNull);
    expect(find.text(Strings.settingsErased), findsOneWidget);
  });
}
