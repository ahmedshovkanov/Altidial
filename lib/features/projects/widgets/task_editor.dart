// lib/features/projects/widgets/task_editor.dart
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/task_status.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/repositories/task_repository.dart';
import 'package:altidial/features/projects/model/task_board.dart';
import 'package:altidial/features/projects/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the rich task editor for [task] as a scroll-controlled bottom sheet.
/// Title, notes and estimate are committed on Save; the chips write through
/// immediately (matching the project detail's deadline/priority chips).
Future<void> showTaskEditor(
  BuildContext context,
  WidgetRef ref, {
  required TaskRow task,
}) {
  final repository = ref.read(tasksRepositoryProvider);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _TaskEditorSheet(task: task, repository: repository),
  );
}

/// Minutes as editable hours: whole hours without decimals (`120` → `2`),
/// fractions trimmed (`90` → `1.5`, `45` → `0.75`), blank for no estimate.
String hoursText(int? minutes) {
  if (minutes == null) return '';
  final hours = minutes / 60;
  if (hours == hours.roundToDouble()) return hours.toInt().toString();
  var text = hours.toStringAsFixed(2);
  while (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  if (text.endsWith('.')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}

class _TaskEditorSheet extends StatefulWidget {
  const _TaskEditorSheet({required this.task, required this.repository});

  final TaskRow task;
  final TaskRepository repository;

  @override
  State<_TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<_TaskEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(
    text: widget.task.title,
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.task.notes ?? '',
  );
  late final TextEditingController _estimate = TextEditingController(
    text: hoursText(widget.task.estimateMinutes),
  );

  late TaskStatus _status = TaskStatus.fromDb(widget.task.boardStatus);
  late int _priority = widget.task.priority;
  late DateTime? _due = widget.task.dueDate;
  late DateTime? _planned = widget.task.plannedDate;
  bool _busy = false;

  int get _id => widget.task.id;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _estimate.dispose();
    super.dispose();
  }

  /// Runs [action]; on failure keeps the sheet open and surfaces a snackbar.
  /// Returns whether it succeeded.
  Future<bool> _attempt(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } on Object {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(Strings.tasksSaveFailed)));
      return false;
    }
  }

  Future<void> _setStatus(TaskStatus status) async {
    if (status == _status) return;
    setState(() => _status = status);
    await _attempt(() => widget.repository.move(_id, status));
  }

  Future<void> _setPriority(int priority) async {
    if (priority == _priority) return;
    setState(() => _priority = priority);
    await _attempt(() => widget.repository.updatePriority(_id, priority));
  }

  Future<void> _setDue(DateTime? date) async {
    setState(() => _due = date);
    await _attempt(() => widget.repository.updateDueDate(_id, date));
  }

  Future<void> _setPlanned(DateTime? date) async {
    setState(() => _planned = date);
    await _attempt(() => widget.repository.updatePlannedDate(_id, date));
  }

  Future<DateTime?> _pick(DateTime? initial) {
    final today = startOfDay(DateTime.now());
    return showDatePicker(
      context: context,
      initialDate: initial ?? today,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
  }

  Future<void> _pickDue() async {
    final picked = await _pick(_due);
    if (picked != null) await _setDue(picked);
  }

  Future<void> _pickPlanned() async {
    final picked = await _pick(_planned);
    if (picked != null) await _setPlanned(picked);
  }

  /// Blank clears the estimate; otherwise parse decimal hours and range-check.
  String? _validateEstimate(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final hours = double.tryParse(text);
    if (hours == null) return Strings.tasksEstimateInvalid;
    return validateTaskEstimate((hours * 60).round());
  }

  int? get _estimateMinutes {
    final text = _estimate.text.trim();
    return text.isEmpty ? null : (double.parse(text) * 60).round();
  }

  Future<void> _save() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await widget.repository.updateTitle(_id, _title.text.trim());
      await widget.repository.updateNotes(_id, _notes.text);
      await widget.repository.updateEstimate(_id, _estimateMinutes);
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(Strings.tasksSaveFailed)));
      return;
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(Strings.tasksDeleteTitle),
        content: const Text(Strings.tasksDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(Strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(Strings.projectsDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!await _attempt(() => widget.repository.remove(_id))) return;
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg + bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(Strings.tasksEditTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('task-title'),
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: Strings.tasksTitleLabel,
                ),
                validator: (value) => validateTaskTitle(value ?? ''),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                key: const Key('task-notes'),
                controller: _notes,
                maxLength: maxTaskNotesLength,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: Strings.tasksNotesTitle,
                  hintText: Strings.tasksNotesHint,
                ),
                validator: (value) => validateTaskNotes(value ?? ''),
              ),
              const SizedBox(height: AppSpacing.sm),
              _SectionLabel(Strings.tasksStatusTitle),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final status in TaskStatus.values)
                    ChoiceChip(
                      key: Key('task-status-${status.name}'),
                      label: Text(Strings.tasksStatusLabels[status.index]),
                      selected: _status == status,
                      onSelected: (_) => _setStatus(status),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _SectionLabel(Strings.tasksPriorityTitle),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (var i = 0; i < Strings.tasksPriorityLabels.length; i++)
                    ChoiceChip(
                      key: Key('task-priority-$i'),
                      label: Text(Strings.tasksPriorityLabels[i]),
                      selected: _priority == i,
                      onSelected: (_) => _setPriority(i),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                key: const Key('task-estimate'),
                controller: _estimate,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: Strings.tasksEstimateTitle,
                  hintText: Strings.tasksEstimateHint,
                ),
                validator: _validateEstimate,
              ),
              const SizedBox(height: AppSpacing.sm),
              _SectionLabel(Strings.tasksDueTitle, value: _due),
              _DateChips(
                prefix: 'task-due',
                value: _due,
                onSet: _setDue,
                onPick: _pickDue,
              ),
              const SizedBox(height: AppSpacing.sm),
              _SectionLabel(Strings.tasksPlannedTitle, value: _planned),
              _DateChips(
                prefix: 'task-planned',
                value: _planned,
                onSet: _setPlanned,
                onPick: _pickPlanned,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  TextButton(
                    onPressed: _busy ? null : _delete,
                    child: const Text(Strings.projectsDelete),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: const Text(Strings.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One section heading, with the current date shown beside it when set.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {this.value});

  final String label;
  final DateTime? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Text(label, style: theme.textTheme.titleSmall),
          if (value != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(Strings.friendlyDate(value!), style: theme.textTheme.labelSmall),
          ],
        ],
      ),
    );
  }
}

/// Today / Tomorrow / Next week / Pick a date, plus Clear when a date is set.
/// [prefix] namespaces the chip keys so the due and planned rows stay distinct.
class _DateChips extends StatelessWidget {
  const _DateChips({
    required this.prefix,
    required this.value,
    required this.onSet,
    required this.onPick,
  });

  final String prefix;
  final DateTime? value;
  final ValueChanged<DateTime?> onSet;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final today = startOfDay(DateTime.now());
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        ActionChip(
          key: Key('$prefix-today'),
          label: const Text(Strings.projectsDeadlineToday),
          onPressed: () => onSet(today),
        ),
        ActionChip(
          key: Key('$prefix-tomorrow'),
          label: const Text(Strings.projectsDeadlineTomorrow),
          onPressed: () => onSet(DateTime(today.year, today.month, today.day + 1)),
        ),
        ActionChip(
          key: Key('$prefix-nextweek'),
          label: const Text(Strings.projectsDeadlineNextWeek),
          onPressed: () => onSet(DateTime(today.year, today.month, today.day + 7)),
        ),
        ActionChip(
          key: Key('$prefix-pick'),
          label: const Text(Strings.tasksPickDate),
          onPressed: onPick,
        ),
        if (value != null)
          ActionChip(
            key: Key('$prefix-clear'),
            label: const Text(Strings.projectsDeadlineClear),
            onPressed: () => onSet(null),
          ),
      ],
    );
  }
}
