import 'dart:async';

import 'package:altidial/app/onboarding/onboarding_providers.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/debug/debug_providers.dart';
import 'package:altidial/shared/widgets/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> activateDebug(BuildContext context, WidgetRef ref) async {
  final active = await ref.read(debugModeProvider.future);
  if (!context.mounted) return;
  if (active) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(Strings.debugAlreadyOn)));
    return;
  }
  final confirmed = await confirmDestructive(
    context,
    title: Strings.debugEnableTitle,
    body: Strings.debugEnableBody,
    confirmLabel: Strings.debugEnableConfirm,
    cancelLabel: Strings.cancel,
  );
  if (!confirmed || !context.mounted) return;
  await _seed(context, ref, Strings.debugLoaded);
}

Future<void> regenerateDemo(BuildContext context, WidgetRef ref) async {
  final confirmed = await confirmDestructive(
    context,
    title: Strings.debugRegenerateTitle,
    body: Strings.debugRegenerateBody,
    confirmLabel: Strings.debugRegenerateConfirm,
    cancelLabel: Strings.cancel,
  );
  if (!confirmed || !context.mounted) return;
  await _seed(context, ref, Strings.debugRegenerated);
}

Future<void> exitDebug(BuildContext context, WidgetRef ref) async {
  final confirmed = await confirmDestructive(
    context,
    title: Strings.debugExitTitle,
    body: Strings.debugExitBody,
    confirmLabel: Strings.debugExitConfirm,
    cancelLabel: Strings.cancel,
  );
  if (!confirmed || !context.mounted) return;

  await ref.read(appDatabaseProvider).resetAll();
  await ref.read(settingsRepositoryProvider).setBool(onboardingDoneKey, false);
  await ref.read(debugModeProvider.notifier).set(false);
  ref.invalidate(onboardingDoneProvider);
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text(Strings.debugExited)));
}

Future<void> _seed(BuildContext context, WidgetRef ref, String success) async {
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
    ),
  );

  try {
    await ref.read(demoSeederProvider).seed();
    await ref.read(settingsRepositoryProvider).setBool(onboardingDoneKey, true);
    await ref.read(debugModeProvider.notifier).set(true);
    ref.invalidate(onboardingDoneProvider);
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(success)));
  } on Object {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(Strings.debugFailed)));
  }
}
