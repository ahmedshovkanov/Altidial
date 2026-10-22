import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/features/projects/widgets/project_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ProjectRow _project({
  required int id,
  String title = 'Alpha',
  int? toneIndex,
  DateTime? deadline,
  int priority = 0,
}) => ProjectRow(
  id: id,
  title: title,
  createdAt: DateTime(2026, 10, 14),
  deadline: deadline,
  targetMinutes: null,
  toneIndex: toneIndex,
  status: 0,
  completedAt: null,
  priority: priority,
);

Widget _host(
  ProjectRow project, {
  int sessionsCount = 0,
  DateTime? lastWorkedAt,
  ({int done, int total})? taskCounts,
}) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: ProjectRowTile(
      project: project,
      plannedMinutes: 60,
      actualMinutes: 30,
      sessionsCount: sessionsCount,
      lastWorkedAt: lastWorkedAt,
      taskCounts: taskCounts,
    ),
  ),
);

void main() {
  testWidgets('null affinity uses neutral ink ring', (tester) async {
    await tester.pumpWidget(_host(_project(id: 1)));
    await tester.pumpAndSettle();

    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    final expected = AppTheme.light.extension<AppColors>()!.ink;
    expect(
      (indicator.valueColor as AlwaysStoppedAnimation<Color>).value,
      expected,
    );
  });

  testWidgets('set affinity uses the tone color', (tester) async {
    await tester.pumpWidget(
      _host(_project(id: 1, toneIndex: Tone.focus.dbIndex)),
    );
    await tester.pumpAndSettle();

    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    final expected = AppTheme.light.extension<ToneColors>()!.fillFor(Tone.focus);
    expect(
      (indicator.valueColor as AlwaysStoppedAnimation<Color>).value,
      expected,
    );
  });

  testWidgets('overdue chip uses the danger color', (tester) async {
    final overdue = DateTime.now().subtract(const Duration(days: 3));
    await tester.pumpWidget(_host(_project(id: 1, deadline: overdue)));
    await tester.pumpAndSettle();

    expect(find.byType(Chip), findsOneWidget);
    final danger = AppTheme.light.extension<AppColors>()!.danger;
    // The chip label carries the danger color when overdue.
    final label = tester.widget<Text>(
      find.descendant(of: find.byType(Chip), matching: find.byType(Text)),
    );
    expect(label.style?.color, danger);
  });

  testWidgets('upcoming deadline chip is not red', (tester) async {
    final future = DateTime.now().add(const Duration(days: 3));
    await tester.pumpWidget(_host(_project(id: 1, deadline: future)));
    await tester.pumpAndSettle();

    expect(find.byType(Chip), findsOneWidget);
    final label = tester.widget<Text>(
      find.descendant(of: find.byType(Chip), matching: find.byType(Text)),
    );
    expect(label.style?.color, isNull);
  });

  testWidgets('row shows sessions and last-worked', (tester) async {
    final worked = DateTime.now().subtract(const Duration(days: 2));
    await tester.pumpWidget(
      _host(_project(id: 1), sessionsCount: 4, lastWorkedAt: worked),
    );
    await tester.pumpAndSettle();

    expect(find.text('4 sessions · worked 2d ago'), findsOneWidget);
  });

  testWidgets('row shows priority dot when priority is set', (tester) async {
    await tester.pumpWidget(_host(_project(id: 1, priority: 2)));
    await tester.pumpAndSettle();

    final dots = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          (widget.decoration as BoxDecoration?)?.shape == BoxShape.circle,
    );
    expect(dots, findsOneWidget);
    expect(tester.getSize(dots), const Size(8, 8));
  });

  testWidgets('row hides priority dot when priority is zero', (tester) async {
    await tester.pumpWidget(_host(_project(id: 1)));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            (widget.decoration as BoxDecoration?)?.shape == BoxShape.circle,
      ),
      findsNothing,
    );
  });

  testWidgets('row shows task counts when provided', (tester) async {
    await tester.pumpWidget(
      _host(_project(id: 1), taskCounts: (done: 1, total: 3)),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 of 3 tasks'), findsOneWidget);
  });

  testWidgets('row hides task counts when null', (tester) async {
    await tester.pumpWidget(_host(_project(id: 1)));
    await tester.pumpAndSettle();

    expect(find.textContaining('tasks'), findsNothing);
  });

  testWidgets('row hides task counts when total is zero', (tester) async {
    await tester.pumpWidget(
      _host(_project(id: 1), taskCounts: (done: 0, total: 0)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('tasks'), findsNothing);
  });
}
