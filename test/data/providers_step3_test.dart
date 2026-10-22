import 'package:drift/native.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/calendar_repository.dart';
import 'package:energy_clock/data/repositories/reuse_repository.dart';
import 'package:energy_clock/data/repositories/series_materialiser.dart';
import 'package:energy_clock/data/repositories/series_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the Step 3 repositories are built on the shared database', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    expect(
      container.read(seriesMaterialiserProvider),
      isA<SeriesMaterialiser>(),
    );
    expect(
      container.read(seriesRepositoryProvider),
      isA<DriftSeriesRepository>(),
    );
    expect(
      container.read(reuseRepositoryProvider),
      isA<DriftReuseRepository>(),
    );
    expect(
      container.read(calendarRepositoryProvider),
      isA<DriftCalendarRepository>(),
    );
  });
}
