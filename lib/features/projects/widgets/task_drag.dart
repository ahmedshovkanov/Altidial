// lib/features/projects/widgets/task_drag.dart
import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/features/projects/widgets/task_card.dart';
import 'package:flutter/material.dart';

/// How long a card is held before a drag starts. Short enough to feel
/// immediate, long enough that column and board scrolling still work.
const Duration taskDragDelay = Duration(milliseconds: 150);

/// A [TaskCard] that can be picked up and dropped on a [TaskDropZone]. Carries
/// the task id as the drag payload. The lifted card lifts on a shadow and
/// scales slightly; the source slot fades behind a dashed outline.
class DraggableTaskCard extends StatelessWidget {
  const DraggableTaskCard({
    required this.task,
    required this.cardWidth,
    this.onTap,
    super.key,
  });

  final TaskRow task;
  final double cardWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return LongPressDraggable<int>(
      data: task.id,
      delay: taskDragDelay,
      feedback: Material(
        color: AppColors.transparent,
        child: SizedBox(
          width: cardWidth,
          child: Transform.rotate(
            angle: -0.0175,
            child: Transform.scale(
              scale: 1.03,
              child: Card(
                margin: EdgeInsets.zero,
                elevation: 8,
                shadowColor: colors.ink,
                child: TaskCard(task: task),
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: CustomPaint(
        foregroundPainter: _DashedBorder(color: colors.outline),
        child: Opacity(opacity: 0.35, child: TaskCard(task: task)),
      ),
      child: TaskCard(task: task, onTap: onTap),
    );
  }
}

/// A column-sized drop target. Highlights (ink border, faint fill, a centred
/// hint) while a card hovers, then reports the dropped task id.
class TaskDropZone extends StatelessWidget {
  const TaskDropZone({
    required this.onAccept,
    required this.child,
    this.dropKey,
    super.key,
  });

  final ValueChanged<int> onAccept;
  final Widget child;
  final Key? dropKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return DragTarget<int>(
      key: dropKey,
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidate, rejected) {
        final active = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: reduceMotion ? Duration.zero : AppMotion.fast,
          curve: AppMotion.standard,
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: active ? colors.surface : AppColors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          // The border lives in the foreground decoration so growing it on
          // hover never changes the child's padding (and so never nudges the
          // cards by a pixel).
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(
              color: active ? colors.ink : colors.outline,
              width: active ? 2 : 1,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              if (active)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: Center(child: Text(Strings.tasksDropHere)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Paints a dashed rounded-rectangle border at the child's bounds.
class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(AppRadii.card),
        ),
      );
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = distance + dash;
        canvas.drawPath(
          metric.extractPath(
            distance,
            end > metric.length ? metric.length : end,
          ),
          paint,
        );
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}
