import 'package:altidial/core/strings.dart';
import 'package:altidial/data/repositories/reuse_repository.dart';
import 'package:flutter/material.dart';

/// Asks for a template's name. Returns it trimmed, or null if the person
/// cancels. A name is required, and at most [maxTemplateNameLength] long.
Future<String?> askTemplateName(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _TemplateNameDialog(),
  );
}

class _TemplateNameDialog extends StatefulWidget {
  const _TemplateNameDialog();

  @override
  State<_TemplateNameDialog> createState() => _TemplateNameDialogState();
}

class _TemplateNameDialogState extends State<_TemplateNameDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = Strings.templateNameRequired);
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(Strings.templateNameTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: maxTemplateNameLength,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: Strings.templateNameLabel,
          hintText: Strings.templateNameHint,
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Strings.cancel),
        ),
        TextButton(onPressed: _submit, child: const Text(Strings.save)),
      ],
    );
  }
}
