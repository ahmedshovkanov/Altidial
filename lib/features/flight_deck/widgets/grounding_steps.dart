// lib/features/flight_deck/widgets/grounding_steps.dart
import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/strings.dart';
import 'package:flutter/material.dart';

/// 5-4-3-2-1 grounding: name 5 things you see, 4 you feel, 3 you hear,
/// 2 you smell, 1 you taste. "Notice one" counts down each sense in turn.
class GroundingSteps extends StatefulWidget {
  const GroundingSteps({super.key});

  @override
  State<GroundingSteps> createState() => _GroundingStepsState();
}

class _GroundingStepsState extends State<GroundingSteps> {
  static const _targets = [5, 4, 3, 2, 1];
  static const _senses = ['see', 'feel', 'hear', 'smell', 'taste'];

  int _step = 0;
  int _left = 5;

  bool get _done => _step >= _targets.length;

  void _notice() {
    if (_done) return;
    setState(() {
      if (_left > 1) {
        _left--;
      } else {
        _step++;
        if (!_done) _left = _targets[_step];
      }
    });
  }

  void _restart() => setState(() {
    _step = 0;
    _left = _targets.first;
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    if (_done) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(Strings.deckGroundingDone,
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _restart,
              child: const Text(Strings.deckGroundingRestart),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(Strings.deckGroundingTitle,
            style: Theme.of(context).textTheme.titleSmall),
        Text(
          'Name $_left thing${_left == 1 ? '' : 's'} you ${_senses[_step]} '
          '(${_step + 1} of ${_targets.length})',
          style: Theme.of(context)
              .textTheme
              .bodyMedium!
              .copyWith(color: colors.muted),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (var i = 0; i < _targets.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: Icon(
                  i < _step
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: colors.muted,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonal(
            onPressed: _notice,
            child: const Text(Strings.deckGroundingNext),
          ),
        ),
      ],
    );
  }
}
