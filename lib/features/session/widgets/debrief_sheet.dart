import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/features/reflections/model/reflection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 10-second post-session debrief. Returns true if saved.
///
/// The `initial*` values seed the sheet when it reopens a reflection the person
/// already made; leaving them out starts a fresh debrief.
Future<bool> showDebriefSheet(
  BuildContext context,
  WidgetRef ref, {
  required int sessionId,
  required String eventTitle,
  required int activeMinutes,
  int? initialEnergy,
  int? initialFocus,
  List<String> initialTags = const [],
  String? initialNote,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DebriefSheet(
      sessionId: sessionId,
      eventTitle: eventTitle,
      activeMinutes: activeMinutes,
      initialEnergy: initialEnergy,
      initialFocus: initialFocus,
      initialTags: initialTags,
      initialNote: initialNote,
    ),
  );
  return result ?? false;
}

class DebriefSheet extends ConsumerStatefulWidget {
  const DebriefSheet({
    required this.sessionId,
    required this.eventTitle,
    required this.activeMinutes,
    this.initialEnergy,
    this.initialFocus,
    this.initialTags = const [],
    this.initialNote,
    super.key,
  });

  final int sessionId;
  final String eventTitle;
  final int activeMinutes;

  /// What the sheet opens with. Nulls mean "not answered yet" — exactly what a
  /// new debrief looks like, and what saveReflection writes back.
  final int? initialEnergy;
  final int? initialFocus;
  final List<String> initialTags;
  final String? initialNote;

  @override
  ConsumerState<DebriefSheet> createState() => _DebriefSheetState();
}

class _DebriefSheetState extends ConsumerState<DebriefSheet> {
  /// Characters left before the counter turns red, so it cannot drift from
  /// [ReflectionTags.maxNoteLength].
  static const int _noteWarnAt = 10;

  late int? _energy = widget.initialEnergy;
  late int? _focus = widget.initialFocus;
  late final List<String> _tags = [...widget.initialTags];
  late final TextEditingController _note = TextEditingController(text: widget.initialNote ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(sessionRepositoryProvider).saveReflection(
        sessionId: widget.sessionId,
        energyRating: _energy,
        focusRating: _focus,
        tags: _tags,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = Strings.debriefFailed;
      });
    }
  }

  Widget _ratingRow({required int? value, required ValueChanged<int> onPick, required String low, required String high}) {
    return Row(
      children: [
        Text(low, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.appColors.muted)),
        const SizedBox(width: AppSpacing.sm),
        for (var i = 1; i <= 5; i++)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: ChoiceChip(
              label: Text('$i'),
              selected: value == i,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => onPick(i));
              },
            ),
          ),
        const SizedBox(width: AppSpacing.sm),
        Text(high, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.appColors.muted)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(Strings.debriefTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(Strings.debriefSessionLine(widget.eventTitle, widget.activeMinutes), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.appColors.muted)),
            const SizedBox(height: AppSpacing.md),
            Text(Strings.debriefEnergy, style: Theme.of(context).textTheme.labelLarge),
            _ratingRow(value: _energy, onPick: (v) => _energy = v, low: Strings.debriefEnergyLow, high: Strings.debriefEnergyHigh),
            const SizedBox(height: AppSpacing.sm),
            Text(Strings.debriefFocus, style: Theme.of(context).textTheme.labelLarge),
            _ratingRow(value: _focus, onPick: (v) => _focus = v, low: Strings.debriefFocusLow, high: Strings.debriefFocusHigh),
            const SizedBox(height: AppSpacing.sm),
            Text(Strings.debriefTags, style: Theme.of(context).textTheme.labelLarge),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final id in ReflectionTags.allIds)
                  FilterChip(
                    label: Text(Strings.tagLabel(id)),
                    selected: _tags.contains(id),
                    onSelected: (on) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (on) {
                          if (_tags.length >= ReflectionTags.maxTags) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(Strings.debriefTooManyTags)));
                            return;
                          }
                          _tags.add(id);
                        } else {
                          _tags.remove(id);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('debrief-note'),
              controller: _note,
              maxLength: ReflectionTags.maxNoteLength,
              decoration: const InputDecoration(hintText: Strings.debriefNoteHint, counterText: ''),
              maxLines: 2,
              onChanged: (_) => setState(() {}),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                Strings.debriefNoteCounter(_note.text.trim().length, ReflectionTags.maxNoteLength),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _note.text.trim().length >= ReflectionTags.maxNoteLength - _noteWarnAt
                      ? context.appColors.danger
                      : context.appColors.muted,
                ),
              ),
            ),
            if (_error != null) ...[
              Text(_error!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.appColors.danger)),
              const SizedBox(height: AppSpacing.xs),
            ],
            Row(
              children: [
                TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text(Strings.debriefSkip)),
                const Spacer(),
                FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? '…' : Strings.debriefSave)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
