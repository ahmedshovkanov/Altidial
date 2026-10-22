import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/features/projects/model/project_progress.dart';
import 'package:altidial/features/projects/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Internal sheet result: null means the sheet was dismissed (keep selection),
/// otherwise [projectId] is the picked project (null for "no project").
class _PickerResult {
  const _PickerResult(this.projectId);
  final int? projectId;
}

/// Bottom sheet listing active projects plus inline `+ New project` creation.
///
/// Returns the picked project id, null for "no project", or the previous
/// [selectedId] when dismissed (so callers can blindly assign the result).
class ProjectPickerSheet extends ConsumerStatefulWidget {
  const ProjectPickerSheet({required this.selectedId, super.key});
  final int? selectedId;

  static Future<int?> show(BuildContext context, int? selectedId) async {
    final result = await showModalBottomSheet<_PickerResult>(
      context: context,
      showDragHandle: true,
      builder: (_) => ProjectPickerSheet(selectedId: selectedId),
    );
    if (result == null) return selectedId;
    return result.projectId;
  }

  @override
  ConsumerState<ProjectPickerSheet> createState() => _ProjectPickerSheetState();
}

class _ProjectPickerSheetState extends ConsumerState<ProjectPickerSheet> {
  late final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? get _nameError => validateProjectTitle(_name.text);

  Future<void> _create() async {
    final error = validateProjectTitle(_name.text);
    if (error != null) {
      setState(() {});
      return;
    }
    final title = _name.text.trim();
    try {
      final id = await ref.read(projectsRepositoryProvider).create(title);
      if (mounted) Navigator.pop(context, _PickerResult(id));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(Strings.projectsSaveFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectListProvider);
    // Rebuild on each keystroke so the inline-create button enables/disables.
    final nameError = _nameError;
    final canCreate = nameError == null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              Strings.projectPickerTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            ...switch (projects) {
              AsyncData(:final value) => [
                for (final ProjectRow p in value.where((p) => p.status == 0))
                  ListTile(
                    title: Text(p.title),
                    trailing: p.id == widget.selectedId
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.pop(context, _PickerResult(p.id)),
                  ),
              ],
              AsyncError(:final error) => [Text('$error')],
              _ => const [
                Center(child: CircularProgressIndicator.adaptive()),
              ],
            },
            ListTile(
              title: const Text(Strings.projectNone),
              onTap: () =>
                  Navigator.pop(context, const _PickerResult(null)),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: Strings.projectNameHint,
                errorText: _name.text.isEmpty ? null : nameError,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: canCreate ? _create : null,
              child: const Text(Strings.projectNew),
            ),
          ],
        ),
      ),
    );
  }
}
