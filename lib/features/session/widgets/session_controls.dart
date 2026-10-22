import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/features/session/model/session_display.dart';
import 'package:altidial/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';

/// The buttons under the ring: pause or resume, add time, finish, abandon.
///
/// Pause is the main button while the time runs. Once the time is used up,
/// Finish takes over, because that is what the person does next.
class SessionControls extends StatelessWidget {
  const SessionControls({
    required this.display,
    required this.stacked,
    required this.onPauseResume,
    required this.onExtend,
    required this.onFinish,
    required this.onAbandon,
    super.key,
  });

  final SessionDisplay display;

  /// One button per row, for large text. Otherwise two rows of buttons.
  final bool stacked;

  final VoidCallback onPauseResume;

  /// Called with the number of seconds to add.
  final void Function(int seconds) onExtend;

  final VoidCallback onFinish;
  final VoidCallback onAbandon;

  @override
  Widget build(BuildContext context) {
    final finishFirst = display.isOvertime && !display.isPaused;

    final pause = AppButton(
      key: const ValueKey('session-pause'),
      label: display.isPaused ? Strings.sessionResume : Strings.sessionPause,
      variant: finishFirst
          ? AppButtonVariant.secondary
          : AppButtonVariant.primary,
      onPressed: onPauseResume,
    );
    final add5 = AppButton(
      key: const ValueKey('session-add-5'),
      label: Strings.sessionAdd5,
      semanticsLabel: Strings.sessionAdd5Semantics,
      variant: AppButtonVariant.secondary,
      onPressed: () => onExtend(5 * 60),
    );
    final add15 = AppButton(
      key: const ValueKey('session-add-15'),
      label: Strings.sessionAdd15,
      semanticsLabel: Strings.sessionAdd15Semantics,
      variant: AppButtonVariant.secondary,
      onPressed: () => onExtend(15 * 60),
    );
    final finish = AppButton(
      key: const ValueKey('session-finish'),
      label: display.isOvertime
          ? Strings.sessionFinish
          : Strings.sessionFinishEarly,
      variant: finishFirst
          ? AppButtonVariant.primary
          : AppButtonVariant.secondary,
      onPressed: onFinish,
    );
    final abandon = AppButton(
      key: const ValueKey('session-abandon'),
      label: Strings.sessionAbandon,
      variant: AppButtonVariant.destructive,
      onPressed: onAbandon,
    );

    const gap = SizedBox(width: AppSpacing.sm, height: AppSpacing.sm);

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          pause,
          gap,
          Row(
            children: [
              Expanded(child: add5),
              gap,
              Expanded(child: add15),
            ],
          ),
          gap,
          finish,
          gap,
          abandon,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(flex: 3, child: pause),
            gap,
            Expanded(flex: 2, child: add5),
            gap,
            Expanded(flex: 2, child: add15),
          ],
        ),
        gap,
        Row(
          children: [
            Expanded(flex: 3, child: finish),
            gap,
            Expanded(flex: 2, child: abandon),
          ],
        ),
      ],
    );
  }
}
