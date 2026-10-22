import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom sheet for reviewing the day: an energy score (1–5) plus one
/// optional win.
class ReviewSheet extends ConsumerStatefulWidget {
  const ReviewSheet({required this.day, super.key});
  final DateTime day;

  static Future<void> show(BuildContext context, {required DateTime day}) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => ReviewSheet(day: day),
    );
  }

  @override
  ConsumerState<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<ReviewSheet> {
  int? _energy;
  late final TextEditingController _win = TextEditingController();

  @override
  void dispose() {
    _win.dispose();
    super.dispose();
  }

  String? get _energyError => _energy == null ? Strings.coachEnergyError : null;
  String? get _winError => validateWinText(_win.text);

  Future<void> _save() async {
    final energy = _energy;
    if (energy == null) {
      setState(() {});
      return;
    }
    final winError = validateWinText(_win.text);
    if (winError != null) {
      setState(() {});
      return;
    }
    final win = _win.text.trim();
    try {
      await ref
          .read(coachRepositoryProvider)
          .saveReview(
            day: widget.day,
            energy: energy,
            winText: win.isEmpty ? null : win,
          );
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
    // Rebuild on each keystroke/tap so errors and Save stay in sync.
    final energyError = _energyError;
    final winError = _winError;
    final canSave = energyError == null && winError == null && !readOnly;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              Strings.coachReviewTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 1; i <= 5; i++)
                  Semantics(
                    label: 'Energy $i of 5',
                    button: true,
                    child: IconButton(
                      icon: Icon(
                        i <= (_energy ?? 0)
                            ? Icons.circle
                            : Icons.circle_outlined,
                      ),
                      onPressed: readOnly
                          ? null
                          : () => setState(() => _energy = i),
                    ),
                  ),
              ],
            ),
            if (energyError != null) Text(energyError),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _win,
              readOnly: readOnly,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: Strings.coachWinHint,
                errorText: winError,
              ),
              onChanged: (_) => setState(() {}),
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

String? validateWinText(String? value) {
  final v = (value ?? '').trim();
  if (v.length > 140) return Strings.coachWinHint;
  return null;
}
