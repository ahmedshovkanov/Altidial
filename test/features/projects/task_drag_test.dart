import 'package:altidial/app/theme/app_theme.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/features/projects/widgets/task_drag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TaskRow _task() => TaskRow(
  id: 1,
  projectId: 1,
  title: 'Ship v1',
  notes: null,
  boardStatus: 1,
  priority: 0,
  estimateMinutes: null,
  dueDate: null,
  plannedDate: null,
  sortOrder: 0,
  blockedReason: null,
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
  completedAt: null,
);

void main() {
  testWidgets('dragging a card onto a zone reports its id', (tester) async {
    int? dropped;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 240,
                child: DraggableTaskCard(task: _task(), cardWidth: 220),
              ),
              Expanded(
                child: TaskDropZone(
                  dropKey: const Key('zone'),
                  onAccept: (id) => dropped = id,
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Ship v1')),
    );
    await tester.pump(taskDragDelay + const Duration(milliseconds: 50));
    await gesture.moveTo(tester.getCenter(find.byKey(const Key('zone'))));
    await tester.pump();

    // Hovering shows the drop hint.
    expect(find.text(Strings.tasksDropHere), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(dropped, 1);
  });

  testWidgets('the lifted card rotates slightly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 240,
                child: DraggableTaskCard(task: _task(), cardWidth: 220),
              ),
              Expanded(
                child: TaskDropZone(
                  dropKey: const Key('zone'),
                  onAccept: (_) {},
                  child: Container(key: const Key('zone-body')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Ship v1')),
    );
    await tester.pump(taskDragDelay + const Duration(milliseconds: 50));
    await gesture.moveTo(tester.getCenter(find.byKey(const Key('zone'))));
    await tester.pump();

    // A small rotation has a small non-zero off-diagonal term (~sin(-0.0175));
    // the pre-existing 45° framework transform (~0.707) is excluded.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Transform &&
            w.transform.entry(1, 0) != 0 &&
            w.transform.entry(1, 0).abs() < 0.1,
      ),
      findsOneWidget,
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('hovering the drop zone does not shift its content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 240,
                child: DraggableTaskCard(task: _task(), cardWidth: 220),
              ),
              Expanded(
                child: TaskDropZone(
                  dropKey: const Key('zone'),
                  onAccept: (_) {},
                  child: Container(key: const Key('zone-body')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final before = tester.getRect(find.byKey(const Key('zone-body')));

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Ship v1')),
    );
    await tester.pump(taskDragDelay + const Duration(milliseconds: 50));
    await gesture.moveTo(tester.getCenter(find.byKey(const Key('zone'))));
    await tester.pump();
    // Let the highlight's AnimatedContainer settle so we measure the hover
    // layout, not a mid-animation frame.
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.getRect(find.byKey(const Key('zone-body'))), before);

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
