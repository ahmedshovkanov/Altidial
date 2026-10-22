import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/project_repository.dart';
import 'package:energy_clock/features/projects/providers.dart';
import 'package:energy_clock/features/projects/widgets/project_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProjectRepository implements ProjectRepository {
  _FakeProjectRepository(this.rows);

  final List<ProjectRow> rows;
  int _nextId = 100;
  String? lastCreatedTitle;

  @override
  Stream<List<ProjectRow>> watchProjects() =>
      Stream.value(List<ProjectRow>.unmodifiable(rows));

  @override
  Stream<ProjectDetail> watchDetail(int id) =>
      Stream.error(StateError('no detail in picker test'));

  @override
  Future<int> create(String title) async {
    lastCreatedTitle = title;
    final id = _nextId++;
    rows.add(
      ProjectRow(
        id: id,
        title: title,
        createdAt: DateTime(2026, 10, 14),
        status: 0,
        priority: 0,
      ),
    );
    return id;
  }

  @override
  Future<void> updateTitle(int id, String title) async {}

  @override
  Future<void> updateNotes(int id, String? notes) async {}

  @override
  Future<void> updatePriority(int id, int priority) async {}

  @override
  Future<void> updateDeadline(int id, DateTime? deadline) async {}

  @override
  Future<void> updateTarget(int id, int? targetMinutes) async {}

  @override
  Future<void> updateAffinity(int id, int? toneIndex) async {}

  @override
  Future<void> complete(int id) async {}

  @override
  Future<void> reopen(int id) async {}

  @override
  Future<void> archive(int id) async {}

  @override
  Future<void> unarchive(int id) async {}

  @override
  Future<void> deleteAndUnlink(int id) async {}
}

ProjectRow _row(int id, String title, {int status = 0}) => ProjectRow(
  id: id,
  title: title,
  createdAt: DateTime(2026, 10, 14),
  status: status,
  priority: 0,
);

/// Opens [ProjectPickerSheet.show] from a button and captures its result.
/// Returns a box whose single entry starts as a sentinel and becomes the
/// sheet result (possibly null) once the sheet pops.
Future<List<Object?>> _openAndCapture(
  WidgetTester tester,
  _FakeProjectRepository fake,
  int? selectedId,
) async {
  final box = <Object?>[const Object()];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        projectsRepositoryProvider.overrideWithValue(fake),
        projectListProvider.overrideWith((ref) => fake.watchProjects()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                ProjectPickerSheet.show(context, selectedId).then((value) {
                  box[0] = value;
                });
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(find.text(Strings.projectPickerTitle), findsOneWidget);
  return box;
}

void main() {
  testWidgets('picker lists active projects and selects one', (tester) async {
    final fake = _FakeProjectRepository([
      _row(1, 'Alpha'),
      _row(2, 'Beta'),
      _row(3, 'Done', status: 1),
    ]);

    final box = await _openAndCapture(tester, fake, null);

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    // Non-active projects are hidden.
    expect(find.text('Done'), findsNothing);

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();

    expect(box[0], 1);
  });

  testWidgets('picker clears with No project', (tester) async {
    final fake = _FakeProjectRepository([_row(1, 'Alpha')]);

    final box = await _openAndCapture(tester, fake, 1);

    expect(find.text(Strings.projectNone), findsOneWidget);

    await tester.tap(find.text(Strings.projectNone));
    await tester.pumpAndSettle();

    expect(box[0], isNull);
  });

  testWidgets('picker lists active projects and creates one inline', (
    tester,
  ) async {
    final fake = _FakeProjectRepository([_row(1, 'Alpha')]);

    final box = await _openAndCapture(tester, fake, null);

    await tester.enterText(find.byType(TextField), 'Portfolio');
    await tester.pump();
    await tester.tap(find.text(Strings.projectNew));
    await tester.pumpAndSettle();

    expect(fake.lastCreatedTitle, 'Portfolio');
    expect(box[0], isNonZero);
  });

  testWidgets('overlong title is rejected inline and disables save', (
    tester,
  ) async {
    final fake = _FakeProjectRepository([_row(1, 'Alpha')]);
    await _openAndCapture(tester, fake, null);

    await tester.enterText(find.byType(TextField), 'a' * 81);
    await tester.pump();

    // Inline validation error; the create button is disabled.
    expect(find.text('Keep it under 80 characters'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, Strings.projectNew),
    );
    expect(button.onPressed, isNull);
    expect(fake.lastCreatedTitle, isNull);
  });
}
