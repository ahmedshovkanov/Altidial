import 'dart:async';

import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/app/theme/tone_colors.dart';
import 'package:altidial/core/flight/flight_details.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/recurrence/recurrence_rule.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/features/clock/data/event_repository.dart';
import 'package:altidial/features/clock/widgets/edit_scope.dart';
import 'package:altidial/features/clock/widgets/repeat_picker.dart';
import 'package:altidial/features/projects/providers.dart';
import 'package:altidial/features/projects/widgets/project_picker_sheet.dart';
import 'package:altidial/shared/widgets/app_button.dart';
import 'package:altidial/shared/widgets/press_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EventSheet extends ConsumerStatefulWidget {
  const EventSheet({
    required this.day,
    required this.initialRange,
    this.existing,
    super.key,
  });

  final DateTime day;
  final MinuteRange initialRange;

  /// Non-null puts the sheet in edit mode.
  final CalendarEvent? existing;

  static Future<void> show(
    BuildContext context, {
    required DateTime day,
    required MinuteRange initialRange,
    CalendarEvent? existing,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          EventSheet(day: day, initialRange: initialRange, existing: existing),
    );
  }

  @override
  ConsumerState<EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends ConsumerState<EventSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late Tone _tone = widget.existing?.tone ?? Tone.focus;
  late MinuteRange _range = widget.initialRange;
  late int? _projectId = widget.existing?.projectId;
  bool _isFlight = false;
  late final TextEditingController _flightNumber = TextEditingController();
  late final TextEditingController _from = TextEditingController();
  late final TextEditingController _to = TextEditingController();

  String? _titleError;
  String? _saveError;

  /// How the event repeats. For an occurrence of a series it becomes the
  /// series' rule once that has loaded. [_originalRule] is what it started as,
  /// to tell whether the person changed it.
  RecurrenceRule _rule = const RecurrenceRule.none();
  RecurrenceRule _originalRule = const RecurrenceRule.none();
  Future<void>? _ruleLoad;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing?.isFlight == true) {
      _isFlight = true;
      _flightNumber.text = existing?.flightNumber ?? '';
      _from.text = existing?.fromCode ?? '';
      _to.text = existing?.toCode ?? '';
    }
    final seriesId = widget.existing?.seriesId;
    if (seriesId != null) _ruleLoad = _loadRule(seriesId);
  }

  @override
  void dispose() {
    _title.dispose();
    _flightNumber.dispose();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  /// Reads the series' rule. If it cannot be read, or the series is gone, the
  /// event is treated as not repeating.
  Future<void> _loadRule(int seriesId) async {
    RecurrenceRule? loaded;
    try {
      loaded = await ref.read(seriesRepositoryProvider).ruleFor(seriesId);
    } on Object {
      loaded = null;
    }
    if (!mounted || loaded == null) return;
    final rule = loaded;
    setState(() {
      // Keep a choice the person made before the rule arrived.
      if (_rule == _originalRule) _rule = rule;
      _originalRule = rule;
    });
  }

  void _nudgeStart(int delta) {
    final start = snapMinute(
      _range.start + delta,
    ).clamp(0, _range.end - minEventMinutes);
    setState(() => _range = MinuteRange(start, _range.end));
  }

  void _nudgeEnd(int delta) {
    final end = snapMinute(
      _range.end + delta,
    ).clamp(_range.start + minEventMinutes, minutesPerDay);
    setState(() => _range = MinuteRange(_range.start, end));
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = Strings.titleRequired);
      return;
    }
    if (_isFlight) {
      final fromOk = isValidAirportCode(_from.text);
      final toOk = isValidAirportCode(_to.text);
      final numberOk = isValidFlightNumber(_flightNumber.text);
      if (!fromOk || !toOk || !numberOk) {
        setState(() {}); // field-level errorText above already shows; stay open
        return;
      }
      if (_range.end <= _range.start) {
        setState(() => _saveError = Strings.flightOvernightError);
        return;
      }
    }
    setState(() {
      _titleError = null;
      _saveError = null;
    });

    try {
      final existing = widget.existing;
      if (existing == null) {
        await _create(title);
      } else if (!await _update(existing, title)) {
        return;
      }
    } on RingOverflowException {
      setState(() => _saveError = Strings.ringOverflow);
      return;
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _create(String title) async {
    if (_rule.repeats && !_isFlight) {
      // Repeating events stay unlinked: the series id is not an event row,
      // so there is nothing to link. The picker row is disabled while a
      // repeat rule is set (see _projectRow).
      await ref
          .read(seriesRepositoryProvider)
          .createRecurring(
            day: widget.day,
            title: title,
            tone: _tone,
            range: _range,
            rule: _rule,
          );
    } else {
      await ref
          .read(eventRepositoryProvider)
          .createEvent(
            day: widget.day,
            title: title,
            tone: _tone,
            range: _range,
            isFlight: _isFlight,
            flightNumber: _isFlight && _flightNumber.text.trim().isNotEmpty
                ? normalizeFlightNumber(_flightNumber.text)
                : null,
            fromCode: _isFlight ? normalizeAirportCode(_from.text) : null,
            toCode: _isFlight ? normalizeAirportCode(_to.text) : null,
            projectId: _projectId,
          );
    }
  }

  /// Saves the edit of [existing]. Returns false if the person cancelled the
  /// question of how far it reaches.
  Future<bool> _update(CalendarEvent existing, String title) async {
    // A quick Save must not read a rule that has not arrived yet.
    await _ruleLoad;
    if (!mounted) return false;

    final events = ref.read(eventRepositoryProvider);
    final series = ref.read(seriesRepositoryProvider);

    Future<void> thisEventOnly() async {
      await events.moveEvent(id: existing.id, day: widget.day, range: _range);
      await events.updateDetails(
        id: existing.id,
        title: title,
        tone: _isFlight ? Tone.inbox : _tone,
      );
      await events.updateFlight(
        id: existing.id,
        isFlight: _isFlight,
        flightNumber: _isFlight && _flightNumber.text.trim().isNotEmpty
            ? normalizeFlightNumber(_flightNumber.text)
            : null,
        fromCode: _isFlight ? normalizeAirportCode(_from.text) : null,
        toCode: _isFlight ? normalizeAirportCode(_to.text) : null,
      );
      if (_projectId != existing.projectId) {
        await events.updateProject(id: existing.id, projectId: _projectId);
      }
    }

    Future<void> fromHere() async {
      await series.updateFromHere(
        eventId: existing.id,
        title: title,
        tone: _tone,
        range: _range,
        rule: _rule,
      );
      if (_projectId != existing.projectId) {
        if (existing.seriesId != null) {
          // Bulk first for any remaining future rows of the old series, then
          // the edited row itself (which now carries the new split series).
          await events.updateProjectForSeries(
            seriesId: existing.seriesId!,
            fromDate: existing.date,
            projectId: _projectId,
          );
          await events.updateProject(id: existing.id, projectId: _projectId);
        } else {
          await events.updateProject(id: existing.id, projectId: _projectId);
        }
      }
    }

    if (existing.seriesId == null) {
      // A one-off event: it stays one, or it starts repeating.
      await (_rule.repeats ? fromHere() : thisEventOnly());
      return true;
    }

    final ruleChanged = _rule != _originalRule;
    final unchanged =
        !ruleChanged &&
        title == existing.title &&
        _tone == existing.tone &&
        _range == existing.range &&
        _projectId == existing.projectId;
    if (unchanged) return true;

    final scope = await askEditScope(context, ruleChanged: ruleChanged);
    if (scope == null) return false;
    await (scope == EditScope.thisEvent ? thisEventOnly() : fromHere());
    return true;
  }

  /// The project picker row: below the tone buttons, and also shown for
  /// flights (flights count as Inbox like any event). Disabled on past
  /// read-only days and for new repeating events — repeating creates stay
  /// unlinked (series carry no project), per the spec's non-goal. Edits keep
  /// the picker so the edit-all-future path can relink a series range.
  Widget _projectRow(bool readOnly, String? projectTitle) {
    final repeatingCreate =
        widget.existing == null && _rule.repeats && !_isFlight;
    final disabled = readOnly || repeatingCreate;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text(Strings.projectPickerTitle),
      subtitle: Text(
        repeatingCreate
            ? Strings.projectRepeatingHint
            : (projectTitle ?? Strings.projectNone),
      ),
      trailing: const Icon(Icons.chevron_right),
      enabled: !disabled,
      onTap: disabled
          ? null
          : () async {
              final picked = await ProjectPickerSheet.show(context, _projectId);
              if (!context.mounted) return;
              setState(() => _projectId = picked);
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final readOnly = isPastDay(widget.day);
    final projects = ref.watch(projectListProvider).valueOrNull;
    String? projectTitle;
    if (_projectId != null && projects != null) {
      for (final p in projects) {
        if (p.id == _projectId) {
          projectTitle = p.title;
          break;
        }
      }
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xs,
        AppSpacing.xl,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? Strings.newEvent : Strings.editEvent,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            style: theme.textTheme.titleMedium,
            decoration: InputDecoration(
              filled: true,
              fillColor: colors.page,
              labelText: Strings.titleLabel,
              hintText: Strings.titleHint,
              errorText: _titleError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.control),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (!_isFlight) ...[
            Text(Strings.toneLabel, style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                for (final tone in Tone.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _ToneTile(
                        tone: tone,
                        selected: tone == _tone,
                        onTap: () => setState(() => _tone = tone),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          _projectRow(readOnly, projectTitle),
          const SizedBox(height: AppSpacing.xl),
          if (widget.existing?.seriesId == null)
            SwitchListTile(
              key: const Key('flight-toggle'),
              title: const Text(Strings.flightToggle),
              secondary: const Icon(Icons.flight),
              value: _isFlight,
              onChanged: (v) => setState(() {
                _isFlight = v;
                if (v) _tone = Tone.inbox;
              }),
            ),
          if (_isFlight) ...[
            TextField(
              key: const Key('flight-number-field'),
              controller: _flightNumber,
              decoration: InputDecoration(
                labelText: Strings.flightNumberLabel,
                hintText: Strings.flightNumberHint,
                errorText:
                    _flightNumber.text.isEmpty ||
                        isValidFlightNumber(_flightNumber.text)
                    ? null
                    : Strings.flightNumberError,
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('flight-from-field'),
                    controller: _from,
                    decoration: InputDecoration(
                      labelText: Strings.flightFromLabel,
                      hintText: Strings.flightAirportHint,
                      errorText:
                          _from.text.isEmpty || isValidAirportCode(_from.text)
                          ? null
                          : Strings.flightAirportError,
                    ),
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 3,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('flight-to-field'),
                    controller: _to,
                    decoration: InputDecoration(
                      labelText: Strings.flightToLabel,
                      hintText: Strings.flightAirportHint,
                      errorText:
                          _to.text.isEmpty || isValidAirportCode(_to.text)
                          ? null
                          : Strings.flightAirportError,
                    ),
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 3,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ],
          _TimeRow(
            label: Strings.startLabel,
            minute: _range.start,
            onDecrease: () => _nudgeStart(-snapStepMinutes),
            onIncrease: () => _nudgeStart(snapStepMinutes),
          ),
          const SizedBox(height: AppSpacing.sm),
          _TimeRow(
            label: Strings.endLabel,
            minute: _range.end,
            onDecrease: () => _nudgeEnd(-snapStepMinutes),
            onIncrease: () => _nudgeEnd(snapStepMinutes),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.page,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 6,
                ),
                child: Text(
                  formatDurationMinutes(_range.durationMinutes),
                  style: theme.textTheme.labelLarge,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (!_isFlight)
            RepeatPicker(
              rule: _rule,
              firstDay: widget.day,
              onChanged: (rule) => setState(() => _rule = rule),
            ),
          if (_saveError != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _saveError!,
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.danger),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton(label: Strings.save, onPressed: _save),
        ],
      ),
    );
  }
}

/// One of the three tone choices: the tone's colour, its name, and, when
/// selected, a 3 pt ink outline and a check.
class _ToneTile extends StatelessWidget {
  const _ToneTile({
    required this.tone,
    required this.selected,
    required this.onTap,
  });

  final Tone tone;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.toneColors.paletteFor(tone);
    final colors = context.appColors;

    return Semantics(
      button: true,
      selected: selected,
      label: tone.label,
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        onTap: () {
          if (!selected) unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.solid,
            borderRadius: BorderRadius.circular(AppRadii.control),
            border: Border.all(
              color: selected ? colors.ink : AppColors.transparent,
              width: 3,
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tone.label,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall!.copyWith(color: palette.onSolid),
                  ),
                  if (selected)
                    Icon(Icons.check_rounded, size: 18, color: palette.onSolid),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A label, the time in large type, and round minus and plus buttons.
class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.minute,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String label;
  final int minute;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
        _StepperButton(
          icon: Icons.remove,
          tooltip: Strings.stepperDecrease(label),
          onPressed: onDecrease,
        ),
        SizedBox(
          width: 96,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatMinuteOfDay(minute),
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall,
            ),
          ),
        ),
        _StepperButton(
          icon: Icons.add,
          tooltip: Strings.stepperIncrease(label),
          onPressed: onIncrease,
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: colors.ink.withValues(alpha: 0.08),
        foregroundColor: colors.ink,
        minimumSize: const Size(44, 44),
        shape: const CircleBorder(),
      ),
    );
  }
}
