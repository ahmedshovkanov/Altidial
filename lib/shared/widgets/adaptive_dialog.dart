import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Asks the user to confirm a destructive action. Shows the native alert on
/// iOS and a Material dialog on every other platform. Returns true only when
/// the user confirms.
///
/// The choice is an explicit check for iOS, not `AlertDialog.adaptive`, which
/// also picks the iOS style on macOS. `flutter test` reports the host's
/// platform, so on a Mac the adaptive widget would change what tests see; this
/// app only ships to iOS, so only iOS gets the native alert.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
}) async {
  final isIos = Theme.of(context).platform == TargetPlatform.iOS;

  final result = isIos
      ? await showCupertinoDialog<bool>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(cancelLabel),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        )
      : await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(cancelLabel),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        );
  return result ?? false;
}
