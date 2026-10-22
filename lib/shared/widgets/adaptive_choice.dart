import 'package:altidial/app/theme/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// One choice offered by [chooseOne].
class ChoiceOption<T> {
  const ChoiceOption({
    required this.label,
    required this.value,
    this.destructive = false,
  });

  final String label;
  final T value;

  /// Shown in the destructive style (red on iOS, the `danger` colour
  /// elsewhere).
  final bool destructive;
}

/// Asks the person to pick one of [options], or cancel. Returns the picked
/// option's value, or null when they cancel or dismiss it. Shows the native
/// action sheet on iOS and a Material dialog on every other platform.
///
/// Like `confirmDestructive`, the choice is an explicit check for iOS, not an
/// `.adaptive` widget, which also picks the iOS style on macOS: `flutter test`
/// reports the host's platform, and this app only ships to iOS.
Future<T?> chooseOne<T>(
  BuildContext context, {
  required String title,
  required List<ChoiceOption<T>> options,
  required String cancelLabel,
  String? body,
}) {
  final isIos = Theme.of(context).platform == TargetPlatform.iOS;

  if (isIos) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(title),
        message: body == null ? null : Text(body),
        actions: [
          for (final option in options)
            CupertinoActionSheetAction(
              isDestructiveAction: option.destructive,
              onPressed: () => Navigator.of(sheetContext).pop(option.value),
              child: Text(option.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(cancelLabel),
        ),
      ),
    );
  }

  return showDialog<T>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(cancelLabel),
        ),
        for (final option in options)
          TextButton(
            style: option.destructive
                ? TextButton.styleFrom(
                    foregroundColor: dialogContext.appColors.danger,
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(option.value),
            child: Text(option.label),
          ),
      ],
    ),
  );
}
