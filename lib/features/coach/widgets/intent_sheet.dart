import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/features/clock/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom sheet for setting the day's intent (one focus goal).
class IntentSheet extends ConsumerStatefulWidget {
  const IntentSheet({required this.day, super.key});
  final DateTime day;

  static Future<void> show(BuildContext context, {required DateTime day}) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => IntentSheet(day: day),
    );
  }

  @override
  ConsumerState<IntentSheet> createState() => _IntentSheetState();
}

class _IntentSheetState extends ConsumerState<IntentSheet> {
  late final TextEditingController _focus = TextEditingController();
  int? _predicted;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  String? get _focusError => validateFocusGoal(_focus.text);

  Future<void> _save() async {
    final error = validateFocusGoal(_focus.text);
    if (error != null) {
      setState(() {});
      return;
    }
    final goal = _focus.text.trim();
    try {
      await ref
          .read(coachRepositoryProvider)
          .saveIntent(day: widget.day, focusGoal: goal, predictedEnergy: _predicted);
      if (mounted) Navigator.pop(context);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(Strings.coachSaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = isPastDay(widget.day, now: ref.watch(clockProvider));
    // Rebuild on each keystroke so the inline error and Save enable/disables.
    final focusError = _focusError;
    final canSave = focusError == null && !readOnly;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              Strings.coachSetIntent,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _focus,
              readOnly: readOnly,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: Strings.coachFocusHint,
                errorText: focusError,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              Strings.predictedEnergyLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 1; i <= 5; i++)
                  Semantics(
                    label: 'Predicted energy $i of 5',
                    button: true,
                    child: IconButton(
                      icon: Icon(
                        i <= (_predicted ?? 0)
                            ? Icons.circle
                            : Icons.circle_outlined,
                      ),
                      onPressed: readOnly
                          ? null
                          : () => setState(
                                () => _predicted =
                                    (_predicted == i) ? null : i,
                              ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: canSave ? _save : null,
              child: const Text(Strings.save),
            ),
          ],
        ),
      ),
    );
  }
}

String? validateFocusGoal(String value) {
  final v = value.trim();
  if (v.isEmpty || v.length > 120) return Strings.coachFocusError;
  return null;
}
